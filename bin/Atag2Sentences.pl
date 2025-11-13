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
  "Write tokenized sentences from atag files: \n".
  "  -A in:  Alignment files <root>.{atag,src,tgt}\n".
  "          to <root>.{SourceTok,FinalTok}\n".
  "Options:\n".
  "  -O out: Write output   <root>\n".
  "  Generate new atag files based on segment alignments\n".
  "  -o reverse: <root>.{SourceTok,FinalTok} to {src,tgt,atag}\n".
  "  -l attach language suffix\n".
  "  -v verbose mode [0 ... ]\n".
  "  -h this help \n".
  "\n";

use vars qw ($opt_O $opt_A $opt_v $opt_o $opt_l $opt_h);

use Getopt::Std;
getopts ('A:O:v:t:lho');

die $usage if defined($opt_h);

my $changeSource = 0;

my $Verbose = 0;
my $fn = '';
my $Segmenter = ''; 
my $LangTag = 0; 
my $Header = {};

if (defined($opt_l)) {$LangTag = 1;}
if (defined($opt_v)) {$Verbose = $opt_v;}

### Read and Tokenize Translog log file
$fn = $opt_A;
if(defined($opt_O)) { $fn = $opt_O;}
if(defined($opt_o)) { print STDERR "Writing: $fn.{src,tgt,atag}\n";}

if(defined($opt_A)) {
  my $A=ReadAtag($opt_A);

  if(defined($opt_o)) {
	my $s = ReadSegments("$opt_A.SourceTok", $A, 'Source');
	my $f = ReadSegments("$opt_A.FinalTok", $A, 'Final');
	if($s != $f) {
	 print STDERR "Unequal number of segments: $opt_A.SourceTok:$s\t$opt_A.FinalTok:$f\n";
#	 exit;
	}
	
    printTok($A, "$fn.src", "Source");
    printTok($A, "$fn.tgt", "Final");
    printAtag($A, $fn);
  }
  else { PrintSegments($fn, $A); }
  exit;
}

printf STDERR "No Output produced\n";
die $usage;

exit;

############################################################
# Read src and tgt files
############################################################


sub ReadDTAG {
  my ($fn, $lang) = @_;
  my ($x, $k, $s, $D, $n); 

  if(!open(DATA, "<:encoding(utf8)", $fn)) {
    printf STDERR "cannot open: $fn\n";
    exit ;
  }

  if($Verbose) {printf STDERR "ReadDtag: %s\n", $fn;}

  $n = 1;
  while(defined($_ = <DATA>)) {
    if($_ =~ /^\s*$/) {next;}
    if($_ =~ /^#/) {next;}
    chomp;
#printf STDERR "$_\n";

    if(/<Text /) { $Header->{$lang} = $_;}

    if(!/<W ([^>]*)>([^<]*)/) {next;} 
    $x = $1;
    $s = $2;
    if(/id="([^"])"/ && $1 != $n) {
      printf STDERR "Read $fn: unmatching n:$n and id:$1\n";
      $n=$1;
    }

#    $s =~ s/([\(\)\\\/])/\\$1/g;
    $D->{$n}{'tok'}=$s;
#printf STDERR "\tvalue:$2\t";
    $x =~ s/\s*([^=]*)\s*=\s*"([^"]*)\s*"/AttrVal($D, $n, $1, $2)/eg;
    if(defined($D->{$n}{id}) && $D->{$n}{id} != $n)  {
      print STDERR "ReadDTAG: IDs $fn: n:$n\tid:$D->{$n}{id}\n";
      if($D->{$n}{id} > $n) {$n= $D->{$n}{id}}
    }
    $n++;
  }
  close (DATA);
  return $D;
}

############################################################
# Read Atag file
############################################################

sub AttrVal {
  my ($D, $n, $attr, $val) = @_;

#printf STDERR "$n:$attr:$val\t";
  $D->{$n}{$attr}=$val;
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
  my $salign = 0;
  while(defined($_ = <ALIGN>)) {
    if($_ =~ /^\s*$/) {next;}
    if($_ =~ /^#/) {next;}
    chomp;

#printf STDERR "Alignment %s\n", $_;
## read aligned files
    if(/<DTAGalign /) { $Header->{align} = $_;} 
    if(/<DTAGalign / && /source="([^"]*)"/) { $A->{Source}{Lang} = $1;} 
    if(/<DTAGalign / && /target="([^"]*)"/) { $A->{Final}{Lang} = $1;} 
    if(/<DTAGalign / && /sent_alignment="([^>]*)"/) { $Segmenter = $1; next;} 
    if(/<alignFile/) {
      my $path = $fn;
      if(/href="([^"]*)"/) { $fn1 = $1;}

## read reference file "a"
      if(/key="a"/) { 
        $A->{'a'}{'fn'} =  $fn1;
        if($fn1 =~ /src$/)    { 
		  $lang='Source'; 
		  $A->{'a'}{'lang'} = 'Source'; 
		  $path .= ".src";
        }
        elsif($fn1 =~ /tgt$/) { 
		  $lang='Final'; 
		  $A->{'a'}{'lang'} = 'Final'; 
		  $path .= ".tgt";
        }
      }
## read reference file "b"
      elsif(/key="b"/) { 
        $A->{'b'}{'fn'} =  $fn1;
        if($fn1 =~ /src$/) { $lang='Source'; $A->{'b'}{'lang'} = 'Source'; $path .= ".src";}
        elsif($fn1 =~ /tgt$/) { $lang='Final'; $A->{'b'}{'lang'} = 'Final';$path .= ".tgt";}
      }
      else {printf STDERR "Alignment wrong %s\n", $_;}
      $A->{$lang}{'D'} =  ReadDTAG("$path", $lang); 
  
      next;
    }

    if(/<salign /) {
	  my ($src) = $_ =~ /src="([0-9]+)"/;
	  my ($tgt) = $_ =~ /tgt="([0-9]+)"/;
	  my $smul = 0;
	  my $tmul = 0;
	  if(defined($A->{salign}{Source}{$src})) { $smul = 1;}
	  if(defined($A->{salign}{Final}{$tgt})) {$tmul = 1; };
	  if($smul == 1) {$A->{salign}{Final}{$tgt}{mul}  = 2};
	  if($tmul == 1) {$A->{salign}{Source}{$src}{mul} = 2};
	  $A->{salign}{Source}{$src}{tgt}{$tgt} = 1;
	  $A->{salign}{Final}{$tgt}{src}{$src} = 1;
#print STDERR "SALIGN $src $tgt\n"
#	  $A->{salign}{$salign}{Source} = $_ =~ s/src="([0-9]+)"//;
#	  $A->{salign}{$salign}{Final} = $_ =~ s/tgt="([0-9]+)"//;
#	  $salign ++;
    }
    if(/<align /) {
#printf STDERR "ALN: $_\n";
      if(/in="([^"]*)"/) { $is=$1;}
      if(/out="([^"]*)"/){ $os=$1;}

      ## aligned to itself
      if($is eq $os) {next;}

      if(/insign="([^"]*)"/) { $is=$1;}
      if(/outsign="([^"]*)"/){ $os=$1;}

      if(/in="([^"]*)"/) { 
        $K = [split(/\s+/, $1)];
        for($i=0; $i <=$#{$K}; $i++) {
          if($K->[$i] =~ /([ab])(\d+)/) { 
            $A->{'n'}{$n}{$A->{$1}{'lang'}}{'dir'} = 'in';
            $A->{'n'}{$n}{$A->{$1}{'lang'}}{'ab'} = $1;
            $A->{'n'}{$n}{$A->{$1}{'lang'}}{'id'}{$2} ++;
            $A->{'n'}{$n}{$A->{$1}{'lang'}}{'s'}=$is;
          }
#printf STDERR "IN:  %s\t$1\t$2\n", $K->[$i];
        }
      }
      if(/out="([^"]*)"/) { 
        $K = [split(/\s+/, $1)];
        for($i=0; $i <=$#{$K}; $i++) {
          if($K->[$i] =~ /([ab])(\d+)/) { 
            $A->{'n'}{$n}{$A->{$1}{'lang'}}{'dir'} = 'out';
            $A->{'n'}{$n}{$A->{$1}{'lang'}}{'ab'} = $1;
            $A->{'n'}{$n}{$A->{$1}{'lang'}}{'id'}{$2} ++;
            $A->{'n'}{$n}{$A->{$1}{'lang'}}{'s'}=$os;
          }
        }
      }
      $n++;
    }
  }
  close (ALIGN);
  return ($A);
}


sub SentenceAlignment {
  my ($fn, $A) = @_;

  my $NoAlign = 0;
  my $H = {};

  foreach my $n (keys %{$A->{Source}{D}}) { $H->{Source}{$A->{Source}{D}{$n}{segId}} ++ }
  foreach my $n (keys %{$A->{Final}{D}})  { $H->{Final}{$A->{Final}{D}{$n}{segId}} ++}

#check whether segID is in both language sides
  foreach my $id (sort {$a<=>$b} keys %{$H->{Source}}) {
    if(!defined($H->{Final}{$id})) {
      print STDERR "Warning: $fn Undefined Final segment $id\n"; 
      foreach my $n (sort {$a<=>$b} keys %{$A->{Final}{D}}) {
        if($A->{Final}{D}{$n}{segId} == $id) {delete($A->{Final}{D}{$n})} 
      } 
      $NoAlign = 1;
    }
  }

#check whether segID is in both language sides
  foreach my $id (sort {$a<=>$b} keys %{$H->{Final}}) {
    if(!defined($H->{Source}{$id})) {
      print STDERR "Warning: $fn Undefined Source segment $id\n";
      foreach my $n (sort {$a<=>$b} keys %{$A->{Source}{D}}) {
        if($A->{Source}{D}{$n}{segId} == $id) {delete($A->{Source}{D}{$n})}
      }
      $NoAlign = 1;
    }
  }
  return $NoAlign;
}
 
# returnt number of read segments
sub ReadSegments{
  my ($fn, $A, $lang) = @_;

  if(!open(SEG,  "<:encoding(utf8)", "$fn")) {
    printf STDERR "cannot open for reading: $fn\n";
    exit 1;
  }

  my $s = 0;
  my $n = 1;
  my $seg = 0;

  while(defined($_ = <SEG>)) {
    chomp;
#print STDERR "XXX1 $_\n";

    my $L = [split(/\s+/, $_)];
	$s ++;
    $seg ++;
    $A->{seg}{$seg}{$lang}{$s} = 1;
    if($Verbose) {print STDERR "$lang align:$seg seg:$s\n";}
		
    for(my $i = 0; $i <= $#{$L}; $i++) {

      if($Verbose > 2) {print STDERR "$fn: $lang: align:$seg seg:$s word:$i $L->[$i]\n"; }

#new segment alignment introduced
	  if($L->[$i] eq '///') { 
	    $s++; 
        $A->{seg}{$seg}{$lang}{$s} = 1;
        if($Verbose) {print STDERR "$lang align:$seg seg:$s \n";}
		next;
      }
#print STDERR "SEG $lang\tsegId:$s id:$n\n";
#d($A->{$lang}{D}{$n});
	  if(!defined($A->{$lang}{D}{$n})) {
	    print STDERR "$lang segment token $n\n";
		next;
      }

	  if($L->[$i] ne $A->{$lang}{D}{$n}{tok}) {
	    if($lang eq 'Source' && $changeSource == 0) {
          print STDERR "$lang set -s to change source language items\n"; 		  
		}
	    else {
        if($Verbose) {print STDERR "$lang new token $n: \"$A->{$lang}{D}{$n}{tok}\" --> \"$L->[$i]\"\n";}

# new token boundary introduced
		if(length($L->[$i]) < length($A->{$lang}{D}{$n}{tok})) {
		
		  if($A->{$lang}{D}{$n}{tok} =~ s/^\Q$L->[$i]\E\s*//) {
		    
			foreach my $m (sort {$b<=>$a} keys %{$A->{$lang}{D}}) {
			  $A->{$lang}{D}{$m+1} = $A->{$lang}{D}{$m};
			  $A->{$lang}{D}{$m} = {};
			  if($m == $n) {last;}
			}
		  
#print STDERR "$i IIII $L->[$i] $A->{$lang}{D}{$n+1}{tok} \n";
		    $A->{$lang}{D}{$n}{tok} = $L->[$i];
		    $A->{$lang}{D}{$n}{id} = $n;
		    $A->{$lang}{D}{$n}{segId} = $A->{$lang}{D}{$n+1}{segId};
		  }
          else { print STDERR "$lang segment short token $n: $L->[$i] does not match\n";}
#		  $A->{$lang}{D}{$n}{tok} =~ s/^\s*//;
		}

# tokens collapsed
		elsif(length($L->[$i]) > length($A->{$lang}{D}{$n}{tok})) {
		  my $str = $L->[$i];
          if($str =~ s/^\Q$A->{$lang}{D}{$n}{tok}\E//) {
		    my $cur = $A->{$lang}{D}{$n}{cur};
			
            while(length($str) > 0) {
		      for(my $m=$n; defined($A->{$lang}{D}{$m}); $m++) {
			    $A->{$lang}{D}{$m} = $A->{$lang}{D}{$m+1};
              }
              if($Verbose) {print STDERR "$lang concat '$str' tok:$n '$A->{$lang}{D}{$n}{tok}' \n";}
			  
              if(!($str =~ s/^\Q$A->{$lang}{D}{$n}{tok}\E//)) { last;}
            }
#print STDERR "$i IIII $L->[$i] $A->{$lang}{D}{$n+1}{tok} \n";
            $A->{$lang}{D}{$n}{tok} = $L->[$i];
            $A->{$lang}{D}{$n}{cur} = $cur;
		  }
          if(length($str) > 0) { print STDERR "$lang unmatched '$str' segment long token $n: $L->[$i] does not match\n";}
		}
        else { print STDERR "$lang segment new token $n: $L->[$i] does not match\n";}
      } }
	  
	  if($n != $A->{$lang}{D}{$n}{id}) {
		$A->{$lang}{D}{$n}{id} = $n;
      }
	  if($s != $A->{$lang}{D}{$n}{segId}) {
		$A->{$lang}{D}{$n}{segId} = $s;
      }
	  $n ++;
    }
  }
  close SEG;
  return $seg;
}


sub PrintSegments {
  my ($fn, $A) = @_;
  my $lineBreak=1;
  my $seg;

  my @L = qw(Source Final);
  foreach my $l (@L) {
    my $lng = "";
	if ($LangTag) {$lng = ".$A->{$l}{Lang}";}

    open(FILE, '>:encoding(utf8)', "$fn.$l"."Tok".$lng) || die ("cannot open file $fn");
    $seg = -1; #initialization
    foreach my $id (sort {$a<=>$b} keys %{$A->{$l}{'D'}}) {
#      $A->{$l}{D}{$id}{tok} =~ s/\\([\(\)\\\/])/$1/g;
      my $tok = $A->{$l}{D}{$id}{tok};
#print STDERR "XXXX\t$l$id $A->{$l}{D}{$id}{tok}\t$tok\n";

      if(defined($A->{$l}{D}{$id}{segId})){ 
	    my $seg1 = $A->{$l}{D}{$id}{segId};
        if($seg != $seg1 && $seg != -1) {
          if(defined($A->{salign}{$l}{$seg1}{mul})) {print FILE " /// "; }
		  else { print FILE "\n"; }
        }
        $seg = $seg1;
      }
      print FILE "$tok ";
    }
    close (FILE);
  }
}

sub printTok {
  my ($A, $fn, $lang) = @_;
  my $cur = 0;
  my $T = '';

  open(F, '>:encoding(utf8)', "$fn") || die ("cannnot open file $fn\n");
  
#print STDERR "cannot open file $fn\n";

  print F "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n";
  printf F "$Header->{$lang}\n";
#  print F "<Text sent_segmenter=\"elan\">\n";

  for my $t (sort {$a<=>$b} keys %{$A->{$lang}{D}}) {
    my $tok = '';
    print F "<W";
	foreach my $f (sort keys %{$A->{$lang}{D}{$t}}) {
#d($A->{$lang}{D}{$t});
      if($f eq "tok") {$tok = $A->{$lang}{D}{$t}{$f}}
      else { print F " $f=\"$A->{$lang}{D}{$t}{$f}\"";}
    }
    print F " >$tok</W>\n";
  }
  printf F "</Text>\n";
  close(F);
  return $T;  
}

sub printAtag {
  my ($A, $root) = @_;
  
# printf STDERR "PrintAtag: $fn, $root $lang1, $lang2\n";  

#  my ($root) = $fn =~ /\/([^\/]+)$/;

  open(ATAG, '>:encoding(utf8)', "$root.atag") || die ("cannot open file $root.atag");

  printf ATAG "$Header->{align}\n";
#  printf ATAG "<DTAGalign sent_alignment=\"elan\" >\n";
  printf ATAG "    <alignFile key=\"a\" href=\"$root.src\" sign=\"_input\"/>\n";
  printf ATAG "    <alignFile key=\"b\" href=\"$root.tgt\" sign=\"_input\"/>\n";

  foreach my $seg (sort {$a<=>$b} keys %{$A->{seg}}) {
    if(!defined($A->{seg}{$seg}{Source})) {$A->{seg}{$seg}{Source}{0}= 1;}
    if(!defined($A->{seg}{$seg}{Final})) {$A->{seg}{$seg}{Final}{0}= 1;}
    foreach my $src (sort {$a<=>$b} keys %{$A->{seg}{$seg}{Source}}) {
      foreach my $tgt (sort {$a<=>$b} keys %{$A->{seg}{$seg}{Final}}){
        printf ATAG "    <salign src=\"%d\" tgt=\"%d\" />\n", $src, $tgt;
#        printf STDERR "    <salign src=\"%d\" tgt=\"%d\" />\n", $src, $tgt;
  } } }
  foreach my $n (sort {$a<=>$b} keys %{$A->{n}}) {
    my $src = "$A->{n}{$n}{Source}{dir}=\"$A->{n}{$n}{Source}{ab}";
    foreach my $id (sort {$a<=>$b} keys %{$A->{n}{$n}{Source}{id}}) {$src .= $id;}
    $src .="\"";
	
    my $tgt = "$A->{n}{$n}{Final}{dir}=\"$A->{n}{$n}{Final}{ab}";
    foreach my $id (sort {$a<=>$b} keys %{$A->{n}{$n}{Final}{id}}) {$tgt .= $id;}
    $tgt .="\"";
		
    printf ATAG "    <align $src $tgt />\n";
  }
  printf ATAG "</DTAGalign>\n";
  close(ATAG);
}