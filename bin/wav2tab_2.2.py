import json
import os
import re
from os.path import join, dirname
from ibm_watson import SpeechToTextV1
from ibm_cloud_sdk_core.authenticators import IAMAuthenticator
import sys, getopt

# alternative language models:
#ar-AR_BroadbandModel
#en-UK_BroadbandModel
#en-UK_NarrowbandModel
#en-US_BroadbandModel (the default)
#en-US_NarrowbandModel
#es-ES_BroadbandModel
#es-ES_NarrowbandModel
#fr-FR_BroadbandModel
#ja-JP_BroadbandModel
#ja-JP_NarrowbandModel
#pt-BR_BroadbandModel
#pt-BR_NarrowbandModel
#zh-CN_BroadbandModel
#zh-CN_NarrowbandModel





def transcribe(filenameWav, languageModel):

#from ibm_cloud_sdk_core.authenticators import IAMAuthenticator

	authenticator = IAMAuthenticator(f'{apikey}')
	speech_to_text = SpeechToTextV1(
	   authenticator=authenticator
	)  #new demo to validate
	speech_to_text.set_service_url(urlpath)


	# speech_to_text = SpeechToTextV1(
	# 	iam_apikey=apikey,
	# 	url=urlpath
	#
	# )
	
	print("sending:", filenameWav, "---", languageModel, "to server")
	filesuffix=os.path.splitext(filenameWav)[1].replace(".","");
	with open(join(dirname(__file__), filenameWav), 'rb') as audio_file:
		speech_recognition_results = speech_to_text.recognize(
            audio=audio_file,
            content_type='audio/'+filesuffix,
            timestamps=True,
			model=languageModel,
            word_alternatives_threshold=0.9,
			inactivity_timeout=600
			).get_result()
		data = json.dumps(speech_recognition_results,indent=2);

	
	pos=filenameWav.rfind('.')
	filenameJason=filenameWav[:pos]+".jason"
	print('writing:', filenameJason)
	fileJason = open(filenameJason, 'w', encoding='utf-8')
	fileJason.write(data)
	fileJason.flush()
	fileJason.close()
	convert2Asr(filenameJason)

def convert2Asr(filenameJason):

	with open(filenameJason) as data_file:    
		data = json.load(data_file)

	pos=filenameJason.rfind('.')
	filenameAsr=filenameJason[:pos]+".asr.txt"
	print("writing: " + filenameAsr)
	fileAsr = open(filenameAsr, 'w', encoding='utf-8')
	
	lng = languageModel[0:2]
	for  alt in data["results"] :
		for  seg in alt["alternatives"] :
			for  word in seg["timestamps"] :
				str1 = lng+"\t"+str(int(word[1]*1000))+"\t"+str(int(word[2]*1000))+"\t"+str(word[0])+"\n"
				fileAsr.write(str1)

	fileAsr.flush()
	fileAsr.close()

	
def joinAsr(dir):
   
	asrFiles = {}
	asrLines = []
	asrFile = []
	asrDur = []
	fileList=os.listdir(dir)
#	print('Join Dir contents', fileList)

	for f in fileList:
		asr = re.search(r'-[0-9]+.asr.txt$', f, flags=0)
		wav = re.search(r'-[0-9]+.wav$', f, flags=0)
		if asr:
			n = re.search(r'[0-9]+', asr[0], flags=0)
			asrFile.insert(int(n[0]), f)
		elif wav:
			# duration = FileLength / (Sample Rate * Channels * Bits per sample /8)
			len = os.path.getsize(dir+'/'+f)
			dur = 1000*(len - 44)/(44100 * 2 * 2)
			n = re.search(r'[0-9]+', wav[0], flags=0)
			print('WavFile: '+n[0]+"\t"+f+"\tdur: ", int(dur))
			asrDur.insert(int(n[0]), dur)
#		else:
#			print('skipping:\t'+f)

			
	for f in asrFile:
		m = re.search(r'-[0-9]+.asr.txt$', f, flags=0)
#		print('Asr:'+f+" m:"+m[0])
		if m:
			n = re.search(r'[0-9]+', m[0], flags=0)
			i = int(n[0])
			if i == 0 :
				print('AsrFile: ',i,"\t"+f)
				asrFileName = dir+'/'+f
				with open(asrFileName, 'r', encoding='UTF8') as asrFile: 
					asrLines = asrFile.read().splitlines()
				asrFile.close()
				end = 0
			else :
				end += int(asrDur[i])
				print('AsrFile: ',i,"\t"+f+"\tend: ", end)

				tempLines = []
				with open(dir+'/'+f, 'r', encoding='UTF8') as tempFile: 
					tempLines = tempFile.read().splitlines()
				for line in tempLines:
					l = line.split()
					l[1] = str(int(l[1]) + end)
					l[2] = str(int(l[2]) + end)
					asrLines.append('\t'.join(l))


	pos=asrFileName.rfind('-')
	filename=asrFileName[:pos]+"-A.asr.txt"
	
	print('writing:  '+filename)
	fileAsr = open(filename, 'w', encoding='utf-8')
	fileAsr.writelines("%s\n" % item  for item in asrLines)
	fileAsr.flush()
	fileAsr.close()
	

def options(argv):
	
	print('Options: ' + argv[0])
	print('\t-f <file>.wav  : send <file>.wav to ASR server, produce <file>.jason and <file>.asr.txt files')
	print('\t-l <language>  : specify one of the defined language models, e.g. ja-JP_BroadbandModel (default: en-US_BroadbandModel)')
	print('\t-d <directory> : send all wav-files in <directory>/*.wav to ASR server and produce <directory>/*.jason and <directory>/*.asr.txt files')
	print('\t-j <directory> : join all <directory>/*-<NUM>.asr.txt files into <directory>/*-A.asr.txt. Files must be numbered <directory>/*-0.asr.txt, <directory>/*-1.asr.txt, ...')
	print('\t-a <file>.jason: convert <file>.jason into <file>.asr.txt (this is part of the -f and -d options)')
	print('\t-u url: url for Watson ASR')
	print('\t-k apikey: apikey for Watson ASR')


wavDir = ''
filenameWav=''
apikey= ""
urlpath= ""
languageModel='en-US_BroadbandModel'

argv=sys.argv[1:]
try:
	opts, args = getopt.getopt(argv,"hd:f:l:u:k:j:a:",["dir=","file=","lang=","url=","key=","join=","Asr="])
except getopt.GetoptError:
	options(sys.argv)
	sys.exit(2)
for opt, arg in opts:
	if opt == '-h':
		options(sys.argv)
		sys.exit()
	elif opt in ("-d", "--dir"):
		wavDir = arg
	elif opt in ("-f", "--file"):
		filenameWav = arg
	elif opt in ("-l", "--lang"):
		languageModel = arg
	elif opt in ("-k", "--key"):
		apikey = arg
	elif opt in ("-u", "--url"):
		urlpath = arg
	elif opt in ("-a", "--Asr"):
		convert2Asr(arg)
		sys.exit()
	elif opt in ("-j", "--join"):
		joinAsr(arg)
		sys.exit()
	
if wavDir != '' :
	print('Dir = '+wavDir)
	fileList=os.listdir(wavDir)
	print('Dir contents', fileList)

	for f in fileList:
		if re.search(r'.wav', f, flags=0):
			transcribe(wavDir+'/'+f, languageModel)
		else:
			print('skipping:', f)
#	joinAsr(wavDir)

elif filenameWav != '' :
	transcribe(filenameWav, languageModel)
else:
	options(sys.argv)
