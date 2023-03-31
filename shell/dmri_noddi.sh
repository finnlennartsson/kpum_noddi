#!/bin/bash
# KPUM NODDI
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base subjectID sessionID [options]
Runs NODDI for preprocessed dMRI data
Invokes Matlab (no desktop/nojvm)

Arguments:
  sID				Subject ID (e.g. 001) 
  ssID                       	Session ID (e.g. MR2)
Options:
  -dwi				Preprocessed dMRI data serie (format: .mif.gz) (default: derivatives/dMRI/sub-sID/ses-ssID/dwi/dwi_preproc_inorm.mif.gz)
  -mask				Mask for dMRI data (format: .mif.gz) (default: derivatives/dMRI/sub-sID/ses-ssID/dwi/mask.mif.gz)
  -threads			Number of CPU to run NODDI calcuations with
  -d / -data-dir  <directory>   The directory used to output the preprocessed files (default: derivatives/dMRI/sub-sID/ses-ssID)
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

currdir=$PWD

# Defaults
datadir=derivatives/dMRI/sub-$sID/ses-$ssID
dwi=$datadir/dwi/dwi_preproc_inorm.mif.gz
mask=$datadir/dwi/mask.mif.gz
threads=4

# check whether the different tools are set and load parameters
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

while [ $# -gt 0 ]; do
    case "$1" in
	-dwi) shift; dwi=$1; ;;
	-mask) shift; mask=$1; ;;
	-threads) shift; threads=$1; ;;
	-d|-data-dir)  shift; datadir=$1; ;;
	-h|-help|--help) usage; ;;
	-*) echo "$0: Unrecognized option $1" >&2; usage; ;;
	*) break ;;
    esac
    shift
done


# Check if images exist, else put in No_image
if [ ! -f $dwi ]; then dwi=""; fi
if [ ! -f $mask ]; then mask=""; fi

echo "dMRI preprocessing
Subject:       	$sID 
Session:        $ssID
DWI (AP):	$dwi
Mask:		$mask 
Directory:     	$datadir
 
$BASH_SOURCE   	$command
----------------------------"

logdir=$datadir/logs
if [ ! -d $datadir ]; then mkdir -p $datadir; fi
if [ ! -d $logdir ]; then mkdir -p $logdir; fi

echo dMRI preprocessing on subject $sID and session $ssID
script=`basename $0 .sh`
timestamp=`date`
echo On $timestamp, executing: $codedir/$script.sh $command > ${logdir}/sub-${sID}_ses-${ssID}_$script.log 2>&1
echo "" >> ${logdir}/sub-${sID}_ses-${ssID}_$script.log 2>&1
echo "Printout $script.sh" >> ${logdir}/sub-${sID}_ses-${ssID}_$script.log 2>&1
cat $codedir/$script.sh >> ${logdir}/sub-${sID}_ses-${ssID}_$script.log 2>&1
echo


################ START ################

##################################################################################
# 0. Put relevant files in $datadir/dwi/noddi folder

for file in $dwi $mask; do
    origdir=`dirname $file`
    filebase=`basename $file .mif.gz`
    outdir=$datadir/dwi/noddi
    
    if [ ! -d $outdir ]; then mkdir -p $outdir; fi
    
    if [ ! -f $outdir/$filebase.mif.gz ]; then
	echo Converting $file to $outdir/$filebase.nii
	if [ $file == $dwi ]; then
	    mrconvert -quiet -json_export $outdir/$filebase.json -export_grad_fsl $outdir/$filebase.bvec $outdir/$filebase.bval $file $outdir/$filebase.nii # Needs to be in .nii-format
	else # is $mask
	    mrconvert -quiet -json_export $outdir/$filebase.json $file $outdir/$filebase.nii # Needs to be in .nii-format
	fi	    
    fi

done

##################################################################################


##################################################################################
# 1. Run NODDI 
cd $datadir/dwi/noddi

echo Running NODDI calculations
noddithreads=6;
noddiparams=noddi-default #this is using the default noddi model

if [ $noddiparams == "noddi-default" ]; then
    matlab -nodesktop -nosplash -r "clc; clear all; addpath(genpath('$HOME/Software/NODDI_toolbox_v1.05/')); addpath('$HOME/Software/nifti_matlab/matlab/'); CreateROI('dwi_preproc_inorm.nii', 'mask.nii', 'NODDI_mask.mat'); protocol = FSL2Protocol('dwi_preproc_inorm.bval', 'dwi_preproc_inorm.bvec'); noddi = MakeModel('WatsonSHStickTortIsoV_B0'); batch_fitting('NODDI_mask.mat', protocol, noddi, 'FittedParams_sub-${sID}_ses-${ssID}_desc-$noddiparams.mat', $noddithreads); SaveParamsAsNIfTI('FittedParams_sub-${sID}_ses-${ssID}_desc-$noddiparams.mat', 'NODDI_mask.mat', 'mask.nii', 'sub-${sID}_ses-${ssID}_desc-$noddiparams'); exit"
fi

cd $currdir

##################################################################################
