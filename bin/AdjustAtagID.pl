#!/usr/bin/perl -w

use strict;
use warnings;
use open IN  => ":crlf";

my $FromId = 0;
my $ToId = 100000;
my $Add = 0;
my $side = '';

my $usage =
  "Modify Id in atag, src or tgt file: \n".
  "e.g. AdjustAtagID.pl -f20 -a\\-2 -sa < x.atag: maps out=\"a20\" --> out=\"a18\"\n".
  "  -s a/b side in *atag (e.g. a13 -> a15) [$side]\n".
  "  -f from id number [$FromId]\n".
  "  -t to id number [$ToId]\n".
  "  -a add number to id [$Add]\n".
  "\n";

use vars qw ($opt_f $opt_a $opt_t $opt_v $opt_s $opt_h);

use Getopt::Std;
getopts ('f:a:t:v:s:h');

die $usage if defined($opt_h);
if (defined($opt_f)) {$FromId = $opt_f};
if (defined($opt_t)) {$ToId = $opt_t};
if (defined($opt_a)) {$Add = $opt_a};
if (defined($opt_s)) {$side = $opt_s};

while(defined($_ = <STDIN>)) {

  if ($side eq '' && /^\s*<W /) {
    $_ =~ /id="([0-9]+)"/;
    my $id=$1;
    if($id >= $FromId && $id <= $ToId) {
		$id += $Add;
		s/id="([0-9]+)"/id="$id"/;
	}
  }
  elsif (/^\s*<align /) {
    $_ =~ /"$side([0-9]+)"/;
    my $id=$1;
#print STDERR "AA id:$id from:$FromId add:$Add\t$_\n";
    if($id >= $FromId && $id <= $ToId) {
#print STDERR "BB id:$id from:$FromId add:$Add\n";
		$id += $Add;
		s/"$side([0-9]+)"/"$side$id"/;
	}
  }
  print STDOUT "$_";
}
