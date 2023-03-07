#!/bin/bash
## KPUM NODDI
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base sID ssID [options]
Pre-script to generate .heudiconv files in /rawdata for subsequent NIfTI-conversion to BIDS /rawdata folder

Arguments:
  sID				Subject ID (e.g. 001) 
  ssID                       	Session ID (e.g. MR2)
Options:
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

while [ $# -gt 0 ]; do
    case "$1" in
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
scriptname=`basename $0 .sh`
logdir=$studydir/derivatives/logs/sub-${sID}/ses-${ssID}

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
           --volume $rawdatadir:/dataOut \
           nipy/heudiconv \
               -d /dataIn/sub-{subject}/ses-{session}/*/*.dcm \
               -f convertall \
               -s ${sID} \
	       -ss ${ssID} \
               -c none \
               -b \
               -o /dataOut \
               --overwrite \
           > $logdir/sub-${sID}_ses-${ssID}_$scriptname.log 2>&1 
           
