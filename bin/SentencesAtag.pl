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
  "  -A in:  Alignment file <filename2>.{atag,src,tgt}\n".
  "Options:\n".
  "  -t starting token id [1] \n".
  "  -f fixation unit gap \n".
  "  -p production unit gap \n".
  "  -v verbose mode [0 ... ]\n".
  "  -h this help \n".
  "\n";

use vars qw ($opt_f $opt_p $opt_t $opt_A $opt_v $opt_h);

use Getopt::Std;
getopts ('T:A:O:G:f:p:v:t:h');

die $usage if defined($opt_h);

my $TRANSLOG = {};
my $Verbose = 0;

if (defined($opt_v)) {$Verbose = $opt_v;}

### Read and Tokenize Translog log file
if (defined($opt_A)) {
  my $A=ReadAtag($opt_A);
  SentencesAtag($A);
  exit;
}

printf STDERR "No Output produced\n";
die $usage;

exit;

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
  $in =~ s/&#xD;/\r/g;
  $in =~ s/&#x9;/\t/g;
  $in =~ s/&quot;/"/g;
  $in =~ s/&nbsp;/ /g;
  return $in;
}

sub MSescape {
  my ($in) = @_;

#  $in =~ s/\&/&amp;/g;
  $in =~ s/\>/&gt;/g;
  $in =~ s/\</&lt;/g;
#  $in =~ s/\n/&#xA;/g;
#  $in =~ s/\r/&#xD;/g;
#  $in =~ s/\t/&#x9;/g;
#  $in =~ s/"/&quot;/g;
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
    if($_ =~ /^\s*$/) {next;}
    if($_ =~ /^#/) {next;}
    chomp;
#printf STDERR "$_\n";

    if(/<Text /) {$H = $_; $H =~ s/<Text//;  $H =~ s/>//;} 
    if(!/<W ([^>]*)>([^<]*)/) {next;} 
    my $x = $1;
    my $s = MSunescape($2);
#printf STDERR "ReadDTAG: $2\t$s\t%s\n", MSescape($s);
    if(/id="([^"])"/i && $1 != $n) {
      printf STDERR "Read $fn: unmatching n:$n and id:$1\n";
      $n=$1;
    }

#    $s =~ s/([\(\)\\\/])/\\$1/g;
    $D->{$n}{'tok'}=$s;
#printf STDERR "\tvalue:$2\t";
    $x =~ s/\s*([^=]*)\s*=\s*"([^"]*)\s*"/AttrVal($D, $n, $1, $2)/eg;
    if(defined($D->{$n}{id}) && $D->{$n}{id} != $n)  {
      print STDERR "ReadDTAG: IDs $fn: n:$n\tid:$D->{$n}{id}\n";
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
  while(defined($_ = <ALIGN>)) {
    if($_ !~ /<\/DTAGalign>/) {printf STDOUT "$_";}
    if($_ =~ /^\s*$/) {next;}
    if($_ =~ /^#/) {next;}
    chomp;

## read aligned files
    if(/<DTAGalign/) {$A->{H} = $_; $A->{H} =~ s/<DTAGalign//;  $A->{H} =~ s/>//;} 
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

    if(/<align /) {
#printf STDERR "ALN: $_\n";
      if(/in="([^"]*)"/) { $is=$1;}
      if(/out="([^"]*)"/){ $os=$1;}

      ## aligned to itself
      if($is eq $os) {next;}
      $is = $os = '---';

      if(/boundary="([^"]*)"/) { $A->{'e'}{$n} = $1}
      if(/insign="([^"]*)"/) { $is=$1;}
      if(/outsign="([^"]*)"/){ $os=$1;}

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
      if(/out="([^"]*)"/) { 
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
      $n++;
    }
  }
  close (ALIGN);
  return ($A);
}

##########################################################
# Parse Keystroke Log
##########################################################

sub SentencesAtag {
  my ($A) = @_;

#  print STDERR "<DTAGalign>\n";
#  print STDERR "    <alignFile key=\"a\" href=\"$root.src\" sign=\"_input\"/>";
#  print STDERR "    <alignFile key=\"b\" href=\"$root.tgt\" sign=\"_input\"/>";
#  print STDERR "</DTAGalign>";
  
  my ($n);
  my $H = {};
  $n=0;
  foreach my $id (sort {$a<=>$b} keys %{$A->{Source}{D}}) {
#print STDERR "XXXX\n";
#d($A->{Source}{D}{$id});
	  if(defined($A->{Source}{D}{$id}{space}) && $A->{Source}{D}{$id}{space} =~ /\n/) { $n++; }
      $H->{$n}{a} .= "a$id ";
      $H->{$n}{as} .= "$A->{Source}{D}{$id}{tok} ";
  }
  $n=0;
  foreach my $id (sort {$a<=>$b} keys %{$A->{Final}{D}}) {
	  if(defined($A->{Final}{D}{$id}{space}) && $A->{Final}{D}{$id}{space} =~ /\n/) { $n++; }
      $H->{$n}{b} .= "b$id ";
      $H->{$n}{bs} .= "$A->{Final}{D}{$id}{tok} ";
  }
  foreach my $n (sort {$a<=>$b} keys %{$H}) {
    printf STDOUT "<align in=\"%s\" out=\"%s\" insign=\"%s\" outsign=\"%s\" />\n", 
	       $H->{$n}{a}, $H->{$n}{b}, $H->{$n}{as}, $H->{$n}{bs};
  }
  print STDOUT "</DTAGalign>";
}

