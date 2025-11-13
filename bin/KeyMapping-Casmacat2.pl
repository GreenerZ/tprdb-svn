#!/usr/bin/perl -w

use strict;
use warnings;

use Encode qw(encode decode);
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

# Escape characters 
my $map = { map { $_ => 1 } split( //o, "\\<> \t\n\r\f\"" ) };

use Data::Dumper; $Data::Dumper::Indent = 1;
sub d { print STDERR Data::Dumper->Dump([ @_ ]); }

my $usage =
  "Translog (incl src, tgt, atag) file to Treex: \n".
  "  -T in: Atag.xml file \n".
  "  -O out Write output <filename>\n".
  "Options:\n".
  "  -v verbose mode [0 ... ]\n".
  "  -h this help \n".
  "\n";

use vars qw ($opt_O $opt_T $opt_v $opt_h);

use Getopt::Std;
getopts ('T:O:v:t:h');


my $ALN = undef;
my $FIX = undef;
my $EYE = undef;
my $KEY = undef;
my $CHR = undef;
my $TOK = undef;
my $TEXT = undef;
my $TRANSLOG = {};
my $Verbose = 0;
my $ReviewSession = 0;

## for printing
my $FIXATIONS = {};
my $fixations =0;
my $MODIFICATIONS = {};
my $SEGMENTS = {};
my $modifications =0;



## Key mapping
my $TextLength = 0;

die $usage if defined($opt_h);
die $usage if not defined($opt_T);
die $usage if not defined($opt_O);

if (defined($opt_v)) {$Verbose = $opt_v};

  my $T = ReadTranslog($opt_T);
  Segments($T);

#my $xxx =0;
  foreach my $seg (sort {$a <=> $b} keys %{$T}) { 
    $FIX=$EYE=$KEY=$CHR=$TOK=$TEXT={};
    $FIX=$EYE=$KEY=$CHR=$TOK=$TEXT=undef;
    if(!defined($T->{$seg}{SEG}{1})) { print STDERR "$opt_T: Segment $seg without Source\n"; next;}
    if(!defined($T->{$seg}{SEG}{2})) { print STDERR "$opt_T: Segment $seg without Target\n"; next;}
    if(!defined($T->{$seg}{SEG}{3})) { print STDERR "$opt_T: Segment $seg without Final\n"; next;}

#print STDERR "Segment source:$seg $T->{$seg}{SEG}{1}{text}\n target:$seg $T->{$seg}{SEG}{2}{text}\n final: $seg $T->{$seg}{SEG}{3}{text}\n";

    if($T->{$seg}{SEG}{3}{text} eq '') {
      print STDERR "$opt_T: Segment: $seg without translation\n";
      next;
    }

    if($Verbose) {print STDERR "Segment: $seg ReviewSession=$ReviewSession\n";}

    my $S = [split(//, $T->{$seg}{SEG}{1}{text})];
    for (my $i = 0; $i<=$#{$S}; $i++) { $CHR->{src}{$i}{'c'} = $S->[$i];}

# MT output is inserted as first event
    if($ReviewSession) {$S = [split(//, $T->{$seg}{SEG}{2}{text})];}
    else {$S = [split(//, "")];}
	
    $TextLength = $#{$S}+1;
    for (my $i = 0; $i<=$#{$S}; $i++) { $CHR->{tra}{$i}{'c'} = $S->[$i];}
    for (my $i = 0; $i<=$#{$S}; $i++) { $TEXT->{$i}{'c'} = $S->[$i];}

    $S = [split(//, $T->{$seg}{SEG}{3}{text})];
    for (my $i = 0; $i<=$#{$S}; $i++) { $CHR->{fin}{$i}{'c'} = $S->[$i];}
 
#    print STDERR "TEXT: >$T->{$seg}{SEG}{3}{text}<\n";
#    d($S);
#    foreach my $x (sort {$b <=> $a} keys %{$CHR->{fin}}) { print STDERR "High1: $x\n"; last;}

    $EYE=$T->{$seg}{EYE};
    $FIX=$T->{$seg}{FIX};
    $TOK=$T->{$seg}{TOK};

    KeyLogAnalyse($T->{$seg}{KEY});
#    CheckForward($seg);
    MapTok2Chr();
    MapSource($seg);
#    UnmapTEXT();
    MapTarget();
#  CheckBackward ();

    FixModTable($seg);
  }
  PrintTranslog($opt_O);
exit;

############################################################
# escape
############################################################

sub MSunescape {
  my ($in) = @_;

  $in =~ s/&quot;/"/g;
  $in =~ s/&nbsp;/ /g;
  $in =~ s/&amp;/\&/g;
  $in =~ s/&gt;/\>/g;
  $in =~ s/&lt;/\</g;
  $in =~ s/&#xA;/\n/g;
  $in =~ s/&#xD;/\r/g;
  $in =~ s/&#x9;/\t/g;
  $in =~ s/&#A;/\n/g;
  $in =~ s/&#D;/\r/g;
  $in =~ s/&#9;/\t/g;
  return $in;
}

sub MSescape {
  my ($in) = @_;

  $in =~ s/\&/&amp;/g;
  $in =~ s/\>/&gt;/g;
  $in =~ s/\</&lt;/g;
  $in =~ s/\n/&#xA;/g;
  $in =~ s/\r/&#xD;/g;
  $in =~ s/\t/&#x9;/g;
  $in =~ s/"/&quot;/g;
#  $in =~ s/ /&nbsp;/g;
  return $in;
}



##########################################################
# Read Translog Logfile
##########################################################

## SourceText Positions
sub ReadTranslog {
  my ($fn) = @_;
  my ($type, $time, $cur);

  my $T = {};
  my $key = 0;
  my $F = '';
  my ($lastTime, $t, $lastCursor, $c);

  open(FILE, '<:encoding(utf8)', $fn) || die ("cannot open file $fn");
  if($Verbose) {printf STDERR "ReadTranslog Reading: $fn\n";}

  $type = 0;
  my $log = 0;
  my $seg = 0;
  my $currentSeg = 0;
  while(defined($_ = <FILE>)) {
    $TRANSLOG->{$log++} = $_;

    if(/<Languages/ && /review="true"/i) { $ReviewSession = 1;}

#printf STDERR "Translog: $ReviewSession %s\n",  $_;

    if(/<Events>/i)                  {$type =4; }
    elsif(/<SourceText[ >]/i)        {$type =1;}
    elsif(/<initialTargetText[ >]/i) {$type =2;}
    elsif(/<TargetText[ >]/i)        {$type =2;}
    elsif(/<finalTargetText[ >]/i)   {$type =3;}
    elsif(/<FinalText[ >]/i)         {$type =3;}
    elsif(/<Alignment[ >]/i)         {$type =6;}
    elsif(/<SourceToken[ >]/i)       {$type =7;}
    elsif(/<FinalToken[ >]/i)        {$type =8;}
	
#print STDERR "Segment: $type\t$_";

   if($type == 1 || $type == 2 || $type == 3) {
      if(/^#/) {next;}
      if(/<segment/i) {
        my ($text) = $_ =~ />(.*)/;
        ($currentSeg) = $_ =~ /Id="([^"]*)/i;
        $T->{$currentSeg}{SEG}{$type}{text} = MSunescape($text);
      }
      elsif($currentSeg > 0) { $T->{$currentSeg}{SEG}{$type}{text} .= MSunescape($_);}
      if($currentSeg > 0) { $T->{$currentSeg}{SEG}{$type}{text} =~ s/<.*//; }
    }

    elsif($type == 4 && /<gaze/) {
      if(/\sTime="([0-9][0-9]*)"/i)  {$time =$1;}
      else {printf STDERR "No Time $_\n"; }

      if(/elementId="([^"]*)"/i) { 
         my $E = $1;
         ($seg) = $E =~ /segment-([0-9][0-9]*)/; 
         if(!defined($seg)) {$seg=$currentSeg}
         if(!defined($T->{$seg})) {
           if($Verbose > 1) {printf STDERR "Seg undefined $seg\n";}
           next;
         }

#         my ($W) = $E =~ /segment-[0-9][0-9]*-(.*)/; 
#         if(!defined($W)) {next}
#
#         if($W eq 'editarea') {$T->{$seg}{EYE}{$time}{'w'} = 2;}
#         elsif($W eq 'target') {$T->{$seg}{EYE}{$time}{'w'} = 2;}
#         elsif($W eq 'source') {$T->{$seg}{EYE}{$time}{'w'} = 1;}
#         else{
#           $T->{$seg}{EYE}{$time}{'w'} = 0;
#         }
      }

      if(/window="([0-9][0-9]*)"/i)   {$T->{$seg}{EYE}{$time}{'w'} = $1;}
      else{$T->{$seg}{EYE}{$time}{'w'} = 0;}
      if(/TTime="([0-9][0-9]*)"/i)    {$T->{$seg}{EYE}{$time}{'tt'} = $1;}
      if(/lX="([-0-9][0-9]*)"/)    {$T->{$seg}{EYE}{$time}{'xl'} = $1;}
      else{$T->{$seg}{EYE}{$time}{'xl'} = 0;}
      if(/lY="([-0-9][0-9]*)"/)    {$T->{$seg}{EYE}{$time}{'yl'} = $1;}
      else{$T->{$seg}{EYE}{$time}{'yl'} = 0;}
      if(/lDil="([0-9.][0-9.]*)"/)  {$T->{$seg}{EYE}{$time}{'pl'} = $1;}
      else{$T->{$seg}{EYE}{$time}{'pl'} = 0;}
      if(/lOffset="([0-9][0-9]*)"/){$T->{$seg}{EYE}{$time}{'c'} = $1;}
      else{$T->{$seg}{EYE}{$time}{'c'} = 0;}
      if(/lChar="([-0-9][0-9]*)"/)    {$T->{$seg}{EYE}{$time}{'yc'} = $1;}
      else{$T->{$seg}{EYE}{$time}{'yc'} = 0;}
      if(/rX="([-0-9][0-9]*)"/)    {$T->{$seg}{EYE}{$time}{'xr'} = $1;}
      else{$T->{$seg}{EYE}{$time}{'xr'} = 0;}
      if(/rY="([-0-9][0-9]*)"/)    {$T->{$seg}{EYE}{$time}{'yr'} = $1;}
      else{$T->{$seg}{EYE}{$time}{'yr'} = 0;}
      if(/rDil="([0-9.][0-9.]*)"/)  {$T->{$seg}{EYE}{$time}{'pr'} = $1;}
      else{$T->{$seg}{EYE}{$time}{'pr'} = 0;}
      if(/rOffset="([0-9][0-9]*)"/){$T->{$seg}{EYE}{$time}{'c'} = $1;}
      else{$T->{$seg}{EYE}{$time}{'c'} = 0;}
      if(/rChar="([-0-9][0-9]*)"/)    {$T->{$seg}{EYE}{$time}{'xc'} = $1;}
      else{$T->{$seg}{EYE}{$time}{'xc'} = 0;}
    }

    elsif($type == 4 && /<fixation/) {

      if(/\sTime="([0-9][0-9]*)"/i)  {$time =$1;}
      else {printf STDERR "No Time $_\n"; }

      if(/elementId="([^"]*)"/i) {
         my $E = $1;
         ($seg) = $E =~ /segment-([0-9][0-9]*)/;
         if(!defined($seg)) {$seg=$currentSeg}
         if(!defined($T->{$seg})) {
           printf STDERR "Seg undefined $seg\n";
           next;
         }

#         my ($W) = $E =~ /segment-[0-9][0-9]*-(.*)/;
#         if(!defined($W)) {next}
#
#         if($W eq 'editarea') {$T->{$seg}{FIX}{$time}{'w'} = 2;}
#         elsif($W eq 'target') {$T->{$seg}{FIX}{$time}{'w'} = 2;}
#         elsif($W eq 'source') {$T->{$seg}{FIX}{$time}{'w'} = 1;}
#         else{ 
#           $T->{$seg}{FIX}{$time}{'w'} = 0;
#           if($Verbose > 1) {printf STDERR "Fixes $seg: $W\n"; }
#         }
      }

      if(/window="([0-9][0-9]*)"/i)   {$T->{$seg}{FIX}{$time}{'w'} = $1;}
      else{$T->{$seg}{EYE}{$time}{'w'} = 0;}
      if(/TTime="([0-9][0-9]*)"/i)    {$T->{$seg}{FIX}{$time}{'tt'} = $1;}
      if(/offset="([0-9][0-9]*)"/i){$T->{$seg}{FIX}{$time}{'c'} = $1;}
      else {$T->{$seg}{FIX}{$time}{'c'} = 0;}
      if(/Duration="([0-9][0-9]*)"/ii)   {$T->{$seg}{FIX}{$time}{'d'} = $1;}
      else {$T->{$seg}{FIX}{$time}{'d'} = 0;}
      if(/X="([-0-9][0-9]*)"/i)     {$T->{$seg}{FIX}{$time}{'x'} = $1;}
      else {$T->{$seg}{FIX}{$time}{'x'} = 0;}
      if(/Y="([-0-9][0-9]*)"/i)     {$T->{$seg}{FIX}{$time}{'y'} = $1;}
      else {$T->{$seg}{FIX}{$time}{'y'} = 0;}

    }
    elsif($type == 4 && /<stopSession/i) {
      foreach my $seg ( keys %{$T}) {
           $T->{$seg}{KEY}{$key} = $_;
           $key++;
       }
    }
    elsif($type == 4 && (/<text/i  || /<segmentClosed/ || /<segmentOpened/ || /<suggestionChosen/i || /<suggestionsLoaded/i || /<decode/i || /<suffixChange/i || /<translated/i || /<drafted/i || /<approved/i || /<rejected/i || /<keyDown/i)) {  
      $seg = '';
      if(/elementId="([^"]*)"/i) { ($seg) = $1 =~ /segment-([0-9][0-9]*)/; }
      if ($seg eq '' ) {print STDERR "text: undefined seg $_";}
      if(!defined($T->{$seg})) {
         if($Verbose > 1) {printf STDERR "Seg $seg undefined in $_\n";}
         next;
      }
      $currentSeg = $seg;
      $T->{$seg}{KEY}{$key} = $_; 
#print STDERR "KEY $seg\t$T->{$seg}{KEY}{$key}";
      $key++;
    }
    elsif($type == 5) {  $F .= $_; }
    elsif($type == 6 && /<Align /) {
      my ($si, $ti);
      if(/sid="([^\"]*)"/) {$si =$1;}
      if(/tid="([^\"]*)"/)  {$ti =$1;}
      $ALN->{'tid'}{$ti}{'sid'}{$si} ++;
      $ALN->{'sid'}{$si}{'tid'}{$ti} ++;
    }
    elsif($type == 7 && /<Token/) {
      if(/segId="([^"]*)"/i) { $seg=$1; }
      if(!defined($T->{$seg})) {
         printf STDERR "Seg $seg undefined in Token\n";
         next;
      }
      if(/cur="([0-9][0-9]*)"/) {$cur =int($1);}
      if(/tok="([^"]*)"/)   {$T->{$seg}{TOK}{src}{$cur}{tok} = MSunescape($1);}
      if(/space="([^"]*)"/) {$T->{$seg}{TOK}{src}{$cur}{space} = MSunescape($1);}
      if(/id="([^"]*)"/)    {$T->{$seg}{TOK}{src}{$cur}{id} = int($1);}
    }

    elsif($type == 8 && /<Token/) {
      if(/segId="([^"]*)"/i) { $seg=$1; }
      if(!defined($T->{$seg})) {
         printf STDERR "Seg $seg undefined in Token\n";
         next;
      }
      if(/cur="([0-9][0-9]*)"/) {$cur =int($1);}
      if(/tok="([^"]*)"/)   {$T->{$seg}{TOK}{fin}{$cur}{tok} = MSunescape($1);}
      if(/space="([^"]*)"/) {$T->{$seg}{TOK}{fin}{$cur}{space} = MSunescape($1);}
      if(/id="([^"]*)"/)    {$T->{$seg}{TOK}{fin}{$cur}{id} = int($1);}
    }

    if(/<\/FinalText>/) {$type =0; }
    if(/<\/SourceTextChar>/) {$type =0; }
    if(/<\/Events>/) {$type =0; }
    if(/<\/SourceTextChar>/) {$type =0; }
    if(/<\/TranslationChar>/) {$type =0; }
    if(/<\/TargetTextChar>/) {$type =0; }
    if(/<\/FinalTextChar>/) {$type =0; }
    if(/<\/FinalText>/) {$type =0; }
    if(/<\/Alignment>/) {$type =0; }
    if(/<\/SourceToken>/){$type =0; }
    if(/<\/FinalToken>/) {$type =0; }
  }
  close(FILE);

#foreach my $f (sort {$a <=> $b} keys %{$TEXT}) { print STDERR "$TEXT->{$f}{c}" }
#printf STDERR "\n";

  return $T;
}



##########################################################
# Parse Keystroke Log
##########################################################

## map all keystrokes on ins and del
sub KeyLogAnalyse {
  my ($K) = @_;

  my $lastKeyTime=0;
  my $SaveTime= 0;
  my $SaveTime2= 0;
  my $auto = 0;
  my $t = 0;
  my $openSegment = 0;
  my $control = 0;
  foreach my $f (sort {$a <=> $b} keys %{$K}) {
    $_ = $K->{$f};

    if(/Time="([0-9][0-9]*)"/i)   {$t = $1;}
    else { print STDERR "KeyLogAnalyse: No Time in $_\n"; next;}

#printf STDERR "KeyLogAnalyse: $t\n"; 

    if($t <= $lastKeyTime) { $t = $lastKeyTime+1; }

#    if((/<suggestionChosen/i && /which="0"/) || /<decode/i){$lastKeyTime=ResetBuffer($t); $auto = 1;} 
    if(/<decode/i){next;}
    if(/<suggestionsLoaded/i) {if($ReviewSession == 0){$auto = 1;}} 
    elsif(/<suggestionChosen/i) {
       if(/which="0"/){$lastKeyTime=ResetBuffer($t); $auto = 1;} 
    }
    elsif(/<suffixChange/i){$auto = 1;} 
    elsif(/<stopSession/i) {
      RewindToSaveTime($lastKeyTime+1, $SaveTime2);
      $SaveTime2 = $t;
      $SaveTime = $t;
	  $openSegment = 0;
    }
    elsif(/<segmentClosed/) {
    }
    elsif(/<segmentOpened/) {
	RewindToSaveTime($lastKeyTime+1, $SaveTime);
	$openSegment++;
        $SaveTime = $t;
    }
    elsif(/<translated/i || /<drafted/i || /<approved/i || /<rejected/i || (/<keyDown/i &&  /mappedKey="Enter"/ && $control == 1 )) {
        $SaveTime = $t;
        $SaveTime2 = $t;
        if($Verbose) { print STDERR "save:$t\tBuffer saved\n";}
        $control = 0;
    } 
    elsif(/<keyDown/i && /mappedKey="Ctrl"/) {
         $control = 1;
    }
    elsif(/<text/i) {
        if(/deleted="([^"]*)/i) {$lastKeyTime=DeleteText($t, MSunescape($1), $auto);} 
        if($t <= $lastKeyTime) { $t = $lastKeyTime+1; }
        if(/inserted="([^"]*)/i) {$lastKeyTime=InsertText($t, MSunescape($1), $auto);} 
        $auto = 0;
        if ($openSegment == 1){
		$SaveTime = $lastKeyTime+1;
	}
    }
#    else { print STDERR "KeyLogAnalyse: Unknown event $_\n";}

# Plot operations    
    if($Verbose > 3){
      /Type="([^"]*)"/; my $type=$1;
      /Cursor="([^"]*)"/; my $cur=$1;
      print STDERR "$type $cur\t"; 
      for(my $j=0; $j < $TextLength; $j++) {  print STDERR "$TEXT->{$j}{'c'}";}
      print STDERR "\n";
    }
 
  }
  if($SaveTime < $t) {RewindToSaveTime($lastKeyTime+1, $SaveTime)}
}

sub ResetBuffer {
  my ($t) = @_;

  my $s = $_;

  while(defined($KEY->{$t})) {$t++}
  for(my $j=$TextLength-1; $j>=0; $j--) {
#printf STDERR "ResetBuffer: %s %s\n", $j, $TEXT->{$j}{'c'};
    $KEY->{$t}{'t'} = "Adel";
    $KEY->{$t}{'k'} = $TEXT->{$j}{'c'};
    $KEY->{$t}{'c'} = $j;
    $t++;
  }
  $TextLength = 0;

  if($Verbose) {
    my ($x) = $s =~ /Time="([0-9][0-9]*)"/i;
    print STDERR "init:$x\tBuffer initialization\n";
  }
  return $t;
}

sub RewindToSaveTime {
  my ($fint, $transt) = @_;

#my $xxx = '';
#printf STDERR "RewindToSaveTime $fint, $transt $TextLength\n";

  if($TextLength <= 0) {return}

  foreach my $t (sort {$b <=> $a} keys %{$KEY}) {
    if($t < $transt) {last;}

    my $k = $KEY->{$t}{'k'};
    my $c = $KEY->{$t}{'c'};

    if($KEY->{$t}{'t'} =~ /ins/) {
#  printf STDERR "RewindToSaveTime 1: $KEY->{$t}{'c'} $KEY->{$t}{'k'}   $TEXT->{$KEY->{$t}{'c'}}{'c'}\n";
#        if($TEXT->{$c}{'c'} ne $k) {
#            printf STDERR "RewindToSaveTime: $transt $c >$k< ne >$TEXT->{$c}{'c'}< ";
#            foreach my $x (sort {$a <=> $b} keys %{$TEXT}) { if($x >= $TextLength) {last;} printf STDERR "$TEXT->{$x}{'c'}";}
#            printf STDERR "\n";
#        }
        for(my $j=$c; $j<$TextLength-1; $j++) { $TEXT->{$j}{'c'} = $TEXT->{$j+1}{'c'}; }
        $KEY->{$fint}{'t'} = "Adel";
        $KEY->{$fint}{'k'} = $k;
        $KEY->{$fint}{'c'} = $c;
        $fint++;
        $TextLength --;
    }
      
    if($KEY->{$t}{'t'} =~ /del/) {
        for(my $j=$TextLength; $j>$c; $j--) { $TEXT->{$j}{'c'} = $TEXT->{$j-1}{'c'}; }
        $TEXT->{$KEY->{$t}{'c'}}{'c'} = $k;
        $KEY->{$fint}{'t'} = "Ains";
        $KEY->{$fint}{'k'} = $k;
        $KEY->{$fint}{'c'} = $c;
        $fint++;
#  printf STDERR "RewindToSaveTime 2: $KEY->{$t}{'c'} $KEY->{$t}{'k'}   $TEXT->{$KEY->{$t}{'c'}}{'c'}\n";
        $TextLength ++;
    }

  }

 if($Verbose) {
    print STDERR "rwnd:$transt\t\t>";
    for(my $j=0; $j<$TextLength; $j++) { print STDERR "$TEXT->{$j}{'c'}";}
    print STDERR "<\n";
  }


  return $fint;
}



sub InsertText {
  my ($t, $Value, $auto) = @_;
  my ($j, $c, $l);

  if($Value eq '') {return $t;}

  my $s = $_;
  my $X=[split(//, $Value)];

  if($s =~ /CursorPosition="([0-9][0-9]*)"/i) {$c = $1;}
  else { printf STDERR "InsertText1: No Cursor in $s\n";}

# make place for insertion in text 
  for($j=$TextLength; $j > $c; $j--) { $TEXT->{$j+$#{$X}}{'c'} = $TEXT->{$j-1}{'c'}; }

#  insert contents of $X in text 
#print STDERR "InsertText: time:$t Log:$Value($#{$X})\n"; 
  for($j=0; $j <= $#{$X}; $j++) { 
#print STDERR "     time:$t text:$c+$j Log:$j:$X->[$j]\n"; 
    $TEXT->{$c+$j}{'c'} = $X->[$j]; 
    if($auto) { $KEY->{$t}{'t'} = 'Ains';}
    else { $KEY->{$t}{'t'} = "Mins";}
    $KEY->{$t}{'k'} = $X->[$j];
    if(/cursorPosition="([0-9][0-9]*)"/i) {$KEY->{$t}{'c'} = $c+$j;}
#print STDERR "InsertText1: $t\tv:$Value\tchar:$X->[$j]\n";
    $t++;
  }
  $TextLength += $#{$X} +1;

### Debugging
  if($Verbose) {
    my $vt;
    if(/Time="([0-9][0-9]*)"/i)   {$vt = $1;}
    if(/CursorPosition="([0-9][0-9]*)"/i) {$c = $1;}
    if($auto) { print STDERR "Ains:$vt $c\t$Value\t>";}
    else { print STDERR "Mins:$vt $c\t$Value\t>";}
    for($j=0; $j<$TextLength; $j++) { print STDERR "$TEXT->{$j}{'c'}";}
    print STDERR "<\n";
  }
  return $t;
}

## Delete
sub DeleteText {
  my ($t, $Value, $auto) = @_;
  my ($j, $c, $l);

  if($Value eq '') {return $t;}
  my $s = $_;
  if($s =~ /CursorPosition="([0-9][0-9]*)"/i) {$c = $1;}
  else { printf STDERR "InsertText1: No Cursor in $s\n";}

  if($c < 0 || $c >= $TextLength) {
    printf STDERR "WARNING: DeleteText length mismatch: Time:$t TextLength:$TextLength Cursor:$c\n";
  }

  my $X=[split(//, $Value)];

  # check inconsistencies between X (buffer) and TEXT (should be identical)
  my $i =0;
  for($j=$c; $j<=$c+$#{$X}; $j++) {
    if($Value  =~ /\#/) { $X->[$i] = $TEXT->{$j}{'c'};}
    elsif($TEXT->{$j}{'c'} ne $X->[$i]) {

      my $offs = SearchDelChar($TEXT, $j, $X, $i);
      for (my $k=0; $k <$offs; $k++) {unshift(@{$X}, '#')}
      printf STDERR "WARNING Delete time:$t cur:$j inserted:$offs\tLog:$Value($#{$X})\tText:$j:$TEXT->{$j}{'c'}\t$offs\n\t"; 
      for (my $k=$j-10;$k<$j+10;$k++) { 
        if($k >= $TextLength) {last;}
        if($k == $j) {print STDERR " |";} 
        if(defined($TEXT->{$k}{'c'})) { printf STDERR "%s", $TEXT->{$k}{c};}
        if($k == $j) {print STDERR "| ";} 
      }
      print STDERR "\n"; 
      last;
    }
    elsif($Verbose > 3) { print STDERR "WARNING: Deleting time:$t cursor:$j buff:$i:$X->[$i] --- $TEXT->{$j}{'c'}\n";}  
    $i++;
  }
  $l = $#{$X}+1;

  # track deletion in text 
  for($j=$c; $j<$TextLength-$l; $j++) {
    if($j+$l >= $TextLength) { last;}
#printf STDERR "DeleteText3: move %d:%s to %d:%s\n", $j+$l, $TEXT->{$j+$l}{'c'}, $j, $TEXT->{$j}{'c'};
    $TEXT->{$j}{'c'} = $TEXT->{$j+$l}{'c'};
  }

  # deletion sequence in text 
  for($j=$l-1; $j>=0; $j--) {
#printf STDERR "DeleteText3: %s %s\n", $TextLength, $c+$j;
    if($c+$j > $TextLength) {last;}
    if($auto) {$KEY->{$t}{'t'} = 'Adel'}
    else {$KEY->{$t}{'t'} = "Mdel";}
    $KEY->{$t}{'k'} = $X->[$j];
    $KEY->{$t}{'del'} = $Value;
    if($X->[$j] =~ /[\s\!?.]/) { $KEY->{$t}{'new'} = 1}
    else { $KEY->{$t}{'new'} = 0}
    if(/CursorPosition="([0-9][0-9]*)"/i) {$KEY->{$t}{'c'} = $c + $j;}
    $t++;
  }

  if($TextLength > $c+$l) {$TextLength -= $l;}
  else {$TextLength = $c;}

### Debugging
  if($Verbose) {
    my $vt = 0;
    if(/Time="([0-9][0-9]*)"/i)   {$vt = $1;}
    if(/CursorPosition="([0-9][0-9]*)"/i) {$c = $1;}
    if($auto){print STDERR "Adel:$vt $c\t$Value\t>";}
    else{print STDERR "Mdel:$vt $c\t$Value\t>";}
    for($j=0; $j<$TextLength; $j++) { print STDERR "$TEXT->{$j}{'c'}";}
    print STDERR "<\n";
  }
  return $t;
}

##############################################################
# Check whether final Text CHR was correctly reproduced (TEXT) 
##############################################################

sub CheckForward {
  my ($seg) = @_;

  my $keyOff = 0;

#print STDERR "CheckForward: $TextLength\n";

  for (my $f=0; $f<$TextLength; $f++) {
#    if(!defined($CHR->{fin}{$f}) && !defined($TEXT->{$f})) { $TextLength = $f; last;}
    if(!defined($CHR->{fin}{$f})) {
      printf STDERR "$opt_T Segment $seg: CheckForward undefined CHR at cur: $f\tTEXT:>$TEXT->{$f}{c}<\n";
      for(my $j=$f; $f<$TextLength; $f++) {$TEXT->{$f}{'c'} = $TEXT->{$f+1}{'c'};}
      $TextLength = $f;
      last;
#      $TextLength--;
#      next;
    }
    if(!defined($TEXT->{$f})) {printf STDERR "$opt_T Segment $seg: CheckForward undefined TEXT cursor: $f\n";d($CHR->{fin}{$f});last;}
    if(!defined($TEXT->{$f}{c})) {printf STDERR "$opt_T Segment $seg: CheckForward undefined TEXT char:\n";d($TEXT->{$f});}

#     $TEXT->{$f}{'add'} += $keyOff;
    if($CHR->{fin}{$f}{'c'} ne $TEXT->{$f}{'c'}) {
      my $t = SearchSubstring($f);
      printf STDERR "$opt_T Segment $seg: CheckForward unmatched CHR cursor: $f offset:$t >%s<\t>%s<\n", $TEXT->{$f}{'c'}, $CHR->{fin}{$f}{'c'}; 
      printf STDERR "Prod. TEXT:\t"; 
      foreach my $m (sort {$a <=> $b} keys %{$TEXT}) { 
        if($m <= $f-10) {next;} 
        if($m < 0) {next;}
        if($m >= $f+10) {last;} 
        if($m >= $TextLength) {last;} 
        if($m == $f) {printf STDERR "|";} 
        printf STDERR "$TEXT->{$m}{'c'}"; 
        if($m == $f) {printf STDERR "|";} 
      }
      printf STDERR "\n"; 

      if($t > 0) { 
        for(my $j=$TextLength-1; $j>=$f; $j--) {$TEXT->{$j+$t}{'c'} = $TEXT->{$j}{'c'};}
        for(my $j=0; $j<$t; $j++) { $TEXT->{$j+$f}{'c'} = $CHR->{fin}{$j+$f}{'c'};  }
        $TextLength += $t;
        $TEXT->{$f}{'add'} = $t *-1;
        $f+=$t-1;
      }
      if($t < 0) { 
        for(my $j=$f; $j<$TextLength+$t; $j++) { $TEXT->{$j}{'c'} = $TEXT->{$j-$t}{'c'};}
        $TextLength += $t;
        $TEXT->{$f}{'add'} = $t *-1;
      }
      $keyOff += $t;

      printf STDERR "New   TEXT:\t"; 
      foreach my $m (sort {$a <=> $b} keys %{$TEXT}) { 
        if($m <= $f-10) {next;} 
        if($m < 0) {next;}
        if($m >= $f+10) {last;} 
        if($m >= $TextLength) {last;} 
        if($m == $f) {printf STDERR "|";} 
        printf STDERR "$TEXT->{$m}{'c'}"; 
        if($m == $f) {printf STDERR "|";} 
      }
      printf STDERR "\n"; 
      printf STDERR "Final TEXT:\t"; 
      foreach my $m (sort {$a <=> $b} keys %{$CHR->{fin}}) { 
        if($m <= $f-10) {next;} 
        if($m < 0) {next;}
        if($m >= $f+10) {last;} 
        if($m >= $TextLength) {last;} 
        if($m == $f) {printf STDERR "|";} 
        print STDERR "$CHR->{fin}{$m}{'c'}"; 
        if($m == $f) {printf STDERR "|";} 
      }
      printf STDERR "\n"; 
#      d($TEXT->{$f});
      next;
    }
  }
}

sub SearchSubstring{
  my ($f) = @_;

  for (my $t=0; $t<5; $t++) { 
    for (my $c=0; $c<5; $c++) { 
      if(matchSubstring($f+$t, $f+$c)) { return $c-$t;}
  }  }  
  return 0;
}

sub matchSubstring{
  my ($txt, $chr) = @_;

  for (my $i=0; $i < 5; $i++) {
     if(!defined($CHR->{fin}{$chr+$i}) || 
        !defined($TEXT->{$txt+$i}) ||
        ($CHR->{fin}{$chr+$i}{'c'} ne $TEXT->{$txt+$i}{'c'})) {return 0;}
  } 
  return 1;
}

sub SearchDelChar {
   my ($Text, $txt, $X, $x) = @_;

  for (my $t=0; $t<5; $t++) {
    my $found = 1;
    for (my $c=0; $c+$x<=$#{$X}; $c++) {
#print STDERR "SearchDelChar: txt:$txt X:$#{$X} x:$x t:$t c:$c $TEXT->{$txt+$t}{c} $X->[$c+$x]\n";
       if(!defined($TEXT->{$txt+$t+$c}) ||
         ($X->[$c+$x] ne $TEXT->{$txt+$t+$c}{'c'})) {$found = 0;last;}
    }
    if($found == 1) {return $t}
  }
  return 0;
}



##########################################################
# Map CHR gaze and fixations on ST
##########################################################

sub MapTok2Chr {
  my $id=-1;

# assign token ID to char positions
  foreach my $cur (sort {$a <=> $b} keys %{$CHR->{fin}}) { 
    if(defined($TOK->{fin}{$cur})) {
      $CHR->{fin}{$cur}{'tok'} = $TOK->{fin}{$cur}{tok}; 
      $id=$TOK->{fin}{$cur}{'id'};
#print STDERR "MapTok2Chr cur:$cur id:$id\n";
#d($TOK->{fin}{$cur});
    }
    $CHR->{fin}{$cur}{'id'} = $id;
  }

  $id=-1;
  foreach my $cur (sort {$a <=> $b} keys %{$CHR->{src}}) { 
#print STDERR "Map $k $s\n";
    if(defined($TOK->{src}{$cur})) {
      $CHR->{src}{$cur}{'tok'} = $TOK->{src}{$cur}{tok}; 
      $id=$TOK->{src}{$cur}{id};
    }
    $CHR->{src}{$cur}{'id'} = $id;
  }
}


##########################################################
# Map CHR gaze and fixations on ST
##########################################################

sub MapSource {
  my ($seg) = @_;
  my ($cur);

  ## initialise id in TEXT and CHR
  my $n = 0;
  my $c = 0;

### map token id from Final text ($CHR->{fin}{$cur}{'id'}) on ireconstructed TEXT
  foreach $cur (sort {$a <=> $b} keys %{$CHR->{fin}}) { 
    if(!defined($TEXT->{$cur})) {printf STDERR "$opt_T Segment $seg: MapSource undefined TEXT cur: $cur\n"; next;}
    if(!defined($TEXT->{$cur}{'c'})) {
      printf STDERR "$opt_T Segment $seg: MapSource undefined TEXT char at cur: $cur\n";
      next;
    }
    if(!defined($CHR->{fin}{$cur}{'c'})) {
      printf STDERR "$opt_T Segment $seg: MapSource undefined CHR char at cur: $cur\n";
      next;
    }
    if($CHR->{fin}{$cur}{'c'} ne $TEXT->{$cur}{'c'}) {
      print STDERR "$opt_T Segment $seg: MapSource unmatched CHR cursor: $cur: TXT:>$TEXT->{$cur}{'c'}<\tCHR:>$CHR->{fin}{$cur}{'c'}<\n"; 
    }
    $TEXT->{$cur}{'id'} = $CHR->{fin}{$cur}{'id'};
  }

  ## make sure all TEXT chars have an id 
  ## assume previous id if not
  $n=0;
  foreach $cur (sort {$a <=> $b} keys %{$TEXT}) { 
    if($cur>=$TextLength) {last;}
    if($cur<0) {next;}
    
    if(!defined($TEXT->{$cur}{'id'})) {
      print STDERR "$opt_T Segment $seg: MapSource undefined TEXT\t>$TEXT->{$cur}{'c'}< setting cur:$cur to id:$n\n";
      $TEXT->{$cur}{'id'} = $n;
    } 
    else {
      $n = $TEXT->{$cur}{'id'};
    }
  }

  ## initialise word id in Eye data on ST
  foreach $cur (sort {$a <=> $b} keys %{$EYE}) { 
    if($EYE->{$cur}{'w'} != 1) {next;}
    $c = $EYE->{$cur}{'c'};
    $EYE->{$cur}{'id'}= $CHR->{src}{$c}{'id'}; 
  }

  ## initialise word id in Fix data on ST
  foreach $cur (sort {$a <=> $b} keys %{$FIX}) { 

    if($FIX->{$cur}{'w'} != 1) {next;}
    $c = $FIX->{$cur}{'c'};
    $FIX->{$cur}{'sid'}= $CHR->{src}{$c}{'id'}; 
  }
}

sub UnmapTEXT {

  foreach my $f (sort {$b <=> $a} keys %{$TEXT}) {
    if(!defined($TEXT->{$f}{'add'})) { next;}
    my $t = $TEXT->{$f}{'add'};

      printf STDERR "Map  TEXT:\t";
      foreach my $m (sort {$a <=> $b} keys %{$TEXT}) {
        if($m <= $f-10) {next;}
        if($m < 0) {next;}
        if($m >= $f+10) {last;}
        if($m >= $TextLength) {last;}
        if($m == $f) {printf STDERR "|";}
        printf STDERR "$TEXT->{$m}{'c'}";
        if($m == $f) {printf STDERR "|";}
      }
      printf STDERR "\n";

    if($t > 0) {
      my $id = $TEXT->{$f}{id};
      for(my $j=$TextLength-1; $j>=$f; $j--) {$TEXT->{$j+$t} = $TEXT->{$j}; $TEXT->{$j}={}}
      for(my $j=0; $j<$t; $j++) { 
        $TEXT->{$j+$f}{'c'} = '#';  
        $TEXT->{$j+$f}{'id'} = $id;
      }
      $TextLength += $t;
      $f+=$t-1;
    }
    if($t < 0) {
      for(my $j=$f; $j<$TextLength+$t; $j++) { $TEXT->{$j} = $TEXT->{$j-$t}; $TEXT->{$j-$t}={}}
      $TextLength += $t;
    }

    printf STDERR "Key  TEXT:\t";
    foreach my $m (sort {$a <=> $b} keys %{$TEXT}) {
        if($m <= $f-10) {next;}
        if($m < 0) {next;}
        if($m >= $f+10) {last;}
        if($m >= $TextLength) {last;}
        if($m == $f) {printf STDERR "|";}
        printf STDERR "%s", $TEXT->{$m}{'c'};
        if($m == $f) {printf STDERR "|";}
      }
      printf STDERR "\n";
  }

####################################
#  foreach my $f (sort {$a <=> $b} keys %{$TEXT}) { printf STDERR "TEXT:\t cur:$f\tid:$TEXT->{$f}{'id'} $TEXT->{$f}{'c'}\n";}

}


############################################################
# Key-to-ST mapping
############################################################

sub MapTarget {
  my ($k, $j, $c);
  my ($F, $E);

  if(defined($FIX)) { $F = [sort {$b <=> $a} keys %{$FIX}];}
  if(defined($EYE)) { $E = [sort {$b <=> $a} keys %{$EYE}];}
  my $e=0; # time index of last eye event
  my $f=0; # time index of last fix event

  my $id=-1; 

  if($Verbose > 1) {print STDERR "MapTarget Backwards:\n";}
  ## loop through keystrokes from end to start

  foreach $k (sort {$b <=> $a} keys %{$KEY}) {
    $c = $KEY->{$k}{'c'};

    if($Verbose > 1) {
      print STDERR "$KEY->{$k}{t}:$k\t$TextLength\t";
      for(my $j=0; $j<$TextLength; $j++) { print STDERR "$TEXT->{$j}{'c'}";}
      print STDERR "\n";
    }


    ## Assign Word ID to FIX samples in target window between time $f and time $k
    while($f <= $#{$F} && $F->[$f] > $k) {
      if($FIX->{$F->[$f]}{'w'} != 2) { $f++; next;}

      my $cur = $FIX->{$F->[$f]}{'c'}; # cursor
      if($cur >= $TextLength) {
        if($Verbose >1 ) { printf STDERR "Target FIX at time:$F->[$f] cur:$FIX->{$F->[$f]}{'c'} >= TEXT:$TextLength\n"; }
        $cur = $TextLength-1;
      }
      if($cur < 0) { $cur = 0;}
      if(!defined($TEXT->{$cur}{'id'})) { printf STDERR "Fix time $k Undef id in TEXT cur:$cur len:$TextLength\n"; }

      ## This is the target ==> source mapping
      $FIX->{$F->[$f]}{'tid'} = $TEXT->{$cur}{'id'}; 
      $f++; 
    }

    ## Assign Word ID to EYE samples in target window between time $e and time $k
    while($e <= $#{$E} && $E->[$e] > $k) {
      my $e1 = $E->[$e];
      if($EYE->{$e1}{'w'} == 2) {
        my $cur = $EYE->{$e1}{'c'};

        if($cur > $TextLength) {
          if($Verbose > 1) {printf STDERR "Eye time:$e1 target cur:$cur >= TEXT:$TextLength\n"; }
 	  $cur = $TextLength-1;
        }
        if($cur < 0) { $cur = 0;}
        if(!defined($TEXT->{$cur}{'id'})) { 
           if($Verbose > 1) {printf STDERR "Eye time $k target id in TEXT cur:$cur len:$TextLength\n"; }
           $cur = $TextLength-1;
        }
        $EYE->{$e1}{'id'} = $TEXT->{$cur}{'id'}; 
      }
      $e++; 
    }

###########################################
# Key -> word mapping
###########################################

    if($KEY->{$k}{'t'} =~ /ins/) {
# Check Consistency of Keys and TEXT
      if(!defined($TEXT->{$c}{'c'})) {printf STDERR "MapTarget time:$k undefined $KEY->{$k}{'t'} char:$c $KEY->{$k}{'k'}\n"; next;}
      if(!defined($TEXT->{$c}{'id'})){printf STDERR "MapTarget time:$k undefined $KEY->{$k}{'t'} id:$c $KEY->{$k}{'k'}\n"; next;}

      if($KEY->{$k}{'k'} ne $TEXT->{$c}{'c'} && $TEXT->{$c}{'c'} ne '#') {
        printf STDERR "MapTarget time:$k no match cursor:$c KEY>%s<\tTEXT:>%s<\n", $KEY->{$k}{'k'}, $TEXT->{$c}{'c'}; 
      }

# remember last id for deletions
      $id = $KEY->{$k}{'id'} = $TEXT->{$c}{'id'};
#print STDERR "Mapping: $k $c $id\n";
      for($j=$c; $j<$TextLength; $j++) { $TEXT->{$j} = $TEXT->{$j+1}; delete($TEXT->{$j+1});}
      $TextLength--;

    }

    elsif($KEY->{$k}{'t'} =~ /del/) {

## delete the only char in TEXT
      if($TextLength <= 0) { }
## delete last char in TEXT
      elsif(!defined($TEXT->{$c}) || !defined($TEXT->{$c}{id})) {
        if(defined($TEXT->{$c-1}) && defined($TEXT->{$c-1}{id})) { $id = $TEXT->{$c-1}{'id'}; }
        else { printf STDERR "MapTarget time:$k undefined $KEY->{$k}{'t'} cur:%s/$TextLength %s\n", $c-1, $KEY->{$k}{'k'}; }
      }
## delete first char in TEXT
      elsif(!defined($TEXT->{$c-1}) || !defined($TEXT->{$c-1}{id})) {
        if(defined($TEXT->{$c}) && defined($TEXT->{$c}{id})) { $id = $TEXT->{$c}{'id'}; }
        else { printf STDERR "MapTarget time:$k undefined $KEY->{$k}{'t'} cur:%s/$TextLength %s\n", $c, $KEY->{$k}{'k'};}
      }
## deletion in the middle of a word
      elsif($TEXT->{$c-1}{'id'} == $TEXT->{$c}{'id'}) { $id = $TEXT->{$c}{'id'}; }
## delete between two words: assume it's the from the suffix
      else { $id = $TEXT->{$c-1}{'id'}; }

#my $lid = -1;
#my $nid = -1;
#if(!defined($KEY->{$k}{del})) {$KEY->{$k}{del} = 'xx'}
#if(defined($TEXT->{$c-1}{id})) {$lid = $TEXT->{$c-1}{'id'}}
#if(defined($TEXT->{$c+1}{id})) {$nid = $TEXT->{$c+1}{'id'}}
#printf STDERR "DELETE: id:$lid $id $nid KEY:$KEY->{$k}{new} Value:$KEY->{$k}{del}\n";
      if(!defined($KEY->{$k}{new})) {$KEY->{$k}{new} = 0}

      for($j=$TextLength; $j>$c; $j--) { $TEXT->{$j} = $TEXT->{$j-1};$TEXT->{$j-1}= {};}
      $KEY->{$k}{'id'}=$TEXT->{$c}{'id'} = $id +  $KEY->{$k}{new};
      $TEXT->{$c}{'c'} = $KEY->{$k}{'k'};

      $TextLength++;
    }
    else { printf STDERR "ERROR undefined KEYSTROKE:\n"; }
  }

### fixations after end of typing
  while($f <= $#{$F}) {
    if($FIX->{$F->[$f]}{'w'} == 2) {
      my $cur = $FIX->{$F->[$f]}{'c'}; 
      $FIX->{$F->[$f]}{'tid'} = $TEXT->{$cur}{'id'}; 
    }
    $f++;
  }

### gaze samples after end of typing
  while($e <= $#{$E}) {
    if($EYE->{$E->[$e]}{'w'} == 2) {
      my $cur = $EYE->{$E->[$e]}{'c'};
      $EYE->{$E->[$e]}{'tid'} = $TEXT->{$cur}{'id'}; 
    }
    $e++; 
  }
}


################################################
## CHECK whether backwards reproduces TranslationText
################################################

sub CheckBackward {

  foreach my $k (sort {$a <=> $b} keys %{$CHR->{tra}}) {
    if(!defined($CHR->{tra}{$k}))     {
      print STDERR "CheckBackward CHR: $k $CHR->{tra}{$k}\n"; 
      next;
    }
    if($CHR->{tra}{$k}{'c'} ne $TEXT->{$k}{'c'}) {
      print STDERR "CheckBackward CHR: $k $TEXT->{$k}{'c'}, $CHR->{tra}{$k}{'c'}\n"; 
      next;
    }
  }
}

################################################
#  PRINTING
################################################

sub FixModTable {
  my ($seg) = @_;

  my ($m, $ord);

  foreach my $t (sort {$a<=>$b} keys %{$FIX}) {

    if(!defined($FIX->{$t}{sid}) && !defined($FIX->{$t}{tid})) { next; }

    if($FIX->{$t}{w} == 1) {
      $FIX->{$t}{tid} = '';
      my $id=$FIX->{$t}{'sid'};
      if(defined($ALN->{'sid'}) && defined($ALN->{'sid'}{$id})) { 
        my $k = 0;
        foreach my $sid (sort  {$a <=> $b} keys %{$ALN->{'sid'}{$id}{'tid'}}) {
          if($k >0) {$FIX->{$t}{tid} .= "+";}
          $FIX->{$t}{tid} .= $sid;
          $k++;
        }
      }  
    }
    elsif ($FIX->{$t}{w} == 2) {
      $FIX->{$t}{sid} = '';
      my $id=$FIX->{$t}{'tid'};
      if(defined($ALN->{'tid'}) && defined($ALN->{'tid'}{$id})) {  
        my $k = 0;
        foreach my $sid (sort  {$a <=> $b} keys %{$ALN->{'tid'}{$id}{'sid'}}) {
          if($k >0) {$FIX->{$t}{sid} .= "+";}
          $FIX->{$t}{sid} .= $sid;
          $k++;
        }
      }
    } 
    else {next;}

    $FIXATIONS->{$fixations++} = "    <Fix time=\"$t\" win=\"$FIX->{$t}{w}\" cur=\"$FIX->{$t}{c}\" dur=\"$FIX->{$t}{d}\" segId=\"$seg\" sid=\"$FIX->{$t}{sid}\" tid=\"$FIX->{$t}{tid}\" />\n";
  }

  foreach my $t (sort {$a<=>$b} keys %{$KEY}) {

    if(!defined($KEY->{$t}{id})) { 
      print STDERR "KEY Undefined $t\n";
      d($KEY->{$t});
      next;
    }

    my $s = '';
    if(defined($ALN->{'tid'}) && defined($ALN->{'tid'}{$KEY->{$t}{'id'}})) { 
      my $k = 0;
      foreach my $sid (sort  {$a <=> $b} keys %{$ALN->{'tid'}{$KEY->{$t}{'id'}}{'sid'}}) {
        if($k >0) {$s .= "+";}
        $s .= $sid;
        $k++;
      }
    }
    my $chr = MSescape($KEY->{$t}{k});
    $MODIFICATIONS->{$modifications++} = "    <Mod time=\"$t\" type=\"$KEY->{$t}{t}\" cur=\"$KEY->{$t}{c}\" chr=\"$chr\" segId=\"$seg\" sid=\"$s\" tid=\"$KEY->{$t}{id}\" />\n";
  }
}

sub Segments {
  my ($T) = @_;

  my $H;

  foreach my $seg (keys %{$T}) {
    foreach my $key (keys %{$T->{$seg}{KEY}}) {
      my $str = $T->{$seg}{KEY}{$key};
      if(($str =~ /<segmentOpened/) || ($str =~ /<segmentClosed/) || ($str =~ /<stopSession/i)){  
          my ($t) = $str =~ /time="([^"]*)/;
          $H->{$t} =  $str;
  } } }

  my $start = -1;
  my $end = -1;
  my $n=0;
  my $seg = 0;
  foreach my $t (sort {$a<=>$b} keys %{$H}) {
    if($H->{$t} =~ /<segmentOpened/) {
      if($start != -1) {
        $end = $t-1;
        $SEGMENTS->{$n++} = "    <Seg segId=\"$seg\" open=\"$start\" close=\"$end\"/>\n";
#print STDERR "Segments no close";
      }
      ($seg) = $H->{$t} =~ /segment-([0-9][0-9]*)/;
#print STDERR "Segment opened $seg\t$H->{$t} ";
      if(!defined($seg)) {print STDERR "Unspecified segment $H->{$t}\n";}
      $start = $t;
    }
    else { 
      if($start != -1) {$SEGMENTS->{$n++} = "    <Seg segId=\"$seg\" open=\"$start\" close=\"$t\" />\n";}
      $start = -1;
    }

  }
}


sub PrintTranslog {
  my ($fn) = @_;
  my $m;

  open(FILE, '>:encoding(utf8)', $fn) || die ("cannot open file $fn");

  foreach my $k (sort {$a<=>$b} keys %{$TRANSLOG}) { 
    if($TRANSLOG->{$k} =~ /<\/logfile>/) {last; }
    print FILE "$TRANSLOG->{$k}"; 
  }

  print FILE "  <Segments>\n";
  foreach my $k (sort {$a<=>$b} keys %{$SEGMENTS}) { print FILE "$SEGMENTS->{$k}"; }
  print FILE "  </Segments>\n";
  print FILE "  <Fixations>\n";
  foreach my $k (sort {$a<=>$b} keys %{$FIXATIONS}) { print FILE "$FIXATIONS->{$k}"; }
  print FILE "  </Fixations>\n  <Modifications>\n";
  foreach my $k (sort {$a<=>$b} keys %{$MODIFICATIONS}) { print FILE "$MODIFICATIONS->{$k}"; }
  print FILE "  </Modifications>\n<\/logfile>\n";
  close(FILE);
}

