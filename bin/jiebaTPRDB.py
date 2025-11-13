#!/usr/bin/env python3
import sys
import jieba
import re

def main(fileName):

	outFile = fileName.replace("-txt", "-tok")
	o = open(outFile, "w", encoding="utf-8")
	with open(fileName, encoding="utf-8") as inFile:
		for line in inFile:
			seg_list = jieba.cut(line.strip())
			o.write(u'\ttag\n'.join(seg_list).strip())
			o.write(u'\ttag\nEOS\n')



#### this is a version for the entire Translog XML file
def main1(translog):
    tran = open(translog, 'r')
#    outp = open(translog + "." + lng + ".src.zh", 'w')
    print(f"reading file: {translog}")
    final = 0
    
    out = ''
    for line in tran.readlines():
        if(line.find("<Languages ") >= 0) :
            if(line.find('source="zh"') >= 0) : out = translog + ".src.zh"
            elif(line.find('target="zh"')>= 0) : out = translog + ".tgt.zh"
            else : 
                print(f"ERROR: no zh language {line}")
                return(0)
            print(f"writing file: {out}")
            outp = open(out, 'w')
            
        if(line.find("<FinalText>") >= 0): 
            line = line.replace("<FinalText>", "")
            final = 1
        if(line.find("</FinalText>") >= 0): 
            line = line.replace("</FinalText>", "")
            final = 0
            
        if(final == 1 and len(line) > 0):
            seg_list = jieba.cut(line.strip())
            outp.write(u'\ttag\n'.join(seg_list).strip())
            outp.write(u'\ttag\nEOS\n')
            
    tran.close()
    outp.close()




if __name__ == '__main__':
    arguments = sys.argv

    if len(arguments) == 2:
        main(arguments[1])
    else:
        print(f"{arguments[0]} wrong number of parameters {len(sys.argv)}")
