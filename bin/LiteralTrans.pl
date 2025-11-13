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
  "Generate HTra, HCross, etc for st, tt, sg and au files \n".
  "Options:\n".
  "  -S study/Tables folder \n".
  "  -e translation entropy for T/P/E separatly \n".  
  "  -v verbose mode [0 ... ]\n".
  "  -h this help \n".
  "\n";

use vars qw ($opt_e $opt_S $opt_O $opt_v $opt_h);

use Getopt::Std;
getopts ('S:v:eh');

my $Verbose = 0;
# text index in filename for entropy distinction 
my $SeparateEntropy = "[0-9][0-9]*";
my $TGidIdx = 0;

die $usage if !defined($opt_S);
die $usage if defined($opt_h);

if (defined($opt_v)) {$Verbose = $opt_v;};
if (defined($opt_e)) {$SeparateEntropy = "_[A-Za-z][A-Za-z]*[0-9][0-9]*";};

my $H = ReadStudy("$opt_S");
if(!defined($H->{sg})) {print STDERR "LiteralTrans: no file in $opt_S\n";}
FeatureEntropy ($H, "sgrp");
FeatureEntropy ($H, "tgrp");
FeatureEntropy ($H, "cross");
FeatureEntropy ($H, "stc");
SegEntropy($H);

# computes gaze path entropy
PathEntropy($H, 'au', 'path');
PathEntropy($H, 'pu', 'tgid');

PrintST_TT($H, 'st');
PrintST_TT($H, 'tt');

PrintAU_PU($H, 'au', 'gaze');
PrintAU_PU($H, 'pu', 'tgid');
PrintSG($H);
 
exit;

sub ReadStudy {
    my $study =shift;
    my $H = {};
  
    opendir(DIR, $study) || die "Undefined $study";
    my @FILES= readdir(DIR);
  
    foreach my $file (@FILES){
if($Verbose) {print STDERR "LiteralTrans: ReadStudy $file\n";}

### READ sg file
        if($file =~ /($SeparateEntropy).sg$/) {
            my ($txt) = $file =~ /($SeparateEntropy).sg$/;
            my ($per) = $file =~ /^P([0-9][0-9]*)_/;
            if(!defined($per)) {
              print STDERR "ERROR: $file Text:$per $txt already used $H->{sg}{$txt}{per}{$per}{name}\n";
                 exit;
            }
      
            if(defined($H->{sg}{$txt}{per}{$per})) {
                print STDERR "ERROR: $file Text:$per $txt already used $H->{sg}{$txt}{per}{$per}{name}\n";
                exit;
            }
            open (IN, "$study/$file") || die "Error: cannot open $study/$file $!";
#print STDERR "$file\ttxt:$txt\tper:$per\n";

            $file =~ s/.sg$//;
            $H->{sg}{$txt}{per}{$per}{name} = $file;
            $H->{sg}{$txt}{per}{$per}{study} = $study;
if($Verbose) {print STDERR "$file\ttxt:$txt\tper:$per\t$study\n";}

            my $sg = 0;
            while (<IN>){
                chomp;
                my @L = (split(/\t/));
                if(/^Id/) {
    #print STDERR "ST segment: $_\n";
                    $H->{sg}{$txt}{per}{$per}{header} = $_;
                    for (my $i=0; $i < @L; $i++) {
                        $H->{sg}{$txt}{per}{$per}{index}{$i} = $L[$i];
                    }
                    next;
                }

                for (my $i=0; $i < @L; $i++) {
                    my $val=$H->{sg}{$txt}{per}{$per}{index}{$i};
                    $H->{sg}{$txt}{per}{$per}{sg}{$sg}{value}{$val} = $L[$i];
                }

                my @S = (split(/\+/, $H->{sg}{$txt}{per}{$per}{sg}{$sg}{value}{STseg}));
                for (my $s=0; $s < @S; $s++) {
                    $H->{sg}{$txt}{per}{$per}{STseg}{$S[$s]} = $sg;
                }
                @S = (split(/\+/, $H->{sg}{$txt}{per}{$per}{sg}{$sg}{value}{TTseg}));
                for (my $s=0; $s < @S; $s++) {
                    $H->{sg}{$txt}{per}{$per}{ttseg}{$S[$s]} = $sg;
                }
                $H->{sg}{$txt}{per}{$per}{sg}{$sg}{str} = $_;
    #print STDERR "ST segment: $_\n";
    #d($H->{sg}{$txt}{per}{$per});
                $sg ++;
            }
            close (IN);
        }
    
#####################
## au files
        if($file =~ /($SeparateEntropy).au$/) {
            my ($txt) = $file =~ /($SeparateEntropy).au$/;
            my ($per) = $file =~ /^P([0-9][0-9]*)_/;
            if(defined($H->{au}{$txt}{per}{$per})) {
                print STDERR "ERROR: $file Part:$per Text:$txt already used $H->{au}{$txt}{per}{$per}{name}\n";
                exit;
            }
            open (IN, "$study/$file") || die "Error: cannot open $study/$file $!";
    #print STDERR "$file\ttxt:$txt\tper:$per\n";

            $file =~ s/.au$//;
            $H->{au}{$txt}{per}{$per}{name} = $file;
            $H->{au}{$txt}{per}{$per}{study} = $study;
    if($Verbose) {print STDERR "$file\t$txt:$txt\tper:$per\t$study\n";}

            my $au = 0;
            my $pi = -1;
            my $type = 0;
            while (<IN>){
                chomp;
                my @X = (split(/\s+/, $_));
    # read header line
                if(/^Id/) {
                    $H->{au}{$txt}{per}{$per}{header} = $_;
                    $H->{au}{$txt}{per}{$per}{rows} = scalar(@X);
              #memorize index for Path and Type
                    for (my $i=0; $i < @X; $i++) {
                        if($X[$i] =~ /GazePath/) {$pi = $i; }
                        if($X[$i] =~ /Type/) {$type = $i; }
                    }
                    if($pi == -1) {print STDERR "LiteralTrans.pl AUEntropy: no fix path in AU $txt:$per\n";}
                    next;
                }
                if($H->{au}{$txt}{per}{$per}{rows} != scalar(@X)) {
                    printf STDERR "non-matching number of rows $study$file.au\n--->\t%s\t@X\n\t$H->{au}{$txt}{per}{$per}{rows}\n", scalar(@X);
                next;
                }
    #if($H->{au}{$txt}{per}{$per}{name} eq 'P06_T6') {
    #print STDERR "P06_T6: $pi\t$type\t$X[$pi]\n";
    #}


                $H->{au}{$txt}{per}{$per}{id}{$au}{au} = $_;
                $H->{au}{$txt}{per}{$per}{id}{$au}{path} = $X[$pi];
                $H->{au}{$txt}{per}{$per}{id}{$au}{type} = $X[$type];
                $au++;
            }
            close (IN);
        }

    #####################
    ## pu files
        if($file =~ /($SeparateEntropy).pu$/) {
            my ($txt) = $file =~ /($SeparateEntropy).pu$/;
            my ($per) = $file =~ /^P([0-9][0-9]*)_/;
            if(defined($H->{pu}{$txt}{per}{$per})) {
                print STDERR "ERROR: $file Part:$per Text:$txt already used $H->{pu}{$txt}{per}{$per}{name}\n";
                exit;
            }
            open (IN, "$study/$file") || die "Error: cannot open $study/$file $!";
    #print STDERR "$file\ttxt:$txt\tper:$per\n";


            $file =~ s/.pu$//;
            $H->{pu}{$txt}{per}{$per}{name} = $file;
            $H->{pu}{$txt}{per}{$per}{study} = $study;
    if($Verbose) {print STDERR "$file\t$txt:$txt\tper:$per\t$study\n";}

            my $pu = 0;
            my $sgid = 0;
            my $tgid = 0;
            while (<IN>){
                chomp;
                my @X = (split(/\s+/, $_));
    # read header line
                if(/^Id/) {
                    $H->{pu}{$txt}{per}{$per}{header} = $_;
                    $H->{pu}{$txt}{per}{$per}{rows} = scalar(@X);
              #memorize index for SGid and TGid
                    for (my $i=0; $i < @X; $i++) {
                        if($X[$i] =~ /SGid/) {$sgid = $i; }
                        if($X[$i] =~ /TGid/) {$tgid = $i; }
                    }
                    if($sgid == 0 || ($tgid == 0)) {
                        print STDERR "LiteralTrans.pl PU: no SGid / TGid $sgid:$tgid\n";
                    }
                    next;
                }
                if($H->{pu}{$txt}{per}{$per}{rows} != scalar(@X)) {
                    printf STDERR "non-matching number of rows $study$file.pu\n--->\t%s\t@X\n\t$H->{pu}{$txt}{per}{$per}{rows}\n", scalar(@X);
                    next;
                }
    #if($H->{pu}{$txt}{per}{$per}{name} eq 'P06_T6') {
    #print STDERR "P06_T6: $pi\t$type\t$X[$pi]\n";
    #}

                $H->{pu}{$txt}{per}{$per}{id}{$pu}{pu} = $_;
                $H->{pu}{$txt}{per}{$per}{id}{$pu}{sgid} = $X[$sgid];
                $H->{pu}{$txt}{per}{$per}{id}{$pu}{tgid} = $X[$tgid];
                $pu++;
            }
            close (IN);
        }


    #####################
    ## st and tt files

        if($file =~ /($SeparateEntropy).st$/ || $file =~ /($SeparateEntropy).tt$/) {
            my $ext = 'st';
            if($file =~ /.tt$/) {$ext = 'tt'}
        
            my ($txt) = $file =~ /($SeparateEntropy).[ts]t$/;
            my ($per) = $file =~ /^P([0-9][0-9]*)_/;
          

            if(defined($H->{$ext}{$txt}{per}{$per})) {
                print STDERR "ERROR: $file Part:$per Text:$txt already used $H->{$ext}{$txt}{per}{$per}{name}\n";
                exit;
            }
            open (IN, "$study/$file") || die "Error: cannot open $study/$file $!";

            $file =~ s/.[ts]t$//;
            $H->{$ext}{$txt}{per}{$per}{name} = $file;
            $H->{$ext}{$txt}{per}{$per}{study} = $study;

            if($Verbose > 2) {print STDERR "$study:$file\t$ext\ttxt:$txt\tper:$per\n";}

            my ($SegIdx, $TGroupIdx,  $SGroupIdx, $TokenIdx, $CrossIdx, $TGnbr, $SGnbr);
              
            while (<IN>){
                chomp;
                my @L = (split(/\s+/));
                if($L[0] eq "Id") {
    #print STDERR "$file\t$_\n";
    #d(@L);
                    $H->{$ext}{$txt}{per}{$per}{header} = $_;
                    $H->{$ext}{$txt}{per}{$per}{rows} = @L;
                    for (my $i=0; $i < @L; $i++) {
                        if($L[$i] eq "STseg")     {$SegIdx = $i;} # for st file
                        if($L[$i] eq "TTseg")     {$SegIdx = $i;} # for tt file
                        elsif($L[$i] eq "TGroup") {$TGroupIdx = $i}
                        elsif($L[$i] eq "SGroup") {$SGroupIdx = $i}
                        elsif($L[$i] eq "SToken") {$TokenIdx = $i}
                        elsif($L[$i] eq "TToken") {$TokenIdx = $i}
                        elsif($L[$i] eq "TGid")   {$TGidIdx = $i}
                        elsif($L[$i] eq "Cross")  {$CrossIdx = $i}
                        elsif($L[$i] eq "TGnbr")  {$TGnbr = $i}
                        elsif($L[$i] eq "SGnbr")  {$SGnbr = $i}
                        # old version TAG/SAG
                        elsif($L[$i] eq "TAGnbr")  {$TGnbr = $i}
                        elsif($L[$i] eq "SAGnbr")  {$SGnbr = $i}
                    }
                    next;
                }
        

    #if(!is_number($STseg)) {print STDERR "$file\t$STseg\n";}

                
                if($H->{$ext}{$txt}{per}{$per}{rows} != @L) {
                    print STDERR "non-matching number of rows $study$file.$ext\t@L\n";
                    next;
                }

                my $id = int($L[0]);
                my $seg   = $L[$SegIdx]; #segment
                my $tok  = $L[$TokenIdx]; #target TGroup
                my $tgrp  = $L[$TGroupIdx]; #target TGroup
                my $sgrp  = $L[$SGroupIdx]; #source SGroup
                my $cross = $L[$CrossIdx]; #Cross
                my $tau   = int($L[$TGnbr]); #AU-TTnum
                my $sau   = int($L[$SGnbr]); #AU-STnum
                my $tid   = '---'; #TGid
                # only take the tid from the st files.
                if ($ext eq 'st') {$tid   = $L[$TGidIdx];}


                $tgrp =~ s/^"//;
                $tgrp =~ s/"$//;
                $tgrp =~ tr/A-Z/a-z/;
                $H->{$ext}{$txt}{id}{$id}{tgrp}{$tgrp}{num} ++;
                $H->{$ext}{$txt}{id}{$id}{tgrp}{$tgrp}{per}{$per} ++;
                
                $sgrp =~ s/^"//;
                $sgrp =~ s/"$//;
                $sgrp =~ tr/A-Z/a-z/;
                $H->{$ext}{$txt}{id}{$id}{sgrp}{$sgrp}{num} ++;
                $H->{$ext}{$txt}{id}{$id}{sgrp}{$sgrp}{per}{$per} ++;

                $H->{$ext}{$txt}{id}{$id}{cross}{$cross}{num}++;
                $H->{$ext}{$txt}{id}{$id}{cross}{$cross}{per}{$per} ++;
                
            
            # joint tgrp + cross + AGprobability
                my $stc  = $tgrp . "_|||_" . $cross . "_|||_" . $sgrp;
            #    $H->{$ext}{$txt}{id}{$id}{stc}{$stc}{ag} = $AGweight;
                $H->{$ext}{$txt}{id}{$id}{stc}{$stc}{num}++;
                $H->{$ext}{$txt}{id}{$id}{stc}{$stc}{per}{$per} ++;

            #if($ext eq 'tt' && $H->{tt}{$txt}{per}{$per}{name} eq 'P01_T1') {
            #print STDERR "$H->{tt}{$txt}{per}{$per}{name}\t$id\t$tgrp\n";
            #}
                
                $H->{$ext}{$txt}{id}{$id}{num} ++;

            #    $H->{$ext}{$txt}{per}{$per}{id}{$id}{AGweight} = $AGweight;
                $H->{$ext}{$txt}{per}{$per}{id}{$id}{stc} = $stc;
                $H->{$ext}{$txt}{per}{$per}{id}{$id}{sgrp} = $sgrp;
                $H->{$ext}{$txt}{per}{$per}{id}{$id}{tgrp} = $tgrp;
                $H->{$ext}{$txt}{per}{$per}{id}{$id}{cross} = $cross;
                $H->{$ext}{$txt}{per}{$per}{id}{$id}{seg} = $seg;
                $H->{$ext}{$txt}{per}{$per}{seg}{$seg}{id}{$id} ++;
                $H->{$ext}{$txt}{per}{$per}{id}{$id}{tid} = $tid;
                $H->{$ext}{$txt}{per}{$per}{id}{$id}{token} = $tok;
                $H->{$ext}{$txt}{per}{$per}{id}{$id}{SGnbr} = $sau;
                $H->{$ext}{$txt}{per}{$per}{id}{$id}{TGnbr} = $tau;
                $H->{$ext}{$txt}{per}{$per}{id}{$id}{entry} = $_;

            }
            close (IN);
        }
    }
    closedir(DIR);
    return $H;
}

sub FeatureEntropy {
  my ($H, $F) = @_;
  
  foreach my $txt (sort keys%{$H->{st}}) {
    foreach my $id (sort keys %{$H->{st}{$txt}{id}}) {
      my $e = 0; # entropy per word
      my $alt = 0;
      foreach my $Fval (keys %{$H->{st}{$txt}{id}{$id}{$F}}) {
        my $p = $H->{st}{$txt}{id}{$id}{$F}{$Fval}{num} / $H->{st}{$txt}{id}{$id}{num};
        my $i = $p * log($p)/log(2);
        $e += $i;
        $alt ++;
        
        foreach my $per (keys %{$H->{st}{$txt}{id}{$id}{$F}{$Fval}{per}}) {

# probablity of token translation 
          $H->{st}{$txt}{per}{$per}{id}{$id}{"P" . $F} = $p;
          $H->{st}{$txt}{per}{$per}{id}{$id}{"N" . $F} = $H->{st}{$txt}{id}{$id}{$F}{$Fval}{num};
#if($txt == 6 && $per == 6 && $id == 0) {
#print STDERR "lesen: st txt:$txt\tper:$per\tid:$i DDDD $F $Fval \n";
#d($H->{st}{$txt}{per}{$per}{id}{$id});
#}

        }
      }
      # word translation entropy 
      $H->{st}{$txt}{id}{$id}{"H" . $F} = -1*$e;

      # number of alternative translations
      $H->{st}{$txt}{id}{$id}{"A" . $F} = $alt; 
      
#printf STDERR "TraEntropy\t$txt\t$id\t$H->{st}{$txt}{id}{$id}{Htra}\t$H->{st}{$txt}{id}{$id}{Ntra}\n";
    }
    foreach my $per (sort keys%{$H->{st}{$txt}{per}}) {
      foreach my $id (keys%{$H->{st}{$txt}{per}{$per}{id}}) {
      # copy entropy values to participants 
        $H->{st}{$txt}{per}{$per}{id}{$id}{"H" . $F} = $H->{st}{$txt}{id}{$id}{"H" . $F};
        $H->{st}{$txt}{per}{$per}{id}{$id}{"A" . $F} = $H->{st}{$txt}{id}{$id}{"A" . $F};

        # copy values to tt file
        foreach my $i (split(/\+/, $H->{st}{$txt}{per}{$per}{id}{$id}{tid})) {
          if($i =~ /^\d+$/) {
            $i = int($i);
            if(!defined($H->{tt}{$txt}{per}{$per}{id}{$i})) {
                print STDERR "$H->{st}{$txt}{per}{$per}{name}: No TT index text:$txt per:$per\tsgid:$id\ttgid:$i\n";
#                d($H->{tt}{$txt}{per}{$per}{id});
                next;
            }

            $H->{tt}{$txt}{per}{$per}{id}{$i}{"N" . $F} = $H->{st}{$txt}{per}{$per}{id}{$id}{"N" . $F};
            $H->{tt}{$txt}{per}{$per}{id}{$i}{"P" . $F} = $H->{st}{$txt}{per}{$per}{id}{$id}{"P" . $F};
            $H->{tt}{$txt}{per}{$per}{id}{$i}{"H" . $F} = $H->{st}{$txt}{id}{$id}{"H" . $F};
            $H->{tt}{$txt}{per}{$per}{id}{$i}{"A" . $F} = $H->{st}{$txt}{id}{$id}{"A" . $F};
          }
        }
      }
    } 
  }
}

sub PathEntropy {
  my ($H, $unit, $path) = @_;

  my ($hc, $hs, $ht, $hj, $pc, $ps, $pt, $pj);
  foreach my $txt (keys%{$H->{$unit}}) {
    foreach my $per (keys%{$H->{$unit}{$txt}{per}}) {
      foreach my $id (keys%{$H->{$unit}{$txt}{per}{$per}{id}}) {
        $hc=$hs=$ht=$hj=$pc=$ps=$pt=$pj=0;
        my $n = 0;
        my $i = 0;
        my $win = '';
        
#        print STDERR "PathEntropy: $unit, $path  
#        $H->{$unit}{$txt}{per}{$per}{id}{$id}{$path}\n";
#        d($H->{$unit}{$txt}{per}{$per}{id}{$id});
        $H->{$unit}{$txt}{per}{$per}{id}{$id}{$path} =~ s/\"//g;
        foreach my $fix (split(/\+/, $H->{$unit}{$txt}{per}{$per}{id}{$id}{$path})) {
          if($fix eq '---') {next;}
          # PU path  (keystrokes)
          if($fix =~ /^(\d+)$/) { $win='T'; $i = int($1);}
          # AU path (Gaze path
          elsif($fix =~ /^([TS]):(\d+)$/) { $win=$1; $i = int($2);}
          else {
            print STDERR "PathEntropy: invalid item $H->{st}{$txt}{per}{$per}{name}: \tAUid:$id SGid:$fix \t$path:$H->{$unit}{$txt}{per}{$per}{id}{$id}{$path}\n";
            next;
          }
          $n++;

          if($win eq 'S') {

            if(!defined($H->{st}{$txt}{per}{$per}{id}{$i}{Htgrp})) {
                print STDERR "AuEntropy: $H->{st}{$txt}{per}{$per}{name}: \tAUid:$id SGid:$i \tpath:$H->{$unit}{$txt}{per}{$per}{id}{$id}{$path}\n";
                d($H->{$unit}{$txt}{per}{$per}{id}{$id});

                print STDERR "STentry: $i\n";
                d($H->{st}{$txt}{per}{$per}{id}{$i});

                next;
            }
            
            $ps += $H->{st}{$txt}{per}{$per}{id}{$i}{Psgrp};
            $pt += $H->{st}{$txt}{per}{$per}{id}{$i}{Ptgrp};
            $pc += $H->{st}{$txt}{per}{$per}{id}{$i}{Pcross};
            $pj += $H->{st}{$txt}{per}{$per}{id}{$i}{Pstc};

            $hs += $H->{st}{$txt}{per}{$per}{id}{$i}{Hsgrp};
            $ht += $H->{st}{$txt}{per}{$per}{id}{$i}{Htgrp};
            $hc += $H->{st}{$txt}{per}{$per}{id}{$i}{Hcross};
            $hj += $H->{st}{$txt}{per}{$per}{id}{$i}{Hstc};
          }
          if($win eq 'T') {
            if(!defined($H->{tt}{$txt}{per}{$per}{id}{$i})) {next;}
            if(!defined($H->{tt}{$txt}{per}{$per}{id}{$i}{Psgrp})) {next;}
            if(!defined($H->{tt}{$txt}{per}{$per}{id}{$i}{Psgrp})) {
                print STDERR "Path $unit TT:$txt per:$per i:$i\n";
                d($H->{tt}{$txt}{per}{$per}{id}{$i});
            }
            
            $ps += $H->{tt}{$txt}{per}{$per}{id}{$i}{Psgrp};
            $pt += $H->{tt}{$txt}{per}{$per}{id}{$i}{Ptgrp};
            $pc += $H->{tt}{$txt}{per}{$per}{id}{$i}{Pcross};
            $pj += $H->{tt}{$txt}{per}{$per}{id}{$i}{Pstc};

            $hs += $H->{tt}{$txt}{per}{$per}{id}{$i}{Hsgrp};
            $ht += $H->{tt}{$txt}{per}{$per}{id}{$i}{Htgrp};
            $hc += $H->{tt}{$txt}{per}{$per}{id}{$i}{Hcross};
            $hj += $H->{tt}{$txt}{per}{$per}{id}{$i}{Hstc};
          }
        }
        if($n > 0) {

          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Psgrp} = $ps / $n;
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Ptgrp} = $pt / $n;
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Pcross} = $pc / $n;
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Pstc} = $pj / $n;
          
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Hsgrp} = $hs / $n;
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Htgrp} = $ht / $n;
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Hcross} = $hc / $n;
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Hstc} = $hj / $n;
        }
        else {
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Psgrp} = 0;
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Ptgrp} = 0;
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Pcross} = 0;
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Pstc} = 0;
          
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Hsgrp} = 0;
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Htgrp} = 0;
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Hcross} = 0;
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Hstc} = 0;
        }
      }
    }
  }
}



sub SegEntropy {
  my ($H) = @_;

  foreach my $txt (sort keys %{$H->{sg}}) {
    foreach my $per (sort {$a<=>$b} keys %{$H->{sg}{$txt}{per}}) {  
#printf STDERR "$H->{sg}{$txt}{per}{$per}{name}\n";
            
      foreach my $idx (sort {$a<=>$b} keys %{$H->{sg}{$txt}{per}{$per}{sg}}) {
        my $HTOT = {};
        my $num = 0;

        my $stLen = $H->{sg}{$txt}{per}{$per}{sg}{$idx}{value}{TokS};
        my $Pcross = 0;
        my $Psgrp = 0;
        my $Ptgrp = 0;
        my $Pstc = 0;
        my $SGnbr = 0;
        my $TGnbr = 0;
        my $Cross = 0;
        foreach my $sseg (split(/\+/, $H->{sg}{$txt}{per}{$per}{sg}{$idx}{value}{STseg})) {
            foreach my $id (sort {$a<=>$b} keys %{$H->{st}{$txt}{per}{$per}{seg}{$sseg}{id}}) {
#printf STDERR "$H->{st}{$txt}{per}{$per}{id}{$id}{token} ";
                $Psgrp += log($H->{st}{$txt}{per}{$per}{id}{$id}{Psgrp}) / log(2);
                $Ptgrp += log($H->{st}{$txt}{per}{$per}{id}{$id}{Ptgrp}) / log(2);
                $Pstc  += log($H->{st}{$txt}{per}{$per}{id}{$id}{Pstc}) / log(2);
                $Pcross += log($H->{st}{$txt}{per}{$per}{id}{$id}{Pcross}) / log(2);
                $SGnbr += $H->{st}{$txt}{per}{$per}{id}{$id}{SGnbr};
                $TGnbr += $H->{st}{$txt}{per}{$per}{id}{$id}{TGnbr};
                $Cross += abs($H->{st}{$txt}{per}{$per}{id}{$id}{cross});
#                #total entropy
                foreach my $stc (keys %{$H->{st}{$txt}{id}{$id}{stc}}) {
                  $HTOT->{$stc} += $H->{st}{$txt}{id}{$id}{stc}{$stc}{num};
                  $num += $H->{st}{$txt}{id}{$id}{stc}{$stc}{num};
                }
            }
        }
        ## avoid devision by 0
        if($stLen == 0) { $stLen = 1;}
        if($num == 0) { $num = 1;}
        
        $H->{sg}{$txt}{per}{$per}{sg}{$idx}{Isgrp}  = -1 * $Psgrp / $stLen;
        $H->{sg}{$txt}{per}{$per}{sg}{$idx}{Itgrp}  = -1 * $Ptgrp / $stLen;
        $H->{sg}{$txt}{per}{$per}{sg}{$idx}{Istc}   = -1 * $Pstc / $stLen;
        $H->{sg}{$txt}{per}{$per}{sg}{$idx}{Icross} = -1 * $Pcross / $stLen;
        $H->{sg}{$txt}{per}{$per}{sg}{$idx}{SGnbr} = $SGnbr / $stLen;
        $H->{sg}{$txt}{per}{$per}{sg}{$idx}{TGnbr} = $TGnbr / $stLen;
        $H->{sg}{$txt}{per}{$per}{sg}{$idx}{Cross} = $Cross / $stLen;
        
        my $e = 0;
        for my $stc (keys %{$HTOT}) {
          my $p = $HTOT->{$stc} / $num;
          my $i = $p * log($p)/log(2);
          $e += $i;
        }
        if($e && $num) {
            $H->{sg}{$txt}{per}{$per}{sg}{$idx}{HTot} = -1*$e;
            $H->{sg}{$txt}{per}{$per}{sg}{$idx}{HTotN} = -1*$e * log(2) / log($num);
        }
        else {
            $H->{sg}{$txt}{per}{$per}{sg}{$idx}{HTot} = 0;
            $H->{sg}{$txt}{per}{$per}{sg}{$idx}{HTotN} = 0;
      } }

    }

  }
}

######################################
# Print ST file
######################################

sub PrintST_TT {
  my ($H, $unit) = @_;
  
  foreach my $txt (sort keys%{$H->{$unit}}) {

    foreach my $per (sort {$a<=$b} keys%{$H->{$unit}{$txt}{per}}) {
      my $study = $H->{$unit}{$txt}{per}{$per}{study};

if(!defined($H->{$unit}{$txt}{per}{$per}{name})) {
print STDERR "undefined filname: text:$txt per:$per\n";
d($H->{$unit}{$txt}{per}{$per});
next;
}

      my $file  = "$H->{$unit}{$txt}{per}{$per}{name}";

      open (STH, ">$study/$file.$unit") || die "Error: cannot open $study/$file.$unit $!";

      if($Verbose) {printf STDERR "LiteralTrans.pl writing $study/$file.$unit\n";}
      printf STH 
      "$H->{$unit}{$txt}{per}{$per}{header}\tAltT\tCountT\tProbT\tHTra\tAltS\tProbS\tHSgrp\tAltC\tProbC\tHCross\tAltSTC\tProbSTC\tHSTC\n";
      foreach my $id (sort {$a<=>$b} keys%{$H->{$unit}{$txt}{per}{$per}{id}}) {
        if(!defined($H->{$unit}{$txt}{per}{$per}{id}{$id}{Hstc})) {
            printf STH "%s\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\n",
                $H->{$unit}{$txt}{per}{$per}{id}{$id}{entry};
            next;
        }
#print STDERR "$H->{$unit}{$txt}{per}{$per}{name} text:$txt per:$per\n";
#d($H->{$unit}{$txt}{per}{$per}{id}{$id});

        printf STH "%s\t%4d\t%4d\t%4.4f\t%4.4f\t%4d\t%4.4f\t%4.4f\t%4d\t%4.4f\t%4.4f\t%4d\t%4.4f\t%4.4f\n", 
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{entry},    # available data from the table
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Atgrp},
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Ntgrp},
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Ptgrp}, 
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Htgrp},
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Asgrp},
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Psgrp},
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Hsgrp},
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Across},
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Pcross},
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Hcross},
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Astc},
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Pstc},
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Hstc};
      }
      close (STH);      
  } }
}

######################################
# Print PU and AU file
sub PrintAU_PU {
  my ($H, $unit, $F) = @_;
  
  foreach my $txt (sort keys%{$H->{$unit}}) {
    foreach my $per (sort {$a<=$b} keys%{$H->{$unit}{$txt}{per}}) {
      my $study = $H->{$unit}{$txt}{per}{$per}{study};
      my $file  = "$H->{$unit}{$txt}{per}{$per}{name}";

      open (AUH, ">$study/$file.$unit") || die "Error: cannot open $study/$file.$unit $!";

      if($Verbose) {printf STDERR "LiteralTrans.pl writing $study/$file.$unit\n";}
      
      printf AUH "$H->{$unit}{$txt}{per}{$per}{header}\tProbS$F\tProbT$F\tProbC$F\tProbSTC$F\tHS$F\tHT$F\tHC$F\tHSTC$F\n";
        
      foreach my $id (sort {$a<=>$b} keys%{$H->{$unit}{$txt}{per}{$per}{id}}) {

        printf AUH "%s\t%4.4f\t%4.4f\t%4.4f\t%4.4f\t%4.4f\t%4.4f\t%4.4f\t%4.4f\n",        
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{$unit},

          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Psgrp},
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Ptgrp},
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Pcross},
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Pstc},
          
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Hsgrp},
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Htgrp},
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Hcross},
          $H->{$unit}{$txt}{per}{$per}{id}{$id}{Hstc};
        
      }
      close (AUH);      
  } }
}


######################################
# Print SG file

sub PrintSG {
  my ($H) = @_;
  
  foreach my $txt (sort keys %{$H->{sg}}) {
    foreach my $per (sort {$a<=>$b} keys %{$H->{sg}{$txt}{per}}) {

      my $study = $H->{sg}{$txt}{per}{$per}{study};
      my $file  = "$H->{sg}{$txt}{per}{$per}{name}";

      open (SGL, ">$study/$file.sg") || die "Error: cannot open $study/$file.sg $!";
      printf SGL "$H->{sg}{$txt}{per}{$per}{header}\tTGnbrMean\tSGnbrMean\tCrossSMean\tISseg\tITseg\tICseg\tISTCseg\tHTot\tHTotN\n";

      if($Verbose) {printf STDERR "LiteralTrans.pl writing $study/$file.sg\n";}
      foreach my $idx (sort {$a<=>$b} keys %{$H->{sg}{$txt}{per}{$per}{sg}}) {

        printf SGL "%s\t%4.2f\t%4.2f\t%4.2f\t%4.2f\t%4.2f\t%4.2f\t%4.2f\t%4.2f\t%4.2f\n", 
			$H->{sg}{$txt}{per}{$per}{sg}{$idx}{str},
			$H->{sg}{$txt}{per}{$per}{sg}{$idx}{TGnbr},
			$H->{sg}{$txt}{per}{$per}{sg}{$idx}{SGnbr},
			$H->{sg}{$txt}{per}{$per}{sg}{$idx}{Cross},
			$H->{sg}{$txt}{per}{$per}{sg}{$idx}{Isgrp},
			$H->{sg}{$txt}{per}{$per}{sg}{$idx}{Itgrp},
			$H->{sg}{$txt}{per}{$per}{sg}{$idx}{Icross},
			$H->{sg}{$txt}{per}{$per}{sg}{$idx}{Istc},
			$H->{sg}{$txt}{per}{$per}{sg}{$idx}{HTot},
			$H->{sg}{$txt}{per}{$per}{sg}{$idx}{HTotN};

      }
      close (SGL);
    }
  }
}
