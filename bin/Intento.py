import os
import sys
import os.path
import glob
import re
import numpy as np
from nltk.translate import AlignedSent, Alignment
import xmltodict
from collections import namedtuple, OrderedDict

# MT systems
import requests
import json

sys.path.append('/data/critt/tprdb/bin/')
import TPRDB
import importlib
importlib.reload(TPRDB)

MT_Engines1 = {'microsoftV3': "ai.text.translate.microsoft.translator_text_api.3-0",
            'deepLv2': "ai.text.translate.deepl.api.v2",
            'proMT': "ai.text.translate.promt.cloud_api.1-0",
            'yandexV2': "ai.text.translate.yandex.cloud-translate.v2",
            'amazon': "ai.text.translate.amazon.translate",
            'baidu': "ai.text.translate.baidu.translate_api",
            'googleAdvanced': "ai.text.translate.google.translate_api.v3",
            'IBMwatsonV3': "ai.text.translate.ibm-language-translator-v3",
            'modernMT': "ai.text.translate.modernmt.enterprise",
            'tencent': "ai.text.translate.tencent.machine_translation_api"
}
MT_Engines = {'01': "ai.text.translate.microsoft.translator_text_api.3-0",
            '02': "ai.text.translate.deepl.api.v2",
            '03': "ai.text.translate.promt.cloud_api.1-0",
            '04': "ai.text.translate.yandex.cloud-translate.v2",
            '05': "ai.text.translate.amazon.translate",
            '06': "ai.text.translate.baidu.translate_api",
            '07': "ai.text.translate.google.translate_api.v3",
            '08': "ai.text.translate.ibm-language-translator-v3",
            '09': "ai.text.translate.modernmt.enterprise",
            '10': "ai.text.translate.tencent.machine_translation_api"
}


# MT systems
MTsystems = {"en_es" : 
             {'01': "ai.text.translate.microsoft.translator_text_api.3-0",
            '02': "ai.text.translate.deepl.api.v2",
            '03': "ai.text.translate.promt.cloud_api.1-0",
            '04': "ai.text.translate.yandex.cloud-translate.v2",
            '05': "ai.text.translate.amazon.translate",
            '06': "ai.text.translate.baidu.translate_api",
            '07': "ai.text.translate.google.translate_api.v3",
            '08': "ai.text.translate.ibm-language-translator-v3",
            '09': "ai.text.translate.modernmt.enterprise",
            '10': "ai.text.translate.tencent.machine_translation_api"
             }, 
            "zh_en":
             {'01': "ai.text.translate.microsoft.translator_text_api.3-0",
            '02': "ai.text.translate.deepl.api.v2",
            '03': "ai.text.translate.promt.cloud_api.1-0",
            '04': "ai.text.translate.yandex.cloud-translate.v2",
            '05': "ai.text.translate.amazon.translate",
            '06': "ai.text.translate.baidu.translate_api",
            '07': "ai.text.translate.google.translate_api.v3",
            '08': "ai.text.translate.ibm-language-translator-v3",
            '09': "ai.text.translate.modernmt.enterprise",
            '10': "ai.text.translate.tencent.machine_translation_api"
             } 
            }

# generates Translog-II files with MT output
def Intento(inStudy, outStudy, sourcLang, targetLang, reverse, verbose = 1) :
           
    template = "/data/critt/tprdb/bin/translog_template.xml"
    if (sourcLang + "_" + targetLang in MTsystems) :
        M = MTsystems[sourcLang + "_" + targetLang]
    else :
        M = MT_Engines
#        print(f"Intento: undefined language pair SL:{sourcLang}, TL:{targetLang}\n")
#        return 1
        
    if(verbose) : print(f"Intento:{inStudy} out:{outStudy} reverse:{reverse} verb:{verbose}\n")

    study = readAtagStudy(inStudy + "/Alignment", singleST=True, verbose=0)  

    for mt in M:
        print(f"MTengines: mt:{mt} sessions:{len(study)} reverse:{reverse}")
#        if(verbose) : print(f"MTengines: mt:{mt} sessions {len(study)} reverse:{reverse}-verb:{verbose}")
        for session in study:
            T=[]
            rev = 'src'
            if(reverse) : rev = 'tgt'

            if(verbose) : print(f"\tSession: {session} segments: {len(study[session][rev])}")
            for st in study[session][rev]:
                tt = getTranslation(M[mt], st, sourcLang, targetLang)                
                if(verbose > 1):  print(f"MT:{mt}\ts:<{st}>\n\tt:<{tt}>\n")
                T.append(tt)
                
            study[session]['MT'] = T

        toTranslogXML(study, outStudy + "/Translog-II", mt, template, sourcLang, targetLang, verbose = 0)
    return 1


def getTranslation(mtSystem, sourceSegment, SL, TL):
    
#    return sourceSegment

    production_APIkey = "q0QwjXgiqoUySQ0PPrchlc1H5jt8G3TZ"

    
    # This is the JSON format that Intento uses
    payload = {
        "context": {
            "text": sourceSegment,
            "from": SL,
            "to": TL
        },
        "service": {
            "provider": mtSystem
        }
    }

    # This is the URL for Intento's API
    # Here's their documentation https://github.com/intento/intento-api#basic-usage
    url = 'https://api.inten.to/ai/text/translate'

    # create variable for API key.
    key = {"apikey": production_APIkey}

    # Make a variable that makes a JSON format POST request to the intento API (r)
    r = requests.post(url, json=payload, headers=key)
    # If no error in POST request..
    if r.ok:
        # Now make a variable that turns the JSON-formatted response into a python dictionary
        slurp_dictionary = json.loads(r.content)

        # Change the value of the 'results' key in the slurp_dictionary to str (the t9n results)
        # Then create variable with this string
        targetSegment = str(slurp_dictionary.get('results')[0])
        
        return targetSegment
    # If error in POST request, don't return anything, just print status code and error message
    else:
        print(r.status_code)
        print(r.content)
    return ""

def readAtagStudy(inStudy, singleST=False, verbose=0):
    H = {}
    R = {}

    for fn in glob.glob(inStudy + "/" + "*"):
           
        if not fn.endswith(("src", "tgt")) : 
            if(verbose): print ("skipping:\t", fn)
            continue
                       
        x = re.match(r".*/P.*_[^0-9](.*)$", fn)
        if(singleST) :
            if (x.group(1)) in R: 
                if(verbose) : print(f"duplicate skipping {fn}")
                continue
            R[x.group(1)] = 1
                
        with open(fn, encoding='utf-8') as fd:
            xml = xmltodict.parse(fd.read(), encoding='utf-8')

        sta = "tgt"
        if(fn.endswith("src")) : sta = "src"
 
        x = re.search(r"/(P[0-9]+_[^0-9]*[0-9]+)", fn)
        session = x.group(1)
        
        if(verbose) : print ("reading: ", fn, "\t", sta, x.group(1))

        segment = ""
        LsegId = 0
        for w in xml['Text']['W']:
#            print(w)
            segId = 1
            if('@segId' in w): segId = int(w['@segId'])
                    
            if((segId != LsegId) and (LsegId > 0)) : 
                H.setdefault(session, {})
                H[session].setdefault(sta, [])
                H[session][sta].append(segment)
#                print (f"{session}.{sta}:{LsegId}-{segId}:\t<{segment}>")
                segment = ""

            LsegId = segId              
#            text = str(w.get('#text'))
            if('@space' in w): segment += w.get('@space')
            if('#text'  in w): segment += w.get('#text')
#            print (f"AAAA: {session}.{sta}-{segId}\tseg:<{segment}>")
       
        if(segment != ''):
            H.setdefault(session, {})
            H[session].setdefault(sta, [])
            H[session][sta].append(segment)
            segment = ''
#        if(verbose): print (f"{session}.{sta}:\t{H[session][sta]}")
    return H

def toTranslogXML(study, Opath, mt, template, sourceLang, targetLang, verbose = 0):

    if not os.path.exists(Opath):
        os.makedirs(Opath)
        if (verbose > 0) : print("toTranslogXML: Directory " , Opath ,  " Created ")

    for session in study:
            
     #  read the xml template file
        with open(template, encoding='utf-8') as fd:
            target_xml = xmltodict.parse(fd.read(), encoding='utf-8')
        
        
        x = re.search(r"P.*_[^0-9]*(.*)$", session)
        if(x) : Sname = "P" + str(mt) + "_" + "MT" + str(x.group(1))
            
        updated_xml = translogXml(study[session], sourceLang, targetLang, Sname, target_xml)

        if(verbose) : print("toTranslogXML: write: " + Opath +  "/" + Sname + ".xml")
            
        f = open(Opath + "/" + Sname + ".xml", 'w', encoding='utf-8')
        
        xml = xmltodict.unparse(updated_xml, pretty=True, short_empty_elements=True)
        
        events = 0
        eventSorted = {}
        for line in xml.split("\n"):  
            if re.search("</Events>", line) :
                for k,v in sorted(eventSorted.items()):
                    print(v, file=f)
                events = 0
            if(events):
                time = re.findall(r"Time=\"([0-9]+)\"", line)[0]
                eventSorted[int(time)] = line
            else: print(line, file=f)

            if re.search("<Events>", line) : events = 1

        f.close()

    return 1


def translogXml(session, sourceLang, targetLang, Sname, target_xml=OrderedDict()):

    position = 0
    keystrokes = []
    
    sourceText = '\n'.join(session['src'])
    targetText = '\n'.join(session['MT'])
    mtOutput = '\n'.join(session['MT'])
    
#    for segId in range(len(session['src'])):                      
#        tgt = session['MT'][segId]                
#    
#        ks = {'Time': str(position+1), 'Cursor': str(position), 'Type': "insert", 'Value': tgt, 'segId': segId}
#        keystrokes += [ks]
#        position += len(tgt)

    if(verbose): print(f"sourceText:<{sourceText}>\ntargetText:\t<{targetText}>")

    target_xml = addKeystrokes(keystrokes, position + 1, target_xml)
    target_xml = addSourceText(sourceText, target_xml)
    target_xml = addMTTargetText(mtOutput, target_xml)
    target_xml = addSourceTextChar(sourceText, target_xml)
    target_xml = addTargetTextChar(targetText, target_xml)
    target_xml = addFinalText(targetText, target_xml)

#    target_xml['LogFile']['startTime'] = started_time
#    target_xml['LogFile']['endTime'] = end_time
    target_xml['LogFile']['Project']['FileName'] = Sname
    target_xml['LogFile']['Project']['Description'] = "Qualitivity"
    
# add new segment marker
    target_xml['LogFile']['Project']['Languages']['@source'] = sourceLang 
    target_xml['LogFile']['Project']['Languages']['@target'] = targetLang
    target_xml['LogFile']['Project']['Languages']['@task'] = "MT"

    return target_xml


def addKeystrokes(keystrokes, final_stop_ts, target_xml):
    if target_xml.get('LogFile').get('Events'):
        target_xml['LogFile']['Events']['System'] = []
        target_xml['LogFile']['Events']['Key'] = []
    else:
        target_xml['LogFile']['Events'] = OrderedDict()
        target_xml['LogFile']['Events']['System'] = []
        target_xml['LogFile']['Events']['Key'] = []

    system = target_xml['LogFile']['Events']['System']
    system.append({'@Time': '0', '@Value': 'START'})
    system.append({'@Time': final_stop_ts, '@Value': 'STOP'})

    keys = target_xml['LogFile']['Events']['Key']
    # keys.append(OrderedDict())
    for ks in keystrokes:
        keys.append(addKsToDict(ks))


    target_xml['LogFile']['Events']['Key'] = keys
    target_xml['LogFile']['Events']['System'] = system

    return target_xml


def addKsToDict(keystrokes_dic):
    # in case of delete keystroke the xml tag should be 
    # <Key Text="suo" Time="90666" Cursor="13" Type="delete"/>
    if keystrokes_dic.get('Type') == 'delete':
        new_dict = {'@Text': keystrokes_dic.get('Value'), '@Time': keystrokes_dic.get('Time'),
                    '@Cursor': keystrokes_dic.get('Cursor'), '@Type': keystrokes_dic.get('Type'), '@segId': keystrokes_dic.get('segId')}
    else:
        new_dict = {'@Value': keystrokes_dic.get('Value'), '@Time': keystrokes_dic.get('Time'),
                    '@Cursor': keystrokes_dic.get('Cursor'), '@Type': keystrokes_dic.get('Type'), '@segId': keystrokes_dic.get('segId')}
    return OrderedDict(new_dict)


def addSourceText(sourceText, target_xml):
    sourceText = re.sub(r"\n", "\\\\par\n", sourceText)
    target_xml['LogFile']['Project']['Interface']['Standard']['Settings']['SourceText'] = "{\\rtf1" + sourceText + "}"
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
    targetText = re.sub(r"\n","\\\\par\n", targetText)
    target_xml['LogFile']['Project']['Interface']['Standard']['Settings']['TargetText'] = "{\\rtf1" + targetText + "}"
    return target_xml


def addFinalText(finalText, target_xml):
    target_xml['LogFile']['FinalText'] = finalText
    return target_xml


if __name__ == '__main__':

    arguments = sys.argv
    args_len = len(sys.argv)
    output_file = ''
    verbose = 1
    reverse = 0

    if args_len < 2:
        exit()
    else:
        input_file = arguments[1]
        output_file = arguments[2]
        sourceLang = arguments[3]
        targetLang = arguments[4]
        reverse = arguments[5]
    if "-v" in arguments:
        verbose = int(arguments[arguments.index("-v") + 1])
 
    Intento(input_file, output_file, sourceLang, targetLang, reverse, verbose=verbose)
