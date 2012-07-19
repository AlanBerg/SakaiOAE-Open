#!/usr/bin/perl
# Get a search term from lines in the error log
open(TMP,'search.txt') || die;
while($line=<TMP>){
	if ($line=~/general.json\?q=(.*)\&sortOn/){
		print "$1\n";
	}else{
		#ignore
	}
}
