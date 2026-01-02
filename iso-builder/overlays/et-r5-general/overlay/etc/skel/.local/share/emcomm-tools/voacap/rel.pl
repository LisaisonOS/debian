#!/usr/bin/perl
# Author: Jari Perkiömäki OH6BG
# 12 June 2016: initial release
# 18 June 2016: added Long-Path predictions; use unpack for extracting table data
# 18 June 2016: added Power, Mode; small improvements
#

use strict;
use warnings;

my @relhour  = ();
my @sdbwhour = ();
my @co  = ();
my @mo  = ();
my @pwr = ();
my @db = ();
my $km  = 0;
my $mi  = 0;
my $brn = 0;
my $fh;
my $voa;
my $mode;
my $path = "Short-Path";

# main loop
open $fh, '>>', \$voa or die $!;
process ();
close $fh;
print $voa;
exit;

### end ###

sub process {
    my $format = 'A4 A5 A5 A5 A5 A5 A5 A5 A5 A5';
    while (<>) {

	    s/^\s+|\s+$//g;
	    
	    if ( substr ($_, -1) eq "s" ) { @mo = split /\s+/; }
	    
            elsif ( substr ($_, -2) eq "kW" ) { @pwr = split /\s+/; }
            elsif ( substr ($_, -2) eq "dB" ) {
             
            @db = split /\s+/;
            if ( $db[13] eq "24.0" ) { $mode = "CW"; }
            elsif ( $db[13] eq "38.0" ) { $mode = "SSB"; }
            else { $mode = "AM"; }
            
            }
	    
	    elsif ( /Long/ ) { $path = "Long-Path"; }
	    
	    elsif ( substr ($_, -1) =~ /\d/ ) { 
		
		    @co = split /\s+/; 
		    $brn  = sprintf "%d", $co[9] + 0.5; 
		    $km   = sprintf "%d", $co[12] + 0.5;
		    $mi   = sprintf "%d", ($co[12] * 0.62137) + 0.5;
		
		}
		
	    elsif ( substr ($_, -3) eq "REL" ) { push (@relhour, [ unpack( $format, $_ ) ] ); }
	    elsif ( substr ($_, -3) eq "DBW" ) { push (@sdbwhour,[ unpack( $format, $_ ) ] ); }
	    
    } # while 
    
    for ($fh) {
	    print $_ "VOACAP Prediction via $path. $mo[0] $mo[1]: SSN $mo[4] Power = $pwr[$#pwr], $mode\n";
            print $_ "TX ($co[0]$co[1], $co[2]$co[3]) to RX ($co[5]$co[6], $co[7]$co[8]): $km km, $mi mi, $brn deg\n\n";
	    print $_ "  | 01|02|03|04|05|06|07|08|09|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|\n";
	}
    
    foreach my $freq (reverse 1..9) { 
	    print $fh band($freq) . "|";
	    foreach my $h (0..23) { print $fh makehourfreq( $h, $freq ); }
	    print $fh "|" . band($freq) . "\n";
	}    

    for ($fh) {
	    print $_ "  | 01|02|03|04|05|06|07|08|09|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|\n\n";
	    print $_ "A = 90 - 100%   d = 25 - 49%  * = REL 0%, but Signal Power over Noise\n";
	    print $_ "B = 75 -  89%   e = 10 - 24%\n";
	    print $_ "C = 50 -  74%   f =  1 -  9%\n\n";
	}    
    
    @relhour = ();
    @sdbwhour = ();

    } # process

sub makehourfreq {
    
    my $h = $_[0];
    my $f = $_[1];
    my $r = $relhour[$h][$f];
    my $s = $sdbwhour[$h][$f];
    
    if ( ($r == 0.00 && $s >= -167) ) {  return " * "; }
    else { return col($relhour[$h][$f]); }
    
    } 

sub band {
    
    my $b = $_[0];
    
    if ($b == 1) { return "80"; }
    if ($b == 2) { return "60"; }
    if ($b == 3) { return "40"; }
    if ($b == 4) { return "30"; }
    if ($b == 5) { return "20"; }
    if ($b == 6) { return "17"; }
    if ($b == 7) { return "15"; }
    if ($b == 8) { return "12"; }
    if ($b == 9) { return "10"; }
    
    } 

sub col {
    
    my $rel = $_[0]; 
    
    if ($rel == 0.00 )                   { return "   "; }
    elsif ($rel >= 0.01 && $rel < 0.10 ) { return " f "; }
    elsif ($rel >= 0.10 && $rel < 0.25 ) { return " e "; }
    elsif ($rel >= 0.25 && $rel < 0.50 ) { return " d "; }
    elsif ($rel >= 0.50 && $rel < 0.75 ) { return " C "; }
    elsif ($rel >= 0.75 && $rel < 0.90 ) { return " B "; }
    elsif ($rel >= 0.90 && $rel < 1.01 ) { return " A "; }
    else  { return " - "; }
    
    } 