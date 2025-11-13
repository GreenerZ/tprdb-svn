#!/usr/bin/perl -w

use strict;
use warnings;

use Encode qw(encode decode);
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

# Escape characters 
my $map = { map { $_ => 1 } split( //o, "\\<> \t\n\r\f" ) };

use Data::Dumper; $Data::Dumper::Indent = 1;
sub d { print STDERR Data::Dumper->Dump([ @_ ]); }

my $usage =
  "Map keystrokes and gaze to words: \n".
  "  -T in:  <study>/Events/*.Atag.xml \n".
  "Options:\n".
  "  -O out: Write output <filename>.\n".
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
my $CHR = undef; # Text from the log file
my $TOK = undef;
my $EXT = undef;
my $TEXT = undef; # Reproduced text from the keystrokes
my $TRANSLOG = {};
my $Verbose = 0;
my $mismatch = 0;
my $TargerLanguage = "";
my $LastDelCur = -1;
my $TradosQualitivity = 0;

## Key mapping
my $TextLength = 0;
my $LastSeg = 0;
my $LastId = 0;
my $LastToken = 0;
my $MaxToken = 0;
my $fn = '';


die $usage if defined($opt_h);
die $usage if not defined($opt_T);

if(defined($opt_v)) { $Verbose = $opt_v;}

if(defined($opt_O)) { $fn = $opt_O;}
else {$fn = $opt_T; $fn =~ s/.xml$/_tab.xml/;}

  my $KeyLog = ReadTranslog($opt_T);
  
  if($TradosQualitivity) { 
	  FixationCursor()
  }

  KeyLogAnalyse($KeyLog);
  

  CheckAtag();
  MapSource();

# append data to file
  FixModTable();

# append data to file
  PrintTranslog($fn);
exit;

############################################################
# escape
############################################################

sub MSunescape {
  my ($in) = @_;

  $in =~ s/&amp;/\&/g;
  $in =~ s/&gt;/\>/g;
  $in =~ s/&lt;/\</g;
  $in =~ s/&#xA;/\n/g;
  $in =~ s/&#10;/\n/g;
  $in =~ s/&#xD;/\r/g;
  $in =~ s/&#13;/\r/g;
  $in =~ s/&#x9;/\t/g;
  $in =~ s/&#9;/\t/g;
  $in =~ s/&quot;/"/g;
  $in =~ s/&nbsp;/ /g;
  return $in;
}

sub MSescape {
  my ($in) = @_;

  if(!defined($in)) {return '';}
  $in =~ s/\>/&gt;/g;
  $in =~ s/\</&lt;/g;
  $in =~ s/\n/&#xA;/g;
  $in =~ s/\r/&#xD;/g;
  $in =~ s/\t/&#x9;/g;
#  $in =~ s/\&/&amp;/g;
#  $in =~ s/"/&quot;/g;
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
  $type = 0;

  my $n = 0;
  my $FinalTextUTF8 = '';
  my $KeyLog = {};
  my $key = 0;
  my ($lastTime, $t, $lastCursor, $c);

  open(FILE, '<:encoding(utf8)', $fn) || die ("cannot open file $fn");
  if($Verbose) {printf STDERR "ReadTranslog Reading: $fn\n";}

  while(defined($_ = <FILE>)) {
#printf STDERR "Translog: %s",  $_;
    $TRANSLOG->{$n++} = $_;

    if(/<Languages/ && /target=\"([^"]*)\"/) { $TargerLanguage = $1;}
    if(/<Description/ && /Qualitivity/) { $TradosQualitivity = 1;}

    if(/<Events>/) {$type =1; }
    elsif(/<SourceTextChar/) {$type =2; }
    elsif(/<TranslationChar/) {$type =3; }
    elsif(/<TargetTextChar/) {$type =3; }
    elsif(/<FinalTextChar/) {$type =4; }
#    elsif(/<FinalText/)   {$type =5; }
    elsif(/<Alignment/)   {$type =6; }
    elsif(/<SourceToken/){$type =7; }
    elsif(/<FinalToken/) {$type =8; }
    elsif(/<Salignment/) {$type =9; }
    elsif(/<FinalTextUTF8/) {$type =10;} 
	

## SourceText Positions
    if($type == 2 && /<CharPos/) {
      if(/Cursor="([0-9][0-9]*)"/){$cur =$1;}
      if(/Value="([^"]*)"/)       {$CHR->{src}{$cur}{'c'} = MSunescape($1);}
      if(/X="([-0-9][0-9]*)"/)     {$CHR->{src}{$cur}{'x'} = $1;}
      if(/Y="([-0-9][0-9]*)"/)     {$CHR->{src}{$cur}{'y'} = $1;}
      if(/Width="([0-9][0-9]*)"/) {$CHR->{src}{$cur}{'w'} = $1;}
      if(/Height="([0-9][0-9]*)"/){$CHR->{src}{$cur}{'h'} = $1;}
    }
## TranslationChar Positions (initialize Text with MT output)
    elsif($type == 3 && /<CharPos/) {
      if(/Cursor="([0-9][0-9]*)"/) {$cur =$1;}
      if(/Value="([^"]*)"/)        {$TEXT->{$cur}{'c'} = $CHR->{tra}{$cur}{'c'} = MSunescape($1);}
      if(/X="([-0-9][0-9]*)"/)      {$TEXT->{$cur}{'x'} = $CHR->{tra}{$cur}{'x'} = $1;}
      if(/Y="([-0-9][0-9]*)"/)      {$TEXT->{$cur}{'y'} = $CHR->{tra}{$cur}{'y'} = $1;}
      if(/Width="([0-9][0-9]*)"/)  {$TEXT->{$cur}{'w'} = $CHR->{tra}{$cur}{'w'} = $1;}
      if(/Height="([0-9][0-9]*)"/) {$TEXT->{$cur}{'h'} = $CHR->{tra}{$cur}{'h'} = $1;}
      $TextLength++;
    }
## FinalText Positions
    elsif($type == 4 && /<CharPos/) {
#print STDERR "Final: $_";
      if(/Cursor="([0-9][0-9]*)"/) {$cur =$1;}
      if(/Value="([^"]*)"/)        {$CHR->{fin}{$cur}{'c'} = MSunescape($1);}
      elsif(/Value='([^']*)'/)     {$CHR->{fin}{$cur}{'c'} = MSunescape($1);}
      else   {print STDERR "no Value in\t$_";}
      
      if(/X="([-0-9][0-9]*)"/)      {$CHR->{fin}{$cur}{'x'} = $1;}
      if(/Y="([-0-9][0-9]*)"/)      {$CHR->{fin}{$cur}{'y'} = $1;}
      if(/Width="([0-9][0-9]*)"/)  {$CHR->{fin}{$cur}{'w'} = $1;}
      if(/Height="([0-9][0-9]*)"/) {$CHR->{fin}{$cur}{'h'} = $1;}
#if($CHR->{fin}{$cur}{'c'} eq "%"){print STDERR '%'. "\t$_";}
#else {printf STDERR "$CHR->{fin}{$cur}{'c'}\t$_";}
    } 
## Mouse has no impact on insertion/deletion$CHR->{src}{$f}{'end'}
    elsif($type == 1 && /<Mouse/) { }
    elsif($type == 1 && /<Eye/) {
      if(/Time="([0-9][0-9]*)"/)  {$time =$1;}
      if(/TT="([0-9][0-9]*)"/)    {$EYE->{$time}{'tt'} = $1;}
      if(/Win="([0-9][0-9]*)"/)   {$EYE->{$time}{'w'} = $1;}
      else{$EYE->{$time}{'w'} = 0;}
      if(/Xl="([-0-9][0-9]*)"/)    {$EYE->{$time}{'xl'} = $1;}
      else{$EYE->{$time}{'xl'} = 0;}
      if(/Yl="([-0-9][0-9]*)"/)    {$EYE->{$time}{'yl'} = $1;}
      else{$EYE->{$time}{'yl'} = 0;}
      if(/pl="([0-9.][0-9.]*)"/)  {$EYE->{$time}{'pl'} = $1;}
      else{$EYE->{$time}{'pl'} = 0;}
      if(/Xr="([-0-9][0-9]*)"/)    {$EYE->{$time}{'xr'} = $1;}
      else{$EYE->{$time}{'xr'} = 0;}
      if(/Yr="([-0-9][0-9]*)"/)    {$EYE->{$time}{'yr'} = $1;}
      else{$EYE->{$time}{'yr'} = 0;}
      if(/pr="([0-9.][0-9.]*)"/)  {$EYE->{$time}{'pr'} = $1;}
      else{$EYE->{$time}{'pr'} = 0;}
      if(/Cursor="([0-9][0-9]*)"/){$EYE->{$time}{'c'} = $1;}
      else{$EYE->{$time}{'c'} = 0;}
      if(/Xc="([-0-9][0-9]*)"/)    {$EYE->{$time}{'xc'} = $1;}
      else{$EYE->{$time}{'xc'} = 0;}
      if(/Yc="([-0-9][0-9]*)"/)    {$EYE->{$time}{'yc'} = $1;}
      else{$EYE->{$time}{'yc'} = 0;}
    }
    elsif($type == 1 && (/<ILfocus / || /<ILtext/)) {
#print STDERR "IL: $_";

      if(/time="([^"]*)"/i)  {$time =$1;}
      if($time < 0) {next;}
      if(/title="([^"]*)"/i)  {$EXT->{$time}{title} = $1;}
      if(/value="([^"]*)"/i)  {$EXT->{$time}{value} = $1;}
      if(/edition="([^"]*)"/i){$EXT->{$time}{edition} = $1;}
	}

    elsif($type == 1 && /<Fix/) {
# Skip End-of-Fixation
      if(!/Dur="([0-9][0-9]*[.]?[0-9]*)"/) {next;}
      elsif($1 == 0) {next;}

      if(/Time="([^"]*)"/)  {$time =$1;}
      if($time < 0) {next;}
	  
      if(/segId="([0-9][0-9]*)"/){$FIX->{$time}{'segId'} = $1;}
	  # undef if not specified
      if(/Cursor="([0-9][0-9]*)"/){$FIX->{$time}{'c'} = $1;}
      else {$FIX->{$time}{'c'} = 0;}
      if(/Block="([0-9][0-9]*)"/) {$FIX->{$time}{'b'} = $1;}
      else {$FIX->{$time}{'b'} = 0;}
      if(/Win="([0-9][0-9]*)"/)   {$FIX->{$time}{'w'} = $1;}
      else {$FIX->{$time}{'w'} = 0;}
      if(/Dur="([0-9][0-9]*[.]?[0-9]*)"/)   {$FIX->{$time}{'d'} = int($1);}
      else {$FIX->{$time}{'d'} = 0;}
      if(/X="([-0-9][0-9]*)"/)     {$FIX->{$time}{'x'} = $1;}
      else {$FIX->{$time}{'x'} = 0;}
      if(/Y="([-0-9][0-9]*)"/)     {$FIX->{$time}{'y'} = $1;}
      else {$FIX->{$time}{'y'} = 0;}

    }
    elsif($type == 1 && /<Key/) {  $KeyLog->{$key++} = $_; }
    elsif($type == 6 && /<Align /) {
#print STDERR "ALIGN: $_";
      my ($si, $ti);
      if(/sid="([^\"]*)"/) {$si =$1;}
      if(/tid="([^\"]*)"/)  {$ti =$1;}
      $ALN->{tid}{$ti}{sid}{$si} ++;
      $ALN->{sid}{$si}{tid}{$ti} ++;
    }
    elsif($type == 9 && /<Salign /) {
#print STDERR "ALIGN: $_";
      my ($si, $ti);
      if(/src="([^\"]*)"/) {$si =$1;}
      if(/tgt="([^\"]*)"/)  {$ti =$1;}
      $ALN->{tgt}{$ti}{src}{$si} ++;
      $ALN->{src}{$si}{tgt}{$ti} ++;
    }
    elsif($type == 7 && /<Token/) {
	  my $id = 0;
      if(/cur="([0-9][0-9]*)"/) {$cur =$1;}
      if(/tok="([^"]*)"/)   {$TOK->{src}{$cur}{tok} = MSunescape($1);}
      if(/space="([^"]*)"/) {$TOK->{src}{$cur}{space} = MSunescape($1);}
      if(/ id="([^"]*)"/)    {$id = $TOK->{src}{$cur}{id} = $1;}
      if(/segId="([^"]*)"/i) {$TOK->{src}{$cur}{seg} = $1;}
      if($id == 0) { print STDERR " Undefined Id $id:\t$_"}
      if(!defined($TOK->{src}{$cur}{seg})) { print STDERR " Undefined seg $TOK->{src}{$cur}{seg}:\t$_"}
      $ALN->{sid}{$id}{seg} = $TOK->{src}{$cur}{seg};

#print STDERR "SOURCE: $_";
#d($TOK->{src}{$cur});
    }

    elsif($type == 8 && /<Token/) {
	  my $id = 0;
	  my $seg = 0;
      if(/cur="([0-9][0-9]*)"/) {$cur =$1;}
      if(/tok="([^"]*)"/)   {$TOK->{fin}{$cur}{tok} = MSunescape($1);}
      if(/space="([^"]*)"/) {$TOK->{fin}{$cur}{space} = MSunescape($1);}
      if(/ id="([^"]*)"/)    {$id = $TOK->{fin}{$cur}{id} = $1;}
      if(/segId="([^"]*)"/i) {$seg = $TOK->{fin}{$cur}{seg} = $1;}
	  if($id == 0) { print STDERR " Undefined Id $id:\t$_"}
	  if(!defined($TOK->{fin}{$cur}{seg})) { print STDERR " Undefined seg $TOK->{fin}{$cur}{seg}:\t$_"}
	  $ALN->{tid}{$id}{seg} = $TOK->{fin}{$cur}{seg};
	  $LastToken = $id;
	  $LastSeg = $seg;
    }
    elsif($type == 10) {
		$FinalTextUTF8 .= MSunescape($_);
		$FinalTextUTF8 =~ s/.*<FinalTextUTF8>//;
		$FinalTextUTF8 =~ s/<\/FinalTextUTF8>.*//;
#	print STDERR "12:>$FinalTextUTF8<\n";
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
    if(/<\/Salignment>/) {$type =0; }
    if(/<\/SourceToken>/){$type =0; }
    if(/<\/FinalToken>/) {$type =0; }
    if(/<\/FinalTextUTF8>/) {$type =0; }
  }
  close(FILE);
#  FinalString($FinalTextUTF8);

  return $KeyLog;
}

sub FinalString {
  my ($FinalTextUTF8) = @_;

  my $T2 = {};
  if(length($FinalTextUTF8) > 0) {
    chomp($FinalTextUTF8);
	my $i=0;
	foreach my $c (split(//, $FinalTextUTF8)){
		$T2->{fin}{$i}{c} = $c;
		$i ++;
    } 
  }
  
  my $chars = '';
  foreach my $i (sort {$a<=>$b} keys %{$CHR->{fin}}) {
		$chars .= $CHR->{fin}{$i}{c};
  }

if($chars ne $FinalTextUTF8) {
print STDERR "FinalString:\n\t>$chars<\n\t>$FinalTextUTF8<\n";
}
#
  my $d = 0;
  if(length($FinalTextUTF8) > 0 && defined($CHR->{fin})) {
	for (my $i = 0; defined($T2->{fin}{$i}{c}) ;$i++){
		if($T2->{fin}{$i}{c} ne $CHR->{fin}{$i}{c}) {
			printf STDERR "$i T2 >$T2->{fin}{$i}{c}< CHR:\t>$CHR->{fin}{$i}{c}<\n";
			$d = 1;
		}
  	}
  }

  my $i=0;
  $CHR->{fin} = {};
  $CHR->{fin} = undef;
  foreach my $c (split(//, $FinalTextUTF8)){
		$CHR->{fin}{$i}{'c'} = MSunescape($c);
		$i ++;
  } 

}

##########################################################
# Parse Keystroke Log
##########################################################

## map all keystrokes on ins and del
sub KeyLogAnalyse {
  my ($Key) = @_;

  $MaxToken = $LastToken;
  $TextLength = 0; ##  TextLength: 
  my $seg  = 1;
  my $id  = 1;
  my $first = 1;
  my $curL = 0;
  my $CurrentToken = 1;
  
  foreach my $cur (sort {$a <=> $b} keys %{$CHR->{fin}}) {
	if(defined($TOK->{fin}{$cur})) {
	  $seg = $TOK->{fin}{$cur}{seg};
	  $id = $TOK->{fin}{$cur}{id};
	  if($id < 1) { $id = 1;}
	  # check whether token position identical to CharPos position
	  if($TOK->{fin}{$cur}{tok} !~ /^\Q$CHR->{fin}{$cur}{c}\E/) {
        if($first) {print STDERR "*** CharPos Difference: cur:$cur char:>$CHR->{fin}{$cur}{c}<\tTokenId:$TOK->{fin}{$cur}{id}\ttok:>$TOK->{fin}{$cur}{tok}<\n";}
		$first = 0;
	} }
        $TEXT->{$cur}{c} = $CHR->{fin}{$cur}{c}; 
	$TEXT->{$cur}{id} = $id;
	$TEXT->{$cur}{seg} = $seg;

#	print STDERR "QQQ: $Qualitivity  c:$cur\ts:$seg\tw:$id >$CHR->{fin}{$cur}{c}<\n";
    # Trados Qualitivity 
	if($TradosQualitivity && ($CHR->{fin}{$cur}{c} eq "\n")) {
        $TEXT->{$cur}{seg} = $seg; # end of segment
    }
    if($cur != $TextLength) {
#    if($cur > 1590) {
        print STDERR "TEXT len: $TextLength Cur: $cur $TEXT->{$cur}{c} $TEXT->{$cur}{c}\n";
    }
    $TextLength++;
  }
#print STDERR "KeyLogAnalyse: Len:$TextLength mxTok:$MaxToken\n";

  my $F = []; # keep fix time indexes in reversed order
  my $E = []; # keep eye time indexes in reversed order
  if(defined($FIX)) { $F = [sort {$b <=> $a} keys %{$FIX}];}
  if(defined($EYE)) { $E = [sort {$b <=> $a} keys %{$EYE}];}

  my $eye=0; # time index of last eye event
  my $fix=0; # time index of last fix event
  my $stime = 0; # IME start time
  my $ltime = 0; # time of last key event
  my $Knum = 0;

  # main loop backwards parse keystroke data through keystrokes
  my $K = [sort  {$a <=> $b} keys %{$Key}];
  for (my $f = $#{$K}; $f >= 0; $f --) {
    $_ = $Key->{$K->[$f]};

    my $time = 0;
    if(/Time="([0-9][0-9]*)"/)   {$time = $1;}
    else { printf STDERR "KeyLogAnalyse: No Time in $_\n";}

    my $type = 'other';
    my $mode = 'other';
    if(/Type="([^\"]*)"/) {
        $type = $1;
        if($type=~/speech/ ) {$type = 'speech'; $mode = 'speech'; }
        if($type=~/return/ ) {$type = 'return'; $mode = 'man'; }
        # /edit/ is Ctrl.V in Translog and has a paste feature 
        if($type=~/edit/ )   {$type = 'edit'; $mode = 'man'; }
        if($type=~/insert/ ) {$type = 'insert'; $mode = 'man'; }
        if($type=~/delete/ ) {$type = 'delete'; $mode = 'man'; }
        if($type=~/^A/ )     {$mode = 'auto'; }
    }
    if($type eq 'other') {
        printf STDERR "KeyLogAnalyse: other mode $_\n";
        next;
    }

    # TRACE editing operations
    if($Verbose >= 1) {
        my $c = 0;
        my $V = '';
        my $T = '';
        my $S = '';
        if(/Cursor="([0-9][0-9]*)"/) {$c = $1 + $mismatch;}
        if(/Value="([^\"]*)"/){$V = MSunescape($1);} 
        if(/Text="([^\"]*)"/) {$T = MSunescape($1);} 
        if(/segId="([^\"]*)"/) {$S = $1;} 
        my $c2 = $c-1;
        if($V and $type eq 'insert') { $c2 = $c+length($V)-1;}
        #if($T) { $c2 = $c+length($T)-1;}
        printf STDERR "TRACE t:$time $mode-$type seg:$S cur:$c-$c2 len:$TextLength mis:$mismatch ins:>$V< del:>$T<\n";
        PlotText($c, $c2, 0);
        printf STDERR "\n";
    }

    # no action in text needed
    if(/Type="edit"/ && /Value="\[Ctrl.C\]"/ ) { next;}

# IME go back to first keystroke
#    print STDERR "BBB0: $type : $Knum\t $_";
#    if(/IMEtext=/ && $type eq 'man') { 
#      my $k = $f-1;
#	  for (my $i = $k; $i >= 0; $i --) {
#        my $s = $Key->{$K->[$k]};
#    print STDERR "\tBBB1: $k\t$Knum:\t $s";
#	    if($s !~ /Type="IME"/) {
#		  last;
#        }
#	    $Knum++;
#		$k--;
#      } 
#      ($stime) = $Key->{$K->[$k+1]} =~ /Time="([0-9][0-9]*)"/;
#	  $f = $k + 1;
#	}

	$ltime = $time;
#    if($stime) { $ltime = $stime}
    if($type eq "edit") { 
      if(/Paste="([^\"]*)"/) {InsertText($ltime, MSunescape($1), $mode);}
      if(/Text="([^\"]*)"/) {DeleteText($ltime, MSunescape($1), $mode);}
    }
    if($type eq "return") {
	  InsertText($ltime, "\n", $mode); 
      if(/Text="([^\"]*)"/) {DeleteText($ltime, MSunescape($1), $mode);}
	}
    if($type eq "delete") { 
      if(/Text="([^\"]*)"/) {DeleteText($ltime, MSunescape($1), $mode);}
      else { 
        if($Verbose) {printf STDERR "Empty Text in delete: $_"; }
        DeleteText($ltime, "#", "delete");
      }
    }
    if($type eq "insert") { # can have selection highlighted in 'Text'
      if(/Value="([^\"]*)"/) { InsertText($ltime, MSunescape($1), $mode);} 
      if(/Text="([^\"]*)"/) { DeleteText($ltime, MSunescape($1), $mode);}
    }
    if($type eq "speech") { 
      if(/Value="([^\"]*)"/) { InsertText($ltime, MSunescape($1), $mode);} 
      if(/Text="([^\"]*)"/) { DeleteText($ltime, MSunescape($1), $mode);}
    }
#    if(/Type="IMEinsert"/) { 
#        if(/Dur="([^\"]*)"/) {$KEY->{$ltime}{dur} = $1};
#        if(/Strokes="([^\"]*)"/) {$KEY->{$ltime}{knum} = $1};
#	}

	if(/Dur="([0-9][0-9]*[.]?[0-9]*)"/)     {$KEY->{$ltime}{dur} = int($1);}
    if(/Strokes="([0-9][0-9]*[.]?[0-9]*)"/) {$KEY->{$ltime}{knum} = $1;}

### fixations after end of typing
    while($fix <= $#{$F} && ($F->[$fix]+ $FIX->{$F->[$fix]}{d}) >= $time ) {
      my $t = $F->[$fix];

      if(!defined($FIX->{$t}{tid}) && ($FIX->{$t}{w} == 2)) {
        my $cur = $FIX->{$t}{c}; 
	    if(!defined($TEXT->{$cur})) { 
          if($Verbose > 1) {printf STDERR "Fix Win=2 on undef Text time $t Len:$TextLength cur:$cur Wid:$LastToken\n"; }
          $FIX->{$t}{tid} = $LastToken;
        }
        else {$FIX->{$t}{tid} = $TEXT->{$cur}{id};}
      }
      $fix++;
    }

### gaze samples after end of typing
    while($eye <= $#{$E} && $E->[$eye] >= $time) {
      if($EYE->{$E->[$eye]}{w} == 2) {
        my $cur = $EYE->{$E->[$eye]}{'c'};
        if(!defined($TEXT->{$cur})) {
          printf STDERR "Eye on undef Text time $E->[$eye] Len:$TextLength cur:$cur Wid:$LastToken\n"; 
          if($Verbose > 1) {$EYE->{$E->[$eye]}{tid} = $LastToken;}
        }
        else { $EYE->{$E->[$eye]}{tid} = $TEXT->{$cur}{id}; }
      }
      $eye++; 
    }

#    if($stime > 0) {
#      if(defined($KEY->{$stime})) {
#        $KEY->{$stime}{dur} = $time - $stime;
#        $KEY->{$stime}{knum} = $Knum;
#printf STDERR "---> IME dur:$KEY->{$stime}{dur} strokes:$KEY->{$stime}{knum}\n";
#      }
#	  elsif($Verbose) {printf STDERR "No match for IME time:$stime\n";}
#      $stime = $Knum = 0;
#    }

  }  ## End of main loop
###########################
  
  
  ## fixations before starting of typing
  while($fix <= $#{$F}) {
    my $t = $F->[$fix];
    
    if(!defined($FIX->{$t}{tid}) && ($FIX->{$t}{w} == 2)) {
      my $cur = $FIX->{$t}{c}; 
	  if(!defined($TEXT->{$cur})) { 
        if($Verbose > 1) {printf STDERR "Warning: Fix beyond text time $F->[$fix] cur:$cur Len:$TextLength\n"; }
		$FIX->{$t}{tid} = 0;
      }
      else {$FIX->{$t}{tid} = $TEXT->{$cur}{id}; }
#      print STDERR "tid_Time0 $F->[$fix] $FIX->{$t}{tid}\n";
      
    }
    $fix++;
  }

### gaze samples before of typing
  while($eye <= $#{$E}) {
    if($EYE->{$E->[$eye]}{w} == 2) {
      my $cur = $EYE->{$E->[$eye]}{'c'};
	  if(!defined($TEXT->{$cur})) { 
        printf STDERR "Warning: Eye beyond text time $E->[$eye] cur:$cur Len:$TextLength\n"; 
		if($Verbose > 1) {$EYE->{$E->[$eye]}{tid} = 0;}
      }
      else { $EYE->{$E->[$eye]}{tid} = $TEXT->{$cur}{id}; }
    }
    $eye++; 
  }
}

sub DeleteText {
  my ($time, $Value, $mode) = @_;
  my ($j, $c);

  my $s = $_;
  my $X=[split(//, $Value)];

  if($s =~ /Cursor="([0-9][0-9]*)"/) {$c = $1 + $mismatch;}
  else { printf STDERR "Delete1: No Cursor in $s\n"; return;}

  if($c > $TextLength) {
    printf STDERR "Delete3: Time:$time Len:$TextLength cur:$c mis:$mismatch Value:\"$Value\"\tDeletion behind Text\n";
#	return;
  }
  
  my $seg = $LastSeg;
  if($_  =~ /segId="(.*)"/){ $seg = $1;}
# if($Verbose && $LastSeg != $seg) {print STDERR "SEG: $seg end with deletion (last:$LastSeg)\n"}
  
  my $id0 = defined($TEXT->{$c}{id}) ? $TEXT->{$c}{id} : 0;
  my $id1 = defined($TEXT->{$c-1}{id}) ? $TEXT->{$c-1}{id} : 0;
  my $id2 = defined($TEXT->{$c+1}{id}) ? $TEXT->{$c+1}{id} : $LastToken;

  my $sg0 = defined($TEXT->{$c}{seg}) ? $TEXT->{$c}{seg} : $LastSeg;
  my $sg1 = defined($TEXT->{$c-1}{seg}) ? $TEXT->{$c-1}{seg} : $LastSeg;
  my $sg2 = defined($TEXT->{$c+1}{seg}) ? $TEXT->{$c+1}{seg} : $LastSeg;
 

#print STDERR "WWW: seg: $LastSeg $seg\t$sg1 $sg0 $sg2\t$sg3\tlen:$#{$X}\tid: $LastId $LastToken\t$id1 $id0 $id2\n";

#if($Verbose && ($sg1 != $seg || $sg2 != $seg)) {
#print STDERR "*** SEG:\tlast:$LastSeg-$seg\tsg:$sg1-$sg0-$sg2\tlen:$#{$X}\n";
#}

## Show context of deletion
if($Verbose > 2) {
  for (my $begin=$c-3;  $begin <= $c+3; $begin ++) {
    if(!defined($TEXT->{$begin})) { next;}
    if(!defined($TEXT->{$begin}{c})) { next;}
	print STDERR "Context:\t$begin\t>$TEXT->{$begin}{c}<\t$TEXT->{$begin}{id}\t$TEXT->{$begin}{seg}\n";
  }
}


  # default deletion steps (characters per word)
  my $step = 0;
  my $word = 0;

  if($Verbose > 2) {
    print STDERR "Delete4:\ttime:$time cur:$c lastDel:$LastDelCur step:$step word:$word mis:$mismatch Len:$TextLength\tseg:$seg\tid:$id0-$id1-$id2 lid:$LastId/$LastToken lseg:$LastSeg chunk:$#{$X} step:$step\tValue:$Value\n";
  }


# make place for insertion in text 
  for($j=$TextLength; $j > $c; $j--) {
    foreach my $key (keys %{$TEXT->{$j-1}}) {$TEXT->{$j+$#{$X}}{$key} = $TEXT->{$j-1}{$key};}
  }


  my $id3 = $id1 + $word + 1;
  #successive deletions forward or backward
  if($LastDelCur > 0 && $LastDelCur >= $c-1 && $LastDelCur <= $c+1){ 
      $id3 = $TEXT->{$LastDelCur}{id} + $word; 
	  # next word
      if($Value =~ /\s/ && $LastDelCur < $c) {$id3 += 1;} 
      if($Value =~ /\s/ && $LastDelCur > $c) {$id3 -= 1;}
  }
  elsif($id0 == $id1 && $id0 > 0) {$id3 = $id0 + $word}

  for($j=$#{$X}; $j >=0 ; $j--) {
    while(defined($KEY->{$time})) {$time--;}
	if($j==$#{$X}) {
		$KEY->{$time}{'value'} = $Value;
	}
	
    if($mode eq "speech") {$KEY->{$time}{'t'} = "Sdel";}
    elsif ($mode eq "auto") {$KEY->{$time}{'t'} = "Adel";}
    else { $KEY->{$time}{'t'} = "Mdel";}

    $TEXT->{$c+$j}{'c'} = $KEY->{$time}{'k'} = $X->[$j]; 
    $KEY->{$time}{'c'} = $c+$j;

    # if deletion string has word: distribute 
	if($step != 0)  {$id3 -= $step;}
	elsif($word != 0) { 
        if($X->[$j] =~ /\s/) {$id3 -= 1;}
    }

	if($id3 <= 0) { print STDERR "ERROR: wordId $id3 step:int($j*$step) word:$word\n";}
	
#printf STDERR "KEYID1: off:%d id:$id0/$id1/$id2 len:%d s:%f/%d ix:%d\n", $c+$j, $#{$X}, $j*$step, int($j*$step), $id3;
   $TEXT->{$c+$j}{id}  = $KEY->{$time}{id} = int($id3);
   $TEXT->{$c+$j}{seg} = $KEY->{$time}{seg} = $seg;
   $TEXT->{$c+$j}{modif} = $time;

if($Verbose > 2) {
printf STDERR "\tKEYID1: val:$X->[$j] steps:$step off:%d id:$id0/$id1/$id2 len:%d s:%4.4f/%d id:%d\n", $c+$j, $#{$X}, $j*$step, int($j*$step), int($id3);
}
    if($Verbose > 2) {
	printf STDERR "\tdel\ttime:$time cur:%d mis:$mismatch Len:$TextLength seg:$TEXT->{$c+$j}{seg} id:$TEXT->{$c+$j}{id}\tValue:$X->[$j]\n", $c+$j; 
    }
	
    $LastToken = $TEXT->{$c+$j}{id};
    $LastId = $TEXT->{$c}{id};
    $LastSeg = $TEXT->{$c+$j}{seg};

#print STDERR "Delete3: $time\tv:$Value\tchar:$X->[$j]\n";
    $time--;
  }
  $LastDelCur = $c + $#{$X};
  $TextLength += $#{$X} +1;
}

sub PlotText {
      my ($c1, $c2, $c3) = @_;
      for (my $t=0; $t<=$TextLength; $t++) { 
        if($c3 != 0 and (($t < $c1-$c3) or ($t > $c2+$c3))) { next;}
        if($t == $c1) {print STDERR ">";}
        if(defined($TEXT->{$t}) && defined($TEXT->{$t}{c})) {
      	  print STDERR "$TEXT->{$t}{c}";
        }
        else {print STDERR "-";}
        if($t == $c2) {print STDERR "<";}
      }
	  print STDERR "\n";
}

sub InsertText {  
  my ($time, $Value, $mode) = @_;
  my ($c, $l);

#print STDERR "InsertText0: $_\n";

  my $s = $_;
  my $mism = 0;
  if($s =~ /Cursor="([0-9][0-9]*)"/) {$c = $1 + $mismatch;}
  else { printf STDERR "Insert1: No Cursor in $s\n";}

  if(!defined($TEXT->{$c})) {
    if($Value ne '') {
	  printf STDERR "Insert2: time:$time cur:$c mis:$mismatch Len:$TextLength Value:\"$Value\"\tInsertion at undefined position\n";
	  if($Verbose) {PlotText($c, $c, 40);}
    }
	return;
  }
  
  if($c > $TextLength) {
    printf STDERR "Insert3: time:$time Len:$TextLength cur:$c mis:$mismatch Value:\"$Value\"\tInsertion behind text\n";
    return;
  }

  my $X=[split(//, $Value)];
  if($#{$X} < 0) {return;} ## empty string
  
  $l = $#{$X}+1;
#  $time += $#{$X};

  if($Verbose > 2) {
    print STDERR "Insert4:\ttime:$time cur:$c mis:$mismatch Len:$TextLength\tsg:$TEXT->{$c}{seg}\tid:$TEXT->{$c}{id}\tValue:$Value -> $TEXT->{$c}{c}\n";
  }

#  print STDERR "\n\n-- from:$c len:$l textLen:$TextLength -- $_\n"; 
#  PlotText($c,$c+$l-1);

  for(my $j=$#{$X}; $j >= 0 ; $j--) { 
    while(defined($KEY->{$time})) {$time--;}
	if($j==$#{$X}) {
		$KEY->{$time}{'value'} = $Value;
	}


	my $cur = $c+$j;
    if(!defined($TEXT->{$cur}) || !defined($TEXT->{$cur}{id}) ) {
	  print STDERR "Warning Insert Value at $c len:$l/$j till cur:$cur mismatch:$mismatch textLen:$TextLength\n\t$_\n"; 
      PlotText($c,$cur, 20);
	  $l = 1;
	  last;
	}
   
    if($TEXT->{$cur}{'c'}  =~ /\#/) { $TEXT->{$cur}{'c'} =  $X->[$j];}
    elsif($TEXT->{$cur}{'c'} ne $X->[$j] and $Verbose) {
      my $txt = /Text="([^\"]*)"/;

      print STDERR "MISMATCH: t:$time cur:$cur INS mism:$mismatch Value:>$Value< Text:>$txt<\n";
      PlotText($cur, $cur, 40);
      $mism = MatchCharInContext($TEXT, $cur, $X->[$j]);
	  $cur += $mism; 
      PlotText($cur, $cur, 40);
    }
	
    if($Verbose > 2) {print STDERR "\tins\ttime:$time cur:$cur mis:$mismatch Len:$TextLength sg:$TEXT->{$c+$j}{seg} id:$TEXT->{$c+$j}{id}\tValue:$Value\t$X->[$j]->$TEXT->{$c+$j}{c}\n"; }

    if ($mode eq "speech") {$KEY->{$time}{'t'} = "Sins";}
    elsif ($mode eq "auto") {$KEY->{$time}{'t'} = "Ains";}
    else {$KEY->{$time}{'t'} = "Mins";}

    # Trados segId in keystroke and 
    if($_  =~ /segId="(.*)"/ && $TEXT->{$cur}{seg} > 0 && $1 != $TEXT->{$cur}{seg}){
#	  print STDERR "INSERT: cur:$cur seg:$TEXT->{$cur}{seg} keySeg:$1 $_\n";
	}
    
    $KEY->{$time}{'k'} = $X->[$j];
    $KEY->{$time}{id}  = $TEXT->{$cur}{id};
    $KEY->{$time}{seg}  = $TEXT->{$cur}{seg};
    $KEY->{$time}{'c'} = $cur;
    $time--;
  }

  $c += $mism;
  $LastToken = $TEXT->{$c+$#{$X}}{id};
  $LastId = $TEXT->{$c}{id};
  $LastSeg = $TEXT->{$c}{seg};
  
  $LastDelCur = -1;

  # track deletion in text 
  for(my $j=$c; $j<$TextLength; $j++) {
    if(!defined($TEXT->{$j+$l}) and $j+$l < $TextLength) {
      my $tx = /Time="([0-9][0-9]*)"/;
      print STDERR "UNDEFINED: t:$tx cur:$j s:$l text:$TextLength\n";
    }
    
    $TEXT->{$j} = $TEXT->{$j+$l};     
    $TEXT->{$j+$l} = undef;
  }
#if($time < 956800) {
#printf STDERR "INS2: cur:$c seg:$TEXT->{421}{seg} $TEXT->{421}{id} $_"; 
#printf STDERR "INS3: cur:$c seg:$TEXT->{$c}{seg} $TEXT->{$c}{id} $_"; 
#}
  
  $TextLength -= $l;
#  $mismatch += $mism;
}

sub MatchCharInContext {
  my ($Text, $cur, $x) = @_;

  my $add = 10; 
  my $m = 1;
  my $o = 1;
  my $c = 1;
  for (my $i = 1; $i < $add; $i++) {
    $m *= -1;
    $o = $i * $m;
    $c = $cur + $o;
#    print STDERR "$cur $c $o\t$TEXT->{$c}{c} - $x\n";
    if($c > 0 and $c < $TextLength and 
       defined($TEXT->{$c}) and defined($TEXT->{$c}{c}) and $TEXT->{$c}{c} eq $x) {
      return $o;
    }   
    $m *= -1;
    $o = $i * $m;
    $c = $cur + $o;
#    print STDERR "$cur $c $o\t$TEXT->{$c}{c} - $x\n";
    if($c > 0 and $c < $TextLength and 
       defined($TEXT->{$c}) and defined($TEXT->{$c}{c}) and $TEXT->{$c}{c} eq $x) {
      return $o;
    }   
  }
  return 0;
}

###########
# TRADOS
##########################################################
# Guess Cursor Position for Fixation from Trados
##########################################################

sub FixationCursor {
	
    # fixation max and min X- position 
    my $H;
	foreach my $time (keys %{$FIX}) { 
		my $seg  = $FIX->{$time}{'segId'};
		my $x  = $FIX->{$time}{'x'}; # x-position
		my $w  = $FIX->{$time}{'w'}; # window
        my $idx = "$seg.$w";
        
		if(defined($H->{$idx}{'MaX'})){  
			if($H->{$idx}{'MaX'} < $x) {$H->{$idx}{'MaX'} = $x;}
		}
		else {$H->{$idx}{'MaX'} = $x}
		if(defined($H->{$idx}{'MiX'})){  
			if($H->{$idx}{'MiX'} > $x) {$H->{$idx}{'MiX'} = $x;}
		}
		else {$H->{$idx}{'MiX'} = $x}
	}

    # window 1: token max and min per source segment
	foreach my $cur (keys %{$TOK->{'src'}}) { 
		my $w = '1';
		my $seg  = $TOK->{'src'}{$cur}{'seg'};
		my $i  = $TOK->{'src'}{$cur}{'id'};
		my $idx = "$seg.$w";
        
#        print STDERR "FixationCursor0: seg:$seg w:$w idx:$idx MaT:$i $cur\n";
        
		if(defined($H->{$idx}{'MaT'})){  
			if($H->{$idx}{'MaT'} < $i) {$H->{$idx}{'MaT'} = $i;}
		}
		else {$H->{$idx}{'MaT'} = $i}
		if(defined($H->{$idx}{'MiT'})){  
			if($H->{$idx}{'MiT'} > $i) {$H->{$idx}{'MiT'} = $i;}
		}
		else {$H->{$idx}{'MiT'} = $i}

		if(defined($H->{$idx}{'MaC'})){  
			if($H->{$idx}{'MaC'} < $cur) {$H->{$idx}{'MaC'} = $cur;}
		}
		else {$H->{$idx}{'MaC'} = $cur}
		if(defined($H->{$idx}{'MiC'})){
			if($H->{$idx}{'MiC'} > $cur) {$H->{$idx}{'MiC'} = $cur;}
		}
		else {$H->{$idx}{'MiC'} = $cur}
        
#        print STDERR "FixationCursor0: idx:$idx MaT:$cur: $H->{$idx}{'MaC'}--$H->{$idx}{'MiC'}\n";

	}
	
    
    # window 2: token max and min per target segment
	foreach my $cur (keys %{$TOK->{'fin'}}) { 
		my $w = 2;
		my $seg  = $TOK->{'fin'}{$cur}{'seg'};
		my $i  = $TOK->{'fin'}{$cur}{'id'};
		my $idx = "$seg.$w";


		if(defined($H->{$idx}{'MaT'})){  
			if($H->{$idx}{'MaT'} < $i) {$H->{$idx}{'MaT'} = $i;}
		}
		else {$H->{$idx}{'MaT'} = $i}
		if(defined($H->{$idx}{'MiT'})){  
			if($H->{$idx}{'MiT'} > $i) {$H->{$idx}{'MiT'} = $i;}
		}
		else {$H->{$idx}{'MiT'} = $i}
		
		if(defined($H->{$idx}{'MaC'})){  
			if($H->{$idx}{'MaC'} < $cur) {$H->{$idx}{'MaC'} = $cur;}
		}
		else {$H->{$idx}{'MaC'} = $cur}
		if(defined($H->{$idx}{'MiC'})){  
			if($H->{$idx}{'MiC'} > $cur) {$H->{$idx}{'MiC'} = $cur;}
		}
		else {$H->{$idx}{'MiC'} = $cur}
#        print STDERR "Token2: idx:$idx MaC:$cur: $H->{$idx}{'MiC'}--$H->{$idx}{'MaC'}\n";
	}
	
	
    my $lastCur = 1;
    my $lastTok = 1;
	foreach my $time (sort {$a <=> $b} keys %{$FIX}) { 
		my $seg = $FIX->{$time}{'segId'};
		my $w = $FIX->{$time}{'w'};
		my $x = $FIX->{$time}{'x'};
		my $idx = "$seg.$w";
		
        if(!defined($H->{$idx}{'MaC'})) {
		    $FIX->{$time}{'c'} = $lastCur;
#        print STDERR "FixationCursor1: $time\t$idx \tcur:$FIX->{$time}{'c'}\n";
            next;
        }
            
		# Delta X 
		my $d = $H->{$idx}{'MaX'} - $H->{$idx}{'MiX'};
#        print STDERR "FixationCursor2: X: $idx\t$H->{$idx}{'MiX'}--$H->{$idx}{'MaX'}\tdiff:$d\t$x\n";
		# Delta Cursor
		my $c = $H->{$idx}{'MaC'} - $H->{$idx}{'MiC'};
#        print STDERR "FixationCursor3: C: $idx\t$H->{$idx}{'MiC'}--$H->{$idx}{'MaC'}\t$c\n";
		# Delta WordId
		my $i = $H->{$idx}{'MaT'} - $H->{$idx}{'MiT'};

#        print STDERR "FixationCursor4: T: $idx\t$H->{$idx}{'MiT'}--$H->{$idx}{'MaT'}\t$i\n";
		# fixation scaler
		my $s = 1-($H->{$idx}{'MaX'} - $x) / ($d +1);

#		$FIX->{$time}{'c'} = int($H->{$idx}{'MiC'});
# distribute fixations over x-axis
		$lastCur = $FIX->{$time}{'c'} = int($H->{$idx}{'MiC'} + ($s * $c));
        if($w == 2) {
            $lastTok = $FIX->{$time}{tid} = int($H->{$idx}{'MiT'} + ($s * $i));
        }
#        print STDERR "FixationCursor2: $time\t$idx \tcur:$FIX->{$time}{'c'}\t$FIX->{$time}{tid}\n";
	}
}

##########################################################
# Check all IDs matching 
##########################################################

sub  CheckAtag {
  my ($A) = @_;
  my $CkAln = {};

## Unlinked ST tokens
  $CkAln->{STaln} = 0;
  foreach my $cur (sort {$a<=>$b} keys %{$TOK->{src}}) {
    my $id = $TOK->{src}{$cur}{id};
    $CkAln->{ST} += 1;
    if(!defined($ALN->{sid}{$id}{tid})) {
      if($Verbose) {
          print STDERR "CheckAtag: Unaligned ST word id:$id\tseg:$ALN->{sid}{$id}{seg}\t$TOK->{src}{$cur}{tok}\n";
      }
      $CkAln->{STaln} += 1;      
  }}

  ## Unlinked TT tokens
  $CkAln->{TTaln} = 0;
  foreach my $cur (sort {$a<=>$b} keys %{$TOK->{fin}}) {
    my $id = $TOK->{fin}{$cur}{id};
    $CkAln->{TT} += 1;
    if(!defined($ALN->{tid}{$id}{sid})) {
      if($Verbose) {
          print STDERR "CheckAtag: Unaligned TT word id:$id\tseg:$ALN->{tid}{$id}{seg}\t$TOK->{fin}{$cur}{tok}\n";
      }
      $CkAln->{TTaln} += 1;
  }	}

  
## All ST linked tokens are within segments
  foreach my $sid (sort {$a<=>$b} keys %{$ALN->{sid}}) {

    if($sid == 0) {next;}
    my $src = $ALN->{sid}{$sid}{seg};
    foreach my $tid (sort {$a<=>$b} keys %{$ALN->{sid}{$sid}{tid}}) {
      if($tid == 0) {next;}
      my $tgt = $ALN->{tid}{$tid}{seg};
      if(!defined($tgt)) {
	    print STDERR "CheckAtag: ST word alignment $sid <-> $tid in segment src:$src with no target segment\n";
      }
      elsif(!defined($ALN->{src}{$src}{tgt}{$tgt})) {
        print STDERR "CheckAtag: ST-TT word alignment id:$sid-$tid\tacross defined segment boundaries $src-$tgt\n";
		$ALN->{src}{$src}{bad}{$tgt} = 1;
  } } }
  
## All TT token are within segments
  foreach my $tid (sort {$a<=>$b} keys %{$ALN->{tid}}) {
    if($tid == 0) {next;}
    my $tgt = $ALN->{tid}{$tid}{seg};
    if(!defined($tgt)) {
        print STDERR "CheckAtag: tgt id:$tid undefined segment\n";
        next;
    }
    foreach my $sid (sort {$a<=>$b} keys %{$ALN->{tid}{$tid}{sid}}) {
      if($sid == 0) {next;}
      my $src = $ALN->{sid}{$sid}{seg};
#print STDERR "CheckAtag: src:$src/$sid  tgt:$tgt/$tid\n";
#d($ALN->{src}{$src});
      if(defined($ALN->{src}{$src}{bad}{$tgt})) {next;}
      if(!defined($ALN->{src}{$src}{tgt}{$tgt})) {
        print STDERR "CheckAtag: TT-ST word alignment id:$tid-$sid\tacross defined segment boundaries $tgt-$src\n";
  } } }

## All links have a token 
  foreach my $sid (keys %{$ALN->{sid}}) { 
    if($sid == 0) {next;}
    if(!defined($ALN->{sid}{$sid}{seg})) {
	  print STDERR "CheckAtag: Alignment >$sid< no ST Token\n";
    }
    else {$ALN->{src}{$ALN->{sid}{$sid}{seg}}{tok} ++;}	
  }

  foreach my $tid (keys %{$ALN->{tid}}) { 
    if($tid == 0) {next;}

    if(!defined($ALN->{tid}{$tid}{seg})) {
	  print STDERR "CheckAtag: Alignment >$tid< no TT Token\n";
    } 
    else {$ALN->{tgt}{$ALN->{tid}{$tid}{seg}}{tok} ++;}	
  }

## No empty segments   
  foreach my $src (keys %{$ALN->{src}}) { 
    if(!defined($ALN->{src}{$src}{tok})) {
	  print STDERR "CheckAtag: Source segment >$src< with no ST Tokens\n";
  } }

  foreach my $tgt (keys %{$ALN->{tgt}}) { 
    if(!defined($ALN->{tgt}{$tgt}{tok})) {
	  print STDERR "CheckAtag: Target segment >$tgt< with no TT Tokens\n";
  } }
  print STDERR "CheckAtag: ST words:$CkAln->{ST} unaligned:$CkAln->{STaln}\n";
  print STDERR "CheckAtag: TT words:$CkAln->{TT} unaligned:$CkAln->{TTaln}\n";
  
}

##########################################################
# Map CHR gaze and fixations on ST
##########################################################

sub MapSource {

  my $id=1;
  foreach my $cur (sort {$a <=> $b} keys %{$CHR->{src}}) { 
#print STDERR "Map $k $s\n";
    if(defined($TOK->{src}{$cur})) {$id=$TOK->{src}{$cur}{id};}
    $CHR->{src}{$cur}{'id'} = $id;
  }
 
  ## initialise word id in Eye data on ST
  foreach my $time (sort {$a <=> $b} keys %{$EYE}) { 
    if($EYE->{$time}{'w'} != 1) {next;}
    my $c = $EYE->{$time}{'c'};
    $EYE->{$time}{'id'}= $CHR->{src}{$c}{'id'}; 
  }

  ## initialise word id in Fix data on ST
  foreach my $time (sort {$a <=> $b} keys %{$FIX}) { 
    if($FIX->{$time}{'w'} != 1) {next;}
    my $c = $FIX->{$time}{'c'};
    $FIX->{$time}{'sid'} = $CHR->{src}{$c}{'id'}; 
  }
}


################################################
#  PRINTING
################################################

sub FixModTable {
  my ($m);

  foreach my $i (sort {$b<=>$a} keys %{$TRANSLOG}) { 
      if($TRANSLOG->{$i} =~ /<\/logfile>/i) {$m=$i;last; }
  }

  my $finSeg = {};  
  foreach my $c (keys %{$TOK->{fin}}) {
    my $id = $TOK->{fin}{$c}{id};
	$finSeg->{$id}{seg} = $TOK->{fin}{$c}{seg};
  }
  
  $TRANSLOG->{$m++} ="  <Fixations>\n";
  my $seg = 0;
  foreach my $t (sort {$a<=>$b} keys %{$FIX}) {

    if($FIX->{$t}{w} == 0) {next}

#if($FIX->{$t}{segId} == 11) {
#print STDERR "FixModTable1:$t $FIX->{$t}{w}\tseg:$FIX->{$t}{segId}\tcur:$FIX->{$t}{c}\ttid:$FIX->#{$t}{tid} sid:$FIX->{$t}{sid}\n";
#}

# source window
    if($FIX->{$t}{w} == 1) {
      $FIX->{$t}{tid} = '';
# most likely fixation on first character
      if(!defined($FIX->{$t}{sid})) {$FIX->{$t}{sid} = 1}
      my $id=$FIX->{$t}{'sid'};

      if(defined($ALN->{'sid'}) && defined($ALN->{'sid'}{$id})) { 
        my $k = 0;
        foreach my $sid (sort  {$a <=> $b} keys %{$ALN->{'sid'}{$id}{'tid'}}) {
          if($k >0) {$FIX->{$t}{tid} .= "+";}
          $FIX->{$t}{tid} .= $sid;
          $k++;
        }
      }  
	  if($FIX->{$t}{tid} eq '') { $FIX->{$t}{tid} = 0}
      my $f=-1;
      foreach my $c (keys %{$TOK->{src}}) {
        if($TOK->{src}{$c}{id} == $id && defined($TOK->{src}{$c}{seg})) { 
          $seg = $TOK->{src}{$c}{seg}; $f=$c;last}
      }
      if($f<0) {print STDERR "No FIX seg at time $t Source Token id:$id\n";}
    }
# target window
    elsif ($FIX->{$t}{w} == 2) {
      $FIX->{$t}{sid} = '';
      
# most likely fixation on first character
      if(!defined($FIX->{$t}{tid})) {$FIX->{$t}{tid} = 1; }
      my $id=$FIX->{$t}{'tid'};
############
#      print STDERR "tid_Time1 $t $FIX->{$t}{tid}\n";

      if(defined($ALN->{'tid'}) && defined($ALN->{'tid'}{$id})) {  
        my $k = 0;
        foreach my $sid (sort  {$a <=> $b} keys %{$ALN->{'tid'}{$id}{'sid'}}) {
          if($k >0) {$FIX->{$t}{sid} .= "+";}
          $FIX->{$t}{sid} .= $sid;
          $k++;
        }
      }
	  if($FIX->{$t}{sid} eq '') { $FIX->{$t}{sid} = 0}
	  my $f=-1;
	  foreach my $c (keys %{$TOK->{fin}}) {
		if($TOK->{fin}{$c}{id} == $id && defined($TOK->{fin}{$c}{seg})) { 
          $seg = $TOK->{fin}{$c}{seg}; $f=1; last
        }
	  }
	  if($f<0) {$seg=1;}
    } 
    # no window assigned
    else {next;}

	# segId is in Trados file
    if(defined($FIX->{$t}{segId})) {$seg=$FIX->{$t}{segId}}

    $TRANSLOG->{$m++} = "    <Fix time=\"$t\" win=\"$FIX->{$t}{w}\" cur=\"$FIX->{$t}{c}\" dur=\"$FIX->{$t}{d}\" X=\"$FIX->{$t}{x}\" Y=\"$FIX->{$t}{y}\" segId=\"$seg\" sid=\"$FIX->{$t}{sid}\" tid=\"$FIX->{$t}{tid}\" />\n";
  }
  $TRANSLOG->{$m++} ="  </Fixations>\n";

  $TRANSLOG->{$m++} ="  <Modifications>\n";

  foreach my $t (sort {$a<=>$b} keys %{$KEY}) {
	
    if(!defined($KEY->{$t}{value})) { next;}
	
    if(!defined($KEY->{$t}{id})) { 
      print STDERR "KEY Undefined id at time $t set to 0\n";
      d($KEY->{$t});
      $KEY->{$t}{id} = 0;
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
    if($s eq '') {$s = 0;}
	
#    my $chr = MSescape($KEY->{$t}{k});
    my $chr = MSescape($KEY->{$t}{value});

    if (!defined($KEY->{$t}{x})) {
      $KEY->{$t}{x} = $KEY->{$t}{y} = $KEY->{$t}{w} = $KEY->{$t}{h} = 0;
    }

    my $f=0;
    if(defined($KEY->{$t}{seg})) {$seg = $KEY->{$t}{seg};}
    else {
      if(defined($finSeg->{$KEY->{$t}{id}})) {$seg = $finSeg->{$KEY->{$t}{id}}{seg}
      }
      else {print STDERR "Segment unknown: time $t key:$KEY->{$t}{k} type=$KEY->{$t}{t} WId:$KEY->{$t}{id} Segment:$seg\n";}
	  $KEY->{$t}{seg} = $seg;
    }
	
	my $dur = "";
	my $strokes = "";
	if(defined($KEY->{$t}{dur})) {$dur = "dur=\"$KEY->{$t}{dur}\" "; }
	if(defined($KEY->{$t}{knum})){$strokes = "strokes=\"$KEY->{$t}{knum}\" ";} 
	
    my $x = int($KEY->{$t}{x} + ($KEY->{$t}{w} / 2));
    my $y = int($KEY->{$t}{y} + ($KEY->{$t}{h} / 2));
    if($KEY->{$t}{t} eq '') {$KEY->{$t}{t} = '---';}
	
    $TRANSLOG->{$m++} = "    <Mod time=\"$t\" type=\"$KEY->{$t}{t}\" cur=\"$KEY->{$t}{c}\" chr=\"$chr\" X=\"$x\" Y=\"$y\" segId=\"$seg\" sid=\"$s\" tid=\"$KEY->{$t}{id}\" $dur $strokes/>\n";
  }
  $TRANSLOG->{$m++} ="  </Modifications>\n";
  
  if(defined($EXT)) {
    $TRANSLOG->{$m++} ="  <External>\n";
	my $title = '';
    foreach my $t (sort {$a<=>$b} keys %{$EXT}) {
      if(defined($EXT->{$t}{title})) {
        $TRANSLOG->{$m++} = "    <Focus  time=\"$t\" title=\"$EXT->{$t}{title}\" />\n";
	    $title = $EXT->{$t}{title};
      }
      if($title =~ /Translog-II/) {next;}
	  if (defined($EXT->{$t}{value} && $EXT->{$t}{edition})) {
        $TRANSLOG->{$m++} = "    <$EXT->{$t}{edition}  time=\"$t\" value=\"$EXT->{$t}{value}\" />\n";
    } }
    $TRANSLOG->{$m++} ="  </External>\n";
  }  
  
  $TRANSLOG->{$m++} ="  <Segments>\n";
  $seg = -1;
  my $t1 = 0;
  my $t2 = 0;
  foreach my $t (sort {$a<=>$b} keys %{$KEY}) {
  	if($seg ne $KEY->{$t}{seg}) {
	  if($t1 != 0) {
        $TRANSLOG->{$m++} = "    <Seg segId=\"$seg\" open=\"$t1\" close=\"$t2\" />\n";
      }
	  $seg = $KEY->{$t}{seg};
	  $t1 = $t-1;
    }
    $t2 = $t-2;
  }
  if($t2 > 0) {$TRANSLOG->{$m++} = "    <Seg segId=\"$seg\" open=\"$t1\" close=\"$t2\" />\n";}
  $TRANSLOG->{$m++} ="  </Segments>\n";
  
  $TRANSLOG->{$m++} ="<\/LogFile>\n";

}

sub PrintTranslog{
  my ($fn) = @_;
  my $m;

  open(FILE, '>:encoding(utf8)', $fn) || die ("cannot open file $fn for writing");

  foreach my $k (sort {$a<=>$b} keys %{$TRANSLOG}) { print FILE "$TRANSLOG->{$k}"; }
  close(FILE);

}
