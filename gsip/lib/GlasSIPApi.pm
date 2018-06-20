package GlasSIPApi;

use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use AplConfig;
use JSON;

sub new {
  my $class = shift();
  my $log = new AplLog();
  my $self = {
      debug => $AplConfig::debug,
      log => $log,
      @_
  };
  return bless($self, $class);
}

sub MakeCall(){
  my $self = shift();
  my ($fs_uuid,$from,$to,$type) = @_;

  my $data = {
    api => "make_call", 
    call_sip => $fs_uuid,
    from => $from,
    to => $to,
    type => $type + 0
  };

  my $json = JSON->new();
  my $js = $json->encode($data);
  $self->callApi($js);
}

sub StartCall(){
  my $self = shift();
  my ($fs_uuid,$from,$to,$type) = @_;

  my $data = {
    "api" => "start_call", 
    "call_sip" => $fs_uuid,
    "from" => $from,
    "to" => $to,
    "type" => $type + 0
  };

  my $json = JSON->new();
  my $js = $json->encode($data);
  $self->callApi($js);
}
sub EndCall(){
  my $self = shift();
  my ($fs_uuid,$from,$to,$finish_type,$type,$bill_seconds) = @_;

  my $data = {
    "api" => "end_call", 
    "call_sip" => $fs_uuid,
    "from" => $from,
    "to" => $to,
    "finish_type" => $finish_type,
    "bill_seconds" => $bill_seconds + 0,
    "type" => $type + 0
  };

  my $json = JSON->new();
  my $js = $json->encode($data);
  $self->callApi($js);
}
sub CallPayment(){
  my $self = shift();
  my ($fs_uuid,$from,$to,$point,$type,$caller_ip) = @_;

  my $data = {
    "api" => "call_payment", 
    "call_sip" => $fs_uuid,
    "caller_id" => $from,
    "reciever_id" => $to,
    "point" => $point + 0,
    "type" => $type + 0,
		"user_ip" => $caller_ip
	};

  my $json = JSON->new();
  my $js = $json->encode($data);
  $self->callApi($js);
}
sub callApi{
    my $self = shift();
    my($json) = @_;

    my $req = HTTP::Request->new( 'POST', $AplConfig::GlasServer );
    $req->header( 'Content-Type' => 'application/json' );
    my $utype;

    $self->{log}->info($AplConfig::GlasServer . $json);

    $req->content( $json );
    my $lwp = LWP::UserAgent->new;
    my $res = $lwp->request( $req );
    if (!$res->is_success) {
      $self->{log}->debug("api call fail:" . $json);
			return(9);
    }
		my $data = $res->content;
		$self->{log}->info($data);
		my $js = decode_json($data);
		return($js->{code});
}

1;
