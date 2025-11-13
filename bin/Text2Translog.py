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

def escapenewline(text):
    """
    Escapes the newline \n with &#10; in the sourcetext, targettext and finaltext
    """
    if text:
        newline = re.findall(r'\n', text)
        if newline:
            text = re.sub(r'\n', '&#10;', text)

    return text


def generateTranslogXml(sourceText, targetText, source_lang, target_lang,
                        task, target_xml=OrderedDict()) :


    if not isinstance(target_xml, OrderedDict):
        logger.error("Enter a valid xml file")
        return

#    target_xml['LogFile']['Project']['Description'] = "Text2Translog"
    target_xml['LogFile']['Project']['Description'] = "Qualitivity"
    target_xml['LogFile']['Project']['Languages']['@source'] = source_lang
    target_xml['LogFile']['Project']['Languages']['@target'] = target_lang
    target_xml['LogFile']['Project']['Languages']['@task'] = task

### Source text
    target_xml['LogFile']['Project']['Interface']['Standard']['Settings']['SourceTextUTF8'] = sourceText;
        
    target_xml['LogFile']['Project']['Interface']['Standard']['Settings']['SourceText'] = \
		"{\\rtf1" + re.sub(r"\n", "\\\\par\n", sourceText) + "}"

    sourceTextChar = []
    target_xml['LogFile']['SourceTextChar']['CharPos'] = []

    for ind, char in enumerate(sourceText):
        sourceTextChar.append(OrderedDict({'@Cursor': str(ind), '@Value': char}))
    target_xml['LogFile']['SourceTextChar']['CharPos'] = sourceTextChar
        
### Target text
    target_xml['LogFile']['Project']['Interface']['Standard']['Settings']['TargetTextUTF8'] = targetText
    target_xml['LogFile']['Project']['Interface']['Standard']['Settings']['TargetText'] = \
		"{\\rtf1" + re.sub(r"\n","\\\\par\n", targetText) + "}"
        
### Final text
    finalTextChar = []
    target_xml['LogFile']['FinalTextChar']['CharPos'] = []
    for ind, char in enumerate(targetText):
        finalTextChar.append(OrderedDict({'@Cursor': str(ind), '@Value': char}))
    target_xml['LogFile']['FinalTextChar']['CharPos'] = finalTextChar

    target_xml['LogFile']['FinalTextUTF8'] = targetText
    target_xml['LogFile']['FinalText'] = targetText
    return target_xml


def main(input_src, input_tgt, output_file, template, 
            source_lang, target_lang, task, loglevel=logging.INFO):
                        
    logger.setLevel(loglevel)

    with open(os.path.abspath(input_src), encoding='utf-8') as fd:
        src = fd.read()

    with open(os.path.abspath(input_tgt), encoding='utf-8') as fd:
        tgt = fd.read()
                
    if(src.count('\n') != tgt.count('\n')) :
        print("Must have same number of lines:", input_src, src.count('\n'), input_tgt, tgt.count('\n'))
        exit(1)
        
    if not template:
        template = os.path.dirname(__file__) + "/translog_template.xml"
     
    with open(template, encoding='utf-8') as fd:
        target_xml = xmltodict.parse(fd.read(), encoding='utf-8')

                  
    updated_xml = generateTranslogXml(src, tgt, source_lang, target_lang,
                                      task, target_xml)


    f = open(output_file, 'w', encoding='utf-8')

    logger.info(f"Output file:\t{output_file}")

    xml = xmltodict.unparse(updated_xml,pretty=True,short_empty_elements=True)
      
    print(xml, file=f)

    f.close()

    return updated_xml


def help():

    logger.error(
        f"Usage:\n{__file__} input_src, input_tgt, output_file, template, source_lang, target_lang, task [--debug]\n"
    )
    exit(1)

                  

if __name__ == '__main__':
   
    loglevel = logging.INFO
        
    arguments = sys.argv
    args_len = len(sys.argv)
    
    if "-h" in arguments:
        help()
    if args_len < 7:
        help()
    else:
        input_src   = arguments[1]
        input_tgt   = arguments[2]
        output_file = arguments[3]
        template    = arguments[4]
        source_lang = arguments[5]
        target_lang = arguments[6]
        task        = arguments[7]

        if "--debug" in arguments: loglevel = logging.DEBUG
		
        main(input_src, input_tgt, output_file, template, 
        source_lang, target_lang, task, loglevel=logging.INFO)
   