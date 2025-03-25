#!/bin/bash
#
# Script to run the dHCP segmentation pipepline only
# (i.e. the scripts/segmentation/pipeline.sh) 
#

usage() 
{
    base=$(basename "$0")
    echo "
    Script to run the dHCP segmentation pipeline only
    
    Usage: $base sID ssID age studydir
    Options:
        -T2     T2 image in .nii format (default: \$datadir/anat/sub-sID_ses-ssID_desc-preproc_T2w.nii)
        -d / -data-dir  <directory>      The directory in \$studydir used to output files in (default: derivatives/dMRI/sub-sID/ses-ssID)
        -t / -threads       Number of CPU cores/threads to run commands in (default: 4)
        -h / -help / --help     Print usage.
    "
    exit 1
}

# Input arguments
sID=$1
ssID=$2
age=$3
studydir=$4
shift 4

codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
currdir=$PWD

# Defaults
datadir=$studydir/derivatives/dMRI/sub-$sID/ses-$ssID

while [ $# -gt 0 ]; do
    case "$1" in
        -T2) shift; t2w=$1; ;;
        -t|-threads) shift; threads=$1; ;;
        -d|-data-dir)  shift; datadir=$studydir/$1; ;;
        -h|-help|--help) usage; ;;
        -*) echo "$0: Unrecognized option $1" >&2; usage; ;;
        *) break ;;
    esac
    shift
done

# Defaults cont'd
#if [ ! -f $t2w ]; then t2w="No_image"; break; fi

outputFolder=$datadir/anat/dhcp_neonatal_segmentation
t2w=$datadir/anat/sub-${sID}_ses-${ssID}_desc-preproc_T2w.nii

echo "Running the dHCP segmentation pipepline only
Subject:        $sID 
Session:        $ssID
Studydir:       $studydir
T2:             $t2w 
Datadir:        $datadir 
Output Folder:  $outputFolder

Script:         $0
----------------------------"

logdir=$datadir/logs
if [ ! -d $datadir ];then mkdir -p $datadir; fi
if [ ! -d $outputFolder ];then mkdir -p $outputFolder; fi
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
# 1. Run the dhcp segmentation   

docker run --rm -t -u $(id -u):$(id -g) \
-v $outputFolder:/data --entrypoint /bin/bash biomedia/dhcp-structural-pipeline:latest \
-c ". /etc/fsl/fsl.sh && /usr/src/structural-pipeline/scripts/segmentation/pipeline.sh $t2w sub-${sID}_ses-${ssID} $age -t $threads" 
#> ${logdir}/sub-${sID}_ses-${ssID}_dhcp_segmentation-pipeline.log 2>&1

