#!/usr/bin/perl

# This is an error.log parser
#
# UNDER CONSTRUCTION
#
# 1) It provides summaries of response times
# This is useful for setting scaling factors in
# performance analysis.
#
# 2) The report can be connected up to Jenkins to cause
# failure and notify developers to clean up issues
#
# 3) It gives you a rough overview of the performance of your
# system without having to log through Apache
#
# Optional commands:
# --startline= Line First line in error log to parse
# --errorfile= Location of errorfile to pass. Overrides the configuration file setting.
# --errordir= Directory where multiple error files are kept. The script will review them all
# --warn=Warn level in ms (default 100 ms)
# --error=Error level in ms (default 4000 ms)
# --dumpfile= Location to dump lines that are passed the ERROR threshold
# --ignore_dump= Dont dump log lines.
#
# Example opts for parsing a dir
# -errordir=/media/OS/Downloads/all/  -dumpfile=/media/OS/Downloads/4_seconds.txt
#
# Example opts for parsing a file
# -errorfile=/media/OS/Downloads/all/error1/error.log
#
# For Questions:
# Alan Berg - a.m.berg AT uva.nl

use File::Find;      # Recursing directories to find files
use Getopt::Long;    # Command line parsing

my $start = time;
my %globals;
my %mime;
my %status;
my %type;
my %action;
my %hour;
my %hour_repsonse;
my %error_hour;
my %warn_hour;
my $response_mime;
my $response_action;

# Location of one error file
# Useful for Running from Jenkins and picking up a time stamped error file
my $errorfile = 0;

# Location of directory with error logs
# Useful for Parsing an archive of log files.
# @TODO Consider parsing .gz files as well
my $errordir = 0;

# Where to start parsing in error log.
# Useful for bug bashes where you want to take a line count before the bash (wc -l)
# And then run the parser by hand arfterwards
my $startline = 0;

# Default warn and error levels
my $warn_level  = 100;
my $error_level = 4000;

# Default location for Dump file
my $dump_file = "all_error.txt";
my $no_dump   = 0;

# TODO Write Commandline help option
GetOptions(
	"errordir=s"    => \$errordir,
	"errorfile=s"   => \$errorfile,
	"startline=i"   => \$startline,
	"warn=i"        => \$warn_level,
	"error=i"       => \$error_level,
	"dumpfile=s"    => \$dump_file,
	"ignore_dump=i" => \$no_dump
);

unless ($no_dump) {
	open( DUMP, ">$dump_file" )
	  || die "Unable to open ERROR DUMP \n";
}
# @TODO consider factoring out into Perl Module
# Either you can point at a file or a directory to parse from the commandline, but not both at the same time
if ( ($errorfile) && ($errordir) ) {
	print
"You can only use one of the two options errorfile for a file to process or errordir for a directory to process\n";
	print "Please remove one of the options\n\n";
	exit();
}
elsif ($errorfile) {
	# Process one file
	process_one_file($errorfile);
}
elsif ($errordir) {
	if ( -d $errordir ) {    # Basic sanity check. A dir is a dir
		                     # Act on all the error files found in the errordir
		find( \&act_on_all_logs, $errordir );
	}
	else {
		print "Error directory $errordir is not a directory - Not searching\n";
		exit();
	}
}

# OK lets print out the counters in a human readable format.
print_report();

### SUBROUTINES
#

# Run through all the files in a directory with error.log but not with .gz
sub act_on_all_logs {
	if ( ( $File::Find::name =~ /error\.log/ )
		&& !( $File::Find::name =~ /\.gz/ ) )
	{
		process_one_file($File::Find::name);
	}
}

# Print a primitive report
sub print_report {
	my $elapsed = time - $start;
	print "Report about Response times of SakaiOAE\nGenerated at "
	  . localtime(time) . "\n\n";
	print "Time taken=$elapsed (S)\n";
	print "Number of files processed: $globals{'processed'}\n";
	if ( $elapsed > 0 ) {
		print "Lines per second = "
		  . int( $globals{"total_lines"} / $elapsed ) . "\n\n";
	}
	else {
		print "\n";
	}

	# Print totals
	print "SUMMARY INFORMATION\n";
	print "\tTotal Response time in Log: $globals{'total_time'}(ms)\n";
	print "\tTotal Lines parsed: $globals{'total_lines'}\n";
	print "\tLines with time information: $globals{'hits'}\n";

	if ( $mime{'text/html'} > 0 ) {
		$ratio = $mime{'application/json'} / $mime{'text/html'};
		printf "\tAverage Number of JSON requests per HTML request: %5.2f\n",
		  $ratio;
	}
	my $average = 0;
	if ( $globals{'hits'} > 0 ) {
		$average = int( $globals{'total_time'} / $globals{'hits'} );
	}
	print "\tAverage Response time: $average (ms)\n";
	if ( $globals{'server_error'} ) {
		print
"\tNumber of Server Errors with Response times: $globals{'server_error'}\n";
	}
	else {
		print "\tNumber of Server Errors with Response times: 0\n";
	}
	print
"\tNumber of Client Errors with Response times: $globals{'client_error'}\n";
	print "SETTINGS\n";
	print "\tLimit for Error: $error_level (ms)\n";
	print "\tLimit for Warning: $warn_level (ms)\n";
	unless ($no_dump) {
		print "\tLocation of lines exceeding limits: $dump_file\n";
	}

	print "\nHOUR OF DAY INFORMATION\n\n";
	print "Hour,Hits,Errors,Warns,Total_Response_time_ms,Average_ms\n";

	# Print Hour report
	for $hour ( sort { lc $a cmp lc $b } ( keys %hour ) ) {
		unless ( defined $error_hour{$hour} ) {
			$error_hour{$hour} = '0';
		}
		unless ( defined $warn_hour{$hour} ) {
			$warn_hour{$hour} = '0';
		}
		if ( $hour{$hour} > 0 ) {
			$average = int( $hour_response{$hour} / $hour{$hour} );
		}
		print
"$hour,$hour{$hour},$error_hour{$hour},$warn_hour{$hour},$hour_response{$hour},$average\n";
	}
	print "\nLOG LEVEL\n";
	for $level ( sort ( keys %type ) ) {
		print "$level,$type{$level}\n";
	}

	print "\nMime Type\n\n";
	print "Mime_type,Hits,Total_response_time_ms,Average_ms\n";
	for $mime ( sort ( keys %mime ) ) {
		if ( $mime{$mime} > 0 ) {
			$average = int( $response_mime{$mime} / $mime{$mime} );
			print "$mime,$mime{$mime},$response_mime{$mime},$average\n";
		}
	}

	print "\nStatus Type\n";
	for $status ( sort ( keys %status ) ) {
		print "$status,$status{$status}\n";
	}

	print "\nACTION Type\n\n";
	print "Action,Hits,Total_response_time_ms,Averge_ms\n";
	for $action ( sort ( keys %action ) ) {
		if ( $action{$action} > 0 ) {
			$average = int( $response_action{$action} / $action{$action} );
			print
			  "$action,$action{$action},$response_action{$action},$average\n";
		}
	}

}

# Process one file
sub process_one_file {
	my ($errfile) = @_;
	$globals{'processed'}++;
	$globals{'last_line'} = '';
	print "Processing: $errfile";
	open( LOG, $errfile )
	  || die "Unable to open error log $errfile";

	# process_one_file Loop for processing line in the file
	my $line_counter = 0;
	while ( $line = <LOG> ) {
		if ( $line_counter++ < $startline ) { next; }
		parse_line( $line, $warn_level, $error_level, $errfile, $line_counter );
	}
	close(LOG);
	print " ==> Line Count: $line_counter\n";
}

# Parse one line of log file
#
# Example log line
#18.05.2012 08:35:14.123 *INFO* [10.52.9.20 [1337355314117]
#GET /devwidgets/newaddcontent/images/newaddcontent_everything_icon.png HTTP/1.1]
#logs/request.log 18/May/2012:08:35:14 -0700 [24710] <- 200 image/png 6ms
sub parse_line {
	my ( $myline, $mywarn, $myerr, $file, $line_counter ) = @_;

	# Global line count
	$globals{'total_lines'}++;

	# Return early before costing heavy processing
	unless ( $line =~ /<-/ ) {
		$globals{'last_line'} = $line;
		return 0;
	}

	# OK, lets get down to work
	if ( $myline =~
/ (\d\d:\d\d:\d\d\.\d\d\d) \*(\w*)\* \[[\d|\.]* \[\d*\] (\w*) (.*) HTTP\/.*] (.*) (.*) (.*) \[\d*] <- (\d*) (.*) (\d*)ms/g
	  )
	{
		$globals{'hits'}++;
		my $time     = $1;
		my $type     = $2;
		my $action   = $3;
		my $uri      = $4;
		my $v5       = $5;
		my $date     = $6;
		my $offset   = $7;
		my $status   = $8;
		my $mime     = $9;
		my $response = $10;

		$date =~ /:(\d\d):(\d\d):(\d\d)/;
		$hour = $1;
		$type{$type}++;
		$action{$action}++;
		$response_action{$action} += $response;
		$mime{$mime}++;
		$response_mime{$mime} += $response;
		$status{$status}++;

		if ( ( $status >= 400 ) && ( $status < 500 ) ) {
			$globals{'client_error'}++;
		}
		if ( $status >= 500 ) {
			$globals{'server_error'}++;
		}

		$hour{$hour}++;
		$hour_response{$hour}  += $response;
		$globals{'total_time'} += $response;

		if ( $response >= $myerr ) {
			$globals{'error_counter'}++;
			$globals{'error_response'} += $response;
			$error_hour{$hour}++;
			unless ($no_dump) {
				print DUMP"\n$file [$line_counter]\n$globals{'last_line'}";
				print DUMP $line;
			}
		}
		elsif ( $response >= $mywarn ) {

			# Warn data
			$globals{'warn_counter'}++;
			$globals{'warn_response'} += $response;
			$warn_hour{$hour}++;
		}
		$globals{'last_line'} = $line;
		return 1;
	}
}