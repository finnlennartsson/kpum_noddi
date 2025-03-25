#!/bin/bash
# KPUM NODDI
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base sID ssID studydir [options]
- do motion-correction (not yet implemented)
- make high-resolution versions T2w MCRIB \
- create relevant brain masks for neonatal-segmentation \

Arguments:
    sID             Subject ID (e.g. 001) 
    ssID            Session ID (e.g. MR2)
    studydir        Studydir with full path (e.g. \$PWD or /mnt/e/Finn/KPUM_NODDI/Data)
Options:
  -T2                         T2 image in .nii format (default: \$datadir/anat/orig/sub-sID_ses-ssID_acq-mcrib_T2w.nii)
  -d / -data-dir  <directory>   The directory in \$studydir used to output files in (default: derivatives/dMRI/sub-sID/ses-ssID)
  -h / -help / --help           Print usage.
"
  exit;
}

################ ARGUMENTS ################

[ $# -ge 1 ] || { usage; }
command=$@
sID=$1
ssID=$2
studydir=$3
shift; shift; shift

# Defaults
datadir=$studydir/derivatives/dMRI/sub-$sID/ses-$ssID
t2w="" # See below - Defaults cont'd

# check whether the different tools are set and load parameters
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

currdir=$PWD

while [ $# -gt 0 ]; do
  case "$1" in
	  -T2) shift; t2w=$1; ;;
	  -d|-datadir)  shift; datadir=$1; ;;
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
if [ ! -f $t2w ]; then t2w="No_image"; fi

echo "Preproc for sMRI-processing
Subject:        $sID 
Session:        $ssID
Studydir:       $studydir
T2:             $t2w 
Directory:      $datadir 

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
if [ ! -d $datadir/anat/orig ]; then mkdir -p $datadir/anat/orig; fi

t2wbasename=`basename $t2w .nii` #sub-${sID}_ses-${ssID}_T2w

if [ ! -f $datadir/anat/orig/$t2wbasename.nii ]; then 
  cp $t2w $datadir/anat/orig/.
fi

#Then update to refer to filebase names (instead of path/file)
t2w=`basename $t2w .nii` #sub-${sID}_ses-${ssID}_T2w

##################################################################################
# 1. Motion-correction
# Not yet implememented

##################################################################################
# 2. Upsample T2w (required for DrawEM neonatal-segmentation)

cd $datadir/anat

if [ ! -d preproc ]; then mkdir -p preproc; fi

image=$t2w;
if [[ $image = "No_image" ]]; then echo "No T2w image"; exit;
else
    if [[ `echo $image | sed 's/\_/\ /g' | awk '{print $NF}'` = T2w ]]; then
	    # BIDS compliant highres name by adding desc-hires in front of T2w 
	    highres=`echo $image | sed 's/\_T2w/\_desc\-hires\_T2w/g'`
    else
	    # or else, just add desc-highres before the file name
	    highres=desc-hires_${image}
    fi
    # Do interpolation (spline)
    if [ ! -f preproc/$highres.nii ]; then
      flirt -in orig/$image.nii -ref orig/$image.nii -applyisoxfm 0.68 -nosearch -out preproc/$highres.nii -interp spline
    fi
    # and update t2w to point to highres
    t2w=$highres;
fi

cd $currdir

##################################################################################
## 3. Create brain mask in T2w-space
cd $datadir/anat

if [ ! -f sub-${sID}_ses-${ssID}_space-T2w_mask.nii ];then
    # bet T2w using -F flag
    bet preproc${t2w}.nii ${t2w}_brain.nii -m -R -F #f 0.3
    mv ${t2w}_brain_mask.nii sub-${sID}_ses-${ssID}_space-T2w_mask.nii

    # Clean-up
    rm *brain*
fi
cd $currdir

##################################################################################
## 3. Finish by creating symbolic link to relevant preprocessed file
cd $datadir/anat

if [ ! -f sub-${sID}_ses-${ssID}_desc-preproc_T2w.nii ]; then 
	# create symbolic link to preproc file
	mrconvert preproc/$t2w.nii sub-${sID}_ses-${ssID}_desc-preproc_T2w.nii;
fi
	
cd $currdir
