package AplConfig;

use strict;

our $version = "0.1";
our $HttpTimeOut = 10;

our $CoreDB = '/opt/freeswitch/db/core.db';

our $log_ident = 'ap';
our $log_facility = 'local6';

our $log_file = undef;

our $fs_server = '127.0.0.1';
our $fs_port = '8021';
our $fs_pass = "ClueCon";
our $recvEventTimed = 1000;
our $recvEventFormat = "plain";
our $Filter = "CHANNEL_CALLSTATE";

our $MongoPort = 27017;
our $MongoServer = "DBSERVER";
our $GlasServer = "http://10.64.100.18:9119";

#config for push

our $call_timeout = 90;
our $busy_timeout = 90;
1;
