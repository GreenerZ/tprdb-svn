#!/usr/bin/perl -w

use strict;
use warnings;
use open IN  => ":crlf";

use File::Copy;
use Data::Dumper; $Data::Dumper::Indent = 1;
sub d { print STDERR Data::Dumper->Dump([ @_ ]); }

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";


# Escape characters 
my $map = { map { $_ => 1 } split( //o, "\\<> \t\n\r\f\"" ) };


my $usage =
  "Produce ProgGraph files: \n".
  "  -T in:  Translog XML file\n".
  "  -I in:  IDFX file\n".
  "  -O out: output file\n".
  "Options:\n".
  "  -v verbose mode [0 ... ]\n".
  "  -h this help \n".
  "\n";

use vars qw ($opt_O $opt_T $opt_I $opt_v $opt_h);

use Getopt::Std;
getopts ('T:I:O:G:f:p:v:t:h');

die $usage if defined($opt_h);

my $LastTime = 0;
my $TRANSLOG = {};
my $Verbose = 0;
my $KeyTime = {};
my $FirstTranslogEvent = 0;

if (defined($opt_v)) {$Verbose = $opt_v;}

### Read and Tokenize Translog log file
if (defined($opt_T) && defined($opt_I)) {
  my $T = ReadTranslog($opt_T);
  my $I = ReadInputlog($opt_I);

  my $d = TimeDistance();
  MapInputLog($T, $I, $d);
  InjInputLog($T, $I);
#  PrintInjected();
  PrintInjected($opt_O);
  exit;
}

printf STDERR "No Output produced\n";
die $usage;

exit;


##########################################################
# Read Translog Logfile
##########################################################

## SourceText Positions
sub ReadTranslog {
  my ($fn) = @_;

  open(FILE, '<:encoding(utf8)', $fn) || die ("cannot open for reading $fn");
  if($Verbose){printf STDERR "ReadTranslog: $fn\n";}

  my $n = -100000;
  my $K = {};
  while(defined($_ = <FILE>)) { 
  	if(/<ILfocus/ || /<ILtext/) {next;}

    if(/time="([^"]*)"/i) {$LastTime = $n = $1;}
    if($FirstTranslogEvent == 0 && /time="[^"]*/i) {$FirstTranslogEvent = $n;}
# CasMaCat
    if(/<text /i && /edition="manual"/) {
      if(/inserted="([^"]*)/i) {$K->{$n}{ins} = $1;}
      if(/deleted="([^"]*)/i) {$K->{$n}{del} = $1;}
      $KeyTime->{$K->{$n}{ins}}{T}{$n} ++
    }
#Translog
#<Key Time="4969" Cursor="45" Type="navi" Value="[Left]" />
#<Key Time="22282" Cursor="53" X="920" Y="398" Width="19" Height="26" Type="insert" Value="a" />

    if(/<Key /i ) {
# Chinese IME

	  if(/IMEtext="/) {
	    $K->{$n}{ins} = ' ';
	    $K->{$n}{del} = '';
	    $KeyTime->{$K->{$n}{ins}}{T}{$n} ++;
      }
	  elsif(/Type="IME"/ && /Value="\[([^\]]*)\]/i) {
	    if($1 eq "Back") { $K->{$n}{ins} = "&#x8;";}
		else { $K->{$n}{ins} = lc($1);}
	    $K->{$n}{del} = '';
        $KeyTime->{$K->{$n}{ins}}{T}{$n} ++;
      }
	  elsif(/Type="insert"/ && /Value="([^"]*)/i){
	  # CHinese comma
        if($1 eq "，") { $K->{$n}{ins} = ",";}
        elsif($1 eq "。") { $K->{$n}{ins} = ".";}
        elsif($1 eq "”" ) { $K->{$n}{ins} = "&quot;";}
		else {$K->{$n}{ins} = $1;}
	    $K->{$n}{del} = '';
        $KeyTime->{$K->{$n}{ins}}{T}{$n} ++;
      }
      elsif(/Type="delete"/ && /Text="([^"]*)/i) {
	    $K->{$n}{ins} = '';
	    $K->{$n}{del} = $1;
        $KeyTime->{$K->{$n}{ins}}{T}{$n} ++;
      }
    }
	if(/<ILfocus/ || /<ILtext/) {next;}
	while(defined($TRANSLOG->{$n})) {$n ++}
    $TRANSLOG->{$n} = $_; 
  }
  close(FILE);
  return $K;
}

sub ReadInputlog {
  my ($fn) = @_;

  open(FILE, '<:encoding(utf8)', $fn) || die ("cannot open for reading $fn");
  if($Verbose){printf STDERR "ReadInputLog: $fn\n";}

  my $n = 1;
  my $event = 0;
  my $T = {};
  my $X = {};
  while(defined($_ = <FILE>)) { 
    if(/<event /i) {$event = 1; if(/type="([^"]*)/i) {$X->{etype} = $1;} 
    else {print STDERR "ReadInputlog $_\n";}}
    
    if(/<\/event/i) {
      $event = 0;
	  $T->{$n++}=$X;
	  if(defined($X->{etype}) && defined($X->{value}) && $X->{etype} eq "keyboard") { 
	      $KeyTime->{$X->{value}}{I}{$X->{start}} ++;
#print STDERR "IIII: $X->{value}\n";
      }
	  $X = {};
    }

    if($event == 1 && /type="([^"]*)/i) {$X->{ptype} = $1;}
    if($event == 1 && /<title>([^<]*)/i) {$X->{title} = $1;}
    if($event == 1 && /<startTime>([^<]*)/i) {
        my $startTime = $1;
        if($X->{etype} eq 'focus') {$startTime -= 5;}
        $X->{start} = $startTime;
    }
    if($event == 1 && /<x>([^<]*)/i) {$X->{x} = $1;}
    if($event == 1 && /<x>([^<]*)/i) {$X->{y} = $1;}
    if($event == 1 && /<y>([^<]*)/i) {$X->{y} = $1;}
    if($event == 1 && /<type>([^<]*)/i) {$X->{type} = $1;}
    if($event == 1 && /<button>([^<]*)/i) {$X->{button} = $1;}
    if($event == 1 && /<key>([^<]*)/i) {$X->{key} = $1;}
#    if($event == 1 && /<value>([^<]*)/i) {$X->{value} = MSescape(MSunescape($1));}
    if($event == 1 && /<value>([^<]*)/i) {$X->{value} = $1;}
    
  }
  close(FILE);
  return $T;
}

sub TimeDistance {
  my $D = {};

  foreach my $k (keys %{$KeyTime}) {
    if(!defined($KeyTime->{$k}{T})) { if($Verbose) {print STDERR "\tundefined in Translog Key >$k<\n";} next;}
    if(!defined($KeyTime->{$k}{I})) { if($Verbose) {print STDERR "\tundefined in Inputlog Key >$k<\n";} next;}
    foreach my $tt (keys %{$KeyTime->{$k}{T}}) {
      foreach my $ti (keys %{$KeyTime->{$k}{I}}) {$D->{$tt-$ti} ++;}
    }
  }

  my $lt = 0;
#  printf STDERR "TimeDiff distribution\n";
  foreach my $d (sort {$D->{$b}<=>$D->{$a}} keys %{$D}) { 
    printf STDERR "MOST FREQUENT DISTANCE: $D->{$d}\t$d\n";
	return $d;
#    if($lt == 0) {$lt = $d;}
  }
}

sub  MapInputLog {
  my ($T, $I, $D) = @_;

  foreach my $t (sort {$a<=>$b} keys %{$T}) {
    my $d = 0;
    foreach my $i (sort {$a<=>$b} keys %{$I}) {
      if($I->{$i}{etype} ne "keyboard") {next;}
#      if($T->{$t}{ins} eq '') {last;} # then it is a deletion

	  $d = $t - $I->{$i}{start};
# printf STDERR "Keystroke time:$t\t$d\t>$T->{$t}{ins}< \n"; 
	  if($d - $D > 200) {next;} 
	  if($d - $D < -200) {
        if($T->{$t}{ins} eq '') {last;} # then it is a deletion
        if($Verbose) {print STDERR "IL Keystroke not found in window\t>$T->{$t}{ins}< \n"; }
		last;
	  }

	  if(!defined($I->{$i}{value})) {next;}
      if(defined($I->{$i}{diff})) { next;}

      if($T->{$t}{del} ne '' && $I->{$i}{value} eq "&#x8;") {
        if($Verbose) {printf STDERR "Keystroke deleted\t>$T->{$t}{del}< timeDiff %d\n", $d - $D; }
##	    $T->{$t}{link} = $i;
	    if($T->{$t}{ins} eq '') {
##		  $I->{$i}{link} = $t; 
		  $I->{$i}{diff} = $d;
        }
		last;
      }

	  if($I->{$i}{value} eq $T->{$t}{ins}) {
        if($Verbose) {printf STDERR "Keystroke inserted\t>$T->{$t}{ins}< timeDiff %d\n", $d - $D;}
##	    $I->{$i}{link} = $t;
		$I->{$i}{diff} = $d;
		last;
      } 
    } 
    if(!defined($I->{0})) {
      $I->{0}{etype} = "init";
##      $I->{0}{link} = $FirstTranslogEvent;
      $I->{0}{diff} = $d;
    }
  }
}

sub  InjInputLog {
  my ($T, $I) = @_;

printf STDERR "InjectInputLog lastTime:$LastTime\n";

  my $d = 0;
  my $m = 0;
  foreach my $i (sort {$a<=>$b} keys %{$I}) {
    if(defined($I->{$i}{diff})) { 
	  $d = $I->{$i}{diff};
	  next;
    }
    if(!defined($I->{$i}{etype})) {if($Verbose) {printf STDERR "InputLog no etype\n"; d($I->{$i});} next;}
    if(!defined($I->{$i}{start})) {if($Verbose) {printf STDERR "InputLog no start\n"; d($I->{$i});} next;}
	
#<text id="451669" elementId="segment-6114-editarea" xPath="" time="1403700128896" cursorPosition="87" deleted="" inserted="m" previous="Hoor eens. Het oorsmeer van deze blauwe vinvis vertelt het verhaal zijn leven en zijn o Oorsmeer Deze blauwe walvis vertelt het verhaal van zijn leven en locale." text="Hoor eens. Het oorsmeer van deze blauwe vinvis vertelt het verhaal zijn leven en zijn om Oorsmeer Deze blauwe walvis vertelt het verhaal van zijn leven en locale." edition="manual"/>

    my $time = $I->{$i}{start} + $d;
	if($time < 0) { next;}
	if($time >= $LastTime) { last;}
	
    while(defined($TRANSLOG->{$time})) {$time ++;}   

	my $s = '';
    if($I->{$i}{etype} eq "keyboard") {
#      if(!defined($I->{$i}{value})) {printf STDERR "InputLog no value\n"; d($I->{$i}); next;}
      if(!defined($I->{$i}{value})) {next;}
	  my  $v = ILescape($I->{$i}{value});
	  $s = "  <ILtext  Time=\"$time\" Value=\"$v\" Edition=\"IL\"/>\n";
	}
	elsif($I->{$i}{etype} eq "focus") { 
	  my  $v = ILescape($I->{$i}{title});
	  $s = "  <ILfocus Time=\"$time\" Title=\"$v\" />\n";
    } 
    elsif ($Verbose) {printf STDERR "InputLog skipping event:$I->{$i}{etype}\n"; next;}

    if($s ne '') {$TRANSLOG->{$time} = $s;}
  }
}

sub  PrintInjected {
  my ($fn) = @_;

  open(FILE, '>:encoding(utf8)', $fn) || die ("cannot open for reading $fn");
  if($Verbose){printf STDERR "ReadTranslog: $fn\n";}

  foreach my $k (sort {$a<=>$b} keys %{$TRANSLOG}) { print FILE "$TRANSLOG->{$k}"; }
  close (FILE);
  
}

### Escape

sub ILescape {
  my ($in) = @_;

  $in =~ s/"/&quot;/g;
  $in =~ s/\n/&#xA;/g;
  $in =~ s/\r/&#xD;/g;
#  $in =~ s/\t/[tab]/g;
#  $in =~ s/&#x9;/[tab]/g;
#  $in =~ s/&#x8;/[delete]/g;
  return $in;
}
