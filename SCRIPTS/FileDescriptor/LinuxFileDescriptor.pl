#!/usr/bin/perl
# A first attempt at monitoring File Descriptors
# For Sakai OAE on Linux
# Good for Burn tests
# Pulls in the command
#     ls -l /proc/2693/fd
# Where 2693 is the PID of the SakaiOAE process
#
# Command line Options:
# -pid = PID of OAE process
# -sleep = Time between running the command (default once every 60 seconds)
# -iterations = Number of times measured before exiting (default 60)
# -debug = 1 print lines not understood (For developers only)
#
# For Questions:
# Alan Berg - a.m.berg AT uva.nl

use Getopt::Long;

my $DEBUG = 0;
my $pid   = 0;
my $sleep = 60;
my $iterations=60;
my %global;


# List the data to be printed out and in which order
my @print_list = (
	'TOTAL',  'sling',      'felix',         'sparsemap',
	'solr',   'jackrabbit', 'activemq-data', 'logs',
	'socket', 'pipe',       'eventpoll',     'java',
	'dev'
);
GetOptions(
	"pid=s"   => \$pid,
	"debug=i" => \$DEBUG,
	"sleep=i" => \$sleep,
	"iterations=i" => \$iterations
);

unless ($pid) {
	print "Exiting as PID of OAE not given as command line option -pid=\n";
	exit(1);
}
my $proc_dir = "/proc/$pid/fd";
unless ( -d $proc_dir ) {
	print "No Proc dir [$proc_dir] so am exiting\n";
	exit(1);
}

foreach $key (@print_list) {
    print "$key,";
}
print "\n";

my $counter=0;

while ($counter++ < $iterations){
	&print_totals();
	sleep($sleep);
}

# Print totals based on print_list
# Using whitelist if there is a large divergance
# compared to the TOTAl then a process is missing
# This forces us to understand which processes are
# consuming file descriptors.
#
sub print_totals(){

# Reset counters that are going to get printed
foreach $key (@print_list) {
    $global{$key}=0;
}

my @result = `ls -l $proc_dir 2>&1`;

# Extra line in output so start with negative counter
$global{'TOTAL'} = -1;

foreach $line (@result) {
	$global{'TOTAL'}++;

	#Concentrate on the sling directory for now
	#Brute force to get things started
	if ( $line =~ /\/sling\// ) {
		$global{'sling'}++;
		if ( $line =~ /\/sling\/felix/ ) {
			$global{'felix'}++;
		}
		elsif ( $line =~ /\/sling\/sparsemap/ ) {
			$global{'sparsemap'}++;
		}
		elsif ( $line =~ /\/sling\/solr/ ) {
			$global{'solr'}++;
		}
		elsif ( $line =~ /\/sling\/jackrabbit/ ) {
			$global{'jackrabbit'}++;
		}
		elsif ( $line =~ /\/sling\/activemq-data/ ) {
			$global{'activemq-data'}++;
		}
		elsif ( $line =~ /\/sling\/logs/ ) {
			$global{'logs'}++;
		}
		elsif ( $line =~ /\/sling\/org\.apache/ ) {
			$global{'launch'}++;
		}
		else {
			if ($DEBUG) {
				print $line;
			}
		}
	}
	elsif ( $line =~ /\/load\// ) {
		$global{'load'}++;
	}
	elsif ( $line =~ /\/jre\/lib/ ) {
		$global{'java'}++;
	}
	elsif ( $line =~ /\/dev/ ) {
		$global{'dev'}++;
	}
	elsif ( $line =~ /socket:/ ) {
		$global{'socket'}++;
	}
	elsif ( $line =~ /pipe:/ ) {
		$global{'pipe'}++;
	}
	elsif ( $line =~ /\.log/ ) {
		$global{'logs'}++;
	}
	elsif ( $line =~ /\[eventpoll\]/ ) {
		$global{'eventpoll'}++;
	}
	elsif ( $line =~ /sakaiproject\.nakamura/ ) {
		# Ignored in the print_list
		$global{'launcher'}++;
	}
	else {
		if ($DEBUG) {
			print $line;
		}
	}
}

foreach $key (@print_list) {
	if(exists ($global{$key})){
    print "$global{$key},";
	} else {
		print "0,";
	}
}
print "\n";
}


