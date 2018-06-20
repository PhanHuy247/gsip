package AplMain;
use warnings;
use strict;
use IO::Handle;
use Data::Dumper;
use warnings;
use Thread;
use ESL;

use lib '/opt/gsip/lib';
use AplConfig;
use AplDefine;
use AplLog;
use GlasSIPApi;
use constant TAG => "AplMain";
sub new {
  my $class = shift();
  my $log = new AplLog(ident=>TAG);
  my $gApi = new GlasSIPApi();
  my $self = {
    esl => undef,
    log => $log,
    glas_api => $gApi,
    @_
    };
    return bless($self, $class);
}
sub start{
	my $self = shift();

  $self->mainloop();
}
sub mainloop{
	my $self = shift();
	$self->{esl} = new ESL::ESLconnection(
		$AplConfig::fs_server,
		$AplConfig::fs_port,
		$AplConfig::fs_pass);
	$self->{esl}->recvEventTimed($AplConfig::recvEventTimed);
	#$self->{esl}->events($AplConfig::recvEventFormat,$AplConfig::Filter);
	$self->{esl}->events($AplConfig::recvEventFormat,"CHANNEL_CALLSTATE CALL_UPDATE CHANNEL_HANGUP_COMPLETE");
	while(1){
		if(!$self->{esl}->connected()){
    	$self->{esl} = new ESL::ESLconnection(
				$AplConfig::fs_server,
				$AplConfig::fs_port,
				$AplConfig::fs_pass);
			$self->{esl}->recvEventTimed($AplConfig::recvEventTimed);
#			$self->{esl}->events($AplConfig::recvEventFormat,$AplConfig::Filter);
			$self->{esl}->events($AplConfig::recvEventFormat,"CHANNEL_CALLSTATE CALL_UPDATE CHANNEL_HANGUP_COMPLETE");
			sleep(1);
			}
			my $e = $self->{esl}->recvEvent();
			if(!$e){
				next;
			}
			my $type = $e->getType();
			my $subclass = $e->getHeader("Event-Subclass");
			if(!defined($subclass)){
				$subclass = "NULL";
			}
			if($type eq 'CALL_UPDATE'){
        if($e->getHeader("variable_endpoint_disposition") eq 'ANSWER'){
          if($e->getHeader("Call-Direction") eq 'inbound'){
              $self->{glas_api}->StartCall(
                $e->getHeader("Unique-ID"),
                $e->getHeader("Caller-Caller-ID-Number"),
                $e->getHeader("Caller-Destination-Number"),
                $e->getHeader("variable_call_type"));
							#初回の課金はここでする
							my $uuid = $e->getHeader("Channel-Call-UUID");
							my $caller_ip = $e->getHeader("Caller-Network-Addr");
							my $ret = $self->doFirstCharge(
								$uuid,
								$self->{esl}->api("uuid_getvar $uuid sip_from_user")->getBody(),
								$self->{esl}->api("uuid_getvar $uuid sip_to_user")->getBody(),
								$self->{esl}->api("uuid_getvar $uuid my_from_charge")->getBody(),
								$self->{esl}->api("uuid_getvar $uuid my_to_charge")->getBody(),
								$self->{esl}->api("uuid_getvar $uuid my_call_type")->getBody(),
								$caller_ip);
							if($ret == 0){
								$self->{esl}->api("uuid_kill ". $uuid);
							}
          }
        }
			}
			if($type eq 'CHANNEL_HANGUP_COMPLETE'){
        my $finish_type = 0;
=pod
        print "Hangup-Cause:" . $e->getHeader("Hangup-Cause") . "\n";
        print "Call-Direction:" . $e->getHeader("Call-Direction") . "\n";
        print "Answer-State:" . $e->getHeader("Answer-State") . "\n";
        print "Call-Direction:" . $e->getHeader("Call-Direction") . "\n";
        print "variable_billsec:" . $e->getHeader("variable_billsec") . "\n";
        print "variable_my_call_type" . $e->getHeader("variable_my_call_type") . "\n";
        print "variable_endpoint_disposition" . $e->getHeader("variable_endpoint_disposition") . "\n";
=cut
				my $r = $e->getHeader("variable_endpoint_disposition");
			  if(defined($r)){
					if($e->getHeader("variable_endpoint_disposition") eq 'DELAYED NEGOTIATION'){
				  	if($e->getHeader("Hangup-Cause") eq 'CALL_REJECTED'){
					    next;
					  }
				  }
				}
				#発信時のEndCall回避
				if($e->getHeader("Caller-Context") eq 'public'){
					next;
				}

        $finish_type = $self->getFinishInfo($e);
				#その他は無視
        if($finish_type == $AplDefine::END_CALL_OTHERS){
          next;
        }

        my $call_success_flg = $e->getHeader("variable_makecall_flg");
        if(defined($call_success_flg) && $call_success_flg == 1){
            $self->{glas_api}->EndCall(
              $e->getHeader("Unique-ID"),
              $e->getHeader("Caller-Caller-ID-Number"),
              $e->getHeader("Caller-Destination-Number"),
              $finish_type,
              $e->getHeader("variable_my_call_type"),
              $e->getHeader("variable_billsec")
            );
        }
      }
			if($type eq 'CHANNEL_CALLSTATE'){
				if($e->getHeader("Channel-Call-State") eq 'RINGING'){
					if($e->getHeader("Answer-State") eq 'ringing'){
						if($e->getHeader("Call-Direction") eq 'outbound'){
		          $self->{esl}->api("uuid_setvar ".$e->getHeader("Channel-Call-UUID")." my_call_success 1");
						}
					}
				}
			}
		}
	}

sub dumpHeaders{
	my $self = shift();
	my($o) = @_;

	my $header = $o->firstHeader();
	while($header){
		$self->{log}->info($header . "->" .$o->getHeader($header));
		$header = $o->nextHeader();
	}
}

sub getFinishInfo{
  my $self = shift();
  my($e) = @_;

  if($e->getHeader("Call-Direction") eq 'outbound'){
    if($e->getHeader("Hangup-Cause") eq 'USER_BUSY'){
			unless(defined($e->getHeader("variable_sip_from_tag"))){
				print "話中" . "\n";
      	return $AplDefine::CALL_BUSY;
			}
    }
  }

 if(defined($e->getHeader("variable_my_point_empty"))){
    if($e->getHeader("variable_my_point_empty") eq '1'){
      print "ポイント切れ" . "\n";
      return $AplDefine::END_CALL_BY_NOT_ENOUGH_POINT;
    }
  }

=pod
print "Caller-ID；" . $e->getHeader("Caller-Caller-ID-Number") . "\n";
print "Destination-ID；" . $e->getHeader("Caller-Destination-Number") . "\n";
print "to_gender：" . $e->getHeader("variable_my_to_gender") . "\n";
print "Caller-Direction；" . $e->getHeader("Caller-Direction") . "\n";
print "variable_sip_hangup_disposition:" . $e->getHeader("variable_sip_hangup_disposition") . "\n";
=cut

  if($e->getHeader("Caller-Direction") eq 'inbound'){
    if($e->getHeader("Hangup-Cause") eq 'ORIGINATOR_CANCEL'){
      print "発信者がキャンセル" . "\n";
      return $AplDefine::CALL_CANCEL;
    }

    #掛けられた人
    if($e->getHeader("variable_sip_hangup_disposition") eq 'send_bye'){
      #切った
      if($e->getHeader("variable_my_to_gender") eq '0'){
        print "男性着信者が切った" . "\n";
        return $AplDefine::END_CALL_BY_MALE;
      }else{
        print "女性着信者が切った" . "\n";
        return $AplDefine::END_CALL_BY_FEMALE;
      }
    }else{
      #掛けられた人だったら
			if($e->getHeader("variable_sip_hangup_disposition") eq 'send_refuse'){
					print "キャンセル" . "\n";
					return $AplDefine::CALL_CANCEL;
			}
      if($e->getHeader("variable_originate_disposition") eq 'CALL_REJECTED'){
				print "着信者が拒否" . "\n";
				return $AplDefine::CALL_BUSY;
			}
			if($e->getHeader("variable_originate_disposition") ne 'USER_BUSY'){
	    	if($e->getHeader("variable_my_to_gender") eq '1'){
 	     		print "男性発信者が切った" . "\n";
 	     	  return $AplDefine::END_CALL_BY_MALE;
 	    	}else{
 	      	print "女性発信者が切った" . "\n";
 	     	  return $AplDefine::END_CALL_BY_FEMALE;
  	    }
			}
   }
  }
  print "その他" . "\n";
  return $AplDefine::END_CALL_OTHERS;
}

sub doFirstCharge{
  my $self = shift();
  my($uuid,$from,$to,$from_charge,$to_charge,$type,$caller_ip) = @_;
        if($from_charge < 0){
          my $res = $self->{glas_api}->CallPayment(
            $uuid,$from,$to,$from_charge,$type,$caller_ip);
          if($res != 0){
						return 0;
          }
					#女性の初回課金なしはここをコメントアウト
#          $res = $self->{glas_api}->CallPayment(
#            $uuid,$to,$from,$to_charge,$type,$caller_ip);
#          if($res != 0){
#						return 0;
#          }
        }else{
          my $res = $self->{glas_api}->CallPayment(
            $uuid,$to,$from,$to_charge,$type,$caller_ip);
          if($res != 0){
						return 0;
          }
					#女性の初回課金なしはここをコメントアウト
#          $res = $self->{glas_api}->CallPayment(
#            $uuid,$from,$to,$from_charge,$type,$caller_ip);
#          if($res != 0){
#						return 0;
#          }
        }
	return 1;
}
1;
