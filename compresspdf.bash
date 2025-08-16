#!/bin/bash

# Skript-Name: compresspdf.bash
# Datum: 10.5.2020

# Die Parameter werden im Format --<parametername> <parameterwert> übergeben

# Obligatorische Parameter:
# --processid (Vorgangs-ID)
# --outputpath (absoluter Pfad zum Zielverzeichnis)
# --title (Name der Ausgabedatei OHNE Dateinamenerweiterung)

# Optionale Parameter:
# --counting (Zählstufen wie Jahrgang oder Band; mehrere Zählstufen werden mit Underscore verbunden)
# --ouputfolder (im Zielverzeichnis neu zu erstellender Ordner zur Speicherung der Ausgabedatei)
# --pdfsettings (Ghostscript-Einstellung; Standardeinstellung: /ebook)
# --inputfolder (Endung des Ordnernamens mit den Eingabedateien; Standardeinstellung: pdf)

METADATA=/opt/digiverso/goobi/metadata
SETTINGS="/screen /ebook /printer /prepress /default"
MESSAGE_URL=https://ub-goobi.ub.unibas.ch/goobi/wi
TOKEN='Goobi-Web-API-Token'
CURL_DATA="-d command=addToProcessLog -d token=${TOKEN}"

# Benannte Parameter im folgenden Format einlesen: --<parametername> <parameterwert>
get_args() {
	typeset arguments
	num=$#	
	mod=$((num%2))	
	if [ $mod -ne 0 ]
	then
		return 1
	fi
	while [ $# -gt 0 ]
	do
		if [[ $1 == *"--"* ]] && [[ $2 != *"--"* ]]
		then
			arg="${1/--/}"
			typeset $arg="$2"
			arguments+="${arg}=$2 "
		else
			return 1
		fi
		shift 2
	done
	echo $arguments
}

# Überprüfen, ob die obligatorischen Parameter übergeben wurden
test_mandatory_args() {
	if echo $1 | grep '^[0-9]\{1,5\}$' > /dev/null 2>&1 
	then
		if [ -d $2 ]
		then 
			if [ ! -z $3 ]
			then
				return 0
			else
				echo misstitle
				return 1
			fi
		else
			echo missdir
			return 1
		fi
	else
		echo missid
		return 1
	fi
}

# Überprüfen, ob die PDF-Eingabedateien vorhanden sind
check_pdf() {
	input=$2
	if [ -z $input ]
	then
		input=pdf
	fi
	if ls ${METADATA}/$1/ocr/*_${input} > /dev/null 2>&1
	then
		pdffolder=`ls ${METADATA}/$1/ocr/ | grep "_${input}$"`
		pdfpath=${METADATA}/$1/ocr/${pdffolder}
		if ls ${pdfpath}/*.pdf > /dev/null 2>&1
		then
			echo $pdfpath
			return 0
		else
			echo nofiles
			return 1
		fi
	else
		echo nofolder
		return 1
	fi		
}

# Ggf. einen neuen Ordner erstellen und den absoluten Zielpfad definieren
compose_outpath() {
	outpathstr="$1"
	if [ ! -z $2 ]
	then
		outpathstr+="/$2"
		[ -d $outpathstr ] || mkdir ${outpathstr}
	fi
	echo "$outpathstr"
}

# Den Namen der PDF-Ausgabedatei generieren
compose_outfile() {
	outfilestr="$1"
	if [ ! -z $2 ]
	then
		outfilestr+="_$2"
	fi
	outfilestr+=".pdf"
	echo "$outfilestr"
}

# Ordner für die Log-Dateien erstellen
create_logfolder() {
	local logfolder=${METADATA}/$1/ocr/compresspdf_log
	[ -d $logfolder ] || mkdir $logfolder
	echo $logfolder
}

# Die Metadaten der PDF-Eingabedateien mit ExifTool nach Warnhinweisen durchsuchen
exif_test() {
	logfolder=`create_logfolder $1`
	exiflog=${logfolder}/exif.log
	[ ! -f $exiflog ] || rm $exiflog
	warning=0
	echo 'Beginn:' `date +'%d.%m.%Y %H:%M:%S'` >> $exiflog
	for file in $2/*.pdf
	do
		if exiftool $file | grep Warning >> $exiflog
		then
			echo $file >> $exiflog
			warning=1
		else
			continue
		fi	
	done
	echo -n 'Ende:' `date +'%d.%m.%Y %H:%M:%S'` >> $exiflog	
	if [ $warning -eq 0 ]
	then
		echo " - Keine Warnhinweise" >> $exiflog
	else
		echo " - Warnhinweise gefunden" >> $exiflog
		echo warnings $exiflog
	fi
	return $warning
}

# Die Einstellungen für die Ghostscript-Option -dPDFSETTINGS festlegen
set_pdfsettings() {
	settingarg=$1
	shift
	for setting in $@
	do
		if [ $setting = $settingarg ]
		then
			echo $setting
			return 0
		else
			continue
		fi
	done
	echo /ebook
}

# Die Eingabedatei(en) mit Ghostscript komprimieren
compress_pdf() {
	logfolder=`create_logfolder $1`
	gslog=${logfolder}/gs.log
	[ ! -f $gslog ] || rm $gslog
	outputfile=$3/$4
	err=1
	echo 'Beginn:' `date +'%d.%m.%Y %H:%M:%S'` >> $gslog
	gs -sDEVICE=pdfwrite \
		-dCompatibilityLevel=1.7 \
		-dPDFSETTINGS=$5 \
		-dNOPAUSE \
		-dBATCH \
		-sOutputFile=$outputfile \
		$2/*.pdf >> $gslog 2>&1
	echo -n 'Ende:' `date +'%d.%m.%Y %H:%M:%S'` >> $gslog
	grep Error $gslog > /dev/null 2>&1 || err=0
	if [ $err -eq 0 ]
	then
		echo " - Kompression erfolgreich" >> $gslog
		echo success $outputfile
	else
		echo " - Kompression mit Fehlermeldungen" >> $gslog
		echo gserror $gslog
	fi
	return $err
}

# Meldungen generieren
write_message() {
	set $*
	case "$1" in
		syntaxerr) 	message="Die Liste der Argumente enthält einen Syntaxfehler. Geben Sie alle Parameter im Format --<parametername> <parameterwert> an."
					type="console" ;;
		missid)		message="Der Vorgangsordner wurde nicht gefunden. Übergeben Sie die Vorgangs-ID mit dem Parameter --processid."
					type="console" ;;
		curlerr)	message="Beim Schreiben in den Vorgangs-Log über die Goobi-API ist ein Fehler aufgetreten."
					type="console" ;;
		nogs)		message="Das Skript kann nicht ausgeführt werden, da der Befehl gs nicht gefunden wurde."
					type="error" ;;
		noexif)		message="Das Skript kann nicht ausgeführt werden, da der Befehl exiftool nicht gefunden wurde."
					type="error" ;;
		missdir)	message="Das Zielverzeichnis wurde nicht gefunden. Übergeben Sie mit dem Parameter --outputpath den absoluten Pfad zum Zielverzeichnis."
					type="warn" ;;
		misstitle)	message="Für die Zieldatei wurde kein Name angegeben. Übergeben Sie mit dem Parameter --title den Namen der Zieldatei."
					type="warn" ;;
		nofolder)	message="Der PDF-Ordner wurde nicht gefunden."
					type="error" ;;
		nofiles)	message="Der PDF-Ordner ist leer."
					type="error" ;;
		warnings)	message="Die Kompression wurde nicht durchgeführt, da ExifTool Warnhinweise lieferte. Einzelheiten entnehmen Sie der Datei $2."
					type="warn" ;;
		gserror)	message="Die Ausführung von Ghostscript lieferte Fehlermeldungen. Einzelheiten entnehmen Sie der Datei $2."
					type="warn" ;;
		success)	message="Die PDF-Dateien wurden in der Datei $2 komprimiert."
					type="info" ;;
	esac
	send_message $type "$message"
}

# Meldung auf Konsole ausgeben und ggf. mit cURL über die Goobi-API an den Vorgangs-Log übermitteln
send_message() {
	case "$1" in
		console)			echo "$2" ;;
		error|warn|info)	curl_data_with_processid="${CURL_DATA} -d processId=$processid"
							curl_data_with_type="${curl_data_with_processid} -d type=$1"
							# curl -s ${curl_data_with_type} --data-urlencode "value=$2" $MESSAGE_URL || { write_message curlerr ; return 1 ; } ;;
							echo "$2" ;;
	esac
}

# Hauptprogramm

args=`get_args $*`
if [ $? = 1 ]
then
	write_message syntaxerr
	exit 1
else
	typeset $args
	test=`test_mandatory_args $processid $outputpath $title`		
	if [ $? = 1 ]
	then
		write_message $test
		exit 1
	else
		# Überprüfen, ob die Kommandos gs und exiftool ausführbar sind
		command -v gs > /dev/null 2>&1 || { write_message nogs ; exit 1 ; }
		command -v exiftool > /dev/null 2>&1 || { write_message noexif ; exit 1 ; }
		pdfdir=`check_pdf $processid $inputfolder`
		if [ $? = 1 ]
		then
			write_message $pdfdir
			exit 1
		else
			outpath=`compose_outpath $outputpath "$outputfolder"`
			outfile=`compose_outfile $title "$counting"`
			exiftest=`exif_test $processid $pdfdir`
			if [ $? = 1 ]
			then
				write_message $exiftest
				exit 1
			else
				dpdfsettings=`set_pdfsettings $pdfsettings $SETTINGS`
				compression=`compress_pdf $processid $pdfdir $outpath $outfile $dpdfsettings`
				write_message $compression
			fi
		fi
	fi
fi

exit 0
