#!/usr/bin/perl	

# Requires Clipboard module 
# sudo cpan Clipboard
# sudo aptitude install xclip

#use Clipboard; 
use Env HOME;
use strict;

my $file = "$HOME/.ssh/id_rsa.pub";

open(SSHKEYFILE,  $file) or die "Cannot find file: $file";

my $clip;
while (<SSHKEYFILE>) {
	$clip = $_;
	next if ($clip =~ /^#/);
	chop $clip;
	last;
	
}
#print $clip;
exec "echo $clip | xclip -selection c";
#Clipboard->copy("$clip");
