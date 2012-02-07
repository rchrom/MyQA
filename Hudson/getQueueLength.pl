#!/usr/bin/perl
# Copyright (C) 2007-2011, GoodData(R) Corporation. All rights reserved.

use LWP::UserAgent;
use HTTP::Request::Common;
use URI;
use JSON;

use strict;
use warnings;
use Env qw(JOB_URL);

my $LOGFILE = "queue-length.csv";
my $HUDSON  = 'http://hudson.qa/hudson/';

download_previous_report();

gen_report();

sub download_previous_report {

	my $jobUrl = "$JOB_URL";
	my $uri    = new URI($jobUrl);
	my $ua     = new LWP::UserAgent;

	my $fileContent = $ua->request(
		GET( new URI("lastSuccessfulBuild/artifact/Hudson/$LOGFILE")->abs($uri) ) )
	  ->decoded_content;
	$fileContent = "" unless $fileContent;
	open( OUTFILE, ">", $LOGFILE );
	print OUTFILE $fileContent , "\n";
	close(OUTFILE);
}

sub get_hudson_queue {

	my $hudson_root = new URI($HUDSON);
	my $ua          = new LWP::UserAgent;

	#print "Request to hudson...";

	my $queue = decode_json(
		$ua->request( GET( new URI('queue/api/json')->abs($hudson_root) ) )
		  ->decoded_content );
	die 'Failed to get Queue' unless $queue;

	#print "responce received\n";

	return $queue;
}

sub gen_report {
	my $queue     = get_hudson_queue;
	my $array_ref = $queue->{"items"};
	my @array     = @$array_ref;

	(
		my $sec,  my $min,  my $hour, my $mday, my $mon,
		my $year, my $wday, my $yday, my $isdst
	) = localtime(time);
	$year += 1900;
	$mon++;
	$mon  = "0" . $mon  if $mon < 10;
	$mday = "0" . $mday if $mday < 10;
	my $CSVSEPARATOR = ";";

	print "Queue size: $#array \n";
	open( OUTFILE, ">>", $LOGFILE );
	foreach my $item (@array) {
		print OUTFILE "${year}${mon}${mday}_${hour}${min}", $CSVSEPARATOR,
		  $#{array}, $CSVSEPARATOR, $item->{"task"}->{"name"}, $CSVSEPARATOR,
		  $item->{"why"}, "\n";
	}
	close(OUTFILE);
}

