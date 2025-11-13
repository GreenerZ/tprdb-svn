echo "SimAlign $1 $2 $3"

# $1: user (annotator)
# $2: study
# $3: command-mode

# new MT study 
newStudy="$2_$3"
method='a'

if [[ $3 == "SA" ]]
then
      method='a'
elif [[ $3 == "SM" ]]
then
      method='m'
elif [[ $3 == "SI" ]]
then
      method='i'
else 
      echo "wrong option $3: Simalign USER STUDY [SA, SM, SI]"
      exit
fi 

yawatIn="/data/critt/yawat/${1}/${2}/"
yawatNew="/data/critt/yawat/${1}/$newStudy/"
tprdbIn="/data/critt/tprdb/${1}/${2}/"
tprdbNew="/data/critt/tprdb/${1}/$newStudy/"

echo "SimAlign: cp $tprdbIn $tprdbNew"
mkdir $tprdbNew
touch "/data/critt/yawat/${1}/${newStudy}.uploaded"


cp -ra $tprdbIn/Alignment   $tprdbNew
cp -ra $tprdbIn/Translog-II $tprdbNew

echo "SimAlign: $yawatIn $yawatNew $method"
python3 /data/critt/tprdb/bin/SimAlign.py $yawatIn $yawatNew $method 2>&1 | more > $tprdbNew/$newStudy.prot
      
# save alignments
echo "Simalign: save Alignments $newStudy" 
cd "/data/critt/tprdb/bin/" && perl ./StudyAnalysis.pl -U $1 -S $newStudy -C taway  2>&1 | more >> $tprdbNew/$newStudy.prot
#touch "${tprdbNew}.uploaded"

# make tables
echo "SimAlign: make Tables $newStudy" 
cd "/data/critt/tprdb/bin/" && perl ./StudyAnalysis.pl -U $1 -S $newStudy -C tables -betf   2>&1 | more >> $tprdbNew/$newStudy.prot 

