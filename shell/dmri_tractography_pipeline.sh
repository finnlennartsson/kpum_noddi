#!/bin/bash
# KPUM NODDI
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base sID ssID studydir [options]
Semi "looked-down" script for running the KPUM NODDI dMRI Tractography pipeline

Arguments:
  sID                           Subject ID (e.g. 035) 
  ssID                          Session ID (e.g. MR1)
  studydir                      Studydir with full path (e.g. \$PWD or /mnt/e/Finn/KPUM_NODDI/Data)
Options:
  -derivatives <directory>      The base derivatives directory (default: \$studydir/derivatives/dMRI)
  -tsv                          Subject tracker tsv-file (default: \$derivatives/Subject_Tracker_for_\$scriptname.tsv)
  -nbr                          Number of streamlines in whole-brain tractogram (default: 10M)
  -a / -atlas                   Atlas used for parcellation (options ALBERT or MCRIB) (default: M-CRIB)
  -p / -protocol                 MRI protocol used in study [ORIG/NEW] (default: NEW) 
  -t / -threads                 Number of CPU threads (default: 10) 
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
protocol=NEW
derivatives=$studydir/derivatives/dMRI
nbr=10M
threads=10
atlas=M-CRIB

# check whether the different tools are set and load parameters
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
scriptname=`basename $0 .sh`

while [ $# -gt 0 ]; do
    case "$1" in
    -tsv)  shift; tsvfile=$1; ;;
    -a|-atlas)  shift; atlas=$1; ;;
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
scriptname=`basename @0 .sh`

echo
echo "KPUM NODDI dMRI tractography pipeline
----------------------------
Subject:            $sID 
Session:            $ssID
Studydir:           $studydir
MRI Protocol:       $protocol
Derivatives:        $derivatives
TSV file:           $tsvfile
Nbr streamlines:    $nbr
Threads:            $threads

CodeDir:            $codedir
$BASH_SOURCE        $command
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

######################################################################################################
## Process to perform - dmri_response
process=dmri_response
processfile=$process.sh
# input to process (see also arguments/options to script)
dwi=$datadir/dwi/sub-${sID}_ses-${ssID}_dir-AP_desc-preproc-inorm_dwi.mif
mask=$datadir/dwi/sub-${sID}_ses-${ssID}_space-dwi_mask.mif
response=dhollander
# Run processfile
echo "START - $process"
starttime=$SECONDS
bash $codedir/$processfile $sID $ssID $studydir -d $datadir -dwi $dwi -mask $mask -response $response -threads $threads;
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
## Process to perform - dmri_csd
process=dmri_csd
processfile=$process.sh
# input to process (see also arguments/options to script)
dwi=$datadir/dwi/sub-${sID}_ses-${ssID}_dir-AP_desc-preproc-inorm_dwi.mif
mask=$datadir/dwi/sub-${sID}_ses-${ssID}_space-dwi_mask.mif
response=dhollander
# Run processfile
echo "START - $process"
starttime=$SECONDS
bash $codedir/$processfile $sID $ssID $studydir -d $datadir -dwi $dwi -mask $mask -response $response -threads $threads;
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
## Process to perform - dmri_5TT_and_registration
# IS RUN WITHIN REGISTRATION STEP (i.e. before tractography pipeline)
######################################################################################################

######################################################################################################
## Process to perform - dmri_tractography
#
process=dmri_tractography
processfile=$process.sh
# input to process (see also arguments/options to script)
csd=$datadir/dwi/csd/csd_dhollander_sub-${sID}_ses-${ssID}_dir-AP_desc-preproc-inorm_dwi_wm_2tt.mif
act5tt=$datadir/dwi/5TT/sub-${sID}_ses-${ssID}_space-dwi_mask.mif
# Run processfile
echo "START - $process"
starttime=$SECONDS
bash $codedir/$processfile $sID $ssID $studydir -d $datadir -csd $csd -5TT $act5tt -nbr $nbr -threads $threads;
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
## Process to perform - dmri_connectome
#
process=dmri_connectome
processfile=$process.sh
# input to process (see also arguments/options to script)
tract=$datadir/dwi/tractography/whole_brain_10M_sift.tck
label=$datadir/dwi/parcellation/$atlas/sub-${sID}_ses-${ssID}_desc-mcrib_space-dwi_dseg.mif
lutin=$codedir/../label_names/$atlas/M-CRIB_labels_FreeSurfer_format.txt
lutout=$codedir/../label_names/$atlas/Structural_Labels.txt
connectome=Structural_M-CRIB
# Run processfile
echo "START - $process"
starttime=$SECONDS
bash $codedir/$processfile $sID $ssID $studydir -d $datadir -csd $csd -5TT $act5tt -nbr $nbr -threads $threads;
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
