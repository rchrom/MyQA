#!/usr/bin/perl	

# Requires Clipboard module 
# sudo cpan Clipboard
# sudo aptitude install xclip

use Clipboard; 

my $file = '/home/radek/.ssh/id_rsa.pub';

open(SSHKEYFILE,  $file) or die "Cannot find file: $file";

my $clip;
while (<SSHKEYFILE>) {
	$clip = $_;
	next if ($clip =~ /^#/);
	chop $clip;
	last;
}
Clipboard->copy("$clip");
