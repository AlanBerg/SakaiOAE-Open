#!/usr/bin/perl
use File::Find;
#use strict; # OK when I have time

# Makes a list of java files
# Then does the easy quick win static bugs
# Tested only on Linux
# Feb 4 2008
# Last modified: May 2008
#
# Contact Alan Berg: a.m.berg@uva.nl

# Can Change
my $src="/home/alan/SAKIOAE/GIT/3akai-ux";
my $size=length($src);
$counter=1;
find(\&list_java, $src);


sub list_java{
if ($File::Find::name=~/\.html$/){
  my $lf=substr($File::Find::name,$size);
  print "$counter,$lf\n";
  $counter++;
}
}
