#!/usr/bin/perl

use strict;

use POSIX qw(strftime);

my $date = strftime "%Y.%m.%d", localtime;

open(F,"<../../GIT/nightly/x2goclient/version.h") or die;
my @lines=<F>;
close(F);

my $text=join("",@lines);
my $version=(split("VERSION \"",$text))[1];
my $version=(split("\"",$version))[0];

open(F,"<../../GIT/nightly/x2goclient/nsis/x2goclient.nsi") or die;
@lines=<F>;
close(F);

$text=join("",@lines);

$text=~s/X2GOCLIENT_VERSION/$version-$date/;
#print $text;

open(F,">../../GIT/nightly/x2goclient/nsis/x2goclient.nsi") or die;
print F $text;
close(F);
