#!/bin/bash
# KPUM NODDI
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base sID ssID studydir [options]
Script that performs OpenMAP-Di by
1. Transfer data into OpenMap-Di folder in correct format
2. Perform OpenMap-Di parcellation

Arguments:
  sID                   Subject ID (e.g. 001) 
  ssID                  Session ID (e.g. MR2)
  studydir              Studydir with full path (e.g. \$PWD or /mnt/e/Finn/KPUM_NODDI/Data)

Options:
  -d / -datadir         Derivatives folder (default: \$studydir/derivatives/dMRI/sub-sID/ses-ssID/dwi)
  -dwi                  Preprocessed and intensity normalised dMRI in .mif format (default: \$datadir/sub-sID_ses-ssID_dir-AP_desc-preproc-inorm_dwi.mif)
  -mask                 Brain mask in .mif format (default: \$derivatives/\$subjectdata/sub-sID_ses-ssID_space-dwi_mask.mif)
  -openmap_path         Path to OpenMap-Di installation (default: $HOME/Software/OpenMAP-Di)  
  -device               Device for OpenMAP-Di (defalt: cpu)
  -t / -threads         Number of threads for MRtrix commands (default: 4)
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
datadir=$studydir/derivatives/dMRI/sub-$sID/ses-$ssID/dwi
dwi=""; mask=""  # See below - Defaults cont'd
openmap_path=$HOME/Software/OpenMAP-Di
device=cpu
threads=4

# check whether the different tools are set and load parameters
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

while [ $# -gt 0 ]; do
    case "$1" in
	  -dwi) shift; dwi=$1; ;;
	  -mask) shift; mask=$1; ;;
    -openmap_path) shift; openmap_path=$1; ;;
    -device) shift; device=1; ;;
	  -t|-threads) shift; threads=$1; ;;
	  -d|-datadir)  shift; datadir=$1; ;;
	  -h|-help|--help) usage; ;;
	  -*) echo "$0: Unrecognized option $1" >&2; usage; ;;
	  *) break ;;
    esac
    shift
done

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
Datadir:        $datadir
DWI (AP):       $dwi
Mask:           $mask   
Device:         $device  
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
# 1. Transfer data into OpenMap-Di folder in correct format

openmap_folder=$datadir/OpenMAP-Di
dwibase=`basename $dwi _dwi.mif`

if [ ! -d $openmap_folder ]; then mkdir -p $openmap_folder; fi

# Convert 3axis-DWI to _0000.nii.gz
isodwi=$datadir/sub-${sID}_ses-${ssID}_dir-AP_desc-preproc-inorm-brain_meanb1000.mif
mrconvert $isodwi $openmap_folder/${dwibase}_0000.nii.gz
# Convert b0 to _0001.nii.gz
b0=$datadir/sub-${sID}_ses-${ssID}_dir-AP_desc-preproc-inorm-brain_meanb0.mif
mrconvert $b0 $openmap_folder/${dwibase}_0001.nii.gz
# Convert to RGB as: R => _0002.nii.gz G => _0003.nii.gz; B => _0004.nii.gz
rgb=$datadir/dti/sub-${sID}_ses-${ssID}_dir-AP_desc-preproc-inorm_dwi_RGB.nii
for idx in 0 1 2; do
  index=$((idx + 2))
  mrconvert -coord 3 $idx $rgb - | mrcalc - -abs $openmap_folder/${dwibase}_000${index}.nii.gz
done

##################################################################################
# 2. Run OpenMap-Di on subject

python $openmap_path/parcellate_neonatal_brain.py  -i $openmap_folder -o $openmap_folder -m $openmap_path/nnUNetTrainerNoMirroring__nnUNetPlans__3d_fullres -device $device


