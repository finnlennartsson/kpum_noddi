#!/bin/bash
# KPUM NODDI
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base subjectID sessionID [options]
Conversion of DICOMs to BIDS and validation of BIDS dataset
The scripts uses Docker and heudiconv
- DICOMs are expected to be in $studyfolder/sourcedata
- Heuristics-files are located in code-subfolder $codedir/heudiconv_heuristics
- NIfTIs are written into a BIDS-organised folder $studyfolder/rawdata

Arguments:
  sID				Subject ID (e.g. 002) 
  ssID                       	Session ID (e.g. MR1)
Options:
  -f / -heuristic_file		Full path to heuristic file to use with heudiconv (default: $codedir/heudiconv_heuristics/sub-sID_ses-ssID_kpum_noddi.py, or if does not exist $codedir/heudiconv_heuristics/kpum_noddi.py)
  -h / -help / --help           Print usage.
"
  exit;
}

################ ARGUMENTS ################

[ $# -ge 2 ] || { usage; }
command=$@
sID=$1
ssID=$2
shift; shift

# Defaults
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
studydir=$PWD 
rawdatadir=$studydir/rawdata
dcmdir=$studydir/sourcedata

if [ -f $codedir/heudiconv_heuristics/sub-${sID}_ses-${ssID}_kpum_noddi.py ]; then
    heuristicfile=$codedir/heudiconv_heuristics/sub-${sID}_ses-${ssID}_kpum_noddi.py
else
    heuristicfile=$codedir/heudiconv_heuristics/kpum_noddi.py
fi

logdir=${studydir}/derivatives/logs/sub-${sID}/ses-${ssID}
scriptname=`basename $0 .sh`

# Read arguments
while [ $# -gt 0 ]; do
    case "$1" in
	-f|-heuristic_file)  shift; heuristicfile=$1; ;;
	-h|-help|--help) usage; ;;
	-*) echo "$0: Unrecognized option $1" >&2; usage; ;;
	*) break ;;
    esac
    shift
done

################ START ################

echo Conversion of DICOMs to BIDS and validation of BIDS dataset
echo Subject ID = $sID
echo Session ID = $ssID
echo heuristics file = $heuristicfile
echo 

if [ ! -d $rawdatadir ]; then mkdir -p $rawdatadir; fi
if [ ! -d $logdir ]; then mkdir -p $logdir; fi

# We place a .bidsignore here
if [ ! -f $rawdatadir/.bidsignore ]; then
    echo -e "# Exclude following from BIDS-validator\n" > $rawdatadir/.bidsignore;
fi

# we'll be running the Docker containers as yourself, not as root:
userID=$(id -u):$(id -g)

###   Get docker images:   ###
docker pull nipy/heudiconv:v0.11.6 #latest
docker pull bids/validator:latest

###   Extract DICOMs into BIDS:   ###

# Get location and file for heuristic file
heuristicdir=`dirname $heuristicfile`
heuristicfile=`basename $heuristicfile`

# Run heudiconv with docker container
docker run --name heudiconv_container \
           --user $userID \
           --rm \
           -it \
           --volume $studydir:/base \
	   --volume $codedir:/code \
	   --volume $heuristicdir:/heuristic \
           --volume $dcmdir:/dataIn:ro \
           --volume $rawdatadir:/dataOut \
           nipy/heudiconv:v0.11.6 \
               -d /dataIn/sub-{subject}/ses-{session}/*/*.dcm \
               -f /heuristic/$heuristicfile \
               -s ${sID} \
               -ss ${ssID} \
               -c dcm2niix \
               -b \
               -o /dataOut \
               --overwrite \
           > ${logdir}/sub-${sID}_ses-${ssID}_$scriptname.log 2>&1 
           
# heudiconv makes files read only
#    We make sure they are readable for everyone
chmod -R u+r,g+r,o+r $rawdatadir


# We run the BIDS-validator:
docker run --name BIDSvalidation_container \
           --user $userID \
           --rm \
           --volume $rawdatadir:/data:ro \
           bids/validator \
               /data \
           > ${studydir}/derivatives/bids-validator_report.txt 2>&1
           #> ${logdir}/bids-validator_report.txt 2>&1                   
           # For BIDS compliance, we want the validator report to go to the top level of derivatives. But for debugging, we want all logs from a given script to go to a script-specific folder
         
