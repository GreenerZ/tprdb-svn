#!/bin/bash

if [ "$1" == "" ] || [ "$2" == "" ] || [ "$3" == "" ]; then
  echo "$0 Path source target task"
  echo ./langPair2Trl.bash ../SH1611/Translog-II/*_T en zh  translating
  exit
fi

for file in $1*.xml ; do
   echo "AddLang $file"
   perl ./LangPair2Trl.pl -T $file -s $2 -t $3 -m $4 > "$file.langPair"
#    root=${file%.xml}
#    atag=${root/Translog-II/Alignment}
#   ./LangPair2Trl.pl -A $atag -s $2 > "$atag.src.langPair"
#   ./LangPair2Trl.pl -A $atag -t $3 > "$atag.tgt.langPair"
done


#linux 
#rename -f 's/.langPair//' $1*.langPair
# cygwin
rename xml.langPair xml .langPair

# call with more and tracker
#for file in /cygdrive/c/Users/iView/Desktop/RUC17/Translog-II/SMI-N/*_T*; do ./LangPair2Trl.pl -T $file -s en -t zh -m translating -r SMI-RED250 > $file-r; done

