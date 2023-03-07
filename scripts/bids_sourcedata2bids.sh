#!/bin/bash
## KPUM NODDI
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base sID [options]
Conversion of DCMs in /sourcedata into NIfTIs in /rawdata
1. NIfTI-conversion to BIDS-compliant /rawdata folder
2. validation of BIDS dataset

Arguments:
  sID				Subject ID (e.g. 001) 
Options:
  -f / -heuristic_file		Full path to heuristic file to use with heudiconv (default: \$codedir/heudiconv_heuristics/kpum_noddi.py)
  -h / -help / --help           Print usage.
"
  exit;
}

################ ARGUMENTS ################

[ $# -ge 1 ] || { usage; }
command=$@
sID=$1

shift
while [ $# -gt 0 ]; do
    case "$1" in
	-f|-heuristic_file)  shift; heuristicfile=$1; ;;
	-h|-help|--help) usage; ;;
	-*) echo "$0: Unrecognized option $1" >&2; usage; ;;
	*) break ;;
    esac
    shift
done

# Define Folders
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
studydir=`pwd`
rawdatadir=$studydir/rawdata;
sourcedatadir=$studydir/sourcedata;
heuristicfile=$codedir/heudiconv_heuristics/kpum_noddi.py
scriptname=`basename $0 .sh`
logdir=$studydir/derivatives/logs/sub-${sID}

if [ ! -d $rawdatadir ]; then mkdir -p $rawdatadir; fi
if [ ! -d $logdir ]; then mkdir -p $logdir; fi

# We place a .bidsignore here
if [ ! -f $rawdatadir/.bidsignore ]; then
echo -e "# Exclude following from BIDS-validator\n" > $rawdatadir/.bidsignore;
fi

# we'll be running the Docker containers as yourself, not as root:
userID=$(id -u):$(id -g)

###   Get docker images:   ###
docker pull nipy/heudiconv:latest  # should be changed to :latest when appropriate
docker pull bids/validator:latest

# Get location and file for heuristic file
heuristicdir=`dirname $heuristicfile`
heuristicfile=`basename $heuristicfile`

################ PROCESSING ################

###   Extract DICOMs into BIDS:   ###
# The images were extracted and organized in BIDS format:

docker run --name heudiconv_container \
           --user $userID \
           --rm \
           -it \
           --volume $studydir:/base \
	   --volume $codedir:/code \
           --volume $sourcedatadir:/dataIn:ro \
	   --volume $heuristicdir:/heuristic \
           --volume $rawdatadir:/dataOut \
           nipy/heudiconv \
               -d /dataIn/sub-{subject}/*/*.dcm \
               -f /heuristic/$heuristicfile \
               -s ${sID} \
               -c dcm2niix \
               -b \
               -o /dataOut \
               --overwrite \
           > $logdir/sub-${sID}_$scriptname.log 2>&1 
           
# heudiconv makes files read only
#    We need some files to be writable, eg for dHCP pipelines
chmod -R u+wr,g+wr $rawdatadir


# We run the BIDS-validator:
docker run --name BIDSvalidation_container \
           --user $userID \
           --rm \
           --volume $rawdatadir:/data:ro \
           bids/validator \
               /data \
           > ${studydir}/derivatives/bids-validator_report.txt 2>&1
           #> ${logdir}/bids-validator_report.txt 2>&1                   
           # For BIDS compliance, we want the validator report to go to the top level of derivatives. But for debugging, we want all logs from a given script to go to a script-specific fold
