#!/bin/bash
# KPUM NODDI
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base subjectID sessionID [options]
Script that calculates tensor and kurtosis parameters from preprocessed dMRI data
1. Estimation of diffusion tensor and calculation of tensor metrics on b0+b1000 data (output in subdirectory /dti)
2. Estimation of diffusion kurtosis and calcuation of kurtosis metrics (incl DTI) on b0+b1000+b2000 data (output in subdirectory /dki)

Arguments:
  sID         Subject ID (e.g. 001) 
  ssID        Session ID (e.g. MR2)
Options:
  -dwi				dMRI preprocessed data in MRtrix .mif format (default: \$datadir/dwi/sub-sID_ses-ssID_desc-preproc-inorm_dwi.mif
  -mask				Brain mask in .mif format (default: \$datadir/dwi/sub-sID_ses-ssID_space-dwi_mask.mif)
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
dwi=""; mask=""  # See below - Defaults cont'd
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

# Defaults cont'd
if [ $dwi=="" ]; then
  dwi=$datadir/dwi/sub-${sID}_ses-${ssID}_desc-preproc-inorm_dwi.mif
fi
if [ $mask=="" ]; then
  mask=$datadir/dwi/sub-${sID}_ses-${ssID}_space-dwi_mask.mif
fi

# Check if images exist, else put in No_image
if [ ! -f $dwi ]; then dwi="No_image"; fi
if [ ! -f $mask ]; then dwi="No_image"; fi

echo "DTI and DKI estimation
Subject:       	$sID 
Session:        $ssID
DWI (AP):       $dwi
Mask:           $mask
Directory:      $datadir
Threads:        $threads
 
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
# 1. Create $dwibase.mif in $datadir/dwi if does not exist

dwisuffix=sub-${sID}_ses-${ssID}_desc-preproc-inorm; 
masksuffix=sub-${sID}_ses-${ssID}_space-dwi;
if [ ! -f $datadir/dwi/${dwisuffix}_dwi.mif ]; then mrconvert $dwi $datadir/dwi/${dwisuffix}_dwi.mif; fi
if [ ! -f $datadir/dwi/${masksuffix}_mask.mif ]; then mrconvert $mask $datadir/dwi/${masksuffix}_mask.mif; fi

# update dwi and mask to point at their filebases
dwi=${dwisuffix}_dwi
mask=${masksuffix}_mask

##################################################################################
## 2. Tensor estimation and tensor parameter calculation

cd $datadir/dwi

if [ ! -d dti ]; then mkdir -p dti; fi
cd dti

if [ ! -f ${dwi}_DT.nii ]; then
    # Only use shells b0 and b1000 for DTI estimation 
    echo "Estimating DTI parameters using only b0 and b1000 shells"
    dwiextract -shells 0,1000 ../${dwi}.mif - | dwi2tensor -mask ../$mask.mif - ${dwi}_DT.nii; 
    tensor2metric -force -fa ${dwi}_FA.nii -adc ${dwi}_MD.nii -rd ${dwi}_RD.nii -ad ${dwi}_AD.nii -vector ${dwi}_RGB.nii -mask ../$mask.mif  ${dwi}_DT.nii
    # Calculate Trace=lambda1+lambda2+lambda3 as 3*MD
    mrcalc ${dwi}_MD.nii 3 -mult ${dwi}_Trace.nii
fi

cd $currdir

##################################################################################
## 3. Kurtosis estimation and kurtosis parameter calculation

cd $datadir/dwi

# Make sure we have NIfTI-versions of $dwi and $mask
if [ ! -f $dwi.nii ]; then
  mrconvert  -json_export $dwi.json -export_grad_fsl $dwi.bvec $dwi.bval $dwi.mif $dwi.nii
fi
if [ ! -f mask.nii ]; then
  mrconvert  -json_export $mask.json $mask.mif $mask.nii  
fi

if [ ! -d dki ]; then mkdir -p dki; fi
cd dki

# Fit the DTI and DKI using DIPY's dipy_fit_dki
dipy_fit_dki  --force \
              --out_dt_tensor ${dwi}_dt.nii \
              --out_fa ${dwi}_fa.nii \
              --out_ga ${dwi}_ga.nii \
              --out_rgb ${dwi}_rgb.nii \
              --out_md ${dwi}_md.nii \
              --out_ad ${dwi}_ad.nii \
              --out_rd ${dwi}_rd.nii \
              --out_mode ${dwi}_mode.nii \
              --out_evec ${dwi}_evec.nii \
              --out_eval ${dwi}_eval.nii \
              --out_dk_tensor ${dwi}_dk.nii \
              --out_mk ${dwi}_mk.nii \
              --out_ak ${dwi}_ak.nii \
              --out_rk ${dwi}_rk.nii \
              ../$dwi.nii ../$dwi.bval ../$dwi.bvec ../$mask.nii 
# Calculate the Trace from eval
mrmath -force ${dwi}_eval.nii -axis 3 sum ${dwi}_trace.nii

cd $currdir



##################################################################################
