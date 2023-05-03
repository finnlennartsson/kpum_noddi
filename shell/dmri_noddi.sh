#!/bin/bash
# KPUM NODDI
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base sID ssID studydir [options]
Script that calulcates NODDI parameters

Arguments:
  sID                   Subject ID (e.g. 001) 
  ssID                  Session ID (e.g. MR2)
  studydir              Studydir with full path (e.g. \$PWD or /mnt/e/Finn/KPUM_NODDI/Data)
Options:
  -derivatives          Derivatives folder (default: \$studydir/derivatives/dMRI)
  -subjectdata          Subject datafolder in derivatives folder which harbors dMRI data (default: sub-sID/ses-ssID/dwi)
  -dwi                  Preprocessed and intensity normalised dMRI in .mif format (default: \$derivatives/\$subjectdata/sub-sID_ses-ssID_dir-AP_desc-preproc-inorm_dwi.mif)
  -mask                 Brain mask in .mif format (default: \$derivatives/\$subjectdata/sub-sID_ses-ssID_space-dwi_mask.mif)
  -dPar                 Axial diffusivity to use for NODDI (default: 0.0017)
  -t / threads          Number of threads for MRtrix commands (default: 4)
  -h / -help / --help   Print usage.
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
derivatives=$studydir/derivatives/dMRI
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
	  -t|-threads) shift; threads=$1; ;;
	  -d|-data-dir)  shift; datadir=$1; ;;
	  -h|-help|--help) usage; ;;
	  -*) echo "$0: Unrecognized option $1" >&2; usage; ;;
	  *) break ;;
    esac
    shift
done

# Now we have decided the $datadir
datadir=$derivatives/$subjectdata

# Defaults cont'd since we have $datadir from above
if [ $dwi=="" ]; then
  dwi=$datadir/sub-${sID}_ses-${ssID}_dir-AP_desc-preproc-inorm_dwi.mif
fi
if [ $mask=="" ]; then
  mask=$datadir/sub-${sID}_ses-${ssID}_space-dwi_mask.mif
fi

# Check if images exist, else put in No_image
if [ ! -f $dwi ]; then dwi="No_image"; fi
if [ ! -f $mask ]; then mask="No_image"; fi

echo "NODDI estimation
----------------------------
Subject:       	$sID 
Session:        $ssID
Studydir:       $studydir
Derivatives:    $derivatives
Subjectdata:    $subjectdata
DWI (AP):       $dwi
Mask:           $mask
dPar:           $dPar           
Threads:        $threads
 
Codedir:        $codedir
$BASH_SOURCE   	$command
----------------------------"

logdir=$datadir/../logs # the logs folder is located go one step below $datadir
if [ ! -d $datadir ]; then mkdir -p $datadir; fi
if [ ! -d $logdir ]; then mkdir -p $logdir; fi

script=`basename $0 .sh`
echo "Running $script on subject $sID and session $ssID"
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
# Output files (nii.gz by default) and are saved in AMICO/NODDI 

dParStr=`echo $dPar | sed 's/\./p/g'`

if [ ! -f $datadir/noddi/${dwisuffix}_recon-NODDI-dPar-${dParStr}_FIT_ICVF.nii ] ; then
  python3 $codedir/../python/dmri_noddi.py \
          --derivatives $derivatives \
          --subjectdata $subjectdata \
          --dwi $dwi.nii \
          --bvec $dwi.bvec \
          --bval $dwi.bval \
          --mask $mask.nii \
          --dPar $dPar
  # Rename output files
  cd $datadir/AMICO/NODDI
  for file in *.nii.gz; do
    mv $file ${dwisuffix}_recon-NODDI-dPar-${dParStr}_$file
    gunzip ${dwisuffix}_recon-NODDI-dPar-${dParStr}_$file
  done
  # and move everything to $datadir/noddi
  cd ../..
  if [ ! -d noddi ]; then mkdir noddi; fi
  mv AMICO/NODDI/* noddi/.
  rm -rf AMICO
  cd $currdir
fi

##################################################################################
