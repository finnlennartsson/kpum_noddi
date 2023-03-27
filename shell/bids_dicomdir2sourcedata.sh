#!/bin/bash
# KPUM NODDI
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base DCMfolder sID ssID [options]
Simple script to put the patient's DICOMs in DICOM-folder into /sourcedata folder using dcm2niix.
sourcedata-folder
 |
 -- subj-sID
     |
     -- ses-ssID
         |
         --DCM-folders for each Series
Data is copied and with file and folder names rearranged and renamed.

Arguments:
  DCMfolder			Patient's DICOM-folder (e.g. dicomdir/001_MR1_XXXX)
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
DCMfolder=$1
sID=$2
ssID=$3
shift; shift; shift

studydir=$PWD
# Defaults
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

################ START ################

echo Transferring $Patient from DoB-folder $DCMfolder to sourcedata-folder $sourcedatafolder;
echo sID = $sID
echo ssID = $ssID;

# Re-arrange DCM into sourcedata-folder in a BIDS-like structure using dcm2niix
if [ ! -d $sourcedatafolder/sub-$sID/ses-$ssID ]; then mkdir -p $sourcedatafolder/sub-$sID/ses-$ssID; fi
echo "Transfer DCMs into $sourcedatafolder/sub-$sID/ses-$ssID"
echo
dcm2niix -d 8 -b o -r y -w 1 -o $sourcedatafolder -f sub-$sID/ses-$ssID/s%2s_%d/%d_%5r.dcm $DCMfolder
