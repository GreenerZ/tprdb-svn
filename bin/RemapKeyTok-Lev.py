# -*- coding: utf-8 -*-
"""
Created on Mon Jul 16 05:15:26 2018

@author: Arndt
"""

# -*- coding: utf-8 -*-
"""
Created on Fri Oct 13 15:39:27 2017
"""
import os
from lxml import etree
import numpy #as numpy
from sys import argv
import sys

script, dir = argv


def levenshtein(seq1, seq2):  
    size_x = len(seq1) + 1
    size_y = len(seq2) + 1
    matrix = numpy.zeros ((size_x, size_y))
    for x in range(size_x):
        matrix [x, 0] = x
    for y in range(size_y):
        matrix [0, y] = y

    for x in range(1, size_x):
        for y in range(1, size_y):
            if seq1[x-1] == seq2[y-1]:
                matrix [x,y] = min(
                    matrix[x-1, y] + 1,
                    matrix[x-1, y-1],
                    matrix[x, y-1] + 1
                )
            else:
                matrix [x,y] = min(
                    matrix[x-1,y] + 1,
                    matrix[x-1,y-1] + 1,
                    matrix[x,y-1] + 1
                )
#    print (matrix)
    return (matrix[size_x - 1, size_y - 1])


#ttdict={}
#for dirs,subdirs,files in os.walk("C:\\Users\\Arndt\\Desktop\\P01_T01.Event.xml\\"):
dirlen = 0
for dirs,subdirs,files in os.walk(dir):
    print(dirs)

    for file in files:
        if file.endswith("Event.xml"):# and  file.startswith("P01_SG12_T01"):
#            print(file)
            with open(os.path.join(dirs,file),"r",encoding="utf-8") as infile:
#                                root = etree.parse(myfile)
#                file=file.replace(".Event.xml",".txt")
                allids={}
                myfile=infile.read()
                myfile=myfile.replace("logfile","LogFile")
                root = etree.fromstring(myfile)
#                root=tree.getroot()
                ttdict={}#
                segmentdict={}
                alignmentdict={}

                for i,item in enumerate(root.iter("Mod")):
#                    print("Item", item)
                    
#                    allids.setdefault("Char",[]).append(item.attrib["char"])#.replace("\"",""))
                    allids.setdefault("Id",[]).append(i)#.replace("\"",""))
                    allids.setdefault("Cur",[]).append(int(item.attrib["cur"]))
                    allids.setdefault("Type",[]).append(item.attrib["type"])
#                    allids.setdefault("Char",[]).append(item.attrib["chr"] if item.attrib["type"]=="Mins" else "*")
                    allids.setdefault("CharRaw",[]).append(item.attrib["chr"])# if line[header.index("Type")]=="Mins" else "*")
                    allids.setdefault("Time",[]).append(int(item.attrib["time"]))# if line[header.index("Type")]=="Mins" else "*")
                    allids.setdefault("TT",[]).append(int(item.attrib["tid"]))# if line[header.index("Type")]=="Mins" else "*")

                for i,item in enumerate(root.iter("FinalToken")):
                    for ttoken in item:
                        ttdict[int(ttoken.attrib["id"])]=ttoken.attrib["tok"]#line[header.index("TToken")].replace("\"","")
                        segmentdict[int(ttoken.attrib["id"])]=ttoken.attrib["segId"]#line[header.index("TToken")].replace("\"","")
#                alignmentdict={}
                for i,alignment in enumerate(root.iter("Align")):
                    alignmentdict.setdefault(int(alignment.attrib["tid"]),[]).append(alignment.attrib["sid"])#].append(alignment.attrib["sid"])#line[header.index("TToken")].replace("\"","")
                for alignment in alignmentdict:
                    alignmentdict[alignment]="+".join(alignmentdict[alignment])
#                for i,alignment in enumerate(root.iter("Align")):

            redodict={}    
#            allids={}
            char=[]
            charids=[]
            delcur=[]
            delchar=[]
            delids=[]
            delpos=[]
            delcurmix=[]
            tt=[]
            deltt=[]
            delcurint=[]
            final=[]

            mytokdict={}
            mydelsurverydict={}
            final=[]
            for i,item in enumerate(allids["Type"]):
                try:
                    if item=="Mins":
                        final.insert(int(allids["Cur"][i]),[allids["CharRaw"][i],allids["Id"][i]])
                    if item=="Mdel":
                        if allids["CharRaw"][i]==final[int(allids["Cur"][i])][0]:
                            
#                                    print("here")
                            mydelsurverydict[allids["Id"][i]]=str(final[int(allids["Cur"][i])][1])
                        del final[int(allids["Cur"][i])]  
                except:
                    pass
                mytokdict.setdefault(int(allids["TT"][i]),[]).append(int(allids["Id"][i]))
            
            deldict={}
            mydellist=[]
            mydelref=[]
            mydelcurlist=[]
            chartok=[]
            mydeltok=[]
            mycompdellist=[]
            mycompdeltok=[]
            for i,item in enumerate(allids["Type"]):
                if allids["CharRaw"][i]!=" ":
                    if item=="Mdel" and len(mydellist)==0:
                            mydellist.append(int(allids["Id"][i]))
                            try:
                                mycompdellist.append(int(mydelsurverydict[allids["Id"][i]]))
                                mycompdeltok.append(int(allids["TT"][i]))

                            except:
                                pass
                            mydelcurlist.append(int(allids["Cur"][i]))
                            mydelref.append(int(allids["Id"][i]))
                            mydeltok.append(int(allids["TT"][i]))
                            
                    elif item=="Mdel" and len(char)==0:
                            mydellist.append(int(allids["Id"][i]))
                            try:
                                mycompdellist.append(int(mydelsurverydict[allids["Id"][i]]))
                                mycompdeltok.append(int(allids["TT"][i]))
                            except:
                                pass
                            mydelcurlist.append(int(allids["Cur"][i]))
                            mydelref.append(int(allids["Id"][i]))
                            mydeltok.append(int(allids["TT"][i]))

                    elif item=="Mdel" and len(char)>0:
                        deldict.setdefault("CharsTok",[]).append(chartok)
                        deldict.setdefault("CharsId",[]).append(char)
                        char=[]
                        chartok=[]
                        mydellist.append(int(allids["Id"][i]))
                        try:
                            mycompdellist.append(int(mydelsurverydict[allids["Id"][i]]))
                            mycompdeltok.append(int(allids["TT"][i]))
                        except:
                            pass
                        mydelcurlist.append(int(allids["Cur"][i]))
                        mydelref.append(int(allids["Id"][i]))
                        mydeltok.append(int(allids["TT"][i]))

                            
                            
                            
                    if item =="Mins" and len(mydellist)>0:
                        char.append(allids["Id"][i])
                        chartok.append(int(allids["TT"][i]))

                        deldict.setdefault("DeletedComp",[]).append(mycompdellist)
                        deldict.setdefault("DeletedCompTok",[]).append(mycompdeltok)
                    
                        deldict.setdefault("DeletedallId",[]).append(mydellist)
                        deldict.setdefault("DeletedspecId",[]).append(mydelref)
                        deldict.setdefault("DeletedCur",[]).append(mydelcurlist)
                        if char not in deldict.setdefault("CharsId",[]):
                            deldict.setdefault("CharsId",[]).append(char)
                            deldict.setdefault("CharsTok",[]).append(chartok)
                        deldict.setdefault("Deltok",[]).append(mydeltok)
                        mycompdellist=[]
                        mydelcurlist=[]
                        mydelref=[]
                        mydellist=[]
                        mycompdeltok=[]
                        mydeltok=[]

                else:# space==True:
                    deldict.setdefault("DeletedComp",[]).append(mycompdellist)
                    deldict.setdefault("DeletedCompTok",[]).append(mycompdeltok)

                    deldict.setdefault("DeletedallId",[]).append(mydellist)
                    deldict.setdefault("DeletedspecId",[]).append(mydelref)
                    deldict.setdefault("DeletedCur",[]).append(mydelcurlist)
                    if char not in deldict.setdefault("CharsId",[]):
                        deldict.setdefault("CharsId",[]).append(char)
#                                print(char)
                        deldict.setdefault("CharsTok",[]).append(chartok)
                    deldict.setdefault("Deltok",[]).append(mydeltok)
                    mydelcurlist=[]
                    mydelref=[]
                    mydellist=[]
                    char=[]
                    space=False
                    chartok=[]
                    mydeltok=[]
                    mycompdellist=[]
#%%            
            
                            
                            
                            
            for item in deldict.setdefault("DeletedspecId",[]):
                mylist=[]
                for stuff in item:
                    
                    mylist.append(allids["CharRaw"][int(stuff)])
                deldict.setdefault("DelChar",[]).append(mylist)
            for item in deldict.setdefault("DeletedComp",[]):
                mylist=[]
                for stuff in sorted(item):
                    
                    mylist.append(allids["CharRaw"][int(stuff)])
                deldict.setdefault("DelCharComp",[]).append(mylist)

            #################################################                #
            for i,item in enumerate(deldict.setdefault("DeletedCur",[])):
                try:
                    deldict["DelChar"][i] = [x for _,x in sorted(zip(item,deldict["DelChar"][i]))]
                except:
                    pass#        
            for item in deldict.setdefault("CharsId",[]):
                mylist=[]
                for stuff in item:
                    
                    mylist.append(allids["CharRaw"][int(stuff)])
                deldict.setdefault("Char",[]).append(mylist)
                
                
            deldict["AllChar"]=deldict.setdefault("DelCharComp",[])+deldict.setdefault("DelChar",[])+deldict.setdefault("Char",[])
            deldict["AllCharId"]=deldict.setdefault("DeletedComp",[])+deldict.setdefault("DeletedallId",[])+deldict.setdefault("CharsId",[])
            deldict["TT"]=deldict.setdefault("DeletedCompTok",[])+deldict.setdefault("Deltok",[])+deldict.setdefault("CharsTok",[])
            for j,item in enumerate(deldict["AllChar"]):
                if len(item)>2:
                    tokenlist=[]
                    for token in list(ttdict.keys())[int(min(deldict.setdefault("TT",[])[j]))-1:int(min(deldict.setdefault("TT",[])[j]))+5]:
                        if "".join(item).lower() in ttdict[token].lower():
                            tokenlist.append([deldict["AllCharId"][j],0.0,"".join(item),ttdict[token],levenshtein(ttdict[token].lower(),"".join(item).lower()),max(len(ttdict[token]),len(item)),"".join(item).lower(),token]) 
                        else:
                            tokenlist.append([deldict["AllCharId"][j],levenshtein(ttdict[token].lower(),"".join(item).lower())/max(len(ttdict[token]),len(item)),"".join(item),ttdict[token],levenshtein(ttdict[token].lower(),"".join(item).lower()),max(len(ttdict[token]),len(item)),"".join(item).lower(),token]) 
    
                    if tokenlist!=[]:
                        tokenlist.sort(key=lambda x: x[1])
                        for item in tokenlist[0][0]:
                            if tokenlist[0][1]<9:
                                if item not in redodict:
                                    
                                    redodict[item]=tokenlist[0]
    
    #
#%%
            for i,mod in enumerate(root.iter("Mod")):
                if i in redodict:
                    if redodict[i][-1] in alignmentdict:
                        mod.attrib["sid"]=str(alignmentdict[redodict[i][-1]])
                    else:
                        pass
                    mod.attrib["segId"]=str(segmentdict[redodict[i][-1]])
                    
                    mod.attrib["tid"]=str(redodict[i][-1])
                    mod.attrib["CoherentEdit"]=str(len(redodict[i][2]))
                    mod.attrib["LSDist"]=str(int(redodict[i][4]))
#                    mod.attrib["Length"]=redodict[i][4]
                else:

#                    mod.attrib["tid"]=""
                    mod.attrib["CoherentEdit"]="0"
                    mod.attrib["LSDist"]="0"
            out=etree.ElementTree(root)
            out.write(os.path.join(dirs,file), pretty_print=True,encoding="utf-8")
