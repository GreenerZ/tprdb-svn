tracker=''
if [ -e $1.txt ] 
then
  tracker="-e $1.txt"
elif [ -e $1.tsv ]
then 
  tracker="-e $1.tsv"
elif [ -e $1.gp3 ]
then 
  tracker="-e $1.gp3"
fi

python3 /data/critt/tprdb/bin/Trados2Translog.py $1.xml -t /data/critt/tprdb/bin/translog_template.xml -o $2 $tracker
