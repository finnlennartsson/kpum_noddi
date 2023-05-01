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
Options:
  -tsv                          Subject tracker tsv-file (default: \$derivatives/Subject_Tracker_for_dmri_pipeline.tsv)
  -p / protocol                 MRI protocol used in study [ORIG/NEW] (default: ORIG) 
  -d / -derivatives <directory> The base derivatives directory (default: derivatives/dMRI)
  -dPar                         Parallel diffusivity for the NODDI model (default: 0.0017)
  -t / -threads                 Number of CPU threads (default: 4) 
  -h / -help / --help           Print usage.
"
  exit;
}


[ $# -ge 2 ] || { usage; }
command=$@
sID=$1
ssID=$2
shift; shift

currdir=$PWD

# Defaults
protocol=ORIG
derivatives=derivatives/dMRI
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

datadir=$derivatives/sub-$sID/ses-$ssID
# Get the code directory from which this script is executed (i.e. the /shell directory)
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo
echo "KPUM NODDI dMRI pipeline
Subject:       	$sID 
Session:        $ssID
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
startTotal=$SECONDS

# Stop entry in $tsvfile then exit
if [ -f $tsvfile ]; then
  stoptest=`cat $tsvfile | grep sub-$sID | grep ses-$ssID | grep Stop`
  if [ ! -z $stoptest ]; then
    # $stoptest is not empty = we have Stop entry in $tsvfile
    echo "Entry with Stop in $tsvfile - we have to exit here"
    exit;
  fi
fi

# Log the process with Check if subjecttrackertsv-file if not exists
tsvprocesslist=""
tsvprocesslistsubjectchecklist=""

######################################################################################################
## Process to perform - dmri_prepare_pipeline
process=dmri_prepare_pipeline
processfile=$process.sh
starttime=$SECONDS
# Run processfile
echo "START - $process"
bash $codedir/$processfile $sID $ssID -d $datadir;
endtime=$SECONDS
# Print timing
runtime_s=$(($endtime - $starttime)); 
runtime_m=$(printf %.3f $(echo "$runtime_s/60" | bc -l));
echo "END - $process"
echo "Runtime was $runtime_m [min]"
# update tsv-list
tsvprocesslistupdated=`echo -e "$tsvprocesslist\t$process\t$process comments"` 
tsvprocesslist=$tsvprocesslistupdated
tsvprocesslistsubjectchecklistupdated=`echo -e "$tsvprocesslistsubjectchecklist\tDone\t"`
tsvprocesslistsubjectchecklist=$tsvprocesslistsubjectchecklistupdated
echo 
######################################################################################################

######################################################################################################
## Process to perform - dmri_preprocess
process=dmri_preprocess
processfile=$process.sh
starttime=$SECONDS
echo "START - $process"
# Run processfile
bash $codedir/$processfile $sID $ssID -s $datadir/session_QC.tsv -d $datadir -p $protocol -t $threads;
endtime=$SECONDS
runtime_s=$(($endtime - $starttime)); 
runtime_m=$(printf %.3f $(echo "$runtime_s/60" | bc -l));
echo "END - $process"
echo "Runtime was $runtime_m [min]"
# update tsv-list
tsvprocesslistupdated=`echo -e "$tsvprocesslist\t$process\t$process comments"` 
tsvprocesslist=$tsvprocesslistupdated
tsvprocesslistsubjectchecklistupdated=`echo -e "$tsvprocesslistsubjectchecklist\tDone\t"`
tsvprocesslistsubjectchecklist=$tsvprocesslistsubjectchecklistupdated
echo 
######################################################################################################

######################################################################################################
## Process to perform - dmri_dtidki
process=dmri_dtidki
processfile=$process.sh
starttime=$SECONDS
echo "START - $process"
dwi=$datadir/dwi/sub-${sID}_ses-${ssID}_dir-AP_desc-preproc-inorm_dwi.mif
mask=$datadir/dwi/sub-${sID}_ses-${ssID}_space-dwi_mask.mif
# Run processfile
bash $codedir/$processfile $sID $ssID -d $datadir -dwi $dwi -mask $mask -t $threads;
endtime=$SECONDS
runtime_s=$(($endtime - $starttime)); 
runtime_m=$(printf %.3f $(echo "$runtime_s/60" | bc -l));
echo "END - $process"
echo "Runtime was $runtime_m [min]"
# update tsv-list
tsvprocesslistupdated=`echo -e "$tsvprocesslist\t$process\t$process comments"` 
tsvprocesslist=$tsvprocesslistupdated
tsvprocesslistsubjectchecklistupdated=`echo -e "$tsvprocesslistsubjectchecklist\tDone\t"`
tsvprocesslistsubjectchecklist=$tsvprocesslistsubjectchecklistupdated
echo 
######################################################################################################

######################################################################################################
## Process to perform - dmri_noddi
process=dmri_noddi
processfile=$process.sh
starttime=$SECONDS
echo "START - $process"
# input to process
tmpdir=`dirname $datadir`
derivatives=`dirname $tmpdir`
subjectdata=sub-${sID}/ses-${ssID}/dwi
dwi=$derivatives/$subjectdata/sub-${sID}_ses-${ssID}_dir-AP_desc-preproc-inorm_dwi.mif
mask=$derivatives/$subjectdata/sub-${sID}_ses-${ssID}_space-dwi_mask.mif
# Run processfile
bash $codedir/$processfile $sID $ssID -derivatives $derivatives -subjectdata $subjectdata -dwi $dwi -mask $mask -dPar $dPar -t $threads;
endtime=$SECONDS
runtime_s=$(($endtime - $starttime)); 
runtime_m=$(printf %.3f $(echo "$runtime_s/60" | bc -l));
echo "END - $process"
echo "Runtime was $runtime_m [min]"
# update tsv-list
tsvprocesslistupdated=`echo -e "$tsvprocesslist\t$process\t$process comments"` 
tsvprocesslist=$tsvprocesslistupdated
tsvprocesslistsubjectchecklistupdated=`echo -e "$tsvprocesslistsubjectchecklist\tDone\t"`
tsvprocesslistsubjectchecklist=$tsvprocesslistsubjectchecklistupdated
echo 
######################################################################################################


######################################################################################################
# Finish by stating how long it took
endTotal=$SECONDS
runtime_s=$(($endTotal - $startTotal)); 
runtime_m=$(printf %.3f $(echo "$runtime_s/60" | bc -l));
echo "Finished - $0"
echo "Runtime was $runtime_m [min]"
echo 

# Now update or create tsv-file 
if [ ! -f $tsvfile ]; then 
  # we have to create $tsvfile
  echo -e "participant_id\tsession_id$tsvprocesslist" > $derivatives/Subject_Tracker_for_dmri_pipeline.tsv
fi
# update by adding 
echo "Book keeping by adding a line at the bottom of $tsvfile"
echo -e "sub-$sID\tses-${ssID}$tsvprocesslistsubjectchecklist" >> $derivatives/Subject_Tracker_for_dmri_pipeline.tsv
