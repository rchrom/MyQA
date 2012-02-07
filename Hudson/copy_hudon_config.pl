#!/usr/bin/perl

use strict;
use File::Copy;

######################################
# Hudson configuration sources
my $hudson_dir="/var/lib/hudson";

# Destination folder where to copy configuraiton 
my $outputdir="/tmp/ra";

#############################################

my $hudson_jobs_dir="$hudson_dir/jobs";
my $file;
my $config="config.xml";

mkdir $outputdir;

# copy config.xml file from directory into directory
sub copyconfig {
	my $fromdir = shift;
	my $todir = shift;
	
	return unless -f "$fromdir/$config";
	
	mkdir ($todir);
	copy("$fromdir/$config",$todir) or die "File cannod be copied $fromdir/$config";
}



opendir ( DIR, $hudson_jobs_dir) || die "Error in openning dir $hudson_jobs_dir \n";

copyconfig($hudson_dir,$outputdir);

while ($file = readdir(DIR)){
	# skip .* and files
	next if grep { /^\./ || -f "$hudson_jobs_dir/$file"} $file ; 
	print $file."\n";
	#  copy config file per job
	copyconfig ("$hudson_jobs_dir/$file","$outputdir/$file");
}
closedir DIR;




