#!/bin/bash
# KPUM NODDI 
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base subjectID sessionID [options]
Performs whole-brain tractography and SIFT-filtering

Arguments:
  sID				Subject ID (e.g. 001) 
  ssID                       	Session ID (e.g. MR1)
Options:
  -csd				CSD mif.gz-file (default: derivatives/dMRI/sub-sID/ses-ssID/csd/csd_dhollander_dwi_preproc_inorm_wm_2tt.mif.gz)
  -nbr				Number of streamlines in whole-brain tractogram (default: 10M)
  -threads			Number of threads for parallell processing (default: 4)
  -d / -data-dir  <directory>   The directory used to output the preprocessed files (default: derivatives/dMRI/sub-sID/ses-ssID/dwi)
  -h / -help / --help           Print usage.
"
  exit;
}

################ ARGUMENTS ################

[ $# -ge 2 ] || { usage; }
command=$@
sID=$1
ssID=$2

currdir=$PWD

# Defaults
datadir=derivatives/dMRI/sub-$sID/ses-$ssID/dwi
csddir=csd
csd=$csddir/csd_dhollander_dwi_preproc_inorm_wm_2tt.mif.gz
tractdir=tractography
threads=4
nbr=10M

# check whether the different tools are set and load parameters
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

shift; shift
while [ $# -gt 0 ]; do
    case "$1" in
	-csd) shift; csd=$1; ;;
	-nbr) shift; nbr=$1; ;;
	-threads) shift; threads=$1; ;;
	-d|-data-dir)  shift; datadir=$1; ;;
	-h|-help|--help) usage; ;;
	-*) echo "$0: Unrecognized option $1" >&2; usage; ;;
	*) break ;;
    esac
    shift
done

echo "Whole-brain tractography
Subject:       $sID 
Session:       $ssID
CSD:	       $csd
Nbr:	       $nbr
Threads:       $threads
Directory:     $datadir 

$BASH_SOURCE   $command
----------------------------"

logdir=$datadir/logs
if [ ! -d $datadir ];then mkdir -p $datadir; fi
if [ ! -d $logdir ];then mkdir -p $logdir; fi

script=`basename $0 .sh`
timestamp=`date`
echo On $timestamp, executing: $codedir/sMRI/$script.sh $command > ${logdir}/sub-${sID}_ses-${ssID}_$script.log 2>&1
echo "" >> ${logdir}/sub-${sID}_ses-${ssID}_$script.log 2>&1
echo "Printout $script.sh" >> ${logdir}/sub-${sID}_ses-${ssID}_$script.log 2>&1
cat $codedir/$script.sh >> ${logdir}/sub-${sID}_ses-${ssID}_$script.log 2>&1
echo


##################################################################################
# 0. Copy to files to datadir (incl .json if present at original location)

for file in $csd; do
    origdir=`dirname $file`
    filebase=`basename $file .mif.gz`
    
    if [[ $file = $csd ]];then outdir=$datadir/csd;fi
    if [ ! -d $outdir ]; then mkdir -p $outdir; fi
    
    if [ ! -f $outdir/$filebase.mif.gz ];then
	cp $file $outdir/.
	if [ -f $origdir/$filebase.json ];then
	    cp $origdir/$filebase.json $outdir/.
	fi
    fi
done

# Update variables to point at corresponding filebases in $datadir
csd=`basename $csd .mif.gz`

##################################################################################
# 1. Perform whole-brain tractography

cd $datadir

if [ ! -d $tractdir ]; then mkdir -p $tractdir; fi

# Whole-brain tractography
# tckgen parameters are taken from Blesa et al, Cerebral Cortex 2021. Default is 0.1
cutoff=0.05 
init=$cutoff # default is equal to cutoff
maxlength=200
minlength=2
if [ ! -f $tractdir/whole_brain_${nbr}.tck ];then
    tckgen -nthreads $threads \
	   -cutoff $cutoff -seed_cutoff $init -minlength $minlength -maxlength $maxlength \
	   -seed_dynamic $csddir/$csd.mif.gz -select $nbr \
	   $csddir/$csd.mif.gz $tractdir/whole_brain_$nbr.tck
fi

# Make an smaller version for visualisation
if [ ! -f $tractdir/whole_brain_${nbr}_edit100k.tck ];then
    tckedit $tractdir/whole_brain_${nbr}.tck -number 100k $tractdir/whole_brain_${nbr}_edit100k.tck
fi

# SIFT-filtering of whole-brain tractogram
if [ ! -f $tractdir/whole_brain_${nbr}_sift.tck ]; then
    count=`tckinfo $tractdir/whole_brain_$nbr.tck | grep \ count: | awk '{print $2}'`;
    count0p10=`echo "$count / 10" | bc`;
    tcksift -term_number $count0p10 $tractdir/whole_brain_$nbr.tck $csddir/$csd.mif.gz $tractdir/whole_brain_${nbr}_sift.tck
fi
if [ ! -f $tractdir/whole_brain_${nbr}_sift_edit100k.tck ];then
    tckedit $tractdir/whole_brain_${nbr}_sift.tck -number 100k $tractdir/whole_brain_${nbr}_sift_edit100k.tck
fi

cd $currdir
