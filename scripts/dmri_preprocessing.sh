#!/bin/bash
# KPUM_NODDI
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base subjectID [options]
Script to do preprocessing of dMRI 
0. Creates folder structure 
   $datadir
	    	/dwi
		/anat
		/fmap
		/qc
		/xfm
		/logs
   and copies the relevant files into /dwi, /anat and /fmap
1. MP-PCA Denoising and Gibbs Unringing 
2. (TOPUP) and EDDY for eddy current-, motion- and (susceptebility image distortion) correction
3. N4 biasfield correction, Normalisation

Arguments:
  sID				Subject ID (e.g. 001) 

Options:
  -dwi				dMRI AP data (default: rawdata/sub-sID/dwi/sub-sID_dir-AP_run-1_dwi.nii.gz)
  -d / -data-dir  <directory>   The directory used to output the preprocessed files (default: derivatives/dMRI/sub-sID/ses-ssID)
  -h / -help / --help           Print usage.
"
  exit;
}

################ ARGUMENTS ################

[ $# -ge 1 ] || { usage; }
command=$@
sID=$1

currdir=$PWD

# Defaults
dwi=rawdata/sub-$sID/dwi/sub-${sID}_dir-AP_run-1_dwi.nii.gz
datadir=derivatives/dMRI/sub-$sID
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

shift;
while [ $# -gt 0 ]; do
    case "$1" in
	-dwi) shift; dwi=$1; ;;
	-d|-data-dir)  shift; datadir=$1; ;;
	-h|-help|--help) usage; ;;
	-*) echo "$0: Unrecognized option $1" >&2; usage; ;;
	*) break ;;
    esac
    shift
done

# Check if files exist, else put in blank/No_image
if [ ! -f $dwi ]; then dwi=""; fi

echo "Preparing for dMRI pipeline              
Subject:       	$sID 
DWI (AP):	$dwi
Directory:     	$datadir 
$BASH_SOURCE   	$command
----------------------------"

logdir=$datadir/logs
if [ ! -d $datadir ];then mkdir -p $datadir; fi
if [ ! -d $logdir ];then mkdir -p $logdir; fi

echo dMRI preprocessing on subject $sID 
script=`basename $0 .sh`
echo Executing: $codedir/$script.sh $command > ${logdir}/sub-${sID}_$script.log 2>&1
echo "" >> ${logdir}/sub-${sID}_$script.log 2>&1
echo "Printout $script.sh" >> ${logdir}/sub-${sID}_$script.log 2>&1
cat $codedir/$script.sh >> ${logdir}/sub-${sID}_$script.log 2>&1
echo


##################################################################################
# 0a. Create subfolders in $datadir

cd $datadir
if [ ! -d anat/orig ]; then mkdir -p anat/orig; fi
if [ ! -d dwi/orig ]; then mkdir -p dwi/orig; fi
if [ ! -d fmap/orig ]; then mkdir -p fmap/orig; fi
if [ ! -d xfm ]; then mkdir -p xfm; fi
if [ ! -d qc ]; then mkdir -p qc; fi
cd $currdir

##################################################################################
# 0. Copy to files to $datadir (incl .json and bvecs/bvals files if present at original location)

# ANATOMY

# FMAP

# DWI
#filelist="$dwi $dwiAPsbref $dwiPA $dwiPAsbref $seAP $sePA"
filelist="$dwi"
for file in $filelist; do
    filebase=`basename $file .nii.gz`;
    filedir=`dirname $file`
    if [ $file == $dwi ]; then
	cp $file $filedir/$filebase.json $filedir/$filebase.bval $filedir/$filebase.bvec $datadir/dwi/orig/.
	# and convert to dwi.mif to be used in processing and put into $datadir/dwi/preproc
	if [ -d $datadir/dwi/preproc ]; then mkdir -p $datadir/dwi/preproc; fi
	mrconvert -stride -1,2,3,4 -json_import $datadir/dwi/orig/$filebase.json -fslgrad $datadir/dwi/orig/$filebase.bvec $datadir/dwi/orig/$filebase.bval $datadir/dwi/orig/$filebase.nii.gz $datadir/dwi/preproc/dwi.mif
    else # should be put in /fmap
	cp $file $filedir/$filebase.json $datadir/fmap/orig/$filebase.nii.gz $datadir/dwi/orig/.
    fi	
done

##################################################################################

##################################################################################
# 1. Do PCA-denoising and Remove Gibbs Ringing Artifacts
cd $datadir/dwi/preproc

# Directory for QC files
if [ ! -d denoise ]; then mkdir denoise; fi

# Perform PCA-denosing
if [ ! -f dwi_den.mif ]; then
    echo Doing MP PCA-denosing with dwidenoise
    # PCA-denoising
    dwidenoise dwi.mif dwi_den.mif -noise denoise/dwi_noise.mif -nthreads 4;
    # and calculate residuals
    mrcalc dwi.mif dwi_den.mif -subtract denoise/dwi_den_residuals.mif
    echo Check the residuals! Should not contain anatomical structure
fi

# Directory for QC files
if [ ! -d unring ]; then mkdir unring; fi

if [ ! -f dwi_den_unr.mif ]; then
    echo Remove Gibbs Ringing Artifacts with mrdegibbs
    # Gibbs 
    mrdegibbs -axes 0,1 dwi_den.mif dwi_den_unr.mif -nthreads 4
    #calculate residuals
    mrcalc dwi_den.mif  dwi_den_unr.mif -subtract unring/dwi_den_unr_residuals.mif
    echo Check the residuals! Should not contain anatomical structure
fi

cd $currdir


##################################################################################
# 2. EDDY for Motion- and eddy distortion correction (NOTE - no FMAP exists)
#
cd $datadir/dwi/preproc

scratchdir=dwifslpreproc
TRT=`mrinfo -property TotalReadoutTime dwi.mif`
PEdir=`mrinfo -property PhaseEncodingDirection dwi.mif`

if [ ! -f dwi_den_unr_eddy.mif ];then
    dwifslpreproc -rpe_none -pe_dir $PEdir -readout_time $TRT \
		  -nocleanup \
		  -scratch $scratchdir \
		  -eddy_options " --slm=linear --repol --mporder=8 --s2v_niter=10 --s2v_interp=trilinear --s2v_lambda=1 --mbs_niter=20 --mbs_ksp=10 --mbs_lambda=10 " \
		  -eddyqc_all eddy \
		  -nthreads 4 \
		  dwi_den_unr.mif \
		  dwi_den_unr_eddy.mif;

    # Now cleanup by transferring relevant files to topup folder and deleting scratch folder
    mv eddy/quad ../../../qc/.
    cp $scratchdir/command.txt $scratchdir/log.txt $scratchdir/eddy_*.txt $scratchdir/applytopup_*.txt $scratchdir/slspec.txt eddy/.
    rm -rf $scratchdir 
    
fi
cd $currdir


##################################################################################
# 3a. Mask generation, N4 biasfield correction
cd $datadir/dwi/preproc

echo "Pre-processing with mask generation, N4 biasfield correction, Normalisation, meanb0,1000,2000 generation and tensor estimation"

# point to right filebase
dwi=dwi_den_unr_eddy

# Create mask and dilate (to ensure usage with ACT)
if [ ! -f mask.mif ]; then
    dwiextract -bzero $dwi.mif - | mrmath -force -axis 3 - mean meanb0tmp.nii.gz
    bet meanb0tmp meanb0tmp_brain -m -f 0.25 -R #-f 0.25 from dHCP dMRI pipeline
    # Check result
    # echo mrview meanb0tmp.nii.gz -roi.load meanb0tmp_brain_mask.nii.gz -roi.opacity 0.5 -mode 2
    mrconvert meanb0tmp_brain_mask.nii.gz mask.mif
    rm meanb0tmp*
fi

# Do B1-correction. Use ANTs N4
if [ ! -f  ${dwi}_N4.mif ]; then
    threads=4;
    if [ ! -d N4 ]; then mkdir N4; fi
    dwibiascorrect ants -mask mask.mif -bias N4/bias.mif $dwi.mif ${dwi}_N4.mif
fi


# last file in the processing
dwipreproclast=${dwi}_N4.mif

cd $currdir


##################################################################################
## 3b. B0-normalise and tensor estimation

cd $datadir/dwi

# Create symbolic link to last file in /preproc and copy mask.mif to $datadir/dwi
mrconvert preproc/$dwipreproclast dwi_preproc.mif
mrconvert preproc/mask.mif mask.mif
dwi=dwi_preproc

# B0-normalisation
if [ ! -f ${dwi}_inorm.mif ]; then
    dwinormalise individual $dwi.mif mask.mif ${dwi}_inorm.mif
fi

# Extract mean b0, b1000 and b2000
for bvalue in 0 1000 2000; do
    bfile=meanb$bvalue

    if [ $bvalue == 0 ]; then
	if [ ! -f $bfile.mif ]; then
	    dwiextract -shells $bvalue ${dwi}_inorm.mif - |  mrmath -force -axis 3 - mean $bfile.mif
	fi
    fi
    
    if [ ! -f ${bfile}_brain.mif ]; then
	dwiextract -shells $bvalue ${dwi}_inorm.mif - |  mrmath -force -axis 3 - mean - | mrcalc - mask.mif -mul ${bfile}_brain.mif
	#mrconvert $bfile.mif $bfile.nii.gz
	#mrconvert ${bfile}_brain.mif ${bfile}_brain.nii.gz
	echo "Visually check the ${bfile}_brain.mif"
	echo mrview ${bfile}_brain.mif -mode 2
    fi
done

# Calculate diffusion tensor and tensor metrics

if [ ! -f dt.mif ]; then
    dwi2tensor -mask mask.mif ${dwi}_inorm.mif dt.mif
    tensor2metric -force -fa fa.mif -adc adc.mif -rd rd.mif -ad ad.mif -vector ev.mif dt.mif
fi

cd $currdir
