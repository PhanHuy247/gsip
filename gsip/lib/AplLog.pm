package AplLog;

use Sys::Syslog;                        # all except setlogsock()
use strict;
use AplConfig;
use Data::Dumper;

sub new {
	my $class = shift();
    my $self = {
      debug => 1,
      ident => 'AplLog',
      @_
    };

		openlog($self->{ident}, 'pid', 'local2');
    return bless($self, $class);
}

sub debug {
	my $class = shift();
	my($log) = @_;
	syslog('LOG_DEBUG', $log);
}

sub info {
	my $class = shift();
	my($log) = @_;
	syslog('LOG_INFO', $log);
}

sub error {
	my $class = shift();
	my($log) = @_;
	syslog('LOG_ERR', $log);
}

sub fatal {
	my $class = shift();
	my($log) = @_;
	syslog('LOG_CRIT', $log);
}


1;
