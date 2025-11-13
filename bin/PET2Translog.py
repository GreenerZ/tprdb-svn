#!/usr/bin/env python3
# coding: utf-8

import re
import sys
import os.path
from dateutil.parser import parse
import xmltodict
from collections import namedtuple
from collections import OrderedDict
import logging
import xml.etree.ElementTree as ET

# Set the logging basic level = INFO
logging.basicConfig(format='[%(levelname)s] %(message)s')
logger = logging.getLogger(__file__)
logger.setLevel(logging.ERROR)


def PET2Translog(xmlDoc):
    # Keeps track if the task is Translation or Post-editing
    task = "translating"
	
    SEGS = {}
	
    for unit in xmlDoc['job']['unit']:
        seg = int(unit['@id'])
        task = str(unit['@type'])
        if "S" in unit: source = unit['S'].get('#text')
		
        version = ''
        if "MT" in unit: version = unit['MT'].get('#text')
		
        SEGS.setdefault(seg, {})
        SEGS[seg]['ST'] = source
        SEGS[seg]['MT'] = version
        SEGS[seg]['task'] = task
        SEGS[seg]['name'] = xmlDoc['job']['@id']
        SEGS[seg]['keys'] = {}

        start = 10000000
        end = 0
        KEYS = {}

        target = ''
        annotations = unit['annotations']['annotation']
		
        if isinstance(annotations, OrderedDict):
            annotations = [annotations]
			
        for annotation in annotations:
            r = annotation['@r']
					
            if "HT" in annotation: 
                target = annotation['HT'].get('#text')
                SEGS[seg]['type'] = 'HT'				
            elif "PE" in annotation: 
                target = annotation['PE'].get('#text')
                SEGS[seg]['type'] = 'PE'			
            else: print("No String:", annotation)
			
            SEGS[seg]['TT'] = target

            time = sortEvents(KEYS, annotation["events"], seg, r, end)
            end += time + 1000
            integrateTimestamps(KEYS)

            k = keystrokesText(KEYS)
            if (target	!= 	k) :
                print ("DIFFERENT SEGMENT: unit", seg, "annotation:", r, "\n**T\t", target, "\n**K\t", k)
                keystrokesText(KEYS, plot=True)
            else: print("SEGMENT RECONSTRUCTED: unit", seg, "annotation:", r)
#            else: print("SEGMENT RECONSTRUCTED: unit", seg, "annotation:", r, "\t", target)
        SEGS[seg]['keys']= KEYS
        SEGS[seg]['start'] = start
        SEGS[seg]['end'] = end	
    return SEGS

def eventsType(E, LIST, type, seg, r, end) :

    last = 0
    for event in LIST: 
        time = int(event['@t'])
        t = time + end
        E.setdefault(t, {})
        E[t]['time'] = t
        E[t]['t'] = time
        E[t]['seg'] = seg
        E[t]['r'] = r
        if ("@offset" in event): E[t]['off'] = int(event['@offset'])
#        else : print("NO OFFSET:", event)
		
        if (type == 'change'): 
            if ("in" in event): E[t]['ins'] = str(event["in"])
            if ("out" in event): E[t]['del'] = str(event["out"])
#            print("AAAA:", E[t], "\t", event)
        k = ''
        if ("#text" in event): k = str(event['#text'])
        if (type == 'command'): E[t]['com'] = k
        if (type == 'keystroke'): E[t]['key'] = k
        if (type == 'flow'): 
            if (k == 'EDITING_START') :
                E[t]['key'] = 'START'
                E[t]['off'] = 0
                print("Editing Start:")
                E[t]['del'] = keystrokesText(E, end=t, plot=True)
            else: E[t]['skip'] = 1
        if (time > last): last = time
    return (last, E)

def sortEvents(E, events, seg, r, end) :

    t1 = t2 = t3 = t4 = 0
    if "keystroke" in events :
        keystroke = events["keystroke"]
        if isinstance(keystroke, OrderedDict):  keystroke = [keystroke]
        (t1, E) = eventsType(E, keystroke, "keystroke", seg, r, end)

#    print("keystroke:", E)
	
    if "change" in events :
        change = events["change"]
        if isinstance(change, OrderedDict):  change = [change]
        (t2, E) = eventsType(E, change, "change", seg, r, end)
				
 					
    if "command" in events :
        command = events["command"]
        if isinstance(command, OrderedDict):  command = [command]
        t3, E = eventsType(E, command, "command", seg, r, end)

    if "flow" in events :
        flow = events["flow"]
        if isinstance(flow, OrderedDict):  flow = [flow]
        t4, E = eventsType(E, flow, "flow", seg, r, end)
	

    return max([t1, t2, t3, t4])


def keystrokesText(KEYS, end=-1, plot = False):

    s = ''
    for time in sorted(KEYS):
        if('skip' in KEYS[time]) : continue
        if(end != -1) and (time >= end) : return s
		
        o = KEYS[time]['off']
        if("del" in KEYS[time]) : s = s[:o] +  s[o + len(KEYS[time]['del']) :]
        if("ins" in KEYS[time]) : s = s[:o] + KEYS[time]['ins'] + s[o:]

#        print("keystrokesText:", time, KEYS[time], "\n\t", s)
        if(plot) :
            print("keystrokesText:", time, KEYS[time]['seg'], KEYS[time]['r'], "\t", KEYS[time], "\n\t", s)
		
    return s
	

def integrateTimestamps(KEYS):

    N1 = {} # command (BACKSPACE) with no key, in or out
    N2 = {} # change with no key
    N3 = {} # keystroke with no in or out

#    print("integrateTimestamps")
    for time in sorted(KEYS):
        if('skip' in KEYS[time]) : continue
		
        if("off" not in KEYS[time]): print("KEY:", KEYS[time])
        o = KEYS[time]['off']
        if "key" not in KEYS[time] : 
            if ("com" in KEYS[time]): 
                if("ins" not in KEYS[time]) and ("del" not in KEYS[time]) : 
#                    print("N1:", KEYS[time])
                    N1.setdefault(o, {})
                    N1[o][time] = 1
                if("ins" in KEYS[time]) : KEYS[time]['key'] = KEYS[time]['ins']
                if("del" in KEYS[time]) : KEYS[time]['key'] = KEYS[time]['del']
            else : 
#                print("N2:", KEYS[time])
                N2.setdefault(o, {})
                N2[o][time] = 1
        elif ("ins" not in KEYS[time]) and ("del" not in KEYS[time]): 
#            print("N3:", KEYS[time])
            N3.setdefault(o, {})
            N3[o][time] = 1
		
#    for off in N1: print("Incomplete N1:", off, N1[off])
#    for off in N2: print("Incomplete N2:", off, N2[off])
#    for off in N3: print("Incomplete N3:", off, N3[off])

    for off in N1: replaceInsDel(KEYS, off, N1, N2)
    for off in N3: replaceInsDel(KEYS, off, N3, N2)
			
	# trailing changes possibly due to:
	# offset different 
	# time different for in and out
    for off in N2:
        for n2 in N2[off]:
		
		# insertion/deletion could not be matched
            if "skip" not in KEYS[n2]:
                n1 = 0
                if(n2-1 in KEYS) : n1 = n2-1
                elif(n2+1 in KEYS) : n1 = n2+1
                
                if(n1) :
					
					# use offset for modification 
                    if("ins" not in KEYS[n1]) and ("ins" in KEYS[n2]) :
                        KEYS[n1]['ins'] = KEYS[n2]['ins']
                    if("del" not in KEYS[n1]) and ("del" in KEYS[n2]) :
                        KEYS[n1]['del'] = KEYS[n2]['del']
						
#                    print("MAPPING:", KEYS[n1])
						
					# use offset for modification 
                    if(KEYS[n1]['off'] != KEYS[n2]['off']) :
#                        print("different offset:", KEYS[n1]['off'], KEYS[n2]['off'])
# set offset of keystroke to insertion/deletion 
                        KEYS[n1]['off'] = KEYS[n2]['off']
                    KEYS[n2]["skip"] = 1
						
# remaining initialization string of segment after EDITING_START
#                else :
#                    print("NEW TEXT N2:", KEYS[n2])
					
    return KEYS




def replaceInsDel(KEYS, off, N1, N2):

    if(off not in N2) :
# keystrokes/commands with no insertion/deletion at same offset
#        print("No offset", off)
        return KEYS
	
    for t1 in N1[off]:
        n2 = 0
        for t2 in N2[off]:
		
#            if(t2 == 3060):
#                print("NNN1:", N1[off], "N2", N2[off], KEYS[t1])

            if(t1 < t2 + 10) and (t1 > t2 - 10) : 
                n2 = t2

                if ("del" in  KEYS[n2]) and ("del" not in  KEYS[t1]) :
                    KEYS[t1]['del'] = KEYS[n2]['del']
                elif ("del" in  KEYS[n2]): 
                    print("DEL:", N1[off], N2[off], "\n\t",  KEYS[t1], "\n\t",  KEYS[n2])
				
                if ("ins" in  KEYS[n2])  and ("ins" not in  KEYS[t1]) :
                    KEYS[t1]['ins'] = KEYS[n2]['ins']
                elif ("ins" in  KEYS[n2]): 
                    print("INS:", N1[off], N2[off], "\n\t",  KEYS[t1], "\n\t",  KEYS[n2])
								
                KEYS[n2]["skip"] = 1
				
#                print("In time:", KEYS[t1], "\n\t\t", KEYS[n2])

# insertions/deletions without keystokes/commands at same time
#        if(n2 == 0) :
#            print("Out time:", t1, "offset:", off, N2[off])
     
    
    return KEYS


def escapenewline(text):
    """
    Escapes the newline \n with &#10; in the sourcetext, targettext and finaltext
    """
    if text:
        newline = re.findall(r'\n', text)
        if newline:
            text = re.sub(r'\n', '&#10;', text)

    return text


def generateTranslogXml(UNIT, template, SL, TL):

    with open(template, encoding='utf-8') as fd:
        target_xml = xmltodict.parse(fd.read(), encoding='utf-8')
	
    target_xml = addKeystrokes(UNIT, target_xml) 
    target_xml = addSourceText(UNIT["ST"], target_xml)
    target_xml = addMTTargetText(UNIT["MT"], target_xml)
    target_xml = addSourceTextChar(UNIT["ST"], target_xml)
    target_xml = addTargetTextChar(UNIT["TT"], target_xml)
    target_xml = addFinalText(UNIT["TT"], target_xml)
                 

    if(target_xml['LogFile']['Events']['Fix'] != []) :
        target_xml['LogFile']['Project']['Plugins']['EyeSampler'] = ""

    target_xml['LogFile']['Project']['FileName'] = UNIT['name']
    target_xml['LogFile']['Project']['Description'] = "Qualitivity"
    target_xml['LogFile']['Project']['Languages']['@source'] = SL
    target_xml['LogFile']['Project']['Languages']['@target'] = TL
    target_xml['LogFile']['Project']['Languages']['@task'] = UNIT['task']

    return target_xml


def writeXML(output_file, XML):

    # updated_xml = xmltodict.unparse(updated_xml,)
    f = open(output_file, 'w', encoding='utf-8')

    logger.info(f"Output file:\t{output_file}")

    xml = xmltodict.unparse(XML ,pretty=True,short_empty_elements=True)
      
    # sort events by timestamps
    events = 0
    eventSorted = {}
    for line in xml.split("\n"):  
        # end of events section
        if re.search("</Events>", line) :
            for k,v in sorted(eventSorted.items()):
                print(v, file=f)
            events = 0
        if(events):
            time = re.findall(r"Time=\"([0-9]+)\"", line)[0]
            eventSorted[int(time)] = line
        else: print(line, file=f)

        # beginning of events section
        if re.search("<Events>", line) : events = 1
      
    f.close()


def addKeystrokes(UNIT, target_xml):
    if target_xml.get('LogFile').get('Events'):
        target_xml['LogFile']['Events']['System'] = []
        target_xml['LogFile']['Events']['Key'] = []
        target_xml['LogFile']['Events']['Fix'] = [] # Added
    else:
        target_xml['LogFile']['Events'] = OrderedDict()
        target_xml['LogFile']['Events']['System'] = []
        target_xml['LogFile']['Events']['Key'] = []
        target_xml['LogFile']['Events']['Fix'] = [] # Added

    system = target_xml['LogFile']['Events']['System']
    system.append({'@Time': '0', '@Value': 'START'})
    system.append({'@Time': UNIT['end'], '@Value': 'STOP'})

    keys = target_xml['LogFile']['Events']['Key']
    # keys.append(OrderedDict())
#    for seg in SEGS:
    for ks in sorted(UNIT['keys']):
        if 'skip' in UNIT['keys'][ks] : 
#            print("skip:", UNIT['keys'][ks])
            continue

        k = addKsToDict(UNIT['keys'][ks])
        if(k) : keys.append(k)

# for fixation data
#    fix_data = target_xml['LogFile']['Events']['Fix'] # Added
#    for elem in fixations: # Added
#        if(int(elem['Time']) > final_stop_ts): break
#        fix_data.append(addFixToDict(elem)) # Added
#    target_xml['LogFile']['Events']['Fix'] = fix_data # Added

    target_xml['LogFile']['Events']['Key'] = keys
    target_xml['LogFile']['Events']['System'] = system

    return target_xml

def addKsToDict(key):
    # in case of delete keystroke the xml tag should be 
    # <Key Text="suo" Time="90666" Cursor="13" Type="delete"/>
	
    new_dict = {}
    if ("del" in key) and ("ins" in key):
        new_dict = {'@Time': key['time'], '@segId': key['seg'], '@Cursor': key['off'], 
		'@Type': 'insert', '@Text': key['del'],  "@Value": key['ins'] }
    elif "del" in key:
        new_dict = {'@Time': key['time'], '@segId': key['seg'], '@Cursor': key['off'], 
		'@Type': 'delete', '@Text': key['del'],  "@Value": "[Back]" }
    elif "ins" in key:
        new_dict = {'@Time': key['time'], '@segId': key['seg'], '@Cursor': key['off'], 
		'@Type': 'insert', "@Value": key['ins'] }
		
    return OrderedDict(new_dict)

def addFixToDict(fixation): # Added
#    print("SSSSS:", fixation)
    new_dict = {'@Time': fixation['Time'], '@Win': fixation['Win'], '@Dur': fixation['Dur'], '@X': fixation['X'], '@Y': fixation['Y'], '@segId': fixation['segId']} # Added #
    return OrderedDict(new_dict) # Added

def addSourceText(sourceText, target_xml):
    rtf = "\\rtf1\\ansi{\\fonttbl\\f0\\fswiss Helvetica;}\\f0\\pard "
    sourceText = UTF8toRTF(sourceText)
    sourceText = re.sub(r"\n", "\\\\par\n", sourceText)
    target_xml['LogFile']['Project']['Interface']['Standard']['Settings']['SourceText'] = "{" + rtf + sourceText + "}"
    return target_xml

def addSourceTextChar(sourceText, target_xml):
    sourceTextChar = []
    target_xml['LogFile']['SourceTextChar']['CharPos'] = []
    for ind, char in enumerate(sourceText):
        sourceTextChar.append(OrderedDict({'@Cursor': str(ind), '@Value': char}))
    target_xml['LogFile']['SourceTextChar']['CharPos'] = sourceTextChar
    return target_xml

def addTargetTextChar(targetText, target_xml):
    targetTextChar = []
    target_xml['LogFile']['FinalTextChar']['CharPos'] = []
    for ind, char in enumerate(targetText):
        targetTextChar.append(OrderedDict({'@Cursor': str(ind), '@Value': char}))
    target_xml['LogFile']['FinalTextChar']['CharPos'] = targetTextChar
    return target_xml

def addMTTargetText(targetText, target_xml):
    rtf = "\\rtf1\\ansi{\\fonttbl\\f0\\fswiss Helvetica;}\\f0\\pard "
    targetText = UTF8toRTF(targetText)
    targetText = re.sub(r"\n","\\\\par\n", targetText)
    target_xml['LogFile']['Project']['Interface']['Standard']['Settings']['TargetText'] = "{" + rtf + targetText + "}"
    return target_xml

def addFinalText(finalText, target_xml):
    target_xml['LogFile']['FinalText'] = finalText
    return target_xml


def help():

    logger.error(
        f"Usage:\n{__file__} <PET_file>\n" +
        f"{__file__} <PET_file> -o <translog_output_file>\n" +
        f"{__file__} <PET_file> -o <translog_output_file> -e <gaze_file> -t <template_file> --debug\n"
    )
    exit(1)


def UTF8toRTF (rtf) :
    rtf = rtf.replace("¡",  "\\'a1")
    rtf = rtf.replace("¢",  "\\'a2")
    rtf = rtf.replace("£",  "\\'a3")
    rtf = rtf.replace("¤",  "\\'a4")
    rtf = rtf.replace("¥",  "\\'a5")
    rtf = rtf.replace("¦",  "\\'a6")
    rtf = rtf.replace("§",  "\\'a7")
    rtf = rtf.replace("¨",  "\\'a8")
    rtf = rtf.replace("©",  "\\'a9")
    rtf = rtf.replace("ª",  "\\'aa")
    rtf = rtf.replace("«",  "\\'ab")
    rtf = rtf.replace("¬",  "\\'ac")
    rtf = rtf.replace("®",  "\\'ae")
    rtf = rtf.replace("¯",  "\\'af")
    rtf = rtf.replace("°",  "\\'b0")
    rtf = rtf.replace("±",  "\\'b1")
    rtf = rtf.replace("²",  "\\'b2")
    rtf = rtf.replace("³",  "\\'b3")
    rtf = rtf.replace("´",  "\\'b4")
    rtf = rtf.replace("µ",  "\\'b5")
    rtf = rtf.replace("¶",  "\\'b6")
    rtf = rtf.replace("·",  "\\'b7")
    rtf = rtf.replace("¸",  "\\'b8")
    rtf = rtf.replace("¹",  "\\'b9")
    rtf = rtf.replace("º",  "\\'ba")
    rtf = rtf.replace("»",  "\\'bb")
    rtf = rtf.replace("¼",  "\\'bc")
    rtf = rtf.replace("½",  "\\'bd")
    rtf = rtf.replace("¾",  "\\'be")
    rtf = rtf.replace("¿",  "\\'bf")
    rtf = rtf.replace("À",  "\\'c0")
    rtf = rtf.replace("Á",  "\\'c1")
    rtf = rtf.replace("Â",  "\\'c2")
    rtf = rtf.replace("Ã",  "\\'c3")
    rtf = rtf.replace("Ä",  "\\'c4")
    rtf = rtf.replace("Å",  "\\'c5")
    rtf = rtf.replace("Æ",  "\\'c6")
    rtf = rtf.replace("Ç",  "\\'c7")
    rtf = rtf.replace("È",  "\\'c8")
    rtf = rtf.replace("É",  "\\'c9")
    rtf = rtf.replace("Ê",  "\\'ca")
    rtf = rtf.replace("Ë",  "\\'cb")
    rtf = rtf.replace("Ì",  "\\'cc")
    rtf = rtf.replace("Í",  "\\'cd")
    rtf = rtf.replace("Î",  "\\'ce")
    rtf = rtf.replace("Ï",  "\\'cf")
    rtf = rtf.replace("Ð",  "\\'d0")
    rtf = rtf.replace("Ñ",  "\\'d1")
    rtf = rtf.replace("Ò",  "\\'d2")
    rtf = rtf.replace("Ó",  "\\'d3")
    rtf = rtf.replace("Ô",  "\\'d4")
    rtf = rtf.replace("Õ",  "\\'d5")
    rtf = rtf.replace("Ö",  "\\'d6")
    rtf = rtf.replace("×",  "\\'d7")
    rtf = rtf.replace("Ø",  "\\'d8")
    rtf = rtf.replace("Ù",  "\\'d9")
    rtf = rtf.replace("Ú",  "\\'da")
    rtf = rtf.replace("Û",  "\\'db")
    rtf = rtf.replace("Ü",  "\\'dc")
    rtf = rtf.replace("Ý",  "\\'dd")
    rtf = rtf.replace("Þ",  "\\'de")
    rtf = rtf.replace("ß",  "\\'df")
    rtf = rtf.replace("à",  "\\'e0")
    rtf = rtf.replace("á",  "\\'e1")
    rtf = rtf.replace("â",  "\\'e2")
    rtf = rtf.replace("ã",  "\\'e3")
    rtf = rtf.replace("ä",  "\\'e4")
    rtf = rtf.replace("å",  "\\'e5")
    rtf = rtf.replace("æ",  "\\'e6")
    rtf = rtf.replace("ç",  "\\'e7")
    rtf = rtf.replace("è",  "\\'e8")
    rtf = rtf.replace("é",  "\\'e9")
    rtf = rtf.replace("ê",  "\\'ea")
    rtf = rtf.replace("ë",  "\\'eb")
    rtf = rtf.replace("ì",  "\\'ec")
    rtf = rtf.replace("í",  "\\'ed")
    rtf = rtf.replace("î",  "\\'ee")
    rtf = rtf.replace("ï",  "\\'ef")
    rtf = rtf.replace("ð",  "\\'f0")
    rtf = rtf.replace("ñ",  "\\'f1")
    rtf = rtf.replace("ò",  "\\'f2")
    rtf = rtf.replace("ó",  "\\'f3")
    rtf = rtf.replace("ô",  "\\'f4")
    rtf = rtf.replace("õ",  "\\'f5")
    rtf = rtf.replace("ö",  "\\'f6")
    rtf = rtf.replace("÷",  "\\'f7")
    rtf = rtf.replace("ø",  "\\'f8")
    rtf = rtf.replace("ù",  "\\'f9")
    rtf = rtf.replace("ú",  "\\'fa")
    rtf = rtf.replace("û",  "\\'fb")
    rtf = rtf.replace("ü",  "\\'fc")
    rtf = rtf.replace("ý",  "\\'fd")
    rtf = rtf.replace("þ",  "\\'fe")
    rtf = rtf.replace("ÿ",  "\\'ff")
    rtf = rtf.replace("{",  "\\’7b")
    rtf = rtf.replace("|",  "\\’7c")
    rtf = rtf.replace("}",  "\\’7d")
    rtf = rtf.replace("~",  "\\’7e")
    rtf = rtf.replace("͵",  "\\’82")
    rtf = rtf.replace("ƒ",  "\\’83")
    rtf = rtf.replace("†",  "\\’86")
    rtf = rtf.replace("‡",  "\\’87")
    rtf = rtf.replace("‰",  "\\’89")
    rtf = rtf.replace("Š",  "\\’8a")
    rtf = rtf.replace("‹",  "\\’8b")
    rtf = rtf.replace("Œ",  "\\’8c")
    rtf = rtf.replace("Ž",  "\\’8e")
    rtf = rtf.replace("‘",  "\\’91")
    rtf = rtf.replace("’",  "\\’92")
    rtf = rtf.replace("“",  "\\’93")
    rtf = rtf.replace("”",  "\\’94")
    rtf = rtf.replace("•",  "\\’95")
    rtf = rtf.replace("–",  "\\’96")
    rtf = rtf.replace("—",  "\\’97")
    rtf = rtf.replace("~",  "\\’98")
    rtf = rtf.replace("™",  "\\’99")
    rtf = rtf.replace("š",  "\\’9a")
    rtf = rtf.replace("›",  "\\’9b")
    rtf = rtf.replace("œ",  "\\’9c")
    rtf = rtf.replace("ž",  "\\’9e")
    rtf = rtf.replace("Ÿ",  "\\’9f")
    return rtf

def main(input_file, eyetracker_file, output_file, template, SL, TL, loglevel=logging.INFO):
    logger.setLevel(loglevel)

    input_file = os.path.abspath(input_file)
                  
    logger.info(f"-------------------------------------------")
    logger.info(f"Trados file:\t{input_file}")
	
    with open(input_file, encoding='utf-8') as fd:
        inputfile = fd.read()
        tabs = re.findall(r'\t', inputfile)
        if tabs:
            inputfile = re.sub(r'\t', r'\\t', inputfile)
            print("Replaced tabs")
        doc = xmltodict.parse(inputfile, encoding='utf-8', strip_whitespace=False)

    UNITS = PET2Translog(doc)

    head, tail = os.path.split(input_file)
    if not output_file: output_file = head + "/generated_" + tail

    for unit in UNITS:
        file = f"{output_file}{unit:03}.xml"
        XML = generateTranslogXml(UNITS[unit], template, SL, TL)
        writeXML(file, XML)  

    return XML

 
if __name__ == '__main__':

     # Initialize the arguments to main method
    output_file = None
    eyetracker_file = None
    template = None
    SL = 'en'
    TL = 'de'       
    
    loglevel = logging.INFO
        
    arguments = sys.argv
    args_len = len(sys.argv)
    
    if "-h" in arguments:
        help()
    if args_len < 2:
        help()
    else:
        input_file = arguments[1]

        if "--debug" in arguments:
            loglevel = logging.DEBUG
        if "-S" in arguments:
            index = arguments.index("-S") + 1
            SL = arguments[index]
        if "-T" in arguments:
            index = arguments.index("-T") + 1
            TL = arguments[index]
        if "-e" in arguments:
            index = arguments.index("-e") + 1
            try:
                eyetracker_file = arguments[index]
            except IndexError:
                logger.error("Eyetracker file not specified")
                exit(1)
        if "-o" in arguments:
            index = arguments.index("-o") + 1
            try:
                output_file = arguments[index]
            except IndexError:
                logger.error("Output file not specified")
                exit(1)
        if "-t" in arguments:
            index = arguments.index("-t") + 1
            try:
                template = arguments[index]
            except IndexError:
                logger.error("Template file not specified")
                exit(1)
        main(input_file, eyetracker_file, output_file, template, SL, TL, loglevel)

   
