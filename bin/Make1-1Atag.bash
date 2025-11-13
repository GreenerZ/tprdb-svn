#!/bin/bash

if [ "$1" == "" ]; then
  echo "$0 Path "
  exit
fi


for src in ../$1/Alignment/*.src
do
	atag=${src/.src}
	root=${atag/$1\/}
	tgt="$atag.tgt"

        ln=$((`wc -l $atag.atag | cut -d\   -f1`))
        #if [ -f $atag.atag ] && [ "$ln" -gt "6" ]
        #then
		#echo "skipping $atag.atag because it has $ln lines"
		#continue
		#fi

		grep -v "<\/DTAGalign>" $atag.atag > $atag.atag-1

        echo "Create $atag.atag"
#        echo "<DTAGalign alignment=\"one-to-one\" >" > $atag.atag
#        echo "    <alignFile key=\"a\" href=\"$root.src\" sign=\"_input\"/>" >> $atag.atag
#        echo "    <alignFile key=\"b\" href=\"$root.tgt\" sign=\"_input\"/>" >> $atag.atag

        lines_src=`grep \<W $src | wc -l `
        lines_tgt=`grep \<W $tgt | wc -l `
        lines=$lines_src
        if [ "$lines" -gt "$lines_tgt" ] 
        then
            lines=$lines_tgt
        fi


        for (( x=1; x<=$lines; x++)) 
        do
            echo "    <align in=\"b$x\" out=\"a$x\" />" >> $atag.atag-1
        done

        echo "</DTAGalign>" >> $atag.atag-1
done


