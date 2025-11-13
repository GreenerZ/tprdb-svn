import sys
import MeCab


def main(fileName):

	outFile = fileName.replace("-txt", "-tok")
	m = MeCab.Tagger('') 
	o = open(outFile, "w", encoding="utf-8")
	with open(fileName, encoding="utf-8") as inFile:
		for line in inFile:
			o.write(m.parse(line))



if __name__ == '__main__':
    arguments = sys.argv

    if (len(arguments) == 2):
        main(arguments[1])
    else:
        print(f"MECAB: Wrong Agruments:{arguments[0]} {len(arguments)}")


