#!/bin/bash
# KPUM NODDI
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base sID ssID [options]
Script that calulcates NODDI parameters

Arguments:
  sID         Subject ID (e.g. 001) 
  ssID        Session ID (e.g. MR2)
Options:
  -derivatives          Derivatives folder (default: derivatives/dMRI_op)
  -subjectdata          Subject datafolder in derivatives folder which harbors dMRI data (default: sub-sID/ses-ssID/dwi)
  -dwi                  Preprocessed and intensity normalised dMRI in .mif format (default: \$derivatives/\$subjectdata/sub-sID_ses-ssID_dir-AP_desc-preproc-inorm_dwi.mif)
  -mask                 Brain mask in .mif format (default: \$derivatives/\$subjectdata/sub-sID_ses-ssID_space-dwi_mask.mif)
  -dPar                 Axial diffusivity to use for NODDI (default: 0.0017)
  -threads              Number of threads for MRtrix commands (default: 4)
  -h / -help / --help   Print usage.
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
derivatives=derivatives/dMRI
subjectdata=sub-$sID/ses-$ssID/dwi
dwi=""; mask=""  # See below - Defaults cont'd
threads=4
dPar=1.7e-3 

# check whether the different tools are set and load parameters
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

while [ $# -gt 0 ]; do
    case "$1" in
    -derivatives) shift; derivatives=$1; ;;
    -subjectdata) shift; subjectdata=$1; ;;
	-dwi) shift; dwi=$1; ;;
	-mask) shift; mask=$1; ;;
	-dPar) shift; dPar=$1; ;;
	-threads) shift; threads=$1; ;;
	-d|-data-dir)  shift; datadir=$1; ;;
	-h|-help|--help) usage; ;;
	-*) echo "$0: Unrecognized option $1" >&2; usage; ;;
	*) break ;;
    esac
    shift
done

# Now decided datadir
datadir=$derivatives/$subjectdata

# Defaults cont'd
if [ $dwi=="" ]; then
  dwi=$datadir/sub-${sID}_ses-${ssID}_dir-AP_desc-preproc-inorm_dwi.mif
fi
if [ $mask=="" ]; then
  mask=$datadir/sub-${sID}_ses-${ssID}_space-dwi_mask.mif
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
dPar:           $dPar           
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

if [ ! -d $datadir ]; then mkdir -p $datadir; fi

##################################################################################
# 1. Create $dwibase.mif in $datadir/dwi if does not exist

dwisuffix=sub-${sID}_ses-${ssID}_dir-AP_desc-preproc-inorm; 
masksuffix=sub-${sID}_ses-${ssID}_space-dwi;

# Put files in correct location
if [ ! -f $datadir/${dwisuffix}_dwi.mif ]; then mrconvert $dwi $datadir/${dwisuffix}_dwi.mif; fi
if [ ! -f $datadir/${masksuffix}_mask.mif ]; then mrconvert $mask $datadir/${masksuffix}_mask.mif; fi

# update dwi and mask to point at their filebases
dwi=${dwisuffix}_dwi
mask=${masksuffix}_mask

cd $datadir
# and make NIfTI-versions of ${dwi}_inorm.mif and mask.mif
if [ ! -f $dwi.nii ]; then
	mrconvert -json_export $dwi.json -export_grad_fsl $dwi.bvec $dwi.bval $dwi.mif $dwi.nii
fi
if [ ! -f $mask.nii ]; then
	mrconvert -json_export $mask.json $mask.mif $mask.nii
fi

cd $currdir

##################################################################################
## 1. NODDI estimation
# Output files (nii.gz by default) are saved AMICO/NODDI_dPar 

python3 code/kpum_noddi/python/dmri_noddi.py \
        --derivatives $derivatives \
        --subjectdata $subjectdata \
        --dwi $dwi.nii \
        --bvec $dwi.bvec \
        --bval $dwi.bval \
        --mask $mask.nii \
        --dPar $dPar

##################################################################################

##################################################################################
## 2. Rename output files

# only works when dPar is input in the format 0.0015
dParStr=`echo $dPar | sed 's/\./p/g'`
cd $derivatives/$subjectdata/AMICO/NODDI_dPar-$dParStr
for file in *.nii.gz; do
    gunzip $file
    mv $file ${dwisuffix}_recon-NODDI-dPar-${dParStr}_$file
done
cd $currdir
##################################################################################
