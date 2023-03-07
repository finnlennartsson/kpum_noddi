#!/bin/bash
# KPUM_NODDI
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base patient [options]

Simple script to put patient DCMs in dicomdir into sourcedata folder using dcm2niix.

sourcedata-folder
 |
 -- sub-\$sID
     |
     -- DCM-folders for each Series

Data is copied and with file and folder names rearranged and renamed.

Arguments:
  patient			Patient's dicomdir-folder in format \$sID (e.g. 001) 
Options:
  -sourcedata			Output sourcedata folder (default: sourcedata)
  -dicomdir		       	Input DICOM folder (default: dicomdir)
  -h / -help / --help           Print usage.
"
  exit;
}

################ ARGUMENTS ################

[ $# -ge 1 ] || { usage; }
command=$@
sID=$1
shift

# Defaults
studydir=$PWD
sourcedata=$studydir/sourcedata;
dicomdir=$studydir/dicomdir;

# Read arguments
while [ $# -gt 0 ]; do
    case "$1" in
	-sourcedata)  shift; sourcedata=$1; ;;
	-dicomdir) shift; dicomdir=$1; ;;
	-h|-help|--help) usage; ;;
	-*) echo "$0: Unrecognized option $1" >&2; usage; ;;
	*) break ;;
    esac
    shift
done

################ START ################

echo Transferring and re-arranging DICOMs for $sID from dicomdir-folder $dicomdir to sourcedata-folder $sourcedata;
echo SubjectID = $sID

# Re-arrange DCM into PMR-folder in a BIDS-like structure using dcm2niix
if [ -d $sourcedata/sub-$sID ]; then
    echo "Folder $sourcedata/sub-$sID already exists => NO transfer"
    echo
else
    mkdir -p $sourcedata/sub-$sID
    echo "Transfer DCMs into $sourcedata/sub-$sID"
    echo
    # FL 2023-03-06 : had to change from default search depth to 6 (-d 6)
    dcm2niix -d 6 -b o -r y -w 1 -v 1 -o $sourcedata -f sub-$sID/s%2s_%d/%d_%5r.dcm $dicomdir/$sID
fi
