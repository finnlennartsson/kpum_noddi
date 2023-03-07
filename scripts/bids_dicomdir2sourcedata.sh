#!/bin/bash
# KPUM NODDI
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base patient [options]
Simple script to put the patient's DICOMs in DICOM-folder into /sourcedata folder using dcm2niix.
sourcedata-folder
 |
 -- subj-$SubjectID
     |
     -- ses-$SessionID
         |
         --DCM-folders for each Series
Data is copied and with file and folder names rearranged and renamed.

Arguments:
  patient			Patient's DICOM-folder in format $SubjectID_$SessionID_XXXX (e.g. 002_MR1_XXXX or 024_MR2_YYYY) 
Options:
  -sourcedata			Output sourcedata folder (default: sourcedata)
  -DCM		       		Input DCM-folder (default: dicomdir)
  -h / -help / --help           Print usage.
"
  exit;
}

################ ARGUMENTS ################

[ $# -ge 1 ] || { usage; }
command=$@
Patient=$1
shift

if [ $# -gt 3 ]; then
    SubjectID=$4;
    SessionID=$5;
else
    SubjectID=`echo "$Patient" | sed 's/\_/\ /g' | awk '{print $1}'`;
    SessionID=`echo "$Patient" | sed 's/\_/\ /g' | awk '{print $2}'`;
fi

# Defaults
studydir=$PWD
sourcedatafolder=$studydir/sourcedata;
DCMfolder=$studydir/dicomdir;

# Read arguments
while [ $# -gt 0 ]; do
    case "$1" in
	-sourcedata)  shift; sourcedatafolder=$1; ;;
	-DCM) shift; DCMfolder=$1; ;;
	-h|-help|--help) usage; ;;
	-*) echo "$0: Unrecognized option $1" >&2; usage; ;;
	*) break ;;
    esac
    shift
done

################ START ################

echo Transferring $Patient from DoB-folder $DCMfolder to sourcedata-folder $sourcedatafolder;
echo SubjectID = $SubjectID
echo SessionID = $SessionID;

# Re-arrange DCM into PMR-folder in a BIDS-like structure using dcm2niix
if [ -d $sourcedatafolder/sub-$SubjectID/ses-$SessionID ]; then
    echo "Folder $sourcedatafolder/sub-$SubjectID/ses-$SessionID already exists => NO transfer"
    echo
else
    echo "Transfer DCMs into $sourcedatafolder/sub-$SubjectID/ses-$SessionID"
    echo
    dcm2niix -d 8 -b o -r y -w 1 -v 1 -o $sourcedatafolder -f sub-$SubjectID/ses-$SessionID/s%2s_%d/%d_%5r.dcm $DCMfolder/$Patient
fi
