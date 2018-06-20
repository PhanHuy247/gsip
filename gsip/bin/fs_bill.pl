#!/usr/bin/perl

use warnings;
use strict;
use warnings;

use lib '/opt/gsip/lib';
use AplConfig;
use AplDefine;
use AplLog;
use AplBill;

my $main = new AplBill();
$main->start();
