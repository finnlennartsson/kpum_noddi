#!/bin/bash
# KPUM NODDI
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base subjectID sessionID [options]
Script that calculates tensor and kurtosis parameters from preprocessed dMRI data
1. Estimation of diffusion tensor and calculation of tensor metrics done on b0+b1000 data (output in subdirectory /dtidki .nii fileformat)
2. Estimation of diffusion kurtosis calcuation of kurtosis metrics (output in subdirectory /dtidki in .nii fileformat)

Arguments:
  sID				Subject ID (e.g. 001) 
  ssID                       	Session ID (e.g. MR2)
Options:
  -dwi				dMRI preprocessed data in MRtrix .mif.gz format (default: \$datadir/dwi/dwi_preproc_inorm.mif.gz
  -mask				Brain mask in .mif.gz format (default: \$datadir/dwi/mask.mif.gz)
  -threads			Number of threads for MRtrix commands (default: 4)
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
if [ ! -f $mask ]; then dwi=""; fi

echo "DTI and DKI estimation
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

##################################################################################
# 0. Create relevant subfolder structure in $datadir

if [ ! -d $datadir/dwi ]; then mkdir -p $datadir/dwi; fi

##################################################################################
# 1. Create $dwibase.mif.gz in $datadir/dwi if does not exist

dwibase=`basename $dwi .mif.gz`
if [ ! -f $datadir/dwi/$dwibase.mif.gz ]; then mrconvert $dwi $datadir/dwi/$dwibase.mif.gz; fi
if [ ! -f $datadir/dwi/$mask.nii ]; then mrconvert $mask $datadir/dwi/mask.nii; fi

# update dwi to point at filebase
dwi=$dwibase

##################################################################################
## 2. Tensor estimation and tensor parameter calculation

cd $datadir/dwi
if [ ! -d dtidki ]; then mkdir -p dtidki; fi
cd dtidki

if [ ! -f ${dwi}_tensor.nii ]; then
    # Only use shells b0 and b1000 for DTI estimation 
    dwiextract -shells 0,1000 ../${dwi}.mif.gz - | dwi2tensor -mask ../mask.mif.gz - ${dwi}_DT.nii; 
    tensor2metric -force -fa ${dwi}_FA.nii -adc ${dwi}_MD.nii -rd ${dwi}_RD.nii -ad ${dwi}_AD.nii -vector ${dwi}_RGB.nii ${dwi}_DT.nii
    # Calculate Trace=lambda1+lambda2+lambda3 as 3*MD
    mrcalc ${dwi}_MD.nii 3 -mult ${dwi}_Trace.nii
fi

cd $currdir

##################################################################################
## 3. Kurtosis estimation and kurtosis parameter calculation



##################################################################################
