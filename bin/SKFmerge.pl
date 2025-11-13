#!/usr/bin/perl -w

use strict;
use warnings;

use Data::Dumper; $Data::Dumper::Indent = 1;
sub d { print STDERR Data::Dumper->Dump([ @_ ]); }

my $usage =
  "SKFmerge: generate Translog file from bilingual Elan output (interpretation: option -A)\n".
  "          merge  Elan output into Translog (sight translation: options -T and -A)\n".
  "  -A: ASR_elan-transcription: <ElanRoot>.txt \n".
  "  -T: Translog-II file: <Translog>.xml (for sight translation)\n".
  "  -O: Output filename: <OutputRoot> (generates <OutputRoot>.xml (and <OutputRoot>.tga.\$lng, for \$lng:{ja,zh}\n".
  "  -s lng: source language (e.g. en, de, da, ja, zh ...)\n".
  "  -t lng: target language (e.g. en, de, da, ja, zh ...)\n".
  "Options:\n".
  "  -E out root: generate merged Elan file\n".
  "  -a: ASR offset\n".
  "  -v verbose mode [0 ... ]\n".
  "  -h this help \n".
  "\n";

use vars qw ($opt_O $opt_A $opt_T $opt_a $opt_E $opt_s $opt_t $opt_v $opt_h);
use Getopt::Std;
getopts ('T:O:A:E:v:t:s:a:h');

my $Verbose = 0;
my $asrOffset = 0;
my $SourceLng = '';
my $TargetLng = '';
my $JaZh = {};

if(defined($opt_v)) { $Verbose = $opt_v;}
if(defined($opt_h) || !defined($opt_A) || !defined($opt_O) || !defined($opt_s) || !defined($opt_t)){ print STDERR $usage; exit;}
#if($opt_A !~ /.txt/) { print STDERR "Wrong format\t\"-A $opt_A\"\nfilename must end in \"*.txt\"\n\n$usage"; exit;}

$TargetLng = $opt_t;
$SourceLng = $opt_s;

my $KeyUpTime = 0;
my $AsrUpTime = 0;
my $TierFile = "";
my $Translog = $opt_T;

if(defined($opt_a)) { $asrOffset = $opt_a;}
if(defined($opt_E)) { $TierFile = $opt_E;}
if(defined($opt_O)) { $Translog = "$opt_O.xml";}
#else {$Translog =~ s/xml$/skf.xml/; }

# sight translation with one language / synchronization of translog file 
if(defined($opt_T)) {makeTiers($opt_T, $opt_A);}

# interpretation with two languages
else {makeTranslog($opt_A);}

WriteJaZh();
if($Verbose) {print STDERR "\n";}

exit;

sub makeTranslog {
  my ($asr) = @_;

  my $H = {};
  $H = readASR($asr, $H);
  
  my $key = '';
  my $fin = '';
  my $src = '';

  foreach my $lng (keys %{$H->{Asr}}) {
#print STDERR "XXX1: $lng $SourceLng $TargetLng\n";
    if($lng eq $SourceLng) {
		$src = "  <SourceTextChar>\n";
		my $off = 0;
# add source keystrokes to CharPos
		foreach my $t (sort {$a <=> $b} keys %{$H->{$lng}}) {
			if($lng eq 'ja' || $lng eq 'zh' ) { $JaZh->{"src.$lng"}{$t} = $H->{$lng}{$t}{ano}; }
			my $L = [split(//, $H->{$lng}{$t}{ano})];
# Same duration for all chars 
#			my $dur = int(($H->{$lng}{$t}{end} - $t)/length($H->{$lng}{$t}{ano}));
			my $dur = int($H->{$lng}{$t}{end} - $t);
			my $tt = $t;
			for (my $i = 0; $i <= $#{$L}; $i++) {
				$src .= "\t<CharPos Cursor=\"$off\" Time=\"$tt\" Dur=\"$dur\" Value=\"$L->[$i]\" />\n";
				$off++;
# same time stamp
#				$tt += $dur;
			}
		}
		$src .= "  </SourceTextChar>"; 
    }
    if($lng eq $TargetLng) {
	  my $off = 0;
	  my $cur = 0;
	  my $end = 0;
      $fin = "  <FinalTextChar>\n";
	  $key = "\t<System Time=\"0\" Value=\"START\" />\n";

# add target keystrokes
	  foreach my $t (sort {$a <=> $b} keys %{$H->{$lng}}) {
	  	if($lng eq 'ja' || $lng eq 'zh' ) { $JaZh->{"tgt.$lng"}{$t} = $H->{$lng}{$t}{ano}; }
		my $val = $H->{$lng}{$t}{ano}; # no blank
		my $dur = $H->{$lng}{$t}{end} - $t; 
		my $tt = $t + $asrOffset;
		$key .= "\t<Key Time=\"$tt\" Cursor=\"$cur\" Dur=\"$dur\" Type=\"insert\" Value=\"$val\" />\n";
		$cur += length($val);
#print STDERR "XXX2: $key\n";

# add target keystrokes to CharPos
		my $L = [split(//, $val)];
		for (my $i = 0; $i <= $#{$L}; $i++) {
			$fin .= "\t<CharPos Cursor=\"$off\" Value=\"$L->[$i]\" />\n";
			$off++;
		}
		$end = $t + $dur;
	  }
      $key .= "\t<System Time=\"$end\" Value=\"STOP\" />";
      $fin .= "  </FinalTextChar>"; 
    }
  }
  if($src eq '' || $fin eq ''){ print STDERR "No language tiers \"$SourceLng\" and \"$TargetLng\" in $asr\n"; return;} 

  ##### write New Translog file
  open(FILE, '>:encoding(utf8)', $Translog) || die ("cannot open file $Translog for writing");
  if($Verbose) {print STDERR "Writing: $Translog\n";}

  print FILE <<EODL;
<?xml version="1.0" encoding="utf-8"?>
<LogFile xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\">
  <Languages source="$SourceLng" target="$TargetLng" task="interpreting" system="elan" />
  <Events>
$key    
  </Events>
$src
$fin
</LogFile>
EODL

  close(FILE);
}

sub WriteJaZh {

  foreach my $lng (keys %{$JaZh}) {
 
#  print STDERR "open: $Translog.$lng\n";
    open(FILE, '>:encoding(utf8)', "$Translog.$lng") || die ("cannot open file $Translog.$lng for writing");
	if($Verbose) {print STDERR "Writing: $Translog.$lng\n";}

    foreach my $t (sort {$a<=> $b} keys %{$JaZh->{$lng}}) { print FILE "$JaZh->{$lng}{$t}\ttag\n";}
    close(FILE);
  }
}

sub makeTiers {
  my ($trlg, $asr) = @_;

  my $H = {};
  $H = readASR($asr, $H);
  my $T = readTranslog($trlg, $H);
  
  if($KeyUpTime == 0) {
     printf STDERR "WARNING: no synchronization: Keysync:$KeyUpTime (no symbol '[Up]' in $trlg)\n";
  }
  if($AsrUpTime == 0) {
     printf STDERR "WARNING: no synchronization: AsrSync:$AsrUpTime (no symbol '[Up]' in $asr)\n";
  }
 
  my $keyOffset = $AsrUpTime  - $KeyUpTime;

##### write file new merged TierFile
  if($TierFile ne '') {
	open(FILE, '>:encoding(utf8)', $TierFile) || die ("cannot open file $TierFile for writing");
    if($Verbose) {print STDERR "Writing: $TierFile\n";}

#  printf STDERR "Keyoffset:$keyOffset sync:$AsrUpTime key:$KeyUpTime asr:$asrOffset\n";
	foreach my $time (sort {$a <=> $b} keys %{$H->{Key}}) {
		printf FILE "Key\t%s\t%s\t%s\n", 
		$time+$asrOffset+$keyOffset, $H->{Key}{$time}{end}+$asrOffset+$keyOffset, $H->{Key}{$time}{val};
	}
	foreach my $time (sort {$a <=> $b} keys %{$H->{Fix}}) {
		printf  FILE "Fix\t%s\t%s\t%s\n", 
		$time+$asrOffset+$keyOffset, $H->{Fix}{$time}{end}+$asrOffset+$keyOffset, $H->{Fix}{$time}{cur};
  }  }

  my $cur = 0;

  foreach my $lng (keys %{$H->{Asr}}) {
  # add token 
    my $ext = '';
	my $CharPos = '';
	if($lng eq 'ja' || $lng eq 'zh'){
        if($lng eq $SourceLng) { $ext = "src.$lng";}
        elsif($lng eq $TargetLng) { $ext = "tgt.$lng";}
	}
	foreach my $time (sort {$a <=> $b} keys %{$H->{$lng}}) {
		if($TierFile ne '') {
			printf  FILE "$lng\t%s\t%s\t%s\n", $time+$asrOffset, $H->{$lng}{$time}{end}+$asrOffset, $H->{$lng}{$time}{ano};
		}

# add ASR as Key to Translog hash
		if($time > $AsrUpTime) {
            if($ext ne '') {$JaZh->{$ext}{$time} = $H->{$lng}{$time}{ano};}

			my $t = $time - $keyOffset;

#		my $val = "$H->{$lng}{$time}{ano} ";
			my $val = $H->{$lng}{$time}{ano}; # no blank
            my $dur = $H->{$lng}{$time}{end} - $time; 
			my $s = "<Key Time=\"$t\" Cursor=\"$cur\" Dur=\"$dur\" Type=\"insert\" Value=\"$val\" />\n";
			$T->{$t}{A} .= $s;
#final text
			if($lng eq $TargetLng) { 
				my $L = [split(//, $val)];
				my $keyDur = int($dur / ($#{$L} + 1));
				my $keyTime = $t;
				my $keyCur = $cur;
				for (my $i = 0; $i <= $#{$L}; $i++) {
					$CharPos .= "\t<CharPos Time=\"$keyTime\" Cursor=\"$keyCur\" Value=\"$L->[$i]\" />\n";
					$keyCur++;
					$keyTime += $keyDur;
				}
			}
			$cur += length($val);	
		}	
	}
	if($lng eq $TargetLng) {
		$CharPos .= "  </FinalTextChar>\n"; 
		$T->{$H->{FINCHAR}}{T} .= $CharPos;
	}

  }
  if($TierFile ne '') {close(FILE);}
  
##### write New Translog file
  open(FILE, '>:encoding(utf8)', $Translog) || die ("cannot open file $Translog for writing");
  if($Verbose) {print STDERR "Writing: $Translog\n";}

  foreach my $time (sort {$a <=> $b} keys %{$T}) {
    if($time > $H->{LAST}) {last;}
    if(defined($T->{$time}{T})) {print FILE "$T->{$time}{T}";}
    if(defined($T->{$time}{A})) {print FILE "$T->{$time}{A}";}
  }
  close(FILE);  
}

sub readASR {
  my ($asr, $H) = @_;

#### read ASR file
  open(FILE, '<:encoding(utf8)', $asr) || die ("cannot open file $asr");
  if($Verbose) {print STDERR "Reading: $asr\n";}

  while(defined($_ = <FILE>)) {
    chomp;
	my ($tier, $start, $end, $ano) = split(/\t+/);
	if(!defined($ano) || $ano =~ /^\s*$/) { print STDERR "\treadASR $asr:\tcorrupted line >$_<\n"; next;}
	$ano =~ s/^\s*//;
	$ano =~ s/\s*$//;

	if($ano eq '[Up]' && $AsrUpTime == 0) {$AsrUpTime = $start;}
#take out [annotations in square brackets]
	if($ano =~ /^\[.*\]$/) {next;}
	
# add space between non-japanese/chinese tokens
	if($tier ne 'ja' && $tier ne 'zh') {$ano .= " ";}

#any kind of punctuation
	if($ano =~ s/(\p{Po}\s*)$//) {
      $H->{$tier}{$end - 1}{ano}= $1;
      $H->{$tier}{$end - 1}{end}= $end;
	  $end = $end - 1;
	}
	if($ano ne '') {
		$H->{$tier}{$start}{ano}= $ano;
		$H->{$tier}{$start}{end}= $end;
	}
	$H->{Asr}{$tier} ++;
#print STDERR "tier:$tier\tstart:$H->{$tier}{$start}{ano}\tend:$H->{$tier}{$start}{ano}\n";
#d($H->{$tier}{$start});
  }
  close(FILE);
  return $H,
}


sub readTranslog {
  my ($trlg, $H) = @_;

# Read Translog
  open(FILE, '<:encoding(utf8)', $trlg) || die ("cannot open file $trlg");
  if($Verbose) {printf STDERR "Reading: $trlg\n";}

  my $time = 0;
  my $final =0;
  my $T = {};
  while(defined($_ = <FILE>)) {
	my $dur = 0;
	my $cur = 0;
	my $val = 0;

	if(/<System/ && /Value="STOP"/) {/Time="([0-9]*)"/; $H->{STOP} = $1;}

    if(/Time="([^"]*)"/)  {$time = $1; }
    if(/<Fix/) {
		if(!/Dur/) {next}
		if(/Dur="([^"]*)"/)   {$dur = $1; }
		if(/Cursor="([^"]*)"/){$cur = $1; }
		$H->{Fix}{$time}{cur}= $cur;
		$H->{Fix}{$time}{end}= $time+$dur;
	}
    elsif(/<Key /) {
		if(/Value="([^"]*)"/) {$val = $1; }
		if(/Dur="([^"]*)"/)   {$dur = $1; }
		if($cur == 0 && $val eq '[Up]' && $KeyUpTime == 0) {$KeyUpTime = $time;}
#printf STDERR "WARNING: $time  $val  $dur\tkt:$KeyUpTime\t$_\n";
		$H->{Key}{$time}{val}= $val;
		$H->{Key}{$time}{end}= $time+$dur;
	}
# lang 
    elsif(/<lockWindows>/) {$_ .= "    <Languages source=\"$SourceLng\" target=\"$TargetLng\" system=\"elan\" />\n";}

# insert final chars
    elsif(/<FinalTextChar/)  {
#		my $cur= 0;
		$final = 1;
		$H->{FINCHAR} = $time;
		$T->{$time}{T} .= "  <FinalTextChar>\n";
		$time ++;
		$_ = '';
#		foreach my $lng (keys %{$H->{Asr}}) {
#			foreach my $t (sort {$a <=> $b} keys %{$H->{$lng}}) {
#				if($t > $H->{STOP}) {next;}
#				if($t <= $AsrUpTime) {next;}
#				my $L = [split(//, $H->{$lng}{$t}{ano})];
#				for (my $i = 0; $i <= $#{$L}; $i++) {
#					$_ .= "\t<CharPos Time=\"$t\" Cursor=\"$cur\" Value=\"$L->[$i]\" />\n";
#					$cur++;
#				}
#		}	}
#		$_ .= "  </FinalTextChar>\n"; 
	}
    elsif(/<\/FinalTextChar/)  { $final = 0; next;}
# exclude keystrokes from Translog
    elsif($final && /<CharPos/ )  {next;}
    $T->{$time}{T} .= $_;
  }
  $H->{LAST} = $time;
  close(FILE);
  return $T;
}
