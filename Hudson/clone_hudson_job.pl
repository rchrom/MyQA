#!/usr/bin/perl
# Copyright (C) 2007-2011, GoodData(R) Corporation. All rights reserved.

use LWP::UserAgent;

use XML::Smart;
use strict;
use warnings;
use Pod::Usage;
use Getopt::Long qw/:config no_ignore_case/;

#override certification validation
$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;

# parameters (script params)

my $toJob;
my $fromJob = "gdc-auditlog (master)";
my $branch  = "master";
my $user    = "hudson";
my $pass    = "p455w0rd";
my $gitpath;
my $hudson_root = 'https://mackenzie.qa.getgooddata.com';


GetOptions(
	'h|help' => sub { pod2usage( -verbose => 1 ); exit },
	'H|man'  => sub { pod2usage( -verbose => 2 ); exit },
	'f|from=s'     => \$fromJob,
	't|to=s'       => \$toJob,
	'b|branch=s'   => \$branch,
	'u|user=s'     => \$user,
	'p|password=s' => \$pass,
	'hudson=s' => \$hudson_root,
	'git|githubpath=s' => \$gitpath
) or die "Run $0 -h or $0 -H for details on usage";

# check version of hudson die if it does not match the required version.
checkVersion();

die "Job to copy has to be specified!" unless defined($toJob);

$gitpath = "gooddata/${toJob}.git" unless defined($gitpath);


# process
my $xml = get_original($fromJob);
$xml = update_config( $xml, $toJob, $branch );

#$xml->save('config.xml') ;

upload_job("$toJob ($branch)", $xml);


sub checkVersion {
		my $url = "$hudson_root";
		my $ua = new LWP::UserAgent;
		$ua->default_headers->authorization_basic( "$user" => "$pass" );
		my $response = $ua->get("$url");
		my $version = $response->header("x-hudson");
		die "Version ($version) is not supported. Requires version at least 2.2 " unless ($version =~ /^2.[2-9]/);		
}

sub get_original {
	my $job = shift or die;
	my $url = "$hudson_root/job/$job/config.xml";

	my $ua = new LWP::UserAgent;
	$ua->default_headers->authorization_basic( "$user" => "$pass" );
	print "Getting: $url\n";
	my $response = $ua->get("$url");
	die "Error at $url\n ", $response->status_line, "\n Aborting"
	  if $response->is_error;
	open( OUTFILE, ">", "config.xml" );
	print OUTFILE $response->content;
	close(OUTFILE);
	my $xml = XML::Smart->new("config.xml") or die "Unable to parse config file";

	unlink("config.xml");
	return $xml;
}

sub update_config {
	my $xml    = shift or die;
	my $job    = shift or die;
	my $branch = shift or die;

	# set Description
	$xml->{project}{description} = "Build $job in branch $branch. (Created by $user).";

	my $entries   = $xml->{project}{"project-properties"};
	my $lastEntry = $entries->{entry}[-1]{string};

	# set Branch name
	my $scmEntryName = "";

	# find scm entry node index
	my $index = -1;
	while ( !( $scmEntryName eq $lastEntry ) ) {

		$scmEntryName = $entries->{entry}[ ++$index ]{string};
		last if ( $scmEntryName eq "scm" );
	}
	die "SCM Entry has not been found in job configuration" if ( $scmEntryName eq $lastEntry );

	my $scmEntry = $entries->{entry}[$index];

	# set branch
	$scmEntry->{"scm-property"}{"originalValue"}{"branches"}{"hudson.plugins.git.BranchSpec"}{"name"} = "$branch";
	$scmEntry->{"scm-property"}{"originalValue"}{"remoteRepositories"}{"RemoteConfig"}{"uris"}
	  {"org.eclipse.jgit.transport.URIish"}{"path"} = "gooddata/${job}.git";
	return $xml;
}

sub upload_job {
	my $job = shift or die;
	my $xml = shift or die;

	my $ua = new LWP::UserAgent;
	$ua->default_headers->authorization_basic( "$user" => "$pass" );

	print "Creating $job\n";

	my $response = $ua->post(
		"$hudson_root/createItem?name=$job",
		'Content-Type' => 'text/xml',
		Content        => $xml->data
	);
	return unless $response->is_error;
	warn "Could not create a job $job, attempting to update existing";

	$response = $ua->post(
		"$hudson_root/job/$job/config.xml",
		'Content-Type' => 'text/xml',
		Content        => $xml->data
	);
	die "Could not create a job $job\n ", $response->status_line, "\n Aborting."
	  if $response->is_error;
}

__END__

=head1 NAME

  clone_hudosn_job.pl - Clone Hudson job
    
=head1 SYNOPSIS

  clone_hudson_job.pl -t <job> [options] 

  Options:
    -help            brief help message
    -man             full documentation
    -t|to            Job to be created
    -f|from          Template fro the new job
    -b|branch        Branch definition for the new job
    -u|user          Username to access Hudson
    -p|password      Password to access Hudson
	-hudson			 Hudson URL
=head1 DESCRIPTION
    
    The main purpose is to clone hudson jobs.
=cut
