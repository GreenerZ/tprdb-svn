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
  "Tokenisation of Translog file: \n".
  "  -T in:  Translog XML <filename>\n".
  "  out: Write Translog file with Tokens to STDOUT\n".
  "Options:\n".
  "  -D out: Write in {.src,.tgt} file\n".
  "  -t read text input\n".
  "  -v verbose mode [0 ... ]\n".
  "  -h this help \n".
  "\n";

use vars qw ($opt_D $opt_T $opt_A $opt_v $opt_h $opt_t);

use Getopt::Std;
getopts ('T:O:D:v:ht');

die $usage if defined($opt_h);

my $SRC = undef;
my $TGT = undef;
my $Verbose = 0;
my $SourceLanguage = '';
my $TargetLanguage = '';
my $SegID = {};
my $Qualitivity = 0; # set to 1 if input from Trados (sentence segment)

#my $ChineseTokenizer = 'D:/tprdb/bin/ChineseTokenizer/stanford-segmenter-2015-12-09/segment.bat';

#my $ChineseTokenizer = '/data/critt/tprdb/bin/ChineseTokenizer/stanford-segmenter-2015-12-09/segment.sh';
my $ChineseTokenizer = '/usr/bin/python3  /data/critt/tprdb/bin/jiebaTPRDB.py';
my $JapaneseTokenizer = '/usr/bin/python3  /data/critt/tprdb/bin/mecab.py';


## Read Configuration file
if(open CONFIG, "StudyAnalysis.cfg") {
  while(defined(my $conf = <CONFIG>)) {  eval $conf;}
  close CONFIG;
}
#else{print STDERR "Couldn't open the configuration file 'StudyAnalysis.cfg'.\n";}


if (defined($opt_v)) {$Verbose = $opt_v;}
if (!defined($opt_T)) {die $usage;}

  my $K = {};
  if(defined($opt_t)) {ReadTexts($opt_T);}
  else{ $K = ReadTranslog($opt_T);}

#Tokenization file is already available
  if ($SourceLanguage eq 'zh' && (-e "$opt_T.src.zh" )) {ReadWordTokens("$opt_T.src.zh", $SRC);}
  elsif ($SourceLanguage eq 'ja' && (-e "$opt_T.src.ja" )) {ReadWordTokens("$opt_T.src.ja", $SRC);}
# ZH/JA Tokenization
  elsif ($SourceLanguage eq 'ja' || $SourceLanguage eq 'zh') { ZH_JA_Tokenize($SRC, $SourceLanguage);}
  else {
    Tokenize($SRC, $SourceLanguage);
    SentenceSegment($SRC);
  }

  if ($TargetLanguage eq 'zh' && (-e "$opt_T.tgt.zh" )) {ReadWordTokens("$opt_T.tgt.zh", $TGT);}
  elsif ($TargetLanguage eq 'ja' && (-e "$opt_T.tgt.ja" )) {ReadWordTokens("$opt_T.tgt.ja", $TGT);}
  elsif ($TargetLanguage eq 'ja' || $TargetLanguage eq 'zh') { ZH_JA_Tokenize($TGT, $TargetLanguage);}
  else{
    Tokenize($TGT, $TargetLanguage);
    SentenceSegment($TGT);
  }

  if (defined($opt_D)) {
    if($SourceLanguage eq '' || $TargetLanguage eq '') { print STDERR "WARNING no language\n";}

    PrintTag("$opt_D.src", $SourceLanguage, $SRC);
    PrintTag("$opt_D.tgt", $TargetLanguage, $TGT);
    PrintAtag("$opt_D", $SourceLanguage, $TargetLanguage);
  }
  else { WriteTranslog($K); }

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
  $in =~ s/&#10;/\n/g;
  $in =~ s/&#xD;/\r/g;
  $in =~ s/&#x9;/\t/g;
  $in =~ s/&#9;/\t/g;
  $in =~ s/&quot;/"/g;
  $in =~ s/&nbsp;/ /g;
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
# Tokenize:
# insert into Text $T at $start position:       
#   token:               $T->{$start}{'tok'} = $w;
#   preceding blank:     $T->{$start}{'space'} = $blank;
#   word number:         $T->{$start}{'wnr'} = $number++;
#   end cursor position: $T->{$start}{'end'} = $cur -1;
############################################################

sub Tokenize {
  my ($T, $language) = @_;
  
  my ($c);
  my $w = "";
  my $start = -1;
  my $blank = "";
  my $tok = 1;
  my $number = 1;
  my $cur;


  foreach $cur (sort {$a <=> $b} keys %{$T}) {
    if($start == -1) {$start = $cur;}

    $c = $T->{$cur}{'c'};
    if($Verbose > 2) { print STDERR "cur: $cur\t$c\n";}

#printf STDERR "Tokenize: $c %d\n", ord($c);

    # current char is
    # tok == 0 : part of a token 
    # tok == 1 : first blank after token
    # tok ==11 : multi blank before token
    # tok == 2 : extra token
    # tok == 3 : beginning of new token

#print STDERR "Key0: cur:$cur c:>$c< tok:$tok w:>$w< b:>$blank< c+1:>$T->{$cur+1}{'c'}<\n";

    #############################################
    # Classify current char as
    #############################################
    # blank before token 
    if(($tok == 1 || $tok == 11) && $c =~ /[\s\n\t\r\f]/) { $tok =11;}

    # part of multi-blanks 
    elsif($c =~ /[\s\n\t\r\f]/ ) { $tok =1;}

    # X.( => X. (
    elsif($c =~ /[\.]/ 
         && defined($T->{$cur+1})
         && $T->{$cur+1}{'c'} =~ /[\(\)]/) { $tok = 0;}

    # French: d'abord => d' abord
    elsif($language eq 'fr'
         && $c =~ /[']/
         && $w =~ /[\p{IsAlpha}]$/
         && defined($T->{$cur+1})
         && $T->{$cur+1}{'c'} =~ /\p{IsAlpha}/) { 
        $tok = 0;  ## same token
    }
    	
    # abcd'[slv] => abce 'abc
    elsif(($c =~ /[']/ || ord($c) == 8217) 
         && $w =~ /[\p{IsAlpha}]$/
         && defined($T->{$cur+1})
         && $T->{$cur+1}{'c'} =~ /\p{IsAlpha}/) { 
	 $tok = 3;}
	  
    elsif($c =~ /[\~\?\!\“\”\"\$\%\&\/\(\)\=\{\}\+\*\|\[\]\/\<\>]/ ||
          ## “ and ”
          ord($c) == 8220 || ord($c) == 8221 || 
          ## ‘ and ’
          ord($c) == 8216 || ord($c) == 8217 || 
          ## ¡ and ¿
          ord($c) == 161 || ord($c) == 191 || 
          ## « and »
          ord($c) == 171 || ord($c) == 187 
          ) {
#printf STDERR "Key3: $c\n";
	    $tok =2; }

    # 012'123 => 012 ' 123
    elsif($c =~ /[']/ 
         && $w =~ /[^\p{IsAlpha}]$/
         && defined($T->{$cur+1})
         && $T->{$cur+1}{'c'} =~ /[^\p{IsAlpha}]/) { 
#printf STDERR "Key4: $c\n";
      $tok = 2;}

    # $'abc => $ ' abc
    elsif($c =~ /[']/
         && $w =~ /[^\p{IsAlnum}]/
         && defined($T->{$cur+1})
         && $T->{$cur+1}{'c'} =~ /\p{IsAlpha}/) { 
#printf STDERR "Key5: $c\n";
	 $tok = 2;}

    # abc'123 => abc ' 123
    elsif($c =~ /[']/
         && $w =~ /[\p{IsAlpha}]$/
         && defined($T->{$cur+1})
         && $T->{$cur+1}{'c'} =~ /[^\p{IsAlpha}]/) { 
#printf STDERR "Key6: $c\n";
	 $tok = 2;}

    # part of a number [,.:;] in numbers stay together (5,300)
    elsif($c =~ /[.,:;]/ 
         && $w =~ /\p{IsN}$/ 
         && defined($T->{$cur+1}) 
         && $T->{$cur+1}{'c'} =~ /^\p{IsN}/) { $tok = 0;}

    # one token: 32-arige  
    elsif($c =~ /-/ 
         && $w =~ /\p{IsN}$/ 
         && defined($T->{$cur+1}) 
         && $T->{$cur+1}{'c'} =~ /\p{IsAlpha}/) { $tok = 0;}

    # multi-dots stay together
    elsif($c =~ /([.,;:-])/ && $w =~ /^([$1][$1]*)$/) { $tok = 0; }

    # entity after number 1.000,12ms => 1.000,12 ms
    elsif($c =~ /[\p{IsAlpha}]/ && $w =~ /^(\p{IsN}+[:.,;]*\p{IsN}*)+$/) { $tok = 3;}

    # token after multi-dots 
    elsif($c =~ /[\p{IsAlnum}]/ && $w =~ /^[:.,;-]+$/) { $tok = 3;}

    # punctuation token गया।
    elsif($c =~ /['`;,.:-]/) { $tok = 3;}

    # no segmentation (part of a token)
    else { $tok = 0;}

#printf STDERR "Key0a:>$w< >$blank< >$c<\t$tok\n";
    #############################################
    # Concat current char as
    #############################################
    # part of token 
    if($tok == 0) { $w .= $c; }

    # sequences of blanks
    elsif($tok == 11) { 
      $blank .= $c; 
      $start = -1;
#printf STDERR "Tok11:>$blank<\n";
    }

    # blank as tokenization border
    elsif($tok == 1) {
      $T->{$start}{'tok'} = $w;
      $T->{$start}{'end'} = $cur -1;
      $T->{$start}{'space'} = $blank;
      $T->{$start}{'wnr'} = $number++;
      if($Verbose >2 ){ printf STDERR "Tok1: $number\t$cur\t>$w<\t>$blank<\t>$c<\n"; }
#d($T->{$start});
      $w = "";
      $blank = $c;
      $start = -1;
    }

    # current is an extra token
    elsif($tok == 2) {
      if($w ne "") {
        if($Verbose > 2) { printf STDERR "Tok2: $number\t$cur-1\t>$w<\t>$blank<\t>$c<\n";}
        $T->{$start}{'tok'} = $w;
        $T->{$start}{'end'} = $cur -1;
        $T->{$start}{'space'} = $blank;
        $T->{$start}{'wnr'} = $number++;
      }
	  else {
        $T->{$cur}{'space'} = $blank;
      }
      if($Verbose > 2) { printf STDERR "Tok2: $number\t$cur\t>$c<\t>$blank<\t><\n";}
#d($T->{$start});
#d($T->{$cur});
      $T->{$cur}{'tok'} = $c;
      $T->{$cur}{'end'} = $cur;
      $T->{$cur}{'wnr'} = $number++;
      $blank=$w = "";
      $start = -1;
      $tok = 1;
    }
    # beginning of new token
    elsif($tok == 3) {
      if($w ne "") {
        $T->{$start}{'tok'} = $w;
        $T->{$start}{'end'} = $cur -1;
        $T->{$start}{'space'} = $blank;
        $T->{$start}{'wnr'} = $number++;
      }
      if($Verbose > 2) { printf STDERR "Tok3: $number\t$cur\t>$w<\t>$blank<\t>$c<\n";}
#d($T->{$start});
      $w = $c;
      $blank = "";
      $start = $cur;
      $tok = 0;
    }
#printf STDERR "Key8: tok:$tok w:$w\t$blank\t$number\n";
  }

#printf STDERR "Key8: $w\t$blank\n";
  # index last token
  if($w ne "") {
      $T->{$start}{'tok'} = $w;
      $T->{$start}{'end'} = $cur;
      $T->{$start}{'space'} = $blank;
      $T->{$start}{'wnr'} = $number;
      if($Verbose >2) {printf STDERR "End$tok: $number\t>$w<\t>$blank<\t>$c<\n";}
  }

  # all chars get a word number 
  foreach $cur (sort {$a <=> $b} keys %{$T}) {
    if(defined($T->{$cur}{'wnr'})) {$number = $T->{$cur}{'wnr'};}
    else {$T->{$cur}{'wnr'} = $number;}
  }
}

sub SentenceSegment {
  my ($Tag) = @_;

  my $seg = 1;
  my $token = 0;
  foreach my $f (sort {$a <=> $b} keys %{$Tag}) {
    if(!defined($Tag->{$f}{'tok'})) { next;}
    if ($Qualitivity == 1) {
#		if(defined($Tag->{$f}{'space'}) && $Tag->{$f}{'space'} =~ /\n/) {print STDERR "SSS$f\n"; d($Tag->{$f})}
		if(defined($Tag->{$f}{'space'}) && $Tag->{$f}{'space'} =~ /\n/) {$seg++;}
		$Tag->{$f}{'seg'} = $seg;
		next;
    }
    if(defined($Tag->{$f}{'space'}) && $Tag->{$f}{'space'} =~ /\n/ && $token > 1) {$token=0; $seg++;}
    $Tag->{$f}{'seg'} = $seg;
    if(defined($Tag->{$f+1}) && $Tag->{$f+1}{c} =~ /^[.?!�|)]$/) {next;}
    if(defined($Tag->{$f+2}) && $Tag->{$f+2}{c} =~ /^[.?!�|)]$/) {next;}
    if(defined($Tag->{$f+3}) && $Tag->{$f+3}{c} =~ /^[.?!�|)]$/) {next;}

    if($Tag->{$f}{'tok'} =~ /^[.?!�|]$/ && $token > 1) { $token=0; $seg++;}
    $token ++;
} }



##########################################################
# Read Translog Logfile
##########################################################

## SourceText Positions
sub ReadTranslog {
  my ($fn) = @_;
  my ($type, $time, $cur);

  my $n = 0;
  my $F = {};
  my ($lastTime, $t, $lastCursor, $c);

#  open(FILE, $fn) || die ("cannot open file $fn");
  open(FILE, '<:encoding(utf8)', $fn) || die ("cannot open file $fn");
#  printf STDERR "ReadTranslog Reading: $fn\n";

  $type = 0;
  while(defined($_ = <FILE>)) {
#printf STDERR "Translog: %s\n",  $_;

#    if($Verbose > 2) { print STDERR "$_";}
    if(/<Description>.*Qualitivity/) { $Qualitivity = 1;}
    if(/<Languages /) {
      if( /source="([^"]*)\"/i) {$SourceLanguage = $1;}
      if( /target="([^"]*)\"/i) {$TargetLanguage = $1;}
    }

    if(/<Events>/) {$type =1; }
    elsif(/<SourceTextChar>/) {$type =2; }
    elsif(/<TranslationChar>/) {$type =3; }
    elsif(/<FinalTextChar>/) {$type =4; }
	
## SourceText Positions
    if($type == 2 && /<CharPos/) {
#print STDERR "Source: $_";
      if(/Cursor="([0-9][0-9]*)"/){$cur =$1;}
      if(/Value="([^"]*)"/)       {$SRC->{$cur}{'c'} = MSunescape($1);}
      if(/X="([0-9][0-9]*)"/)     {$SRC->{$cur}{'x'} = $1;}
      if(/Y="([0-9][0-9]*)"/)     {$SRC->{$cur}{'y'} = $1;}
      if(/Width="([0-9][0-9]*)"/) {$SRC->{$cur}{'w'} = $1;}
      if(/Height="([0-9][0-9]*)"/){$SRC->{$cur}{'h'} = $1;}
#printf STDERR "$SRC->{$cur}{'c'}";
    }
## FinalText Positions
    elsif($type == 4 && /<CharPos/) {
#print STDERR "Final: $_";
      if(/Cursor="([0-9][0-9]*)"/) {$cur =$1;}
      if(/Value="([^"]*)"/)        {$TGT->{$cur}{'c'} = MSunescape($1);}
      if(/X="([0-9][0-9]*)"/)      {$TGT->{$cur}{'x'} = $1;}
      if(/Y="([0-9][0-9]*)"/)      {$TGT->{$cur}{'y'} = $1;}
      if(/Width="([0-9][0-9]*)"/)  {$TGT->{$cur}{'w'} = $1;}
      if(/Height="([0-9][0-9]*)"/) {$TGT->{$cur}{'h'} = $1;}
#if($TGT->{$cur}{'c'} eq "%"){print STDERR '%'. "\t$_";}
#else {printf STDERR "$TGT->{$cur}{'c'}\t$_";}
    } 
    $F->{$n++} = $_;

    if(/<\/FinalText>/) {$type =0; }
    if(/<\/SourceTextChar>/) {$type =0; }
    if(/<\/Events>/) {$type =0; }
    if(/<\/SourceTextChar>/) {$type =0; }
    if(/<\/TranslationChar>/) {$type =0; }
    if(/<\/FinalTextChar>/) {$type =0; }
    if(/<\/FinalText>/) {$type =0; }
  }
  close(FILE);

  return $F;
}

sub ReadTexts {
  my ($fn) = @_;
  my $type = 1;

  open(FILE, '<:encoding(utf8)', $fn) || die ("cannot open file $fn");

  my $S = '';
  my $T = '';
  while(defined($_ = <FILE>)) {

    if(/<Languages /) {
      if( /source="([^"]*)\"/i) {$SourceLanguage = $1;}
      if( /target="([^"]*)\"/i) {$TargetLanguage = $1;}
    }

    elsif(/<SourceText>/) {$type =2;}
    elsif(/<TargetText>/) {$type =3;}

    if($type == 2) { $S .= $_;}
    if($type == 3) { $T .= $_;}
	
    if(/<\/SourceText>/) {$type =1;}
    if(/<\/TargetText>/) {$type =1;}
  }
  close(FILE);
  $S =~ s/.*<SourceText>//;
  $S =~ s/<\/SourceText>.*//;
  $T =~ s/.*<TargetText>//;
  $T =~ s/<\/TargetText>.*//;

  my $L = [split(//, $S)];
  for (my $i=0; $i <= $#{$L}; $i++) {
    $SRC->{$i}{'c'} = MSunescape($L->[$i]);
  }
  $L = [split(//, $T)];
  for (my $i=0; $i <= $#{$L}; $i++) {
    $TGT->{$i}{'c'} = MSunescape($L->[$i]);
  }
  
  return {};
}

sub  WriteTranslog{
  my ($K) = @_;

  my $n=0;
  my $space= '';
  foreach my $f (sort {$a <=> $b} keys %{$K}) { 
    if($K->{$f} =~ /<\/LogFile/) {$n = $f; last;}
  }

  ## Insert Source Token
  $K->{$n++} = " <SourceToken>\n";   
  foreach my $cur (sort {$a <=> $b} keys %{$SRC}) { 
    if(!defined($SRC->{$cur}{'tok'})) { next;}
    if(!defined($SRC->{$cur}{'wnr'})) { 
      print "WriteTranslog: no wnr\n";
      d($SRC->{$cur});
      next;
    }
    if(!defined($SRC->{$cur}{'space'})) { $space = '';}
    else {$space = $SRC->{$cur}{space};}
    $space = MSescapeAttr($space);
    $SRC->{$cur}{tok} = MSescapeAttr($SRC->{$cur}{tok});

    $K->{$n++} = "    <Token id=\"$SRC->{$cur}{wnr}\" cur=\"$cur\" space=\"$space\" tok=\"$SRC->{$cur}{tok}\" />\n";
  }
  $K->{$n++} = " </SourceToken>\n";   

  ## Insert Target Token
  $K->{$n++} = " <FinalToken>\n";   
  foreach my $cur (sort {$a <=> $b} keys %{$TGT}) {
    if(!defined($TGT->{$cur}{'tok'})) { next;}
    if(!defined($TGT->{$cur}{'wnr'})) { 
      print "WriteTranslog: no wnr\n";
      d($TGT->{$cur});
      next;
    }
    if(!defined($TGT->{$cur}{'space'})) { $space = '';}
    else {$space = $TGT->{$cur}{space};}
    $space = MSescapeAttr($space);
    $TGT->{$cur}{tok} = MSescapeAttr($TGT->{$cur}{tok});

    $K->{$n++} = "    <Token id=\"$TGT->{$cur}{wnr}\" cur=\"$cur\" space=\"$space\" tok=\"$TGT->{$cur}{tok}\" />\n";
  }
  $K->{$n++} = " </FinalToken>\n";   
  $K->{$n++} = "</LogFile>\n";   

  ## Write out XML file
  foreach $n (sort {$a <=> $b} keys %{$K}) { print STDOUT $K->{$n}; }
}


## Print DTAG tag format
sub PrintTag {
  my ($fn, $language, $Tag) = @_; 
  my ($f, $s); 

  if(!open(FILE,  ">:encoding(utf8)", $fn)) {
    printf STDERR "cannot open: $fn\n";
    return ;
  }
  if($Verbose){ printf STDERR "Writing: $fn\n";}
#  my $w = 0;

  printf FILE "<Text language=\"$language\" >\n";
  foreach $f (sort {$a <=> $b} keys %{$Tag}) {
#    if($Verbose>2) {printf STDERR "Tag: $f\t";}
    
    if(!defined($Tag->{$f}{'tok'})) { next;}
    if($Verbose>2) {printf STDERR "Tok: $Tag->{$f}{'tok'}\n";}

    $s = '';
#    if(defined($Tag->{$f}{'end'}) && defined($Tag->{$f}{'x'})) {
#      $w = $Tag->{$Tag->{$f}{'end'}}{'x'} + $Tag->{$Tag->{$f}{'end'}}{'w'} - $Tag->{$f}{'x'};
#    }

    $s .= "cur=\"$f\"";
    if(defined($Tag->{$f}{'wnr'})) { $s .= " id=\"$Tag->{$f}{'wnr'}\""; }
    if(defined($Tag->{$f}{'seg'})) { 
	  my $seg = $Tag->{$f}{'seg'};
	  $s .= " segId=\"$seg\"";   
	  $SegID->{$language}{$seg} ++;
    }

      #if(defined($Tag->{$f}{'space'}) && $Tag->{$f}{'space'} ne "") {$s .= " space=\"$Tag->{$f}{'space'}\"";}
    if(defined($Tag->{$f}{'space'}) && $Tag->{$f}{'space'} ne "") {
       my $e = MSescapeAttr($Tag->{$f}{'space'});
       $s .= " space=\"$e\"";
    }
    printf FILE "<W %s>%s</W>\n", $s, MSescapeAttr($Tag->{$f}{'tok'});
  }
  printf FILE "</Text>\n";
  close (FILE);
}


sub PrintAtag {
  my ($fn, $lang1, $lang2) = @_;
  my ($root) = $fn =~ /.*\/Alignment\/(.*)/;
  
  if(!defined($root)) {$root='';}

# printf STDERR "PrintAtag: $fn, $root $lang1, $lang2\n";  

  open(ATAG, '>:encoding(utf8)', "$fn.atag") || die ("cannot open file $fn.atagaaa");

  if($Qualitivity == 1) {printf ATAG "<DTAGalign sent_alignment=\"Qualitivity\" >\n";}
  else {printf ATAG "<DTAGalign sent_alignment=\"casmacat2\" >\n";}
  printf ATAG "    <alignFile key=\"a\" href=\"$root.src\" sign=\"_input\"/>\n";
  printf ATAG "    <alignFile key=\"b\" href=\"$root.tgt\" sign=\"_input\"/>\n";
  for my $seg (sort {$a<=>$b} keys %{$SegID->{$lang1}}) {
    if(!defined($SegID->{$lang2})) { printf STDERR "PrintAtag: unaligned segment $seg\n"; next;}
    printf ATAG "    <salign src=\"$seg\" tgt=\"$seg\"/>\n";
  }
  printf ATAG "</DTAGalign>\n";
  close(ATAG);
}

sub ZH_JA_Tokenize {
  my ($H, $lng) = @_;

# generate the -txt file
  if(open(TMP, ">:encoding(utf8)", "$opt_T.$lng-txt")) {
    foreach my $i (sort {$a <=> $b} keys %{$H}) { print TMP "$H->{$i}{'c'}"; }
  }
  close (TMP);

  if($lng eq 'ja' && ! -e "$opt_T.ja-tok") {
    print "calling $JapaneseTokenizer $opt_T.ja-txt \n";
    system("$JapaneseTokenizer $opt_T.ja-txt");
#    my $ret = `$JapaneseTokenizer $opt_T.ja-txt`;
#    print STDOUT "$ret";
  }
  elsif($lng eq 'zh' ) {
## Lingua tokenizer
#    execute("$ChineseTokenizer < $opt_T.zh-txt > $opt_T.zh-tok1");
## stanford tokenizer
#    execute("$ChineseTokenizer pku $opt_T.zh-txt UTF-8 0 > $opt_T.zh-tok1");
# jiba tokenizer
    print "calling $ChineseTokenizer  $opt_T.zh-txt\n";
    system("$ChineseTokenizer $opt_T.zh-txt");

## this is for the stanford tokenizer
    if(-e "$opt_T.zh-tok1") {
      open(TOKO, ">:encoding(utf8)", "$opt_T.zh-tok");
      if(open(TOK, "<:encoding(utf8)", "$opt_T.zh-tok1")) {
        while(defined(my $T = <TOK>)) {
          $T =~ s/\s+/\tPOS\n/sg;
          print TOKO "$T";
      } }
      close (TOKO);
      close (TOK);
    }
  }

#  unlink "$opt_T.ja-txt";
  return ReadWordTokens("$opt_T.$lng-tok", $H);
}

sub ReadWordTokens {
  my ($fn, $H) = @_;
  
  if(!open(FN, "<:encoding(utf8)", $fn)) {printf STDERR "ReadWordTokens: cannot open file $fn\n";}
  my $cur = 0;
  my $wnr = 1;
  my $seg = 1;
  my $space = '';
  my $tok = ''; 
  my $tag = '';
  my $newSeg = 0;
  while(defined($_ = <FN>)) {
#printf STDERR "ReadWordTokens $_";
#$zzz++;

    while(defined($H->{$cur}) && $H->{$cur}{c} =~ /\s/) {
      $space .= $H->{$cur}{c};
#      printf STDERR "SPACE: cur:$cur\tspace:>$space<\tlen:%d\n", length($H->{$cur}{c});
      $cur += length($H->{$cur}{c});
    }
	## this is a return
    if ($_ =~ /^EOS/) { 
      if($newSeg == 0 ) {$seg ++;}
      $newSeg = 1;
      next;
    }
    ($tok, $tag) = split(/\t+/);

    if(!defined($H->{$cur}{c})) { print STDERR "WARNING: c:$cur\ttok:$tok\n"; d($H->{$cur});}

# skip empty tokens
    if($tok =~ /^\s*$/) {next;}
# replace blanks to make sure each token is only one token ...
    $tok =~ s/\s+/_/g;

#    if($tok eq 'EOS') {$seg ++; $newSeg = 1; next; }

    if($H->{$cur}{c} ne substr($tok,0,1)) { print STDERR "WARN: c:$cur\tk:>$H->{$cur}{c}<\ttok:>$tok<\n";}

    if($Qualitivity == 0) {
        if($space =~ /\n/ && $newSeg == 0) {$seg ++; $newSeg = 1;}
    }
    $H->{$cur}{'space'} = $space;
    $H->{$cur}{'tok'} = $tok;
    $H->{$cur}{'tag'} = $tag;
    $H->{$cur}{'wnr'} = $wnr;
    $H->{$cur}{'seg'} = $seg;

#    printf STDERR "ReadWordTokens:$tok:len:%d\t seg:$seg cur:$cur\tspace:>$space<\tlen:%d\n", length($H->{$cur}{tok}), length($H->{$cur}{space});

    if($Qualitivity == 0) {
        if(ord($tok) == 12290 && $newSeg == 0) {$seg ++; $newSeg = 1;}
	}
    if(ord($tok) != 12290 && $space !~ /\n/) { $newSeg = 0;}

    $space = '';
    $wnr ++;
    $cur += length($tok);
  }
  close (FN);
#  unlink "$seg";

  return $H;
}

sub execute {

    my $cmd = shift;
    `$cmd`;    
    
}
