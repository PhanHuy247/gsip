package AplUtil;

use strict;
use warnings;
use AplConfig;
use AplDefine;
use AplLog;
use PHP::Serialization qw(serialize);
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use DBI;
use DBIx::QueryLog;

sub GetUserPath {
    my ($file) = @_;

		return ($AplConfig::BaseDir . $file);
}

sub GetTelChannel {
    my($uri) = @_;
    my $tel;
    my $domain;
    if($uri !~ /^([^\@]+)\@(.+)$/){
        return undef;
    }
    $tel = $1;
    $domain = $2;
    foreach my $key (keys(%$AplConfig::LineType)){
        if($domain =~ /^$AplConfig::LineType->{$key}{Condition}$/){
            return($tel,$AplConfig::LineType->{$key}{Code})
        }
    }
    return ($1,$2);
}

=pod
sub postAndGet {
    #my($url,$Direction,$CallStatus,$kind,$opt) = @_;
    my($dbh,$log,$AccountSid,$CallSid,$url,$from,$dest,
        $Direction,$CallStatus,$kind,$opt) = @_;


   my %params = 
        makeParam($AccountSid,$CallSid,
        $from,$dest,$Direction,$CallStatus,$AplConfig::version);
    #add option values
    if(defined($opt)){
        foreach my $key (keys %$opt){
            #$params{$key} = $opt->{$key};
            %params->{$key} = $opt->{$key};
        }
    }
    my $dataId;
    #logging
    my $sql = "INSERT INTO http_request_logs (AccountSid,Url,CallSid,mode,Parameter,RequestDatetime,status) values (?,?,?,?,?,now(),0)";
    my $sth = $dbh->prepare($sql);
    $sth->execute($AccountSid,$url,$CallSid,$kind,serialize(\%params));
    if($kind eq $AplDefine::LogKind->{LOG_REQUEST}{Code}){
        $dataId = $sth->{mysql_insertid};
    }
    
    my $request = POST($url, [%params]);

    my $ua = LWP::UserAgent->new;
    $ua->timeout($AplConfig::HttpTimeOut);
    my $response = $ua->request($request);

    #log update
    $sql = "UPDATE http_request_logs set ResponseHeader = ? ,ResponseBody = ? ,ResponseDatetime = now() ,StatusCode = ? ,ErrorDescription = ? where CallSid = ?";
    $sth = $dbh->prepare($sql);
    $sth->execute($response->headers_as_string,$response->content,$response->code,$response->status_line,$CallSid);
    if (!$response->is_success) {
        $log->fatal('fail');

        if($kind ne $AplDefine::LogKind->{LOG_FAIL_BACK}{Code}){
            my $opt = {
                ErrorUrl => $url,
                ErrorCode => $AplDefine::Error->{HTTP_STATUS_ERROR}{Code},
                ErrorDescription => $AplDefine::Error->{HTTP_STATUS_ERROR}{Description} . "\n" . $response->status_line,
            };
            #can't cantinue
            $self->postError($opt);
        }
        return undef;
    }
    return($response->content,$dataId);
}

sub makeParam {
    my ($AccountSid,$CallSid,$Caller,$Called,$Direction,$CallStatus,$ApiVersion) = @_;

    my %params = (
        AccountSid => $AccountSid ,
        CallSid => $CallSid ,
        CalledVia => $Called ,
        Called => $Called ,
        CalledCountry =>  ,
        To => $Called ,
        Caller => $Caller ,
        CallerCountry =>  ,
        From => $Caller ,
        ForwardedFrom => $Called ,
        Direction => $Direction ,
        CallStatus => $CallStatus ,
        ApiVersion => $ApiVersion ,
        FromState => '' ,
        FromCity => '' ,
        FromZip => '' ,
        FromCountry => '' ,
        ToState => '' ,
        ToCity => '' ,
        ToZip => '' ,
        ToCountry => '' ,
        CallerState => '' ,
        CallerCity => '' ,
        CallerZip => '' ,
        CalledCity => '' ,
        CalledZip => '' ,
        CalledState => '' ,
    );
    return(%params);
} 
=cut
1;
