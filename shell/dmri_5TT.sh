#!/bin/bash
# KPUM NODDI
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base sID ssID studydir [options]
Runs the 5ttgen mcrib routine for generation of 5TT image from T2w
Also generates/transforms M-CRIB parcellations into space-T2w

Arguments:
    sID                         Subject ID (e.g. 001) 
    ssID                        Session ID (e.g. MR2)
    studydir                    Studydir with full path (e.g. \$PWD or /mnt/e/Finn/KPUM_NODDI/Data)
Options:
    -t2w                        T2 image (default: \$datadir/anat/orig/sub-sID_ses-ssID_acq-mcrib_T2w.nii)
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

# check whether the different tools are set and load parameters
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

while [ $# -gt 0 ]; do
    case "$1" in
	-t2w) shift; t2w=$1; ;;
	-threads) shift; threads=$1; ;;
	-d|-data-dir)  shift; datadir=$1; ;;
	-h|-help|--help) usage; ;;
	-*) echo "$0: Unrecognized option $1" >&2; usage; ;;
	*) break ;;
    esac
    shift
done

# Defaults cont'd
if [ $t2w=="" ]; then
    t2w=$datadir/anat/orig/sub-${sID}_ses-${ssID}_acq-mcrib_T2w.nii
fi

# Check if images exist, else put in No_image
if [ ! -f $t2w ]; then t2w="No_image"; fi

echo "Generating 5TT image using MRtrix's 5ttgen mcrib routine
Subject:       	$sID 
Session:        $ssID
Studydir:       $studydir
T2w:            $t2w
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

##################################################################################
## 2. N4-biasfield correct 
cd $datadir/anat

if [ ! -f sub-${sID}_ses-${ssID}_desc-restore_T2w.nii ]; then
    # N4 biasfield (ANTs)
    N4BiasFieldCorrection -d 3 -i orig/$t2w.nii -x sub-${sID}_ses-${ssID}_space-T2w_mask.nii -o [sub-${sID}_ses-${ssID}_desc-restore_T2w.nii,sub-${sID}_ses-${ssID}_desc-biasfield_T2w.nii] -c [50x50x50,0.001] -s 2 -b [100,3] -t [0.15,0.01,200]
fi
cd $currdir

##################################################################################
## 3. Perform 5ttgen mcrib
cd $datadir/anat

MCRIBpath=$studydir/atlases/M-CRIB
scratchdir=5ttgen_mcrib

mrtrix_path=$HOME/Software/mrtrix3
mrtrix_5ttgen_mcrib_path=$HOME/Software/mrtrix_5ttgen_neonatal
export PATH="${mrtrix_5ttgen_mcrib_path}/bin:$PATH"

# Run 5ttgen mcrib
# NOTE - built from Manuel Blesa's github repo https://github.com/mblesac/mrtrix3/tree/5ttgen_neonatal_rs

if [ ! -f sub-${sID}_ses-${ssID}_5TT.nii ]; then

    # Put mrtrix3_5ttgen_neonatal first in $PATH
    mrtrix_path=$HOME/Software/mrtrix3
    mrtrix_5ttgen_neonatal_path=$HOME/Software/mrtrix_5ttgen_neonatal
    export PATH="${mrtrix_5ttgen_neonatal_path}/bin:$PATH"

    5ttgen mcrib \
	   -mask sub-${sID}_ses-${ssID}_space-T2w_mask.nii \
	   -mcrib_path $MCRIBpath \
	   -ants_parallel 0 -quick -nthreads $threads \
	   -nocleanup -scratch $scratchdir \
	   -sgm_amyg_hipp \
	   -parcellation sub-${sID}_ses-${ssID}_desc-mcrib_dseg.nii \
	   sub-${sID}_ses-${ssID}_desc-restore_T2w.nii t2w sub-${sID}_ses-${ssID}_5TT.nii

#    5ttgen mcrib \
#	   -mask sub-${sID}_ses-${ssID}_space-T2w_mask.nii \
#	   -mcrib_path $MCRIBpath \
#	   -ants_parallel 2 -nthreads $threads \
#	   -nocleanup -scratch $scratchdir \
#	   -sgm_amyg_hipp \
#	   -parcellation sub-${sID}_ses-${ssID}_desc-mcrib_dseg.nii \
#	   sub-${sID}_ses-${ssID}_desc-restore_T2w.nii t2w sub-${sID}_ses-${ssID}_5TT.nii
    # clean up
    # rm -rf $scratchdir

    # Put back original mrtrix3 first in $PATH
    export PATH="${mrtrix_path}/bin:$PATH"

fi


cd $currdir

#######################################################################################

end=`date +%s`
runtime=$((end-start))
TIME=$(convertsecs $runtime)
echo "Total runtime = $TIME"
