#!/bin/bash
# KPUM NODDI
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base sID ssID [options]
Semi "looked-down" script for running the KPUM NODDI dMRI pipeline

Arguments:
  sID                           Subject ID (e.g. 035) 
  ssID                          Session ID (e.g. MR1)
  studydir                      Studydir with full path (e.g. \$PWD or /mnt/e/Finn/KPUM_NODDI/Data)
Options:
  -d / -derivatives <directory> The base derivatives directory (default: \$studydir/derivatives/dMRI)
  -tsv                          Subject tracker tsv-file (default: \$derivatives/Subject_Tracker_for_dmri_pipeline.tsv)
  -p / protocol                 MRI protocol used in study [ORIG/NEW] (default: ORIG) 
  -dPar                         Parallel diffusivity for the NODDI model (default: 0.0017)
  -t / -threads                 Number of CPU threads (default: 4) 
  -h / -help / --help           Print usage.
"
  exit;
}


[ $# -ge 3 ] || { usage; }
command=$@
sID=$1
ssID=$2
studydir=$3
shift; shift; shift

currdir=$PWD

# Defaults
protocol=ORIG
derivatives=$studydir/derivatives/dMRI
dPar=0.0017
threads=4

# check whether the different tools are set and load parameters
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

while [ $# -gt 0 ]; do
    case "$1" in
    -tsv)  shift; tsvfile=$1; ;;
    -p|-protocol)  shift; protocol=$1; ;;
    -d|-derivatives)  shift; derivatives=$1; ;;
    -dPar)  shift; dPar=$1; ;;
    -t|-threads)  shift; threads=$1; ;;
    -h|-help|--help) usage; ;;
    -*) echo "$0: Unrecognized option $1" >&2; usage; ;;
    *) break ;;
    esac
    shift
done

# Defaults cont'd
tsvfile=$derivatives/Subject_Tracker_for_dmri_pipeline.tsv

# Set Variables
datadir=$derivatives/sub-$sID/ses-$ssID

# Get the code directory from which this script is executed (i.e. the /shell directory)
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo
echo "KPUM NODDI dMRI pipeline
Subject:       	$sID 
Session:        $ssID
Studydir:       $studydir
MRI Protocol:   $protocol
Derivatives:    $derivatives
TSV file:       $tsvfile
dPar for NODDI: $dPar
Threads:        $threads

$BASH_SOURCE   	$command
----------------------------"
echo

########################################
## START

echo codedir is $codedir
echo 
echo ls $studydir 
ls $studydir