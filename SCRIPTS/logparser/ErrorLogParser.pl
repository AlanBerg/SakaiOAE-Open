#!/usr/bin/perl

# This is an error log parser.
#
# Optional commands:
# --config= Location of configuration file (falls back to config.yml)
# --startline= Line First line in error log to parse
# --ignore_info= Set to 1 to ignore the info level. This level has the most noise
# --ignore_unknown= Set to 1 to ignore the Warn level which contains a lot of noise
# --errordir= Location of directory containing log files. Overrides the configuration file setting.
# --errorfile= Location of errorfile to pass. Overrides the configuration file setting.
# --add_date= Set to 1 if you want a date stamp added at the end of file names
# --debug= Set to 1 to get extra debug information

# The error log is a mixture of different logging information types
# The aim of this parser is to make a concise report from the log
# using whitelisting of known defects are generic summaries.
#
# In Linux to install the YAML module:
# sudo apt-get install libconfig-yaml-perl
#
# Use of the command line options supports using Jenkins or processing
# whole directories of log files.
#
# For Questions:
# Alan Berg - a.m.berg AT uva.nl

use YAML;            # YAML configuration
use File::Find;      # Recursing directories to find files
use Getopt::Long;    # Commandline parsing

my $start = time;

# Some counters for a later version of the parser
# Dont like global variables so at least placing them in a hash
my %global_counters;
$global_counters{"dirty"}       = 0;
$global_counters{"total_lines"} = 0;
my %global_types;
my $global_slow    = "";
my $global_unknown = "";

# String to keep results to printout to screen and HTML
my $pre_string = "";

# Default values for command line options
# Location of configuration file- Fall back to file.
my $file = "config.yml";

# Where to start parsing in error log.
# Useful for bug bashes where you want to take a line count before the bash (wc -l)
# And then run the parser by hand arfterwards
my $startline = 0;

# Location of one error file
# Useful for Running from Jenkins and picking up a time stamped error file
my $errorfile = 0;

# Location of directory with error logs
# Useful for Parsing an archive of log files.
# @TODO Consider parsing .gz files as well
my $errordir = 0;

# There are a lot of rules at INFO and UNKNOWN level
# Consider ignoring so we dont have to keep them up to date.
my $ignoreInfo    = 0;
my $ignoreUnknown = 0;

# Used during debugging to discover unmet patterns
# Do not overwrite uncaught file
my $nowrite_uncaught = 0;

# Decide if to print a date stamp at end of filenames.
# Remember this is the date of parsing not the date of the error file.
my $hasStamp = 0;

my $debug = 0;

# TODO Write Commandline help option
GetOptions(
	"config=s"           => \$file,
	"ignore_info=i"      => \$ignoreInfo,
	"ignore_unknown=i"   => \$ignoreUnknown,
	"errordir=s"         => \$errordir,
	"errorfile=s"        => \$errorfile,
	"startline=i"        => \$startline,
	"nowrite_uncaught=i" => \$nowrite_uncaught,
	"add_date=i"         => \$hasStamp,
	"debug=i"            =>,
	\$debug
);

# Load in configuration
open my $fh, '<', $file or die "can't open config file: $file";
my $yml = do { local $/; <$fh> };
my $config = Load($yml);

my $timestamp = "";
if ($hasStamp) {
	$timestamp = "." . stamp();
}

# Open Files that relevant data is going to be split
# Also a cheap man's sanity check of the configuration file
open( SLOW, ">$config->{OUTPUT_FILES}{SLOW}$timestamp" )
  || die
  "Unable to open HTML summary $config->{OUTPUT_FILES}{SLOW}$timestamp\n";
unless ($nowrite_uncaught) {
	open( DUMP, ">$config->{OUTPUT_FILES}{UNCAUGHT}$timestamp" )
	  || die
"Unable to open HTML summary $config->{OUTPUT_FILES}{UNCAUGHT}$timestamp\n";
}
open( URGENT, ">$config->{OUTPUT_FILES}{URGENT}$timestamp" )
  || die
  "Unable to open HTML summary $config->{OUTPUT_FILES}{URGENT}$timestamp\n";

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
else {

	# If no relevant commandline option fall back to configuration file
	process_one_file( $config->{INPUT_FILES}{ERROR_LOG} );
}

# Output results
# Perl is great for getting work done. However, reducing lines of code
# Sometimes decreases readabilty
$pre_string .=
  "Number of lines parsed: " . $global_counters{"total_lines"} . "\n";
my $elapsed = time - $start;
$pre_string .= "Time taken=$elapsed (S)\n";
if ( $elapsed > 0 ) {
	$pre_string .= "Lines per second = "
	  . int( $global_counters{"total_lines"} / $elapsed ) . "\n";
}

foreach $type ( sort( keys %global_types ) ) {
	$local_counter = $global_types{$type};
	$pre_string .= "\n\n$type: $global_types{$type}\n";

	$pre_string .= "Urgent Patterns:\n";

# sort keys (bug patterns) in a case insensitive alphetical manner, making the report easier to read.
	for $rule ( sort { lc $a cmp lc $b }
		( keys %{ $config->{ 'URGENT_' . $type } } ) )
	{
		if ( $config->{ 'URGENT_' . $type }{$rule} ) {
			$pre_string .= "\t$rule: $config->{'URGENT_' . $type }{$rule}\n";
			$local_counter -= $config->{ 'URGENT_' . $type }{$rule};
		}
	}
	$pre_string .= "Patterns to Ignore:\n";
	for $rule ( sort { lc $a cmp lc $b }
		( keys %{ $config->{ 'IGNORE_' . $type } } ) )
	{
		if ( $config->{ 'IGNORE_' . $type }{$rule} ) {
			$pre_string .= "\t$rule: $config->{'IGNORE_' . $type }{$rule}\n";
			$local_counter -= $config->{ 'IGNORE_' . $type }{$rule};
		}
	}

	# Only an estimate, so lets not waste console space
	#$pre_string .= "Uncounted: $local_counter\n\n";
}
$pre_string .=
  "\n\nNumber of lines that are still untainted: $global_counters{'dirty'}\n";
$pre_string .= "See: $config->{OUTPUT_FILES}{UNCAUGHT}\n\n";
$pre_string .= "Slow query file: $config->{OUTPUT_FILES}{SLOW}\n";
$pre_string .= "Urgent query file: $config->{OUTPUT_FILES}{URGENT}\n";

print $pre_string;
sendToHTML($pre_string);

#
###END process_one_file

### SUBROUTINES
#

# Process one file
sub process_one_file {
	my ($errfile) = @_;
	print "Processing: $errfile";
	open( LOG, $errfile )
	  || die "Unable to open error log $errfile\n";

	# process_one_file Loop for processing Log file
	my $line_counter = 0;
	while ( $line = <LOG> ) {
		if ( $line_counter++ < $startline ) { next; }
		parse_types($line);
	}
	close(LOG);
	print " ==> Line Count: $line_counter\n";
	$global_counters{"total_lines"} += $line_counter;
}

# Run through all the files in a directory with error.log but not with .gz
sub act_on_all_logs {
	if ( ( $File::Find::name =~ /error\.log/ )
		&& !( $File::Find::name =~ /\.gz/ ) )
	{
		process_one_file($File::Find::name);
	}
}

# Make an HTML file.
# $pre_string is a global variable. Should pass to ease refactoring later
# TODO Consider outputing summary in machine readable format
# Such as XML or CSV
# TODO Very primitive, but if there is demand then we can beautify.
sub sendToHTML {
	open( HTML, ">$config->{OUTPUT_FILES}{SUMMARY_HTML}$timestamp" )
	  || die
"Unable to open HTML summary $config->{OUTPUT_FILES}{SUMMARY_HTML}$timestamp\n";
	print HTML header() . $pre_string . footer();
}

# Choose log level or if does not follow expected structure
# such as stack traces then place in unknown catagory.
sub parse_types {
	my ($line) = @_;
	if ( $line =~ / \*(\w*)\* / ) {
		my $type = $1;
		if ( ($ignoreInfo) && ( $type eq 'INFO' ) ) {

			#IGNORE INFO
		}
		else {
			$global_types{$type}++;
			parse( $type, $line );
		}
	}
	else {
		unless ($ignoreUnknown) {
			$global_types{'UNKNOWN'}++;
			parse( 'UNKNOWN', $line );
		}
	}
}

# Do the Parsing of each line iterating through each filter in the configuration file
# There are currently six sets of filter depending on log level
# Slow errors for ERROR and WARN level are filtered out to a file.
sub parse {
	my ( $ruleset, $line ) = @_;
	my $flag = 0;

	# Check all ignore rules for a given log level defined by $ruleset
	for $rule ( keys %{ $config->{ 'IGNORE_' . $ruleset } } ) {
		if ( $line =~ /$rule/ ) {
			$config->{ 'IGNORE_' . $ruleset }{$rule}++;
			$flag = 1;
		}
	}

	# Check all urgent rules for a given log level defined by $ruleset
	for $rule ( keys %{ $config->{ 'URGENT_' . $ruleset } } ) {
		if ( $line =~ /$rule/ ) {
			$config->{ 'URGENT_' . $ruleset }{$rule}++;
			print URGENT $line;
			$flag = 1;
		}
	}

	# TODO: Consolidate next two if statements
	# Should iterate and make into a set of rules
	if (   ( $line =~ /$config->{'SLOW_ERROR'}/ )
		|| ( $line =~ /$config->{'SLOW_ERROR_SOLR'}/ ) )
	{
		$config->{ 'IGNORE_' . $ruleset }{'SLOW QUERIES'}++;
		print SLOW "[$1 ms][$ruleset] $2\n";
		$flag = 1;
	}

	if (   ( $line =~ /$config->{'SLOW_WARN'}/ )
		|| ( $line =~ /$config->{'SLOW_WARN_SOLR'}/ ) )
	{
		$config->{ 'IGNORE_' . $ruleset }{'SLOW QUERIES'}++;
		print SLOW "[$1 ms][$ruleset] $2\n";
		$flag = 1;
	}

	unless ($flag) {
		unless ($nowrite_uncaught) {
			print DUMP "$line";
		}
	}

	# Debug information to discover rules
	unless ($flag) {

		# Debug line uncomment to enable
		if ($debug) {
			if ( $ruleset eq 'ERROR' ) { print "$line"; }
			if ( $ruleset eq 'WARN' )  { print "$line"; }
		}
		$global_counters{'dirty'}++;
	}
	return $flag;
}

# Header string for printing an HTML file
# Can also pull in yet another file. Start simple.
sub header {

#my $time = localtime(time);
#my $h2 = "<h2>$config->{HTML}{TITLE}</h2>\n<h3>Report Generated: $time</h3>\n";
#return "<html><head><title>Exception Report</title></head>\n<body>\n$h2 <pre>\n\n";
	return "";
}

# Footer string for printing an HTML file.
sub footer {

	#return "</pre></body></html>";
	return "";
}

# Timestamp
sub stamp {
	my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
	  localtime;
	$year += 1900;
	$mon  += 1;
	return sprintf "%04d-%02d-%02d", $year, $mon, $mday;
}
