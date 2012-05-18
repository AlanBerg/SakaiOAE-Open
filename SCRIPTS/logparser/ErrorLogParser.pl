#!/usr/bin/perl

# This is an error log parser
#
# Optional commands:
# --config=location of configuration file
# --startline=Line First line in error log to parse
#
# The error log is a mixture of different logging information types
# The aim of this parser is to make a concise report from the log
# using whitelisting of known defects are generic summaries
#
# In Linux to install the YAML module:
# sudo apt-get install libconfig-yaml-perl
#
# For Questions:
# Alan Berg - a.m.berg AT uva.nl

use YAML;    # YAML configuration
use File::Find;
use Getopt::Long;

# Some counters for a later version of the parser
# Dont like global variables so at least placing them in a hash
my %global_counters;
my %global_types;
my $global_slow    = "";
my $global_unknown = "";

# String to keep results to printout to screen and HTML
my $pre_string     = ""; 

# Location of configuration fie- Fall back to file.
my $file      = "config.yml";    
my $startline = 0;
GetOptions( "config=s" => \$file, "startline=i" => \$startline );

# Load in configuration
open my $fh, '<', $file or die "can't open config file: $file";
my $yml = do { local $/; <$fh> };
my $config = Load($yml);


open( LOG, $config->{INPUT_FILES}{ERROR_LOG} )
  || die "Unable to open error log $config->{INPUT_FILES}{ERROR_LOG}\n";

# Open Files that relevant data is going to be split
# Also a cheap man's sanity check of the configuration file
open( SLOW, ">$config->{OUTPUT_FILES}{SLOW}" )
  || die "Unable to open HTML summary $config->{OUTPUT_FILES}{SLOW}\n";
open( DUMP, ">$config->{OUTPUT_FILES}{UNCAUGHT}" )
  || die "Unable to open HTML summary $config->{OUTPUT_FILES}{UNCAUGHT}\n";
open( URGENT, ">$config->{OUTPUT_FILES}{URGENT}" )
  || die "Unable to open HTML summary $config->{OUTPUT_FILES}{URGENT}\n";

# MAIN Loop for processing Log file
my $line_counter = 0;
while ( $line = <LOG> ) {
	if ( $line_counter++ < $startline ) { next; }
	parse_types($line);
}

# Output results
# Perl is great for getting work done. However, reducing lines of code
# Sometimes decreases readabilty
foreach $type ( keys %global_types ) {
	$local_counter = $global_types{$type};
	$pre_string .= "$type: $global_types{$type}\n";
	$pre_string .= "Urgent Patterns:\n";
	for $rule ( keys %{ $config->{ 'URGENT_' . $type } } ) {
		if ( $config->{ 'URGENT_' . $type }{$rule} ) {
			$pre_string .= "\t$rule: $config->{'URGENT_' . $type }{$rule}\n";
			$local_counter -= $config->{ 'URGENT_' . $type }{$rule};
		}
	}
	$pre_string .= "Patterns to Ignore:\n";
	for $rule ( keys %{ $config->{ 'IGNORE_' . $type } } ) {
		if ( $config->{ 'IGNORE_' . $type }{$rule} ) {
			$pre_string .= "\t$rule: $config->{'IGNORE_' . $type }{$rule}\n";
			$local_counter -= $config->{ 'IGNORE_' . $type }{$rule};
		}
	}
	$pre_string .= "Uncounted: $local_counter\n\n";
}
$pre_string.="Number of lines that are still untainted: $global_counters{'dirty'}\n";
$pre_string.="See: $config->{OUTPUT_FILES}{UNCAUGHT}\n\n";
$pre_string.="Slow query file: $config->{OUTPUT_FILES}{SLOW}\n";
$pre_string.="Lines considered urgent: $config->{OUTPUT_FILES}{URGENT}\n";

print $pre_string;
sendToHTML($pre_string);
#
###END MAIN

### SUBROUTINES
#

# Make an HTML file.
# $pre_string is a global variable. Should pass to ease refactoring later
# TODO Consider outputing summary in machine readable format
# Such as XML or CSV
# TODO Very primitive, but if there is demand then we can beautify.
sub sendToHTML {
	open( HTML, ">$config->{OUTPUT_FILES}{SUMMARY_HTML}" )
	  || die
	  "Unable to open HTML summary $config->{OUTPUT_FILES}{SUMMARY_HTML}\n";
	print HTML header() . $pre_string . footer();
}

# Choose log level or if does not follow expected structure
# such as stack traces then place in unknown catagory.
sub parse_types {
	my ($line) = @_;
	if ( $line =~ / \*(\w*)\* / ) {
		$global_types{$1}++;
		parse( $1, $line );
	}
	else {
		$global_types{'UNKNOWN'}++;
		parse( 'UNKNOWN', $line );
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
		print DUMP "$line";		
	}
	
	# Debug information to discover rules
	unless ($flag) {
		
		# Debuf line uncomment to enable
		#if ( $ruleset eq 'INFO' ) { print "$line"; }
		$global_counters{'dirty'}++;
	}
	return $flag;
}

# Header string for printing an HTML file
# Can also pull in yet another file. Start simple.
sub header {
	my $time = localtime(time);
	my $h2 =
	  "<h2>$config->{HTML}{TITLE}</h2>\n<h3>Report Generated: $time</h3>\n";
	return
	  "<html><head><title>Exception Report</title></head>\n<body>\n$h2 <pre>";
}

# Footer string for printing an HTML file.
sub footer {
	return "</pre></body></html>";
}

