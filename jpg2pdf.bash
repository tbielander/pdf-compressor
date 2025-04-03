#!/bin/bash

# Skript-Name: jpg2pdf.bash
# Argument $1: absoluter Pfad zum Eingabeordner
# Argument $2: absoluter Pfad zum Ausgabeordner
# Output: Alle JPEG-Dateien innerhalb eines Ordners werden in einem Multipage-PDF-Dokument mit dem Namen des betreffenden Ordners zusammengeführt

# Achtung: showpage ist für Multi-Page-Dokumente unerlässlich!

VIEWJPEG=/usr/share/ghostscript/9.26/lib/viewjpeg.ps

viewjpeg_concat() {
	string=""
	for file in ${@}
	do
		string+="(${file}) << /PageSize 2 index viewJPEGgetsize 2 array astore  >> setpagedevice viewJPEG showpage "
	done
	echo "$string"
}

convert() {
	filename=`echo "$1" | grep -E -o '[^/]+$'`.pdf
	path=`echo "$2"`
	outputfile="${path}/${filename}"
	# echo ${outputfile}
	output=$1
	viewjpeg_str=`viewjpeg_concat ${@:3}`
	gs -sDEVICE=pdfwrite -o ${outputfile} ${VIEWJPEG} -c ${viewjpeg_str} -f
}

get_jpg() { 	
	jpegs=$(ls $1/*.jpg 2> /dev/null)
	if [ -n "$jpegs" ]
	then
		convert $1 $2 $jpegs
	else
		subfolders=`find $1 -mindepth 1 -maxdepth 1 -type d`
		if [ -n "$subfolders" ]
		then
			for folder in $subfolders
			do
				get_jpg $folder $2
			done
		else
			return 0
		fi
	fi
}

# Hauptprogramm
[ -d $2 ] || mkdir $2
get_jpg $1 $2
