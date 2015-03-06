#!/usr/bin/perl

use strict;

use POSIX qw(strftime);

my $date = strftime "%Y.%m.%d", localtime;

open(F,"<$ARGV[0]/src/version.h") or die;
my @lines=<F>;
close(F);

my $text=join("",@lines);
my $version=(split("VERSION \"",$text))[1];
my $version=(split("\"",$version))[0];
my $hash=`cd $ARGV[0] && git log --pretty=format:'%h' -n 1`;

open(F,"<$ARGV[0]/nsis/x2goclient.nsi") or die;
@lines=<F>;
close(F);

$text=join("",@lines);

$text=~s/X2GOCLIENT_VERSION/$version-$date-$hash/;
#print $text;

open(F,">$ARGV[0]/nsis/x2goclient.nsi") or die;
print F $text;
close(F);
