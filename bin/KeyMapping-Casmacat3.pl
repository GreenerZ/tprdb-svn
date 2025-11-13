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
  "  -s verbose segment\n".
  "  -h this help \n".
  "\n";

use vars qw ($opt_O $opt_T $opt_v $opt_s $opt_h);

use Getopt::Std;
getopts ('T:O:v:t:s:h');


my $ALN = undef;
my $FIX = undef;
my $EYE = undef;
my $KEY = undef;
my $CHR = undef;
my $TOK = undef;
my $TEXT = undef;
my $EXT = undef;

my $TRANSLOG = {};
my $Verbose = 0;
my $ReviewSession = 0;

## for printing
my $FIXATIONS = {};
my $fixations =0;
my $MODIFICATIONS = {};
my $SEGMENTS = {};
my $modifications =0;
my $VerboseSegment =0;
my $Task = "PE";

## Key mapping
my $TextLength = 0;

die $usage if defined($opt_h);
die $usage if not defined($opt_T);
die $usage if not defined($opt_O);

if (defined($opt_v)) {$Verbose = $opt_v};
if (defined($opt_s)) {$VerboseSegment = $opt_s};

  my $T = ReadTranslog($opt_T);
  ## produce segment open/close events
  Segments($T);

#my $xxx =0;
  my $Verbose1=$Verbose; 
  foreach my $seg (sort {$a <=> $b} keys %{$T}) { 
    $FIX=$EYE=$KEY=$CHR=$TOK=$TEXT={};
    $FIX=$EYE=$KEY=$CHR=$TOK=$TEXT=undef;
	$Verbose = $Verbose1;
	if($VerboseSegment == $seg) {$Verbose=1};

#print STDERR "Editing: $Task\n";
    if(!defined($T->{$seg}{SEG}{1})) { print STDERR "$opt_T: Segment $seg without Source\n"; next;}
    if($Task =~/post/i && !defined($T->{$seg}{SEG}{2})) { print STDERR "$opt_T: Segment $seg without Target\n"; next;}
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
    elsif($Task =~ /trans/) {$S = [split(//, " ")];}
#    else {$S = [split(//, "")];}
    else {$S = [split(//, $T->{$seg}{SEG}{2}{text})];}
	
    $TextLength = $#{$S}+1;
	
#printf STDERR "ZZZ $TextLength\t%f\t%f\n", $#{$S}+1, scalar($S);
    for (my $i = 0; $i<=$#{$S}; $i++) { $CHR->{tra}{$i}{'c'} = $S->[$i];}
    for (my $i = 0; $i<=$#{$S}; $i++) { $TEXT->{$i}{'c'} = $S->[$i];}

#
    $S = [split(//, $T->{$seg}{SEG}{3}{text})];
    for (my $i = 0; $i<=$#{$S}; $i++) { $CHR->{fin}{$i}{'c'} = $S->[$i];}
#    if($Task =~ /trans/) {for (my $i = 0; $i<=$#{$S}; $i++) { $CHR->{fin}{$i+1}{'c'} = $S->[$i];} $CHR->{fin}{0}{'c'} =' ';}
#    else {for (my $i = 0; $i<=$#{$S}; $i++) { $CHR->{fin}{$i}{'c'} = $S->[$i];}}
 
    $EYE=$T->{$seg}{EYE};
    $FIX=$T->{$seg}{FIX};
    $TOK=$T->{$seg}{TOK};

    KeyLogAnalyse($T->{$seg}{KEY});
	
    MapTok2Chr();
    MapSource($seg);
    MapTarget();

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
  $in =~ s/&#10;/\n/g;
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
  my $WindowWidth = 0;
  while(defined($_ = <FILE>)) {
    $TRANSLOG->{$log++} = $_;

    if(/<Languages/ && /review="true"/i) { $ReviewSession = 1;}
    if(/<Languages/ && /task="([^"]*)"/i) { $Task = $1;}

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
	
    if(/<resize /i &&  /width="([0-9]*)"/){$WindowWidth = $1; }

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
           if($Verbose >  3) {printf STDERR "Seg undefined $seg\n";}
           next;
         }
      }

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

      if($T->{$seg}{EYE}{$time}{'xr'} < $WindowWidth/2 && $T->{$seg}{EYE}{$time}{'xl'} < $WindowWidth/2) {$T->{$seg}{EYE}{$time}{'w'} = 1;}
      elsif($T->{$seg}{EYE}{$time}{'xr'} > $WindowWidth/2 && $T->{$seg}{EYE}{$time}{'xl'} > $WindowWidth/2) {$T->{$seg}{EYE}{$time}{'w'} = 2;}
      else{$T->{$seg}{EYE}{$time}{'w'} = 0;}
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
      }

      if(/TTime="([0-9][0-9]*)"/i)    {$T->{$seg}{FIX}{$time}{'tt'} = $1;}
      if(/offset="([0-9][0-9]*)"/i){$T->{$seg}{FIX}{$time}{'c'} = $1;}
      else {$T->{$seg}{FIX}{$time}{'c'} = 0;}
      if(/Duration="([0-9][0-9]*)"/ii)   {$T->{$seg}{FIX}{$time}{'d'} = $1;}
      else {$T->{$seg}{FIX}{$time}{'d'} = 0;}
      if(/X="([-0-9][0-9]*)"/i)     {$T->{$seg}{FIX}{$time}{'x'} = $1;}
      else {$T->{$seg}{FIX}{$time}{'x'} = 0;}
      if(/Y="([-0-9][0-9]*)"/i)     {$T->{$seg}{FIX}{$time}{'y'} = $1;}
      else {$T->{$seg}{FIX}{$time}{'y'} = 0;}
      if($T->{$seg}{FIX}{$time}{'x'} < $WindowWidth/2) {$T->{$seg}{FIX}{$time}{'w'} = 1;}
      elsif($T->{$seg}{FIX}{$time}{'x'} >= $WindowWidth/2) {$T->{$seg}{FIX}{$time}{'w'} = 2;}

    }
    elsif($type == 4 && /<stopSession/i) {
      foreach my $seg ( keys %{$T}) {
           $T->{$seg}{KEY}{$key} = $_;
           $key++;
       }
    }
    elsif($type == 4 && (/<text/i  || /<segmentOpened/ || /<segmentClosed/ || /<suggestionChosen/i || /<suggestionsLoaded/i || /<suffixChange/i || /<translated/i || /<drafted/i || /<approved/i || /<rejected/i || /<keyDown/i)) {  
      $seg = '';
      if(/elementId="([^"]*)"/i) { ($seg) = $1 =~ /segment-([0-9][0-9]*)/; }
      if ($seg eq '' ) {print STDERR "text: undefined seg $_";}
      if(!defined($T->{$seg})) {
         if($Verbose) {printf STDERR "Seg $seg undefined in $_\n";}
         next;
      }
      $currentSeg = $seg;
      $T->{$seg}{KEY}{$key} = $_; 
#print STDERR "KEY $seg\t$T->{$seg}{KEY}{$key}";
      $key++;
    }
	
    elsif($type == 4 && (/<ILfocus / || /<ILtext/)) {
      if(/time="([^"]*)"/i)  {$time =$1;}
      if($time < 0) {next;}
      if(/title="([^"]*)"/i)  {$EXT->{$time}{title} = $1;}
      if(/value="([^"]*)"/i)  {$EXT->{$time}{value} = $1;}
      if(/edition="([^"]*)"/i){$EXT->{$time}{edition} = $1;}
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
  my $auto = 0;
  my $t = 0;

  foreach my $f (sort {$a <=> $b} keys %{$K}) {
    $_ = $K->{$f};

    if(/Time="([0-9][0-9]*)"/i)   {$t = $1;}
    else { print STDERR "KeyLogAnalyse: No Time in $_\n"; next;}
#print STDERR "KeyLogAnalyse:$_\n";

    if($t <= $lastKeyTime) { $t = $lastKeyTime+1; }
	else {$lastKeyTime = $t}

	my ($Segment) = $_ =~ /elementId="([^"]*)"/;
	
    if(/<suggestionsLoaded/i) {if($ReviewSession == 0){$auto = 1;}} 
    elsif(/<suggestionChosen/i) {
       if($Verbose) {print STDERR "suggestionChosen:$Segment textLength:$TextLength\n";}
       if(/which="0"/){
	     $lastKeyTime=ResetBuffer($t);
		 $auto = 1;
       } 
    }
#    elsif(/<segmentOpened/i){$SaveTime = 0} 
    elsif(/<suffixChange/i){$auto = 1;} 
    elsif(/<stopSession/i) {$lastKeyTime=RewindToSaveTime($lastKeyTime, $SaveTime);}
    elsif(/<translated/i || /<drafted/i || /<approved/i || /<rejected/i ) {
        $SaveTime = $t;
        if($Verbose) { 
          print STDERR "save:$t\t$Segment\t>";
          my $j=0;
          while (defined($TEXT->{$j})) { print STDERR "$TEXT->{$j}{'c'}"; $j++;}
          print STDERR "<\n";
		}
    } 
    elsif(/<text/i) {
  		if(/edition="manual"/ ||  /edition="sourceCopied"/ || /edition="searchReplace"/) {$auto = 0;}
 		else {$auto = 1;}
        my $txt = '';
        my $seg = '';
		if(/previous="([^"]*)/i) {$seg = MSunescape($1);}
		else {printf STDERR "InsertText1: No previous attribute in $_\n";}

#print STDERR "Match vorher time $t\t$Verbose\n";
       for(my $k=0; $k<$TextLength; $k++) {$txt .= "$TEXT->{$k}{'c'}";}
       $lastKeyTime=RepairSegTEXT($seg, $txt, $lastKeyTime);

		my $cursor = 0;
        if(/CursorPosition="([0-9][0-9]*)"/i) {$cursor = $1;}
        else { printf STDERR "InsertText1: No Cursor in $_\n";}
#        if($Task =~/trans/i) {$cursor -= 1;}

#print STDERR "Match vorher:$TextLength\t$_\n";
        if(/deleted="([^"]*)/i) {$lastKeyTime=DeleteText($lastKeyTime, MSunescape($1), $cursor, $auto);} 
        if(/inserted="([^"]*)/i) {$lastKeyTime=InsertText($lastKeyTime, MSunescape($1), $cursor, $auto);} 
        $auto = 0;
#print STDERR "Match nachher time $t\t$TextLength\n";

        $txt = '';
        $seg = '';
        for(my $k=0; $k<$TextLength; $k++) {if(defined($TEXT->{$k})){$txt .= "$TEXT->{$k}{'c'}";}}
        if(/text="([^"]*)/i) {$seg = MSunescape($1);}
		else {printf STDERR "InsertText1: No text attribute in $_\n";}
		
        $lastKeyTime=RepairSegTEXT($seg, $txt, $lastKeyTime);
    }

# Plot operations    
    if($Verbose > 3){
      print STDERR "   $t\t\t ";
#      for(my $j=0; $j < $TextLength; $j++) {  print STDERR "$TEXT->{$j}{'c'}";}
      my $j=0;
      while (defined($TEXT->{$j})) { print STDERR "$TEXT->{$j}{'c'}"; $j++;}
      print STDERR "\n";
    }
  }
#  if($SaveTime < $t && $SaveTime != 0) {RewindToSaveTime($lastKeyTime+1, $SaveTime)}
  return $t;
}

## update TEXT with previous 
sub RepairSegTEXT {
	my ($t1, $t2, $time) =  @_;

	if($t1 eq $t2) { return $time}
#    print STDERR "RepairSegTEXT previous/text mismatch:$time\n\t>$t2<\n\t>$t1<\n";
	
    my $T1=[split(//, $t1)];
	my $T2=[split(//, $t2)];

    my $x = $#{$T1}+1;	
	for(my $j =0; $j <= $#{$T1}; $j++) { if ($j > $#{$T2} || $T1->[$j] ne $T2->[$j]) {$x=$j; last}}

    my $s1=$#{$T1}; 
    my $s2=$#{$T2};
    while($s1>$x && $s2>$x) { if ($T1->[$s1] ne $T2->[$s2]) {last;}  $s1--;$s2--;}
    if($Verbose) {
        print STDERR "RepairSegTEXT previous/text mismatch:$time\tPrefix:$x\tsuffix last:$s1\tsuffix this:$s2\n";
		print STDERR "\tGOAL:\t>$t1<\n\tTEXT:\t>$t2<\n";
    }
    if($s2 >= $x) {
	    my $del = '';
        for(my $j = $x; $j <= $s2; $j++) { $del .= "$T2->[$j]";}
        if($Verbose) {print STDERR "***Del:$x-$s2\t>$del<\n";}
#print STDERR "***Del:$x-$s2\t>$del<\n";
        $time=DeleteText($time+1, $del, $x, -1); 
    } 
    if($s1 >= $x) {
	    my $ins = '';
        for(my $j = $x; $j <= $s1; $j++) { $ins .= "$T1->[$j]";}
        if($Verbose) {print STDERR "***Ins:$x-$s1\t>$ins<\n";}
#print STDERR "***Ins:$x-$s1\t>$ins<\n";
		$time=InsertText($time+1, $ins, $x, -1);
    }
	return $time;
}


## update TEXT with previous 
sub RepairSegTEXT2 {
	my ($t1, $t2, $time) =  @_;

    my $T1=[split(//, $t1)];
	my $T2=[split(//, $t2)];

    my $x=-1;	
	for(my $j =0; $j < $#{$T1}; $j++) { if ($j > $#{$T2} || $T1->[$j] ne $T2->[$j]) {$x=$j; last}}

	if($x != -1) {
	  my $s1=$#{$T1}; 
	  my $s2=$#{$T2};
	  my $str1=''; 
	  my $str2='';
      while($s1>=$x && $s2>=$x) { if ($T1->[$s1] ne $T2->[$s2]) {last;} $str2 = "$T1->[$s1]$str2"; $s1--;$s2--;}
      if($Verbose && ($s1 >= $x || $s2 >= $x)) {
        for(my $j = 0; $j < $#{$T1}; $j++) { if ($j > $#{$T2} || $T1->[$j] ne $T2->[$j]) {last;}; $str1 .= "$T1->[$j]";}
        print STDERR "RepairSegTEXT previous/text mismatch:$time\tPrefix:$x\tsuffix last:$s1\tsuffix this:$s2\n";
		print STDERR "\tGOAL:\t$t1\tTEXT:\t$t2";
        print STDERR "\tPrefix:\t$str1\n\tSuffix\t$str2\n";
      }
      my ($ins, $del);
      $del = '';
      $ins = '';
      if($s2 >= $x) {
        for(my $j = $x; $j <= $s2; $j++) { $del .= "$T2->[$j]";}
        if($Verbose) {print STDERR "\tinsert:$x-$s2:$del\n";}
        $time=DeleteText($time+1, $del, $x, -1); 
      } 
      if($s1 >= $x) {
        for(my $j = $x; $j <= $s1; $j++) { $ins .= "$T1->[$j]";}
        if($Verbose) {print STDERR "\tdelete:$x-$s1:$ins\n";}
		$time=InsertText($time+1, $ins, $x, -1);
      }
	  ### Debugging
#      print STDERR "REP TEXT:\t";
#      for(my $k=0; $k<$TextLength; $k++) {
#	    if(defined($TEXT->{$k})){ print STDERR "$TEXT->{$k}{'c'}";} else {print STDERR "TEXT $k undefined\n"}
#      }
#	  print STDERR "\n";
#      print STDERR "Del TEXT:\t>$del<\n";
#	  print STDERR "Ins TEXT:\t>$ins<\n"; 
	###
	}
	return $time;
}

sub ResetBuffer {
  my ($t) = @_;

  my $s = $_;

  while(defined($KEY->{$t})) {$t++}
  for(my $j=$TextLength-1; $j>=0; $j--) {
#printf STDERR "ResetBuffer: %s %s\n", $j, $TEXT->{$j}{'c'};
    $KEY->{$t}{'t'} = "Adel";
    $KEY->{$t}{'k'} = $TEXT->{$j}{'c'};
	$TEXT->{$j} = undef;
    $KEY->{$t}{'c'} = $j;
    $t++;
  }
  $TextLength = 0;

  if($Verbose) {
    my ($x) = $s =~ /Time="([0-9][0-9]*)"/i;
    print STDERR "init:$x\n";
    my $j=0;
    while (defined($TEXT->{$j})) { print STDERR "$TEXT->{$j}{'c'}"; $j++;}
    print STDERR "<\n";
  }
  return $t;
}

sub RewindToSaveTime {
  my ($fint, $transt) = @_;

#my $xxx = '';
#printf STDERR "RewindToSaveTime $fint, $transt $TextLength\n";

  if($TextLength <= 0) {return $fint;}

  foreach my $t (sort {$b <=> $a} keys %{$KEY}) {
    if($t < $transt) {last;}

    my $k = $KEY->{$t}{'k'};
    my $c = $KEY->{$t}{'c'};

#printf STDERR "RewindToSaveTime: TextLen:$TextLength type:$KEY->{$t}{'t'} $KEY->{$t}{'c'} $KEY->{$t}{'k'}   $TEXT->{$KEY->{$t}{'c'}}{'c'}\n";

    if($KEY->{$t}{'t'} =~ /ins/) {
#  printf STDERR "RewindToSaveTime 1: $KEY->{$t}{'c'} $KEY->{$t}{'k'}   $TEXT->{$KEY->{$t}{'c'}}{'c'}\n";
#        if($TEXT->{$c}{'c'} ne $k) {
#            printf STDERR "RewindToSaveTime: $transt $c >$k< ne >$TEXT->{$c}{'c'}< ";
#            foreach my $x (sort {$a <=> $b} keys %{$TEXT}) { if($x >= $TextLength) {last;} printf STDERR "$TEXT->{$x}{'c'}";}
#            printf STDERR "\n";
#        }
        for(my $j=$c; $j<$TextLength-1; $j++) { $TEXT->{$j}{'c'} = $TEXT->{$j+1}{'c'}; $TEXT->{$j+1}=undef;}
        $KEY->{$fint}{'t'} = "Adel";
        $KEY->{$fint}{'k'} = $k;
        $KEY->{$fint}{'c'} = $c;
        $fint++;
        $TextLength --;
    }
      
    if($KEY->{$t}{'t'} =~ /del/) {
        for(my $j=$TextLength; $j>$c; $j--) { $TEXT->{$j}{'c'} = $TEXT->{$j-1}{'c'}; $TEXT->{$j-1}=undef;}
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
    print STDERR "rwnd:$transt/$fint\t>";
    my $j=0;
    while (defined($TEXT->{$j})) { print STDERR "$TEXT->{$j}{'c'}"; $j++;}
    print STDERR "<\n";
  }

  return $fint;
}

sub InsertText {
  my ($t, $Value, $cursor, $auto) = @_;
  my ($j, $l);
  my $vt = $t;

  if($Value eq '') {return $t;}

  my $X=[split(//, $Value)];

# make place for insertion in text 
  for($j=$TextLength; $j > $cursor; $j--) { $TEXT->{$j+$#{$X}}{'c'} = $TEXT->{$j-1}{'c'}; $TEXT->{$j-1}=undef}

#  insert contents of $X in text 
#print STDERR "InsertText: time:$t Log:$Value($#{$X})\n"; 
  for($j=0; $j <= $#{$X}; $j++) { 
#print STDERR "     time:$t text:$cursor+$j Log:$j:$X->[$j]\n"; 
    $TEXT->{$cursor+$j}{'c'} = $X->[$j]; 
    if($auto) { $KEY->{$t}{'t'} = 'Ains';}
    else { $KEY->{$t}{'t'} = "Mins";}
    $KEY->{$t}{auto} = $auto;
    $KEY->{$t}{'k'} = $X->[$j];
    $KEY->{$t}{'c'} = $cursor+$j;
    $t++;
  }
  $TextLength += $#{$X} +1;

### Debugging
  if($Verbose && $auto >= 0) {
    if($auto) { print STDERR "Ains:$vt $cursor\t$Value\t>";}
    else { print STDERR "Mins:$vt $cursor\t$Value\t>";}
    for($j=0; $j<$TextLength; $j++) { if(defined($TEXT->{$j})) {print STDERR "$TEXT->{$j}{'c'}";}}
    print STDERR "<\n";
  }
  return $t;
}

## Delete
sub DeleteText {
  my ($t, $Value, $cursor, $auto) = @_;
  my ($j, $l);
  my $vt = $t;

  if($Value eq '') {return $t;}
  my $s = $_;
 
  my $X=[split(//, $Value)];

  # check inconsistencies between X (buffer) and TEXT (should be identical)
  my $i =0;
  for($j=$cursor; $j<=$cursor+$#{$X}; $j++) {
    if(!defined($TEXT->{$j})) { 
      printf STDERR "WARNING Delete time:$t TEXT undefined cur:$j\n"; 
	  return $t;
    }
    if($Value  =~ /\#/) { $X->[$i] = $TEXT->{$j}{'c'};}
    elsif($TEXT->{$j}{'c'} ne $X->[$i]) {

      my $offs = SearchDelChar($TEXT, $j, $X, $i);
      for (my $k=0; $k <$offs; $k++) {unshift(@{$X}, '#')}
      printf STDERR "WARNING Delete time:$t cur:$j inserted:$offs\tLog:$Value($#{$X})\tText:$j:$TEXT->{$j}{'c'}\t$offs\n\t"; 
      for (my $k=$j-20;$k<$j+20;$k++) { 
#      for (my $k=$0;$k<$TextLength;$k++) { 
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

  # apply deletion in text buffer
  for($j=$cursor; $j<$TextLength; $j++) {
    if(defined($TEXT->{$j+$l})) {
	  $TEXT->{$j}{'c'} = $TEXT->{$j+$l}{'c'};
	  $TEXT->{$j+$l}=undef;
    }
	else {$TEXT->{$j}=undef};
  }

# my $V = 0;
#  if($t==1396868162404) {$V = 1;}
#  if($V) {
#    print STDERR "DELETE:$t\tTL:$TextLength\tDL:$l\t$Value\n";
#    my $j=0;
#    while (defined($TEXT->{$j})) { print STDERR "$TEXT->{$j}{'c'}"; $j++;}
#    print STDERR "\n";
#  }

  # deletion sequence in text 
  for($j=$l-1; $j>=0; $j--) {
#printf STDERR "DeleteText3: %s %s\n", $TextLength, $cursor+$j;
    if($cursor+$j > $TextLength) {last;}
    if($auto) {$KEY->{$t}{'t'} = 'Adel'}
    else {$KEY->{$t}{'t'} = "Mdel";}
    $KEY->{$t}{auto} = $auto;
    $KEY->{$t}{'k'} = $X->[$j];
    $KEY->{$t}{'del'} = $Value;
    $KEY->{$t}{'c'} = $cursor + $j;
    if($X->[$j] =~ /[\s\!?.]/) { $KEY->{$t}{new} = 1}
    else { $KEY->{$t}{new} = 0} 
    $t++;
  }

  if($TextLength > $cursor+$l) {$TextLength -= $l;}
  else {$TextLength = $cursor;}

#  $j=$TextLength;
#  if (defined($TEXT->{$j})) { print STDERR "NOT DELETED\tTL:$TextLength\tDL:$l\t"; while (defined($TEXT->{$j})) { print STDERR "$TEXT->{$j}{'c'}"; $j++;}; print STDERR "\n";}

### Debugging
  if($Verbose && $auto >= 0) {
    if($auto){print STDERR "Adel:$vt $cursor\t$Value\t>";}
    else{print STDERR "Mdel:$vt $cursor\t$Value\t>";}
    for($j=0; $j<$TextLength; $j++) { print STDERR "$TEXT->{$j}{'c'}";}
    print STDERR "<\n";
  }
  return $t;
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
  
#  print STDERR "Original Final:\n";
#  foreach $cur (sort {$a <=> $b} keys %{$CHR->{fin}}) { print STDERR "$CHR->{fin}{$cur}{'c'}"; }
#  print STDERR "\n";
#  print STDERR "Reconstructed Final:\n";
#  foreach $cur (sort {$a <=> $b} keys %{$TEXT}) { print STDERR "$TEXT->{$cur}{'c'}"; }
#  print STDERR "\n";

### map token id from Final text ($CHR->{fin}{$cur}{'id'}) on reconstructed TEXT
  foreach $cur (sort {$a <=> $b} keys %{$CHR->{fin}}) { 
    if(!defined($TEXT->{$cur})) {printf STDERR "$opt_T Segment $seg: MapSource undefined TEXT cur: $cur CHR:>$CHR->{fin}{$cur}{'c'}<\n"; next;}
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

############################################################
# Key-to-ST mapping
############################################################

sub MapTarget {
  my ($t, $j, $c);
  my ($F, $E);

  if(defined($FIX)) { $F = [sort {$b <=> $a} keys %{$FIX}];}
  if(defined($EYE)) { $E = [sort {$b <=> $a} keys %{$EYE}];}
  my $e=0; # time index of last eye event
  my $f=0; # time index of last fix event

  my $id=-1; 

  if($Verbose > 1) {print STDERR "MapTarget Backwards:\n";}
  ## loop through keystrokes from end to start

  foreach $t (sort {$b <=> $a} keys %{$KEY}) {
    $c = $KEY->{$t}{'c'};

    if($Verbose > 1) {
      print STDERR "TEXT $KEY->{$t}{t}:$t\t$c:$KEY->{$t}{k}\t";
      for(my $j=0; $j<$TextLength; $j++) { print STDERR "$TEXT->{$j}{'c'}";}
      print STDERR "\n";
    }


    ## Assign Word ID to FIX samples in target window between time $f and time $t
    while($f <= $#{$F} && $F->[$f] > $t) {
      if($FIX->{$F->[$f]}{'w'} != 2) { $f++; next;}

      my $cur = $FIX->{$F->[$f]}{'c'}; # cursor
      if($cur >= $TextLength) {
        if($Verbose >1 ) { printf STDERR "Target FIX at time:$F->[$f] cur:$FIX->{$F->[$f]}{'c'} >= TEXT:$TextLength\n"; }
        $cur = $TextLength-1;
      }
      if($cur < 0) { $cur = 0;}
      if(!defined($TEXT->{$cur}{'id'})) { printf STDERR "Fix time $t Undef id in TEXT cur:$cur len:$TextLength\n"; }

      ## This is the target ==> source mapping
      $FIX->{$F->[$f]}{'tid'} = $TEXT->{$cur}{'id'}; 
      $f++; 
    }

    ## Assign Word ID to EYE samples in target window between time $e and time $t
    while($e <= $#{$E} && $E->[$e] > $t) {
      my $e1 = $E->[$e];
      if($EYE->{$e1}{'w'} == 2) {
        my $cur = $EYE->{$e1}{'c'};

        if($cur > $TextLength) {
          if($Verbose > 1) {printf STDERR "Eye time:$e1 target cur:$cur >= TEXT:$TextLength\n"; }
 	      $cur = $TextLength-1;
        }
        if($cur < 0) { $cur = 0;}
        if(!defined($TEXT->{$cur}{'id'})) { 
           if($Verbose > 1) {printf STDERR "Eye time $t target id in TEXT cur:$cur len:$TextLength\n"; }
           $cur = $TextLength-1;
        }
        $EYE->{$e1}{'id'} = $TEXT->{$cur}{'id'}; 
      }
      $e++; 
    }

###########################################
# Key -> word mapping
###########################################

    if($KEY->{$t}{'t'} =~ /ins/) {
# Check Consistency of Keys and TEXT
      if(!defined($TEXT->{$c}{'c'})) {printf STDERR "MapTarget time:$t undefined type:$KEY->{$t}{'t'} char:$c $KEY->{$t}{'k'}\n"; next;}
      if(!defined($TEXT->{$c}{'id'})){printf STDERR "MapTarget time:$t undefined type:$KEY->{$t}{'t'} id:$c $KEY->{$t}{'k'}\n"; next;}

      if($KEY->{$t}{'k'} ne $TEXT->{$c}{'c'} && $TEXT->{$c}{'c'} ne '#') {
        printf STDERR "MapTarget time:$t $KEY->{$t}{auto} no match at cursor:$c KEY>%s<\tTEXT:>%s<\n", $KEY->{$t}{'k'}, $TEXT->{$c}{'c'}; 
      }

# remember last id for deletions
      $id = $KEY->{$t}{'id'} = $TEXT->{$c}{'id'};
#print STDERR "Mapping: $t $c $id\n";
      for($j=$c; $j<$TextLength; $j++) { $TEXT->{$j} = $TEXT->{$j+1}; $TEXT->{$j+1}=undef;}
      $TextLength--;
    }

    elsif($KEY->{$t}{'t'} =~ /del/) {

## delete the only char in TEXT
      if($TextLength <= 0) { }
## delete last char in TEXT
      elsif(!defined($TEXT->{$c}) || !defined($TEXT->{$c}{id})) {
        if(defined($TEXT->{$c-1}) && defined($TEXT->{$c-1}{id})) { $id = $TEXT->{$c-1}{'id'}; }
        else { printf STDERR "MapTarget time:$t undefined $KEY->{$t}{'t'} cur:%s/$TextLength %s\n", $c-1, $KEY->{$t}{'k'}; }
      }
## delete first char in TEXT
      elsif(!defined($TEXT->{$c-1}) || !defined($TEXT->{$c-1}{id})) {
        if(defined($TEXT->{$c}) && defined($TEXT->{$c}{id})) { $id = $TEXT->{$c}{'id'}; }
        else { printf STDERR "MapTarget time:$t undefined $KEY->{$t}{'t'} cur:%s/$TextLength %s\n", $c, $KEY->{$t}{'k'};}
      }
## deletion in the middle of a word
      elsif($TEXT->{$c-1}{'id'} == $TEXT->{$c}{'id'}) { $id = $TEXT->{$c}{'id'}; }
## delete between two words: assume it's the from the suffix
      else { $id = $TEXT->{$c-1}{'id'}; }

      if(!defined($KEY->{$t}{new})) {$KEY->{$t}{new} = 0}

      for($j=$TextLength; $j>$c; $j--) { $TEXT->{$j} = $TEXT->{$j-1}; $TEXT->{$j-1} = undef;}
      $KEY->{$t}{'id'}=$TEXT->{$c}{'id'} = $id; #-  $KEY->{$t}{new};
      $TEXT->{$c}{'c'} = $KEY->{$t}{'k'};

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

  
  my $exi = 0;
  my $focus = '';
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

## produce segment open/close events
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
  print FILE "  </Fixations>\n";
  print FILE "  <Modifications>\n";
  foreach my $k (sort {$a<=>$b} keys %{$MODIFICATIONS}) { print FILE "$MODIFICATIONS->{$k}"; }
  print FILE "  </Modifications>\n";
  
  if(defined($EXT)) {
    print FILE "  <External>\n";
	my $title = '';
    foreach my $t (sort {$a<=>$b} keys %{$EXT}) {
      if(defined($EXT->{$t}{title})) {
        print FILE "    <Focus  time=\"$t\" title=\"$EXT->{$t}{title}\" />\n";
	    $title = $EXT->{$t}{title};
      }
      if($title =~ /Translog-II/) {next;}
	  if (defined($EXT->{$t}{value} && $EXT->{$t}{edition})) {
        print FILE "    <$EXT->{$t}{edition}  time=\"$t\" value=\"$EXT->{$t}{value}\" />\n";
    } }
    print FILE "  </External>\n";
  }  
  print FILE "<\/logfile>\n";
  close(FILE);
}

