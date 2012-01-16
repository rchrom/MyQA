use XML::LibXML::Reader;
use strict;

my $hudson_dir    = "hudson";
my $hudson_config = "$hudson_dir/config.xml";

my @slaves;
my @jobs;

parseHudsonConfig($hudson_config);

#print "Number of jobs: $#jobs \n";
#print "Number of slaves: $#slaves \n";
#genSlavesTable(@slaves);
#exit ;

my $jobsConfig = {};
foreach my $job (@jobs) {
	$jobsConfig->{$job}->{"job.name"} = $job;
	parseJobConfig( $hudson_dir, $job);
}
genJobsTable($jobsConfig);

########################################################

sub genSlavesTable {
	print "||hostname||Build Executor||Description||Executors count||Label||\n";
	foreach my $hash (@_) {
		print "|".$hash->{"host"} . "|"
		  . $hash->{"name"} . "|"
		  . $hash->{"desc"} . "|"
		  . $hash->{"executors"} . "|"
		  . $hash->{"label"} ."|\n";
	}
}

######################################################

sub genJobsTable {
	my $hashref = shift;
	my @keys    = keys %$hashref;
	print "||Job Name||Description||SCM Source||SCM URL||Branch||Job Command||\n"
	  ;
	foreach (@keys) {
		my $hash = $hashref->{$_};
		print "|", $hash->{"job.name"}, "|", $hash->{"desc"}?$hash->{"desc"}:'-', "|",
		  $hash->{"scm.source"}?$hash->{"scm.source"}:'-', "|", $hash->{"scm.url"}?$hash->{"scm.url"}:'-', "|",
		  $hash->{"scm.branch"}?$hash->{"scm.branch"}:'-', "|", $hash->{"command"}?$hash->{"command"}:'-', "|\n";
	}
}

######################################################

sub parseJobConfig {
	( my $hudson_dir, my $job ) = @_;

	my $jobConfigFile = "$hudson_dir/$job/config.xml";

	die "Configuration file not found for job: $job" unless -f $jobConfigFile;

	my $reader = XML::LibXML::Reader->new( location => "$jobConfigFile" )
	  or die "cannot read $jobConfigFile\n";
	my $config = $jobsConfig->{$job};
	$jobsConfig->{$job}->{"job.name"} = $job;

	while ( $reader->read ) {
		if (   $reader->name eq 'properties'
			&& $reader->nodeType == XML_READER_TYPE_ELEMENT )
		{

			# skip properties
			until (  $reader->name eq 'properties'
				  && $reader->nodeType == XML_READER_TYPE_END_ELEMENT )
			{
				last if ( $reader->nodeType eq 0 );
				$reader->read;
			}

		}
		$jobsConfig->{$job}->{"scm.url"} = getNodeValue($reader)
		  if ( ( $reader->name eq 'url' )
			&& ( $reader->nodeType == XML_READER_TYPE_ELEMENT ) );

		$jobsConfig->{$job}->{"scm.source"} = getNodeValue($reader)
		  if ( ( $reader->name eq 'source' )
			&& ( $reader->nodeType == XML_READER_TYPE_ELEMENT ) );

		$jobsConfig->{$job}->{"scm.branch"} = getNodeValue($reader)
		  if ( ( $reader->name eq 'branch' )
			&& ( $reader->nodeType == XML_READER_TYPE_ELEMENT ) );

		  if ( ( $reader->name eq 'command' )
			&& ( $reader->nodeType == XML_READER_TYPE_ELEMENT ) ) {
				my $command = getNodeValue($reader);
				$command =~ s/\n/\\\\\n /g;
				$command =~ s/\|/\\\|/g;
				$jobsConfig->{$job}->{"command"} = $command;
			};

		 if ( ( $reader->name eq 'description' )
			&& ( $reader->nodeType == XML_READER_TYPE_ELEMENT ) ){
				my $desc = getNodeValue($reader);
				$desc =~ s/\n/\\\\\n /g;
				$desc =~ s/\|/\\\|/g;
				$jobsConfig->{$job}->{"desc"} = $desc;
			};
	}
}


##############################################

sub parseHudsonConfig {
	my $xmlfile = shift;
	my $reader = XML::LibXML::Reader->new( location => "$xmlfile" )
	  or die "Cannot read $xmlfile\n";

	while ( $reader->read ) {
		processSlave($reader)
		  if ( ( $reader->name eq 'slave' )
			&& ( $reader->nodeType == XML_READER_TYPE_ELEMENT ) );
		processView($reader)
		  if ( ( $reader->name eq 'views' )
			&& ( $reader->nodeType == XML_READER_TYPE_ELEMENT ) );

	}
	{    # uniq job names
		my %hash;
		for (@jobs) {
			$hash{$_} = 1;
		}
		@jobs = keys(%hash);
	}
}

##############################################

sub processSlave {
	my $slaveName, my $slaveDesc, my $slaveExecutors, my $slaveLabel,
	  my $slaveHost;

	my $reader = shift;

	# skip all before slaves
	while (
		$reader->read
		&& !(
			   ( $reader->name eq 'slave' )
			&& ( $reader->nodeType == XML_READER_TYPE_END_ELEMENT )
		)
	  )
	{
		if (   ( $reader->name eq 'name' )
			&& ( $reader->nodeType == XML_READER_TYPE_ELEMENT ) )
		{
			$slaveName = getNodeValue($reader);
		}
		if (   ( $reader->name eq 'description' )
			&& ( $reader->nodeType == XML_READER_TYPE_ELEMENT ) )
		{
			$slaveDesc = getNodeValue($reader);
		}
		if (   ( $reader->name eq 'numExecutors' )
			&& ( $reader->nodeType == XML_READER_TYPE_ELEMENT ) )
		{
			$slaveExecutors = getNodeValue($reader);
		}
		if (   ( $reader->name eq 'label' )
			&& ( $reader->nodeType == XML_READER_TYPE_ELEMENT ) )
		{
			$slaveLabel = getNodeValue($reader);
		}
		if (   ( $reader->name eq 'host' )
			&& ( $reader->nodeType == XML_READER_TYPE_ELEMENT ) )
		{
			$slaveHost = getNodeValue($reader);
		}
	}
	push(
		@slaves,
		{
			"name"      => $slaveName,
			"desc"      => $slaveDesc,
			"executors" => $slaveExecutors,
			"label"     => $slaveLabel,
			"host"      => $slaveHost
		}
	);
}

##############################################

sub processView {
	my $reader = shift;
	while (
		( $reader->read )
		&& !(
			   ( $reader->name eq 'views' )
			&& ( $reader->nodeType == XML_READER_TYPE_END_ELEMENT )
		)
	  )
	{
		push( @jobs, getNodeValue($reader) )
		  if ( ( $reader->name eq 'string' )
			&& ( $reader->nodeType == XML_READER_TYPE_ELEMENT ) );
	}
}

##############################################

sub getNodeValue {

	my $reader = shift;
	$reader->read;
	my $retval = $reader->value;
	$reader->read;
	$retval;
}
