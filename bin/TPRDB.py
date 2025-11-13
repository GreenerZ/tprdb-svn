#!/usr/bin/env python
# coding: utf-8

import os
import re
import sys
import os.path
import glob
import numpy as np
import pandas as pd

from nltk.translate import AlignedSent, Alignment
from nltk.translate import alignment_error_rate


# read all tables from [studies] with the specified extension

def readTPRDBtables(studies, ext,  path="/data/critt/tprdb/TPRDB/", verbose = 0):
    df = pd.DataFrame()
    for study in studies:
        # print filename
        if(verbose > 1) : 
            for fn in glob.glob(path + study + ext): print("\t", fn)
        # list of tables (dataframes) 
        l = [pd.read_csv(fn, sep="\t", dtype=None) for fn in glob.glob(path + study + ext)]
        # print filename # sessions rows
        if(verbose) : 
            row = 0
            for d in l: row += len(d.index) 
            print(f"{study}\t#sessions:{len(l)}\t{ext}:{row}")
        l.insert(0, df)
        df = pd.concat(l, ignore_index=True)
    return(df)

## read - write studies from YAWAT directory (/data/critt/yawat)
# return: dictionary with session data
def readYawatStudy(alsPath, singleST=False, participants=[], verbose=0):
    H = {}
    R = {}
    if(verbose > 0): print ("reading: ", alsPath)
    
    for session in glob.glob(alsPath + "*crp"):
        
        # read only one ST in the study
        if(singleST) :
            x = re.match(r".*/P.*_[^0-9]*(.*)$", session)
            if (x.group(1)) in R: 
                if(verbose) : print(f"readYawatStudy: duplicate skipping {session}")
                continue
            R[x.group(1)] = 1
        if participants :
            x = re.match(r".*/(P.*)_[^0-9]*.*$", session)
            if (x.group(1) not in participants): 
                if(verbose) : print(f"{x.group(1)} readYawatStudy: skipping {session}")
                continue

        sLen = 0
        tLen = 0

        src = [] # source segments
        tgt = [] # target segments
        aln = [] # alignments
        nbr = [] # alignment (number, sourcePrefLen, sourceSegLen, targetPrefLen, targetSegLen) 
        Syt = {} # yawat annotation source
        Tyt = {} # yawat annotation target

        # read source and target segments
        ses = session.replace(".crp", "").replace(alsPath, "")
        
        if verbose > 0 : print ("reading session: ", ses)
        
        crp = open(session, "r", encoding="utf-8")
        number = crp.readline()
        while number:
            # alignment number
            source = crp.readline()
            target = crp.readline()
            sl = len(source.split())
            tl = len(target.split())
            nbr.append((int(number), sLen, sl, tLen, tl))
            src.append(source)
            tgt.append(target)
            sLen += sl
            tLen += tl
            if(verbose > 1): print (f"\t{number}\t{source}\t{target}")
            number = crp.readline()
        crp.close()
        if(len(src) != len(tgt)): print(f"ERROR: src tgt len does not match {cnt}")

        # read the alignment files
        ali = open(session.replace(".crp", ".aln"), "r")
        line = ali.readline()
        cnt = 0
        while(line):
            if(line.strip() == '') :
                line = ali.readline()
                continue
            a1 = line.split()
#            print(f"{session} >{line}<")
            # line number in crp and aln must match
            if(int(a1[0]) != nbr[cnt][0]): 
                if verbose > 0 : 
                    print(f"ERROR: aln line {cnt} -- {int(a1[0])} -- {nbr[cnt][0]}");
            a2 = []
            for j in range(1,len(a1)) :
                sl,tl,m = a1[j].split(':')
#                print(f"AA:>{sl}-{tl}-{m}<")
                
                if(sl != ''): 
                    if(m != "unspec") :
                        for s in sl.split(','): 
                            Syt[int(s) + nbr[cnt][1]] = m
                   
                if(tl != ''): 
                    if(m != "unspec") :
                        for t in tl.split(','): 
                            Tyt[int(t) + nbr[cnt][3]] = m
                    
                if(sl == '' or tl == ''): continue
             
 #                print(f"BB:>{sl}-{tl}-{m}<")
                if(verbose > 2): print(f"readYawatStudy: {a1[j]}")

                for s in sl.split(','): 
                    for t in tl.split(','): 
                        a2.append((int(s),int(t)))
            aln.append(a2)

    #        print(f"Line{cnt}:\t{line.strip()}\n\t{a2}")
            line = ali.readline()
            cnt += 1
        ali.close()
        if(len(src) != len(aln)): print(f"ERROR: src aln len does not match {cnt}")

        H.setdefault(ses, {})
        H[ses]["src"] = src
        H[ses]["tgt"] = tgt
        H[ses]["aln"] = aln
        H[ses]["nbr"] = nbr
        H[ses]["Syt"] = Syt
        H[ses]["Tyt"] = Tyt
    return H


## dump a study YAWAT format
def writeYawatStudy(path, study, feat="aln", verbose=0):

    # Create target Directory if don't exist
    if not os.path.exists(path):
        os.mkdir(path)
        if (verbose > 0) : print("writeYawatStudy: Directory " , path ,  " Created ")

    for session in study:
        
        # another session name 
        if 'name' in study[session] :  
            newSession = path + study[session]['name']
        else : newSession = path + session.split("/")[-1].replace(".crp", "") 
            
        if verbose > 0 : print ("Output file: ", newSession)
        
        crp = open(newSession + ".crp", "w+", encoding='utf-8')
        aln = open(newSession + ".aln", "w+", encoding='utf-8')

        for i in range(len(study[session]["nbr"])):
            
            # write crp file
            cs = str(study[session]['nbr'][i][0]) + "\n" + study[session]['src'][i] + study[session]['tgt'][i]
            if verbose > 1 : print(f"{cs}")
            crp.write(cs)

            # prepare aln: collect s - t mappings in H
            H = {}
            H.setdefault('s', {}) # s - to - t mapping
            H.setdefault('t', {}) # t - to - s mapping
            H.setdefault('m', {}) # skip token in a previous chunk

#            debug = 0
#            if(session == '/data/critt/yawat/TPRDB/SG12/P02_T3' and i ==1): debug =1 

            # read alignments into a dictionary
            for n in study[session][feat][i] :
#                print(f"{session}\t{feat} i:{i}\tn:{n}")
                s,t = n
                H['s'].setdefault(s, {})
                H['t'].setdefault(t, {})
                H['s'][s][t] = 1
                H['t'][t][s] = 1

            ts = '' # target 
            ss = '' 
            ms = str(study[session]['nbr'][i][0])
#            if(debug) : print("debug1", H)
#SGstudy['/data/critt/yawat/TPRDB/SG12/P02_T3']['RAtra1'][1]

            # generate aln string
            marker = "unspec"

            for s in sorted(H['s']):
                # check if ST annotation marker exists
                idx = int(s)+study[session]['nbr'][i][1]
                if "Syt" in study[session] and idx in study[session]["Syt"]:
                    marker = study[session]["Syt"][idx]
                else : marker = "unspec"

                # skip if already in a previous chunk
                if s in H['m'].keys(): continue
            
                tl = sorted(H['s'][s].keys())
                ts = ",".join(map(str, tl))
                ss = '' 
                
                for t in tl:

                    sl = sorted(H['t'][t].keys())
                    sm = ",".join(map(str, sl))
                    
#                    if(debug) : print(f"debug3\t {t}{sm:20} {ts:20}")
                        
                    # check whether all entries are m X n 
                    if(ss != '' and ss != sm):
                        print(f"writeYawatStudy:{newSession}:seg{i} {ss:15} / {sm:15}\t{ts}")
                        print(f"\t{study[session][feat][i]}")

                    # mark S token that are eaten up
                    for m in sl: H['m'][m] = 1
                    ss = sm
                    
                ms += " " + ss + ":" + ts + ":" + marker
                if verbose > 1 : print(f"mapping\t{s}\t{ss}:{ts}:{marker}\n\t{ms}")
                  
            aln.write(ms + "\n")
        aln.close()
        crp.close()

###############################################################
# read corpus

# read bitext: st tt segment translations in two files sfn and tfn
# return: Alignment corpus

def readBitext(sfn, tfn):
    txt = []
    src = open(sfn, "r+", encoding="utf-8")
    tgt = open(tfn, "r+", encoding="utf-8")
    sl = src.readline()
    tl = tgt.readline()
    while sl and tl:
        s = sl.split()
        t = tl.split()
#        print(s,"\t",t)
        txt.append(AlignedSent(s, t))
        sl = src.readline()
        tl = tgt.readline()
    return (txt)

# convert aligned bitext into a study
def alignedBitext2Study(BT):
    S = {}
    session = "/P01_T1"
    S.setdefault(session, {})
    S[session].setdefault('src', {})
    S[session].setdefault('tgt', {})
    S[session].setdefault('aln', {})
    S[session]['nbr'] = np.arange(1, len(BT)+1)
    for i in range(len(BT)):
        S[session]['src'][i] = " ".join(BT[i].words) + "\n"
        S[session]['tgt'][i] = " ".join(BT[i].mots) + "\n"
        S[session]['aln'][i] = sorted([(p[0],p[1]) 
                                for p in list(BT[i].alignment) if p[0] != None and p[1] != None])
    return(S)



# write translation_table to fn
def writeDic(fn, tt) :
    # em_ibm2.translation_table
    dic = open(fn, "w")
    for s in tt :
        for t in tt[s] :
            dic.write(f"{s}\t{t}\t{tt[s][t]}\n")

    dic.close



##########################################################################
# 

# merge features in fromStudy into toStudy
def mergeAlignments(toStudy, fromStudy, feature): 

    for session in fromStudy : 
        if(session not in toStudy.keys()) : 
            print(f"ERROR: {session} not in toStudy")
            continue
        ts = len(toStudy[session]['src']) 
        fs = len(fromStudy[session]['src'])
        if(ts != fs) : 
            print(f"ERROR: {session} different length {ts}-{fs}")
            continue
        for f in feature:              
            if(session in toStudy[session].keys()) : 
                print(f"ERROR: {feature} already defined in toStudy")
                continue
            if(type(fromStudy[session][f]) is list and 
                len(fromStudy[session][f]) != len(toStudy[session]['aln'][i])) :
                print(f"{session}-{i}: len mismatch {len(fromStudy[session][f])}-{len(study[session]['aln'][i])}")

            toStudy[session][f] = fromStudy[session][f]

    return(toStudy)

###################################################################
# transform a Yawat study into alignment representation for IBMModels
def yawat2Alignment(study):
    tst = []
    ref = []
    for session in sorted(study): 
        for i in range(len(study[session]['src'])):
            s = study[session]['src'][i].split()
            t = study[session]['tgt'][i].split()
            a = study[session]['aln'][i]
            ref.append(AlignedSent(s, t, Alignment(a)))
            tst.append(AlignedSent(s, t))
    return (ref, tst)
           
def yawat2text(study, sfn, tfn) :
    src = open(sfn, "w+")
    tgt = open(tfn, "w+")

    for session in sorted(study): 
        for i in range(len(study[session]['src'])):
            src.write(study[session]['src'][i])
            tgt.write(study[session]['tgt'][i])
    src.close()
    tgt.close()

# 
def alignment2Yawat(study, tst, feat="aln", invert=0, cp_src=0, cp_tgt=0, verbose=0):
    j = 0
    for session in sorted(study): 

        if(cp_src) : 
            k = j
            Scp = []
            for i in range(len(study[session]['src'])): 
                Scp.append(" ".join(tst[k].words) + " \n")
                k += 1
            study[session]['src'] = Scp
        if(cp_tgt) : 
            k = j
            Scp = []
            for i in range(len(study[session]['src'])): 
                Scp.append(" ".join(tst[k].mots) + " \n")
                k += 1
            study[session]['tgt'] = Scp
                      
        
        for i in range(len(study[session]['src'])):              
            try:    newFeat = list(tst[j].alignment)
            except: newFeat = list(tst[j])

#            debug = 0
#            if(session == '/data/critt/yawat/TPRDB/SG12/P02_T3' and i == 1): debug =1 

            study[session].setdefault(feat, {})
            if(invert == 0):  
#                newFeat = sorted([p for p in newFeat ])
                newFeat = sorted([(p[0],p[1]) 
                           for p in newFeat if p[0] != None and p[1] != None])
            else: 
                newFeat = sorted([(p[1],p[0]) 
                           for p in newFeat if p[0] != None and p[1] != None])

#            if(debug): print(f"debug:\n{sorted(list(tst[j].alignment))}\n{newFeat}")        

            # check whether the sentences are identical: throw warning
            if(invert): sl = study[session]['tgt'][i].split()
            else: sl = study[session]['src'][i].split()
                      
            if(sl != tst[j].words):
                print(f"{session}-{i}/{j}: source length:{len(tst[j].words)}-{len(sl)}")
                print(f'\t>{" ".join(sl)}<')
                print(f'\t>{" ".join(tst[j].words)}<')
                      
            if(invert): sl = study[session]['src'][i].split()
            else: sl = study[session]['tgt'][i].split()
            if(sl != tst[j].mots):
                print(f"{session}-{i}/{j}: target length:{len(tst[j].mots)}-{len(sl)}")
                print(f'\t{" ".join(sl)}')
                print(f'\t{" ".join(tst[j].mots)}\n')
                
            study[session][feat][i] = newFeat
            j += 1
    if (j != len(tst)):
        print(f"alignment2Yawat: len mismatch Study:{j} new:{len(tst)}")

    return

###############################################
from random import seed
from random import randint
# seed random number generator
seed(1)
    
## Generate random alignments 
def randomAlignment(ALN):
    R = []
    
    for a in range(len(ALN)):
        aln = []
        m = ALN[a].mots
        w = ALN[a].words
        ml = len(m) -1
        wl = len(w) -1
        # number of st-tt alignments is ml + wl
        for i in range(2*ml):
            mv = randint(0, ml)
            wv = randint(0, wl)
            aln.append((wv, mv))
        R.append(AlignedSent(w, m, Alignment(aln)))
    return R   
         
# compute alignment error rate (AER) for all segments in every session
def alignmentErrors(study, features, verbose = 0):
    H = {}
    n = 0

    for session in sorted(study): 
        for i in range(len(study[session]['src'])): 
            s = ''
            sess = session+"-"+str(i)

            # compute alignment error for each combination of alignments f*(f-1)/2
            for j in range(len(features)-1): 
                if features[j] not in study[session].keys(): 
                    if(verbose): print(f"ERROR: {j} not in study")
                    return

                for k in range(j+1, len(features)): 
                    ref = features[j]
                    tst = features[k]
                    t = Alignment(study[session][tst][i])
                    r = Alignment(study[session][ref][i])
                      
                    # assume error if there is no alignment
                    if(len(r) == 0 or len(t) == 0): 
                        if(verbose): print(f"{session}-{i:2} empty alignments")
                        a = 1.0
                    else : a = alignment_error_rate(r, t)
#                    else : a = AlignmentErrors(r, t)
                    f = f"{ref}-{tst}"
                              
                    H.setdefault('sum', {})
                    H.setdefault(sess, {})
                    H['sum'].setdefault(f, 0.0)
                    H['sum'][f] += a
                    H[sess][f] = a
                    s += f"{a:.2} "
            n += 1
            if(verbose): print(f"{sess}\t{s}")
    for h in H['sum'].keys():
        print(f"{h:15}\tSum of errors:{H['sum'][h]:.4}\taverage:{H['sum'][h]/n:.4}")
    return (H)

def AlignmentErrorRate(ref, tst):
    H = {}
    for r in ref: H[r] = 1
    m = 0
    for t in tst: 
        if t in H: m += 1
              
    return 1 - (m+m)/(len(ref) + len(tst))
            

#################################################################################
# from forward and backward alignments produce "row_diag_final_and" alignment
def gdfaStudy(alForw, alBack):
    gdfa = []
    for i in range(len(alForw)):
        if(alForw[i].mots != alBack[i].words) :
            print(f"Warning: does not match:\n\talForw:{alForw[i].mots}\n\talBack:{alBack[i].words}")
        if(alForw[i].words != alBack[i].mots) :
            print(f"Warning: does not match:\n\talForw:{alForw[i].words}\n\talBack:{alBack[i].mots}")
              
        forw = [(p[0], p[1]) for p in list(alForw[i].alignment) if p[0] != None and p[1] != None ]
        back = [(p[1], p[0]) for p in list(alBack[i].alignment) if p[0] != None and p[1] != None ]
        gdfa.append(AlignedSent(alForw[i].words, alForw[i].mots, 
                                Alignment(grow_diag_final_and(forw, back))))
    return (gdfa)


from collections import defaultdict


def grow_diag_final_and(e2f, f2e):

    neighbors = [(-1, 0), (0, -1), (1, 0), (0, 1), (-1, -1), (-1, 1), (1, -1), (1, 1)]
    alignment = set(e2f).intersection(set(f2e))  # Find the intersection.
    union = set(e2f).union(set(f2e))

    # *aligned* is used to check if neighbors are aligned in grow_diag()
    aligned = defaultdict(set)
    for i, j in alignment:
        aligned['e'].add(i)
        aligned['f'].add(j)

    def grow_diag():
        """
        Search for the neighbor points and them to the intersected alignment
        points if criteria are met.
        """

        # iterate until no new points added
        while True:
            no_new_points = True
            A = alignment.copy()
            for (e, f) in A:
                # for each neighboring point (e-new, f-new)
                for neighbor in neighbors:
                    neighbor = tuple(i + j for i, j in zip((e, f), neighbor))
                    # if ( ( e-new not aligned and f-new not aligned)
                    # and (e-new, f-new in union(e2f, f2e) )
                    if (neighbor not in alignment and 
                        neighbor in union):
                        
                        alignment.add(neighbor)
                        e_new, f_new = neighbor
                        aligned['e'].add(e_new)
                        aligned['f'].add(f_new)
                        no_new_points = False
            # iterate until no new points added
            if no_new_points:
                break

    def final_and():
        """
        Adds remaining points that are not in the intersection, not in the
        neighboring alignments but in the original *e2f* and *f2e* alignments
        """
        # for english word e = 0 ... en
        for (e_new, f_new) in union:
            if (e_new not in aligned['e'] and 
                f_new not in aligned['f']):

                alignment.add((e_new, f_new))
                aligned['e'].add(e_new)
                aligned['f'].add(f_new)

    grow_diag()
    final_and()
    return sorted(alignment)


#########################################
# generate a transitive closure for mappings

def transitiveAlignment(ALN, verbose = 0):
    T = []
    for aln in ALN:
        if(verbose) : print(f"TA\ts:{aln.words}\n\tt:{aln.mots}")
        # transform alignments into list of tuples
        a = list(aln.alignment)
        
        T.append(AlignedSent(aln.words, aln.mots, 
                             Alignment(transitiveMapping(a, verbose=verbose) )))
        
    return(T)


def transitiveMapping(A, verbose = 1):
    
    H = {}
    for n in A :
        if (verbose > 1): print(f"n:{n}")
        s,t = n
        H.setdefault(s, {})
        H[s].setdefault('s', set())
        H[s].setdefault('t', set())
        H[s]['s'] = H[s]['s'].union({s})
        H[s]['t'] = H[s]['t'].union({t})

    # generate aln string
    K = sorted(H.keys())

    S = set()
    no_new = True
    
    # join sets until 
    while no_new :
        no_new = False
        for i1 in range(len(K)):
            if(i1 in S and verbose): print(f"Skipping1:{i1} in {S}")
            if(i1 in S): continue
            for i2 in range(i1+1,len(K)):
                if(i2 in S and verbose): print(f"Skipping2:{i2} in {S}")
                if(i2 in S): continue
                k1 = K[i1]
                k2 = K[i2]
                if(verbose > 1): print(f"k1:{i1}-{k1} k2:{i2}-{k2} \t{K}")
                if(H[k1]['t'].intersection(H[k2]['t'])):
                    H[k1]['s'] = H[k1]['s'].union(H[k2]['s'])
                    H[k1]['t'] = H[k1]['t'].union(H[k2]['t'])
                    S.add(i2)
                    no_new = True
               
    aln = []
    for i1 in range(len(K)):
        if(i1 in S): continue
        k1 = K[i1]
        if(verbose > 1): print(f"{','.join(map(str, sorted(H[k1]['s']))):20} --- {','.join(map(str, sorted(H[k1]['t'])))}")
        for s in sorted(H[k1]['s']):
            for t in sorted(H[k1]['t']):
                aln.append((s,t))

    return(aln)

