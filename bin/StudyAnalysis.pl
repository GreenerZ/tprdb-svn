#!/usr/bin/perl -w

use strict;
use warnings;
use File::Find;
use File::Copy;
use File::Path qw(make_path remove_tree);
use File::stat;

use Data::Dumper; $Data::Dumper::Indent = 1;
sub d { print STDERR Data::Dumper->Dump([ @_ ]); }

# all tprdb studies:
#my @studies = qw(ACS08 ADU17 AE17 ALG14 AR19 AR20 ARMT19 BACK2020 BB17 BD08 BD13 BML12 CEMPT13 CET6 CFT12 CFT13 CFT14 CPH17 CS19 DG01 EFT14 ENDU20 ENDU20-MT ENJA15 ENTP19 ESMT19 GS12 GV18 HF12 HLR13 HNUJd HNUJml HNUJms IMBi18 IMBi18bolt IMBst18 IMBst18bolt JAMT19 JIN15 JLG10 JN13 JTD16 KTHJ08 LS14 LWB09 MP16 MPM16 MS12 MS13 NJ12 OCT13 PFT13 PFT14 RH12 ROBOT14 RUC16 RUC17 RUCMT17 SG12 SJM16 SPC15 ST19 STC17 STC17bolt STCM17 STML18 STML18bolt TDA14 WARDHA13 XIANG19 ZHMT19 ZHPT12);
#my @studies = qw(ACS08 ADU17 AE17 ALG14 AR19 AR20 ARMT19 BACK2020 BB17 BD08 BD13 BML12 BML12_MT_SA BML12_MT_SI BML12_MT_SM BML12_NTO_SA BML12_NTO_SI BML12_NTO_SM BML12_re BML12_SA BML12_SI BML12_SM CEMPT13 CET6 CFT12 CFT13 CFT14 CPH17 CS19 DG01 EFT14 ENDU20 ENDU20-MT ENJA15 ENTP19 ESMT19 Events GS12 GV18 HF12 HLR13 HNUJd HNUJml HNUJms IMBi18 IMBi18bolt IMBst18 IMBst18bolt JAMT19 JIN15 JLG10 JN13 JTD16 KTHJ08 LS14 LWB09 MP16 MPM16 MS12 MS13 NJ12 OCT13 PFT13 PFT14 predict20 predict20-MT RH12 ROBOT14 RUC16 RUC17 RUCMT17 SG12 SJM16 SPC15 ST19 STC17 STC17bolt STML18 STML18bolt TDA14 WARDHA13 XIANG19 ZHMT19 ZHPT12);

# 28 Sept 2024
my @studies = qw(ACS08 ADU17 AE17 ALG14 AR19 AR20 ARMT19 ATJA22 ATZH22 AU20 BACK2020 BB17 BD08 BD13 BITEXT_07092023 BML12 BML12_MT_SA BML12_MT_SI BML12_MT_SM BML12_NTO_SA BML12_NTO_SI BML12_NTO_SM BML12_re BML12_SA BML12_SI BML12_SM CEMPT13 CET6 CFT12 CFT13 CFT14 CPH17 CREATIVE CREATIVE2 CS19 DG01 DG21 DG21error EFT14 ENDU20 ENDU20-MT ENJA15 ENTP19 ESMT19 GS12 GV18 HE17 HF12 HLR13 HNUJd HNUJml HNUJms IMBi18 IMBi18bolt IMBst18 IMBst18bolt JAMT19 JIN15 JLG10 JN13 JTD16 KTHJ08 lecontra LiTian2019New LS14 LWB09 MAecho2019 MP16 MPM16 MS12 MS13 NEUROTRAD_2 NJ12 OCT13 PFT13 PFT14 predict20 predict20-MT RH12 ROBOT14 RUC16 RUC17 RUCMT17 SG12 SJM16 SPC15 ST19 STC17 STC17bolt STML18 STML18bolt TDA14 WARDHA13 XIANG19 ZHMT19 ZHPT12);


my @translog = qw(ACS08 ADU17 AE17 ALG14 AR19 AR20 ARMT19 ATJA22 ATZH22 AU20 BACK2020 BB17 BD08 BD13 BITEXT_07092023 BML12 BML12_MT_SA BML12_MT_SI BML12_MT_SM BML12_NTO_SA BML12_NTO_SI BML12_NTO_SM BML12_re BML12_SA BML12_SI BML12_SM CEMPT13 CET6 CPH17 CREATIVE CREATIVE2 CS19 DG01 DG21 DG21error EFT14 ENDU20 ENDU20-MT ENJA15 ENTP19 ESMT19 GS12 GV18 HE17 HF12 HLR13 HNUJd HNUJml HNUJms IMBi18 IMBi18bolt IMBst18 IMBst18bolt JAMT19 JIN15 JLG10 JN13 JTD16 KTHJ08 lecontra LiTian2019New LWB09 MAecho2019 MP16 MPM16 MS12 MS13 NEUROTRAD_2 NJ12 13-Oct PFT13 PFT14 predict20 predict20-MT RH12 ROBOT14 RUC16 RUC17 RUCMT17 SG12 SJM16 SPC15 ST19 STC17 STC17bolt STML18 STML18bolt TDA14 WARDHA13 XIANG19 ZHMT19 ZHPT12);

my @studiesM = qw(ACS08 ALG14 BB17 BD08 BD13 CEMPT13 CFT12 CFT13 CFT14 DG01 EFT14 GS12 HF12 HLR13 HNUJ IMBi18 IMBst18 JIN15 JLG10 JN13 JTD16 LS14 LWB09 MP16 MPM16 MS13 OCT13 PFT13 PFT14 RH12 ROBOT14 RUC16 SJM16 SPC15 STCM17 TDA14 WARDHA13 ZHPT12);


#my @multiLing = qw(ADU17 AR19 ARMT19 BML12 CS19 ENDU20 ENDU20-MT ENJA15 ESMT19 HNUJml JAMT19 KTHJ08 MP16 MPM16 MS12 NJ12 RUC17 RUCMT17 SG12 SJM16 SPC15 STC17 STC17bolt STCM17 STML18 STML18bolt TDA14 WARDHA13 ZHMT19);

my @multiLing = qw(ADU17 AR19 ARMT19 BACK2020 BML12 BML12_MT_SA BML12_MT_SI BML12_MT_SM BML12_NTO_SA BML12_NTO_SI BML12_NTO_SM BML12_re BML12_SA BML12_SI BML12_SM CS19 ENDU20 ENDU20-MT ENJA15 ESMT19 HF12 HNUJml JAMT19 KTHJ08 MP16 MPM16 MS12 NJ12 RUC17 RUCMT17 SG12 SJM16 STC17 STC17bolt STML18 STML18bolt TDA14 WARDHA13 ZHMT19);

my @multiLing6 = qw(BML12 ENJA15 KTHJ08 MS12 NJ12 RUC17 SG12);

my @ministerSpeech = qw(IMBi18 IMBi18bolt IMBst18 IMBst18bolt ST19 XIANG19);

my @missionStatements = qw(GV18 JTD16 HNUJms ENTP19);

my @casmacat  = qw(CFT12 CFT13 CFT14 LS14 CEMPT13);


use vars qw (
$opt_a 
$opt_b 
$opt_c 
$opt_C 
$opt_f 
$opt_g 
$opt_h
$opt_i 
$opt_m 
$opt_p 
$opt_S 
$opt_T 
$opt_U 
$opt_V 
$opt_x 
$opt_v 
$opt_Y 
);

use Getopt::Std;
getopts ('C:cS:U:Y:T:x:l:a:mb:p:f:iv:c:h');

my $Command = '';
my $Study = '';
my $buildTables = 'et';
my $DBversion = '';
my $initialToken = ''; # value ' -i';
my $User = '';
my $yawatBase = '/data/critt/yawat/';
my $tprdbBase = '/data/critt/tprdb/';
my $AUgap = 1000;
my $AUgaze = 250;
my $PUgap = 1000;
my $FUgap = 400;
my $Verbose = 0;
my $exeption = '';
my $CrittTokenizer = 0;
my $Configuration = "/data/critt/tprdb/bin/StudyAnalysis.cfg";

if (defined($opt_h)) {Usage("");}
if (defined($opt_x)) {$Configuration = $opt_x;}
# execute the Config file
CFGfile($Configuration);

if (defined($opt_a)) {$AUgap = $opt_a;}
if (defined($opt_b)) {$buildTables = $opt_b;}
if (defined($opt_C)) {$Command = $opt_C;}
if (defined($opt_c)) {$CrittTokenizer = 1;}
if (defined($opt_f)) {$FUgap = $opt_f;}
if (defined($opt_g)) {$AUgaze = $opt_g;}
if (defined($opt_i)) {$initialToken = ' -i';}
if (defined($opt_p)) {$PUgap = $opt_p;}
if (defined($opt_m)) {$exeption = "-e";}
if (defined($opt_S)) {$Study = $opt_S;}
if (defined($opt_T)) {$tprdbBase = $opt_T;}
if (defined($opt_U)) {$User = $opt_U;}
if (defined($opt_V)) {$DBversion = $opt_V;}
if (defined($opt_v)) {$Verbose = $opt_v;}
if (defined($opt_Y)) {$yawatBase = $opt_Y;}


sub Usage {
    my ($s) = @_;

    print "$s\n";
    print "Manipulation/generation of the TPR-DB\n";
    print "Usage ./StudyAnalysis.pl -C command -S study [options]\n";
    print "Options:\n";
    print "-C command:\t one of: [tokenize | tables | tprdb | TER | annotate | yawat | taway | literal]\n";
    print "-S study:\t study name <'tprdb' | 'casmacat' | 'multiLing' | 'superLing' | study > (all commands)\n";
    print "-U User:\t user name \n";
    print "-Y yawat base:\t [$yawatBase] \n";
    print "-T tprdb base:\t [$tprdbBase] \n";
    print "-b tables:\t build tables <[e:events | t:tables | f:force] default: et> (command: tables) \n";
    print "-V version:\t version suffix for TPR-DB (command: tprdb) \n";
    print "-c use Critt Tokenizer [$CrittTokenizer])\n";
    print "-a AU pause (AU tables [$AUgap])\n";
    print "-g AU gaze merge (AU tables [$AUgaze])\n";
    print "-p PU threshold (PU tables [$PUgap])\n";
    print "-f FU threshold (FU tables [$FUgap])\n";
    print "-m toknization exception [$FUgap])\n";

    exit 1;
}


sub Tokenize {
    my $study = shift;

    my $trl = "$study/Translog-II/";
    my $aln = "$study/Alignment/";

    print $trl."\n";
    opendir(DIR, $trl);
    my @FILES= sort readdir(DIR);

    foreach my $file (@FILES){
        if ($file =~ /^\./ ) {next; }
        if ($file !~ /xml$/i ) {next; }

        my $root = $file;
        if ($root=~ s/\.xml//i) {

            if ( not -e $aln){ make_path $aln or die "Directory creation failed: $!"; }
            if(($buildTables !~ /f/) && 
               (stat("$aln$root.src") || stat("$aln$root.tgt") || stat("$aln$root.atag"))){ 
                print "Tokenize: tokenization skipped because file exists $aln$root.{src,tgt,atag}\n";
                next; 
            }

            my $type = LogFileType("$trl$file");
            if ($type eq "casmacat-1"){
              print "./TokenizeCasmacat.pl -T $trl$file -D $aln$root\n";
              execute("perl ./TokenizeCasmacat.pl -T $trl$file -D $aln$root");
            }
            elsif ($type eq "casmacat-2"){
              print "./TokenizeCasmacat2.pl -T $trl$file -D $aln$root $initialToken\n";
              execute("perl ./TokenizeCasmacat2.pl -T $trl$file -D $aln$root $initialToken");
            }
            elsif ($type eq "casmacat-3"){
              print "./TokenizeCasmacat2.pl -T $trl$file -D $aln$root casmacat-2\n";
              execute("perl ./TokenizeCasmacat2.pl -T $trl$file -D $aln$root");
            }
            else {
              print "./Tokenize.pl -T flag $CrittTokenizer $trl$file -D $aln$root\n";
              if($CrittTokenizer) {
                print "./Tokenize.pl -T $trl$file -D $aln$root\n";
                system("perl ./Tokenize.pl -T $trl$file -D $aln$root");
              }
              else {
                print "export STANZA_RESOURCES_DIR=/data/critt/tprdb/bin/stanza_resources\n";
                print "python3 ./Translog-Tokenizer-v0.1.py $exeption $trl$file $aln$root \n";
                system("export STANZA_RESOURCES_DIR=/data/critt/tprdb/bin/stanza_resources && /bin/python3 ./Translog-Tokenizer-v0.1.py $exeption $trl$file $aln 2>&1 | more");
            }  }

        }
    }
    closedir(DIR);
}

sub MergeEvents{
    my $study = shift;
    my $dir = "$study/Events/";
    my $trans_path = "$study/Translog-II/";
	
    if ( not -e "$study"){
       print "MergeEvents: $study does not exist\n";
	   return;
    }
    if ( not -e $dir){
       make_path $dir or die "Directory creation failed: $!";
    }
    opendir(DIR,$trans_path);
    my @FILES= sort readdir(DIR);
    closedir(DIR);

    foreach my $file (@FILES){
        if ($file=~ m/\.xml$/i){
            my $temp_path = $trans_path.$file;
            my $log_path = $temp_path;
            $temp_path =~ s/\.xml$//;
            my $outp = $temp_path;
            $outp =~ s/Translog-II/Events/i;
            my $atag = $temp_path;
            $atag =~ s/Translog-II/Alignment/;
			
            if ( older_than($log_path,$outp.".Event.xml") 
                   and older_than($atag.".atag",$outp.".Event.xml")
                   and older_than($atag.".src",$outp.".Event.xml")
                   and older_than($atag.".tgt",$outp.".Event.xml")
                   )
            {
                print "Keymapping skipping: $outp.Events.xml\n";
                next;
            }
           
            my $type = LogFileType("$log_path");

            if ($type eq "elan"){
              print "./KeyMapping-Elan.pl -T $outp.Atag.xml -O $outp.Event.xml \n";
              execute("perl ./KeyMapping-Elan.pl -T $log_path -A $atag -O $outp.Event.xml");
            }
			else {
            print "MergeAtagTrl.pl -T $log_path -A $atag -O $outp.Atag.xml\n";
              execute("perl ./MergeAtagTrl.pl -T $log_path -A $atag -O $outp.Atag.xml");
			}
            
            if ($type eq "casmacat-1"){
              print "KeyMapping-Casmacat1.pl -T $outp.Atag.xml -O $outp.Event.xml\n";
              execute("perl ./KeyMapping-Casmacat1.pl -T $outp.Atag.xml -O $outp.Event.xml");
            }

            elsif ($type eq "casmacat-2"){
              print "KeyMapping-Casmacat2.pl -T $outp.Atag.xml -O $outp.Event.xml\n";
              execute("perl ./KeyMapping-Casmacat2.pl -T $outp.Atag.xml -O $outp.Event.xml");
            }
            elsif ($type eq "casmacat-3"){
              print "./KeyMapping-Casmacat3.pl -T $outp.Atag.xml -O $outp.Event.xml\n";
              execute("perl ./KeyMapping-Casmacat3.pl -T $outp.Atag.xml -O $outp.Event.xml");
            }
            else {
                print "KeyMapping.pl -T $outp.Atag.xml -O $outp.Event.xml\n";
                execute("perl ./KeyMapping.pl -T $outp.Atag.xml -O $outp.Event.xml");
            }
            $outp =~ s/\//\\/g;
       
#            unlink "$outp.Atag.xml";
#            print "$outp.Atag.xml\n";
        }
        
    }
# Arnts enhanced Keymapping
#	print STDERR "RemapKeyTok-Lev.py $dir\n";
#	execute("/cygdrive/c/ProgramData/Anaconda3/python.exe RemapKeyTok-Lev.py ../$User/$Study/Events");
#	execute("python RemapKeyTok-Lev.py $dir");
}

sub TokenTables{
    my $study = shift;

    my $table_path = "$study/Tables/";
    my $event_path = "$study/Events/";
    
    if ( not -e "$study" ){
       print "TokenTables: $study does not exist\n";
	   exit 1;
    }
    if ( not -e "$event_path"){
       print "TokenTables: $event_path does not exist\n";
	   exit 1;
    }
    if ( not -e $table_path){
       make_path $table_path or die "Directory creation failed: $!";
    }

    print "TokenTables opening study $event_path\n"; 

    opendir(DIR,$event_path);
    my @FILES = sort readdir(DIR);
    closedir(DIR); 
	my $flag = 0;
	foreach my $file (@FILES){
        
        if ($file=~ m/\.Event\.xml$/i){
            my $root = $file; 
            $root =~ s/\.Event.xml$//;
            if (older_than("$event_path$file", "$table_path$root.st")){ 
              print "TokenTables skipping $table_path$root\n"; 
              next; 
            }

            print "./ProgGraphTables.pl -T $event_path$file -O $table_path -a $AUgap -g $AUgaze -p $PUgap -f $FUgap\n"; 
            system("perl ./ProgGraphTables.pl -T $event_path$file -O $table_path -a $AUgap -g $AUgaze -p $PUgap -f $FUgap");
            $flag = 1;
        }
    }
	
### Machine entropy
## adds H and P to st and sg files
    if ($flag == 1) {
      print "./LiteralTrans.pl -S $table_path\n";
      execute("perl ./LiteralTrans.pl -S $table_path");
    }
}

sub AtagToYawat {
    my $atag = shift;
    my $yawat = shift;
	
    if (-e $yawat){ unlink "$yawat/*"; }
    else { make_path $yawat or die "Directory creation failed: $!"; }
	$atag .= "/Alignment/";

    opendir(DIR, $atag) or die "Cannot open $atag for reading: $!";
    my @FILES= readdir(DIR);
    closedir(DIR);

    foreach my $file (@FILES){
        if ($file =~ /.atag$/i){
           $file =~s/.atag$//;
           print   "./Atag2Yawat.pl -A $atag$file -O $yawat$file\n"; 
           execute("perl Atag2Yawat.pl -A $atag$file -O $yawat$file");
        }
    }
    execute("/bin/chmod -R og+wr $yawat");
}


sub YawatToAtag {
    my $align = shift;
    my $yawat = shift;

	$align .= "/Alignment";
    print "YAWAT: $yawat --> $align\n";
	
    opendir(DIR,$yawat);
    my @FILES= readdir(DIR);
    closedir(DIR);

    foreach my $file (@FILES){
        if ($file =~ /.aln$/i){
           $file =~s/.aln$//;
           print "./Atag2Yawat.pl -A $align/$file -Y $yawat/$file -O $align/$file\n";
           execute("perl Atag2Yawat.pl -A $align/$file -Y $yawat/$file -O $align/$file");
        }  
    }
}

sub ReadTokenFreqLex {
  my (@LANG) = @_;
  
  my $gram = 1;
  my $LEX = {};

  foreach my $lang(@LANG) {
    if(!open(LEX, '<:encoding(utf8)', "../FreqLex/$lang")) { 
      printf "Cannot open file ../FreqLex/$lang\n"; 
      next;
    }

    printf "Reading ../FreqLex/$lang\n"; 
    while(defined($_ = <LEX>)) {
	  chomp;
      my ($lex, $num, $prob) = split(/\t/, $_);
      if(!defined($num)) {print "TokenFreq $lang\t$_\n"; next;} 
      if($num =~ /1-grams/) {$gram = 1; next}
      if($num =~ /2-grams/) {$gram = 2; next}

      $LEX->{$lang}{$gram}{$lex} = $prob;
    }
	close(LEX);
  }
  return  $LEX;
}

sub AssignLexProb {
  my ($LEX, $Align) = @_;
  
  my $min = -50;
  my $gram = 1;
  my $first = '';

  opendir(DIR, "$Align");
  my @FILES= readdir(DIR);
  closedir(DIR); 

  foreach my $file (@FILES){
    if ($file !~ /src$/i && $file !~ /tgt$/){next;}

    if(!open(TOK, '<:encoding(utf8)', "$Align/$file")) { 
      print "Cannot open file $Align/$file\n"; 
      next;
    }
    if(!open(OUT, '>:encoding(utf8)', "$Align/$file-lex")) { 
      print "Cannot open file $Align/$file-lex\n"; 
      next;
    }
	
    print "AssignLexProb: opening study $Align/$file\n"; 
    my $lang = '';

    while(defined($_ = <TOK>)) {
      if(/<Text/) {
        if(/freqLex/) { 
          print "$file: freqLex exists $_"; 
          last; 
        }
        if(/language="([^"]*)"/) { 
          $lang = $1;
          s/(language="[^"]*")/$1 lexFreq="yes"/;
        } 
      }
      if(/<W/ && />([^<]*)</) { 
        my $lc = lc($1);
	    my $p=$min;
        if(defined($LEX->{$lang}{1}{$lc})) {$p = $LEX->{$lang}{1}{$lc}}
        s/segId=/Prob1="$p" segId=/;
        if($first ne '') {
          my $sec = "$first|||$lc";
          $p = $min;
          if(defined($LEX->{$lang}{2}{$sec})) {$p = $LEX->{$lang}{2}{$sec}}
          s/segId=/Prob2="$p" segId=/;
        }
        $first = $lc;
      }
      print OUT "$_";
#      print STDERR "$_";
    }
    close(TOK);
    close(OUT);
  }
}


## corrupt file paths ...
sub TER {
    my $study = shift;

    execute("cut -f 1 ../AddColumns/TER.sg | grep $study > ../AddColumns/TER.flag");
    if (! -z "../AddColumns/TER.flag") { print "$study already TER scored\n"; return;}

    print   "./getTER.py ../$study ../$study/Tranlations.txt ../AddColumns/TER.$study 3\n"; 
    execute("python ./getTER.py ../$study ../$study/Translations.txt ../AddColumns/TER.$study 3");

    execute("cat  ../AddColumns/TER.$study  >> ../AddColumns/TER.sg");
}

sub AnnotateTrl{
    my $study = shift;
    my $arg = shift;
    my $dir = "$study/Alignment_NLP/";
    my $align_path = "$study/Alignment/";
    my $python_args = "";
    my $flag = 0;

    if ( not -e $dir){
       make_path $dir or die "Directory creation failed: $!";
    }

    opendir(DIR,$align_path);
    my @FILES= readdir(DIR);
    foreach my $file (@FILES){
        
        my $temp_path = $align_path.$file;
        my $new_path = $temp_path;
        $new_path =~ s/Alignment/Alignment_NLP/;
        
        if ($temp_path=~ m/(\.src|\.tgt)$/i){
            
            if (older_than($new_path,$temp_path)){
                $python_args = $python_args.$temp_path." ";
            }
        }
        elsif($temp_path=~ m/\.atag$/i){
            if (older_than($new_path,$temp_path)){
                copy($temp_path,$new_path) or die "Copy failed: $!";
            }
        }
    }
    if($python_args){
        $python_args =~ s/^\s*(.*?)\s*$/$1/;
        execute("python AnnotateTrl.py $python_args");
        
    }
    closedir(DIR);
}


sub older_than{
    my ($file1,$file2)=@_;
    if (stat($file1) and not(stat($file2))){
        #print "X";
        return 0;
    }
    elsif (stat($file2) and not(stat($file1))){
        #print "Y";
        return 1;    
    }
    elsif (stat($file1) and stat($file2)){
        if (stat($file1)->mtime < stat($file2)->mtime){
            #print "Z";
            return 1;
        }
        else{
            #print "A";
            return 0;
        }
    }
    #print "M";
    return 0;
    
}


sub LogFileType {
    my ($fn) = @_;
    my $type = '';

    open (IN, $fn) || die "Error: cannot open $fn $!";

    while (<IN>){
        if(/<Version/i && /CASMACAT2/i ) { $type = "casmacat-2";}
        elsif(/<Version/i && /CASMACAT3/i ) { $type = "casmacat-3";}
        elsif(/<Version/i && /elan/i ) { $type = "elan";}
        elsif (/<VersionString/i && /fieldtrial1/i ) { $type = "casmacat-1";}
        elsif ($_=~ /<VersionString/i) {$type = "translog-2";}
        if($type ne '') {last};
    }
    close (IN);
#    printf STDERR "LogFileType $fn: version $type\n";
    return $type;
}


sub execute {

    my $cmd = shift;
    `$cmd`;    
    
}

#print STDERR "RemapKeyTok-Lev.py ../$User/$Study/Events\n";
#execute("/cygdrive/c/ProgramData/Anaconda3/python.exe RemapKeyTok-Lev.py ../$User/$Study/Events");
#exit(0);

### Commands with 1 argument
if($Command eq "CFT13"){
# machine translation entropy  
    print "TableMerge.pl -P  ../CFT13/Tables -M ../CFT13/MTH-11_13_21_22_31_32_33.st -S st\n";
	execute("perl ./TableMerge.pl -P ../CFT13/Tables -M ../CFT13/MTH-11_13_21_22_31_32_33.st -S st");
# collapse sg tables
    print "./CFT13-PE-RE.pl > ../CFT13/Tables/CFT13-PE-RE.seg\n";
    execute("perl ./CFT13-PE-RE.pl > ../CFT13/Tables/CFT13-PE-RE.seg");
# quality and edit distance
    print "./TableMerge.pl -P ../CFT13/Tables -M ../CFT13/CFT13_TER+Quality.seg -S seg\n";
	execute("perl ./TableMerge.pl -P ../CFT13/Tables -M ../CFT13/CFT13_TER+Quality.seg -S seg");
    exit 0;    
}

### Commands with 2 or more argument

if ($Command eq ''){ Usage("-C Command required\n"); }
if ($Study eq ''){ Usage("-S Study required\n"); }

if($Study eq "tprdb"){}
elsif($Study eq "translog"){ @studies = @translog; }
elsif($Study eq "casmacat"){ @studies = @casmacat; }
elsif($Study eq "studiesM"){ @studies = @studiesM; }
elsif($Study eq "multiLing"){ @studies = @multiLing; }
elsif($Study eq "multiLing6"){ @studies = @multiLing6; }
elsif($Study eq "missionStatements"){ @studies = @missionStatements; }
elsif($Study eq "ministerSpeech"){ @studies = @ministerSpeech; }
else{@studies = ($Study);}

if($Command eq "tokenize"){
    foreach my $s (@studies){ Tokenize("$tprdbBase/$User/$s/"); }
    exit 0;    
}

if($Command eq "literal"){
    foreach my $s (@studies){
      print "./LiteralTrans.pl -S $tprdbBase/$User/$s/Tables\n";
      execute("perl ./LiteralTrans.pl -S $tprdbBase/$User/$s/Tables");
    }
    exit 0;    
}

if($Command eq "tprdb"){
    if($DBversion eq ''){ Usage("-V Version required e.g. 'v2.1'\n"); }

    my $TPRVERSION = "$Study$DBversion";
    my $GB18030 = $TPRVERSION ."_GB18030";

    execute("mkdir -p $TPRVERSION/bin");
    execute("cp StudyAnalysis.pl Tokenize.pl MergeAtagTrl.pl KeyMapping.pl ProgGraphTables.pl LiteralTrans.pl progGra.R $TPRVERSION/bin");

    foreach my $s (@studies) {
        print "copy $TPRVERSION/$s\n";
        execute("mkdir -p $TPRVERSION/$s/Tables");
        execute("cp ../$s/Tables/* $TPRVERSION/$s/Tables");

        execute("mkdir -p $GB18030/$s/Tables");

## convert into GB18030
        opendir(DIR, "$TPRVERSION/$s/Tables");
        my @FILES= readdir(DIR);
        closedir(DIR);

        foreach my $file (@FILES){
		  execute("iconv -f UTF8 -t GB18030 $TPRVERSION/$s/Tables/$file > $GB18030/$s/Tables/$file");
		}
	}
    execute("zip -r $TPRVERSION.zip $TPRVERSION/*");

## create concatenated tables files
    execute("cat $TPRVERSION/*/Tables/*sg | grep -v ^Id > $TPRVERSION/m.sg");
    execute("cat $TPRVERSION/*/Tables/*st | grep -v ^Id > $TPRVERSION/m.st");
    execute("cat $TPRVERSION/*/Tables/*cu | grep -v ^Id > $TPRVERSION/m.cu");
    execute("head -1 $TPRVERSION/BML12/Tables/P01_T1.sg > $TPRVERSION/h.sg");
    execute("head -1 $TPRVERSION/BML12/Tables/P01_T1.st > $TPRVERSION/h.st");
    execute("head -1 $TPRVERSION/BML12/Tables/P01_T1.cu > $TPRVERSION/h.cu");
    execute("cat $TPRVERSION/h.sg $TPRVERSION/m.sg > $TPRVERSION/tables.sg");
    execute("cat $TPRVERSION/h.st $TPRVERSION/m.st > $TPRVERSION/tables.st");
    execute("cat $TPRVERSION/h.cu $TPRVERSION/m.cu > $TPRVERSION/tables.cu");
    execute("rm $TPRVERSION/h.* $TPRVERSION/m.*");

## compatible with Chinese operating system 
    execute("iconv -f UTF8 -t GB18030 $TPRVERSION/tables.cu > $GB18030/tables.cu");
    execute("iconv -f UTF8 -t GB18030 $TPRVERSION/tables.st > $GB18030/tables.st");
    execute("iconv -f UTF8 -t GB18030 $TPRVERSION/tables.sg > $GB18030/tables.sg");
	exit 0;
}


if($Command eq "tables"){
    foreach my $s (@studies){
      if($buildTables =~ /e/ || (not -d "$tprdbBase/$User/$s/Events")) {
        if($buildTables =~ /f/) { 
			printf STDERR "tables: remove $tprdbBase/$User/$s/Events\n";
			remove_tree "$tprdbBase/$User/$s/Events";  
		}
        MergeEvents("$tprdbBase/$User/$s"); 
      }
      if($buildTables =~ /t/) { 
	    if($buildTables =~ /f/) { 
			printf STDERR "tables: remove $tprdbBase/$User/$s/Tables\n";
			remove_tree "$tprdbBase/$User/$s/Tables";  
		}
	    TokenTables("$tprdbBase/$User/$s", $buildTables); 
      }
    }
    exit 0;    
}

if($Command eq "yawat"){

   foreach my $s (@studies){ AtagToYawat("$tprdbBase/$User/$s/", "$yawatBase/$User/$s/");}

   exit 0;    
}

if($Command eq "taway"){

   foreach my $s (@studies){ YawatToAtag("$tprdbBase/$User/$s/", "$yawatBase/$User/$s/");}

   exit 0;    
}

if($Command eq "freqLex"){
    my $LEX = ReadTokenFreqLex(qw (en da es));
    foreach my $s (@studies){ AssignLexProb($LEX, "$tprdbBase/$User/$s/Alignment/"); }
    exit 0;    
}

## NLTK toolkit
if($Command eq "annotate"){
    foreach my $s (@studies){ AnnotateTrl("$tprdbBase/$User/$s/"); }
    exit 0;    
}

## NLTK toolkit
if($Command eq "TER"){
    foreach my $s (@studies){ TER("$tprdbBase/$User/$s/"); }
    exit 0;    
}

Usage("No defined command");

sub CFGfile {
    my $cfg =shift;

    open CFGFILE, "$cfg" or die "Permission $cfg: $!\n";
    while (my $l = <CFGFILE>) {
      my ($l2) = $l =~ /^([^#]*)/;
      if($l2 =~ /^\s*$/) {next;}
      chomp $l2;
	  eval $l2;	  
    }
    close CFGFILE;
}
