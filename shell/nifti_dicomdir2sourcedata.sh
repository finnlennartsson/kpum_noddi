#!/bin/bash
# KPUM NODDI
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base DCMparentfolder DCMdatafolder sID ssID [options]
Simple script to put the patient's DICOMs in DICOM-folder into /sourcedata folder using dcm2niix.
sourcedata-folder
 |
 -- subj-sID
     |
     -- ses-ssID
         |
         --DCM-folders for each Series

Two-step processes
1. Data is copied and with file and folder names rearranged and renamed into "DCMparenfolder"/sourcedata
2. Data anonymized using Python-script "codedir"/python/anonymize_dicoms.py 

Arguments:
  DCMparentfolder		Parent DICOM-folder (e.g. rawdicomdir)
  DCMdatafolder			Patient's DICOM-folder within Parent DICOM-folder (e.g. 002_MR1_8193760_20210512/DICOM_fromPACS)
  sID				Patient's Subject ID (e.g. 001)
  ssID				Patient's Session ID (e.g. MR1)
Options:
  -sourcedata			Output sourcedata folder (default: sourcedata)
  -h / -help / --help           Print usage.
"
  exit;
}

################ ARGUMENTS ################

[ $# -ge 1 ] || { usage; }
command=$@
DCMparentfolder=$1
DCMdatafolder=$2
sID=$3
ssID=$4
shift; shift; shift; shift

studydir=$PWD

# Defaults
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
sourcedatafolder=$studydir/sourcedata;

# Read arguments
while [ $# -gt 0 ]; do
    case "$1" in
	-sourcedata)  shift; sourcedatafolder=$1; ;;
	-h|-help|--help) usage; ;;
	-*) echo "$0: Unrecognized option $1" >&2; usage; ;;
	*) break ;;
    esac
    shift
done

DCMfolder=$DCMparentfolder/$DCMdatafolder

logdir=${studydir}/derivatives/logs/sub-${sID}/ses-${ssID}
script=`basename $0 .sh`


################ START ################

echo Transferring $Patient from DoB-folder $DCMfolder to sourcedata-folder $sourcedatafolder/sub-$sID/ses-$ssID;
echo sID = $sID
echo ssID = $ssID;
echo

if [ ! -d $logdir ]; then mkdir -p $logdir; fi

timestamp=`date`
echo On $timestamp,
echo executing: $codedir/$script.sh $command > ${logdir}/sub-${sID}_ses-${ssID}_$script.log 2>&1
echo "" >> ${logdir}/sub-${sID}_ses-${ssID}_$script.log 2>&1
echo "Printout $script.sh" >> ${logdir}/sub-${sID}_ses-${ssID}_$script.log 2>&1
cat $codedir/$script.sh >> ${logdir}/sub-${sID}_ses-${ssID}_$script.log 2>&1
echo

##################################################################################
# 1. Re-arrange DCM into sourcedata-folder in a BIDS-like structure using dcm2niix

#sourcedata_nonanonym=$DCMparentfolder/sourcedata_non-anonym/sub-$sID/ses-$ssID;
sourcedata_nonanonym=$DCMparentfolder/sourcedata/sub-$sID/ses-$ssID;
output=$sourcedata_nonanonym;

if [ ! -d $output ]; then mkdir -p $output; fi

echo "Organizing DCM-input in $DCMfolder into non-anonymized folder $output"
dcm2niix -d 8 -b o -r y -w 1 -o $output -f s%2s_%d/%d_%5r.dcm $DCMfolder

##################################################################################
# 2. Anonymize by re-cursively looking in $sourcedata_nonanonym for all folders sub-$sID/ses-$ssID/*

# define anonymizing python-script
pythonfile=$codedir/../python/anonymize_dicoms.py 

if [ -f $pythonfile ]; then
    output=$sourcedatafolder/sub-$sID/ses-$ssID; # update output-folder
    currdir=$PWD
    for serie in ${sourcedata_nonanonym}/*; do
	    echo "Anonymizing DCMs in $serie"
	    seriebase=`basename $serie`
	    if [ ! -d $output/$seriebase ]; then mkdir -p $output/$seriebase; fi
	    # go and do anonymization
	    cd $serie
	    python3 $pythonfile # will anonoymize files in $serie
	    cd $currdir
	        
    done
    echo "All DCMs anonymized. Final output in $output";
else
    	echo "Cannot find $pythonfile. No anonymization is performed. Final output in $output";
	exit;
fi
##################################################################################
