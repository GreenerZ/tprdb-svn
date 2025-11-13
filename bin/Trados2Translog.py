#!/usr/bin/env python3
# coding: utf-8

# ### Post Edited Text

import re
import sys
import os.path
from dateutil.parser import parse
import xmltodict
from collections import namedtuple
from collections import OrderedDict
import logging
import xml.etree.ElementTree as ET
import pandas as pd
import statsmodels.formula.api as smf
import math
import matplotlib.pyplot as plt
import numpy as np

# Set the logging basic level = INFO
logging.basicConfig(format='[%(levelname)s] %(message)s')
logger = logging.getLogger(__file__)
logger.setLevel(logging.ERROR)

# Record format for Translog
Record = namedtuple('Record', ['source', 'targetUpdated', 'captured_keystrokes', 'last_timestamp', 'mt_output'])

# store start and end for each record
TimeDic = {}

# To store the timestamp of the first keystroke of the first ever record
first_timestamp = 0.0


def processTradosFile(xmlDoc, recordNumber=None):
    # Keeps track if the task is Translation or Post-editing
    task = "translating"
    mt_output_counts = 0
    duplicate_records = 0
    records = []
    # Stores the keystores for each segment in a dictionary
    recorded_keystrokes_dict = dict()

    # Fix for iterating <Activity> tag
    # <Activity> contains multiple <Record>. Iterate through each <Activity> and add all <Record> to a list
    activity = xmlDoc['QualitivityProfessional']['Client']['Project']['Activity']

    started_time = 0
    end_time = 0
    activity_tag = None

    if isinstance(activity, OrderedDict):
        activity_tag = activity
        records = activity['Document']['Record']
    elif isinstance(activity, list):
        for act in activity:
            records = records + act['Document']['Record']
        activity_tag = activity[0]
    else:
        logger.error(f"Unknown type of <Activity> : {type(activity)}")

    started_time = activity_tag['@started']
    end_time = activity_tag['@stopped']
#    print(f"start:{started_time}\tend:{end_time}")
    
    source_lang = activity_tag['Document']['@sourceLang']
    if source_lang:
        source_lang = source_lang.split('-')[0]
    target_lang = activity_tag['Document']['@targetLang']
    if target_lang:
        target_lang = target_lang.split('-')[0]
    project_name = xmlDoc['QualitivityProfessional']['Client']['Project']['@name']

    # To store the timestamp of last keystroke of previous record
    last_timestamp = 0.0
    
    # To extract the whole trados xml file
    # Handles the case if the xml file has only 1 record
    if isinstance(records, OrderedDict):
        records = [records]
    for ind, record in enumerate(records):
        # sourceText = record['contentText']['source']
        #print(record, "\n")
        #print("ID:", record['@id'], "\n")
        #print("SID:", record['@segmentId'], "\n")
        
        ############## changed
        targetUpdated = removeHTMLtags(record['contentText']['targetUpdated'])
        recordId = int(record['@id'])
        segmentId = int(record['@segmentId'])
            
        logger.debug(f"TargetUpdate: {targetUpdated}")
        # For some records, the field targetUpdated is absent
        # We assume this record as "not translated"
        # We skip this record
        if not targetUpdated:
            logger.debug(f"No targetUpdated found for Record Id: {recordId}!!")
#                continue

        first = segmentId not in recorded_keystrokes_dict.keys()
        firstTime = last_timestamp
        capturedData = processRecord(record, last_timestamp, first)
        last_timestamp = capturedData.last_timestamp

        if capturedData.mt_output:
            mt_output_counts += 1

            # Check for duplicate segment ids
        if segmentId in recorded_keystrokes_dict.keys():
            duplicate_records += 1
            # previousSegmentId = segment_record_id_dict[segmentId]
            previousCapturedData = recorded_keystrokes_dict[segmentId]
            # previousCapturedData.last_timestamp = capturedData.last_timestamp
            # append the keystrokes
            new_captured_keystrokes = previousCapturedData.captured_keystrokes + capturedData.captured_keystrokes
            # update the last_timestamp and targetUpdated
            recorded_keystrokes_dict[segmentId] = Record(capturedData.source, capturedData.targetUpdated,
                                                         new_captured_keystrokes, capturedData.last_timestamp,
                                                         previousCapturedData.mt_output)
            logger.debug(f"Record ID {recordId} updates existing segment {segmentId}")
        else:
            # segment_record_id_dict[sourceText] = recordId
            recorded_keystrokes_dict[segmentId] = capturedData
            firstTime = 0

# timestamps for texts     
        orig_text = removeHTMLtags(record['contentText']['targetOriginal'])
            # can be 'NoneType'
        if(type(orig_text) != "str") : orig_text = ''
        TimeDic.setdefault(segmentId, {})
        TimeDic[segmentId].setdefault(firstTime, {})
        TimeDic[segmentId][firstTime] = len(orig_text)
#            print(f"REC1: seg:{segmentId} first:{firstTime}\tlen:{len(orig_text)}\ttargetUpdated:{orig_text} ")

        TimeDic[segmentId].setdefault(last_timestamp, {})
        TimeDic[segmentId][last_timestamp] = len(capturedData.targetUpdated)
#        print(f"REC2: seg:{segmentId} last: {last_timestamp}\tlen:{len(capturedData.targetUpdated)}\ttargetUpdated:{capturedData.targetUpdated} ")
            

    if mt_output_counts:
        task = "PE"

    logger.debug(f"Total Number of duplicate records = {duplicate_records}")
    logger.debug(f"Total Number of processed records = {len(recorded_keystrokes_dict.keys())}")

    return recorded_keystrokes_dict, started_time, end_time, source_lang, target_lang, project_name, task


def checkRecordCompleteness(xmlDoc):

    if (not ('QualitivityProfessional' in xmlDoc and 
       'Client'   in xmlDoc['QualitivityProfessional'] and 
       'Project'  in xmlDoc['QualitivityProfessional']['Client'] and
       'Activity' in xmlDoc['QualitivityProfessional']['Client']['Project'] and
       'Document' in xmlDoc['QualitivityProfessional']['Client']['Project']['Activity'] and
       'Record'   in xmlDoc['QualitivityProfessional']['Client']['Project']['Activity']['Document'])) :
        
        logger.error(f"Wrong File Format")
        return 1
 
    records = xmlDoc['QualitivityProfessional']['Client']['Project']['Activity']['Document']['Record']
    segments = set([int(record['@segmentId']) for record in records])
    for i in range(len(segments)) :
        if(i+1 not in segments):
            logger.error(f"checkRecordCompleteness: missing log record for segment: {i+1}\t from {segments}")
#            return 1
    logger.info(f"Segs complete:\t{segments}")
    return 0
    


def removeHTMLtags(text):
#    logger.error(f"HTMLtags0: {text}")
    
    f = 0
#    if(text and re.search(r"highlight=yellow", text)) : 
#        logger.error(f"removeHTMLtags0: {text}")
#        f = 1

    if text and re.findall(r'</?.*?>', text):
        text = re.sub(r'</?.*?>', '', text)
        text = re.sub(r'\xa0', ' ', text)

#    if(f) : logger.error(f"removeHTMLtags1: {text}")

    # Restore the tabs escaped while reading the source file.
    if text:
        text = re.sub(r'\\t', r'\t', text)
    return text


def processRecord(record, last_timestamp, first):
    """
    This method processes each segment(record) of Trados Post Editing XML file
    """
    # Stores the list of keystrokes
    captured_keystrokes = []
    # Stores the output generated by MT systems in case of Post Editing Tasks
    mt_output = ''
    # Stores the timestamp in milisecord (difference between current_ts and first keystroke recorded)
    ts = 0.0

    recordId = record['@id']
    segmentId = record['@segmentId']
    source = removeHTMLtags(record['contentText']['source'])
    targetOriginal = removeHTMLtags(record['contentText']['targetOriginal'])
    targetUpdated = removeHTMLtags(record['contentText']['targetUpdated'])
    if(targetUpdated == None): targetUpdated = ''
    
    recordStoppedTs = record['@stopped']
    recordStoppedTs = convertTimestampToMs(recordStoppedTs)
    recordStartedTs = record['@started']
    recordStartedTs = convertTimestampToMs(recordStartedTs)
    
    # All the timestamps are calculated as difference in ms from  timestamp of very first record of the document
    global first_timestamp
    if(first_timestamp == 0.0): 
        first_timestamp = recordStartedTs

    recordStartedTs = recordStartedTs - first_timestamp
    recordStoppedTs = recordStoppedTs - first_timestamp

    # some records doesn't have any keyStrokes that is <keyStrokes/>
    if not record['keyStrokes']:
#        origin = record['translationOrigins']['original']
#        if(origin.get('@originType')) :
#            mt_output = targetUpdated
# this is perhaps always MT output?
        if(first) :
            mt_output = targetUpdated
        logger.debug(f"No Keystrokes for Record Id: {recordId} and Segment Id: {segmentId}\tfirst:{first}\t{mt_output}")
        return Record(source, targetUpdated, captured_keystrokes, recordStoppedTs, mt_output)

    keystrokes = record['keyStrokes']['ks']
    
#    print(f"PR3 keystrokes1: {type(keystrokes)}\t{keystrokes}")

    if targetOriginal:
        original_text = targetOriginal
    else:
        original_text = ''
        targetOriginal = ''

    # check if MT output in keystrokes
    once = 0
    for ksa in keystrokes:
        # Hack: if only one element in the ks list
        if once: break
        if isinstance(ksa, str) : 
          ks = keystrokes
          once = 1
        else: ks = ksa
        
        system = ks.get('@system')
        # The system attribute contains the MT translation
        # Fetch that text and use it at initial original_text
        if system:
            logger.debug(f"Only MT for Record Id: {recordId} segment Id: {segmentId}")
            original_text = removeHTMLtags(ks.get('@text'))
#            mt_output = ks.get('@text')
            mt_output = removeHTMLtags(original_text)
            if once : 
                return Record(source, targetUpdated, captured_keystrokes, recordStoppedTs, mt_output)
            break

    logger.debug(f"Target Original Text: '{original_text}'")
    

    # Convert the target original_text to array of characters
    orig_text = [w for w in original_text]

    # Assign the first_timestamp to the last_timestamp recorded of the last record

    curr_updated_text = original_text
    once = 0
    for ksa in keystrokes:
        # Hack: if only one element in the ks list
        if once: break
        # in case there is only one entry 'keystrokes' is not a list 
        if isinstance(ksa, str) : 
            ks = keystrokes
            once  = 1
        else: ks = ksa
        
#        print(f"PR5 {once} ksa:{ksa}")
        text = removeHTMLtags(ks.get('@text'))
        key = ks.get('@key')
        position = ks.get('@position')
        pos = int(position)
        created = ks.get('@created')
        selection = removeHTMLtags(ks.get('@selection'))
        system = ks.get('@system')

        # Skip this keystroke as it contains the MT translation and is taken care of earlier
        if system: continue
        
#        print(f"PR6 sel:{selection}, text:{text}")
        
        # ignore if selected text is inserted. 
        if (selection == text): continue

        tt = convertTimestampToMs(created)
        ts = tt - first_timestamp

        # If the keystroke has non empty "selection" attribute
        if selection:
            logger.debug(f"Select operation at position: {position}")

            orig_text, ks_list = extractSelectionKeystrokesPE(orig_text, selection, pos, text, key, ts, segmentId)
            curr_updated_text = ''.join(orig_text)
            for ks in ks_list:
                captured_keystrokes.append(ks)
        # Keystroke is either Insert or Delete
        else:

            # So far this funtionality is not used
            if key == '[BACK]':
                opType = "delete"
                # deletes the characters
                del (orig_text[pos])
                curr_updated_text = ''.join(orig_text)
                logger.debug(f"Delete Operation: at position: {pos}")
                logger.debug(f"\tTarget text after Deletion = '{curr_updated_text}'")

            else:
                opType = "insert"
                for index, char in enumerate(text):
                    orig_text.insert(pos + index, char)
                curr_updated_text = ''.join(orig_text)
                #logger.debug(f"Insert: '{text}' at position: {pos}\t'{curr_updated_text}'")
                #logger.debug(f"\tTarget text after Insert = '{curr_updated_text}'")

            target_ks = {'Time': str(ts), 'Cursor': position, 'Type': opType, 'Value': text, 'segId': segmentId}

            captured_keystrokes.append(target_ks)    

    logger.debug(f"Recovered text: {curr_updated_text}")
    # Validation
    if (targetUpdated == curr_updated_text):
        logger.debug(f"Success for Record Id: {recordId} and Segment Id: {segmentId}")
    else:
        logger.error(f"Mismatch Record Id: {recordId}")
        logger.error(f"\tRecovered: '{curr_updated_text}'")
        logger.error(f"\tTargetUpd: '{targetUpdated}'")

    # For some segments it is observed that there is no MT output
    # However trados picks the translation from Translation memory
    # This is to handle that scenario.
    if not mt_output:
        mt_output = targetOriginal

    return Record(source, targetUpdated, captured_keystrokes, recordStoppedTs, mt_output)


def extractSelectionKeystrokesPE(orig_text, selection, position, text, key, time, segId=None):
    ks_list = []
    curr_updated_text = ''.join(orig_text)
    len_curr_text = len(curr_updated_text)
    logger.debug(f"before: '{curr_updated_text}'")
    logger.debug(f"select: '{selection}'")
#    logger.debug(f"length: text before:{len(curr_updated_text)} selction length: {len(selection)}")
    
    if position == len_curr_text:
        position = position - 1
        logger.debug(f"\tPosition is last character of the string")

    start = position

    # if selection does not match: adjust start
    if(curr_updated_text.find(selection, start) != start) : 
        start =  position - len(selection)
        if(curr_updated_text.find(selection, start) != start) :
            start =  position - len(key)
            o = 1
            m = 1
            while (curr_updated_text.find(selection, start) != start) :
                start =  position - (o*m)       
#                logger.debug(f"\tMismatch:start:{start} pos:{position} sel:{len(selection)}")

                if(start == 0 or start == len(curr_updated_text)) : break
                if(m < 0) : o += 1
                m *= -1
                
        logger.debug(f"\tMismatch reset {position} to {start} matching:{curr_updated_text.find(selection, start)}")
        
    if(curr_updated_text.find(selection, start) != start) : 
        logger.error(f"SelectionOffset seg:{segId} time:{time} Mismatch: start:{start} pos:{position} \
        key:{key}\n\t\tsel:\t>{selection}<\n\t\ttext:\t>{curr_updated_text}<")

    end = start + len(selection)

    if(curr_updated_text.find(selection, start) == start):
        # Delete characters
        # Added this if condition for special case of [Return]
        logger.debug(f"\tstart:{start} key:{key} match:{curr_updated_text[start:end]}")
        
        if not key == '[Return]':
            del (orig_text[start:end])

        elif key == '[Return]' and text:
            logger.debug(f"\tdelete start:{start} match:{curr_updated_text[start:end]})")
            del (orig_text[start:end])

        # Create a keystroke entry for delete
        target_ks = {'Time': str(time), 'Cursor': start, 'Type': "delete", 'Value': selection, 'segId': segId}
        ks_list.append(target_ks)

        # Insert Space
        # Sometimes [Space] keystroke has some valid characters in text attribute. This will handle those scenario
        if key == '[Space]' and text == ' ':
            logger.debug(f"\tinsert key:{key} start:{start} match:{curr_updated_text[start:end]})")
            orig_text.insert(start, ' ')
            # Create a keystroke entry for insert
            target_ks = {'Time': str(time + 1), 'Cursor': start, 'Type': "insert", 'Value': ' ', 'segId': segId}
            ks_list.append(target_ks)

        else:
            # Insert characters

            logger.debug(f"\tInsert: '{text}'")
            if text:
                for i, c in enumerate(text):
                    orig_text.insert(start + i, c)
                # Create a keystroke entry for insert
                target_ks = {'Time': str(time + 1), 'Cursor': start, 'Type': "insert", 'Value': text, 'segId': segId}
                ks_list.append(target_ks)

    logger.debug(f"after:  '{''.join(orig_text)}'\n")

    return orig_text, ks_list


def escapenewline(text):
    """
    Escapes the newline \n with &#10; in the sourcetext, targettext and finaltext
    """
    if text:
        newline = re.findall(r'\n', text)
        if newline:
            text = re.sub(r'\n', '&#10;', text)

    return text


def generateTranslogXml(trados_records, fixations, started_time, end_time, source_lang, target_lang, project_name, task, target_xml=OrderedDict()):
    if not isinstance(target_xml, OrderedDict):
        logger.error("Enter a valid xml file")
        return

    if not trados_records:
        return
# Screenoutput
#    print(len(trados_records))
    position = 0
    all_keystrokes = []
    final_source_text = ''
    final_target_text = ''
    final_mt_output = ''
    final_stop_ts = 0
    keys = list(trados_records.keys())
# Screenoutput
#    print(keys)
    # Sort by segmentId
    keys.sort()
    for segId in keys:
        record = trados_records.get(segId)
        
        sourceText = escapenewline(record.source)
        targetText = escapenewline(record.targetUpdated)
        mtOutput = escapenewline(record.mt_output)
        keystrokes = record.captured_keystrokes
# Screenoutput
#        if segId == 1:
#            print (keystrokes)
        last_timestamp = record.last_timestamp
        
        
#        print(f"segId:{segId} last_timestamp:{last_timestamp}")
        # compute text prefix for each keystroke: add up length of previous segments 
        for ks in keystrokes:
            position = 0
            ks_time = int(ks['Time'])
            for sId in TimeDic: 
                # only previous segments
                if(sId < segId) :
                    for tId in reversed(sorted(TimeDic[sId])):
                        if(tId <= ks_time): 
                            position += TimeDic[sId][tId] + 1                    
                            break
#            logger.debug(f"pos:{position}\t ks:{ks}")
            ks['Cursor'] = str(int(ks['Cursor']) + position)

        
        # Capture the value of last_timestamp of last record to be used in <System> tag
#        final_stop_ts = last_timestamp + 1
        final_stop_ts = convertTimestampToMs(end_time) - first_timestamp - 1 

#       for ks in keystrokes:
#            print(f"ks:{ks}") 
#            ks['Cursor'] = str(int(ks['Cursor']) + position)

        # add return for segment boundary
        sourceText += '\n'
        targetText += '\n'
        position += len(targetText)
        
        # add segment boundary
        mtOutput += '\n'

        final_source_text += sourceText
        final_target_text += targetText
        final_mt_output += mtOutput
        all_keystrokes += keystrokes
    logger.debug(f"final_mt_output: {final_mt_output}\n")
        
#    logger.debug(f"all_keystrokes: {recordId} {all_keystrokes}\n")

    logger.debug(f"final: {final_source_text}\n")
    target_xml = addKeystrokes(all_keystrokes, fixations, final_stop_ts, target_xml) # Modified #
    target_xml = addSourceText(final_source_text, target_xml)
    target_xml = addMTTargetText(final_mt_output, target_xml)
    target_xml = addSourceTextChar(final_source_text, target_xml)
    target_xml = addTargetTextChar(final_target_text, target_xml)
    target_xml = addFinalText(final_target_text, target_xml)
                 

#    target_xml['LogFile']['startTime'] = started_time
#    target_xml['LogFile']['endTime'] = end_time
    if(target_xml['LogFile']['Events']['Fix'] != []) :
        target_xml['LogFile']['Project']['Plugins']['EyeSampler'] = ""

    target_xml['LogFile']['Project']['FileName'] = project_name
    target_xml['LogFile']['Project']['Description'] = "Qualitivity"
    target_xml['LogFile']['Project']['Languages']['@source'] = source_lang
    target_xml['LogFile']['Project']['Languages']['@target'] = target_lang
    target_xml['LogFile']['Project']['Languages']['@task'] = task

    return target_xml


def addKeystrokes(keystrokes, fixations, final_stop_ts, target_xml):
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
    system.append({'@Time': final_stop_ts, '@Value': 'STOP'})

    keys = target_xml['LogFile']['Events']['Key']
    # keys.append(OrderedDict())
    for ks in keystrokes:
        keys.append(addKsToDict(ks))

    fix_data = target_xml['LogFile']['Events']['Fix'] # Added
    for elem in fixations: # Added
        if(int(elem['Time']) > final_stop_ts): break
        fix_data.append(addFixToDict(elem)) # Added

#    print("FIXDATA", len(fix_data))

    target_xml['LogFile']['Events']['Key'] = keys
    target_xml['LogFile']['Events']['System'] = system
    target_xml['LogFile']['Events']['Fix'] = fix_data # Added

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

def addFixToDict(fixation): 
#    print("SSSSS:", fixation)
    new_dict = {'@Time': fixation['Time'], '@Win': fixation['Win'], '@Dur': fixation['Dur'], '@X': fixation['X'], '@Y': fixation['Y'], '@segId': fixation['segId'], '@fixId': fixation['FixId']} 
    return OrderedDict(new_dict) # Added

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

#####################################################################
# ------------------------------ Added ------------------------------

# convert "2021-07-28T22:25:47.368" to "1619044223237"
# convert "2021-07-28 22:25:47.368" to "1619044223237"
# convert "2021-7-28T22:25:47.368"  to "1619044223237"
# convert "22:25:47.368"            to "1631831423237"
def convertTimestampToMs(ts):
    tt = parse(re.split(r'[ T]', ts)[-1])
    tt = tt.timestamp()
    tt = int(tt * 1000)
    return tt

# Remove square brackets for the keys having square brackets
def RemoveSquareBrackets(key):
    updated = ""
    if len(key) != 0:
        if key[0] == "[" and key[-1] == "]":
            updated = key[1:-1]
        else:
            updated = key
    return updated


def readTradosKS(Trados_file, verbose = 0):
    tree = ET.ElementTree(file = Trados_file)
    root = tree.getroot()

    Trados_KS = {}

    for KS in root.iterfind('.//ks'):
        fks = convertTimestampToMs(KS.attrib['created']) - first_timestamp
        if KS.attrib['text'] != "" and KS.attrib['text'] != "\n":
            Trados_KS.setdefault(fks, {})
            Trados_KS[fks]['t'] = KS.attrib['created']
            Trados_KS[fks]['k'] = RemoveSquareBrackets(KS.attrib['text'].upper())
            if(Trados_KS[fks]['k'] == ' '): Trados_KS[fks]['k'] = 'Space'
            
            if(verbose) : print(f"Tados KeyTime: {fks}\tKey: {Trados_KS[fks]}")

    return Trados_KS


def scaleFixation(fx, mn, mx, w):
    if(np.isnan(fx)): return int(w)
    return int((fx-mn) * w / (mx - mn))


def readGazePointKS_FS(Gazepoint_file, verbose = 0):


    width = 1    # window
    height = 1   # window
    fix = 0      # fixation number
    dur = 0      # fixation duration
    start = 0    # start time of fixation
    first = 0    # start time of session
    n = 1        # number of gaze points
    KS = {}
    FS = {}
    X = 0
    Y = 0

    fd = open(Gazepoint_file, "r", encoding='utf-8')

    while True:
        line = fd.readline()
        if not line : break

        if(re.search(r'^\s*$', line)) : continue

        # beginning of session
        if(re.search('<ACK', line)) :
            s = line.split("\t")[0] 
            if('<ACK' not in s) :
                f = convertTimestampToMs(s)
                if(first == 0 or f < first) : first = f
                print("EE1 fst:\t", first, f, line)
                    
        # screen size
        if(re.search('ID="SCREEN_SIZE', line)) :
            m = re.search(r'WIDTH="([^"]*)"', line)
            if(m): width = int(m.group(1))
            m = re.search(r'HEIGHT="([^"]*)"', line)
            if(m): height = int(m.group(1))
            print("EE2 siz:\t", width, height)
            continue
        
        # keystrokes 
        if(re.search('pressed', line)) :
            s = line.split("\t")[0] 
            t = 0
            if('pressed' not in s) :
                t = convertTimestampToMs(s) - first
            else :
                print("KEYSTROKE ERROR:\t", line)
                continue
            k = line.split("\t")[1] 
            if('pressed' in k) :
                m = re.search(r'\t(.*) pressed', line)
#                k = k.replace('pressed', '')
                k = m.group(1)
                k = k.replace("'", "")
                KS[t] = k
                print("KEY:", "\t\tstart:", t, k)
                
            else :
                print("KEYSTROKE ERROR:\t", line)
                continue

#            2022-01-20 19:48:18,290	't' pressed

        # gaze data
        elif(re.search('<REC', line)) :
            # start time
            if(start == 0): 
                s = line.split("\t")[0] 
                if('<REC' not in s) :
                    start = convertTimestampToMs(s) - first

            
            if not re.search(r"FPOGV", line) :
                print("INCOMPLETE Line:", line)
                continue
            
            # fixation
            m = re.search(r'FPOGID="([^"]*)"', line)
            f = int(m.group(1))
            
            # inside fixation
            if (f == fix): 
                if (re.search(r'FPOGV="0"', line)): continue
                
                # duration
                m = re.search(r'FPOGD="([^"]*)"', line)
                dur = int(float(m.group(1)) * 1000)
                
                mx = re.search(r'FPOGX="([^"]*)"', line)
                my = re.search(r'FPOGY="([^"]*)"', line)
                X += float(mx.group(1))
                Y += float(my.group(1))            
                n += 1
                
                # duration from external timer
                s = line.split("\t")[0] 
                if('<REC' not in s) :
                    end = convertTimestampToMs(s) - first
                continue

            # new fixation
            elif(fix > 0) :
                X = int(width * X / n)
                Y = int(height * Y / n)
                FS.setdefault(start, {})
                FS[start]['Dur'] = dur
#                (Y - minY) * 350 /maxY - minY
                FS[start]['X'] = scaleFixation(X, 0, 1, width)
                FS[start]['Y'] = scaleFixation(Y, 0, 1, height)
                FS[start]['Win'] = 1

    #            FS[start]['Pup'] = row['CURRENT_FIX_PUPIL']

#                print("FIX:", fix, "\tstart:", start, "\tX-Y:", X, Y, "\tdur:", dur, "\tend-start:", end - start)

            
            # duration
            m = re.search(r'FPOGD="([^"]*)"', line)
            dur = int(float(m.group(1)) * 1000)
            # Fix X
            m = re.search(r'FPOGX="([^"]*)"', line)
            X = float(m.group(1))
            # Fix Y
            m = re.search(r'FPOGY="([^"]*)"', line)
            Y = float(m.group(1))          
            #print("EE3 new:\t", start, dur, line)
           
            fix = f
            start = 0
            n = 1
    fd.close()

    return (KS , FS)
    
def readEyelinkKS(Eyelink_file, verbose = 0):

    xls_data = pd.read_csv(Eyelink_file, encoding='UTF-8', delimiter='\t', low_memory=False)
    offset=xls_data["CURRENT_FIX_END"].min()

    Eyelink_KS = {}
#    start_TS = int(xls_data.loc[0,'TRIAL_START_TIME'])
    xls1 = xls_data[["CURRENT_FIX_MSG_LIST_TIME", "CURRENT_FIX_MSG_LIST_TEXT"]]
    for i, row in xls1[(xls1['CURRENT_FIX_MSG_LIST_TEXT'] != "[]")].iterrows():
        key_lst = RemoveSquareBrackets(row['CURRENT_FIX_MSG_LIST_TEXT']).split(', ')
        time_lst = RemoveSquareBrackets(row['CURRENT_FIX_MSG_LIST_TIME']).split(', ')
#        print(key_lst, "\t", time_lst)
        for idx, key in enumerate(key_lst):
            if "KeyDown" in key:
                if(key_lst[idx].split('KeyDown ')[1] != "Return"):
                    fks = int(time_lst[idx]) - offset
                    Eyelink_KS.setdefault(fks, {})
                    Eyelink_KS[fks]['k'] = key_lst[idx].split('KeyDown ')[1]
                    if(verbose) : print(fks, Eyelink_KS[fks])
    return  Eyelink_KS


def readEyelinkFS(Eyelink_file, verbose = 0):
    xls_data = pd.read_csv(Eyelink_file, encoding='UTF-8', delimiter='\t', low_memory=False)
    Eyelink_FS = {}
    
    offset=xls_data["CURRENT_FIX_END"].min()

    xls1 = xls_data[[
         "CURRENT_FIX_PUPIL", 
         "CURRENT_FIX_X", 
         "CURRENT_FIX_Y",
         "CURRENT_FIX_NEAREST_INTEREST_AREA_LABEL",
         "CURRENT_FIX_INTEREST_AREA_LABEL", 
         "CURRENT_FIX_DURATION",
         "CURRENT_FIX_END",
         "CURRENT_FIX_INDEX"
        ]]
    maxX  = xls1['CURRENT_FIX_X'].max()
    maxY  = xls1['CURRENT_FIX_Y'].max()
    minX  = xls1['CURRENT_FIX_X'].min()
    minY  = xls1['CURRENT_FIX_Y'].min()

    for i, row in xls1.iterrows():
        start = row['CURRENT_FIX_END'] - row['CURRENT_FIX_DURATION'] - offset
        
        Eyelink_FS.setdefault(start, {})
        Eyelink_FS[start]['Dur'] = row['CURRENT_FIX_DURATION']
        Eyelink_FS[start]['X'] = scaleFixation(row['CURRENT_FIX_X'], minX, maxX, 1200)
        Eyelink_FS[start]['Y'] = scaleFixation(row['CURRENT_FIX_Y'], minY, maxY, 350)
        Eyelink_FS[start]['Pup'] = row['CURRENT_FIX_PUPIL']
        Eyelink_FS[start]['FixId'] = row['CURRENT_FIX_INDEX']
        
        if (row['CURRENT_FIX_INTEREST_AREA_LABEL'] == 'st'): 
            Eyelink_FS[start]['Win'] = 1
        elif (row['CURRENT_FIX_INTEREST_AREA_LABEL'] == 'tt'): 
            Eyelink_FS[start]['Win'] = 2
        else : 
            Eyelink_FS[start]['Win'] = 0
    return  Eyelink_FS


def readTobiiFS(Tobii_file):
    Tobii_FS = {}
    
    # read file
    tsv_data = pd.read_csv(Tobii_file, encoding='UTF-8', delimiter='\t', low_memory=False)

    # take out NaN fixation 
    tsv_data=tsv_data.dropna(subset=['FixationIndex'])
    tsv_data.FixationIndex = tsv_data['FixationIndex'].astype('int')
    
        
    maxX  = tsv_data['FixationPointX (MCSpx)'].max()
    maxY  = tsv_data['FixationPointY (MCSpx)'].max()
    minX  = tsv_data['FixationPointX (MCSpx)'].min()
    minY  = tsv_data['FixationPointY (MCSpx)'].min()
    
    # average X and Y positions per fixation
    FIX = {}
    FIY = {}
    fix = tsv_data.FixationIndex.unique()
    for f in fix : 
        X = tsv_data[tsv_data['FixationIndex'] == f]['FixationPointX (MCSpx)']
        FIX[f]= np.mean(X)
        Y = tsv_data[tsv_data['FixationIndex'] == f]['FixationPointY (MCSpx)']
        FIY[f]= np.mean(Y)

    # keep only one line per fixation
    tsv1 = tsv_data.drop_duplicates(subset='FixationIndex')

    for i, row in tsv1.iterrows() :
            
        tobiiTs = convertTimestampToMs(row['LocalTimeStamp']) - first_timestamp

        X = scaleFixation(FIX[row['FixationIndex']], minX, maxX, 1200) 
        Y = scaleFixation(FIY[row['FixationIndex']], minY, maxY, 350)
        
        Tobii_FS.setdefault(tobiiTs, {})     

        if(row['AOI[ST]Hit'] == 1): Tobii_FS[tobiiTs]['Win'] = 1 
        elif(row['AOI[TT]Hit'] == 1): Tobii_FS[tobiiTs]['Win'] = 2 
        else : Tobii_FS[tobiiTs]['Win'] = 0       

        Tobii_FS[tobiiTs]['X'] = X
        Tobii_FS[tobiiTs]['Y'] = Y
        Tobii_FS[tobiiTs]['FixId'] = row['FixationIndex']
        Tobii_FS[tobiiTs]['Dur'] = row['GazeEventDuration']
        Tobii_FS[tobiiTs]['Pup'] = (row['PupilRight'] + row['PupilLeft']) / 2

#    print('TS3', len(Tobii_FS.keys()))
  
    return Tobii_FS


def readTobiiKS(Tobii_file, verbose = 0):
    Tobii_KS = {}
    
    tsv_data = pd.read_csv(Tobii_file, encoding='UTF-8', delimiter='\t', low_memory=False)
    
    tsv1 = tsv_data[(tsv_data['KeyPressEvent'].notna())]
    
    for i, row in tsv1[(tsv1['KeyPressEvent'] != 'None')].iterrows():
        
        tobiiTs = convertTimestampToMs(row['LocalTimeStamp']) - first_timestamp

        if (row['KeyPressEvent'] != "Return"):
            Tobii_KS.setdefault(tobiiTs, {})
            Tobii_KS[tobiiTs]['t'] = row['LocalTimeStamp']
            Tobii_KS[tobiiTs]['k'] = row['KeyPressEvent']

            if(verbose == 1): print(f"Tobii KeyTime: {row['RecordingDate']}\t{tobiiTs}\tKey: {row['KeyPressEvent']}")
#            print(f"KeyTime: {tobiiTs}--{row['LocalTimeStamp']}\tKey:{row['KeyPressEvent']}")

    return Tobii_KS

#########################################
# Different ways of mapping keystroks
                  
def allMatchingKeys(KS1, KS2):
    R = pd.DataFrame()
    T1 = []
    T2 = []
    K1 = []
    K2 = []
    diff = []

    for k1 in KS1:
        for k2 in KS2:
            if KS1[k1] == KS2[k2]:
                T1.append(k1)
                K1.append(KS1[k1])
                T2.append(k2)
                K2.append(KS2[k2])
                diff.append(k2-k1)

    R['T1'] = T1
    R['K1'] = K1
    R['T2'] = T2
    R['K2'] = K2
    R['diff'] = diff
    return R
                  
def minTimeMatchingKeys(KS1, KS2):
    R = pd.DataFrame()
    T1 = []
    T2 = []
    K1 = []
    K2 = []
    diff = []
    M = {}

    for k1 in sorted(KS1):
        m1 = math.inf
        k3 = 0
        for k2 in sorted(KS2):
#            print(k1, k2,  "KS1:", KS1[k1], "KS2:", KS2[k2])
            if KS1[k1]['k'] == KS2[k2]['k']:
#                print("\t\t Bingo")
                m2 = k2-k1
                if(k2 in M): continue

                if abs(m2) < abs(m1): 
                    m1 = m2
                    k3 = k2
        if(k3 != 0) :
#            print(m1,  k1, k3, "KS1:", KS1[k1], "KS2:", KS2[k3])
            M[k2] = True
            T1.append(k1)
            K1.append(KS1[k1]['k'])
            T2.append(k3)
            K2.append(KS2[k3]['k'])
            diff.append(m1)

    R['T1'] = T1
    R['K1'] = K1
    R['T2'] = T2
    R['K2'] = K2
    R['diff'] = diff
    return R

def minTimeKeys(KS1, KS2):
    R = pd.DataFrame()
    T1 = []
    T2 = []
    K1 = []
    K2 = []
    diff = []
    M = {}

    for k1 in KS1:
        m1 = math.inf
        k3 = 0
        for k2 in KS2:
            m2 = k2-k1
            if(k2 in M): continue
            if(abs(m2) < abs(m1)): 
                m1 = m2
                k3 = k2
        if(k3 != 0) :
            M[k2] = True
            T1.append(k1)
            K1.append(KS1[k1])
            T2.append(k3)
            K2.append(KS2[k3])
            diff.append(m2)

    R['T1'] = T1
    R['K1'] = K1
    R['T2'] = T2
    R['K2'] = K2
    R['diff'] = diff
    return R
                  
def allKeys(KS1, KS2):
    R = pd.DataFrame()
    T1 = []
    T2 = []
    K1 = []
    K2 = []
    diff = []

    for k1 in KS1:
        for k2 in KS2:
            T1.append(k1)
            K1.append(KS1[k1])
            T2.append(k2)
            K2.append(KS2[k2])
            diff.append(k2-k1)

    R['T1'] = T1
    R['K1'] = K1
    R['T2'] = T2
    R['K2'] = K2
    R['diff'] = diff
    return R

def RemoveOutliers(df, perc):
    df.sort_values(by=['diff'], inplace=True)
    return df[int(len(df)*perc):int(len(df)*(1-perc))]

def findInterceptAndSlope(df):
    lmf = smf.ols(formula="T1 ~ T2", data=df).fit()
    intercept, slope = lmf.params
    return intercept, slope

def mapFixations1(GazeFs, intercept, slope):
 
    fix_event = []
#    print("MAP0", len(GazeFs.keys()))
        
    for fix in GazeFs:
        target_TS = round(fix*slope + intercept)
        if target_TS >= 0:
            fix_event.append({"Time": str(target_TS), 
                              "Win" : str(GazeFs[fix]["Win"]), 
                              "Dur": str(int(GazeFs[fix]["Dur"])), 
                              "FixId": str(int(GazeFs[fix]["FixId"])), 
                              "X": str(int(GazeFs[fix]["X"])), 
                              "Y": str(int(GazeFs[fix]["Y"])),
                              "segId": str(0)
                             }) 
    
#    print("MAP1", len(fix_event))
    return fix_event

def mapFixations(Trados_file, Eyetracker_file):
                  
    # read Trados Keystrokes
    Q = os.path.abspath(Trados_file)    
    TradosKs = readTradosKS(Q)
                  
    E = os.path.abspath(Eyetracker_file)

    #### Tobii eyetracker
    if(Eyetracker_file.endswith("tsv")) : 
        EyeTrackerKs = readTobiiKS(E)
        EyeTrackerFs = readTobiiFS(E)

    #### Eyelink
    elif(Eyetracker_file.endswith("txt")) : 
        EyeTrackerKs = readEyelinkKS(E)
        EyeTrackerFs = readEyelinkFS(E)
        
    #### GazePoint
    elif(Eyetracker_file.endswith("gp3")) : 
        EyeTrackerKs, EyeTrackerFs = readGazePointKS_FS(E)
    else : 
        print(f"mapFixations: Unknown eyetracker format {Eyetracker_file}")
        return {}

    print("Trados Keys:", len(TradosKs))
    print("Etrack Keys:", len(EyeTrackerKs))


    df0 = minTimeMatchingKeys(TradosKs, EyeTrackerKs)
    df4 = df0[(df0['diff'] != 0)]

    # keep half of the differences  
    rem = (1-min(len(TradosKs), len(EyeTrackerKs)) / (df4.shape[0] * 2)) /2   

    df4 = RemoveOutliers(df4, rem)                  
    intercept4, slope4 = findInterceptAndSlope(df4)

    print(f"minTimeMatchingKeys Keys: {df0.shape}\tafter {df4.shape}")
    print(f"FirstTime:{first_timestamp} Intercept: {intercept4:4.9}\tSlope:{slope4:4.9}\n")
#    printBestMatch(df0)
    
#    # produce all Q-key * E-key intervals
#    df0 = allKeys(TradosKs, EyeTrackerKs)
#                  
#    # keep half of the differnces  
#    rem = (1-min(len(TradosKs), len(EyeTrackerKs)) / (df0.shape[0] * 2)) /2   
#
#    df4 = RemoveOutliers(df0, rem)
#    intercept4, slope4 = findInterceptAndSlope(df4)
#
#    print(f"df4:checkAllKeys Keys: rem:{rem:4.4}\t{df0.shape}\tafter {df4.shape}")
#    print(f"Intercept: {intercept4:4.9}\tSlope:{slope4:4.9}")

    #####################
    fixations = mapFixations1(EyeTrackerFs, intercept4, slope4)
#    mergePrint(fixations, TradosKs)
    return fixations

#------------------
# ONLY FOR DEBUGGING
def mergePrint(Fixations, TradosKs):
    for fix in Fixations:
        
        if fix["Time"] in TradosKs:
            print("double:", fix["Time"])
        else: TradosKs[int(fix["Time"])] = fix
            
    for fix in sorted(TradosKs):
        print(fix, TradosKs[fix])


def printBestMatch(df, Tobii = {}):

    print(f"Key\tQ\tE\tdiff")

    dfs = df.sort_values(by=['T1'])
    for index, row in dfs.iterrows() :
        print(f"{row['K1']}\t{row['T1']}\t{row['T2']}\t{row['diff']}")
        if(row['T1'] in Tobii):
            print(f"\tTrados:{row['T1']}\t{Tobii[row['T1']]}")
              
#    print(df.sort_values(by=['T1']).head(100))

#------------------


def fixToSegment(xmlDoc,Fixations):
    # xmlDoc=doc
    activity = xmlDoc['QualitivityProfessional']['Client']['Project']['Activity']
    records=activity['Document']['Record']
    
    segDic={}
    for i,segment in enumerate(records):
        started=convertTimestampToMs(segment['@started'])-first_timestamp
        stopped=convertTimestampToMs(segment['@stopped'])-first_timestamp 
        segmentactive=[started,stopped]
        segDic.setdefault(segment["@segmentId"],[]).append(segmentactive)
#        print("FIX0",  i, started, stopped, type(Fixations))
        
    for fix in Fixations:
        for segment in segDic:
            for activeperiods in segDic[segment]:
                start=activeperiods[0]
                end=activeperiods[1]
#                logger.info(f"fixtosegment {i}, {segment}, {start}, {end}, {fix}")
                if int(fix["Time"]) >= start and int(fix["Time"]) <= end:
                    fix["segId"]=segment
                    
                  
                  
# ------------------------------------------------------------

def main(input_file, eyetracker_file, output_file=None, template=None, loglevel=logging.INFO):
    logger.setLevel(loglevel)

    input_file = os.path.abspath(input_file)
                  
    logger.info(f"-------------------------------------------")
    logger.info(f"Trados file:\t{input_file}")


    with open(input_file, encoding='utf-8') as fd:
        inputfile = fd.read()
        tabs = re.findall(r'\t', inputfile)
        if tabs:
            inputfile = re.sub(r'\t', r'\\t', inputfile)
        doc = xmltodict.parse(inputfile, encoding='utf-8', strip_whitespace=False)

    # return if a record is missing
    if (checkRecordCompleteness(doc)) : return 1

    captured_trados_data, started_time, end_time, source_lang, target_lang, project_name, task = processTradosFile(doc)

    if not template:
        template = os.path.dirname(__file__) + "/translog_template.xml"
     
    with open(template, encoding='utf-8') as fd:
        target_xml = xmltodict.parse(fd.read(), encoding='utf-8')

                  
    fixations = []
    if(eyetracker_file != '' and eyetracker_file != None):
        logger.info(f"Tracker file:\t{eyetracker_file}")
        fixations = mapFixations(input_file, eyetracker_file)
        fixToSegment(doc, fixations)

#    print("TTT", len(fixations))
    updated_xml = generateTranslogXml(captured_trados_data, fixations, started_time, end_time, source_lang, target_lang,
                                      project_name, task, target_xml) # Modified

    head, tail = os.path.split(input_file)
    if not output_file: output_file = head + "/generated_" + tail

    # updated_xml = xmltodict.unparse(updated_xml,)
    f = open(output_file, 'w', encoding='utf-8')

    logger.info(f"Output file:\t{output_file}")

    xml = xmltodict.unparse(updated_xml,pretty=True,short_empty_elements=True)
      
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
      
    # fix to call from Flask. needs to return a string object
    # updated_xml = xmltodict.unparse(updated_xml,pretty=True, short_empty_elements=True)
    f.close()

    return updated_xml


def help():

    logger.error(
        f"Usage:\n{__file__} <qualitivity_file>\n" +
        f"{__file__} <qualitivity_file> -o <translog_file>\n" +
        f"{__file__} <qualitivity_file> -o <translog_file> -e <gaze_file> -t <template_file> --debug\n"
    )
    exit(1)

                  
def validate_input_file(filename):
    if not os.path.isfile(filename):
        logger.error(f"Invalid Input file: {filename}")
        exit(1)

def validate_output_file(filename):
    opath, name = os.path.split(filename)
    if not os.path.isdir(os.path.abspath(opath)):
        logger.error(f"Invalid Output file directory: {os.path.abspath(opath)}")
        exit(1)
    if not re.match(r'.*xml$', name):
        logger.error(f"Output file name '{name}' should be in the format: <path>/<name>.xml")
        exit(1)

# How to run?
# for i in `ls lucas/files`; do ./Trados2Translog.py lucas/files/$i; done

if __name__ == '__main__':

     # Initialize the arguments to main method
    output_file = None
    eyetracker_file = None
    template = None
       
    
    loglevel = logging.INFO
        
    arguments = sys.argv
    args_len = len(sys.argv)
    
    if "-h" in arguments:
        help()
    if args_len < 2:
        help()
    else:
        input_file = arguments[1]
        validate_input_file(input_file)

        if "--debug" in arguments:
            loglevel = logging.DEBUG
        if "-e" in arguments:
            index = arguments.index("-e") + 1
            try:
                eyetracker_file = arguments[index]
                validate_input_file(eyetracker_file) # Added
            except IndexError:
                logger.error("Eyetracker file not specified")
                exit(1)
        if "-o" in arguments:
            index = arguments.index("-o") + 1
            try:
                output_file = arguments[index]
                validate_output_file(output_file)
            except IndexError:
                logger.error("Output file not specified")
                exit(1)
        if "-t" in arguments:
            index = arguments.index("-t") + 1
            try:
                template = arguments[index]
                validate_output_file(template)
            except IndexError:
                logger.error("Template file not specified")
                exit(1)
        main(input_file, eyetracker_file, output_file, template, loglevel) # Modified

   
