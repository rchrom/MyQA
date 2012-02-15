#!/usr/bin/perl
# Copyright (C) 2007-2011, GoodData(R) Corporation. All rights reserved.

use LWP::UserAgent;
use LWP::Simple;
use HTTP::Request::Common;
use URI;
use XML::Smart;
use strict;
use warnings;

my $HUDSON_ROOT  = 'https://mackenzie.qa.getgooddata.com';

# copy from
my $from = "gdc-auditlog";

my $to = "gdc-cache";
my $branch = "stable-66";


my $xml = get_original($from);

$xml = update_config($xml, $to, $branch);

print $xml->data;
upload_job("$to $branch", $xml);


sub get_original {
    my $job = shift or die;
    print "TODO: Getting: $HUDSON_ROOT/job/$job/config.xml\n";
    
    #XML::Smart->new ("$HUDSON_ROOT/job/$job/config.xml")
    XML::Smart->new ("config.xml")
		or die;
}

sub update_config {
    my $xml = shift or die;
    my $job = shift or die;
    my $branch = shift or die;
   
    my ($project_type) = $xml->nodes_keys;
    
    #traverse and update .... branches.name      
#   $xml->{$project_type}{"scm-property"}{originalValue}{branches}{"hudson.plugins.git.BranchSpec"}{name} = $branch;
	#traverse and update .... uris/.../path
	
	#traverse and update .... description
	$xml->{$project_type}{description} = "Build $job in branch $branch";
   
    return $xml;
}

sub upload_job {
	my $job = shift or die;
	my $xml = shift or die;

	print "Creating $job\n";
	
	my $ua = new LWP::UserAgent;
	# XXX: encode
	my $response = $ua->post ("$HUDSON_ROOT/createItem?name=$job",
		'Content-Type' => 'text/xml',
		Content => $xml->data);
	return unless $response->is_error;
	warn "Could not create a job $job, attempting to update existing";

	$response = $ua->post ("$HUDSON_ROOT/job/$job/config.xml",
		'Content-Type' => 'text/xml',
		Content => $xml->data);
	die $response->content if $response->is_error;

}