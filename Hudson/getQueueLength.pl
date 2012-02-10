#!/usr/bin/perl
# Copyright (C) 2007-2011, GoodData(R) Corporation. All rights reserved.

use LWP::UserAgent;
use LWP::Simple;
use HTTP::Request::Common;
use URI;
use JSON;

use strict;
use warnings;
use Env qw(JOB_URL);

my $LOGFILE = "queue-length.txt";
my $HUDSON  = 'http://hudson.qa/hudson/';

# CL tool source
my $clzipname      = "gooddata-cli-1.2.48";
my $mainCLUrl      = "${HUDSON}job/GoodData%20CL/lastSuccessfulBuild/artifact/cli-distro/target";
my $alternateCLUrl = "https://github.com/downloads/gooddata/GoodData-CL";

## MAIN
download_previous_report();    # skip if $JOB_URL is not defined
gen_report();                  # generate actual state of hudson queue
upload_to_secure();            # skip if download previsous report failed
## END

# Download previous report from Job storage if any
sub download_previous_report {

	# skip loading previous report if JOB_URL is not defined
	if ( defined($JOB_URL) ) {
		print "Downloading previous statistics ...";
		my $code = getstore( "$JOB_URL/lastSuccessfulBuild/artifact/Hudson/$LOGFILE", "$LOGFILE" );
		die "Unable to download statistics. " if $code != 200;
		print "...downloaded.\n";
	}
	else {
		print "\$JOB_URL is not defined, creating new one";
	}
}

# Get hudson queue information in hash
sub _get_hudson_queue {
	my $hudson_root = new URI($HUDSON);
	my $ua          = new LWP::UserAgent;

	print "Request to hudson for queue...";

	my $queue = decode_json( $ua->request( GET( new URI('queue/api/json')->abs($hudson_root) ) )->decoded_content );
	die 'Failed to download queue' unless $queue;

	print "...received.\n";

	return $queue;
}

# generate csv report
sub gen_report {
	my $queue     = _get_hudson_queue;
	my $array_ref = $queue->{"items"};
	my @array     = @$array_ref;

	( my $sec, my $min, my $hour, my $mday, my $mon, my $year, my $wday, my $yday, my $isdst ) = localtime(time);
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

# download cl tool and unpack to subfolder
# returns: folder where cltool is unpacked
sub _get_cl_tool {

	# determine where from cli tool is going to be downloaded.
	my $clzipurl = $mainCLUrl;

	print "Search for the cli tool on '$clzipurl' ...";
	my $content = get("$clzipurl/*.zip");
	if ( $content =~ '/.*>(gooddata-cli-[^<]*)\.zip<.*/' ) {
		$clzipname = $1;
		print "found actual version: ${clzipname}.\n";
	}
	else {
		print "\n WARN: zipfile has not been found on $clzipurl, fallback to $alternateCLUrl";
		$clzipurl = $alternateCLUrl;
	}

	my $clzip = $clzipname . ".zip";

	#clear before
	system("rm -rf $clzipname");

	# download cltool
	print "Downloading CLI tool from '$clzipurl' ...";
	my $code = getstore( "$clzipurl/$clzip", $clzip );
	die "Unable to download cli tool version $clzip errcode: $code"
	  if $code != 200;
	print "...downloaded.\n";
	die "Zip file does not exists (not downloaded)." unless ( -f "$clzip" );

	# unpack cltool
	print " Unpacking data ... from $clzip\n ";
	system("unzip -q $clzip");

	# return folder where cltool is located
	return "$clzipname";
}

# upload data to gooddata
sub upload_to_secure {
	if ( defined($JOB_URL) ) {
		my $cltool = _get_cl_tool();
		print "Upload data to secure...";
		die "Unable to upload to secure."
		  if system(
"./$cltool/bin/gdi.sh -h secure.gooddata.com -u radek.chromy+hudson\@gooddata.com -p 5up3r74jn3h3510 getQueueLength.script.txt"
		  );
		print "uploaded.\n";
	}
	else {
		print
		  "\$JOB_URL is not defined, upload to secure is not allowed cause of there are not going to be actual data";
	}
}
