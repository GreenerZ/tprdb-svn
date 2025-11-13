# $1: user (annotator)
# $2: study 
# $3: SL
# $4: TL
# $5: reverse flag [0,1]
# 1: SL and TL are reversed, read TL segments from YAWAT
# -: copy old src into new study

# read data 
inStudy="/data/critt/tprdb/${1}/${2}/"

# new MT study 
mtStudy="${2}_NTO"

# automatically generate MT output in new Study
newStudy="/data/critt/tprdb/${1}/${mtStudy}"


# generate MT study
echo ""
echo "Intento: $1 $2 $3 $4 $5 --- generate new MT $newStudy/" 
python3 -u /data/critt/tprdb/bin/Intento.py $inStudy ${newStudy}/ $3 $4 $5 -v 0

# tokenize
echo "Intento: $1 $2 $3 $4 $5 --- Tokenize MT $mtStudy" 2>&1 
cd "/data/critt/tprdb/bin/" && perl ./StudyAnalysis.pl -U $1 -S $mtStudy -C tokenize  -b f  2>&1 

# copy src files from old to new study
echo "Intento: $1 $2 $3 $4 $5 --- CopySrc $newStudy" 2>&1 
python3 /data/critt/tprdb/bin/CopySrc.py "${inStudy}/Alignment/" "${newStudy}/Alignment/"  2>&1 

# produce yawat
echo "Intento: $1 $2 $3 $4 $5 --- toYawat MT $mtStudy" 2>&1 
cd "/data/critt/tprdb/bin/" && perl ./StudyAnalysis.pl -U $1 -S $mtStudy -C yawat  2>&1 

# SimAlign
echo "Intento: $1 $2 $3 $4 $5 --- Simalign MT $mtStudy SA" 2>&1 
/data/critt/tprdb/bin/SimAlign.bash $1 ${mtStudy} SA  2>&1

echo "Intento: $1 $2 $3 $4 $5 --- Simalign MT $mtStudy SI" 2>&1 
/data/critt/tprdb/bin/SimAlign.bash $1 ${mtStudy} SI  2>&1

echo "Intento: $1 $2 $3 $4 $5 --- Simalign MT $mtStudy SM" 2>&1 
/data/critt/tprdb/bin/SimAlign.bash $1 ${mtStudy} SM  2>&1


