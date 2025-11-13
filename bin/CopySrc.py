import os
import sys
import os.path
import glob
import re
import shutil

# copy src files from src Study to tgt Study
def CopySrc(Orig, Dest, verbose=1):
    
    SRC = {}
    ALN = {}
    MAP = {}
    if(verbose>1) : print(Orig, Dest, verbose)
    for session in glob.glob(Orig + "*"):
        if not session.endswith(("src", "atag")): continue
            
        x = re.search(r"P.*_[^0-9]*([0-9]*).*$", session)
        # keep only one 
        if(verbose>1) : print("ORIG", x.group(1), session)
            
        if(session.endswith("src")) :
            if(x.group(1) in SRC): continue
            SRC[x.group(1)] = session
            print("STC", session, x.group(1))
            idx = 0
            with open(session, "r") as file_input:
                for line in file_input:
                    s = re.search(' segId="([0-9]*)"', line)
                    i = re.search(' id="([0-9]*)"', line)
                    w = re.search('>([^<]*)<', line)
                    
                    if(s and i): 
                        idx = int(i.group(1))
                        MAP.setdefault(x.group(1), {})
                        MAP[x.group(1)].setdefault("w", {})
                        MAP[x.group(1)].setdefault("s", {})
                        MAP[x.group(1)]["w"].setdefault(idx, {})
                        MAP[x.group(1)]["w"][idx]["w"] = w.group(1)
                        MAP[x.group(1)]["w"][idx]["s"] = s.group(1)
                
        if(session.endswith("atag")) :
            if (x.group(1) in ALN): continue
            ALN[x.group(1)] = session
            print("ALN:", x)

    for session in glob.glob(Dest + "*"):
        x = re.search(r"P.*_[^0-9]*([0-9]*).*$", session)
        if(verbose): print("DEST1", session, x.group(1))
        
        if session.endswith("src"):
            if(x.group(1) in MAP): 
                if(verbose) : print("SRC MAPPING:", session)
                with open(session, "r") as file_input:
                    off = 0
                    for line in file_input:
#                        print("DEST3:", line)
                        s = re.search(' segId="([0-9]*)"', line)
                        i = re.search(' id="([0-9]*)"', line)
                        w = re.search('>([^<]*)<', line)
                        if (not s): continue

                        idx = int(i.group(1))
                        seg = int(s.group(1))
                        if(idx not in MAP[x.group(1)]["w"]):
                            print("WARNING:", i.group(1) , "not in MAP")
                            continue
                            
                        if(MAP[x.group(1)]["w"][idx + off]["w"] == w.group(1)) : 
                            aln = int(MAP[x.group(1)]["w"][idx  + off]["s"])
                            MAP[x.group(1)]["s"][seg] = aln
                        elif(MAP[x.group(1)]["w"][idx + off + 1]["w"] == w.group(1)) :
                            off += 1
                            print("WARNING:", idx, "offset", off )
                        elif(MAP[x.group(1)]["w"][idx + off - 1]["w"] == w.group(1)) :
                            off -= 1
                            print("WARNING:", idx, "offset", off )
                        elif(MAP[x.group(1)]["w"][idx + off + 2]["w"] == w.group(1)) :
                            off += 2
                            print("WARNING:", idx, "offset", off )
                        elif(MAP[x.group(1)]["w"][idx + off - 2]["w"] == w.group(1)) :
                            off -= 2
                            print("WARNING:", idx, "offset", off )
                        else :                                      
                            print("WARNING:", w.group(1) , "not in MAP:", idx)
                            continue
                

    for session in glob.glob(Dest + "*"):
        x = re.search(r"P.*_[^0-9]*([0-9]*).*$", session)
        if(verbose): print("DEST2", session, x.group(1))
        
        if session.endswith("tgt"): 
            with open(session, "r+") as fin:
                lines = fin.readlines()
                fin.seek(0)
                fin.truncate()
                aln = 1
                for line in lines:
                    s = re.search(' segId="([0-9]*)"', line)
                    if(s):
                        seg = int(s.group(1))
                        if(seg in  MAP[x.group(1)]["s"]) :
                            aln = MAP[x.group(1)]["s"][seg]
                        else:
                            print(f"WARNING: tgt segId {seg} not in list, taking:{aln}")
                            print(f'segId {MAP[x.group(1)]["s"]}')

                        line = re.sub(f'segId="{seg}"', f'segId="{aln}"', line)                   
                    fin.write(line)

        if session.endswith("src"): 
            if(x.group(1) in SRC): 
                if(verbose) : print("copy", SRC[x.group(1)], session)
                shutil.copy2(SRC[x.group(1)], session)

        if session.endswith("atag"): 
            if(x.group(1) in ALN): 
                if(verbose) : print("copy", ALN[x.group(1)], session)
                with open(ALN[x.group(1)], "r") as file_input:
                    with open(session, "w") as output: 
                        for line in file_input:
                            if "<align " not in line: 
                                output.write(line)
        
if __name__ == '__main__':

    arguments = sys.argv
    args_len = len(sys.argv)
    input_file = ''
    output_file = ''
    verbose = 0

    if args_len < 2:
        exit()
    else:
        input_file = arguments[1]
        output_file = arguments[2]
    if "-v" in arguments:
        verbose = arguments[arguments.index("-v") + 1]
 

    CopySrc(input_file, output_file, verbose=verbose)
