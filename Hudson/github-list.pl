#!/usr/bin/perl
# Copyright (C) 2007-2011, GoodData(R) Corporation. All rights reserved.

use LWP::UserAgent;
use HTTP::Request::Common;
use URI;
use JSON;

use strict;
use warnings;

my $github_root = new URI ('https://api.github.com/');
my $github_ua = new LWP::UserAgent;

$github_ua->default_headers->authorization_basic (
	'osklive-kacatko' => 'da89afafb1de95a156d5dd41de07d831');

# Get list of our private repositories
my $repos = decode_json ($github_ua->request (GET (
	new URI ('orgs/gooddata/repos?type=private')
		->abs ($github_root)))
		->decoded_content);
die 'Failed to list GitHub repositories' unless $repos;

@$repos = sort {$a->{name} cmp $b->{name} } @$repos;

# Create/update a job for each
foreach my $repo (grep { $_->{name} =~ /^gdc-/ } @$repos) {
	
	print($repo->{name}, "  ", $repo->{ssh_url}, "  ",  $repo->{description}, "\n");

}
