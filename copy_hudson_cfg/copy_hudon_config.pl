use strict;
use File::Copy;

my $hudson_dir="/var/lib/hudson";
my $hudson_jobs_dir="$hudson_dir/jobs";
my $file;
my $outputdir="/tmp/ra";

mkdir $outputdir;


my $config="config.xml";

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
	copyconfig ("$hudson_jobs_dir/$file","$outputdir/$file");
}
closedir DIR;




