#!/usr/bin/perl

use warnings;
use strict;
use warnings;

use lib '/opt/gsip/lib';
use AplConfig;
use AplDefine;
use AplLog;
use IvrMain;

my $main = new IvrMain();
$main->start();
print "last lain\n";
