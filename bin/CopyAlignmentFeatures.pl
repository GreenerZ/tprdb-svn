#!/usr/bin/perl -w

use strict;
use warnings;
use open IN  => ":crlf";

my $fromFn = '';
my $toFn = '';
my $verbose = 0;
my @Feat = [];
my @Del = [];


my $usage =
  "Copy feature/values for identical Ids from reference file to target file to STDOUT\n".
  "e.g. CopyAlignmentFeatures.pl -f <reference.src> -t <to.src> -F \"lemma,pos\"\n".
  "  -f reference filename\n".
  "  -t target filename\n".
  "  -C feature set to be copied (f1,f2,f3...)\n".
  "  -D feature set to be deleted in target\n".
  "  -v verbose \n".
  "\n";

use vars qw ($opt_f $opt_t $opt_C $opt_D $opt_v $opt_s $opt_h);

use Getopt::Std;
getopts ('f:t:D:C:v:s:h');

die $usage if defined($opt_h);
if (defined($opt_f)) {$fromFn = readSAlignmentFile($opt_f)};
if (defined($opt_t)) {$toFn = $opt_t};
if (defined($opt_C)) {@Feat = split(",", $opt_C)};
if (defined($opt_D)) {@Del = split(",", $opt_D)};
if (defined($opt_v)) {$verbose = $opt_v};


if(!open(FILE, '<:encoding(utf8)', $toFn)) { 
	printf "Cannot open file $toFn\n"; 
}

while(defined($_ = <FILE>)) {
	if(/<W/ && /id="([0-9]+)"/) {
		my $id = $1;
		my $l = $fromFn->{$id};
		if($verbose) {print STDERR "id:$id\t$l\n\tin\t$_";}
# check whether words are identical
		my ($fw) = $l =~ />([^<]+)</;
		my ($tw) = $_ =~ />([^<]+)</;
		if($fw ne $tw) {
			print STDERR "Non-matching word $id:$fw / $tw:\n\ttar:\t$_\tref:\t$l\n";
		}
# check whether segIds are identical
		($fw) = $l =~ /segId="([0-9]+)"/;
		($tw) = $_ =~ /segId="([0-9]+)"/;
		if($fw ne $tw) {
			print STDERR "Non-matching segId $id:$fw / $tw:\n\ttar:\t$_\tref:\t$l\n";
		}

# delete features
		foreach my $f (@Del) {
			if($l =~ /$f="([^"]+)"/) {
				my $v = $1;
				if($verbose) {print STDERR "\tdeleting: $f:$v\n";} 
				if(/$f="([^"]+)"/) {$_ =~ s/$f="[^"]+"//;	}
			}
		}
# copy features
		foreach my $f (@Feat) {
			if($l =~ /$f="([^"]+)"/) {
				my $v = $1;
				if($verbose) {print STDERR "\t$f:$v\n";} 
				if(/$f="([^"]+)"/) {$_ =~ s/$f="[^"]+"/$f="$v"/;	}
				else {s/<W/<W $f="$v"/;}
			}
			else {print STDERR "No feature \"$f\" in reference line: $l";}
		}
	}
	print STDOUT "$_";
}


sub readSAlignmentFile {
	my ($fn) = @_;
	
	my $H = {};

	if(!open(FROM, '<:encoding(utf8)', $fn)) { 
      printf "Cannot open file $fn\n"; 
    }
	while(defined($_ = <FROM>)) {
#		if(/id="([0-9]+)"/) { print STDERR "$1\t$_"};
		if(/id="([0-9]+)"/) { $H->{$1} = $_}
	}  
	close(FROM);
    return $H;
}
