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
my $map = { map { $_ => 1 } split( //o, "\t\n\r\f\"" ) };

my $FUFixGap = 400;
my $PUKeyGap = 1000;
my $AUpauseGap = 1000;
my $AUgazeMerge = 250;

my $HalfFixationRadius = 40; # GazePath turns


my $usage =
  "Extract tables from Translog.Event.xml file: \n".
  "  -T in:  (basename).Event.xml filename\n".
  "  -O path: Output path for path/basename.{st,tt,au ...}\n".
  "Options:\n".
  "  -f min fixation gap in FU [$FUFixGap]\n".
  "  -a min pause gap in AU [$AUpauseGap]\n".
  "  -g min pause gap in AU [$AUgazeMerge]\n".
  "  -p min production unit boundary [$PUKeyGap]\n".
  "  -v verbose mode [0 ... ]\n".
  "  -h this help \n".
  "\n";

use vars qw ($opt_O $opt_T $opt_a $opt_f $opt_g $opt_p $opt_v $opt_k $opt_h);

use Getopt::Std;
getopts ('T:O:p:k:f:v:c:a:g:h');

die $usage if defined($opt_h);

my $ALN = undef;

my $SRC = undef;
my $TGT = undef;
my $KEY = undef;
my $FIX = undef;
my $EXT = undef;
my $SS = undef;
my $SG = undef;
my $FU = undef;
my $PU = undef;
my $AG = undef;
my $AU = undef;
my $SourceLang = '';
my $TargetLang = '';
my $Study = '';
my $Text = '';
my $Task = '';
my $Part = '';
my $SessionDuration = 0;
my $SessionPause = 0;

my $DraftingStart = 10000000000;
my $DraftingEnd = 0;

my $Verbose = 0;
my $Tid2AG = {};
my $Tid2Sid = {};
my $Session = '';
my $WarningsCount = {};
        
if (defined($opt_v)) {$Verbose = $opt_v;}
if (defined($opt_p)) {$PUKeyGap = $opt_p;}
if (defined($opt_f)) {$FUFixGap = $opt_f;}
if (defined($opt_a)) {$AUpauseGap = $opt_a;}
if (defined($opt_g)) {$AUgazeMerge = $opt_g;}

if(!defined($opt_O)) {$opt_O = ''}

if (!defined($opt_T)) {
	printf STDOUT "No Output produced\n";
	die $usage;
}

$WarningsCount->{StartTime} = time();
  

# Read and Tokenize Translog log file
if(ReadTranslog($opt_T) == 0) {
    print STDERR "ProgGraphTables.pl WARNING: no process data in $opt_T\n";
}

if($SourceLang eq '' || $TargetLang eq '') { 
    print STDERR "ERROR $opt_T no language specified\n";
	$WarningsCount->{noLanguage} ++;
    exit 1;
}

($Study, $Session) = $opt_T =~ /.*\/([^\/]*)\/Events.*\/([^.]*)\.Event.xml/;
($Part, $Task, $Text) = $Session =~/([^_]*)_([A-Za-z]*)([0-9]*)/;

#print STDERR "$opt_T\t>$Study<\t>$Session<\t>$Part<\t$Task\t$Text\n";

if(!defined($Study) || !defined($Part) || !defined($Task) || !defined($Text)) {
    print STDERR "$opt_T: Incorrect filename or path\n";
	exit;
}


## External data, delete fixations outside Transloag
ExternalData();

## Features for KD file
KeystrokesData();
  

## Alignment Groups
if(defined($ALN)) { 
#	addProcessingTime("MakeAlignGroups");
    MakeAlignGroups();
	
#	addProcessingTime("AlignmentGroups");
    AlignmentGroups('au');
		
#	addProcessingTime("CrossingAlignmentGroups");
    CrossingAlignmentGroups();
}

## Fixation Units
#  addProcessingTime("FixationUnits");
FixationUnits();

## Target Token Units
MakeTargetUnits();
TargetTokenUnits();
CrossFeature($TGT, 'ttid', 'sid', 'TTseg');

## Source Token Units
MakeSourceUnits();
AlignmentGroups('st');

SourceTargetID();
CrossFeature($SRC, 'stid', 'tid', 'STseg');

ProductionUnits();
AddPUtoST();

# Segments
SegmentSummary();
  
# Session
SessionSummary();

## For all tokens/Units
ParallelActivity();
GazeTimeOnToken();
EditEfficiency();


#
ActivityUnits();

  ## Fixation data for PU
FixationData();
  
##############################################
############ PRINTING ########################

###### Session
my @SSlabels = qw(ALseg STseg TTseg Dur TimeD TimeR Break FDur TD5000 TD1000 TB1000 FDurSeg DurSeg Scatter FixS TrtS FixT TrtT Ins Del TokS LenS TokT LenT);

###########
my @SGlabels = qw(STseg TTseg Nedit Dur FDur PreGap TG300 TD300 TB300 TG500 TD500 TB500 TG1000 TD1000 TB1000 TG2000 TD2000 TB2000 TG5000 TD5000 TB5000 Scatter FixS TrtS FixT TrtT ParFixS ParTrtS ParFixT ParTrtT Ins Del TokS LenS TokT LenT LenMT Yawat String);

## Alignment Group
my @AGlabels = qw(STseg TTseg SGroup SGnbr SGid TGroup TGnbr TGid Ins Del Pause Dur PosS PosT Munit Cross Edit1 Time1 Dur1 Pause1 Pause1TrtS Pause1TrtT ParFixS1 ParTrtS1 ParFixT1 ParTrtT1 Edit2 Time2 Dur2 Pause2 Pause2TrtS Pause2TrtT ParFixS2 ParTrtS2 ParFixT2 ParTrtT2 TimeR  DurR EditR Runit FixS FPDurS TrtS FixT FPDurT TrtT ParFixS ParTrtS ParFixT ParTrtT InEff Edit);

###### Target Tokens
my @TTlabels = qw(TTseg TToken Lemma SGid SGroup SGnbr Cur Ins Del Pause Dur Prob1 Prob2 PoS UPoS TGroup  TGnbr Munit Cross Edit1 Time1 Dur1 Pause1 Pause1TrtS Pause1TrtT ParFixS1 ParTrtS1 ParFixT1 ParTrtT1 Edit2 Time2 Dur2 Pause2 Pause2TrtS Pause2TrtT ParFixS2 ParTrtS2 ParFixT2 ParTrtT2 TimeR  DurR EditR Runit FFTime FFDTime FFDur RPDur Regr FixS FPDurS TrtS FixT FPDurT TrtT ParFixS ParTrtS ParFixT ParTrtT InEff Yawat Edit);

###########
my @STlabels = qw(STseg SToken Lemma SGid SGroup SGx SGnbr STime Cur Ins Del Pause Dur Sdur Prob1 Prob2 PoS UPoS TGroup TGid TGnbr Munit Cross Edit1 Time1 Dur1 Pause1 Pause1TrtS Pause1TrtT ParFixS1 ParTrtS1 ParFixT1 ParTrtT1 Edit2 Time2 Dur2 Pause2 Pause2TrtS Pause2TrtT ParFixS2 ParTrtS2 ParFixT2 ParTrtT2 TimeR DurR EditR Runit FFTime FFDTime FFDur RPDur Regr FixS FPDurS TrtS FixT FPDurT TrtT ParFixS ParTrtS ParFixT ParTrtT InEff Yawat PUnbr PUdur PUpause PUsid PUtid PUslen PUtlen Edit);


# Production Units
my @PUlabels = qw(TimeTU DurTU Time Pause Dur Phase Ins Del STseg TTseg SGid TGid SGnbr TGnbr Scatter CrossS CrossT PosS PosT WinSwitch GazePath FixS TrtS FixT TrtT ParFixS ParTrtS ParFixT ParTrtT TurnXS FixSspanX FixSspanY TurnXT FixTspanX FixTspanY FixSmeanX FixSmeanY FixTmeanX FixTmeanY FixSdist FixSmean FixSstd FixTdist FixTmean FixTstd Yawat Edit);

# Activity Unit
my @AUlabels = qw(Time Phase Type Dur SGid SGnbr TGid TGnbr Ins Del PosS PosT Scatter CrossS CrossT Gram5 GazePath FixS TrtS FixT TrtT TurnXS TurnXT TTseg WinSwitch FixSmeanX FixSmeanY FixSspanX FixSspanY FixTmeanX FixTmeanY FixTspanX FixTspanY FixSmean FixTmean FixSstd FixTstd Edit);

# Fixation Units
my @FUlabels = qw(Time Dur Win Fix Span Turn FixKeyDist Seg GazePath) ;

# Keystrokes
my @KDlabels = qw(Time Pause Border Type Cur Char TTseg STid SGid TTid Strokes Dur EdStr LsDist Draft DistCur DistTTid);

# Fixations
my @FDlabels = qw(Time Dur Win Seg STid SGid TTid TGid Cur X Y Paral Edit EDid );

# External
my @EXTlabels = qw(Focus Time Dur nFix DFix  Edit Return KDidN KDidL SGidN SGidL TTsegN TTsegL );

my $SS1 = {};
$SS1->{0} = $SS;
DefaultValues($SS1);
PrintTemplate("$opt_O$Session.ss", \@SSlabels, $SS1);
DefaultValues($SG);
PrintTemplate("$opt_O$Session.sg", \@SGlabels, $SG);
DefaultValues($AG);
PrintTemplate("$opt_O$Session.ag", \@AGlabels, $AG);
DefaultValues($TGT);
PrintTemplate("$opt_O$Session.tt", \@TTlabels, $TGT);
DefaultValues($SRC);
PrintTemplate("$opt_O$Session.st", \@STlabels, $SRC);
DefaultValues($KEY);
PrintTemplate("$opt_O$Session.kd", \@KDlabels, $KEY);
DefaultValues($FIX);
PrintTemplate("$opt_O$Session.fd", \@FDlabels, $FIX);
DefaultValues($AU);
PrintTemplate("$opt_O$Session.au", \@AUlabels, $AU);
DefaultValues($PU);
PrintTemplate("$opt_O$Session.pu", \@PUlabels, $PU);
DefaultValues($TGT);
PrintTemplate("$opt_O$Session.fu", \@FUlabels, $FU);
DefaultValues($EXT);
PrintTemplate("$opt_O$Session.ex", \@EXTlabels, $EXT);
	  
addProcessingTime("ProcessingTime");
printProcessingTime();

exit 0;


###################################################
sub addProcessingTime {
	my ($func) = @_;
	$WarningsCount->{$func} += time() - $WarningsCount->{StartTime};
	$WarningsCount->{StartTime} = time();
}

sub printProcessingTime {
	my ($func, ) = @_;
	
	for my $f (sort keys %{$WarningsCount}) {
		if($f eq "StartTime") {next;}
		if($WarningsCount->{$f} == 0) {next;}
		if($Verbose){print STDERR "\t$f\t$WarningsCount->{$f}\n";}
}	}

############################################################
# escape
############################################################

sub escape {
  my ($in) = @_;
#printf STDERR "in: $in\n";
  $in =~ s/(.)/exists($map->{$1})?sprintf('\\%04x',ord($1)):$1/egos;
  return $in;
}

sub unescape {
  my ($in) = @_;
  $in =~ s/\\([0-9a-f]{4})/sprintf('%c',hex($1))/egos;
  return $in;
}

sub MSunescape {
  my ($in) = @_;

  $in =~ s/&amp;/\&/g;
  $in =~ s/&gt;/\>/g;
  $in =~ s/&lt;/\</g;
  $in =~ s/&#xA;/\n/g;
  $in =~ s/&#10;/\n/g;
  $in =~ s/&#xD;/\r/g;
  $in =~ s/&#x9;/\t/g;
  $in =~ s/&#9;/\t/g;
  $in =~ s/&#10;/\n/g;
  $in =~ s/&quot;/"/g;
  $in =~ s/&nbsp;/ /g;
  return $in;
}

## escape for R tables
sub Rescape {
  my ($in) = @_;

#  $in =~ s/([ \t\n\r\f\#\'\"\\])/_/g;
  $in =~ s/([ \t\n\r\f])/_/g;
  $in =~ s/([\"])/'/g;
  return $in;

}

##########################################################
# Read Translog Logfile
##########################################################

## SourceText Positions
sub ReadTranslog {
  my ($fn) = @_;
  my ($id);

  my $n = 0;
  my $KeyCount = 0;

  open(FILE, '<:encoding(utf8)', $fn) || die ("cannot open file $fn");

  my $type = 0;
  my $time = 0;
  my $lastMod = 0;
  my $SessionStart = 0;
  my $SessionStop = 0;
  my $Session = {};
  my $maxTid = 0;
  my $SessionRun = 0;
  my $LastSegClose =0;
  
  while(defined($_ = <FILE>)) {
#printf STDERR "Translog: %s\n",  $_;

    if(/<System / && /Value="STOP"/) {
      if(/Time="([^\"]*)"/) {$SessionDuration = $1 - $SessionStart;  $SessionStop = $1;}
    }
	elsif(/<segmentClosed / && /time="([0-9][0-9]*)/ ) {$LastSegClose = $1}
    elsif(/<stopSession / && /time="([0-9][0-9]*)/ ) {
      $SessionStop = $1; 
	  $SessionRun = 0;
	  $SessionDuration = $1-$SessionStart-$SessionPause;
#printf STDERR "stop:\t$SessionStop time:%d\tpause:$SessionPause\tdur:$SessionDuration\n", $1-$SessionStart;
    }
    elsif(/<startSession/ && /time="([0-9][0-9]*)"/) {
	  if($SessionRun == 1) {$SessionStop = $LastSegClose;}
      $SessionRun = 1;

      if($SessionStart == 0) {$SessionStart = $1;}
      else {$SessionPause += $1 - $SessionStop; $Session->{$1-$SessionStart} = $SessionPause;}
    }

    if(/<Language/i) {
      if(/source="([^\"]*)"/i) {$SourceLang = $1; }
      if(/target="([^\"]*)"/i) {$TargetLang = $1; }
    }

    elsif(/<SourceToken/)  {$type = 1; }
    elsif(/<Fixations/)    {$type = 2; }
    elsif(/<Modifications/){$type = 3; }
    elsif(/<ModificationFinal/){$type = 3; }
    elsif(/<ModificationSource/){$type = 12; }
    elsif(/<Alignment/)    {$type = 4; }
    elsif(/<FinalToken/)   {$type = 6; }
    elsif(/<Segment/)      {$type = 7; }
    elsif(/<Salignment/)   {$type = 8; }
    elsif(/<sourceText/)   {$type = 9; }
    elsif(/<initialTargetText/)   {$type = 10; }
    elsif(/<External/i)   {$type = 11; }
	
    if($type == 1 && /<Token/) {
      if(/ id="([^\"]+)"/)   {$id = $1;}
	  else {$id  = 0; $WarningsCount->{NoSrcId} ++;}
	  
      if(/cur="([^\"]*)"/)   {$SRC->{$id}{Cur}  = $1;}
	  else {$SRC->{$id}{Cur}  = 0;}
	  
      if(/tok="([^\"]*)"/)   {$SRC->{$id}{SToken} = Rescape(MSunescape($1));}
	  else {$SRC->{$id}{SToken} = '---'; $WarningsCount->{NoSrcTToken} ++;}
	  
      if(/Prob1="([^\"]*)"/) {$SRC->{$id}{Prob1} = $1;}
      if(/Prob2="([^\"]*)"/) {$SRC->{$id}{Prob2} = $1;}
      if(/pos="([^\"]*)"/)   {$SRC->{$id}{PoS} = $1;} else {$SRC->{$id}{PoS} = '---';}
      if(/space="([^\"]*)"/) {$SRC->{$id}{space} = Rescape(MSunescape($1));}
	  
      if(/yawat="([^\"]*)"/) {$SRC->{$id}{Yawat} = $1;}
      else {$SRC->{$id}{Yawat} = '---';}
	  
      if(/time="([^\"]+)"/)  {$SRC->{$id}{STime} = $1;}
	  else {$SRC->{$id}{STime} = 0;}
	  
      if(/dur="([^\"]*)"/)   {$SRC->{$id}{Sdur} = $1;}
      else   {$SRC->{$id}{Sdur} = 0;}
	  
	  
      if(/segId="([^\"]+)"/) {$SRC->{$id}{STseg}  = $1;}
      elsif(/seg="([^\"]*)+/){$SRC->{$id}{STseg}  = $1;}
      else {$SRC->{$id}{STseg}  = 0; $WarningsCount->{NoSrcSeg} ++;}
	  
      if(/Lemma="([^\"]*)"/) {$SRC->{$id}{Lemma} = Rescape(MSunescape($1));}
      else {$SRC->{$id}{Lemma} = '---'}
	  
      if(/ pos="([^\"]*)"/)   {$SRC->{$id}{PoS} = Rescape(MSunescape($1));}
      elsif(/ xpos="([^\"]*)"/)   {$SRC->{$id}{PoS} = Rescape(MSunescape($1));}
      else {$SRC->{$id}{PoS} = '---'}
 
      if(/ upos="([^\"]*)"/)   {$SRC->{$id}{UPoS} = Rescape(MSunescape($1));}
      else {$SRC->{$id}{UPoS} = '---'}
      
    }
    if($type == 6 && /<Token/) {
      if(/ id="([0-9][0-9]*)"/) {$id =$1;}
      if(/tok="([^\"]+)"/)   {$TGT->{$id}{TToken} = Rescape(MSunescape($1));}
	  else {$TGT->{$id}{TToken} = '---'; $WarningsCount->{NoTgtTToken} ++;}
	  
      if(/Prob1="([^\"]*)"/) {$TGT->{$id}{Prob1} = $1;}
      if(/Prob2="([^\"]*)"/) {$TGT->{$id}{Prob2} = $1;}
      if(/space="([^\"]*)"/) {$TGT->{$id}{space} = Rescape(MSunescape($1));}
      if(/cur="([^\"]+)"/)   {$TGT->{$id}{Cur}  = $1;}
	  else {$TGT->{$id}{Cur} = 0; $WarningsCount->{NoTgtCur} ++;}
	  
      if(/pos="([^\"]*)"/)   {$TGT->{$id}{PoS} = $1;} 
	  else {$TGT->{$id}{PoS} = '---';}
	  
      if(/yawat="([^\"]*)"/) {$TGT->{$id}{Yawat} = $1;}
	  else {$TGT->{$id}{Yawat} = '---';}

      if(/segId="([^\"]+)"/) {$TGT->{$id}{TTseg}  = $1;}
      elsif(/seg="([^\"]+)"/){$TGT->{$id}{TTseg}  = $1;}
      else {$TGT->{$id}{TTseg}  = 0;   $WarningsCount->{NoTgtTseg} ++;}
	  	  
      if(/Lemma="([^\"]*)"/) {$TGT->{$id}{Lemma} = Rescape(MSunescape($1));}
      else {$TGT->{$id}{Lemma} = '---'}
	  
      if(/ pos="([^\"]*)"/)   {$TGT->{$id}{PoS} = Rescape(MSunescape($1));}
      elsif(/ xpos="([^\"]*)"/)   {$TGT->{$id}{PoS} = Rescape(MSunescape($1));}
      else {$TGT->{$id}{PoS} = '---'}
	  
      if(/ upos="([^\"]*)"/)   {$TGT->{$id}{UPoS} = Rescape(MSunescape($1));}
      else {$TGT->{$id}{UPoS} = '---'}
    }
    elsif($type == 2 && /<Fix /) {
#printf STDERR "Translog: %s",  $_;
      if(/time="([0-9][0-9]*)"/) {$time =$1-$SessionStart; }
	  
	  if($time < 0) {
		  print STDERR "WARNING: FIXATION Time $time  Start: $SessionStart Fixation:$1\n";
		  next;
	  }
      $FIX->{$time}{Time} = $time;
      if(/win="([^\"]+)"/)        {$FIX->{$time}{Win} = $1;}
      else {$FIX->{$time}{Win}  = 0;  $WarningsCount->{NoFixWin} ++;}
	  
      if(/dur="([0-9][0-9]*)"/)  {$FIX->{$time}{Dur} = $1;}
      else {$FIX->{$time}{Dur}  = 0;  $WarningsCount->{NoFixDur} ++;}
	  
      if(/cur="([-0-9][0-9]*)"/) {$FIX->{$time}{Cur}  = $1;}
      else {$FIX->{$time}{Cur}  = 0;  $WarningsCount->{NoFixCur} ++;}
	  
      if(/segId="([^\"]*)"/)      {$FIX->{$time}{Seg}  = $1;}
      elsif(/seg="([^\"]+)"/)     {$FIX->{$time}{Seg}  = $1;}
      else {$FIX->{$time}{Seg}  = 0;  $WarningsCount->{NoFixSeg} ++;}
	  
      if(/X="([^\"]+)"/)          {$FIX->{$time}{X} = $1;}
      else {$FIX->{$time}{X}  = 0;   $WarningsCount->{NoFixX} ++;}
	  
      if(/Y="([^\"]+)"/)          {$FIX->{$time}{Y} = $1;}
      else {$FIX->{$time}{Y}  = 0;   $WarningsCount->{NoFixY} ++;}
	  
      if(/tid="([^\"]+)"/)        {$FIX->{$time}{TGid}  = $1;}
      else {$FIX->{$time}{TGid}  = 0;   $WarningsCount->{NoFixTid} ++;}
	  $FIX->{$time}{TTid} = (sort {$a <=> $b} split(/\+/, $FIX->{$time}{TGid}))[0];
	  
      if(/sid="([^\"]+)"/)        {$FIX->{$time}{SGid}  = $1;}
      else {$FIX->{$time}{SGid}  = 0;  $WarningsCount->{NoFixSid} ++;}
	  $FIX->{$time}{STid} = (sort {$a <=> $b} split(/\+/, $FIX->{$time}{SGid}))[0];

      $n += 1;

    }
    elsif($type == 3 && /<Mod /) {
      if(/type="---"/) {next;}

      if(/time="([0-9][0-9]*)"/) {$time = $1-$SessionStart;}
	  
	  ## ignore not-assigned keystrokes (Trados)
      next if(/segId="([^\"]*)"/ && $1 == 0); 
	  
      $KEY->{$time}{Time}  = $time;
      if(/segId="([^\"]*)"/)      {$KEY->{$time}{TTseg}  = $1;}
      elsif(/seg="([^\"]*)"/)      {$KEY->{$time}{TTseg}  = $1;}
      else {$KEY->{$time}{TTseg}  = -1;  $WarningsCount->{NoKeyTTseg} ++;}
	  
      if(/cur="([0-9][0-9]*)"/)  {$KEY->{$time}{Cur}  = $1;}
	  else { $KEY->{$time}{Cur} = 0;}
	  
      if(/chr="([^\"]*)"/)        {
		  $KEY->{$time}{ochar} = MSunescape($1);
          $KEY->{$time}{Char} = Rescape(MSunescape($1));
      }
      if(/type="([^\"]+)"/)       {$KEY->{$time}{Type} = $1;}
      else  {$KEY->{$time}{Type} = 'ins'; $WarningsCount->{NoKeyType} ++;}

      if(/strokes="([^\"]*)"/)    {$KEY->{$time}{Strokes} = $1;}
	  else {$KEY->{$time}{Strokes} = length($KEY->{$time}{ochar});}

      if(/dur="([^\"]*)"/)        {$KEY->{$time}{Dur} = $1;}
	  else {$KEY->{$time}{Dur} = 0;}

      if(/tid="([^\"]+)"/)        {$KEY->{$time}{TTid}  = $1;}
      else {$KEY->{$time}{TTid} = 0; $WarningsCount->{NoKeyTid} ++;}
		
      if(/sid="([^\"]+)"/)        {$KEY->{$time}{SGid}  = $1;}
      else {$KEY->{$time}{SGid} = 0; $WarningsCount->{NoKeySid} ++;}
	  $KEY->{$time}{STid} = (sort {$a <=> $b} split(/\+/, $KEY->{$time}{SGid}))[0];
	  
      if(/CoherentEdit="([^\"]*)"/) {$KEY->{$time}{EdStr} = $1;}
	  else {$KEY->{$time}{EdStr} = 0;}
	  
      if(/LSDist="([^\"]*)"/)     {$KEY->{$time}{LSdist} = $1;}
	  else {$KEY->{$time}{LsDist} = 0;}  	  
	  
      $KEY->{$time}{nbr} = $KeyCount ++;
      $n += 2;

	## heuristic to compute a better DraftingEnd
      my $P = $time;
	  foreach my $t (sort  {$b <=> $a} keys %{$Session}) {
	    if($t < $time) { $P -= $Session->{$t}; last}
      }
      if($DraftingStart > $P) { $DraftingStart = $P;}
	  	  
      if(0.62*($SessionStop - $SessionStart) <= $time && $KEY->{$time}{TTid}  > $maxTid) {
		$maxTid=$KEY->{$time}{TTid} ; 
		$DraftingEnd = $time;
      }
	  $lastMod = $time;
#printf  STDERR "time:\t$time\tstart:$SessionStart/$DraftingStart end:$SessionStop/$DraftingEnd maxTid:$maxTid R:%d\n",  0.62*($SessionStop - $SessionStart);

    }

    if($type == 4 && /<Align /) {
      my $tid;
      if(/sid="([^\"]*)"/) {$id =$1;}
      if(/tid="([^\"]*)"/) {$tid=$1;}
	  if($id == 0 || $tid == 0) {next;}
      $ALN->{stid}{$id}{id}{$tid} = 1;
      $ALN->{ttid}{$tid}{id}{$id} = 1;
    }
   if($type == 7 && /<Seg /) {
      my ($s,$o,$c);
      if(/segId="([^\"]+)"/) {$s =$1;}
      if(/open="([^\"]+)"/) {$o =$1;}
      if(/close="([^\"]*+)"/) {$c=$1;}
	  # open and close 
	  if(defined($s) && ($c > $o + 1)) {
		  $SG->{$s}{openHash}{$o - $SessionStart} = 1;
		  $SG->{$s}{closeHash}{$c - $SessionStart} = 1;
	  }
    }
    if($type == 10 && /<segment /) {
      my ($s,$o);
      if(/id="([^\"]*)"/) {$s = $1;}
      if(/>([^<]*)/) {$o = $1;}
      $SG->{$s}{MTL} = length($o);
    }
    if($type == 8 && /<Salign /) {
      my ($s,$t);
      if(/src="([^\"]*)"/) {$s = $1;}
	  else {$s = -1}
      if(/tgt="([^\"]*)"/) {$t = $1;}
	  else {$t = -1}
	  if($t =~ /^[0-9]+$/ && $s =~ /^[0-9]+$/) { 
        $ALN->{sseg}{$s}{tsegHash}{$t} = 1;
        $ALN->{tseg}{$t}{ssegHash}{$s} = 1;
        $SG->{$s}{tsegHash}{$t} = 1;
        $SG->{$s}{ssegHash}{$s} = 1;	
	  }
	  else {print STDERR "$fn Salign not numeric: $_";}
    }
    if($type == 11) {
      if(/time="([0-9][0-9]*)"/) {$time = $1-$SessionStart;}
      $EXT->{$time}{str} = $_;
    }
	
    if(/<\/Segment>/)      {$type = 0; }
    if(/<\/SourceToken>/)  {$type = 0; }
    if(/<\/Fixations>/)    {$type = 0; }
    if(/<\/Modifications>/){$type = 0; }
    if(/<\/Salignment/)    {$type = 0; }
    if(/<\/Alignment/)    {$type = 0; }
    if(/<\/FinalToken/)   {$type = 0; }
    if(/<\/sourceText/)   {$type = 0; }
    if(/<\/initialTargetText/) {$type = 0; }
    if(/<\/External/i) {$type = 0; }
    if(/<\/ModificationFinal/){$type = 0; }
    if(/<\/ModificationSource/){$type = 0; }

  }
  close(FILE);
  if($SessionRun ==1) {	$SessionDuration = $time-$SessionPause;}
  if($DraftingEnd == 0) {$DraftingEnd = $lastMod;} 
#print STDERR "end: $SessionRun dur:$SessionDuration time:$time start:$SessionStart pause:$SessionPause\n";

  return $n;
}

sub DefaultValues {
	my ($U) = @_;
	
	foreach my $u (keys %{$U}) {
## ST
		if(!defined($U->{$u}{Prob1})) {$U->{$u}{Prob1} = 0}
		if(!defined($U->{$u}{Prob2})) {$U->{$u}{Prob2} = 0}
## AU
		if(!defined($U->{$u}{Scatter})) {$U->{$u}{Scatter} = 0}
		if(!defined($U->{$u}{TTseg})) {$U->{$u}{TTseg} = '---'}
		if(!defined($U->{$u}{Edit})) {$U->{$u}{Edit} = '---'}
		if(!defined($U->{$u}{DurR})) {$U->{$u}{DurR} = 0}
		if(!defined($U->{$u}{FixSdist})) {$U->{$u}{FixSdist} = 0}
		if(!defined($U->{$u}{FixTdist})) {$U->{$u}{FixTdist} = 0}
		if(!defined($U->{$u}{FixSmean})) {$U->{$u}{FixSmean} = 0}
		if(!defined($U->{$u}{FixTmean})) {$U->{$u}{FixTmean} = 0}
		if(!defined($U->{$u}{FixSstd})) {$U->{$u}{FixSstd} = 0}
		if(!defined($U->{$u}{FixTstd})) {$U->{$u}{FixTstd} = 0}
		if(!defined($U->{$u}{GazePath})) {$U->{$u}{GazePath} = '---';}
		
## AG
		if(!defined($U->{$u}{STseg})) {$U->{$u}{STseg} = '---'}
		if(!defined($U->{$u}{PosS})) {$U->{$u}{PosS} = '---'}
		if(!defined($U->{$u}{PosT})) {$U->{$u}{PosT} = '---'}

## KD
		if(!defined($U->{$u}{DistCur})) {$U->{$u}{DistCur} = 0}
		if(!defined($U->{$u}{DistTTid})) {$U->{$u}{DistTTid} = 0}

## ST and TT 
		if(!defined($U->{$u}{EditR})) {$U->{$u}{EditR} = '---'}
		if(!defined($U->{$u}{Runit})) {$U->{$u}{Runit} = 0}
		if(!defined($U->{$u}{TimeR})) {$U->{$u}{TimeR} = 0}
		if(!defined($U->{$u}{DurR})) {$U->{$u}{DurR} = 0}
		if(!defined($U->{$u}{Pause1TrtS})) {$U->{$u}{Pause1TrtS} = 0}
		if(!defined($U->{$u}{Pause1TrtT})) {$U->{$u}{Pause1TrtT} = 0}
		
		if(!defined($U->{$u}{Ins})) {$U->{$u}{Ins} = 0}
		if(!defined($U->{$u}{Del})) {$U->{$u}{Del} = 0}
		if(!defined($U->{$u}{Pause})) {$U->{$u}{Pause} = 0}
		if(!defined($U->{$u}{Munit})) {$U->{$u}{Munit} = 0}
		if(!defined($U->{$u}{Pause2TrtS})) {$U->{$u}{Pause2TrtS} = 0}
		if(!defined($U->{$u}{Pause2TrtT})) {$U->{$u}{Pause2TrtT} = 0}
		if(!defined($U->{$u}{InEff})) {$U->{$u}{InEff} = 0}

		if(!defined($U->{$u}{SGx})) {$U->{$u}{SGx} = 0}
		if(!defined($U->{$u}{PUnbr})) {$U->{$u}{PUnbr} = 0}
		if(!defined($U->{$u}{PUdur})) {$U->{$u}{PUdur} = 0}
		if(!defined($U->{$u}{PUpause})) {$U->{$u}{PUpause} = 0}
		if(!defined($U->{$u}{PUsid})) {$U->{$u}{PUsid} = 0}
		if(!defined($U->{$u}{PUtid})) {$U->{$u}{PUtid} = 0}
		if(!defined($U->{$u}{PUslen})) {$U->{$u}{PUslen} = 0}
		if(!defined($U->{$u}{PUtlen})) {$U->{$u}{PUtlen} = 0}

## PU
		if(!defined($U->{$u}{SGroup})) {$U->{$u}{SGroup} = '---'}
		if(!defined($U->{$u}{TGroup})) {$U->{$u}{TGroup} = '---'}
		if(!defined($U->{$u}{SGnbr})) {$U->{$u}{SGnbr} = 0}
		if(!defined($U->{$u}{TGnbr})) {$U->{$u}{TGnbr} = 0}
		if(!defined($U->{$u}{SGid})) {$U->{$u}{SGid} = '---'}
		if(!defined($U->{$u}{TGid})) {$U->{$u}{TGid} = '---'}
		
		if(!defined($U->{$u}{Edit1})) {$U->{$u}{Edit1} = '---'}
		if(!defined($U->{$u}{Time1})) {$U->{$u}{Time1} = 0}
		if(!defined($U->{$u}{Dur1})) {$U->{$u}{Dur1} = 0}
		if(!defined($U->{$u}{Pause1})) {$U->{$u}{Pause1} = 0}
		if(!defined($U->{$u}{ParFixS1})) {$U->{$u}{ParFixS1} = 0}
		if(!defined($U->{$u}{ParTrtS1})) {$U->{$u}{ParTrtS1} = 0}
		if(!defined($U->{$u}{ParFixT1})) {$U->{$u}{ParFixT1} = 0}
		if(!defined($U->{$u}{ParTrtT1})) {$U->{$u}{ParTrtT1} = 0}

		if(!defined($U->{$u}{Edit2})) {$U->{$u}{Edit2} = '---'}
		if(!defined($U->{$u}{Time2})) {$U->{$u}{Time2} = 0}
		if(!defined($U->{$u}{Dur2})) {$U->{$u}{Dur2} = 0}
		if(!defined($U->{$u}{Pause2})) {$U->{$u}{Pause2} = 0}
		if(!defined($U->{$u}{ParFixS2})) {$U->{$u}{ParFixS2} = 0}
		if(!defined($U->{$u}{ParTrtS2})) {$U->{$u}{ParTrtS2} = 0}
		if(!defined($U->{$u}{ParFixT2})) {$U->{$u}{ParFixT2} = 0}
		if(!defined($U->{$u}{ParTrtT2})) {$U->{$u}{ParTrtT2} = 0}
		
		if(!defined($U->{$u}{ParFixS})) {$U->{$u}{ParFixS} = 0}
		if(!defined($U->{$u}{ParTrtS})) {$U->{$u}{ParTrtS} = 0}
		if(!defined($U->{$u}{ParFixT})) {$U->{$u}{ParFixT} = 0}
		if(!defined($U->{$u}{ParTrtT})) {$U->{$u}{ParTrtT} = 0}
		
#SG
		if(!defined($U->{$u}{TokS})) {$U->{$u}{TokS} = 0;}
		if(!defined($U->{$u}{LenS})) {$U->{$u}{LenS} = 0;}
		if(!defined($U->{$u}{TokT})) {$U->{$u}{TokT} = 0;}
		if(!defined($U->{$u}{LenT})) {$U->{$u}{LenT} = 0;}
		if(!defined($U->{$u}{String})) {$U->{$u}{String} = '---';}

		if(!defined($U->{$u}{FixS})) {$U->{$u}{FixS} = 0;}
		if(!defined($U->{$u}{TrtS})) {$U->{$u}{TrtS} = 0;}
		if(!defined($U->{$u}{FixT})) {$U->{$u}{FixT} = 0;}
		if(!defined($U->{$u}{TrtT})) {$U->{$u}{TrtT} = 0;}

		if(!defined($U->{$u}{FDur})) {$U->{$u}{FDur} = 0;}
		if(!defined($U->{$u}{Dur})) {$U->{$u}{Dur} = 0;}
		if(!defined($U->{$u}{Yawat})) {$U->{$u}{Yawat} = '---';}
		if(!defined($U->{$u}{LenMT})) {$U->{$u}{LenMT} = 0;}
	}
}

#################################################
# FIXATION UNITS (FU)
#################################################

sub FixationUnits {

  my @L = (sort {$a<=>$b} keys %{$FIX});
  my $win = -1;
  my $start = 0; #unit starting time
  my $min = 0;
  my $max = 0;
  my $fix = 0;
  my $turn = 0;
  my $path = '';
  my $time = 0;

  for(my $i=0; $i < scalar(@L); $i++) {
    $time = $L[$i];
    if($win == -1) {$win=$FIX->{$time}{Win}; $start = $time; next;}
    if($win == 0 && $FIX->{$time}{Win} == 0) {next;}
    if($win == 0) {$start=$time; $win=$FIX->{$time}{Win}; next;}
	
	my $xtime =  $L[$i-1] + $FIX->{$L[$i-1]}{Dur};
    if($win != $FIX->{$time}{Win} || $time - $xtime > $FUFixGap) {
	  if($xtime > $time) { 
	    if($Verbose) { printf STDERR "FixationUnits: overlapping fixations win:$FIX->{$time}{Win}:$start --- $xtime win:$win:$time --> %d\n", $xtime - $time;}
        $xtime = $time;
	  }
      $FU->{$start}{Time} = $start;
      $FU->{$start}{Dur} = $xtime - $start;
      $FU->{$start}{FixKeyDist } = FixKeyDist($start, $xtime);
      $FU->{$start}{Span} = $max - $min;
      $FU->{$start}{Turn} = $turn;
      $FU->{$start}{Fix} = $fix;
      $FU->{$start}{Win} = $win;
	  $FU->{$start}{Seg} = $FIX->{$start}{Seg} ;
      $FU->{$start}{GazePath} = $path;
      $win = $FIX->{$time}{Win};

	  $start = $time;
	  $max = $min = $turn = $fix = 0;
	  $path = '';
	}
    $fix ++;
    if($win == 1) {
		if($path ne '') {$path .= "+";}
		$path .= "S:$FIX->{$time}{STid}";
		if($FIX->{$time}{STid}  < $min || $min == 0) { $min = $FIX->{$time}{STid} ;}
		if($FIX->{$time}{STid}  > $max || $max == 0) { $max = $FIX->{$time}{STid} ;}
        if($fix > 2 &&  
		  (($FIX->{$time}{STid}  > $FIX->{$L[$i-1]}{STid}  && $FIX->{$L[$i-1]}{STid}  < $FIX->{$L[$i-2]}{STid} ) ||
           ($FIX->{$time}{STid}  < $FIX->{$L[$i-1]}{STid}  && $FIX->{$L[$i-1]}{STid}  > $FIX->{$L[$i-2]}{STid} )))	{
			$turn ++;
		}
	}
    if($win == 2) {
		if($path ne '') {$path .= "+";}
		$path .= "T:$FIX->{$time}{TTid}"; 
		if($FIX->{$time}{TTid}  < $min || $min == 0) { $min = $FIX->{$time}{TTid} ;}
		if($FIX->{$time}{TTid}  > $max || $max == 0) { $max = $FIX->{$time}{TTid} ;}
        if($fix > 2 &&  
		  (($FIX->{$time}{TTid}  > $FIX->{$L[$i-1]}{TTid}  && $FIX->{$L[$i-1]}{TTid}  < $FIX->{$L[$i-2]}{TTid} ) ||
           ($FIX->{$time}{TTid}  < $FIX->{$L[$i-1]}{TTid}  && $FIX->{$L[$i-1]}{TTid}  > $FIX->{$L[$i-2]}{TTid} )))	{
			$turn ++;
		}	 
	}
} }


## Unit Starttime, Endtime 
sub FixKeyDist {
  my ($s, $e) = @_;
  my $last = 0;
  
#print STDERR "FixKeyDist $t $ut\n";
  foreach my $k (sort {$a<=>$b} keys %{$KEY}) {
#print STDERR "FixKeyDist $t $ut $k\n";
    if($k >= $s && $k <= $e) {return 0;}
	if($k > $e) {return $k-$e;}
	$last = $k;
  }
  if($last < $s) {return $last - $s};
  return $last - $e;
}

#################################################
# Keystrokes (KD)
#################################################
sub KeystrokesData {

	# merge ssegHash 
	my $lastSeg = 1;
	foreach my $t (keys %{$KEY}) {
  	    my $tseg = $KEY->{$t}{TTseg};
if(!defined($ALN->{tseg}{$tseg}{ssegHash})) {
$KEY->{$t}{ssegHash} = $lastSeg;
print STDERR "Warning UNDEFINED Keystroke time $t Tseg: $tseg assigned to Sseg\n";
d($lastSeg);
next;
}
 
		$lastSeg = $KEY->{$t}{ssegHash} = $ALN->{tseg}{$tseg}{ssegHash};
	}
	
	### word/sentence boundary flags
	my $t0 = 0;
	my $wstart = 1;
	my $sstart = 2;
	my $noword = 4;

	foreach my $t (sort  {$a <=> $b} keys %{$KEY}) {
		$KEY->{$t}{Draft} = $t > $DraftingEnd ? 1 : 0;
		
		# substitute backslash \  (bug in a Trados file)
		if($KEY->{$t}{Char} =~ /^\\*$/) { $KEY->{$t}{Char} =~ s/\\/\\\\/g;}
		
		if(!defined($TGT->{$KEY->{$t}{TTid}})) {
			$WarningsCount->{"Undefined KEY-TTid: $KEY->{$t}{TTid}"} ++;
			$KEY->{$t}{TTid} = 0;
			next;
		}
		foreach my $id (split(/\+/, $KEY->{$t}{SGid})) {
			if($id == 0) {next;}
			if(!defined($SRC->{$id})) {
				$KEY->{$t}{SGid} = $KEY->{$t}{SGid} =~ s/[+]$id//g;
				if($KEY->{$t}{SGid} eq '') {$KEY->{$t}{SGid} = 0;}
				next;
		}	}
		
		
		if($t0 > 0) {
			$KEY->{$t0}{DistCur} = abs($KEY->{$t}{Cur}  - $KEY->{$t0}{Cur} );
			$KEY->{$t0}{DistTTid} = abs($KEY->{$t}{TTid}  - $KEY->{$t0}{TTid} );
			  
			if ($KEY->{$t}{TTid}  != $KEY->{$t0}{TTid} ) { $wstart = 1}
		#	if ($KEY->{$t}{Char} =~ /\w/ && $KEY->{$t0}{Char} =~ /\W/) {$wstart = 1}
			if ($KEY->{$t}{TTseg}  != $KEY->{$t0}{TTseg} ) { $sstart = 2}
			if ($KEY->{$t}{Char} =~ /\W/) {$noword = 4}

		}
		
		# border of keystroke: WordStart SegmentStart NoChar
		$KEY->{$t}{Border} = $wstart + $sstart + $noword;
		$wstart = $sstart = $noword = 0;
		
		# Pause preceding keystroke
		$KEY->{$t}{Pause} = $t - $t0;
		$t0 = $t;
	}
}

sub AddPUtoST {
	foreach my $start (sort  {$a <=> $b} keys %{$PU}) {
		if($PU->{$start}{SGid}  eq '---') {next;}
		
		my @TID = split(/\+/, $PU->{$start}{TGid} );
		my @SID = split(/\+/, $PU->{$start}{SGid} );
		foreach my $i (@SID) {
			$i = int($i);
			if(!defined($SRC->{$i})) {
				if($i > 0) {print STDERR "Undefined PU-SGid: $i\t $PU->{$start}{SGid} \n";}
				next;
			}
			if(defined($SRC->{$i}{PUnbr})) {
				$SRC->{$i}{PUnbr} += 1;
				next;
			}
			$SRC->{$i}{PUnbr} = 1;
			$SRC->{$i}{PUdur} = $PU->{$start}{Dur};
			$SRC->{$i}{PUpause} = $PU->{$start}{Pause};
			$SRC->{$i}{PUsid} = $PU->{$start}{SGid} ;
			$SRC->{$i}{PUtid} = $PU->{$start}{TGid} ;
			$SRC->{$i}{PUtlen} = scalar(@TID);
			$SRC->{$i}{PUslen} = scalar(@SID);
}	}	}

#################################################
# Sentence Segments (SG)
#################################################

sub SegmentSummary {

	my $H = {};

	# reverse ordering of keystrokes
	my $t0 = 0;
	foreach my $t (sort  {$a <=> $b} keys %{$KEY}) {
		# ignore automatically inserted keystrokes
		if($KEY->{$t}{Type} eq 'Ains' ||  $KEY->{$t}{Type} eq 'Adel') { next;}
		
		# check whether TTseg exists
		if(!defined($KEY->{$t}{TTseg} )) {
			print STDERR "Warning: time $t undef seg\n"; 
			next;
		}
		if(!defined($H->{$KEY->{$t}{TTseg}}{first})) {$H->{$KEY->{$t}{TTseg}}{first} = $t}
		elsif ($t < $H->{$KEY->{$t}{TTseg}}{first}) {$H->{$KEY->{$t}{TTseg}}{first} = $t}
		
		if(!defined($H->{$KEY->{$t}{TTseg}}{last})) {$H->{$KEY->{$t}{TTseg}}{last} = $t}
		elsif ($t > $H->{$KEY->{$t}{TTseg}}{last}) {$H->{$KEY->{$t}{TTseg}}{last} = $t}
		
		$H->{$KEY->{$t}{TTseg}}{time}{$t} = 1;
		
		# time of pervious keystroke
		$KEY->{$t}{prev} = $t0;
		
		# first keystroke in new segment
		$KEY->{$t}{first} = 0;
		if($t0 == 0) {$KEY->{$t}{first} = 1;}
		elsif($KEY->{$t}{TTseg} != $KEY->{$t0}{TTseg})  {$KEY->{$t}{first} = 1;}
		
		$t0 = $t;
		
#print STDERR "KKK: $t tseg:$KEY->{$t}{TTseg} first:$H->{$KEY->{$t}{TTseg}}{first} last:$H->{$KEY->{$t}{TTseg}}{last}\n";
	}
	
	# merge ssegHash 
	foreach my $sseg (keys %{$SG}) {
		foreach my $tseg (keys %{$SG->{$sseg}{tsegHash}}) {
		# join two hashes
			$SG->{$sseg}{ssegHash} = {%{$ALN->{tseg}{$tseg}{ssegHash}}, %{$SG->{$sseg}{ssegHash}}};
		}
	}
	
	## Loop over segments
#	d(keys %{$SG});
	foreach my $sseg (sort  {$a <=> $b} keys %{$SG}) {
		my $t0 = 0;
		my $dur = 0;
		my $LastId = -1;

		initializeSegment($sseg);
		my $U = {};
		$U->{Type} = 7;

		## loop over target segments
		foreach my $tseg (sort  {$a <=> $b} keys %{$SG->{$sseg}{tsegHash}}) {

## Scanpath features
#			next;
			## loop over keystroks in targt segments
			foreach my $t (sort  {$a <=> $b} keys  %{$H->{$tseg}{time}}) {

				$t0 = $KEY->{$t}{prev};
#printf STDERR "Segment2: seg:$sseg tseg:$tseg time:$t delay:%d, first:$KEY->{$t}{first}\n", $t-$dur-$t0;
				SegDelay($sseg, $t-$dur-$t0, $KEY->{$t}{first}); 
				
				
			## Chinese keystroks have a duration  
				$dur = $KEY->{$t}{Dur};
			
			# Scattered typing	
				foreach my $i (split(/\+/, $KEY->{$t}{TTid} )) {
					if($LastId != -1) {$SG->{$sseg}{scat} += abs($i - $LastId);}
					$LastId = $i;
					$SG->{$sseg}{Keys} += 1;
				} 

			# number of insertions and deletions
				if($KEY->{$t}{Type} =~ /ins/) {
					$SG->{$sseg}{Ins} += $KEY->{$t}{Strokes};
				}
				elsif($KEY->{$t}{Type} =~ /del/) {
					$SG->{$sseg}{Del} += $KEY->{$t}{Strokes};
				}
				else {
					print STDERR "SegmentSummary: Keystroke without Type\n"; d($KEY->{$t});
				}
			}
		}	
		
 
   
	## number/length of source and target fixations
		foreach my $t (keys %{$FIX}) {
			my $s = $FIX->{$t}{Seg} ;

			if($FIX->{$t}{Win} == 2 && defined($SG->{$sseg}{tsegHash}{$s})) { 
				$SG->{$sseg}{TrtT} += $FIX->{$t}{Dur};
				$SG->{$sseg}{FixT} ++;
			}
			if($FIX->{$t}{Win} == 1 && defined($SG->{$sseg}{ssegHash}{$s})) { 
				$SG->{$sseg}{TrtS} += $FIX->{$t}{Dur};
				$SG->{$sseg}{FixS} ++;
			}
		}

	## number/length of source sentence
		foreach my $t (sort  {$a <=> $b} keys %{$SRC}) {
			my $s = $SRC->{$t}{STseg} ;
			if(defined($SG->{$sseg}{ssegHash}{$s})) { 
				$SG->{$sseg}{TokS} ++;
				
				#yawat
				if(defined($SRC->{$t}{Yawat}) && $SRC->{$t}{Yawat} ne '---') {
				  if(defined($SG->{$sseg}{Yawat})) { $SG->{$sseg}{Yawat} .= "+S:$SRC->{$t}{Yawat}";}
				  else { $SG->{$sseg}{Yawat} = "S:$SRC->{$t}{Yawat}";}
				}
				if(defined($SRC->{$t}{SToken})) {$SG->{$sseg}{LenS} += length($SRC->{$t}{SToken});}
				if(defined($SRC->{$t}{space})) {$SG->{$sseg}{LenS} += length($SRC->{$t}{space})}
			}
		}

## number/length of target sentence
		foreach my $t (sort  {$a <=> $b} keys %{$TGT}) {
			my $s = $TGT->{$t}{TTseg} ;
			if(defined($s) && defined($SG->{$sseg}{tsegHash}{$s})) { 
				$SG->{$sseg}{TokT} ++;
				
				if(defined($TGT->{$t}{Yawat}) && $TGT->{$t}{Yawat} ne '---') {
					if(defined($SG->{$sseg}{Yawat})) { $SG->{$sseg}{Yawat} .= "+T:$TGT->{$t}{Yawat}";}
					else {$SG->{$sseg}{Yawat} = "T:$TGT->{$t}{Yawat}";}
				}
				
				if(defined($TGT->{$t}{TToken})) {
					$SG->{$sseg}{LenT} += length($TGT->{$t}{TToken});
					if(defined($SG->{$sseg}{String})) { $SG->{$sseg}{String} .= '_';}         
					$SG->{$sseg}{String} .= $TGT->{$t}{TToken};         
				}
				if(defined($TGT->{$t}{space})) {$SG->{$sseg}{LenT} += length($TGT->{$t}{space})}
			  }
		}
		
	# scatter
		if(defined($SG->{$sseg}{scat})) {

			$SG->{$sseg}{Scatter} = 
			sprintf("%4.2f", ($SG->{$sseg}{scat}-$SG->{$sseg}{TokT}+1) /$SG->{$sseg}{Keys});
		}
		else {$SG->{$sseg}{Scatter} = 0;}
		
		# TTseg and STseg
		my $text = '';
		foreach my $s (sort  {$a <=> $b} keys %{$SG->{$sseg}{ssegHash}}) { 
			if(length($text) > 0) {$text .= "+"; }
			$text .= "$s";
		}
		if(length($text) > 0) {$SG->{$sseg}{STseg} = $text;}
		else {$SG->{$sseg}{STseg} = '---';}

		$text = '';
		foreach my $s (sort  {$a <=> $b} keys %{$SG->{$sseg}{tsegHash}}) {
			if(length($text) > 0) {$text .= "+";}
			$text .= "$s";
		}
		if(length($text) > 0) {$SG->{$sseg}{TTseg} = $text;}
		else {$SG->{$sseg}{TTseg} = '---';}

	}
}

sub initializeSegment {
	my ($seg) = @_;
	
	if(!defined($SG->{$seg}{PreGap})) {$SG->{$seg}{PreGap} = 0;}
	if(!defined($SG->{$seg}{Nedit})) {$SG->{$seg}{Nedit} = 0;}
	if(!defined($SG->{$seg}{TG300})) {$SG->{$seg}{TG300} = 0;}
	if(!defined($SG->{$seg}{TB300})) {$SG->{$seg}{TB300} = 0;}
	if(!defined($SG->{$seg}{TD300})) {$SG->{$seg}{TD300} = 0;}

	if(!defined($SG->{$seg}{TG500})) {$SG->{$seg}{TG500} = 0;}
	if(!defined($SG->{$seg}{TB500})) {$SG->{$seg}{TB500} = 0;}
	if(!defined($SG->{$seg}{TD500})) {$SG->{$seg}{TD500} = 0;}

	if(!defined($SG->{$seg}{TG1000})) {$SG->{$seg}{TG1000} = 0;}
	if(!defined($SG->{$seg}{TB1000})) {$SG->{$seg}{TB1000} = 0;}
	if(!defined($SG->{$seg}{TD1000})) {$SG->{$seg}{TD1000} = 0;}

	if(!defined($SG->{$seg}{TG2000})) {$SG->{$seg}{TG2000} = 0;}
	if(!defined($SG->{$seg}{TB2000})) {$SG->{$seg}{TB2000} = 0;}
	if(!defined($SG->{$seg}{TD2000})) {$SG->{$seg}{TD2000} = 0;}
	
	if(!defined($SG->{$seg}{TG5000})) {$SG->{$seg}{TG5000} = 0;}
	if(!defined($SG->{$seg}{TB5000})) {$SG->{$seg}{TB5000} = 0;}
	if(!defined($SG->{$seg}{TD5000})) {$SG->{$seg}{TD5000} = 0;}
	
	if(!defined($SG->{$seg}{FDur})) {$SG->{$seg}{FDur} = 0;}
	if(!defined($SG->{$seg}{Dur})) {$SG->{$seg}{Dur} = 0;}
	
}

## Keystroke pauses and Segments D500: 500, Pdur: 1000, Ldur:2000, Kdur:5000 Fdur:200000 

sub SegDelay {
	my ($seg, $delay, $first) = @_;
  
#printf STDERR "\tSegDel: delay:$delay, seg:$seg, first:$first\n";
	if($delay < 0) {
		$WarningsCount->{"SegDel $seg"} +=  $delay;
		return;
	}

    if($first) {
#printf STDERR "\tSegDel: delay:$delay, seg:$seg, first:$first\n";
	  $SG->{$seg}{PreGap} += $delay;
      $SG->{$seg}{Nedit} ++;
	}
	else {
      if($delay > 300) {
        $SG->{$seg}{TG300} += $delay;            
        $SG->{$seg}{TB300} ++;
      }
      else {$SG->{$seg}{TD300} += $delay;}
      if($delay > 500) {
        $SG->{$seg}{TG500} += $delay;            
        $SG->{$seg}{TB500} ++;
      }
      else {$SG->{$seg}{TD500} += $delay;}
      if($delay > 1000) {
        $SG->{$seg}{TG1000} += $delay;
        $SG->{$seg}{TB1000} ++;
      }
	  else {$SG->{$seg}{TD1000} += $delay;}
      if($delay > 2000) {
        $SG->{$seg}{TG2000} += $delay;
        $SG->{$seg}{TB2000} ++;
	  }
      else {$SG->{$seg}{TD2000} += $delay;}
      if($delay > 5000) {
        $SG->{$seg}{TG5000} += $delay;
        $SG->{$seg}{TB5000} ++;
	  }
      else {$SG->{$seg}{TD5000} += $delay;}
    }

    if($delay < 200000) {$SG->{$seg}{FDur} += $delay;}
	$SG->{$seg}{Dur} += $delay;
}

#################################################
# Session Summary (SS)
#################################################

sub SessionSummary {

  $SS->{Dur} = $SessionDuration;
  $SS->{TimeD} = $DraftingStart;
  $SS->{TimeR} = $DraftingEnd;
  $SS->{Break} = $SessionPause;

  foreach my $start (keys %{$PU}) {
    $SS->{TD1000} += $PU->{$start}{Dur};
    $SS->{TB1000} ++;
  }

  
  ## fdur and duration of pause > 200 secs
  $SS->{TD5000} = 0;
  $SS->{FDur} = 0;
  foreach my $seg (keys %{$SG}) {
    if($seg > 0) {$SS->{ALseg} ++;}
    foreach my $tseg (keys %{$SG->{$seg}{tseg}}) {if($tseg > 0) {$SS->{TTseg} ++;}}
    $SS->{TD5000}  += $SG->{$seg}{TD5000};
    $SS->{FDurSeg} += $SG->{$seg}{FDur};
    $SS->{DurSeg}  += $SG->{$seg}{Dur};
  }
  
## number of insertions and deletions
  foreach my $t (keys %{$KEY}) {
    if($KEY->{$t}{Type} =~ /ins/) {
      $SS->{Ins} += $KEY->{$t}{Strokes};
    }
    else {
      $SS->{Del} += $KEY->{$t}{Strokes};
    }
  }

## number/length of source sentence
  foreach my $t (keys %{$SRC}) {
      $SS->{TokS} ++;
      if(defined($SRC->{$t}{SToken})) {$SS->{LenS} += length($SRC->{$t}{SToken});}
      if(defined($SRC->{$t}{space}))  {$SS->{LenS} += length($SRC->{$t}{space})}
  }

## number/length of target sentence
    foreach my $t (keys %{$TGT}) {
      $SS->{TokT} ++;
      if(defined($TGT->{$t}{TToken}))   {$SS->{LenT} += length($TGT->{$t}{TToken});}
      if(defined($TGT->{$t}{space})) {$SS->{LenT} += length($TGT->{$t}{space})}
    }

## Scatter keystrokes
  my $LastId = -1;
  my $scatter = 0;
  foreach my $t (sort  {$a <=> $b} keys %{$KEY}) {
    if(!defined($KEY->{$t}{TTid} )) { next;}
	
	# should not be necessary: TTid is a number
    foreach my $i (split(/\+/, $KEY->{$t}{TTid} )) {
      if($LastId != -1) {$scatter += abs($i - $LastId);}
      $LastId = $i;
  } }
  if($LastId > -1) { 
	$SS->{Scatter} = sprintf("%4.2f", ($scatter - $SS->{TokT} + 1) / scalar(keys %{$KEY}));
  }
  else {$SS->{Scatter} = 0;}

## number/length of source and target fixations
    foreach my $t (keys %{$FIX}) {
      if($FIX->{$t}{Win} == 2) { 
        $SS->{TrtT} +=$FIX->{$t}{Dur};
        $SS->{FixT} ++;
      }
      if($FIX->{$t}{Win} == 1) { 
        $SS->{TrtS} +=$FIX->{$t}{Dur};
        $SS->{FixS} ++;
      }
    }
}


#################################################
# Source Token Units (ST)
#################################################

sub MakeSourceUnits {

  if(!defined($ALN)) { return 0;}

  foreach my $sid (sort  {$a <=> $b} keys %{$SRC}) {
    if(defined($ALN->{stid} {$sid})) {
      my $str = '';
      my $ttid = '';
      foreach my $tid (sort  {$a <=> $b} keys %{$ALN->{stid}{$sid}{id}}) {
        if($tid == 0) {next;}

        if(!defined($SRC->{$sid}{SGnbr})) {
          my $SGroup = '';
		  my $stid = '';
          foreach my $sid2 (sort {$a <=> $b} keys %{$ALN->{ttid}{$tid}{id}}) {
			if(!defined($SRC->{$sid2})) {
				$WarningsCount->{"NoSourceWord $sid2"} ++;
				delete($ALN->{ttid}{$tid}{id}{$sid2});
				next;
			}
			$SRC->{$sid}{SGnbr} ++;
			if($SGroup ne '') {$SGroup .= "_"; $stid .= "+"};
			$SGroup .= $SRC->{$sid2}{SToken};
			$stid .= $sid2;
		  }
          $SRC->{$sid}{SGroup} = $SGroup;
          $SRC->{$sid}{SGid} = $stid;
        }
        $SRC->{$sid}{ttidHash}{$tid} ++;
        $SRC->{$sid}{TGnbr} ++;
        $Tid2Sid->{$tid} = $sid;
        if(length($str) > 0) {$str .= '_'; $ttid .= '+';}
        $str .= $TGT->{$tid}{TToken};
        $ttid .= "$tid";
      }
      $SRC->{$sid}{TGroup} = $str;
      $SRC->{$sid}{TGid} = $ttid;
    }
  }
}

sub SourceTargetID {

  foreach my $sid (keys %{$SRC}) {
    if(!defined($ALN->{stid}{$sid})) {next;}
    foreach my $tid (keys %{$ALN->{stid}{$sid}{id}}) { $SRC->{$sid}{id}{$tid} ++;}
  }

  foreach my $tid (keys %{$TGT}) {
    if(!defined($ALN->{ttid} {$tid})) {next;}
    foreach my $sid (keys %{$ALN->{ttid}{$tid}{id}}) { $TGT->{$tid}{stidHash}{$sid} ++;}
  }
}


# Fatures for AG, SRC, TGT
sub MicroUnitFeatures {
  my ($U, $start, $end, $last, $ins, $del, $len, $str) = @_;

#printf STDERR "MicroUnitFeatures start:$start, end:$end, last: $last, ins:$ins, del:$del, len:$len, str:$str\n";
  if(!defined($U->{Time1}) || $U->{Time1} == 0) {
#printf STDERR "MicroUnitFeatures1 dur:%s pause:%s\n", $end - $start, $start - $last; 
    $U->{Time1} = $start;
    $U->{Dur1} = $end - $start;
    $U->{Pause1} = $start - $last;
    $U->{Edit1} = $str;
	($U->{Pause1TrtS}, $U->{Pause1TrtT}) = PauseFixations($last ,$start);
  }
  elsif(!defined($U->{Time2}) || $U->{Time2} == 0) {
    $U->{Time2} = $start;
    $U->{Dur2} = $end - $start;
    $U->{Pause2} = $start - $last;
    $U->{Edit2} = $str;
	($U->{Pause2TrtS}, $U->{Pause2TrtT}) = PauseFixations($last ,$start);
  }
  
  ## 
  if($start > $DraftingEnd) {
#  print STDERR "DRAFTING \n";
	# add values when TimeR is defined
    if(defined($U->{TimeR})) {
		$U->{DurR} += $end - $start;
		$U->{EditR} .= $str;
	}
	else {
		$U->{TimeR} = $start;
		$U->{DurR} = $end - $start;
		$U->{EditR} = $str;
	}
    $U->{Runit} ++;
  }
  
  ## memorize micro units
  push(@{$U->{start}}, $start);
  push(@{$U->{end}}, $end);
#  push(@{$U->{last}}, $last);
#  push(@{$U->{medit}}, $str);

  $U->{Munit} ++;
  $U->{Dur} += $end - $start;
  $U->{Pause} += $start - $last;
  $U->{Ins} += $ins;
  $U->{Del} += $del;
  $U->{len} += $len;
  $U->{Edit} .= $str;
  my ($w1, $w2) = PauseFixations($last ,$start);
  $U->{Pause2TrtS} = $w1;
  $U->{Pause2TrtT} = $w2;
}

sub PauseFixations {
  my ($p1, $p2) = @_;
  
  my $w1 = 0;
  my $w2 = 0;
  foreach my $f1 (sort  {$a <=> $b} keys %{$FIX}) {
    my $f2 = $f1 + $FIX->{$f1}{Dur};
    if($f1 > $p2) { last;}
    if($f2 < $p1) {next;}
	
	my $t1 = $f1;
	my $t2 = $f2;
    if($f1 < $p1) { $t1 = $p1;}
    if($f2 > $p2) { $t2 = $p2;}
	
    if($FIX->{$f1}{Win} == 1) { $w1 += $t2-$t1;}
    if($FIX->{$f1}{Win} == 2) { $w2 += $t2-$t1;}
#  printf STDERR "P: $p1 - $p2\t f: $f1 - $f2\t %d\n", $t2-$t1;
  }	
  return ($w1, $w2);
}
  

######################################################
##### Alignment Groups (AG)
#######################################################

sub MakeAlignGroups {

  if(!defined($ALN)) { return 0;}

  my $au = 0;
  foreach my $tid (sort  {$a <=> $b} keys %{$ALN->{ttid} }) {
    if(defined($ALN->{ttid} {$tid}{visited})) {next;}
    $ALN->{ttid}{$tid}{visited}=$au;

    foreach my $sid (sort {$a <=> $b} keys %{$ALN->{ttid}{$tid}{id}}) {
      if(!defined($SRC->{$sid})) {
	    $WarningsCount->{"Undefined ALN-STid: $sid"} += 1;
		delete($ALN->{ttid}{$tid}{id}{$sid});
		next;
	  }
      if(defined($SRC->{$sid}{visited})) {next;}
      $SRC->{$sid}{visited} = $au;

	# SGroup
      if(defined($AG->{$au}{SGroup}) && $AG->{$au}{SGroup} ne '') {
		$AG->{$au}{SGroup} .= '_';
	  }
      $AG->{$au}{SGroup} .= $SRC->{$sid}{SToken};
	  
	# SGid
      if(defined($AG->{$au}{SGid}) && $AG->{$au}{SGid} ne '') {
		$AG->{$au}{SGid} .= '+';
	  }
      $AG->{$au}{SGid} .= $sid;
	  
	  #PosS 
      if(defined($SRC->{$sid}{PoS})) {
		if(defined($AG->{$au}{PosS}) && $AG->{$au}{PosS} ne '') {$AG->{$au}{PosS} .= '+';}
		$AG->{$au}{PosS} .= $SRC->{$sid}{PoS};
	  }
      if(!defined($SRC->{$sid}{PoS})) { $AG->{$au}{PosS} = '---';}

      $AG->{$au}{stidHash}{$sid} ++;
	  
      $ALN->{stid}{$sid}{SGnbr} = $AG->{$au}{SGnbr} ++;
      $AG->{$au}{STseg} = $SRC->{$sid}{STseg} ;

      foreach my $tid2 (sort {$a <=> $b} keys %{$ALN->{stid}{$sid}{id}}) {
		if(!defined($TGT->{$tid2})) {
			print STDERR "MakeAlignGroups: sid:$sid tid:$tid2 no tgt token\n";
			next;
		}
        if(defined($TGT->{$tid2}{visited})) {next;}
        $TGT->{$tid2}{visited} = $au;

        if(defined($AG->{$au}{TGroup}) && $AG->{$au}{TGroup} ne '') {
			$AG->{$au}{TGroup} .= '_';
		}
		if(!defined($TGT->{$tid2}{TToken})) {
			print STDERR "TTTT: $tid2 $au\n";
			d($TGT->{$tid2});
		}
		
#        $ALN->{stid}{$sid}{2946} = $AG->{$au}{TGnbr} ++;
        $AG->{$au}{TGroup} .= $TGT->{$tid2}{TToken};
        $AG->{$au}{ttidHash}{$tid2} ++;
		
		# an AG can only be one segment 
        $AG->{$au}{TTseg} = $TGT->{$tid2}{TTseg} ;
      }
	  
	  ## concatenate TID 
	  my $ttid = '';
	  my $pos = '';
	  foreach my $tid (sort {$a <=> $b} keys %{$AG->{$au}{ttidHash}}) {
		if(length($ttid) > 0){$ttid .= '+';}
		$ttid .= $tid;
		
		if(defined($TGT->{$tid}{PoS})) {
			if(length($pos) > 0){$pos .= '+';}
			$pos .= $TGT->{$tid}{PoS};
		}
		
	  }
	  $AG->{$au}{TGnbr} = scalar(keys %{$AG->{$au}{ttidHash}});
	  $AG->{$au}{TGid} = $ttid;
	  $AG->{$au}{PosT} = $pos;
	  
    }
    $au +=100;
  }
  

## unaligned TGT Token
  $au = 0;
  foreach my $tid (sort  {$a <=> $b} keys %{$TGT}) {

    if(defined($TGT->{$tid}{visited})) { $au = $TGT->{$tid}{visited}; }
    else {
      while(defined($AG->{$au})) { $au++;}
  #print STDERR "WARNING: too many AG gaps $au\n"; next;}
      $AG->{$au}{TGroup} = $TGT->{$tid}{TToken};
      $AG->{$au}{SGroup} = "---";
      $AG->{$au}{ttidHash}{$tid} =1;
      $AG->{$au}{stidHash}{-1} = 1;
    }
    $Tid2AG->{$tid} = $au;
  }

  return 1;
}



#################################################
# Alignment Groups  (AG)
#################################################

sub AlignmentGroups {
  my ($U) = @_;

  my ($ins, $del, $len, $start, $end, $last, $u, $last_u);
  $ins=$del=$len=$start=$end=$last=$u=$last_u = 0;
  my $str = '';
  my $type = 'ins';

  foreach my $t (sort  {$a <=> $b} keys %{$KEY}) {
# Skip automatic insertions and deletions
    if($KEY->{$t}{Type} eq 'Ains' ||  $KEY->{$t}{Type} eq 'Adel') { next;}

    my $tid = $KEY->{$t}{TTid} ;

    if($U eq 'au') {$u=$Tid2AG->{$tid};}
    elsif(defined($Tid2Sid->{$tid})) {$u=$Tid2Sid->{$tid};}
    else {$u = undef;}

# printf STDERR "AlignmentGroups Tok:$tid\t$TGT->{$tid}{TToken}\t$u:$AG->{$u}{TGroup}\tkey:$KEY->{$t}{Char}\t$start\n";
# if($u == 400) {printf STDERR "AlignmentGroups $u $AG->{$u}{TGroup} $start\n";}

    if(!defined($u) || !defined($last_u) ||  ($start > 0 && $u != $last_u)) {
      if($type =~ /del/) {$str .= ']';}
      if(defined($last_u)) {

        if($U eq 'au') {MicroUnitFeatures($AG->{$last_u}, $start, $end, $last, $ins, $del, $len, $str);}
        else { MicroUnitFeatures($SRC->{$last_u}, $start, $end, $last, $ins, $del, $len, $str);}
      }

      $ins=0; $del=0; $len=0;
      $last = $end;
      # Chinese Char start before 
      $start = $t - $KEY->{$t}{Dur};
#      $start = $t;
      $str = '';
      $type='ins';
    }

    if($KEY->{$t}{Type} =~ /ins/) {
      if($type !~ /ins/) {$str .= ']';}
      $ins += $KEY->{$t}{Strokes};
    }
    else {
      if($type !~ /del/) {$str .= '[';}
      $del += $KEY->{$t}{Strokes};
    }
    $str .= $KEY->{$t}{Char};
    $len++;

    if($start == 0) { $start = $t; }
      # Chinese Char start before 
#    $end = $t + $KEY->{$t}{Dur};
    $end = $t;
    $last_u = $u;
    $type =$KEY->{$t}{Type};
  }
  if($type =~ /del/) {$str .= ']';}

  if(defined($last_u)) {
    if($U eq 'au') {MicroUnitFeatures($AG->{$last_u}, $start, $end, $last, $ins, $del, $len, $str);}
    else { MicroUnitFeatures($SRC->{$last_u}, $start, $end, $last, $ins, $del, $len, $str);}
  }
  AllTokenUnit();
}

# copy Unit features into all tokens in AG
sub AllTokenUnit {

  foreach my $sid (sort  {$b <=> $a} keys %{$SRC}) {
    # some editing took place
	if(defined($SRC->{$sid}{Munit}) && $SRC->{$sid}{Munit} > 0 && !defined($SRC->{$sid}{tokenUnit}))  {
		my $U=$SRC->{$sid};
		my $SGx = 1;
		for my $su (split(/\+/, $SRC->{$sid}{SGid})) {
			if(defined($SRC->{$su}{tokenUnit})) { next;}
			$SRC->{$su}{tokenUnit}  = 1;
#		$SRC->{$sid}{tokenUnit} = 1;
#		foreach my $tu (keys %{$U->{TGid} }) {
#			foreach my $su (sort {$b <=> $a} keys %{$TGT->{$tu}{SGid} }) {
			#print STDERR "AllTokenUnit:$sid $su\t$SRC->{$sid}{SGid}\n";
					$SRC->{$su}{SGx}  = $SGx ++;
					$SRC->{$su}{Pause2TrtS}  = $U->{Pause2TrtS};
					$SRC->{$su}{Pause2TrtT} = $U->{Pause2TrtT};
#					$SRC->{$su}{medit}  = $U->{medit};
					$SRC->{$su}{Munit} = $U->{Munit};
					$SRC->{$su}{Time1}  = $U->{Time1};
					$SRC->{$su}{Dur1}   = $U->{Dur1};;
					$SRC->{$su}{Pause1} = $U->{Pause1};
					$SRC->{$su}{Edit1} = $U->{Edit1};
					$SRC->{$su}{Time2}  = $U->{Time2};
					$SRC->{$su}{Dur2}   = $U->{Dur2};
					$SRC->{$su}{Pause2} = $U->{Pause2};
					$SRC->{$su}{Edit2} = $U->{Edit2};
					$SRC->{$su}{Dur}    = $U->{Dur};
					$SRC->{$su}{Pause}  = $U->{Pause};
					$SRC->{$su}{Ins}    = $U->{Ins};
					$SRC->{$su}{Del}    = $U->{Del};
					$SRC->{$su}{len}    = $U->{len};
					$SRC->{$su}{Edit}   = $U->{Edit};
					$SRC->{$su}{InEff}   = $U->{InEff};

		}
    }
  }
}

#################################################
# Target Tokens
#################################################


sub MakeTargetUnits {

  if(!defined($ALN)) { return 0;}

  foreach my $tid (sort  {$a <=> $b} keys %{$TGT}) {
    if($tid == 0) {next;}
    if(defined($ALN->{ttid} {$tid})) {
      my $str = '';
      my $stid = '';
      foreach my $sid (sort  {$a <=> $b} keys %{$ALN->{ttid}{$tid}{id}}) {
#        if($sid == 0) {next;}
        if(!defined($SRC->{$sid})) {next;}

        if(!defined($TGT->{$tid}{TGnbr})) {
          my $tgroup = '';
          foreach my $tid2 (sort {$a <=> $b} keys %{$ALN->{stid}{$sid}{id}}) {
			$TGT->{$tid}{TGnbr} ++;
			if($tgroup ne '') {$tgroup .= "_"};
			$tgroup .= $TGT->{$tid2}{TToken};
          }
          $TGT->{$tid}{TGroup} = $tgroup;
        }
        $TGT->{$tid}{stidHash} {$sid} ++;
        $TGT->{$tid}{SGnbr} ++;
        if($str ne '') {$str .= '_'; $stid .= '+';}
        $str .= $SRC->{$sid}{SToken};
        $stid .= "$sid";
      }
      $TGT->{$tid}{SGroup} = $str;
      $TGT->{$tid}{SGid} = $stid;
    }
  }
}


sub TargetTokenUnits {

  my ($ins, $del, $len, $start, $end, $last, $id);
  $ins=$del=$len=$start=$end=$last=$id = 0;
  my $str = '';
  my $type = 'ins';


  foreach my $t (sort  {$a <=> $b} keys %{$KEY}) {
    if($KEY->{$t}{Type} eq 'Ains' ||  $KEY->{$t}{Type} eq 'Adel') { next;}

    if($start > 0 && $KEY->{$t}{TTid}  != $id) {
      if($type =~ /del/) {$str .= ']';}
      MicroUnitFeatures($TGT->{$id}, $start, $end, $last, $ins, $del, $len, $str);

      $ins=0; $del=0; $len=0;
      $last = $end;
# IME
      $start = $t-$KEY->{$t}{Dur};
#      $start = $t;
      $str = '';
      $type='ins';
    }

    if($KEY->{$t}{Type} =~ /ins/) {
      if($type !~ /ins/) {$str .= ']';}
      $ins += $KEY->{$t}{Strokes};
    }
    else {
      if($type !~ /del/) {$str .= '[';}
      $del += $KEY->{$t}{Strokes};
    }
    $str .= $KEY->{$t}{Char};
    $len++;
# IME
    if($start == 0) { $start = $t-$KEY->{$t}{Dur}; }
    $end = $t;
 
#   if($start == 0) { $start = $t; }
#   $end = $t + $KEY->{$t}{Dur};
    $id = $KEY->{$t}{TTid} ;
    $type =$KEY->{$t}{Type};
  }
  if($type =~ /del/) {$str .= ']';}
  MicroUnitFeatures($TGT->{$id}, $start, $end, $last, $ins, $del, $len, $str);
}

#################################################
# Fixation Data
#################################################

sub FixationData {

#  my $E = [sort {$a<=>$b} keys %{$EXT}];
#  my $e = 0;
#  my $ext1 = 0;
#  my $ext2 = 0;
	foreach my $fix (sort {$a<=>$b} keys %{$FIX}) {
		if(!defined($fix)) {
			print STDERR "fix undefined\n";
			next;
		}
		if(!defined($FIX->{$fix}{Dur})) {
			print STDERR "fix $fix undefined\n";
			d($FIX->{$fix});
			next;
		}

	# SGid contains only on (the first) id
		$FIX->{$fix}{SGid} = $FIX->{$fix}{STid};
		$FIX->{$fix}{STid} = (split(/\+/, $FIX->{$fix}{STid}))[0];
		
		my $H = Overlap($fix, $FIX->{$fix}{Dur}, $PU);

		if(defined($H->{0})) { 
		  $FIX->{$fix}{Paral}=sprintf("%d", $H->{0}{d});
		}
		else { 
		  $FIX->{$fix}{Paral} = 0;
		}

		$H = {};
		my $del = 0;
		foreach my $key (sort {$a<=>$b} keys %{$KEY}) {

		   if($key >= $fix && $key <= $fix+$FIX->{$fix}{Dur}) { 
			  $H->{$KEY->{$key}{TTid} } ++;
			  if($KEY->{$key}{Type} =~ /del/ && $del == 0) {$FIX->{$fix}{Edit} .= '['; $del = 1;}
			  elsif($KEY->{$key}{Type} !~ /del/ && $del == 1) {$FIX->{$fix}{Edit} .= ']'; $del = 0;}
			  $FIX->{$fix}{Edit} .= $KEY->{$key}{Char};
		   }
		}
		if($del == 1) {$FIX->{$fix}{Edit} .= ']'}
		if(!defined($FIX->{$fix}{Edit}) || $FIX->{$fix}{Edit}  eq '') {$FIX->{$fix}{Edit} = '---';}

		my $s = '';
		foreach my $key (keys %{$H}) { $s .= "$key+"; }
		if($s ne '') {$FIX->{$fix}{EDid} = $s;}
		else {$FIX->{$fix}{EDid} = "---";}
	}
}

##################################################
#  External Data
##################################################

sub ExternalData {

  my $title = '';
  my $start = -1;
  my $str = '';
  my $ret = '';
  my $del = 0;
  my $nFix = 0;
  my $dFix = 0;
  my $F = [sort {$a<=>$b} keys %{$FIX}];
  my $E = [sort {$a<=>$b} keys %{$EXT}];
  my $f = 0;

  for(my $e = 0; $e<=$#{$E}; $e++) {
    my $t = $E->[$e];
    my $title = '';

    if($EXT->{$t}{str} =~ /<Focus/ && $EXT->{$t}{str} =~ /title="([^"]*)"/i)  {
	  $title = $1;
	  if($title =~ /Window\|Exited/ || $title =~ /Text\|Window\|Entered$/i || $title =~ /Text\|Current Text\|/) { next;}
	  if($title =~ /HTML_title/) {
	    if($ret eq "") {$ret = $title; }
	    else {$ret .= "|||$title";}
		next;
      }
      
      # switch of Focus    
      $EXT->{$t}{Focus} = escape($title);
      $EXT->{$t}{Time} = $t;
#print STDERR "FOCUS\ttime:$t\t$title\n";
	  if($start > -1) {
	    $EXT->{$start}{Edit} = escape($str);
	    $EXT->{$start}{Return} = escape($ret);
	    $EXT->{$start}{Dur} = $t - $start;
		$EXT->{$start}{nFix} = $nFix;
		$EXT->{$start}{DFix} = $dFix;		
#print STDERR "FOCUS\ttime:$t\t$title\n";
#d($EXT->{$start});
      }
      
      $nFix = 0;
	  $dFix = 0;
	  $str = '';
	  $ret = '';
	  $start = $t;
	}
    if($start >= 0) {
# accumilate keystrokes in #str
		if($EXT->{$t}{str} =~ /<IL/ && $EXT->{$t}{str} =~ /value="([^"]*)"/i)  {
			my $value = $1;
			if($value eq "") {$value = " ";}
			if($value =~ /\[delete\]/ || $value =~ /&#x8;/) {
				if($del == 0) { $str .= "[."; $del = 1;}
				else { $str .= ".";}
			}
			else {
				if($del == 1) { $str .= "]";}
				$str .= $value;  
				$del = 0;
			}
		}
		if($f<=$#{$F}) {
#print STDERR "FIX1\tfix:$f\ttime:$F->[$f]\t$t\n";
			while($F->[$f] < $t) { 
#print STDERR "FIX2\tbefore $title\ttime:$t\tfix:$f\tFixTime:$F->[$f]\n";
				$f ++;
			}
			while($F->[$f] >= $t && $e+1 <= $#{$E} && $F->[$f] <= $E->[$e+1]) {
				$nFix ++;
				$dFix += $FIX->{$F->[$f]}{Dur};
				if($title !~ /Translog-II User/i)  {delete($FIX->{$F->[$f]});}
				$f++;
  } }	} 	}
  foreach my $t (sort {$a<=>$b} keys %{$EXT}) {
    # delete keystrokes, entries that do not contain a Focus slot
    if(!defined($EXT->{$t}{Focus})) {
        delete($EXT->{$t});
        next;
    }

    # add information about last /next Keystroke Id, word, segment
	my $k1=0;
    foreach my $k (sort {$a<=>$b} keys %{$KEY}) {
	  if($k < $t) {$k1=$k; next;}
	  $EXT->{$t}{KDidN} = $KEY->{$k}{nbr};
	  $EXT->{$t}{SGidN} = $KEY->{$k}{SGid} ;
	  $EXT->{$t}{TTsegN} = $KEY->{$k}{TTseg} ;
	  if(defined($KEY->{$k1})) {
        $EXT->{$t}{KDidL} = $KEY->{$k1}{nbr};
	    $EXT->{$t}{SGidL} = $KEY->{$k1}{SGid} ;
        $EXT->{$t}{TTsegL} = $KEY->{$k1}{TTseg} ;
	  }
#	  printf STDERR "DUDU $t\t$k\t$k1\n";
#	  d($EXT->{$t});
	  last;
	}
  }
}

##################################################
#  Crossing Reading/writing activity
##################################################

sub CrossFeature {
	my ($T, $aln, $aln1, $dir) = @_;

	if(!defined($ALN)) {return;}

	my $lminTid = 0;	# min tid of last AU
	my $lmaxTid = 0;  # max tid of last AU
	my $maxTid = 0;
	my $tidMax = 0;	# max tid of current AU
	my $tidMin = 0;	# min tid of current AU
	my $lseg = 0;		# last segment number 
	my $SmaxTid = 0; 	# last Tid for next segment

	foreach my $sid (sort {$a<=>$b} keys %{$T}) {

		if(!defined($T->{$sid}{$dir} )) {
			print STDERR "Undefined NEW $aln:$sid seg:$lseg $T->{$sid}{$dir} \n";
		}
		if($T->{$sid}{$dir}  != $lseg) {$SmaxTid = $maxTid;}
		$lseg = $T->{$sid}{$dir} ;
		my $deb = 0;
		$T->{$sid}{Cross} = 0;
		
		if(defined($ALN->{$aln}{$sid})) {
		# part of a mlti-word alignment 
			if(defined($ALN->{$aln}{$sid}{au})) {
				$T->{$sid}{Cross} = $ALN->{$aln}{$sid}{au};
				$tidMax = $ALN->{$aln}{$sid}{tidMax};
				$tidMin = $ALN->{$aln}{$sid}{tidMin};
				if($deb) {
					print STDERR "CrossFeature1: $aln $sid tid:$tidMin - $tidMax cross:$T->{$sid}{Cross}\n";
				}
			}
			else {
				$tidMax = $SmaxTid;
				$tidMin = $SmaxTid + 200;
				foreach my $id (sort {$a<=>$b} keys %{$ALN->{$aln}{$sid}{id}}) {
					if($id > $tidMax) { $tidMax = $id;}
					if($id < $tidMin) { $tidMin= $id;}
					if($deb) {
						print STDERR "\tT $sid id:$id last:$maxTid min:$tidMin max:$tidMax\tlseg/max:$lseg / $lmaxTid\n";
					}
					if($id > $maxTid) {$maxTid = $id;}
				}
				my $cross = $tidMax - $lminTid;
				if (abs($tidMin - $lmaxTid) > abs($cross)) {$cross = $tidMin - $lmaxTid}

				foreach my $tid1 (keys %{$ALN->{$aln}{$sid}{id}}) {
					foreach my $sid1 (keys %{$ALN->{$aln1}{$tid1}{id}}) {
				  # memorize cross value in all words of a multi-word alignment
						$ALN->{$aln}{$sid1}{au} = $cross;
						$ALN->{$aln}{$sid1}{tidMax} = $tidMax;
						$ALN->{$aln}{$sid1}{tidMin} = $tidMin;
				} 	}
				$T->{$sid}{Cross} = $cross;

				if($deb) {
					printf STDERR "T  $aln $sid last:$lminTid-$lmaxTid tid:$tidMin-$tidMax dmin:%d dmax:%d cross:$T->{$sid}{Cross}\n", $tidMin - $lmaxTid, $tidMax - $lminTid;}
			} 
			$lmaxTid = $tidMax;
			$lminTid = $tidMin;
		#print STDERR "CrossFeature: $aln $sid cross:$T->{$sid}{Cross}\n";
		}
		else {$T->{$sid}{Cross} = 0;}
		$lmaxTid = $tidMax;
		$lminTid = $tidMin;
	}
}

sub CrossingAlignmentGroups {

  if(!defined($ALN)) {return;}

  my $lastSid = 0;
  my ($smin, $smax, $tmin, $tmax, $aln);
  
  foreach my $au (sort {$a<=>$b} keys %{$AG}) {
    $smin=$tmin=10000;
    $smax=$tmax=0;
    $aln=1;

    foreach my $tid (keys %{$AG->{$au}{ttidHash} }) {
      if(defined($ALN->{ttid}{$tid})) {
        if($tmax < $tid) { $tmax = $tid;}
        if($tmin > $tid) { $tmin = $tid;}
        foreach my $id (keys %{$ALN->{ttid}{$tid}{id}}) {
          if($smax < $id) { $smax = $id;}
          if($smin > $id) { $smin = $id;}
      } }
      else { $aln=0; }
    }

    if($aln) {$AG->{$au}{Cross} = sprintf("%s", $smax-$lastSid); }
    else {$AG->{$au}{Cross} = sprintf("0"); }

    $lastSid = $smax;

  }
}

##################################################
#  Gazing duration on Token
##################################################

sub GazeOnToken {
  my ($win, $id) = @_;

  my $trt = 0;   # total reading time
  my $fpd = 0;   # first pass duration
  my $time = 0;  # first fixation time
  my $dtime = 0; # first fixation during drafting time
  my $ffdur = 0; # first fixation duration 
  my $reg = 0;   # outgoing regression 
  my $rp = 0;    # regression path flag
  my $rpd = 0;   # regression path duration
  my $number = 0;

  my $ids = 'STid';
  if($win == 2) {$ids = 'TTid';}
  foreach my $fix (sort {$a<=>$b} keys %{$FIX}) {

    if($FIX->{$fix}{Win} == $win && $FIX->{$fix}{$ids} == $id) {
      if($FIX->{$fix}{Dur} == 0) {printf STDERR "GazeOnToken no duration t:$fix win:$win\t$ids\n";}
      else {
	    $trt += $FIX->{$fix}{Dur}; 
        if($number == 0) { $ffdur = $trt; $time = $fix;}
#if($fix >= $DraftingStart - 1000 && $dtime == 0) { printf STDERR "DT: id:$id\tfix:$fix\tfftime:$time\tdiff:%4.4d\t draft:$DraftingStart\n", $fix - $time;}	
        if($fix >= $DraftingStart - 1000 && $dtime == 0) { $dtime = $fix;}	
	    if($rp == 0) {$rpd += $FIX->{$fix}{Dur}; }
		$number++;
	  }
    }
    elsif($number > 0) {
	  if($fpd == 0) {
        $rpd = $fpd = $trt;  
	    if($FIX->{$fix}{Win} == $win && $FIX->{$fix}{$ids} < $id) { $reg = 1;}
	  }
      if($FIX->{$fix}{Win} != $win || $FIX->{$fix}{$ids} > $id) { $rp = 1;}
	  elsif ($rp == 0) {$rpd += $FIX->{$fix}{Dur}; }
#printf STDERR "GazeOnToken 2 $time\ttrt:$trt\tfpd:$fpd\tf:$ffdur\tn:$number rpd:$rpd win:$win\t$id\n";
    }
  }
  if($fpd == 0) { $fpd = $trt;}
#  printf STDERR "GazeOnToken 2 $time\ttrt:$trt\tfpd:$fpd\tf:$ffdur\tn:$number win:$win\t$id\n";
  return ($time, $dtime, $ffdur, $fpd, $trt, $number, $rpd, $reg);
}

 
sub GazeTimeOnToken {

  my $time = 0;  # first fixation time
  my $dtime = 0; # first fixation during drafting time
  my $ffdur = 0; # first fixation duration
  my $trt = 0;
  my $fpd = 0; 
  my $rpd = 0; 
  my $regr = 0; 
  my $number = 0;
  
#printf STDERR "GazeTimeOnToken Source1:\n";
  foreach my $sid (keys %{$SRC}) {
    ($time, $dtime, $ffdur, $fpd, $trt, $number, $rpd, $regr) = GazeOnToken(1, $sid);
    $SRC->{$sid}{FPDurS} = $fpd;
    $SRC->{$sid}{TrtS} = $trt;
    $SRC->{$sid}{FixS} = $number;
    $SRC->{$sid}{FFDTime} = $dtime;
    $SRC->{$sid}{FFTime} = $time;
    $SRC->{$sid}{FFDur} = $ffdur;
    $SRC->{$sid}{RPDur} = $rpd;
    $SRC->{$sid}{Regr} = $regr;

    $trt = 0;
    $fpd = 0;
    $number = 0;
    foreach my $tid (keys %{$SRC->{$sid}{ttidHash} }) {
      my ($t, $e, $d, $f, $r, $n, $p, $g) = GazeOnToken(2, $tid);
      $fpd += $f;
      $trt += $r;
      $number += $n;
    }
    $SRC->{$sid}{FPDurT} = $fpd;
    $SRC->{$sid}{TrtT} = $trt;
    $SRC->{$sid}{FixT} = $number;
  }

#printf STDERR "GazeTimeOnToken Target:\n";
  foreach my $tid (keys %{$TGT}) {
    ($time, $dtime, $ffdur, $fpd, $trt, $number, $rpd, $regr) = GazeOnToken(2, $tid);
    $TGT->{$tid}{FPDurT} = $fpd;
    $TGT->{$tid}{TrtT} = $trt;
    $TGT->{$tid}{FixT} = $number;
    $TGT->{$tid}{FFDTime} = $dtime;
    $TGT->{$tid}{FFTime} = $time;
    $TGT->{$tid}{FFDur} = $ffdur;
    $TGT->{$tid}{RPDur} = $rpd;
    $TGT->{$tid}{Regr} = $regr;

    $trt = 0;
    $fpd = 0;
    $number = 0;
    foreach my $sid (keys %{$TGT->{$tid}{stidHash} }) { 
      my ($t, $e, $d, $f, $r, $n, $p, $g) = GazeOnToken(1, $sid);
      $fpd += $f;
      $trt += $r;
      $number += $n;
    }
    $TGT->{$tid}{FPDurS} = $fpd;
    $TGT->{$tid}{TrtS} = $trt;
    $TGT->{$tid}{FixS} = $number;
  }

#printf STDERR "GazeTimeOnToken AG:\n";
  foreach my $au (keys %{$AG}) {
    $trt = 0;
    $fpd = 0;
    $number = 0;
    foreach my $sid (keys %{$AG->{$au}{stidHash}}) {
      my ($t, $e, $d, $f, $r, $n, $p, $g) = GazeOnToken(1, $sid);
      $fpd += $f;
      $trt += $r;
      $number += $n;
    }
    $AG->{$au}{FPDurS} = $fpd;
    $AG->{$au}{TrtS} = $trt;
    $AG->{$au}{FixS} = $number;

    $fpd = 0;
    $trt = 0;
    $number = 0;
    foreach my $tid (keys %{$AG->{$au}{ttidHash} }) {
      my ($t, $e, $d, $f, $r, $n, $p, $g) = GazeOnToken(2, $tid);
      $fpd += $f;
      $trt += $r;
      $number += $n;
    }
    $AG->{$au}{FPDurT} = $fpd;
    $AG->{$au}{TrtT} = $trt;
    $AG->{$au}{FixT} = $number;
  }
}


sub EditEfficiency {
  foreach my $sid (keys %{$SRC}) { 
    if(defined($SRC->{$sid}{TGroup}) && defined($SRC->{$sid}{len})) {
      $SRC->{$sid}{InEff} = sprintf("%4.2f", $SRC->{$sid}{len} / (1+length($SRC->{$sid}{TGroup}))); 
  } }
  foreach my $tid (keys %{$TGT}) { 
    if(defined($TGT->{$tid}{TToken})  && defined($TGT->{$tid}{len})) {
      $TGT->{$tid}{InEff} = sprintf("%4.2f", $TGT->{$tid}{len} / (1+length($TGT->{$tid}{TToken})));
  } }

  foreach my $au  (keys %{$AG }) { 
    if(defined($AG->{$au}{TGroup}) && defined($AG->{$au}{len}))   {
      $AG->{$au}{InEff}   = sprintf("%4.2f", $AG->{$au}{len} / (1+length($AG->{$au}{TGroup}))); 
    }
  }
}


##################################################
#  Parallel Reading/writing activity
##################################################

## amount of overlap between $start - $dur and intervals in $U
sub Overlap {
  my ($start, $dur, $U) = @_;
  my $m = 0;
  my $H = {1 => {d => 0, n => 0}, 2 => { d => 0, n => 0}};

  if($dur == 0) { return $H; }

  my $win;
  foreach my $u (sort {$a<=>$b} keys %{$U}) {

    if($u+$U->{$u}{Dur} < $start) {next;}
    if($u > $start+$dur) {last;}

## FIX has a window PU has not
    if(defined($U->{$u}{Win})) { $win = $U->{$u}{Win}}
    else {$win = 0;}

# printf STDERR "U:%s--%s\tPU:%s--%s\t%s\n", $u, $u+$U->{$u}{Dur}, $start, $start+$dur, $win;
    ## U inside PU
    if($u <= $start && $u+$U->{$u}{Dur} >= $start+$dur) {$H->{$win}{d} += $dur; $H->{$win}{n}++;}
    ## PU overlap start of U
    elsif($u <= $start && $u+$U->{$u}{Dur} < $start+$dur) {$H->{$win}{d} += $u+$U->{$u}{Dur}-$start; $H->{$win}{n}++;}
    ## PU overlap end of U
    elsif($u > $start && $u+$U->{$u}{Dur} >= $start+$dur) {$H->{$win}{d} += $start+$dur - $u; $H->{$win}{n}++;}
    ## PU inside U
    elsif($u > $start && $u+$U->{$u}{Dur} < $start+$dur) {$H->{$win}{d} += $U->{$u}{Dur}; $H->{$win}{n}++;}
    else { print STDERR "Overlap: Error3\n";}
  }

  return $H;
}


sub ParallelActivity {
  my $m = 0;
  my $H;

#  foreach my $u (sort {$a<=>$b} keys %{$PU}) {
  foreach my $u (keys %{$PU}) {
    $H=Overlap($u, $PU->{$u}{Dur}, $FIX);
    foreach my $win (keys %{$H}) {
      my $winStr = 'N';
	  if($win == 1) {$winStr = 'S';}
	  if($win == 2) {$winStr = 'T';}

      $PU->{$u}{"ParTrt$winStr"} = sprintf("%d",$H->{$win}{d});
      $PU->{$u}{"ParFix$winStr"} = sprintf("%d",$H->{$win}{n});
    }
  }

#  foreach my $u (sort {$a<=>$b} keys %{$FU}) {
  foreach my $u (keys %{$FU}) {
    $H=Overlap($u, $FU->{$u}{Dur}, $PU);
    if(defined($H->{0})) { 
      $FU->{$u}{ParFix}=sprintf("%d", $H->{0}{n});
      $FU->{$u}{ParTrt}=sprintf("%d", $H->{0}{d});
    }
    else { 
      $FU->{$u}{ParFix} = 0;
      $FU->{$u}{ParPar} = 0;
    }
  }

#  foreach my $u (sort {$a<=>$b} keys %{$AG}) {
  foreach my $u (keys %{$AG}) {
    $AG->{$u}{ParTrtS} = 0;
    $AG->{$u}{ParFixS} = 0;
    $AG->{$u}{ParTrtT} = 0;
    $AG->{$u}{ParFixT} = 0;
	
	# loop over micro units
    for(my $i=0; $i<=$#{$AG->{$u}{start}}; $i++) {
      my $start = $AG->{$u}{start}[$i];
      my $dur   = $AG->{$u}{end}[$i] - $AG->{$u}{start}[$i];

      $H=Overlap($start, $dur, $FIX);
#printf STDERR "ParallelActivity1 au:$u i:$i start:$start dur:$dur\n";
#d($H);

      foreach my $win (keys %{$H}) {
	    my $winStr = 0;
	    if($win == 1) {$winStr = 'S';}
	    if($win == 2) {$winStr = 'T';}
		
        $AG->{$u}{"ParTrt${winStr}"} += sprintf("%d", $H->{$win}{d});
        $AG->{$u}{"ParFix${winStr}"} += sprintf("%d", $H->{$win}{n});
 		
#        push(@{$AG->{$u}{"Paral$winStr"}}, $H->{$win}{d});
        if($i == 0) {
          $AG->{$u}{"ParTrt${winStr}1"} =sprintf("%d", $H->{$win}{d});
          $AG->{$u}{"ParFix${winStr}1"} =sprintf("%d", $H->{$win}{n});
        }
        if($i == 1) {
          $AG->{$u}{"ParTrt${winStr}2"} =sprintf("%d", $H->{$win}{d});
          $AG->{$u}{"ParFix${winStr}2"} =sprintf("%d", $H->{$win}{n});
        }
      }
#printf STDERR "ParallelActivity2 au:$u i:$i start:$start dur:$dur\n";
#d($AG->{$u}{start});

    }
  }

#  foreach my $u (sort {$a<=>$b} keys %{$TGT}) {
  foreach my $u (keys %{$TGT}) {
    $TGT->{$u}{ParTrtS} = 0;
    $TGT->{$u}{ParFixS} = 0;
    $TGT->{$u}{ParTrtT} = 0;
    $TGT->{$u}{ParFixT} = 0;
	
	# loop over micro units
    for(my $i=0; $i<=$#{$TGT->{$u}{start}}; $i++) {
      my $start = $TGT->{$u}{start}[$i];
      my $dur   = $TGT->{$u}{end}[$i] - $TGT->{$u}{start}[$i];

      $H=Overlap($start, $dur, $FIX);
      foreach my $win (keys %{$H}) {
	    my $winStr = 0;
	    if($win == 1) {$winStr = 'S';}
	    if($win == 2) {$winStr = 'T';}
#        push(@{$TGT->{$u}{"Paral$winStr"}}, $H->{$win}{d});
		$TGT->{$u}{"ParTrt${winStr}"} += $H->{$win}{d};
		$TGT->{$u}{"ParFix${winStr}"} += $H->{$win}{n};
		
        if($i == 0) {
          $TGT->{$u}{"ParTrt${winStr}1"} = sprintf("%d", $H->{$win}{d});
          $TGT->{$u}{"ParFix${winStr}1"} = sprintf("%d", $H->{$win}{n});
        }
        if($i == 1) {
          $TGT->{$u}{"ParTrt${winStr}2"} = sprintf("%d", $H->{$win}{d});
          $TGT->{$u}{"ParFix${winStr}2"} = sprintf("%d", $H->{$win}{n});
        }
      }
    }
  } 

#  foreach my $u (sort {$a<=>$b} keys %{$SRC}) {
  foreach my $u (sort {$a<=>$b}keys %{$SRC}) {
    $SRC->{$u}{ParTrtS} = 0;
    $SRC->{$u}{ParTrtT} = 0;
    $SRC->{$u}{ParFixS} = 0;
    $SRC->{$u}{ParFixT} = 0;
	
	# loop over micro units
    for(my $i=0; $i<=$#{$SRC->{$u}{start}}; $i++) {
      my $start = $SRC->{$u}{start}[$i];
      my $dur   = $SRC->{$u}{end}[$i] - $SRC->{$u}{start}[$i];

      $H=Overlap($start, $dur, $FIX);
      foreach my $win (keys %{$H}) {
  	    my $winStr = '';
	    if($win == 1) {$winStr = 'S';}
	    if($win == 2) {$winStr = 'T';}

#        push(@{$SRC->{$u}{"Paral$winStr"}}, $H->{$win}{d});
		
		$SRC->{$u}{"ParTrt${winStr}"} += $H->{$win}{d};
		$SRC->{$u}{"ParFix${winStr}"} += $H->{$win}{n};
        if($i == 0) {
          $SRC->{$u}{"ParTrt${winStr}1"} = sprintf("%d", $H->{$win}{d});
          $SRC->{$u}{"ParFix${winStr}1"} = sprintf("%d", $H->{$win}{n});
        }
        if($i == 1 ) {
          $SRC->{$u}{"ParTrt${winStr}2"} = sprintf("%d", $H->{$win}{d});
          $SRC->{$u}{"ParFix${winStr}2"} = sprintf("%d", $H->{$win}{n});
        }
      }
    }
	foreach my $seg (sort {$a<=>$b} keys %{$SG}) { 
	  my $s = $SRC->{$u}{STseg};
      if(defined($SG->{$seg}{sseg}{$s})) { 
#print STDERR "PPPP: word:$u seg:$s seg:$seg win1:$SRC->{$u}{par1} num1:$SRC->{$u}{num1}\n";
        $SG->{$seg}{ParTrtS} += $SRC->{$u}{ParTrtS};
        $SG->{$seg}{ParTrtT} += $SRC->{$u}{ParTrtT};
        $SG->{$seg}{ParFixS} += $SRC->{$u}{ParFixS};
        $SG->{$seg}{ParFixT} += $SRC->{$u}{ParFixT};
	} }
  }
}

#################################################
# Production Units
#################################################

sub ProductionUnits {

	my $last = 0;
	my $start = 0;
	my $end = 0;
	my $T = {}; # time keystrokes in PU 

	my $K = [sort  {$a <=> $b} keys %{$KEY}];
	for (my $i = 0; $i <= $#{$K}; $i ++) {
		my $t = $K->[$i];

		if(!defined($KEY->{$t}{Type})) {
			printf STDERR "ProductionUnits1: $t\n";
			#d($KEY->{$t})
		}
		# automatic insertion or deletion
		if($KEY->{$t}{Type} eq 'Ains' ||  $KEY->{$t}{Type} eq 'Adel') { next;}
		
	## Production Unit detected 
		if($start != 0 && ($t - $end) > $PUKeyGap) {

			$PU->{$start}{Type} = 7;
			ScanPathFeatures($PU->{$start}, $last, $end);
			$PU->{$start}{Pause} = $start - $last; # initial typing pause
			$PU->{$start}{Dur} = $end - $start; # Dur of burst
			$PU->{$start}{Time} = $start;   # Start of Production Unit
			$PU->{$start}{TimeTU} = $last;   # Start of Translation Unit
			$PU->{$start}{DurTU} = $end - $last;   # Duration of TU
			addYawatInfo($PU->{$start}, $T);

		#printf STDERR "ProductionUnits3:\t$last\t$start\t$end\n"; 
		#d($PU->{$start});

			$start = 0;
			$last = $end;
			$T = {};
		}
		if($start == 0) {$start = $t - $KEY->{$t}{Dur}; }
		$T->{$t} ++;

#	$end = $t + $KEY->{$t}{Dur};
		$end = $t;
	}

	$PU->{$start}{Type} = 7;
	ScanPathFeatures($PU->{$start}, $last, $end);
	$PU->{$start}{Pause}  = $start - $last;
	$PU->{$start}{Dur}    = $end - $start;
	$PU->{$start}{Time}   = $start;   # Start of Production Unit
	$PU->{$start}{TimeTU} = $last;   # Start of Translation Unit
	$PU->{$start}{DurTU}  = $end - $last;   # Duration of TU
}

#####

sub addYawatInfo {
	my ($U, $K) = @_;
	
	my $H = {};
	## number/length of source sentence
	foreach my $t (keys %{$K}) {
		$H->{ttid}{$KEY->{$t}{TTid}} ++;
		foreach my $stid (split(/\+/, $KEY->{$t}{SGid})) {
			if($stid == 0) {next;}
			$H->{stid}{$stid} ++;
	}	}
	
	my $yawat = '';
	foreach my $stid (sort  {$a <=> $b} keys %{$H->{stid}}) {
		#yawat
		if(!defined($SRC->{$stid})) {
			print STDERR "addYawatInfo: $stid\n";
			next;
		}
		if(defined($SRC->{$stid}{Yawat}) && $SRC->{$stid}{Yawat} ne '---') {
			if(length($yawat) > 0) {$yawat .= "+";}
			$yawat .= "S:$SRC->{$stid}{Yawat}";
	}	}
	foreach my $ttid (sort  {$a <=> $b} keys %{$H->{ttid}}) {
		if(defined($TGT->{$ttid}{Yawat}) && $TGT->{$ttid}{Yawat} ne '---') {
			if(length($yawat) > 0) {$yawat .= "+";}
			$yawat .= "T:$TGT->{$ttid}{Yawat}";
	}	}
	if(length($yawat) > 0) {$U->{Yawat} = $yawat;}
	else {$U->{Yawat} = "---";}
}

##################################################
#  Activity Units
##################################################

sub ActivityUnits {

  my $time = 0;  #start time of current AU1
  my $start = 0; #start time of last AU
  my $end = 0;   #end time of last AU
  my $Type = 0;  #type of AU

  my $T = MergeFUPU();
  my @L = (sort {$a<=>$b} keys %{$T});
  
  for(my $i=0; $i <= $#L; $i++) {
    $time  = $L[$i];

	if($T->{$time}{Dur} == 0){$T->{$time}{Dur} += 1;}
	my $end1 = $time + $T->{$time}{Dur};
	my $typ1 = $T->{$time}{stype};
	
#initialization	
    if($Type == 0) {
		$start = $time; 
		$end = $end1; 
		$Type = $typ1; 
		next;
	}
#printf STDERR "ActivityUnits0: $time $end1 <= $end dur: $T->{$time}{Dur}\ttype:$typ1 = $T->{$time}{stype} = $Type\n";

	#gap between successive AUs
    if($end <= $time) {
		#pause if gap > $AUpauseGap 
		if($end+$AUpauseGap <= $time) {
			$AU->{$end}{Type} = 8;
#printf STDERR "ActivityUnits - 1\n";
			ScanPathFeatures($AU->{$end}, $end, $time);
		}
## join successive AUs if identical
		elsif($Type == $typ1) {
			$end = $end1;
			next;
		}

		else {my $g = int(($time - $end)/2); $end += $g; $time -= $g;}
		$AU->{$start}{Type} = $Type;
		ScanPathFeatures($AU->{$start}, $start, $end);
		$start = $time; 
		$end = $end1; 
		$Type = $typ1; 
		next;
    }

	# current AU1 inside last AU
	if($end1 <= $end) {
	# initial segment if shorter than $AUgazeMerge
		if($Type == $typ1) {
			printf STDERR "ActivityUnits2: same:$typ1 start:$start/%d\t$time\t$end1\n", $end - $start;
		}

		# insert initial segment
		if($start+$AUgazeMerge <= $time) {
			$AU->{$start}{Type} = $Type;
#printf STDERR "ActivityUnits - 3\n";
			ScanPathFeatures($AU->{$start}, $start, $time);
			$start = $time; 
		}
		# set segment start to time
		else {$time = $start;}
		$AU->{$time}{Type} = $Type | $typ1;
#printf STDERR "ActivityUnits - 4\t$time, $end1\n";
		ScanPathFeatures($AU->{$time}, $time, $end1);
		$start = $end1; 
	}
	#overlap AU1 and AU
	else {
		if($start+$AUgazeMerge <= $time) {
			$AU->{$start}{Type} = $Type;
#printf STDERR "ActivityUnits - 5\n";
			ScanPathFeatures($AU->{$start}, $start, $time);
		}
		else {$time = $start;}
		if($Type == $typ1) {
			printf STDERR "ActivityUnits3: same:$typ1 start:$start/%d $time\n", $end - $start;
		}		
		
		$AU->{$time}{Type} = $Type | $typ1;
#printf STDERR "ActivityUnits - 6\n";
		ScanPathFeatures($AU->{$time}, $time, $end);
		$start = $end;
		$end = $end1;
		$Type = $typ1;
	}

  }
  ActivityUnitsNgram();
}

sub ActivityUnitsNgram {
  my $s1 = '0';
  my $s2 = '0';
  my $s3 = '0';
  my $s4 = '0';
  my $s5 = '0';

  foreach my $t (sort {$a<=>$b} keys %{$AU}) {
	$AU->{$t}{Time} = $t;
  
    if(!defined($AU->{$t}{Type})) {$AU->{$t}{Type} = 0;}	
	my $s1 = $AU->{$t}{Type};

	$AU->{$t}{Gram5} = "$s1$s2$s3$s4$s5";
	$s5 = $s4;
	$s4 = $s3;
	$s3 = $s2;
	$s2 = $s1;
  }
  
}

## features for AU and PU
sub ScanPathFeatures {
    my ($U, $s, $e) = @_;

    $U->{Time}  = $s;
    $U->{Dur}  = $e - $s;
	
	$U->{CrossS} = 0;
	$U->{CrossT} = 0;
	$U->{TrtS} = 0;
	$U->{TrtT} = 0;
	$U->{TurnXS} = 0;
	$U->{TurnXT} = 0;
    $U->{Del}  = 0;
    $U->{FixS} = 0;
    $U->{FixT} = 0;
    $U->{InEff} = 0;
    $U->{Ins}  = 0;
    $U->{Key}  = 0;
	
	$U->{WinSwitch} = 0;
    $U->{FixSspanX} = 0;
    $U->{FixSspanY} = 0;
    $U->{FixTspanX} = 0;
    $U->{FixTspanY} = 0;
    $U->{FixSmeanX} = 0;
    $U->{FixSmeanY} = 0;
    $U->{FixTmeanX} = 0;
    $U->{FixTmeanY} = 0;

### fixations
    if($U->{Type} & 3) {FixPathFeatures($U, $s, $e);}
### keystrokes
	if($U->{Type} & 4) {KeyPathFeatures($U, $s, $e);}

	
## Phase
	if($DraftingStart > $e) {$U->{Phase} = 'O';}
	elsif($DraftingEnd < $e) {$U->{Phase} = 'R';}
	else {$U->{Phase} = 'D';}

# default values
    if(!defined($U->{PosS})) { $U->{PosS} = '---';}
    if(!defined($U->{PosT})) { $U->{PosT} = '---';}
    if(!defined($U->{SGid})) { $U->{SGid} = '---';}
    if(!defined($U->{TGid})) { $U->{TGid} = '---';}
}


#################################    
### Fixations in a AU or PU unit

sub FixPathFeatures {
    my ($U, $s, $e) = @_;
	
    my $t0 = 0;
	my $dlast = 0;
	my $win = 0;
    my $M = {};
    $M->{minX1} = 0;
    $M->{maxX1} = 0;
    $M->{minY1} = 0;
    $M->{maxY1} = 0;
    
    $M->{minX2} = 0;
    $M->{maxX2} = 0;
    $M->{minY2} = 0;
    $M->{maxY2} = 0;
       
    $M->{fixX1} = ();
    $M->{fixY1} = ();
    $M->{fixX2} = ();
    $M->{fixY2} = ();
	# direction of fixation path
    $M->{fix1dir} = 0;
    $M->{fix2dir} = 0;
    $M->{fix2dir} = 0;
    $M->{fix2dir} = 0;
	$M->{fixX1dist} = 0;
    $M->{fixX2dist} = 0;
    $M->{fixY1dist} = 0;
    $M->{fixY2dist} = 0;
	
	$U->{GazePath} = '';
	$U->{FixS} = 0;
	$U->{FixT} = 0;
	$U->{TrtS} = 0;
	$U->{TrtT} = 0;
    $U->{TurnXS} = 0;
    $U->{TurnXT} = 0;
    $U->{FixSmeanX} = 0;
    $U->{FixTmeanX} = 0;
    $U->{FixSmeanY} = 0;
    $U->{FixTmeanY} = 0;
   
#   print STDERR "\n";
    foreach my $t (sort  {$a <=> $b} keys %{$FIX}) {
	    if($t + $FIX->{$t}{Dur} <= $s) {$t0 = $t; next;}
	    if($t > $e) {last;}
		
        if(!defined($FIX->{$t}{Win}) || ($U->{Type} == 0)) {
			print STDERR "fixation $t:\twin undef\n";
			d($FIX->{$t});
			next;
		}
			
        # switch between ST - TT
		if($win != $FIX->{$t}{Win}) {$U->{WinSwitch} += 1;}
		$win = $FIX->{$t}{Win};
		
		if($win == 1 && !defined($SRC->{$FIX->{$t}{STid}})) {
			$WarningsCount->{"Undefined FIX-STid: $FIX->{$t}{STid}"} ++;
#			print STDERR "FixPathFeatures: $t win:$win Undefined src Id: $FIX->{$t}{TTid}\n";
			next;
		}
		if($win == 2 && !defined($TGT->{$FIX->{$t}{TTid}})) {
			$WarningsCount->{"Undefined FIX-TTid: $FIX->{$t}{TTid}"} ++;
#			print STDERR "FixPathFeatures: $t win:$win Undefined src Id: $FIX->{$t}{TTid}\n";
			next;
		}

        # segments
#  	    $M->{seg}{$FIX->{$t}{Seg}} ++; 
		
        if($win == 1) {
			if($M->{minX1} == 0 || $FIX->{$t}{X} < $M->{minX1}) {$M->{minX1} = $FIX->{$t}{X};}
			if($M->{maxX1} == 0 || $FIX->{$t}{X} > $M->{maxX1}) {$M->{maxX1} = $FIX->{$t}{X};}
			if($M->{minY1} == 0 || $FIX->{$t}{Y} < $M->{minY1}) {$M->{minY1} = $FIX->{$t}{Y};}
			if($M->{maxY1} == 0 || $FIX->{$t}{Y} > $M->{maxY1}) {$M->{maxY1} = $FIX->{$t}{Y};}
			$U->{FixS} +=1;

			# memorize fixation path
			push(@{$M->{fixX1}}, $FIX->{$t}{X});
			push(@{$M->{fixY1}}, $FIX->{$t}{Y});
			  
			## fixation path
			if($U->{GazePath} ne '') {$U->{GazePath} .= "+";}
			$U->{GazePath} .= "S:$FIX->{$t}{STid}";
			
			# total reading time 
			if($t < $s) {$U->{TrtS} += $FIX->{$t}{Dur} - ($s - $t); }
			else {$U->{TrtS} += $FIX->{$t}{Dur}}
			  
			# average fix dist
			if($M->{fix1dir} > 0) { 
				$M->{fixX1dist} += abs($FIX->{$t}{X} - $FIX->{$t0}{X});
				$M->{fixY1dist} += abs($FIX->{$t}{Y} - $FIX->{$t0}{Y});
			}
			  
			# turn 
			$M->{fix2dir} = 0;
			if($M->{fix1dir} == 0) { $M->{fix1dir} = 3}
			elsif($M->{fix1dir} == 3 && $FIX->{$t}{X} > $FIX->{$t0}{X}) { $M->{fix1dir} = 1}
			elsif($M->{fix1dir} == 1 && $FIX->{$t}{X} < $FIX->{$t0}{X} - $HalfFixationRadius) {
				$U->{TurnXS} += 1;
				$M->{fix1dir} = 2;
			}
			elsif($M->{fix1dir} == 2 && $FIX->{$t}{X} > $FIX->{$t0}{X} + $HalfFixationRadius) {
				$U->{TurnXS} += 1;
				$M->{fix1dir} = 1;
			}
          
        }
        elsif($win == 2) {
		  if($M->{minX2} == 0 || $FIX->{$t}{X} < $M->{minX2}) {$M->{minX2} = $FIX->{$t}{X};}
		  if($M->{maxX2} == 0 || $FIX->{$t}{X} > $M->{maxX2}) {$M->{maxX2} = $FIX->{$t}{X};}
		  if($M->{minY2} == 0 || $FIX->{$t}{Y} < $M->{minY2}) {$M->{minY2} = $FIX->{$t}{Y};}
		  if($M->{maxY2} == 0 || $FIX->{$t}{Y} > $M->{maxY2}) {$M->{maxY2} = $FIX->{$t}{Y};}
#print STDERR "OOOOO: $FIX->{$t}{X}: min:$M->{minX2} max:$M->{maxX2} $FIX->{$t}{Y}: min:$M->{minY2} $M->{maxY2}\n";
#d($FIX->{$t});
		  
          $U->{FixT} +=1;
          
          push(@{$M->{fixX2}}, $FIX->{$t}{X});
          push(@{$M->{fixY2}}, $FIX->{$t}{Y});
          
		  ## fixation path
          if($U->{GazePath} ne '') {$U->{GazePath} .= "+";}
          $U->{GazePath} .= "T:$FIX->{$t}{TTid}";

          # total reading time 
          if($t < $s) {$U->{TrtT} += $FIX->{$t}{Dur} - ($s - $t); }
          else {$U->{TrtT} += $FIX->{$t}{Dur}}
          
          # average fix dist
          if($M->{fix2dir} > 0) { 
            $M->{fixX2dist} += abs($FIX->{$t}{X} - $FIX->{$t0}{X});
            $M->{fixY2dist} += abs($FIX->{$t}{Y} - $FIX->{$t0}{Y});
          }

#print STDERR "TurnXT1: $U->{TurnXT} dir:$M->{fix2dir} $t:$FIX->{$t}{X}\t$t0:$FIX->{$t0}{X}\n"; 
         # turn 
          $M->{fix1dir} = 0;
          if($M->{fix2dir} == 0) { $M->{fix2dir} = 3}
          elsif($M->{fix2dir} == 3 && $FIX->{$t}{X} > $FIX->{$t0}{X}) { $M->{fix2dir} = 1}
          elsif($M->{fix2dir} == 3 && $FIX->{$t}{X} < $FIX->{$t0}{X}) { $M->{fix2dir} = 2}
          elsif($M->{fix2dir} == 1 && $FIX->{$t}{X} < $FIX->{$t0}{X} - $HalfFixationRadius) {
#print STDERR "Turn-A: $U->{TurnXT} dir:$M->{fix2dir} $t:$FIX->{$t}{X}\t$t0:$FIX->{$t0}{X}\n"; 
            $U->{TurnXT} += 1;
            $M->{fix2dir} = 2;
          }
          elsif($M->{fix2dir} == 2 && $FIX->{$t}{X} > $FIX->{$t0}{X} + $HalfFixationRadius) {
#print STDERR "Turn-B: $U->{TurnXT} dir:$M->{fix2dir} $t:$FIX->{$t}{X}\t$t0:$FIX->{$t0}{X}\n"; 

            $U->{TurnXT} += 1;
            $M->{fix2dir} = 1;
          }

        }
	  	
        $t0 = $t;
    }
    
	if($U->{GazePath} eq '') {$U->{GazePath} = '---'};

    ### No fixations
	if($t0 == 0) {return;}
	
    $U->{FixSspanX} = $M->{maxX1} - $M->{minX1};
    $U->{FixSspanY} = $M->{maxY1} - $M->{minY1};
    $U->{FixTspanX} = $M->{maxX2} - $M->{minX2};
    $U->{FixTspanY} = $M->{maxY2} - $M->{minY2};
     
#print STDERR "FFF >$M->{fixX1dist}<  >$U->{FixS}<\n";
    if($U->{FixS} > 0) {$U->{FixSmeanX} = sprintf("%4.2f", $M->{fixX1dist} / $U->{FixS});}
    if($U->{FixT} > 0) {$U->{FixTmeanX} = sprintf("%4.2f", $M->{fixX2dist} / $U->{FixT});}
    if($U->{FixS} > 0) {$U->{FixSmeanY} = sprintf("%4.2f", $M->{fixY1dist} / $U->{FixS});}
    if($U->{FixT} > 0) {$U->{FixTmeanY} = sprintf("%4.2f", $M->{fixY2dist} / $U->{FixT});}

## standard dev. and median of fixation path
	if(defined($M->{fixX1}) && defined($M->{fixY1})) {
		($U->{FixSmean}, $U->{FixSstd}, $U->{FixSdist}) = FixScanPath($M->{fixX1}, $M->{fixY1});
	}
	if(defined($M->{fixX2}) && defined($M->{fixY2})) {
		($U->{FixTmean}, $U->{FixTstd}, $U->{FixTdist}) = FixScanPath($M->{fixX2}, $M->{fixY2});
	}
}


sub FixScanPath {
    my ($X, $Y) = @_;
	
	my @D = ();
	my $m = scalar(@{$X});
	my $sum = 0;
	my $min = 0;
    my $max = 0;
	my ($x, $y, $d, $j);

#    foreach my $i (@{$X}) { 
    for(my $i = 0; $i < (@{$X})-1; $i++) { 
		$j = $i + 1;
		$x = (@$X[$i] - @$X[$j]) * (@$X[$i] - @$X[$j]);
		$y = (@$Y[$i] - @$Y[$j]) * (@$Y[$i] - @$Y[$j]);
		$d = sqrt($x + $y);
		if($d < $min && $min != 0) {$min = $d}
		if($d > $max && $max != 0) {$max = $d};
		$sum += $d;
#	print STDERR "FixScanPath: $m, $i, @$X[$i], @$X[$j], $x, $z\n";
	    push(@D, $d);
	}

	my $ave = $sum / $m;
	my $std = stdev(\@D, $ave);
#	print STDERR "SSS3: $ave, $std\n";
	return (sprintf("%4.2f", $ave), sprintf("%4.2f", $std),  sprintf("%4.2f", $sum));

}

## 
sub stdev{
    my($data, $average) = @_;

    if(@{$data} == 1){return 0;}
    my $sqtotal = 0;
    foreach(@$data) {
        $sqtotal += ($average-$_) ** 2;
    }
    my $std = ($sqtotal / (@$data-1)) ** 0.5;
    return $std;
}

sub KeyPathFeatures {
    my ($U, $s, $e) = @_;

    my $type = 'Mins';
    my $LastId = -1;
    my $Tids = {};
    my $Sids = {};
    my $SegT = {}; 
    my $SegS = {}; 
    my $scatter = 0;
    my $KeyStrokes = 0;

    foreach my $t (sort  {$a <=> $b} keys %{$KEY}) { 
	      # automatic insertion or deletion
        if($KEY->{$t}{Type} eq 'Ains' ||  $KEY->{$t}{Type} eq 'Adel') { next;}

        if($t <= $s) {next;}
        if($t > $e) {last;}

        # number of keystrokes
	if($KEY->{$t}{Type} =~ /ins/) {$U->{Ins} += $KEY->{$t}{Strokes};}
	if($KEY->{$t}{Type} =~ /del/) {$U->{Del} += $KEY->{$t}{Strokes};}
        $U->{Key} ++;
		
	    # edit string end of deletion
	if($type!~/$KEY->{$t}{Type}/ && $KEY->{$t}{Type} =~ /ins/) {$U->{Edit}.= ']';}
	if($type!~/$KEY->{$t}{Type}/ && $KEY->{$t}{Type} =~ /del/) {$U->{Edit}.= '[';}
	$U->{Edit} .= $KEY->{$t}{Char};
	$type = $KEY->{$t}{Type};
		
	$SegT->{$KEY->{$t}{TTseg}} ++;
	#
	# merge st hash segments
	$SegS = {%{$SegS}, %{$KEY->{$t}{ssegHash}}};
			
	# scattered text production 
	if(defined($KEY->{$t}{TTid} )) { 
	    foreach my $i (split(/\+/, $KEY->{$t}{TTid} )) {
		if($LastId != -1) {
			$scatter +=  abs($i - $LastId); 
			$KeyStrokes++;
		}
		$LastId = $i;
		$Tids->{$i}++; 
 	    }
	}
	if(defined($KEY->{$t}{SGid} )) {
	  foreach my $i (split(/\+/, $KEY->{$t}{SGid} )) {
		$Sids->{$i}++;
	  }
	}

    }
	# end foreach KEY loop
	
    if($type =~ /del/) {  $U->{Edit} .= ']';}
  
    # scatter feature
    $U->{Scatter} = 0;
    if($KeyStrokes) {
		# subtract number of different words 
		$U->{Scatter} = sprintf("%4.2f", ($scatter - scalar(keys %{$Tids}) + 1) / $KeyStrokes);
	}
	
    # STseg and TTseg
	$U->{TTseg} = '';
    foreach my $seg (sort {$a<=>$b} keys %{$SegT}) { 
	    if(length($U->{TTseg}) > 0) {$U->{TTseg} .= '+';} 
		$U->{TTseg} .= $seg;
    }

    $U->{STseg} = '';
    foreach my $seg (sort {$a<=>$b} keys %{$SegS}) { 
	    if(length($U->{STseg}) > 0) {$U->{STseg} .= '+';} 
		$U->{STseg} .= $seg;
    }
	
    $U->{SGnbr} = scalar(keys %{$Sids});
    $U->{TGnbr} = scalar(keys %{$Tids});
	  	
    # average CROSS on source
    my $CroS = 0;
    my $n = 0;
    foreach my $s (sort  {$a <=> $b} keys %{$Sids}) {
	if($s <= 0) { next;}
		
        if($U->{SGid}) {$U->{SGid}  .= "+"; } 
		$U->{SGid}  .= "$s"; 
		
		if(defined($SRC->{$s})) {
		  if($U->{PosS}) {$U->{PosS} .= "+";}
		  $U->{PosS} .= $SRC->{$s}{PoS};
		  $CroS += abs($SRC->{$s}{Cross});
		  $n ++;
        }
    }
	if(!defined($U->{SGid})) {$U->{SGid} = '---';}
    if($CroS > 0) {$U->{CrossS} =  sprintf("%4.2f", $CroS /= $n);}
	
	# average CROSS on source
	my $CroT = 0;
	$n = 0;
    foreach my $s (sort  {$a <=> $b} keys %{$Tids}) {
		if($s <= 0) { next;}

		if($U->{TGid}) {$U->{TGid}  .= "+"; } 
		$U->{TGid}  .= "$s"; 
		
		if(defined($TGT->{$s})) {
			if($U->{PosT}) {$U->{PosT}  .= "+"; } 
			$U->{PosT} .= $TGT->{$s}{PoS};
			$CroT += abs($TGT->{$s}{Cross});
			$n ++;
        }
    }
	if(!defined($U->{TGid})) {$U->{TGid} = '---';}
    if($CroT > 0) {$U->{CrossT} =  sprintf("%4.2f", $CroT /= $n);}
}

sub MergeFUPU {
  my $T;

  foreach my $f (keys %{$FU}) {
    if($FU->{$f}{Win} & 3) {
      $T->{$f} = $FU->{$f}; 
      $T->{$f}{stype} = $FU->{$f}{Win};
	}
  }
  foreach my $f (sort {$a<=>$b} keys %{$PU}) { 
    my $t = $f;
    while(defined($T->{$t})) {$t++}
    $T->{$t} = $PU->{$f}; 
    $T->{$t}{stype} = 4;
  }
  return $T;
}


################################################################
# PRINTING
################################################################

###################################################
# PRINTING TEMPLATE


sub PrintTemplate {
	my ($fn, $label, $UNIT) = @_;

	if(defined($UNIT->{SS})) {
		if(!open(FILE, ">>:encoding(utf8)", $fn)) {
			printf STDERR "cannot open: $fn\n";
			return ;
		}
	}
	else {
		if(!open(FILE, ">:encoding(utf8)", $fn)) {
			printf STDERR "cannot open: $fn\n";
			return ;
		}
	}

    my $string = "Id\t";
    $string .= "Study\t";
    $string .= "Session\t";
    $string .= "SL\t";
    $string .= "TL\t";
    $string .= "Task\t";
    $string .= "Text\t";
    $string .= "Part";
	
	foreach (@{$label}) {$string .= "\t$_";}
	printf FILE "$string\n";
#	printf STDERR "\n$fn HEADING\n$string\n";
	  
	
	my $n = 1;
	foreach my $u (sort  {$a <=> $b} keys %{$UNIT}) {
		$string = "$n\t";
	    $string .= "$Study\t";
		$string .= "$Session\t";
		$string .= "$SourceLang\t";
		$string .= "$TargetLang\t";
		$string .= "$Task\t";
		$string .= "$Text\t";
		$string .= "$Part";
		$n++;

		if($Verbose > 10) {
			d($UNIT->{$u});
			foreach my $l (keys %{$UNIT->{$u}}) {
				if(grep( /^$l$/, @{$label})) {next; print STDERR "$fn\tfound: $l\n";}
				else { print STDERR "*** NOT in Labels: $l\n";}
			}
		}
		
		my $p = 1;
		foreach my $l (@{$label}) {
			if(!defined($UNIT->{$u}{$l})) {
				$WarningsCount->{"No Label '$l'"} += 1;
#				print STDERR "$fn\tLabel '$l' no value in row $u\n";
				$UNIT->{$u}{$l} = '---';
			}
            # alpha numerical string
			if($UNIT->{$u}{$l} =~ /^[-+.=_a-z0-9]+$/i) { 
				$string .= "\t$UNIT->{$u}{$l}";
			}
			# put quotes around
			else {
				$string .= "\t\"$UNIT->{$u}{$l}\"";
			}
		}
		print FILE "$string\n";
	}
	close(FILE);
}
