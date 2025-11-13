DIR=data/$1/

rm -rf ${DIR}Alignment_NLP
mkdir -p ${DIR}Alignment_NLP

python AnnotateTrl.py ${DIR}Alignment/*.src
python AnnotateTrl.py ${DIR}Alignment/*.tgt

cp ${DIR}Alignment/*.atag ${DIR}Alignment_NLP
