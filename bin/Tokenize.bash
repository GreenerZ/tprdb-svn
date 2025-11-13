#!/bin/bash

for file in Translog-II/*.xml  
do 
    token=${file%.xml}
    token=${token/Translog-II/Alignment}
   /data/critt/tprdb/bin/Tokenize.pl -T $file -D $token
done
