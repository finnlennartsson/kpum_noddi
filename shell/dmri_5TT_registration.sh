#!/bin/bash
# KPUM NODDI
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base sID ssID studydir [options]
1.  Runs the 5ttgen mcrib routine for generation of 5TT image from T2w
    Also generates/transforms M-CRIB parcellations into space-T2w
2.  Performs registration T2 <=> dwi
    and maps T2, 5TT and M-CRIB parcellations into space-dwi

Arguments:
    sID                         Subject ID (e.g. 001) 
    ssID                        Session ID (e.g. MR2)
    studydir                    Studydir with full path (e.g. \$PWD or /mnt/e/Finn/KPUM_NODDI/Data)
Options:
    -t2w                        T2w image (default: \$datadir/anat/orig/sub-sID_ses-ssID_acq-mcrib_T2w.nii)
    -a / -atlas			Atlas used for parcellation (options ALBERT or MCRIB) (default: M-CRIB)
    -p / protocol                 MRI protocol used in study [ORIG/NEW] (default: ORIG) 
    -threads                    Number of CPUs to use (default: 10)
    -d / -data-dir  <directory> The directory used to output the preprocessed files (default: \$studydir/derivatives/dMRI/sub-sID/ses-ssID)
    -h / -help / --help         Print usage.
"
  exit;
}

convertsecs() 
{
 ((h=${1}/3600))
 ((m=(${1}%3600)/60))
 ((s=${1}%60))
 printf "%02d:%02d:%02d\n" $h $m $s
}

start=`date +%s`

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
t2w="";  # See below - Defaults cont'd
threads=10
atlas="M-CRIB"
protocol='NEW'

# check whether the different tools are set and load parameters
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

while [ $# -gt 0 ]; do
    case "$1" in
	-t2w) shift; t2w=$1; ;;
	-threads) shift; threads=$1; ;;
	-a|-atlas)  shift; atlas=$1; ;;
	-p|-protocol)  shift; protocol=$1; ;;
	-d|-data-dir)  shift; datadir=$1; ;;
	-h|-help|--help) usage; ;;
	-*) echo "$0: Unrecognized option $1" >&2; usage; ;;
	*) break ;;
    esac
    shift
done

# Defaults cont'd
if [[ $t2w == "" ]]; then
    t2w=$datadir/anat/orig/sub-${sID}_ses-${ssID}_acq-mcrib_T2w.nii
fi

# Check if images exist, else put in No_image
if [ ! -f $t2w ]; then t2w="No_image"; fi

echo "Generating 5TT image using MRtrix's 5ttgen mcrib routine
Subject:       	$sID 
Session:        $ssID
Studydir:       $studydir
T2w:            $t2w
Atlas:		$atlas
Protocol:	$protocol
Directory:     	$datadir 
Threads:        $threads

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
# 0. Copy to file to datadir 
t2wbase=`basename $t2w .nii`
if [ ! -d $datadir/anat/orig ]; then mkdir -p $datadir/anat/orig; fi

if [ ! -f $datadir/anat/orig/$t2wbase.nii ]; then
    cp $t2w $datadir/anat/orig/$t2wbase.nii
fi
# Then update to refer to filebase names (instead of path/file)
t2w=$t2wbase

##################################################################################
				        
##################################################################################
## 1. Create brain mask
cd $datadir/anat/orig

# Create brain mask
if [ ! -f sub-${sID}_ses-${ssID}_space-T2w_mask.nii ]; then
    bet $t2w.nii tmp.nii -m -R -f 0.3
    mv tmp_mask.nii ../sub-${sID}_ses-${ssID}_space-T2w_mask.nii
    #rm tmp*nii*
fi
cd $currdir

# refer t2wmask to this file
t2wmask=sub-${sID}_ses-${ssID}_space-T2w_mask.nii

##################################################################################
## 2. N4-biasfield correct 
cd $datadir/anat

if [ ! -f sub-${sID}_ses-${ssID}_desc-restore_T2w.nii ]; then
    # N4 biasfield (ANTs)
    N4BiasFieldCorrection -d 3 -i orig/$t2w.nii -x $t2wmask -o [sub-${sID}_ses-${ssID}_desc-restore_T2w.nii,sub-${sID}_ses-${ssID}_desc-biasfield_T2w.nii] -c [50x50x50,0.001] -s 2 -b [100,3] -t [0.15,0.01,200]
fi
cd $currdir

# update t2w to point to the N4BiasFieldCorrected T2w
t2w=sub-${sID}_ses-${ssID}_desc-restore_T2w.nii

##################################################################################
## 3. Perform 5ttgen mcrib
cd $datadir/anat

MCRIBpath=$studydir/atlases/M-CRIB

#scratchdir=5ttgen_mcrib
scratchdir=$HOME/5ttgen_mcrib

# Run 5ttgen mcrib
# NOTE - built from Manuel Blesa's github repo https://github.com/mblesac/mrtrix3/tree/5ttgen_neonatal_rs

if [ ! -f sub-${sID}_ses-${ssID}_5TT.nii ]; then

    # Put bin of mrtrix3_5ttgen_neonatal first in $PATH
    # mrtrix3_5ttgen_neonatal is installed in the same software location as mrtrix3
    # so just need to get the bin of this and then change the name
    # basefolder for installation of Manuel Blesa's mrtrix3 version with 5ttgen mcrib
    tmpbin=`which mrconvert`
    mrtrix3_bin=`dirname $tmpbin`
    mrtrix3_5ttgenmcrib_bin=`echo $mrtrix3_bin | sed 's/mrtrix3/mrtrix3\_5ttgen\_neonatal/g'`
    export PATH="$mrtrix3_5ttgenmcrib_bin:$PATH"
    echo $PATH

#    5ttgen mcrib \
#	   -mask $t2wmask \
#	   -mcrib_path $MCRIBpath \
#	   -ants_parallel 0 -quick -nthreads $threads \
#	   -nocleanup -scratch $scratchdir \
#	   -sgm_amyg_hipp \
#	   -parcellation sub-${sID}_ses-${ssID}_desc-mcrib_dseg.nii \
#	   $t2w t2w sub-${sID}_ses-${ssID}_5TT.nii

    5ttgen mcrib \
	   -mask sub-${sID}_ses-${ssID}_space-T2w_mask.nii \
	   -mcrib_path $MCRIBpath \
	   -ants_parallel 2 -nthreads $threads \
	   -nocleanup -scratch $scratchdir \
	   -sgm_amyg_hipp \
	   -parcellation sub-${sID}_ses-${ssID}_desc-mcrib_dseg.nii \
	   sub-${sID}_ses-${ssID}_desc-restore_T2w.nii t2w sub-${sID}_ses-${ssID}_5TT.nii
    # clean up
    # rm -rf $scratchdir

    # Put back original mrtrix3 first in $PATH
    export PATH="${mrtrix_path}/bin:$PATH"

fi

cd $currdir

#######################################################################################

##################################################################################
## 4. Registration 

cd $datadir
if [ ! -d xfm ]; then mkdir xfm; fi

# define variables
meanb1000_brain=sub-${sID}_ses-${ssID}_dir-AP_desc-preproc-inorm-brain_meanb1000.nii
meanb1000_brain_basename=`basename $meanb1000_brain .nii`
t2w_brain=sub-${sID}_ses-${ssID}_desc-restore-brain_T2w.nii

# First, 
# We have in preprocess don brain extractions of meanb1000, but needs to be in .nii-format
if [ ! -f dwi/$meanb1000_brain ]; then
    mrconvert dwi/${meanb1000_brain_basename}.mif dwi/$meanb1000_brain
fi
# and construct skull-stripped t2w
if [ ! -f anat/${t2w_brain} ]; then
    mrcalc anat/$t2w anat/$t2wmask -mult anat/$t2w_brain
fi

# Registration using BBR
if [ ! -f xfm/sub-${sID}_ses-${ssID}_from-dwi_to-T2w_flirt-bbr.mat ]; then 
    echo "Rigid-body linear registration using FSL's FLIRT with BBR"
    # First, make sure that we have a WM seg in /anat
    wmseg=sub-${sID}_ses-${ssID}_5TTwm.nii
    if [ ! -f anat/$wmseg ]; then
        # Extract WM from 5TT image and save as 3D image
	    mrconvert -coord 3 2 -axes 0,1,2 anat/sub-${sID}_ses-${ssID}_5TT.nii anat/$wmseg
    fi

#    # Second, perform 2-step registration
#    flirt -in dwi/$meanb1000_brain -ref anat/$t2w_brain -dof 6 -omat xfm/tmp.mat
#    flirt -in dwi/$meanb1000_brain -ref anat/$t2w_brain -dof 6 -cost bbr -wmseg anat/$wmseg -init xfm/tmp.mat -omat xfm/sub-${sID}_ses-${ssID}_from-dwi_to-T2w_flirt-bbr.mat -schedule $FSLDIR/etc/flirtsch/bbr.sch
#    rm xfm/tmp.mat

    # Currently, NOT working with BBR, so do only rigid-body 6 DOF (i.e. initialisation step)
    flirt -in dwi/$meanb1000_brain -ref anat/$t2w_brain -dof 6 -omat xfm/sub-${sID}_ses-${ssID}_from-dwi_to-T2w_flirt-rigid-6dof.mat


fi

# Transform FLIRT registration matrix into MRtrix format
if [ ! -f xfm/sub-${sID}_ses-${ssID}_from-dwi_to-T2w_mrtrix-rigid-6dof.mat ];then
     transformconvert xfm/sub-${sID}_ses-${ssID}_from-dwi_to-T2w_flirt-rigid-6dof.mat dwi/$meanb1000_brain anat/$t2w_brain flirt_import xfm/sub-${sID}_ses-${ssID}_from-dwi_to-T2w_mrtrix-rigid-6dof.mat
fi

cd $currdir

##################################################################################

####################################################################################################
## 5. Transformations of T2, 5TT, allLabels-file into dMRI space by updating image headers (no resampling!)

cd $datadir

# Define variables
t2w_dwispace=sub-${sID}_ses-${ssID}_desc-restore-brain_space-dwi_T2w.nii
t2w_dwispace_basename=`basename $t2w_dwispace .nii`

# T2
if [ ! -f anat/$t2w_dwispace ]; then
    mrtransform anat/$t2w -linear xfm/sub-${sID}_ses-${ssID}_from-dwi_to-T2w_mrtrix-rigid-6dof.mat anat/$t2w_dwispace -inverse
    mrconvert anat/$t2w_dwispace dwi/$t2w_dwispace_basename.mif
fi

# Take care of 5TT
actdir=dwi/5TT
if [ ! -d $actdir ]; then mkdir -p $actdir; fi
if [ ! -f  $actdir/sub-${sID}_ses-${ssID}_space-dwi_5TT.mif ]; then
    mrtransform -inverse -linear xfm/sub-${sID}_ses-${ssID}_from-dwi_to-T2w_mrtrix-rigid-6dof.mat anat/sub-${sID}_ses-${ssID}_5TT.nii $actdir/sub-${sID}_ses-${ssID}_space-dwi_5TT.mif
fi
if [ ! -f  $actdir/sub-${sID}_ses-${ssID}_space-dwi_5TTvis.mif ]; then
    5tt2vis $actdir/sub-${sID}_ses-${ssID}_space-dwi_5TT.mif $actdir/sub-${sID}_ses-${ssID}_space-dwi_5TTvis.mif
fi


# Take care of all_labels
labeldir=dwi/parcellation/M-CRIB
if [ ! -d $labeldir ]; then mkdir -p $labeldir; fi

if [ ! -f $labeldir/sub-${sID}_ses-${ssID}_desc-mcrib_space-dwi_dseg.mif ]; then
    mrtransform  -inverse -linear xfm/sub-${sID}_ses-${ssID}_from-dwi_to-T2w_mrtrix-rigid-6dof.mat anat/sub-${sID}_ses-${ssID}_desc-mcrib_dseg.nii $labeldir/sub-${sID}_ses-${ssID}_desc-mcrib_space-dwi_dseg.mif
fi

cd $currdir
####################################################################################################


end=`date +%s`
runtime=$((end-start))
TIME=$(convertsecs $runtime)
echo "Total runtime = $TIME"
