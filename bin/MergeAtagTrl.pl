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
  "  -T in:  Translog XML file <filename1>\n".
  "  -A in:  Alignment file <filename2>.{atag,src,tgt}\n".
  "  -O out: Write output   <filenamex3>\n".
  "Options:\n".
  "  -v verbose mode [0 ... ]\n".
  "  -h this help \n".
  "\n";

use vars qw ($opt_O $opt_T $opt_A $opt_v $opt_h);

use Getopt::Std;
getopts ('T:A:O:G:f:p:v:t:h');

die $usage if defined($opt_h);

my $TRANSLOG = {};
my $STimeHash = {};
my $Verbose = 0;

if (defined($opt_v)) {$Verbose = $opt_v;}

### Read and Tokenize Translog log file
if (defined($opt_T) && defined($opt_A) && defined($opt_O) ) {
  ReadTranslog($opt_T);
  my $A=ReadAtag($opt_A);

  MergeAtag($A);
  PrintTranslog($opt_O, $A);
  exit;
}

printf STDERR "No Output produced\n";
die $usage;

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
  $in =~ s/&#xD;/\r/g;
  $in =~ s/&#x9;/\t/g;
  $in =~ s/&quot;/"/g;
  $in =~ s/&nbsp;/ /g;
  return $in;
}

sub MSescape {
  my ($in) = @_;

  $in =~ s/\>/&gt;/g;
  $in =~ s/\</&lt;/g;
  $in =~ s/"/&quot;/g;
#  $in =~ s/\&/&amp;/g;
#  $in =~ s/\n/&#xA;/g;
#  $in =~ s/\r/&#xD;/g;
#  $in =~ s/\t/&#x9;/g;
#  $in =~ s/ /&nbsp;/g;
  return $in;
}

sub MSescapeAttr {
  my ($in) = @_;

  $in =~ s/\&/&amp;/g;
#  $in =~ s/\>/&gt;/g;
#  $in =~ s/\</&lt;/g;
  $in =~ s/\n/&#xA;/g;
  $in =~ s/\r/&#xD;/g;
  $in =~ s/\t/&#x9;/g;
  $in =~ s/"/&quot;/g;
#  $in =~ s/ /&nbsp;/g;
  return $in;
}



############################################################
# Read src and tgt files
############################################################


sub ReadDTAG {
  my ($fn) = @_;
  my ($D); 

  if(!open(DATA, "<:encoding(utf8)", $fn)) {
    printf STDERR "cannot open: $fn\n";
    exit ;
  }

  if($Verbose) {printf STDERR "ReadDtag: %s\n", $fn;}

  my $n = 1;
  my $H = '';
  while(defined($_ = <DATA>)) {
#printf STDERR "$_\n";
    if($_ =~ /^\s*$/) {next;}
    if($_ =~ /^#/) {next;}
    chomp;

    if(/<Text /) {$H = $_; $H =~ s/<Text//;  $H =~ s/>//;} 
    if(!/<W ([^>]*)>([^<]*)/) {next;} 
    my $x = $1;
    my $s = MSunescape($2);
#printf STDERR "ReadDTAG: $n\t%s\t$_\n", MSescape($s);
    if(/\sid="([^\"])"/i && $1 != $n) {
      printf STDERR "Read $fn: unmatching n:$n and id:$1\t$_\n";
      $n=$1;
    }

#    $s =~ s/([\(\)\\\/])/\\$1/g;
    $D->{$n}{'tok'}=$s;
#printf STDERR "\tvalue:$2\t";
    $x =~ s/\s*([^=]*)\s*=\s*"([^"]*)\s*"/AttrVal($D, $n, $1, $2)/eg;
    if(defined($D->{$n}{id}) && $D->{$n}{id} != $n)  {
      print STDERR "ReadDTAG: $fn: IDs do not match #n:$n\tid:$D->{$n}{id}\n";
    }
    $n++;
  }
  close (DATA);
  return ($H,$D);
}

############################################################
# Read Atag file
############################################################

sub AttrVal {
  my ($D, $n, $attr, $val) = @_;

#printf STDERR "$n:$attr:$val\t";
  $D->{$n}{$attr}=MSunescape($val);
}


sub ReadAtag {
  my ($fn) = @_;
  my ($A, $K, $fn1, $i, $is, $os, $lang, $n); 

  if(!open(ALIGN,  "<:encoding(utf8)", "$fn.atag")) {
    printf STDERR "cannot open for reading: $fn.atag\n";
    exit 1;
  }

  if($Verbose) {printf STDERR "ReadAtag: $fn.atag\n";}

## read alignment file
  $n = 0;
  my $H = '';
  my $segid=0;

  while(defined($_ = <ALIGN>)) {
    if($_ =~ /^\s*$/) {next;}
    if($_ =~ /^#/) {next;}
    chomp;

## read aligned files
    if(/<DTAGalign/) {$A->{H} = $_; $A->{H} =~ s/.*<DTAGalign//;  $A->{H} =~ s/>.*//;} 
    if(/<alignFile/) {
      my $path = $fn;
      if(/href="([^"]*)"/) { $fn1 = $1;}

## read reference file "a"
      if(/key="a"/) { 
        $A->{'a'}{'fn'} =  $fn1;
        if($fn1 =~ /src$/)    { $lang='Source'; $A->{'a'}{'lang'} = 'Source'; $path .= ".src";}
        elsif($fn1 =~ /tgt$/) { $lang='Final'; $A->{'a'}{'lang'} = 'Final'; $path .= ".tgt";}
      }
## read reference file "b"
      elsif(/key="b"/) { 
        $A->{'b'}{'fn'} =  $fn1;
        if($fn1 =~ /src$/) { $lang='Source'; $A->{'b'}{'lang'} = 'Source'; $path .= ".src";}
        elsif($fn1 =~ /tgt$/) { $lang='Final'; $A->{'b'}{'lang'} = 'Final';$path .= ".tgt";}
      }
      else {printf STDERR "Alignment wrong %s\n", $_;}

#      $A->{$lang}{'D'} =  ReadDTAG("$path"); 
      my ($H, $D) =  ReadDTAG("$path"); 
      $A->{$lang}{'D'} =  $D;
      $A->{$lang}{'H'} =  $H;
  
      next;
    }

    if(/<salign /) {
      if(/src="([^"]*)"/) { $A->{'SA'}{$segid}{src} = $1;}
      if(/tgt="([^"]*)"/) { $A->{'SA'}{$segid}{tgt} = $1;}
      $segid++;
    }
    if(/<align /) {
#printf STDERR "ALN: $_\n";
      if(/in="([^"]*)"/) { $is=$1;}
      if(/out="([^"]*)"/){ $os=$1;}

      ## aligned to itself
      if($is eq $os) {next;}
      $is = $os = '---';

      if(/boundary="([^"]*)"/){ $A->{'e'}{$n}{boundary} = $1}
      if(/yawat="([^"]*)"/)   { $A->{'e'}{$n}{yawat} = $1}
      if(/insign="([^"]*)"/)  { $is=$1;}
      if(/outsign="([^"]*)"/) { $os=$1;}

      if(/in="([^"]*)"/) { 
        my $jdtag =  $1;
        $jdtag =~ s/([ab][0-9]*)/$1 /g;
#printf STDERR "IN:  $jdtag\n";
        $K = [split(/\s+/, $jdtag)];
        for($i=0; $i <=$#{$K}; $i++) {
          if($K->[$i] =~ /([ab])(\d+)/) { 
            $A->{'n'}{$n}{$A->{$1}{'lang'}}{'id'}{$2} ++;
            $A->{'n'}{$n}{$A->{$1}{'lang'}}{'s'}=$is;
          }
#printf STDERR "IN:  %s\t$1\t$2\n", $K->[$i];
        }
      }
      if(/out="([^\"]*)"/) { 
        my $jdtag =  $1;
        $jdtag =~ s/([ab][0-9]*)/$1 /g;
        $K = [split(/\s+/, $jdtag)];
        for($i=0; $i <=$#{$K}; $i++) {
          if($K->[$i] =~ /([ab])(\d+)/) { 
            $A->{'n'}{$n}{$A->{$1}{'lang'}}{'id'}{$2} ++;
            $A->{'n'}{$n}{$A->{$1}{'lang'}}{'s'}=$os;
          }
        }
      }
#print STDERR "XXX\n";
#d($A->{'n'}{$n});
      $n++;
    }
  }
  close (ALIGN);
  return ($A);
}


##########################################################
# Read Translog Logfile
##########################################################

## SourceText Positions
sub ReadTranslog {
  my ($fn) = @_;

  open(FILE, '<:encoding(utf8)', $fn) || die ("cannot open for reading $fn");
  if($Verbose){printf STDERR "ReadTranslog: $fn\n";}

  my $n = 0;
  my $IME = 0;
  my $H = {};
  my $type = 0;
  my $FinalTextUTF8 = {};
  my $FinalTextChar = {};
  while(defined($_ = <FILE>)) { 
    if((/<Languages/ && /target="ja"/) ||
       (/<Languages/ && /target="zh"/)){$IME = 1;}
    if(/<Eye /i) {next;}   ## Translog-II
    if(/<Fix / && !/Dur=/) {next;}   ## Translog-II
    if(/<gaze /i) {next;}  ## Casmacat-II
	
    if(/<FinalTextUTF8/) {$type = 1;} 
    if(/<FinalTextUTF8.*\/>/) {$type = 0;}
    if($type == 1) {$FinalTextUTF8->{$n} .= $_; } 
#    if($type == 1) {print STDERR "R\t$_"; } 
    if(/<\/FinalTextUTF8>/) {$type = 0; }

    if(/<\/FinalTextChar>/) {$type = 0; }
    if($type == 2) {$FinalTextChar->{$n} = $_;} 
    if(/<FinalTextChar/) {$type = 2;} 
    if(/<<TargetTextChar.*\/>/) {$type = 0;}
 
# unique timest:wamp for keystrokes
    if($_ =~ /<Key .*Time="([0-9]+)"/) {
      my $t1 = $1;
      my $t2 = $1;
      while(defined($H->{$t2})) {$t2++;}
	  $H->{$t1} = $H->{$t2} = 1;
      if($t1 != $t2) {$_ =~ s/Time="$t1"/Time="$t2"/;}
    }
# timestamp of ST word for interpretation
    if($_ =~ /<CharPos.*Cursor="([0-9]+)".*Time="([0-9]+).*Dur="([0-9]+)"/) {

	  $STimeHash->{$1}{T} = $2;
	  $STimeHash->{$1}{D} = $3;
	}
        $TRANSLOG->{$n} = $_; 
	$n += 5;
  }
  close(FILE);

  MapFinalTextChar($FinalTextChar, $FinalTextUTF8);
  if ($IME) {MapIMEtext()}
  return;
}

sub MapFinalTextChar {
	my ($FinalTextChar, $FinalTextUTF8) = @_;
	
	my $utf8 = '';
	my $chars = '';
	my $n = 0;
	my $Index = 0;

	if(defined($FinalTextUTF8)) {
		foreach $n (sort {$a<=>$b} keys %{$FinalTextUTF8}) {
			$utf8 .= MSescapeAttr($FinalTextUTF8->{$n});
			$Index = $n;
		}
#print STDERR "FinalTextUTF82:$n -- $Index\n$utf8\n";
	}
	
	chomp($utf8);
	$utf8 =~ s/&#xD;&#xA;/&#xA;/g;
	$utf8 =~ s/.*<FinalTextUTF8>//;
	$utf8 =~ s/<\/FinalTextUTF8>.*//;
	$utf8 = MSunescape($utf8);

	$chars = '';
	foreach my $i (sort {$a<=>$b} keys %{$FinalTextChar}) {
		my ($c) = $FinalTextChar->{$i} =~ /<CharPos .* Value="([^"]*)"/;
#if(!defined($c)) {
#print STDERR "MapFinalTextChar:$i\n\t>$chars<\n\t>$FinalTextChar->{$i}<\n";}
		if(defined($c)) {$chars .= MSunescape("$c");}
	}

	if(defined($FinalTextUTF8)) {
		foreach $n (sort {$a<=>$b} keys %{$FinalTextUTF8}) {
			delete($TRANSLOG->{$n});
		}
	}

	if($Index > 0) { 
		$Index = (sort {$a<=>$b} keys %{$FinalTextUTF8})[0];
	}
	else {
		$Index = (sort {$a<=>$b} keys %{$FinalTextChar})[0]-8;
	}
		
#print STDERR "Not equal: $n\n\tFinalTextUTF8:\n>$utf8<\n\tFinalTextChar:\n>$chars<\n";		
#print STDERR "Not equal2: $n\n";		
	$TRANSLOG->{$Index} = "<FinalTextUTF8>$chars<\/FinalTextUTF8>\n"; 
	#	$TRANSLOG->{$Index} = "<FinalTextUTF8><\/FinalTextUTF8>\n"; 
}

sub MapIMEtext {

   my $val = '';
   my $ime = '';
   my $endTime = 0;
   my $startTime = 0;
   my $numKeys = 0;
   my $cur = 0;
   my $del = '';
   my $ind = 0;
   my $N = '';
   my $H = undef;
   
   foreach my $n (sort {$b<=>$a} keys %{$TRANSLOG}) {
     # skip non-keystrokes
     if (!($TRANSLOG->{$n} =~ /<Key /)) { next; }

# new insertion

     #    print STDERR "AAA0: $n\t $TRANSLOG->{$n}";
     # IME is complete entry  
     if ($endTime > 0 && !($TRANSLOG->{$n} =~ /Type="IME"/)) {
        my $dur = $endTime - $startTime;
       	$N =~ s/Type="insert"/Type="IMEinsert"/;
        $N =~ s/\/>/Strokes=\"$numKeys\" Dur=\"$dur\" \/>/;
	$TRANSLOG->{$n+1} = $N;
#print STDERR "AAA0: $n/$ind\t$TRANSLOG->{$n+1}\n";
        $endTime = 0;
    }

    # IME collect IME keystrokes
    if($TRANSLOG->{$n} =~ /IMEtext=/ && $TRANSLOG->{$n} =~ /Type="insert"/) {
	  if($ime ne '' && $ime ne 'Space') {
#print STDERR "UNMATCHED IMEtext $n\t >$ime<\t$TRANSLOG->{$n}";
        	my $dur = $endTime - $startTime;
       		$N =~ s/Type="insert"/Type="IMEinsert"/;
        	$N =~ s/\/>/Strokes=\"$numKeys\" Dur=\"$dur\" \/>/;
		$TRANSLOG->{$n+1} = $N;
#print STDERR "UNMATCHED IMEtext $n/$ind\t$TRANSLOG->{$n+1}";
	  }
      ($endTime) = $TRANSLOG->{$n} =~ /Time="(\d*)"/;
      $numKeys = 0;
      $ind = $n;
      $N = $TRANSLOG->{$n};
      $TRANSLOG->{$n} =~ s/Type="insert"/Type="IME"/;

      ($ime) = $TRANSLOG->{$n} =~ /IMEtext="(.*?)"/; 
# printf STDERR "AAA1: $n\t$TRANSLOG->{$n}";
      
      if($TRANSLOG->{$n} =~ /Text=/) {($del) = $TRANSLOG->{$n} =~ /Text="(.*?)"/;}
	  else {$del = '';}
    }
# new keystroke
    elsif($TRANSLOG->{$n} =~ /Type="IME"/ && $ime ne '') {
       my ($v) = $TRANSLOG->{$n} =~ /Value="\[(.*)\]"/;
	   $ime =~ s/(.*)$v/$1/;
	   $TRANSLOG->{$n} =~ s/Value=/IMEtext=\"[$v]\" Value=/;
#print STDERR "AAA2: $n\time:$ime v:$v $TRANSLOG->{$n}";
       $numKeys += 1;
       ($startTime) = $TRANSLOG->{$n} =~ /Time="(\d*)"/;
    }
    else {
#      print STDERR "AAA3: $n\t$TRANSLOG->{$n}";
    }

  }
  if ($endTime > 0) {
     my $dur = $endTime - $startTime;
     $N =~ s/Type="insert"/Type="IMEinsert"/;
     $N =~ s/\/>/Strokes=\"$numKeys\" Dur=\"$dur\" \/>/;
     $TRANSLOG->{$ind} = $N;
# print STDERR "AAA4: $ind\t$TRANSLOG->{$ind}\n";
    }
#  DistributeKeys($H, $val, $cur, $del);
}

sub DistributeKeys {
    my ($H, $val, $cur, $del) = @_;
		
	my $step = 1;
	if(length($val) > 1) {$step = int(int(keys %{$H}) / (length($val)-1));}
    if($step == 0) {$step = 1;}
#	printf STDERR "AAA4: $k step:$step cur:$cur $s $h del:$del val:%d:$val keys:%d\n", length($val), int(keys %{$H});

    my $K = [split(//, $val)];
    my $s=0;
	my $k = 0;
	my $N = '';

    my $l = 0;
    foreach my $h (sort {$a<=>$b} keys %{$H}) {
#printf STDERR "AAA4: $k step:$step cur:$cur $s $h del:$del val:%d:$val keys:%d\n", length($val), int(keys %{$H});
#d($H);
        if($k % $step == 0 && defined($K->[$s+1])) {
		    $N = $H->{$h};
#print STDERR "AAA5: $k $cur $step $K->[$s]\n";
			if($del ne '') {$N =~ s/Type=/Text="$del" Type=/; $del = '';}
			$N =~ s/Type="IME"/Type="insert"/;
			$N =~ s/Value=".*?"/Value="$K->[$s]"/;
			$N =~ s/Cursor="\d*?"/Cursor="$cur"/;
			$TRANSLOG->{$h+1} = $N;
#print STDERR "XXX7: $k $step cur:$cur $K->[$s] $TRANSLOG->{$h+1}";
			$s++;
			$cur++;
        }
		$k++;
		$l=$h;
    }
    if(defined($K->[$s])) {
	    $N = $H->{$l};
#print STDERR "AAA5: $k $cur $step $K->[$s]\n";
 		if($del ne '') {$N =~ s/Type=/Text="$del" Type=/; $del = '';}
		$N =~ s/Type="IME"/Type="insert"/;
		$N =~ s/Value=".*?"/Value="$K->[$s]"/;
		$N =~ s/Cursor="\d*?"/Cursor="$cur"/;
		$TRANSLOG->{$l+1} = $N;
#print STDERR "AAA8: $k $cur $step $K->[$s] $TRANSLOG->{$l+1}\n";
	    $s++;
    }
    if(defined($K->[$s])) {print STDERR "incomplete decompose $s:$K->[$s] from $#{$K}\n"};
}

##########################################################
# Parse Keystroke Log
##########################################################

sub MergeAtag {
  my ($A) = @_;

  my @L = qw(Final Source);
  foreach my $n (sort {$a<=>$b} keys %{$A->{'n'}}) {
    foreach my $l (@L) {
      foreach my $id (sort {$a<=>$b} keys %{$A->{'n'}{$n}{$l}{'id'}}) {
        if(!defined($A->{$l}{'D'}{$id})) {
          print STDERR "MergeAtag: Undefined $l: ID:$id\n";
          next;
        }
        $A->{'n'}{$n}{$l}{'id'}{$id} = $A->{$l}{'D'}{$id}{'cur'};
      }
      foreach my $id (keys %{$A->{$l}{D}}) {
        if(!defined($A->{n}{$n}{$l}{id})) { print STDERR "MergeAtag: Undefined token: $l: ID:$id\n";}
      }
    }
  }
}

sub PrintTranslog{
  my ($fn, $A) = @_;
  my $m;

  foreach my $i (sort {$b<=>$a} keys %{$TRANSLOG}) { if($TRANSLOG->{$i} =~ /<\/logfile>/i) {$m=$i;last; }}

  my @L = qw(Source Final);
  foreach my $l (@L) {
    $TRANSLOG->{$m++} ="  <$l"."Token$A->{$l}{H}>\n";
    foreach my $id (sort {$a<=>$b} keys %{$A->{$l}{'D'}}) {

      my $s = "    <Token ";
      foreach my $attr (sort keys %{$A->{$l}{D}{$id}}) { 
         my $MS =  MSescapeAttr($A->{$l}{D}{$id}{$attr});
         $s .= " $attr=\"$MS\"";
# add timestamp for ST word interpretation
		 if(defined($STimeHash) && $attr eq 'cur') {
           if(defined($STimeHash->{$MS})) { $s .= " time=\"$STimeHash->{$MS}{T}\" dur=\"$STimeHash->{$MS}{D}\"";}
#print STDERR "STimeHash2: $attr\t$MS\t$STimeHash->{$MS}\t$s\n";		   
		 }
      }
      $s .= " />\n";

      $TRANSLOG->{$m++} = $s;
    }
    $TRANSLOG->{$m++} ="  </$l"."Token>\n";
  }

  $TRANSLOG->{$m++} = "  <Alignment$A->{'H'}>\n";
  foreach my $n (sort {$a<=>$b} keys %{$A->{'n'}}) {
    my $S = {};
    foreach my $l (@L) {
      my $k=0;
      foreach my $id (sort {$a<=>$b} keys %{$A->{'n'}{$n}{$l}{'id'}}) {
#        my $s = MSescape($A->{'n'}{$n}{$l}{'s'});
        if($l eq "Source") {$S->{$l}{$k} = "sid=\"$id\" ";}
        if($l eq "Final")  {$S->{$l}{$k} = "tid=\"$id\" ";}
        if(defined($A->{'e'}{$n})) {$S->{e}{$k} = $A->{'e'}{$n}}
        $k++;
      }
    }
    foreach my $n (sort {$a<=>$b}keys %{$S->{'Source'}}) {
      foreach my $k (sort {$a<=>$b}keys %{$S->{'Final'}}) {
#print STDERR "<align $S->{'Source'}{$n} $S->{'Final'}{$k} />\n";
        my $s = "    <Align $S->{'Source'}{$n} $S->{'Final'}{$k}";
        foreach my $x (sort keys %{$S->{e}{$n}}) {$s .= " $x=\"$S->{e}{$n}{$x}\""}
        $s .= " />\n";
        $TRANSLOG->{$m++} = $s;
      }
    }
  }
  $TRANSLOG->{$m++} ="  </Alignment>\n";
  $TRANSLOG->{$m++} ="  <Salignment>\n";
  foreach my $n (sort {$a<=>$b} keys %{$A->{SA}}) {
    $TRANSLOG->{$m++} = "    <Salign src=\"$A->{SA}{$n}{src}\" tgt=\"$A->{SA}{$n}{tgt}\" />\n";
  }
  $TRANSLOG->{$m++} ="  </Salignment>\n";

  $TRANSLOG->{$m++} ="</LogFile>\n";

  open(FILE, '>:encoding(utf8)', $fn) || die ("cannot open for writing $fn");

  foreach my $k (sort {$a<=>$b} keys %{$TRANSLOG}) { print FILE "$TRANSLOG->{$k}"; }
  close(FILE);
}
