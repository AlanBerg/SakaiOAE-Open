#!/usr/bin/perl

# Reads a CSV file with user IDs and passwords, a file of first names, and a file of last names,
# and combines them into CSV rows of "ID,password,firstName,lastName", which can then be
# read by usersfromcsv.pl.

# Added random numbers to add a little chaos for indexing etc + e-mail
$clean=100;
$counter_time=0;
$counter=0;
$first=time;
$range = 100000000;



$file = $ARGV[0];
$first = $ARGV[1];
$last = $ARGV[2];

open (F, $file) || die ("Could not open $file!");
open (FN, $first) || die ("Could not open $first!");
open (LN, $last) || die ("Could not open $last!");

while ($line = <F>)
{
  ($name,$password) = split ',', $line;
  
  $firstName = <FN>;
  if ( ! $firstName ) {
    close(FN);
    open (FN, $first) || die ("Could not open $first!");
    $firstName = <FN>;
  }
  $lastName = <LN>;
  if ( ! $lastName ) {
    close(LN);
    open (LN, $last) || die ("Could not open $last!");
    $lastName = <LN>;
  }
  chomp($firstName);
  chomp($lastName);
  chomp($name);
  chomp($password);
  $firstName =~ s/(\w+)/\u\L$firstName/g;
  $lastName =~ s/(\w+)/\u\L$lastName/g;
  $random_number = int(rand($range));
  print "$name,$password,$firstName,$lastName,$random_number\@email\n";
}


close (F);
close (FN);
close (LN);



