#!/bin/bash
# KPUM NODDI
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base sID ssID studydir [options]
Semi "looked-down" script for running the KPUM NODDI dMRI DTI-DKI-Noddi pipeline

Arguments:
  sID                           Subject ID (e.g. 035) 
  ssID                          Session ID (e.g. MR1)
  studydir                      Studydir with full path (e.g. \$PWD or /mnt/e/Finn/KPUM_NODDI/Data)
Options:
  -derivatives <directory>      The base derivatives directory (default: \$studydir/derivatives/dMRI)
  -tsv                          Subject tracker tsv-file (default: \$derivatives/Subject_Tracker_for_\$scriptname.tsv)
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
scriptname=`basename $0 .sh`

while [ $# -gt 0 ]; do
    case "$1" in
    -tsv)  shift; tsvfile=$1; ;;
    -p|-protocol)  shift; protocol=$1; ;;
    -derivatives)  shift; derivatives=$1; ;;
    -dPar)  shift; dPar=$1; ;;
    -t|-threads)  shift; threads=$1; ;;
    -h|-help|--help) usage; ;;
    -*) echo "$0: Unrecognized option $1" >&2; usage; ;;
    *) break ;;
    esac
    shift
done

# Defaults cont'd
tsvfile=$derivatives/Subject_Tracker_for_$scriptname.tsv

# Set Variables
datadir=$derivatives/sub-$sID/ses-$ssID

# Get the code directory from which this script is executed (i.e. the /shell directory)
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
scriptname=`basename $0 .sh`

echo
echo "KPUM NODDI dMRI DTI-DKI-NODDI pipeline
----------------------------
Subject:       	$sID 
Session:        $ssID
Studydir:       $studydir
MRI Protocol:   $protocol
Derivatives:    $derivatives
TSV file:       $tsvfile
dPar for NODDI: $dPar
Threads:        $threads

CodeDir:        $codedir
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
# Run processfile
echo "START - $process"
starttime=$SECONDS
bash $codedir/$processfile $sID $ssID $studydir -s $studydir/nifti/sub-$sID/ses-$ssID/session_QC.tsv -d $datadir;
endtime=$SECONDS
echo "END - $process"
# Print timing
runtime_s=$(($endtime - $starttime)); 
runtime_m=$(printf %.3f $(echo "$runtime_s/60" | bc -l));
echo "Runtime was $runtime_m [min]"
# update tsv-list
tsvprocesslistupdated=`echo -e "$tsvprocesslist\t$process"` 
tsvprocesslist=$tsvprocesslistupdated
echo 
######################################################################################################

######################################################################################################
## Process to perform - dmri_preprocess
process=dmri_preprocess
processfile=$process.sh
# Run processfile
echo "START - $process"
starttime=$SECONDS
bash $codedir/$processfile $sID $ssID $studydir -s $datadir/session_QC.tsv -d $datadir -p $protocol -t $threads;
endtime=$SECONDS
echo "END - $process"
# Print timing
runtime_s=$(($endtime - $starttime)); 
runtime_m=$(printf %.3f $(echo "$runtime_s/60" | bc -l));
echo "Runtime was $runtime_m [min]"
# update tsv-list
tsvprocesslistupdated=`echo -e "$tsvprocesslist\t$process"` 
tsvprocesslist=$tsvprocesslistupdated
echo 
######################################################################################################

######################################################################################################
## Process to perform - dmri_dtidki
process=dmri_dtidki
processfile=$process.sh
dwi=$datadir/dwi/sub-${sID}_ses-${ssID}_dir-AP_desc-preproc-inorm_dwi.mif
mask=$datadir/dwi/sub-${sID}_ses-${ssID}_space-dwi_mask.mif
# Run processfile
echo "START - $process"
starttime=$SECONDS
bash $codedir/$processfile $sID $ssID $studydir -d $datadir -dwi $dwi -mask $mask -t $threads;
endtime=$SECONDS
echo "END - $process"
# Print timing
runtime_s=$(($endtime - $starttime)); 
runtime_m=$(printf %.3f $(echo "$runtime_s/60" | bc -l));
echo "Runtime was $runtime_m [min]"
# update tsv-list
tsvprocesslistupdated=`echo -e "$tsvprocesslist\t$process"` 
tsvprocesslist=$tsvprocesslistupdated
echo 
######################################################################################################

######################################################################################################
## Process to perform - dmri_noddi
process=dmri_noddi
processfile=$process.sh
# input to process
subjectdata=sub-${sID}/ses-${ssID}/dwi
dwi=$derivatives/$subjectdata/sub-${sID}_ses-${ssID}_dir-AP_desc-preproc-inorm_dwi.mif
mask=$derivatives/$subjectdata/sub-${sID}_ses-${ssID}_space-dwi_mask.mif
# Run processfile
echo "START - $process"
starttime=$SECONDS
bash $codedir/$processfile $sID $ssID $studydir -derivatives $derivatives -subjectdata $subjectdata -dwi $dwi -mask $mask -dPar $dPar -t $threads;
endtime=$SECONDS
echo "END - $process"
# Print timing
runtime_s=$(($endtime - $starttime)); 
runtime_m=$(printf %.3f $(echo "$runtime_s/60" | bc -l));
echo "Runtime was $runtime_m [min]"
# update tsv-list
tsvprocesslistupdated=`echo -e "$tsvprocesslist\t$process"` 
tsvprocesslist=$tsvprocesslistupdated
echo 
######################################################################################################

######################################################################################################
# Finish by stating how long it took
endTotal=$SECONDS
runtime_s=$(($endTotal - $startTotal)); 
runtime_m=$(printf %.3f $(echo "$runtime_s/60" | bc -l));
echo "Finished - $scriptname.sh"
echo "Included processes in $scriptname: $tsvprocesslist "
echo "Runtime was $runtime_m [min]"
echo 

# Now update or create tsv-file 
if [ ! -f $tsvfile ]; then 
  # we have to create $tsvfile
  echo -e "participant_id\tsession_id\t$scriptname\tQC\tcomments" > $derivatives/Subject_Tracker_for_$scriptname.tsv
fi
# update by adding 
echo "Book keeping by adding a line at the bottom of $tsvfile"
echo -e "sub-$sID\tses-${ssID}\tDone\tPending\t" >> $derivatives/Subject_Tracker_for_$scriptname.tsv
