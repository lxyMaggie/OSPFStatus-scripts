#!/usr/bin/perl
use Socket;
use File::Copy;
#
########################################################################
# Put the directory the script/data files are located in here - be sure
# to surround them with quotes and do not add the ending /
########################################################################

$localdir = "/home/ndnmonitor/test_bed_monitor/Parser2";

%router_prefixes=();
%adv_prefixes=();
%router_links1=();
%topology=();
$lasttimestamp = 0;
$lastfile = "";
%prefix_timestamp = ();
%link_timestamp = ();

######################
# Read in config file
######################
open(INFILE,"$localdir/parse.conf") || die("Unable to open parse.conf");
while(<INFILE>){
	chomp;
	if ($_ =~ m/lasttimestamp/){
		($keyword,$value) = split("=");
		$lasttimestamp = $value;
	}
	if ($_ =~ m/lastfile/){
		($keyword,$value) = split("=");
		$lastfile = $value;
	}
	if ($_ =~ m/timezone/){
		($keyword,$value) = split("=");
		$timezone = $value;
	}
	if ($_ =~ m/htmldir/){
		($keyword,$value) = split("=");
		$htmldir = $value;
	}
}
close(INFILE);

####################################################
# Read in prefixes, links, timestamps, and topology
####################################################
open(INFILE,"$localdir/prefix") || die("Unable to open prefix");
while(<INFILE>){
	chomp;
	($prefix,$origin,$timestamp) = split(":", $_, 3);
	$router_prefixes{$prefix} = $origin;
	$prefix_timestamp{$prefix} = $timestamp;
}
close(INFILE);

open(INFILE,"$localdir/links1") || die("Unable to open links1");
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

open(INFILE,"$localdir/topology") || die("Unable to open topology");
while(<INFILE>){
	chomp;
	if ($_ =~ "Router"){
		($extra,$router) = split(":");
		if ($router eq ("Northeastern University")){
			$router_name = "Northeastern University";
		}elsif ($router eq ("64.57.23.210")){
			$router_name = "sppsalt1.arl.wustl.edu";
		}elsif ($router eq ("64.57.23.178")){
			$router_name = "sppkans1.arl.wustl.edu";
		}elsif ($router eq ("64.57.23.194")){
			$router_name = "sppwash1.arl.wustl.edu";
		}elsif ($router eq ("64.57.19.226")){
			$router_name = "sppatla1.arl.wustl.edu";
		}elsif ($router eq ("64.57.19.194")){
			$router_name = "spphous1.arl.wustl.edu";
		}else{
			$iaddr = $router;
			$iaddr = inet_aton($iaddr);
			$router_name = lc(gethostbyaddr($iaddr, AF_INET));
			if (length($router_name) == 0){
				$router_name = $router;
			}
		}
		$line = <INFILE>;
		chomp($line);
		while ($line !~ m/END/){
			($linkID,$linkdata) = split(":",$line);
			$topology{$router_name}{$linkID} = $linkdata;
			$line = <INFILE>;
			chomp($line);
		}
	}
}
close(INFILE);

open(INFILE,"$localdir/link_timestamp") || die("Unable to open link_timestamp");
while(<INFILE>){
	chomp;
	($link,$timestamp) = split(":");
	if ($link eq ("Northeastern University")){
		$link_name = "Northeastern University";
	}elsif ($link eq ("64.57.23.210")){
		$link_name = "sppsalt1.arl.wustl.edu";
	}elsif ($link eq ("64.57.23.178")){
		$link_name = "sppkans1.arl.wustl.edu";
	}elsif ($link eq ("64.57.23.194")){
		$link_name = "sppwash1.arl.wustl.edu";
	}elsif ($link eq ("64.57.19.226")){
		$link_name = "sppatla1.arl.wustl.edu";
	}elsif ($link eq ("64.57.19.194")){
		$link_name = "spphous1.arl.wustl.edu";
	}else{
		$iaddr = $link;
		$iaddr = inet_aton($iaddr);
		$link_name = lc(gethostbyaddr($iaddr, AF_INET));
		if (length($link_name) == 0){
			$link_name = $link;
		}
	}
	$link_timestamp{$link_name} = $timestamp;
}
close(INFILE);

for $router (keys %topology){
	$adv_prefixes{$router}=();
}

for $prefix (keys %router_prefixes){
	$router = $router_prefixes{$prefix};
	if ($router eq ("Northeastern University")){
		$router_name = "Northeastern University";
	}elsif ($router eq ("64.57.23.210")){
		$router_name = "sppsalt1.arl.wustl.edu";
	}elsif ($router eq ("64.57.23.178")){
		$router_name = "sppkans1.arl.wustl.edu";
	}elsif ($router eq ("64.57.23.194")){
		$router_name = "sppwash1.arl.wustl.edu";
	}elsif ($router eq ("64.57.19.226")){
		$router_name = "sppatla1.arl.wustl.edu";
	}elsif ($router eq ("64.57.19.194")){
		$router_name = "spphous1.arl.wustl.edu";
	}else{
		$iaddr = $router;
		$iaddr = inet_aton($iaddr);
		$router_name = lc(gethostbyaddr($iaddr, AF_INET));
		if (length($router_name) == 0){
			$router_name = $router;
		}
	}
	push (@{$adv_prefixes{$router_name}}, $prefix);
}

&check_topology();
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
#$lasttimestamp = &convert_timestamp($lasttimestamp);

$lasttimestamp = &get_local_timestamp($lasttimestamp);

##########################
# Output HTML to terminal
##########################
print "<html>\n";
print "<head>\n";
print "<title>OSPFN Testbed Status</title>\n";
print "</head>\n";
print "<body bgcolor=\"#ffffee\">\n";

print "<table>\n";
print "<tr><td><b>Page last updated:</b></td>\n";
print "<td><b>$mon/$mday/$year $hour:$min:$sec $timezone</b></td></tr>\n";
print "<tr><td><b>Last logfile processed:</b></td>\n";
print "<td><b>$lastfile</b></td></tr>\n";
print "<tr><td><b>Last timestamp in logfile:</b></td>\n";
print "<td><b>$lasttimestamp $timezone</b></td></tr>\n";
print "<tr></tr></table>\n";
print "<p></p>\n";

print "<table><tr><td valign=\"top\">\n";

print "<table border=\"1\" cellpadding=\"5\">\n";
print "<tr><th colspan=\"3\">Advertised Prefixes</th></tr>";
print "<tr><th>Router</th>\n";
print "<th>Prefix Timestamp</th>\n";
print "<th>Prefix</th></tr>\n";
&prefix_table();
print "</table></td><td valign=\"top\">\n";

print "<table border=\"1\" cellpadding=\"5\">\n";
print "<tr><th colspan=\"3\">Link Status</th></tr>";
print "<tr><th>Router</th>\n";
print "<th>LSA Timestamp</th>\n";
print "<th>Links</th></tr>\n";
&links_table();
print "</table></td><td valign=\"top\">\n";

print "<table>\n";
print "<tr><th>Link Status Legend</th></tr>";
print "<tr><td bgcolor = \"Lime\"></td><td>Link is connected and is part of the testbed topology</td></tr>\n";
print "<tr><td bgcolor = \"Red\"></td><td>Link is not connected and is part of the testbed topology</td></tr>\n";
print "<tr><td bgcolor = \"SkyBlue\"></td><td>Link is connected but not part of the testbed topology</td></tr>\n";
#print "<tr><td bgcolor = \"WhiteSmoke\"></td><td>Link is not connected and not part of the testbed topology</td></tr>\n";
print "</table>\n";

print "</td></tr></table>\n";


#print "<table>\n";
#print "<tr><td><b>Network Topology</b></td></tr>\n";
#print "<tr><td><img src=\"topology.jpg\" alt=\"Network Topology\" /></td></tr>\n";
#print "</table>\n";

print "</body>\n";
print "</html>\n";

##############################################################
# Subroutine to check existing links against known topology -
# color the entries appropriately:
# Red - link is in topology but not connected
# Green - link is in topology and connected
# Blue - link is not in topology but is connected
##############################################################
sub check_topology
{
	for $router (keys %router_links1){
		if ($router eq ("Northeastern University")){
			$router_name = "Northeastern University";
		}elsif ($router eq ("64.57.23.210")){
			$router_name = "sppsalt1.arl.wustl.edu";
		}elsif ($router eq ("64.57.23.178")){
			$router_name = "sppkans1.arl.wustl.edu";
		}elsif ($router eq ("64.57.23.194")){
			$router_name = "sppwash1.arl.wustl.edu";
		}elsif ($router eq ("64.57.19.226")){
			$router_name = "sppatla1.arl.wustl.edu";
		}elsif ($router eq ("64.57.19.194")){
			$router_name = "spphous1.arl.wustl.edu";
		}else{
			$iaddr = $router;
			$iaddr = inet_aton($iaddr);
			$router_name = lc(gethostbyaddr($iaddr, AF_INET));
			if (length($router_name) == 0){
				$router_name = $router;
			}
		}
		for $link (keys %{$router_links1{$router}}){
			if ($router eq ("Northeastern University")){
				$router_name = "Northeastern University";
			}elsif ($router eq ("64.57.23.210")){
				$router_name = "sppsalt1.arl.wustl.edu";
			}elsif ($router eq ("64.57.23.178")){
				$router_name = "sppkans1.arl.wustl.edu";
			}elsif ($router eq ("64.57.23.194")){
				$router_name = "sppwash1.arl.wustl.edu";
			}elsif ($router eq ("64.57.19.226")){
				$router_name = "sppatla1.arl.wustl.edu";
			}elsif ($router eq ("64.57.19.194")){
				$router_name = "spphous1.arl.wustl.edu";
			}else{
				$iaddr = $router;
				$iaddr = inet_aton($iaddr);
				$router_name = lc(gethostbyaddr($iaddr, AF_INET));
				if (length($router_name) == 0){
					$router_name = $router;
				}
			}
			if (!exists $topology{$router_name}{$link}){
				$topology{$router_name}{$link} = "SkyBlue";
			}else{
				$topology{$router_name}{$link} = "Lime";
			}
		}
	}
}

###################################
# Constructs HTML for prefix table
###################################
sub prefix_table
{
	for $router (sort { lc($a) cmp lc($b) } keys %adv_prefixes){
		if (!exists $adv_prefixes{$router}[0]){
			$adv_prefixes{$router}[0] = "-";
		}
		$size = scalar(@{$adv_prefixes{$router}});
		print "<tr><td rowspan=\"$size\">$router</td>\n";
		for ($i = 0; $i < $size; $i ++){
			if (exists $prefix_timestamp{$adv_prefixes{$router}[$i]}){
				#$string = &convert_timestamp($prefix_timestamp{$adv_prefixes{$router}[$i]})." $timezone";
				#$string = $prefix_timestamp{$adv_prefixes{$router}[$i]}." $timezone"	
				$string = &get_local_timestamp($prefix_timestamp{$adv_prefixes{$router}[$i]})." $timezone";	
					
			}else{
				$string = "-";
			}
			print "<td>$string</td>\n";
			print "<td>$adv_prefixes{$router}[$i]</td></tr>\n";
		}
	}
}

##################################
# Constructs HTML for links table
##################################
sub links_table
{
	for $router (sort keys %topology){
		$size=0;
		for $link (keys %{$topology{$router}}){
			$size ++;
		}
		print "<tr><td rowspan=\"$size\">$router</td>\n";
		if (exists $link_timestamp{$router}){
			#$string = &convert_timestamp($link_timestamp{$router})." $timezone";
			#$string = $link_timestamp{$router}." $timezone";	
			$string = &get_local_timestamp($link_timestamp{$router})." $timezone";	
		}else{
			$string = "-";
		}
		print "<td rowspan=\"$size\">$string</td>\n";
		for $link (keys %{$topology{$router}}){
			if ($link eq ("Northeastern University")){
				$link_name = "Northeastern University";
			}elsif ($link eq ("64.57.23.210")){
				$link_name = "sppsalt1.arl.wustl.edu";
			}elsif ($link eq ("64.57.23.178")){
				$link_name = "sppkans1.arl.wustl.edu";
			}elsif ($link eq ("64.57.23.194")){
				$link_name = "sppwash1.arl.wustl.edu";
			}elsif ($link eq ("64.57.19.226")){
				$link_name = "sppatla1.arl.wustl.edu";
			}elsif ($link eq ("64.57.19.194")){
				$link_name = "spphous1.arl.wustl.edu";
			}else{
				$iaddr = $link;
				$iaddr = inet_aton($iaddr);
				$link_name = lc(gethostbyaddr($iaddr, AF_INET));
				if (length($link_name) == 0){
					$link_name = $link;
				}
			}
			$color = $topology{$router}{$link};
			print "<td bgcolor=\"$color\">$link_name</td></tr>\n";
		}
	}
}

################################################################
# Converts timestamp in the OSPFN logfiles into readable format
################################################################
sub convert_timestamp
{
	my $timestamp = $_[0];
	my $year = substr($timestamp,0,4);
	my $month = substr($timestamp,4,2);
	my $day = substr($timestamp,6,2);
	my $hour = substr($timestamp,8,2);
	my $min = substr($timestamp,10,2);
	my $sec = substr($timestamp,12,2);
	my $string = "$month/$day/$year $hour:$min:$sec";
	
	$string;
}


sub get_local_timestamp 
{
        my $timestamp = $_[0];
        my $unixtime = substr($timestamp,0,10);
        my $readable_time = localtime($unixtime);
        $readable_time; 
}

