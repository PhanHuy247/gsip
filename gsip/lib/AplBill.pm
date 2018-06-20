package AplBill;
use warnings;
use strict;
use Data::Dumper;
use warnings;
use DBI;
#use Cache::Memcached::Fast;

use lib '/opt/gsip/lib';
use AplConfig;
use AplDefine;
use AplLog;
use ESL;
use GlasSIPApi;

use constant TAG => "AplBill";

sub new {
  my $class = shift();
  my $log = new AplLog(ident=>TAG);
  my $gApi = new GlasSIPApi();
  my $dbh = DBI->connect("dbi:SQLite:dbname=$AplConfig::CoreDB");
	if (!$dbh){
		$log->fatal($AplDefine::Error->{DATABASE_CONNECT_ERROR}{Description} .
			$AplDefine::Error->{DATABASE_CONNECT_ERROR}{Description});
		$log->fatal($dbh->err);
		$log->fatal($dbh->errstr);
		return undef;
	}

  my $self = {
    esl => undef,
    log => $log,
    dbh => $dbh,
    glas_api => $gApi,
    @_
    };
    return bless($self, $class);
}

sub start{
  my $self = shift();
      $self->{esl} = new ESL::ESLconnection(
        $AplConfig::fs_server,
        $AplConfig::fs_port,
        $AplConfig::fs_pass);
  my $sql = "select call_uuid,strftime('%s', 'now','localtime') - strftime('%s', call_created) ,strftime('%Y年%m月%d日 %H時%M分%S秒', 'now','localtime'),strftime('%Y年%m月%d日 %H時%M分%S秒', call_created) from calls";
  while(1){
    if(!$self->{esl}->connected()){
      $self->{esl} = new ESL::ESLconnection(
        $AplConfig::fs_server,
        $AplConfig::fs_port,
        $AplConfig::fs_pass);
        sleep(1);
      }
    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute();

    while(my @row = $sth->fetchrow_array) {
      print "call_uuid:$row[0]\n";
      if(!$self->{esl}->connected()){
	next;
      }
      my $my_charge_count = $self->{esl}->api("uuid_getvar $row[0] my_charge_count")->getBody();

      print "現在時刻：$row[2]\n";
      print "開始時刻：$row[3]\n";
      print "経過時間：$row[1]\n";
      my $need_times = int($row[1]/15)+1;
      print "課金必要回数：$need_times\n";
      print "課金回数：$my_charge_count\n";

#			#15秒経過時に女性のみ課金
#			if($row[1] == 15){
#				$self->doFemaleOnlyCharge($row[0]);
#			}

      if($need_times > $my_charge_count){
        #分数に対して課金回数が足りないので課金
        print "課金\n";
				print "uuid_getvar $row[0] sip_from_user\n";

	  		my $t_from = $self->{esl}->api("uuid_getvar $row[0] sip_from_user")->getBody();
				if($t_from =~ /^-ERR/){
	        print "No such t_from \n";
					next;
				}
	  		my $t_to = $self->{esl}->api("uuid_getvar $row[0] sip_to_user")->getBody();
				if($t_to =~ /^-ERR/){
		      print "No such t_to \n";
					next;
				}
        my $t_from_charge = $self->{esl}->api("uuid_getvar $row[0] my_from_charge")->getBody();
				if($t_from_charge =~ /^-ERR/){
	        print "No such t_from_charge \n";
					next;
				}
        my $t_to_charge = $self->{esl}->api("uuid_getvar $row[0] my_to_charge")->getBody();
				if($t_to_charge =~ /^-ERR/){
	        print "No such t_to_charge \n";
					next;
				}
	  		my $t_type = $self->{esl}->api("uuid_getvar $row[0] my_call_type")->getBody();
				if($t_type =~ /^-ERR/){
	        print "No such t_type \n";
					next;
				}
				#課金
				#マイナスを先に
				#だけど両方共マイナスで後の方だけ課金失敗の場合は終わらせるけど先に課金した方は戻さない
				my $caller_ip = $self->{esl}->api("uuid_getvar $row[0] sip_from_host")->getBody();
print "uuid:" . $row[0] . "\n";
print "callerIP:" . $caller_ip . "\n";
				if($t_from_charge > 0){
        	my $res = $self->{glas_api}->CallPayment(
	  				$row[0],$t_from,$t_to,$t_from_charge,$t_type,$caller_ip);
					if($res != 0){
						$self->{esl}->api("uuid_setvar $row[0] my_point_empty 1");
						$self->{esl}->api("uuid_kill $row[0]");
						next;
					}
        	$res = $self->{glas_api}->CallPayment(
	  				$row[0],$t_to,$t_from,$t_to_charge,$t_type,$caller_ip);
					if($res != 0){
						$self->{esl}->api("uuid_setvar $row[0] my_point_empty 1");
						$self->{esl}->api("uuid_kill $row[0]");
						next;
					}
				}else{
        	my $res = $self->{glas_api}->CallPayment(
	  				$row[0],$t_to,$t_from,$t_to_charge,$t_type,$caller_ip);
					if($res != 0){
						$self->{esl}->api("uuid_setvar $row[0] my_point_empty 1");
						$self->{esl}->api("uuid_kill $row[0]");
						next;
					}
        	$res = $self->{glas_api}->CallPayment(
	  				$row[0],$t_from,$t_to,$t_from_charge,$t_type,$caller_ip);
					if($res != 0){
						$self->{esl}->api("uuid_setvar $row[0] my_point_empty 1");
						$self->{esl}->api("uuid_kill $row[0]");
						next;
					}
				}
        $my_charge_count++;
        $self->{esl}->api("uuid_setvar $row[0] my_charge_count $my_charge_count");
      }
    }
  sleep 1;
  }
}


sub doFemaleOnlyCharge{
  my $self = shift();
  my($call_uuid) = @_;

  my $t_from_charge = $self->{esl}->api("uuid_getvar $call_uuid my_from_charge")->getBody();
  if($t_from_charge =~ /^-ERR/){
    print "No such t_from_charge \n";
    next;
  }
  my $t_to_charge = $self->{esl}->api("uuid_getvar $call_uuid my_to_charge")->getBody();
  if($t_to_charge =~ /^-ERR/){
    print "No such t_to_charge \n";
    next;
  }
  my $t_from = $self->{esl}->api("uuid_getvar $call_uuid sip_from_user")->getBody();
  if($t_from =~ /^-ERR/){
    print "No such t_from \n";
    return 1;
  }
  my $t_to = $self->{esl}->api("uuid_getvar $call_uuid sip_to_user")->getBody();
  if($t_to =~ /^-ERR/){
    print "No such t_to \n";
    return 1;
  }
  my $t_type = $self->{esl}->api("uuid_getvar $call_uuid my_call_type")->getBody();
  if($t_type =~ /^-ERR/){
    print "No such t_type \n";
    return 1;
  }
  my $caller_ip = $self->{esl}->api("uuid_getvar $call_uuid sip_from_host")->getBody();

  if($t_from_charge < 0){
    my $res = $self->{glas_api}->CallPayment(
    $call_uuid,$t_to,$t_from,$t_to_charge,$t_type,$caller_ip);
    if($res != 0){
      $self->{esl}->api("uuid_setvar $call_uuid my_point_empty 1");
      $self->{esl}->api("uuid_kill $call_uuid");
      return 0;
    }
  }else{
    my $res = $self->{glas_api}->CallPayment(
    $call_uuid,$t_from,$t_to,$t_from_charge,$t_type,$caller_ip);
    if($res != 0){
      $self->{esl}->api("uuid_setvar $call_uuid my_point_empty 1");
      $self->{esl}->api("uuid_kill $call_uuid");
      return 0;
    }
  }
}
1;
