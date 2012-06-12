#!/usr/bin/perl
#
########################################################################
# Put the directory the script/data files are located in here - be sure
# to surround them with quotes and do not add the ending /
########################################################################

$localdir = "/home/ndnmonitor/test_bed_monitor/Parser2";

$timestamp = 0;
$prefix = ();
%router_prefixes = ();
%router_links1 = ();
%router_links3 = ();
%prefix_timestamp = ();
%link_timestamp = ();

###################################################################################
# Read in config file to get log directory, last log file read, and last line read
###################################################################################
open(INFILE,"$localdir/parse.conf")|| die("Unable to open parse.conf");
while(<INFILE>){
	chomp;
	if ($_ !~ m/#/){
		if ($_ =~ m/logdir/){
			($keyword,$value) = split("=");
			$logdir = $value;
		}

		if ($_ =~ m/lastfile/){
			($keyword,$value) = split("=");
			$lastfile = $value;
		}

		if ($_ =~ m/lasttimestamp/){
			($keyword,$value) = split("=");
			$lasttimestamp = $value;
		}

		if ($_ =~ m/timezone/){
			($keyword,$value) = split("=");
			$timezone = $value;
		}
	}

}
close(INFILE);
$lastfilestamp = substr($lastfile,0,14);

#################################
# Read in prefix and links files
#################################
open(INFILE,"$localdir/prefix") || die("Unable to open prefix.txt");
while(<INFILE>){
	chomp;
	($prefix,$origin,$timestamp) = split(":", $_, 3);
	$router_prefixes{$prefix} = $origin;
	$prefix_timestamp{$prefix} = $timestamp;
}
close(INFILE);

open(INFILE,"$localdir/links1") || die("Unable to open links1.txt");
while(<INFILE>){
	chomp;
	if ($_ =~ "Router"){
		($extra,$router) = split(":");
		$line = <INFILE>;
		chomp($line);
		while ($line !~ m/END/){
			($linkID,$linkdata) = split(":",$line);
			$router_links1{$router}{$linkID} = $linkdata;
			$line = <INFILE>;
			chomp($line);
		}
	}
}
close(INFILE);

open(INFILE,"$localdir/links3") || die("Unable to open links3.txt");
while(<INFILE>){
	chomp;
	if ($_ =~ "Router"){
		($extra,$router) = split(":");
		$line = <INFILE>;
		chomp($line);
		while ($line !~ m/END/){
			($linkID,$linkdata) = split(":",$line);
			$router_links3{$router}{$linkID} = $linkdata;
			$line = <INFILE>;
			chomp($line);
		}
	}
}
close(INFILE);

open(INFILE,"$localdir/link_timestamp") || die("Unable to open link_timestamp.txt");
while(<INFILE>){
	chomp;
	($router,$timestamp) = split(":");
	$link_timestamp{$router} = $timestamp;
}
close(INFILE);

#################################################
#Read in names of all files in the log directory
#Add only .log files into the @files array
#################################################
opendir DIR, $logdir || die("Unable to open directory $logdir");
@dirfiles = readdir(DIR);
closedir DIR;

@dirfiles = sort(@dirfiles);
for ($i=0; $i < scalar(@dirfiles); $i++){
	if($dirfiles[$i] =~ /.log/){
		push(@files, $dirfiles[$i]);
	}
}

###########################################################
#Start with last file read and every new file in directory
#This adds and deletes advertised prefixes as well as pull
#out type 1 and type 3 links from the router LSAs
###########################################################
for ($i=0; $i < scalar(@files); $i++){
	if ($lastfilestamp <= substr($files[$i],0,14)){
		#print "*** Parsing ".$files[$i]." ***\n";
		open(INFILE,"$logdir/$files[$i]");
		while(<INFILE>){
			chomp;
			#($timestamp, $line) = split(':', $_, 2);
			#print " Reading: $_\n";	
			($first, $second) = split(':', $_, 2);
			#print "First: $first\n";	
			($timestamp, $dummy) = split('-', $first, 2);
			$line = $second;	
			
			#print "Timestamp: ".$timestamp." Line: ".$line." \n";	
					
			if ($line =~ m/Opaque Type  236/){
				$line = <INFILE>;
				chomp($line);
				#print "Line1 : $line \n";	
				while ($line !~ m/lsa_read called/ && $line !~ m/ospfnstop/ && !eof(INFILE)){
					#print "Line2 : $line\n";	
					if ($line =~ m/name prefix:/){
						($extra,$prefix) = split('name prefix: ',$line,2);
						#print "Prefix: $prefix \n";	
					}
					if ($line =~ m/:\//){
						($extra,$prefix) = split(':',$line,2);
						#print "Prefix: $prefix \n";	
					}
					if ($line =~ m/Advertising Router/){
						($extra,$origin) = split('Router ',$line,2);
						#print "Origin: $origin \n";	
					}
					if ($line =~ m/Delete _name opaque lsa called/){
						$action = "delete";
						#print "Action: Delete \n";	
					}
					if ($line =~ m/Update_name_opaque_lsa called/){
						$action = "add";
						#print "Action: Add\n";	
					}
					$line = <INFILE>;
					chomp($line);
				}
				if ($origin ne('') && $prefix ne('')){
					if ($action eq("delete")){
						delete($router_prefixes{$prefix});
						$prefix_timestamp{$prefix} = $timestamp;
					}
					if ($action eq("add")){
						$router_prefixes{$prefix} = $origin;
						$prefix_timestamp{$prefix} = $timestamp;
					}
				#print "Prefix: $prefix Origin: $origin Action: $action \n";
				}
			}
			if ($line =~ m/(router-LSA)/){
				$line = <INFILE>;
				chomp($line);
				while ($line !~ m/lsa_read called/ && $line !~ m/ospfnstop/ && !eof(INFILE)){
					$line = <INFILE>;
					chomp($line);
					if ($line =~ m/Advertising Router/){
						($extra,$router) = split('Router ',$line,2);
						$router_links1{$router}=();
						$router_links3{$router}=();
					}
					if ($line =~ m/Link ID/ ){
						($extra,$linkID) = split('ID ',$line,2);
					}
					if ($line =~ m/Link Data/){
						($extra,$linkdata) = split('Data ',$line,2);
					}
					if ($line =~ m/Type/){
						($extra,$type) = split('Type ',$line,2);
						if ($type eq ('1')){
							$router_links1{$router}{$linkID} = $linkdata;
						}
						if ($type eq ('3')){
							$router_links3{$router}{$linkID} = $linkdata;
						}
					}
				}
				$link_timestamp{$router} = $timestamp;
			}
			
		}
		close(INFILE);
		$lasttimestamp = $timestamp;
	}
}

################################################
#Output prefixes and type1/type3 links to files
################################################
open(OUTFILE,">$localdir/prefix")|| die("Unable to write to prefix");
while (($prefix,$origin)=each(%router_prefixes)){
	#$date = &get_date;
	$timestamp = $prefix_timestamp{$prefix};
	#if (($date - $timestamp) < 1000000){
		print OUTFILE "$prefix:$origin:$timestamp\n";
	#}
}
close(OUTFILE);

open(OUTFILE,">$localdir/links1")|| die("Unable to write to links1");
for $router (keys %router_links1){
	print OUTFILE "Router:$router\n";
	for $linkID (keys %{$router_links1{$router}}){
		print OUTFILE "$linkID:$router_links1{$router}{$linkID}\n";
	}
	print OUTFILE "END\n";
}
close(OUTFILE);

open(OUTFILE,">$localdir/links3")|| die("Unable to write to links3");
for $router (keys %router_links3){
	print OUTFILE "Router:$router\n";
	for $linkID (keys %{$router_links3{$router}}){
		print OUTFILE "$linkID:$router_links3{$router}{$linkID}\n";
	}
	print OUTFILE "END\n";
}
close(OUTFILE);

open(OUTFILE,">$localdir/link_timestamp")|| die("Unable to write to link_timestamp");
while (($key,$value)=each(%link_timestamp)){
	print OUTFILE "$key:$value\n";
}
close(OUTFILE);

###################################
#Finished - update parse.conf file
###################################
open(OUTFILE,">$localdir/parse.conf")|| die("Unable to write to parse.conf");
print OUTFILE "logdir=$logdir\n";
printf OUTFILE "lastfile=%s\n",pop(@files);
print OUTFILE "lasttimestamp=$lasttimestamp\n";
print OUTFILE "timezone=$timezone\n";
close(OUTFILE);

#######################
#Get today's timestamp
#######################
sub get_date{
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900;
	$mon += 1;
	if ($mon < 10){
	$mon = "0".$mon;
	}
	if ($mday < 10){
		$mday = "0".$mday;
	}
	if ($hour < 10){
		$hour = "0".$hour;
	}
	if ($min < 10){
		$min = "0".$min;
	}
	if ($sec < 10){
		$sec = "0".$sec;
	}
	$date = "$year$mon$mday$hour$min$sec";
	
	$date;
}
