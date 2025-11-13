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
  "yawat-> atag:  options -A <atag> -Y <yawat> -O <atag>.{atag,srg,tgt}\n".
  "atag -> yawat: options -A <atag> -O <yawat>.{aln,crp} \n".
  "Options:\n".
  "  -A atag file root \n".
  "  -Y yawat file  \n".
  "  -O output file root \n".
  "  -M entropy from yawat (Moritz format)\n".
  "  -v verbose mode [0 ... ]\n".
  "  -h this help \n".
  "\n";

use vars qw ($opt_A $opt_Y $opt_O $opt_M $opt_v $opt_h);

use Getopt::Std;
getopts ('A:Y:M:O:v:h');

my $Verbose = 0;

if (defined($opt_M)) {
    ReadYawatMoritz($opt_M);
    exit;
}

die $usage if !defined($opt_O);

die $usage if defined($opt_h);

if (defined($opt_v)) {$Verbose = $opt_v;}

## Yawat -> Atag
if (defined($opt_Y)) {
    my $A=ReadAtag($opt_A);
    my $Y=ReadYawat($opt_Y, $A);
    PrintAtag($opt_O, $A, $Y);
	PrintTok($opt_O, $A, "src");
	PrintTok($opt_O, $A, "tgt");
    exit;
}

## Atag -> Yawat
elsif (defined($opt_A)) {
    my $A=ReadAtag($opt_A);
    PrintYawat($opt_O, $A);
    exit;
}


exit;


sub ReadYawat {
  my ($fn, $A) = @_;
 
  if(!open(CRP, "<:encoding(utf8)", "$fn.crp")) {
    printf STDERR "ReadYawat: cannot open: $fn.crp\n";
    return undef;
  }
   
  my $line = 1;
  my $CRF = {};
  my $seg = 0;
  my $s;
  while(defined($_ = <CRP>)) {
#printf STDERR "ReadYawat0:$_";
    if($_ =~ /^\s*$/) { printf STDERR "ReadYawat: $fn.crp Empty line:$line\n"; } 
    if($line == 1) { $seg = int($_)}
    elsif($line == 2) { $s = $_}
    else {
       $CRF->{$seg}{src} = $s;
       $CRF->{$seg}{tgt} = $_;
       my $src = [split(/\s+/, $CRF->{$seg}{src})];
       my $tgt = [split(/\s+/, $CRF->{$seg}{tgt})];
       $CRF->{$seg}{stok} = $#{$src} + 1;
       $CRF->{$seg}{ttok} = $#{$tgt} + 1;
#printf STDERR "ReadYawat0:\t$seg\n$CRF->{$seg}{src}\n$CRF->{$seg}{tgt}\n$CRF->{$seg}{stok}\t$CRF->{$seg}{ttok}\n";
       for (my $i = 0; $i <= $#{$src}; $i++) {$CRF->{$seg}{tokS}{$i} = $src->[$i];}
       for (my $i = 0; $i <= $#{$tgt}; $i++) {$CRF->{$seg}{tokT}{$i} = $tgt->[$i];}


       $line = 0
    }
    $line ++;
  }
  close(CRP);
  
  if(!open(ALN, "<:encoding(utf8)", "$fn.aln")) {
    printf STDERR "ReadYawat: cannot open: $fn.aln\n";
    return undef;
  }
   
  if($Verbose) {printf STDERR "ReadYawat: %s\n", $fn;}

  my $sid = $A->{src}{lang};
  my $tid = $A->{tgt}{lang};
  my $X = {};
  my $srcTok = 1;
  my $tgtTok = 1;
  while(defined($_ = <ALN>)) {
#printf STDERR "ReadYawat1:\t$_\n";
    if($_ =~ /^\s*$/) { next;} 
    my $L = [split(/\s+/)];
    for (my $l = 0; $l <= $#{$L}; $l++) {
        if($L->[$l] !~ /:/) {
          $seg = $L->[$l];
#print STDERR "ReadYawat2 $seg\t$CRF->{$seg}{src}$CRF->{$seg}{tgt}\n$_";
          next;
        }
        my ($S, $T, $D) = split(/:/, $L->[$l]);
        my $src = [split(/,/, $S)];
        my $tgt = [split(/,/, $T)];

# YAWAT annotation to src and tgt files
#printf STDERR "ReadYawat3:\ttgt:>$T<\tsrc:>$S< ano:$D\n";
        for (my $s = 0; $s <= $#{$src}; $s++) { 
if($A->{$sid}{D}{$src->[$s]+$srcTok}{tok} ne $CRF->{$seg}{tokS}{$src->[$s]}) {
		printf STDERR "ReadYawatS:$fn\tSeg:$seg Atag id:%d:$A->{$sid}{D}{$src->[$s]+$srcTok}{tok}\tYawat id:$src->[$s]+$srcTok:$CRF->{$seg}{tokS}{$src->[$s]}\n", $src->[$s]+$srcTok;
}
		  if(defined($A->{$sid}{D}{$src->[$s]+$srcTok})) {
  		    if($D ne 'unspec'){
              $A->{$sid}{D}{$src->[$s]+$srcTok}{str} =~ s/ segId=/ yawat=\"$D\" segId=/;
#printf STDERR "ReadYawatS:$A->{$sid}{D}{$src->[$s]+$srcTok}{str}\n";
		  } }
		}
        for (my $t = 0; $t <= $#{$tgt}; $t++) { 
if($A->{$tid}{D}{$tgt->[$t]+$tgtTok}{tok} ne $CRF->{$seg}{tokT}{$tgt->[$t]}) {
		printf STDERR "ReadYawatT:$fn\tSeg:$seg Atag id:%d:$A->{$tid}{D}{$tgt->[$t]+$tgtTok}{tok}\tYawat id:$tgt->[$t]+$tgtTok:$CRF->{$seg}{tokT}{$tgt->[$t]}\n", $tgt->[$t]+$tgtTok;
}
		  if(defined($A->{$tid}{D}{$tgt->[$t]+$tgtTok})) {
		    if($D ne 'unspec'){
              $A->{$tid}{D}{$tgt->[$t]+$tgtTok}{str} =~ s/ segId=/ yawat=\"$D\" segId=/;
#printf STDERR "ReadYawatT:$A->{$tid}{D}{$tgt->[$t]+$tgtTok}{str}\n";
		  } }
		}
        for (my $s = 0; $s <= $#{$src}; $s++) {
          for (my $t = 0; $t <= $#{$tgt}; $t++) {
#printf STDERR "ReadYawat4:\ttgt:%s\tsrc:%s ano:%s\n", $tgt->[$t]+$tgtTok, $src->[$s]+$srcTok, $D;
             $X->{$tgt->[$t]+$tgtTok}{$src->[$s]+$srcTok} = $D;
        } }
#    my $lngA = $A->{'a'}{'lang'};
#    my $lngB = $A->{'b'}{'lang'};
#
#if($A->{'a'}{'lang'} eq "src") {
#print STDERR "SRC: src:$A->{a}{'D'}{$srcTok}{tok}\ttgt:$A->{b}{'D'}{$tgtTok}{tok}\n";}
#else {print STDERR "TGT: src:$A->{b}{'D'}{$srcTok}{tok}\ttgt:$A->{a}{'D'}{$tgtTok}{tok}\n";
#}

    }
    $srcTok += $CRF->{$seg}{stok};
    $tgtTok += $CRF->{$seg}{ttok};
	

  }
  close (ALN);
  
  
  my $H = {};
  my $n=0;
  foreach my $tgt (sort {$a<=>$b} keys %{$X}) {
    foreach my $src (sort {$a<=>$b} keys %{$X->{$tgt}}) {
      $H->{$n++} = "<align in=\"$tid$tgt\" out=\"$sid$src\" />\n";
  } }

  return $H;
}


sub ReadYawatMoritz {
  my ($fn) = @_;
 
  if(!open(CRP, "<:encoding(utf8)", "$fn.crp")) {
    print STDERR "ReadYawat: cannot open: $fn.crp\n";
    return;
  }

  my $line = 1;
  my $CRF = {};
  my $seg = 0;
  my $s = ''; 
  my $ls = '';
  my $Alignments = 0;
  while(defined($_ = <CRP>)) {
    chomp;

    if($_ =~ /^\s*$/) { printf STDERR "$fn WARNING ReadYawat: Empty line\n"; } 
    if($line == 1) { $seg = $_}
    elsif($line == 2) { $s = $_}
    else {
       if($ls ne '' && $ls ne $s) {printf STDERR "source different $ls, $s\n";}
	   $ls = $s;
       $CRF->{$seg}{stok} = [split(/\s+/, $s)];
       $CRF->{$seg}{ttok} = [split(/\s+/, $_)];
       $line = 0;
	   $Alignments ++;
    }
    $line ++;
  }
  close(CRP);
  
  if(!open(ALN, "<:encoding(utf8)", "$fn.aln")) {
    printf STDERR "ReadYawat: cannot open: $fn.aln\n";
    return;
  }
   
  if($Verbose) {print STDERR "ReadYawat: $fn.aln\n";}

  my $ALN = {};
  while(defined($_ = <ALN>)) {
#printf STDERR "ReadYawat1:\t$_\n";
    if($_ =~ /^\s*$/) { next;} 
    my $L = [split(/\s+/)];

    for (my $l = 0; $l <= $#{$L}; $l++) {
        if($L->[$l] !~ /:/) {
          $seg = $L->[$l];
		  if(!defined($CRF->{$seg})) {printf STDERR "ReadYawat2:\t undefined seg: $seg\n";}
          next;
        }
        my ($S, $T, $D) = split(/:/, $L->[$l]);
        my $src = [split(/,/, $S)];
        my $tgt = [split(/,/, $T)];

        for (my $s = 0; $s <= $#{$src}; $s++) {
          if(!defined($ALN->{$src->[$s]}{str})) {
            $ALN->{$src->[$s]}{str} = $CRF->{$seg}{stok}[$src->[$s]];
          }
          elsif ($ALN->{$src->[$s]}{str} ne $CRF->{$seg}{stok}[$src->[$s]]) {
            print STDERR "WARNING: position $s:$src->[$s]:$ALN->{$src->[$s]}{str} in $seg different source word $CRF->{$seg}{stok}[$src->[$s]]\n";
          }
		  
		  my $ts = '';
		  # append n target alignments
          for (my $t = 0; $t <= $#{$tgt}; $t++) { if($ts ne '') {$ts .= '_';} $ts .= $CRF->{$seg}{ttok}[$tgt->[$t]];}
          $ALN->{$src->[$s]}{tgt}{$ts}{seg}{$seg} ++;
        }
    }
  }
  close (ALN);

#----------------------------------------
## compute Entropy
  foreach my $src (keys %{$ALN}) {
    foreach my $tgt (keys %{$ALN->{$src}{tgt}}) {
      foreach my $seg (keys %{$ALN->{$src}{tgt}{$tgt}{seg}}) {
	    $ALN->{$src}{nbr} ++;
	    $ALN->{$src}{tgt}{$tgt}{nbr} ++;
  } } }

  foreach my $src (keys %{$ALN}) {
    foreach my $tgt (keys %{$ALN->{$src}{tgt}}) {
      my $p = $ALN->{$src}{tgt}{$tgt}{nbr} / $ALN->{$src}{nbr};
      $ALN->{$src}{tgt}{$tgt}{p} = $p;
      $ALN->{$src}{h} += $p * log($p)/log(2);
    }
#    $ALN->{$src}{h} /= $Alignments; 
  }

## print out
  $s = '';
  foreach my $src (sort {$a<=>$b} keys %{$ALN}) {
    $s = sprintf ("%d\t\"%s\"\t%d\t%2.4f\t", $src, $ALN->{$src}{str}, $ALN->{$src}{nbr}, $ALN->{$src}{h});
    foreach my $tgt (sort {$ALN->{$src}{tgt}{$b}{nbr} <=> $ALN->{$src}{tgt}{$a}{nbr}} keys %{$ALN->{$src}{tgt}}) {
      $s .= sprintf ("\"%s\":%d:%2.4f\t",$tgt,$ALN->{$src}{tgt}{$tgt}{nbr},$ALN->{$src}{tgt}{$tgt}{p});
    }
	print STDOUT "$s\n";
  }
}


###########################################################
# Read src and tgt files
############################################################


sub ReadToken {
  my ($fn) = @_;
  my ($D); 

  if(!open(DATA, "<:encoding(utf8)", $fn)) {
    printf STDERR "ReadDTAG: cannot open: $fn\n";
    return undef;
  }

  if($Verbose) {printf STDERR "ReadDtag: %s\n", $fn;}

  my $id = 'null';
  my $line = '';
  while(defined($_ = <DATA>)) {
    my $seg = 0;
    my $tok = '';
	my $ywt = '';

    if(!/<W ([^>]*)>([^<]*)/) {$line .= $_; next;}
    if(/segId="([^"]*)"/) { $seg=$1}
    if(/yawat="([^"]*)"/) { $ywt=$1}
#    if(/yawat="([^"]*)"/) {printf STDERR "ReadDtag: $fn yawat:$ywt\n";}
    if(/\sid="([^"]*)"/) { $id=$1}
    if(/>([^<]*)</) { $tok=$1}
    if($id eq 'null') {next;}
    s/( yawat="[^"]*")//;

    if($seg == 0) {printf STDERR "ReadDtag: $fn\t$id seg:zero $tok\n"; next;}
	if($line ne '') {$D->{$id}{header} =$line}
	if($ywt ne '') {$D->{$id}{yawat} =$ywt}
    $D->{$id}{str}=$_;
    $D->{$id}{seg}=$seg;
    $D->{$id}{tok}=$tok;
    $line = '';
#printf STDERR "ReadDtag: $fn seg:$seg id:$id $tok\n";
#d($D->{$id}{tok});

  }
  if($line ne '') {$D->{$id}{footer} =$line}
  close (DATA);
  return $D;
}


############################################################
# Read Atag filtgte
############################################################

sub ReadAtag {
  my ($fn) = @_;
  my ($A, $fn1); 

  if(!open(ALIGN,  "<:encoding(utf8)", "$fn.atag")) {
    printf STDERR "ReadAtag: $fn.atag\tcannot open for reading\n";
    exit 1;
  }

  if($Verbose) {printf STDERR "ReadAtag: $fn.atag\n";}

  my $salign = 0;
  my $talign = 0;
  my $atag = 0;
  my $lnk = 0;
  my $H = {};

  ## read alignment file
  while(defined($_ = <ALIGN>)) {
    $A->{atag}{$atag++} = $_;
  
    if($_ =~ /^\s*$/) {next;}
    if($_ =~ /^#/) {next;}
    chomp;

#printf STDERR "Alignment %s\n", $_;
## read aligned files
    if(/<alignFile/) {

      my $path = $fn;
      if(/href="([^"]*)"/) { $fn1 = $1;}

## read reference file "a"
      if(/key="a"/) { 
        if($fn1 =~ /src$/)    { $A->{'a'}{'lang'} = 'src'; $path .= ".src";}
        elsif($fn1 =~ /tgt$/) { $A->{'a'}{'lang'} = 'tgt';  $path .= ".tgt";}
        $A->{$A->{'a'}{'lang'}}{lang} = 'a';
        $A->{a}{'fn'} =  $path;
        $A->{a}{'D'} =  ReadToken($path); 
      }
## read reference file "b"
      elsif(/key="b"/) { 
        if($fn1 =~ /src$/)    { $A->{'b'}{'lang'} = 'src'; $path .= ".src";}
        elsif($fn1 =~ /tgt$/) { $A->{'b'}{'lang'} = 'tgt';  $path .= ".tgt";}
        $A->{$A->{'b'}{'lang'}}{lang} = 'b';
        $A->{b}{'fn'} =  $path;
        $A->{b}{'D'} =  ReadToken($path); 
      }
      else {printf STDERR "Alignment wrong %s\n", $_;}
      next;
    }
  
    if(/<salign /) {
      my $sseg = 0;
      my $tseg = 0;
      if(/src="([^"]*)"/) { $sseg = $1;}
      if(/tgt="([^"]*)"/) { $tseg = $1;}
      if(defined($H->{tgt}{$tseg})) { $salign = $H->{tgt}{$tseg};}
      elsif(defined($H->{src}{$sseg})) { $salign = $H->{src}{$sseg};}
      else {$salign = $H->{max} = $sseg;};

      $A->{SEG}{$salign}{src}{$sseg} ++;
      $A->{SEG}{$salign}{tgt}{$tseg} ++;
      $H->{src}{$sseg} = $salign; 
      $H->{tgt}{$tseg} = $salign;
#print STDERR "HHHH: aln:$salign src:$sseg tgt:$tseg\n";
#d($A->{aln}{$salign});
    }

    if(/<align /) {
	  my ($is, $os, $yawat);
#      if(/yawat="([^"]*)"/){ $yawat=$1;}
#	  else {$yawat = 'unspec';}
      if(/in="([^"]*)"/) { $is=$1;}
      if(/out="([^"]*)"/){ $os=$1;}

      ## aligned to itself
      if($is eq $os) {next;}

      my $seg = 0;
	  $is = 'b';
	  $os = 'a';
	  $lnk ++;
      if(/in="([^"]*)"/) {
## comming from jdtag it has no blanks e.g a10a12a13
        my $aln = $1;
        $aln =~ s/([ab])/ $1/g;

        my $K = [split(/\s+/, $aln)];
        for(my $i=0; $i <=$#{$K}; $i++) {
          if($K->[$i] =~ /([ab])(\d+)/) {
            $seg = 1;
			if($1 ne $is) {print STDERR "in Changing from $is to $1\n"; $is = $1;}
            if(!defined($A->{$is}{'D'}{$2})) {
              print STDERR "ReadAtag: $A->{$1}{'fn'}\tundefined id:$2 in atag $aln\n";
			  next;
            } 
            else {$seg = $A->{$is}{'D'}{$2}{seg};}
			
            $H->{$A->{$is}{lang}}{lnk}{$lnk}{id}{$2} = $A->{$1}{'D'}{$2};
            $H->{$A->{$is}{lang}}{id}{$2}{lnk}{$lnk} ++;
            $H->{$A->{$is}{lang}}{id}{$2}{tok} = $A->{$1}{'D'}{$2};
            $H->{$A->{$is}{lang}}{id}{$2}{seg} = $seg;
			
			$A->{$1}{'D'}{$2}{lnk} = $lnk;
			
          }
        }
#printf STDERR "IN:  $seg $talign\t$aln\n";
#d($A->{A}{$seg}{$talign});
      }

      if(/out="([^"]*)"/) {
        my $aln = $1;
        $aln =~ s/([ab])/ $1/g;

        my $K = [split(/\s+/, $aln)];
        for(my $i=0; $i <=$#{$K}; $i++) {
          if($K->[$i] =~ /([ab])(\d+)/) {
            $seg = 1;
			$os = $1;
            if(!defined($A->{$1}{'D'}{$2})) {
              print STDERR "ReadAtag: $A->{$1}{'fn'}\tundefined id:$2 in atag $aln\n";
			  next;
            }
            else {$seg = $A->{$os}{'D'}{$2}{seg};}
			
            $H->{$A->{$os}{lang}}{lnk}{$lnk}{id}{$2} = $A->{$1}{'D'}{$2};
            $H->{$A->{$os}{lang}}{id}{$2}{lnk}{$lnk} ++;
            $H->{$A->{$os}{lang}}{id}{$2}{tok} = $A->{$1}{'D'}{$2};
            $H->{$A->{$os}{lang}}{id}{$2}{seg} = $seg;

			$A->{$1}{'D'}{$2}{lnk} = $lnk;
      
#printf STDERR "AAA: $seg $2 $A->{$1}{'D'}{$2}{tok}\n";
          }
        }
      }	  
    }
    $talign++;
  }
  close (ALIGN);

  my $lngA = $A->{'a'}{'lang'};
  my $lngB = $A->{'b'}{'lang'};

### Check  data structure
  if(!defined($H->{max})) {
     foreach my $seg (keys %{$H->{src}}) { $A->{SEG}{0}{src}{$seg} ++;}
     foreach my $seg (keys %{$H->{tgt}}) { $A->{SEG}{0}{tgt}{$seg} ++;}
  }

## Alignment 
  my $au = 0;
  foreach my $ida (sort {$a<=>$b}keys %{$H->{$lngA}{id}}) {
    if(defined($H->{$lngA}{id}{$ida}{visited})) {next;}
    $H->{$lngA}{id}{$ida}{visited} = 1;
    $au ++;
    $H->{au}{$au}{$lngA}{id}{$ida} = $H->{$lngA}{id}{$ida}{tok};
    $H->{au}{$au}{$lngA}{seg} = $H->{$lngA}{id}{$ida}{seg};
#printf STDERR "AAA1:$lngA au:$au id:$ida\n";
#d($H->{au}{$au}{$lngA}{id}{$ida});

    foreach my $lnk (keys %{$H->{$lngA}{id}{$ida}{lnk}}) {
      if(defined($H->{$lngB}{lnk}{$lnk}{visited})) {next;}
      $H->{$lngB}{lnk}{$lnk}{visited} = 1;
      foreach my $idb (keys %{$H->{$lngB}{lnk}{$lnk}{id}}) {
        $H->{au}{$au}{$lngB}{id}{$idb} = $H->{$lngB}{id}{$idb}{tok};
        $H->{au}{$au}{$lngB}{seg} = $H->{$lngB}{id}{$idb}{seg};
#printf STDERR "AAA2:$lngB au:$au id:$idb\n";
        foreach my $lnb (keys %{$H->{$lngB}{id}{$idb}{lnk}}) {
          foreach my $idaa (keys %{$H->{$lngA}{lnk}{$lnb}{id}}) {
            if(defined($H->{$lngA}{id}{$idaa}{visited})) {next;}
            $H->{$lngA}{id}{$idaa}{visited} = 1;
            $H->{au}{$au}{$lngA}{id}{$idaa} = $H->{$lngA}{id}{$idaa}{tok};
            $H->{au}{$au}{$lngA}{seg} = $H->{$lngA}{id}{$idaa}{seg};
#printf STDERR "AAA3:$lngA au:$au id:$idaa\n";
      } } }
    }
  }
  
  #add AUs
  foreach my $au (sort {$a<=>$b} keys %{$H->{au}}) {
    my $align = $H->{src}{$H->{au}{$au}{src}{seg}};
    $A->{SEG}{$align}{au}{$au} = $H->{au}{$au};
#if($H->{au}{$au}{tgt}{id} == 39) {
#printf STDERR "AAA1:au:$au\n";
#d($H->{au}{$au});
#}
  }
  
### check word alignment
  foreach my $id (sort {$a<=>$b} keys %{$A->{a}{'D'}}) { 
    my $seg=$A->{a}{'D'}{$id}{seg}; 
	if(!defined($A->{a}{'D'}{$id}{lnk})) {
	  $au++;
      my $align = $H->{$lngA}{$seg};
	  $A->{SEG}{$align}{au}{$au}{$lngA}{id}{$id} = $A->{a}{'D'}{$id};
	}
    if(!defined($H->{$lngA}{$seg})) { 
      printf STDERR "Unaligned word a$id \"$A->{a}{'D'}{$id}{tok}\" in source segment a:$seg of $fn.atag\n\n";
    } 
  }
  foreach my $id (sort {$a<=>$b} keys %{$A->{b}{'D'}}) { 
    my $seg=$A->{b}{'D'}{$id}{seg}; 
	if(!defined($A->{b}{'D'}{$id}{lnk})) {
	  $au++;
      my $align = $H->{$lngB}{$seg};
	  $A->{SEG}{$align}{au}{$au}{$lngB}{id}{$id} = $A->{b}{'D'}{$id};
	}
    if(!defined($H->{$lngB}{$seg})) { 
    } 
  }
  return ($A);
}


sub PrintYawat {
  my ($fn, $A) = @_;

  open(ALN, '>:encoding(utf8)', "$fn.aln") || die ("cannot open file $fn.aln");
  open(CRP, '>:encoding(utf8)', "$fn.crp") || die ("cannot open file $fn.crp");

  my $srcToken = 1;
  my $tgtToken = 1;
  my $sid = $A->{src}{lang};
  my $tid = $A->{tgt}{lang};
  
  foreach my $aln (sort {$a<=>$b} keys %{$A->{SEG}}) {
    print ALN "$aln ";
    print CRP "$aln\n";

    my $tgtNextToken = 0;
    my $srcNextToken = 0;

# Print CRP file source segment
    foreach my $seg (sort {$a<=>$b} keys %{$A->{SEG}{$aln}{src}}) { 
# print STDERR "BBB $seg\n";
      foreach my $id (sort {$a<=>$b} keys %{$A->{$sid}{'D'}}) {
        if($A->{$sid}{'D'}{$id}{seg} == $seg) { 
          print CRP "$A->{$sid}{'D'}{$id}{tok} ";
          $srcNextToken++;
        }
      }
    }
    print CRP "\n";

# Print CRP file target segment
    foreach my $seg (sort {$a<=>$b} keys %{$A->{SEG}{$aln}{tgt}}) {
      foreach my $id (sort {$a<=>$b} keys %{$A->{$tid}{'D'}}) {
        if($A->{$tid}{'D'}{$id}{seg} == $seg) { 
          print CRP "$A->{$tid}{'D'}{$id}{tok} ";
          $tgtNextToken++;
        }
      }
    }
    print CRP "\n";

## Print ALN file
# $A->{SEG}{$aln}{au}{$au}
    foreach my $au (sort {$a<=>$b} keys %{$A->{SEG}{$aln}{au}}) {

#print STDERR "AU: aln:$aln au:$au\n";
#d($A->{SEG}{$aln}{au}{$au});
		my $yawat = 'unspec';
		my $ali1 = '';
		my $ali2 = '';
		my $AU = $A->{SEG}{$aln}{au}{$au};
	    my $first = 0;

        foreach my $src_id (sort {$a<=>$b} keys %{$AU->{src}{id}}) {
#printf STDERR "$fn PrintYawat: SegAlignment $aln: source:$src_id token:%d #tokens:$srcNextToken\n", $src_id-$srcToken;

          if($src_id-$srcToken >= $srcNextToken) { 
            printf STDERR "PrintYawat: $fn\tcrossing forward Seg:$aln source:$src_id token:%d max:$srcNextToken\n", $src_id-$srcToken;
            next;
          };
          if($src_id-$srcToken < 0) { 
            printf STDERR "PrintYawat: $fn\tcrossing backward Seg:$aln source:$src_id token:%d min:$srcToken\n", $src_id-$srcToken;
            $src_id=$srcToken
          };
#          if($first != 0) { print ALN ",";}
#          printf ALN "%d", $src_id-$srcToken;
          if($first != 0) {$ali1 .= ",";}
		  $ali1 .= $src_id-$srcToken;
		  if(defined($AU->{src}{id}{$src_id}{yawat})) {$yawat = $AU->{src}{id}{$src_id}{yawat};}
          $first ++;
#printf STDERR "PrintYawat: source:$aln au:$au src:$src_id:%d length:$srcToken\n", $src_id-$srcToken; 
        }
#        if($first==0) {printf ALN "0";}
#        print ALN ":";
        $first = 0;
        foreach my $tgt_id (sort {$a<=>$b} keys %{$AU->{tgt}{id}}) {
#printf STDERR "PrintYawat: Seg:$aln target:$tgt_id token:%d min:$tgtToken next:$tgtNextToken\n", $tgt_id-$tgtToken;
#if($aln == 3) {d($AU->{tgt}{id})}

          if($tgt_id-$tgtToken >= $tgtNextToken) { 
            printf STDERR "PrintYawat: $fn\tforward crossing Seg:$aln target:$tgt_id token:%d max:$tgtNextToken\n", $tgt_id-$tgtToken;
            next;
          };
          if($tgt_id-$tgtToken < 0) { 
            printf STDERR "PrintYawat: $fn\tbackward crossing Seg:$aln target:$tgt_id token:%d min:$tgtToken\n", $tgt_id-$tgtToken;
            $tgt_id=$tgtToken
          };
		  if(defined($AU->{tgt}{id}{$tgt_id}{yawat})) {
		    if($yawat ne 'unspec' && $AU->{tgt}{id}{$tgt_id}{yawat} ne $yawat) {
               printf STDERR "PrintYawat: $fn\tincompatible yawat code:$yawat $AU->{tgt}{id}{$tgt_id}{yawat}\n"; 
			}
		    else {$yawat = $AU->{tgt}{id}{$tgt_id}{yawat};}
		  }
          if($first != 0) {$ali2 .= ",";}
		  $ali2 .= $tgt_id-$tgtToken;
#printf STDERR "PrintYawat: target:$aln au:$au tgt:$tgt_id:%d length:$tgtToken\n", $tgt_id-$tgtToken; 
          $first ++;
        }
        if($yawat ne 'unspec' || ($ali1 ne '' && $ali2 ne '')) { print ALN "$ali1:$ali2:$yawat ";}
    }
    print ALN "\n";
    $srcToken+=$srcNextToken;
    $tgtToken+=$tgtNextToken;
  
  }
} 


sub PrintAtag {
  my ($fn, $A, $Y) = @_;

  open(ATAG, '>:encoding(utf8)', "$fn.atag") || die ("cannot open file $fn.atag");

#print STDERR "AAA\n";
#d($Y);
  my $first = 1;
  foreach my $atag (sort {$a<=>$b} keys %{$A->{atag}}) {
    if($A->{atag}{$atag} =~ /<DTAGalign/) {
      if($A->{atag}{$atag} =~ /alignment=/) {$A->{atag}{$atag} =~ s/alignment="[^"]*"/alignment="yawat"/;} 
      else {$A->{atag}{$atag} =~ s/DTAGalign/DTAGalign alignment=\"yawat\"/;}
    }
    if($A->{atag}{$atag} =~ /<align /) {
      if($first) {
        foreach my $h (sort {$a<=>$b} keys %{$Y}) {print ATAG "$Y->{$h}";}
        $first = 0;
      }
      next;
    }
    if($A->{atag}{$atag} =~ /<\/DTAGalign/i && $first) {
       foreach my $h (sort {$a<=>$b} keys %{$Y}) {print ATAG "$Y->{$h}";}
      $first = 0;
    }

    print ATAG "$A->{atag}{$atag}";
  }
  close(ATAG);
}


## Print DTAG tag format
sub PrintTok {
  my ($fn, $A, $lng) = @_; 
  my ($f, $s); 

  my $lid = $A->{$lng}{lang};

  if(!open(FILE,  ">:encoding(utf8)", "$fn.$lng")) {
    printf STDERR "cannot open: $fn.$lng\n";
    return ;
  }
  if($Verbose){ printf STDERR "Writing: $fn.$lng\n";}

  foreach my $id (sort {$a<=>$b} keys %{$A->{$lid}{D}}) {
    if(defined($A->{$lid}{D}{$id}{header})){ print FILE "$A->{$lid}{D}{$id}{header}";}
	print FILE "$A->{$lid}{D}{$id}{str}";
    if(defined($A->{$lid}{D}{$id}{footer})){ print FILE "$A->{$lid}{D}{$id}{footer}";}
	
  }
  close (FILE);
}

