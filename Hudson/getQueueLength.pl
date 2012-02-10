#!/usr/bin/perl
# Copyright (C) 2007-2011, GoodData(R) Corporation. All rights reserved.

use LWP::UserAgent;
use HTTP::Request::Common;
use URI;
use JSON;

use strict;
use warnings;
use Env qw(JOB_URL);

my $LOGFILE = "queue-length.txt";
my $HUDSON  = 'http://hudson.qa/hudson/';

download_previous_report();

gen_report();

sub download_previous_report {

	# skip loading previous report if JOB_URL is not defined
	return unless defined($JOB_URL);

	my $jobUrl = "$JOB_URL";

	my $uri = new URI($jobUrl);
	my $ua  = new LWP::UserAgent;

	my $fileContent = $ua->request(
		GET(
			new URI("lastSuccessfulBuild/artifact/Hudson/$LOGFILE")->abs($uri)
		)
	)->decoded_content;
	$fileContent = "" unless $fileContent;
	open( OUTFILE, ">", $LOGFILE );
	print OUTFILE $fileContent, "\n";
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
	$hour = "0" . $hour if $hour < 10;
	$min  = "0" . $min  if $min < 10;
	my $CSVSEPARATOR = ";";

	print "Queue size: $#array\n";
	open( OUTFILE, ">>", $LOGFILE );

	if ( $#array <= 0 ) {
		print OUTFILE "${year}-${mon}-${mday} ${hour}:${min};0;-;-\n";
	}
	else {
		foreach my $item (@array) {
			my $reason = $item->{"why"};
			$reason = "Build in progress"
			  if $reason =~ "Build #.* is already in progress.*";
			$reason = "Offline node: $1"
			  if $reason =~ "All nodes of label '\(.*\)' are offline";
			$reason = "Bussy node: $1"
			  if $reason =~ "Waiting for next available executor on \(.*\)";
			$reason = "In the quiet period"
			  if $reason =~ "In the quiet period. Expires in .*";

			print OUTFILE "${year}-${mon}-${mday} ${hour}:${min}",
			  $CSVSEPARATOR,
			  $#{array}, $CSVSEPARATOR, $item->{"task"}->{"name"},
			  $CSVSEPARATOR,
			  $reason, "\n";
		}
	}
	close(OUTFILE);
}
