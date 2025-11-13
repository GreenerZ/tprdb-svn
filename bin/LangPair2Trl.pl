#!/usr/bin/perl -w

use strict;
use open IN  => ":crlf";

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

use Data::Dumper; $Data::Dumper::Indent = 1;
sub d { print STDERR Data::Dumper->Dump([ @_ ]); }

my $usage =
  "Insert Language pair in Translog file\n".
  "Arguments:\n".
  "  -T   <TranslogFile>.xml\n".
  "  -s   source language \n".
  "  -t   target language \n".
  "  -m   task \n".
  "  -r   tracker \n".
  "  -f   overwrite languages tag \n".
  "  Add language pair in Alignment file\n".
  "  -A   <TokenFile>.{src,tgt} \n".
  "  -c   check language definition \n".
  "  -P   path \n".
  "  -h   this help \n".
  "\n";

use vars qw ($opt_P $opt_c $opt_s $opt_r $opt_m $opt_t $opt_f $opt_T $opt_A $opt_v $opt_h);

use Getopt::Std;
getopts ('s:t:m:r:T:P:A:hcfv:');

die $usage if defined($opt_h);
my $languageExists = 0;

if (defined($opt_c) && defined($opt_T)) {CheckLangPair($opt_T, $opt_P);}

my $Force = 0;
my $TransMode = '';
my $Tracker = '';
if (defined($opt_f)) {$Force = 1;}
if (defined($opt_m)) {$TransMode = " task=\"$opt_m\"";}
if (defined($opt_r)) {$Tracker = " tracker=\"$opt_r\"";}

if (defined($opt_T) && defined($opt_s) && defined($opt_t)) {InsertLangPair($opt_T, $opt_s, $opt_t);}
elsif (defined($opt_A) && defined($opt_s)) {InsertLangToken("$opt_A.src", $opt_s);}
elsif (defined($opt_A) && defined($opt_t)) {InsertLangToken("$opt_A.tgt", $opt_t);}
else {print STDERR "nothing\n"}

exit ($languageExists);

sub CheckLangPair {
  my ($fn, $path) = @_;

  if(!open(F,  "<:encoding(utf8)", $fn)) {
    printf STDOUT "cannot open for reading: $fn\n";
    exit 1;
  }

  while(defined($_ = <F>)) {if(/<Languages/) {$languageExists = 1; last;}}
  if($languageExists == 0) {
    printf STDOUT "$fn: No language pair defined\n";
    open(HANDLE, ">>$path/NoLanguages") or die "touch NoLanguages: $!\n";
    close(HANDLE); 
  }
}

sub InsertLangPair {
  my ($fn, $s, $t) = @_;
  
  if(!open(F,  "<:encoding(utf8)", $fn)) {
    printf STDERR "cannot open for reading: $fn\n";
    exit 1;
  }

  printf STDERR "Reading: $fn\n";

  while(defined($_ = <F>)) {

    if(/<Languages/) {
      $languageExists = 1;
	  if($Force) {
          print STDERR "replace:\t$_\tby:\t<Languages source=\"$s\" target=\"$t\"$TransMode$Tracker />\n"; 
    	  print STDOUT "    <Languages source=\"$s\" target=\"$t\"$TransMode$Tracker />\n";
		  next;
	  }
    }
    elsif(/<Plugins/ && $languageExists == 0) { 
    	  print STDOUT "    <Languages source=\"$s\" target=\"$t\"$TransMode$Tracker />\n";
	}
    print STDOUT $_;
  }
  close(F);
}

sub InsertLangToken {
  my ($fn, $lng) = @_;

  if(!open(F,  "<:encoding(utf8)", $fn)) {
    printf STDERR "cannot open for reading: $fn\n";
    exit 1;
  }

  printf STDERR "Reading: $fn\n";

## read alignment file
  while(defined($_ = <F>)) {

    if(/<Text/) {
      if(/language=/) { print STDERR "Warning $_\tdid not substiture\tlanguage=\"$lng\" \n"; }
      else {s/<Text/<Text language=\"$lng\"/; }
    } 
    print STDOUT $_;
  }
  close(F);
}
