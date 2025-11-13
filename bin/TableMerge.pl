#!/usr/bin/perl -w

use strict;
use warnings;
use Data::Dumper; $Data::Dumper::Indent = 1;
sub d { print STDERR Data::Dumper->Dump([ @_ ]); }


my $usage =
  "Merge files to tables: \n".
  "  -P: path to tables folder\n".
  "  -M: file to merge\n".
  "  -S: file suffixes\n".
  "Options:\n".
  "  -v verbose mode [0 ... ]\n".
  "  -h this help \n".
  "\n";

use vars qw ($opt_P $opt_S $opt_M $opt_f $opt_p $opt_v $opt_h);

use Getopt::Std;
getopts ('P:S:M:p:k:v:h');

die $usage if defined($opt_h);
die $usage if !defined($opt_P);
die $usage if !defined($opt_S);
die $usage if !defined($opt_M);

my $suf = $opt_S;

	die $usage if !opendir(DIR, "$opt_P/");
	my @TABLE= readdir(DIR); 
	closedir(DIR);
    
	my $H = {};
	open(FILE, '<:encoding(utf8)', "$opt_M") || die ("cannot open file $opt_M");
	while(defined(my $in = <FILE>)) {
		chomp($in);
		$in =~ s/^([-]*\w*)\s*//;
		my $i = $1;
		if($suf =~ /st$/) { 
			$in =~ s/^([-]*\w*)\s*//;
			my $j = $1;
			$H->{$i}{$j} = $in;
		}
		else { $H->{$i} = $in;}
#print STDERR "XXX3 $i\t$in\n";
	}
	close(FILE);
			
    foreach my $tab (@TABLE) { 
        if($tab =~ /$suf$/) {
			my $n=0;
			my $X = {};
print STDERR "TableMerge: $opt_P/$tab\n";
			open(FILE, '<:encoding(utf8)', "$opt_P/$tab") || die ("cannot open file $opt_P/$tab");
			while(defined(my $in = <FILE>)) {
				chomp($in);
				$in =~ s/\s*$//;

				if($suf =~ /st$/) { 
					my ($i, $j); 
					$in =~ /^([-]*\w*)\s*([-]*\w*)/;
					$i=$1; $j=$2;

					if($n == 0) {
						if(!defined($H->{$i}{$j})) {print STDERR "Undefined first header feature $i->$j in $opt_M\n"; exit;}
						if($in =~ /$H->{$i}{$j}/) {print STDERR "Already defined feature  $H->{$i}{$j}\n"; last;}
						$X->{$n} = "$in\t$H->{$i}{$j}";
					}
					else {
						if(defined($H->{$i}{$j})) {$X->{$n} = "$in\t$H->{$i}{$j}";}
						else {$X->{$n} = "$in\t$H->{-1}{-1}"; }
				}	}
				else {
					$in =~ /^(\w*)/;
					my $i = $1;
					if($n == 0) {
						if(!defined($H->{$i})) {print STDERR "Undefined header feature $i in  $opt_M\n"; exit;}
						if($in =~ /$H->{$i}/) {print STDERR "Already defined feature  $H->{$i}\n"; last;}
						$X->{$n} = "$in\t$H->{$i}";
					}
					else {
						if(defined($H->{$i})) {$X->{$n} = "$in\t$H->{$i}";}
						else {$X->{$n} = "$in\t$H->{-1}"; }
				}	}
#print STDERR "XXX7 $n\n";
				$n++;
			}
			close(FILE);

			open(FILE, '>:encoding(utf8)', "$opt_P/$tab") || die ("cannot open file $opt_P/$tab");
		    foreach my $n (sort {$a<=>$b} keys %{$X}) {print FILE "$X->{$n}\n";}
			close (FILE);
		}
	}
