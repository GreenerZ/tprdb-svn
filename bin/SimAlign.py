#!/usr/bin/env python
# coding: utf-8

import os
import sys
import os.path
import glob
import numpy as np
from nltk.translate import AlignedSent, Alignment
from nltk.translate import alignment_error_rate

# load TPRDB library
sys.path.append('/data/critt/tprdb/bin/')
import TPRDB
import importlib
importlib.reload(TPRDB)


# load Simaligner
from simalign import SentenceAligner



# "/data/critt/yawat/TPRDB/AR19/"
def SimAlign(inStudy, outStudy="", method="a", verbose=0) :
    # method: m, a, i
    
    print(f"SimAlign initiate AimAlign\n")
    myaligner = SentenceAligner(model="bert", token_type="bpe", matching_methods=method)

    print(f"SimAlign in:{inStudy} out:{outStudy} method:{method}\n")

    # read a study from the YAWAT folder (German)
    study = TPRDB.readYawatStudy(inStudy, verbose=0)
    print(f"SimAlign sessions:{len(study.keys())}")

    # separate study into list of NLTK alignments with reference and test set
    ref, tst = TPRDB.yawat2Alignment(study)
    print(f"SimAlign segments:{len(ref)}")

    #run alignment
    SimA = simAlignment(tst, method, myaligner, verbose=0)

    print("SimAlign: transitiveAlignment")
    # transitive mapping 
    SimAT = TPRDB.transitiveAlignment(SimA, verbose = 0)
    
    # add alignments to study under feature name "SimA"
    TPRDB.alignment2Yawat(study, SimAT, feat="SimAT")

    # write alignments to study
    if(inStudy == '') : outStudy = inStudy
    print(f"SimAlign: writeYawatStudy {outStudy}")
    TPRDB.writeYawatStudy(outStudy, study, feat="SimAT")


# simalign
   
def simAlignment(ALN, method, myaligner, verbose = 0):
    R = []
    
    for seg in range(len(ALN)):
        aln = []
        mot = ALN[seg].mots
        word = ALN[seg].words
        if(verbose): print(f"simAlignment: {seg} from {len(ALN)}")
        if((seg % 10) == 0) : print(f"simAlignment: {seg} from {len(ALN)}")

        if(len(mot) == 0 or len(word) == 0):
            if(verbose): print(f"Unaligned: {word}\n{mot}")
            R.append(AlignedSent(word, mot, Alignment(aln)))
        else :
            aln = myaligner.get_word_aligns(word, mot)
            for a in aln:
                R.append(AlignedSent(word, mot, Alignment(aln[a])))
                break
    return R   


def help():

    print (
        f"Usage:\n{__file__} <path_/input/yawat/study>\t<path/output/yawat/study>\tmethod [ami] [-verbose level] \n")
    exit(1)

if __name__ == '__main__':

    arguments = sys.argv
    args_len = len(sys.argv)
    output_file = ''
    method = 'a'
    verbose = 0

    if args_len < 2: 
        print(arguments)
        help()
    if "-h" in arguments: help()
    if "-v" in arguments:
        verbose = arguments.index("-o") + 1

    input_file = arguments[1]
    output_file = arguments[2]
    method = arguments[3]
 
    SimAlign(input_file, outStudy=output_file, method=method, verbose=verbose)

