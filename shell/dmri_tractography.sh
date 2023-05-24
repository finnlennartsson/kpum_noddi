#!/bin/bash
# KPUM NODDI
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base subjectID sessionID [options]
Performs whole-brain tractography and SIFT-filtering

Arguments:
    sID             Subject ID (e.g. 001) 
    ssID            Session ID (e.g. MR2)
    studydir        Studydir with full path (e.g. \$PWD or /mnt/e/Finn/KPUM_NODDI/Data)
Options:
  -csd				CSD mif-file (default: \$datadir/csd/csd_dhollander_sub-sID_ses-ssID_dir-AP_desc-preproc-inorm_dwi_wm_2tt.mif) 
  -5TT				5TT mif-file in dMRI space (default: \$datadir/5TT/sub-sID_ses-ssID_space-dwi_5TT.mif)
  -nbr				Number of streamlines in whole-brain tractogram (default: 10M)
  -threads			Number of threads for parallell processing (default: 10)
  -d / -data-dir  <directory>   The directory used to output the preprocessed files (default: derivatives/dMRI_np/sub-sID/ses-ssID/dwi)
  -h / -help / --help           Print usage.
"
  exit;
}

################ ARGUMENTS ################

[ $# -ge 3 ] || { usage; }
command=$@
sID=$1
ssID=$2
studydir=$3
shift; shift; shift

currdir=$PWD

# Defaults
datadir=$studydir/derivatives/dMRI/sub-$sID/ses-$ssID
csd="" # See below - Defaults cont'd
act5tt="" # See below - Defaults cont'd
nbr=10M
threads=10

# check whether the different tools are set and load parameters
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

while [ $# -gt 0 ]; do
    case "$1" in
	-csd) shift; csd=$1; ;;
	-5TT) shift; act5tt=$1; ;;
	-nbr) shift; nbr=$1; ;;
	-threads) shift; threads=$1; ;;
	-d|-data-dir)  shift; datadir=$1; ;;
	-h|-help|--help) usage; ;;
	-*) echo "$0: Unrecognized option $1" >&2; usage; ;;
	*) break ;;
    esac
    shift
done

# Defaults cont'd
if [ $csd=="" ]; then
    csd=$datadir/csd/csd_dhollander_sub-${sID}_ses-${ssID}_dir-AP_desc-preproc-inorm_dwi_wm_2tt.mif
fi
if [ $act5tt=="" ]; then
    act5tt=$datadir/5TT/sub-${sID}_ses-${ssID}_space-dwi_5TT.mif
fi

echo "Whole-brain ACT tractography
Subject:       $sID 
Session:       $ssID
CSD:	       $csd
5TT:           $act5tt
Nbr:	       $nbr
Threads:       $threads
Directory:     $datadir 

CodeDir:        $codedir
$BASH_SOURCE    $command
----------------------------"

logdir=$datadir/logs
if [ ! -d $datadir ];then mkdir -p $datadir; fi
if [ ! -d $logdir ];then mkdir -p $logdir; fi

script=`basename $0 .sh`
echo "Running $script on subject $sID and session $ssID"
timestamp=`date`
echo On $timestamp, executing: $codedir/$script.sh $command > ${logdir}/sub-${sID}_ses-${ssID}_$script.log 2>&1
echo "" >> ${logdir}/sub-${sID}_ses-${ssID}_$script.log 2>&1
echo "Printout $script.sh" >> ${logdir}/sub-${sID}_ses-${ssID}_$script.log 2>&1
cat $codedir/$script.sh >> ${logdir}/sub-${sID}_ses-${ssID}_$script.log 2>&1
echo


##################################################################################
# 0. Copy to files to datadir (incl .json if present at original location)

for file in $csd $act5tt; do
    origdir=`dirname $file`
    filebase=`basename $file .mif`
    
    if [[ $file = $csd ]];then outdir=$datadir/dwi/csd;fi
    if [[ $file = $act5tt ]];then outdir=$datadir/dwi/5TT;fi
    if [ ! -d $outdir ]; then mkdir -p $outdir; fi
    
    if [ ! -f $outdir/$filebase.mif ];then
	cp $file $outdir/.
	if [ -f $origdir/$filebase.json ];then
	    cp $origdir/$filebase.json $outdir/.
	fi
    fi
done

# Update variables to point at corresponding filebases in $datadir
csd=`basename $csd .mif`
act5tt=`basename $act5tt .mif`

##################################################################################
# 1. Perform whole-brain tractography

cd $datadir/dwi

# define output tractdir
tractdir=tractography
if [ ! -d $tractdir ]; then mkdir -p $tractdir ; fi

# If a gmwmi mask does not exist, then create one
if [ ! -f 5TT/${act5tt}_gmwmi.mif ];then
    5tt2gmwmi 5TT/$act5tt.mif 5TT/${act5tt}_gmwmi.mif
fi

# Whole-brain tractography
# tckgen parameters are taken from Blesa et al, Cerebral Cortex 2021. Default is 0.1
cutoff=0.05 
init=$cutoff # default is equal to cutoff
maxlength=200
minlength=2
if [ ! -f $tractdir/whole_brain_${nbr}.tck ];then
    tckgen -nthreads $threads \
	   -cutoff $cutoff -seed_cutoff $init -minlength $minlength -maxlength $maxlength \
	   -act 5TT/$act5tt.mif -backtrack -seed_dynamic csd/$csd.mif \
	   -select $nbr \
	   csd/$csd.mif $tractdir/whole_brain_$nbr.tck
fi
if [ ! -f $tractdir/whole_brain_${nbr}_edit100k.tck ];then
    tckedit $tractdir/whole_brain_${nbr}.tck -number 100k $tractdir/whole_brain_${nbr}_edit100k.tck
fi

# SIFT-filtering of whole-brain tractogram
if [ ! -f $tractdir/whole_brain_${nbr}_sift.tck ]; then
    count=`tckinfo $tractdir/whole_brain_$nbr.tck | grep \ count: | awk '{print $2}'`;
    count0p10=`echo "$count / 10" | bc`;
    tcksift -nthreads $threads -act 5TT/$act5tt.mif -term_number $count0p10 $tractdir/whole_brain_$nbr.tck csd/$csd.mif $tractdir/whole_brain_${nbr}_sift.tck
fi
if [ ! -f $tractdir/whole_brain_${nbr}_sift_edit100k.tck ];then
    tckedit $tractdir/whole_brain_${nbr}_sift.tck -number 100k $tractdir/whole_brain_${nbr}_sift_edit100k.tck
fi

cd $currdir