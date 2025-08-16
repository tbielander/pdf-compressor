#!/bin/bash

# Script-Name: compresspdf_cli.bash
# Argument $1: Pfad zur Liste der einschlägigen Vorgang-IDs, z. B. /home/UNIBASEL/bielan0000/schwar_ids.list oder ~/schwar_ids.list

METAPFAD=/opt/digiverso/goobi/metadata
ORIGINALS='_pdf' # '_fullpdf'
ZIELPFAD=/avshare/Schweizer_Arbeitgeber
IDS="$1"

# Log-Verzeichnis erstellen, falls noch keines vorhanden
if [ ! -d ${ZIELPFAD}/log ]
then
	mkdir ${ZIELPFAD}/log
fi 

# Log-Datei für die gegebene Serie anlegen
idsdatei="${IDS##*/}"  # Dateiname der Liste der Vorgangs-IDs
logdatei=$(echo "$idsdatei" | sed -e 's/_ids_/_compresspdf_/' -e 's/\.list/\.log/')
touch ${ZIELPFAD}/log/${logdatei}

beginn=$(date +'%Y-%m-%d %H:%M:%S')
echo -e "###\nBeginn: $beginn\n" | tee -a ${ZIELPFAD}/log/${logdatei}

# Endwert der Laufvariablen für die for-Schleife aus der Anzahl Zeilen in der Liste $1 bestimmen
zeilenzahl=$(wc -l $1 | cut -d " " -f 1)

# for-Schleife liest die Vorgangs-IDs einzeln aus $1 ein
for((z=1; z<="$zeilenzahl"; z++))
do
	id=$(head -n $z $1 | tail -n 1)
	if ls ${METAPFAD}/${id}/ocr/*${ORIGINALS} > /dev/null 2>&1
	then
		pdfordner=$(ls ${METAPFAD}/${id}/ocr/ | grep ${ORIGINALS}$)
		pdfpfad=${METAPFAD}/${id}/ocr/${pdfordner}
		jg=$(echo $pdfordner | grep -o "[0-9]\{4\}${ORIGINALS}$" | cut -c1-4)
		echo "Vorgangs-ID: $id, Jahrgang: $jg" | tee -a ${ZIELPFAD}/log/${logdatei}
		if ls ${pdfpfad}/*.pdf > /dev/null 2>&1
		then
			gs -sDEVICE=pdfwrite \
			-dCompatibilityLevel=1.7 \
			-dPDFSETTINGS=/ebook \
			-dNOPAUSE \
			-dQUIET \
			-dBATCH \
			-sOutputFile=${ZIELPFAD}/Schweizer_Arbeitgeber_${jg}.pdf \
			${pdfpfad}/*.pdf >> >( tee -a ${ZIELPFAD}/log/${logdatei} )
		else
			echo "Vorgangs-ID: $id --> Fehler: leerer PDF-Ordner" | tee -a ${ZIELPFAD}/log/${logdatei}
			continue
		fi
	else
		echo "Vorgangs-ID: $id --> Fehler: PDF-Ordner nicht gefunden" | tee -a ${ZIELPFAD}/log/${logdatei}
		continue
	fi
done

ende=$(date +'%Y-%m-%d %H:%M:%S')
echo -e "\nEnde: $ende\n###\n" | tee -a ${ZIELPFAD}/log/${logdatei}

exit 0
