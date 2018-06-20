package GOpLog;
use warnings;
use strict;
use Data::Dumper;
use warnings;
use MongoDB;
use DateTime;
use DBI;

use lib '/opt/gsip/lib';
use AplConfig;
use AplDefine;
use AplLog;

use constant TAG => "AplBill";

sub new {
  my $class = shift();
  my $log = new AplLog(ident=>TAG);

  my $mongo = MongoDB::MongoClient->new( host => $AplConfig::MongoServer, port => $AplConfig::MongoPort );
  my $oplog = $mongo->get_database('local');

my %attr = (RaiseError=>1, PrintError=>1,AutoCommit=>1,mysql_enable_utf8 => 1,on_connect_do => ['SET NAMES utf8mb4']
);
my $dbh = DBI->connect(
                "DBI:mysql:checkdata:localhost",
                "root",
                "",
                \%attr);

  my $self = {
    esl => undef,
    log => $log,
    oplog => $oplog,
    mysql => $dbh,
    @_
    };
    return bless($self, $class);
}

sub start{
  my $self = shift();

  my $sql = "insert into chat (from_user,to_user,msg,msg_type) values (?,?,?,?)";
  $self->{mysql}->do("SET NAMES utf8mb4");
  my $sth = $self->{mysql}->prepare($sql);
  my $cursor = $self->{oplog}->get_collection( 'oplog.rs' );
  my $call_tran = $cursor->find({"ts" => {'$gt' => DateTime->now(time_zone => 'local')},ns => qr/chatlogextension/ , op => 'i'});
  #my $call_tran = $cursor->find({ns => qr/chatlogextension/ , op => 'i'});
 $call_tran->tailable_await(1);
 $call_tran->tailable(1);
 my $flag = 0;
 while (1) {
my $batch = $call_tran->next;
if(!$batch){
        sleep 1;
        next;
}
#print Dumper $batch->{o} ;
  my $to = $batch->{o}->{to};
  my $from = $batch->{o}->{from};
  my $msg = $batch->{o}->{value};
  my $type = $batch->{o}->{type};
if($type eq 'PP'){
  if($flag == 0){
    $sth->execute($from,$to,$msg,$type);
    print "$from :$to : $type : $msg\n";
    $flag = 1;
  }else{
    $flag = 0;
  }
  
}
}
  }
1;
