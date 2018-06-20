package IvrMain;

use warnings;
use strict;
use IO::Handle;
use Data::Dumper;
use warnings;
use Thread;
use ESL::IVR;
use MongoDB;
use DBI;

use lib '/opt/gsip/lib';
use AplConfig;
use AplDefine;
use AplLog;
use GlasSIPApi;

use constant TAG => "IvrMain";

sub new {
  my $class = shift();
  my $log = new AplLog(ident=>TAG);
	my $con = new ESL::IVR;
  my $gApi = new GlasSIPApi();
  my $mongo = MongoDB::MongoClient->new( host => $AplConfig::MongoServer, port => $AplConfig::MongoPort );
  my $userdb = $mongo->get_database('userdb');
  my $settingdb = $mongo->get_database('settingdb');
  my $col_user = $userdb->get_collection('user');
  my $col_point = $settingdb->get_collection('communication_setting');

  my $self = {
    esl => undef,
    log => $log,
    con => $con,
    fs_uuid => undef,
    from_uri => undef,
    destination_number => undef,
    caller_id_number => undef,
    type => undef,
    type_str => undef,
    glas_api => $gApi,
    m_user => $col_user,
    m_setting => $col_point,
    @_
    };
    return bless($self, $class);
}

sub start{
  my $self = shift();

  my $switch_r_sdp = $self->{con}->getVar('switch_r_sdp');
  $self->{fs_uuid} = $self->{con}->{_uuid};
  $self->{from_uri} = $self->{con}->getVar('sip_from_uri');
  $self->{destination_number} = $self->{con}->getVar('destination_number');
  $self->{caller_id_number} = $self->{con}->getVar('caller_id_number');
  $self->{log}->debug("destination_number:".$self->{destination_number});
  $self->{log}->debug("caller_id_number:".$self->{caller_id_number});
  $self->{log}->debug("switch_r_sdp:".$switch_r_sdp);

if($switch_r_sdp =~ /video/){
          $self->{type} = $AplDefine::VIDEO_CALL;
          $self->{type_str} = $AplDefine::VIDEO_CALL_STR;
  }else{
          $self->{type} = $AplDefine::VOICE_CALL;
          $self->{type_str} = $AplDefine::VOICE_CALL_STR;
  }

  my ($from_charge,$to_charge,$from_gender,$to_gender) = 
    $self->getChargeInfo($self->{caller_id_number},$self->{destination_number},$self->{type_str});

  $self->{con}->setVar('call_type',$self->{type});
  $self->{con}->setVar('my_call_type',$self->{type});

  $self->{con}->setVar('my_from_charge',$from_charge);
  $self->{con}->setVar('my_to_charge',$to_charge);

  $self->{con}->setVar('my_from_gender',$from_gender);
  $self->{con}->setVar('my_to_gender',$to_gender);

  $self->{con}->setVar('my_charge_count',1);

  $self->{glas_api}->MakeCall(
    $self->{fs_uuid},
    $self->{caller_id_number},
    $self->{destination_number},
    $self->{type}
  );

  $self->{con}->setVar('makecall_flg',1);
  $self->{con}->setVar('my_call_success',0);
  my $start_time = time;
  my $end_time = $start_time + $AplConfig::call_timeout;
  
  my $dbhh = DBI->connect("dbi:SQLite:dbname=$AplConfig::CoreDB");
  my $sqll = "select callstate, b_state from basic_calls where cid_name is not null and dest is not null and (cid_name= ? or dest = ?)";
  my $ssth = $dbhh->prepare($sqll);
  
  my $rrow;
  my $secondRow;

  $ssth->execute($self->{destination_number}, $self->{destination_number});
  
  if (my @row = $ssth->fetchrow_array) {
    $rrow = $row['callstate'];
    $secondRow = $row['b_state'];
  } else {
    $rrow = "dummy";
    $secondRow = "dummy";
  }

  $dbhh->disconnect;

  if ($rrow eq "ACTIVE" || $secondRow eq "ACTIVE") {
    $end_time = time + $AplConfig::busy_timeout;
    
    my $call_timeout = $end_time - time;
    $self->{con}->execute("set","call_timeout=$call_timeout");
    $self->{con}->execute("set","hangup_after_bridge=true");
    $self->{con}->execute("set", "continue_on_fail=NORMAL_TEMPORARY_FAILURE,USER_NOT_REGISTERED,PROGRESS_TIMEOUT");
    $self->{con}->execute("set", "progress_timeout=5");
    $self->{con}->execute("pre_answer");
    
    sleep $AplConfig::busy_timeout;
    $self->{con}->execute("hangup", "USER_BUSY");
    exit;
  }
  
  while($end_time > time){
    $self->{log}->debug("retry:".time);
    my $call_timeout = $end_time - time;
    $self->{con}->execute("set","call_timeout=$call_timeout");
    $self->{con}->execute("set","hangup_after_bridge=true");
    $self->{con}->execute("set","continue_on_fail=true");
    $self->{con}->execute("set", "continue_on_fail=NORMAL_TEMPORARY_FAILURE,USER_NOT_REGISTERED,PROGRESS_TIMEOUT");
    $self->{con}->execute("set", "progress_timeout=15");
    $self->{con}->execute("pre_answer");
    $self->{con}->execute("set", "ringback=");

my $res;

$res = $self->{con}->execute("bridge","user/$self->{destination_number}\@\${domain_name}");
    if(!defined($res)){
      $self->{log}->debug("no res");
      $self->{log}->debug("before exit2");
        exit;
    }else{
      $self->{log}->debug("result:".$res->serialize());
      $self->dumpHeaders($res);
    }
    sleep 2;
    $self->{log}->debug("in loop");
  }
}
sub dumpHeaders{
  my $self = shift();
  my($o) = @_;

  my $header = $o->firstHeader();
  while($header){
    $self->{log}->debug($header . "->" .$o->getHeader($header));
    $header = $o->nextHeader();
  }
}

sub getChargeInfo{
  my $self = shift();
  my($from,$to,$type_str) = @_;

my $from_obj = $self->{m_user}->find_one({ _id => MongoDB::OID->new(value => $from) });
  my $to_obj = $self->{m_user}->find_one({ _id => MongoDB::OID->new(value => $to) });
  my $from_start_point = $from_obj->{point};
  my $from_gender = $from_obj->{gender};
  my $is_from_purchase = $from_obj->{have_purchase};
  my $to_start_point = $to_obj->{point};
  my $to_gender = $to_obj->{gender};
  my $is_to_purchase = $to_obj->{have_purchase};

  my $str_from = "$from_obj->{user_name}:$self->{caller_id_number}:$from_start_point:$from_gender:$is_from_purchase";
  my $str_to = "$to_obj->{user_name}:$self->{destination_number}:$to_start_point:$to_gender:$is_to_purchase";

  $self->{log}->info( "[" . $self->{fs_uuid} . "]" . $type_str . ":" . $str_from . " => " . $str_to);
  my $caller_receiver =  $self->makeCaller_receiver($from_gender,$to_gender);
  my $price = $self->{m_setting}->find_one({"type" => $type_str,"caller_receiver" => $caller_receiver});

  my $from_point;
  my $to_point;
$self->{log}->info("caller:".$price->{caller});
$self->{log}->info("potential_customer_caller:".$price->{potential_customer_caller});
$self->{log}->info("receiver:".$price->{receiver});
$self->{log}->info("potential_customer_receiver:".$price->{potential_customer_receiver});
  $self->{log}->info("is_to_purchase" . $is_to_purchase);
  $self->{log}->info("is_from_purchase" . $is_from_purchase);

if($caller_receiver eq 'male_female'){
  if($is_from_purchase){
    $from_point = $price->{caller};
    $to_point = $price->{receiver};
  }else{
    $from_point = $price->{potential_customer_caller};
    $to_point = $price->{potential_customer_receiver};  
  }
}else{
if($is_to_purchase){
  $from_point = $price->{caller};
  $to_point = $price->{receiver};
}else{
  $from_point = $price->{potential_customer_caller};
  $to_point = $price->{potential_customer_receiver};  
 }
}








  $self->{log}->info("charge from:$from_point to:$to_point");
  return($from_point,$to_point,$from_gender,$to_gender);
}

sub makeCaller_receiver{
  my $self = shift();
  my($from,$to) = @_;
  my $from_str;
  my $to_str;

  if($from eq '1'){
    $from_str = 'female';
  }else{
    $from_str = 'male';  
  }
  if($to eq '1'){
    $to_str = 'female';
  }else{
    $to_str = 'male';  
  }
  return ($from_str . "_" . $to_str);
}












1;
