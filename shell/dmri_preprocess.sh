#!/bin/bash
# KPUM NODDI
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base subjectID sessionID studydir [options]
Script to preprocess dMRI data 
Requires that folder structure for dMRI pipeline has been run (e.g. with script dmri_prepare_pipeline.sh)
1. MP-PCA Denoising and Gibbs Unringing 
2. TOPUP and EDDY for motion- and susceptebility image distortion correction
3. N4 biasfield correction, Normalisation

Arguments:
  sID							Subject ID (e.g. 001) 
  ssID							Session ID (e.g. MR2)
  studydir                      Studydir with full path (e.g. \$PWD or /mnt/e/Finn/KPUM_NODDI/Data)
Options:
  -s / -session-file			Session file to depict which files should go into preprocessing. Overrides defaults below (default: \$studydir/derivatives/dMRI/sub-\$sID/ses-\$ssID/session_QC.tsv)
  -dwi							dMRI AP data (default: \$datadir/dwi/orig/sub-sID_ses-ssID_dir-AP_dwi.nii)
  -p / protocol					This defines MRI protocol [ORIG/NEW]; ORIG = no fmap dir-PA and use vol 0 as b0 value for dir-AP; NEW = fmap dir-PA and 7b0 values for dir-AP) (default: ORIG)
  -t / threads					Number of threads for MRtrix commands (default: 4)
  -d / -data-dir  <directory>	The directory used to output the preprocessed files (default: \$studydir/derivatives/dMRI/sub-\$sID/ses-\$ssID)
  -h / -help / --help			Print usage.
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
datadir=$studydir/derivatives/dMRI/sub-$sID/ses-$ssID
sessionfile=$studydir/derivatives/dMRI/sub-$sID/ses-$ssID/session_QC.tsv
threads=4
protocol=ORIG
# assign default for datadir and dwi dependent on if we have the default sessionfile
if [ ! -f $sessionfile ]; then
    dwi=$datadir/dwi/orig/sub-${sID}_ses-${ssID}_dir-AP_dwi.nii
    datadir=derivatives/dMRI/sub-$sID/ses-$ssID
    sessionfile=""
else # we have a sessionfile and we put datadir to its dirname
    datadir=`dirname $sessionfile`
    dwi=""
fi

# check whether the different tools are set and load parameters
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

while [ $# -gt 0 ]; do
    case "$1" in
	-s|session-file) shift; sessionfile=$1; ;;
	-dwi) shift; dwi=$1; ;;
	-t|-threads) shift; threads=$1; ;;
	-p|-protocol) shift; protocol=$1; ;;
	-d|-data-dir)  shift; datadir=$1; ;;
	-h|-help|--help) usage; ;;
	-*) echo "$0: Unrecognized option $1" >&2; usage; ;;
	*) break ;;
    esac
    shift
done


# Check if images exist, else put in No_image
if [ ! -f $dwi ]; then dwi=""; fi
if [ ! -f $sessionfile ]; then sessionfile="No_sessionfile"; fi

echo "dMRI preprocessing
Subject:       	$sID 
Session:        $ssID
Studydir:		$studydir
Session file:	$sessionfile
DWI (AP):		$dwi
MRI Protocol:	$protocol
Threads:		$threads
DataDirectory:	$datadir

Codedir:		$codedir
$BASH_SOURCE   	$command
----------------------------"

logdir=$datadir/logs
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
# Config

# Make sure we have FSLOUTPUTTYPE=NIFTI
export FSLOUTPUTTYPE=NIFTI

##################################################################################
# 0. Create subfolder structure in $datadir

cd $datadir
if [ ! -d anat ]; then mkdir -p anat; fi
if [ ! -d dwi ]; then mkdir -p dwi; fi
if [ ! -d fmap ]; then mkdir -p fmap; fi
if [ ! -d xfm ]; then mkdir -p xfm; fi
if [ ! -d qc ]; then mkdir -p qc; fi
cd $currdir

##################################################################################
# 1. Create dwi.mif in $datadir/dwi/preproc and put b0AP.mif b0PA.mif in $datadir/dwi/preproc/topup

if [ ! -d $datadir/dwi/preproc/topup ]; then mkdir -p $datadir/dwi/preproc/topup; fi

# If we have a session.tsv file, use this
if [ ! $sessionfile == No_sessionfile ]; then
    echo "Reading $sessionfile and use entries to create relevant files"
    {
	read
	while IFS= read -r line
	do
	    # check if the file/image has passed QC (qc_pass_fail = 4th column)
	    QCPass=`echo "$line" | awk '{ print $4 }'`

	    if [[ $QCPass == 1 || $QCPass == 0.5 ]]; then
		
		# Get file from column nbr 3
		file=`echo "$line" | awk '{ print $3 }'`
		filebase=`basename $file .nii`
		filedir=`dirname $file`

		#### Read flags in session.tsv file with corresponding column index
		## DKI AP data (dMRI_DKI = 6th column)
		dwiAP=`echo "$line" | awk '{ print $6 }'`
		if [ $dwiAP == 1 ]; then		    
		    if [ ! -f $datadir/dwi/preproc/dwiAP.mif ]; then 

				case $protocol in
					NEW) # We have NEW protocol and can use all our b0s
				 		echo "We have NEW protocol"
						mrconvert -json_import $datadir/$filedir/$filebase.json \
							-fslgrad $datadir/$filedir/$filebase.bvec $datadir/$filedir/$filebase.bval \
							$datadir/$filedir/$filebase.nii $datadir/dwi/preproc/dwiAP.mif
						;;
					ORIG) # We have ORIG protocol only use one b0
				 		echo "We have ORIG protocol"
						mrconvert -json_import $datadir/$filedir/$filebase.json \
							-fslgrad $datadir/$filedir/$filebase.bvec $datadir/$filedir/$filebase.bval \
							$datadir/$filedir/$filebase.nii $datadir/dwi/preproc/tmp_dwiAP.mif
						dwiextract -shells 1000,2000 $datadir/dwi/preproc/tmp_dwiAP.mif $datadir/dwi/preproc/tmp_dwiAP_b1000b2000.mif
						dwiextract -shells 0 $datadir/dwi/preproc/tmp_dwiAP.mif - | mrconvert -coord 3 0 -axes 0,1,2 - $datadir/dwi/preproc/tmp_dwiAP_b0.mif
						mrcat -axis 3 $datadir/dwi/preproc/tmp_dwiAP_b0.mif $datadir/dwi/preproc/tmp_dwiAP_b1000b2000.mif $datadir/dwi/preproc/dwiAP.mif
						rm $datadir/dwi/preproc/tmp_*
						;;
				esac

		    fi
		fi		
		## b0AP and b0PA data
		volb0AP=`echo "$line" | awk '{ print $8 }'` #(dMRI_vol_for_b0AP = 8th column)
		if [ ! $volb0AP == "-" ]; then
		    b0APvol=$volb0AP #Remember this to later!!
		    if [ ! -f $datadir/dwi/preproc/topup/b0AP.mif ]; then
			mrconvert $datadir/$filedir/$filebase.nii -json_import $datadir/$filedir/$filebase.json - | \
			    mrconvert -coord 3 $volb0AP -axes 0,1,2 - $datadir/dwi/preproc/topup/b0AP.mif
		    fi
		fi
		volb0PA=`echo "$line" | awk '{ print $9 }'` #(dMRI_vol_for_b0PA = 9th column)
		if [ ! $volb0PA == "-" ]; then
		    if [ ! -f $datadir/dwi/preproc/topup/b0PA.mif ]; then
			#Finn 2023-03-31: change to extract one volb0PA, which was not done in ORIG
			mrconvert $datadir/$filedir/$filebase.nii -json_import $datadir/$filedir/$filebase.json - | \
			    mrconvert -coord 3 $volb0PA -axes 0,1,2 - $datadir/dwi/preproc/topup/b0PA.mif
			    #ORIG mrconvert $datadir/$filedir/$filebase.nii -json_import $datadir/$filedir/$filebase.json $datadir/dwi/preproc/topup/b0PA.mif
		    fi
		fi
	    fi
	    
	done
    } < "$sessionfile"
else
    echo "No session.tsv file, using input/defaults"
    filedir=`dirname $dwi`
    filebase=`basename $dwi .nii`
    if [ ! -f $datadir/dwi/preproc/dwiAP.mif ]; then
	echo "Transferring $filedir/$filebase.nii into $datadir/dwi/preproc/dwiAP.mif"
	mrconvert $filedir/$filebase.nii \
		  -json_import $filedir/$filebase.json \
		  -fslgrad $filedir/$filebase.bvec $filedir/$filebase.bval  \
		  $datadir/dwi/preproc/dwiAP.mif
    fi
fi


##################################################################################
# 1b. Create dwi.mif $datadir/dwi/preproc and b0APPA.mif in $datadir/dwi/preproc/topup

cd $datadir/dwi/preproc

if [ ! -d topup ]; then mkdir topup; fi

# Create b0APPA.mif to go into TOPUP
if [ ! -f topup/b0APPA.mif ]; then
    if [ -f topup/b0AP.mif ] && [ -f topup/b0PA.mif ]; then
	echo "Creating b0APPA.mif from b0AP.mif and b0PA.mif"
	mrcat topup/b0AP.mif topup/b0PA.mif topup/b0APPA.mif
    else
	if [ -f topup/b0AP.mif ] && [ ! -f topup/b0PA.mif ]; then
	    echo "We only have b0AP.mif in /topup => do not have a fieldmap, so eddy will be run without a TOPUP fieldmap"
	else	
	    echo "No b0APPA.mif or pair of b0AP.mif and b0PA.mif are present to use with TOPUP
	          1. Do this by putting one good b0 from dir-AP_dwi and dir-PA_dwi into a file b0APPA.mif into $datadir/dwi/preproc/topup
			  2. The same b0 from dir-AP_dwi should be put 1st in the dir-AP_dwi dataset, as dwifslpreprocess will use the 1st b0 in dir-AP and replace the first b0 in b0APPA with
			  3. Run this script again.     
    	 	  "
	    exit;
	fi
    fi
fi

# Create dwi.mif to go into further processing. NOTE: b0APvol will be put first in dwi.mif
# This code snippet has been adapted from https://github.com/sotnir/NENAH-BIDS/blob/main/dMRI/preprocess.sh
if [ ! -f dwi.mif ]; then

    # If we can use topup (i.e. we have the file topup/b0APPA.mif) then we need to re-arrange in dwiAP
    if [ -f topup/b0APPA.mif ]; then
		# 1. extract higher shells and put in a joint file
		dwiextract -shells 1000,2000 dwiAP.mif tmp_dwiAP_b1000b2000.mif	
		# 2. Sort out b0s
		# a) extract the b0 that will be used for TOPUP by
		b0topup=$b0APvol;
		# b) and put in /topup/tmp_b0$dir.mif
		mrconvert -coord 3 $b0topup -axes 0,1,2 dwiAP.mif topup/tmp_b0AP.mif
		# c) and extract b0s from dwiAP.mif where the b0 for TOPUP will be placed first (by creating and an indexlist)
		indexlist=$b0topup;
		for index in `mrinfo -shell_indices dwiAP.mif | awk '{print $1}' | sed 's/\,/\ /g'`; do
			if [ ! $index == $b0topup ]; then
				indexlist=`echo $indexlist,$index`;
			fi
		done
		echo "Extracting b0-values in order $indexlist from dwiAP.mif, i.e. extracting volume $b0topup for TOPUP first";
		mrconvert -coord 3 $indexlist dwiAP.mif tmp_dwiAP_b0.mif
		
		# Put everything into file dwi.mif, with AP followed by PA volumes
		# FL 2021-12-20 - NOTE TOPUP and EDDY not working properly for dirPA, so only use dirAP to go into dwi.mif
		mrcat -axis 3 tmp_dwiAP_b0.mif tmp_dwiAP_b1000b2000.mif dwi.mif
		
		# clean-up
		rm tmp_dwi*.mif* tmp_b0AP.mif*
		
	else # We don't have possibility to use TOPUP, so dwiAP.mif as it is becoms dwi.mif
		mrconvert dwiAP.mif dwi.mif
    fi	
    
fi


cd $currdir


##################################################################################
# 2. Do PCA-denoising and Remove Gibbs Ringing Artifacts
cd $datadir/dwi/preproc

# Directory for QC files
if [ ! -d denoise ]; then mkdir denoise; fi

# Perform PCA-denosing
if [ ! -f dwi_den.mif ]; then
    echo Doing MP PCA-denosing with dwidenoise
    # PCA-denoising
    dwidenoise dwi.mif dwi_den.mif -noise denoise/dwi_noise.mif -nthreads $threads;
    # and calculate residuals
    mrcalc dwi.mif dwi_den.mif -subtract denoise/dwi_den_residuals.mif
    echo Check the residuals! Should not contain anatomical structure
fi

# Directory for QC files
if [ ! -d unring ]; then mkdir unring; fi

if [ ! -f dwi_den_unr.mif ]; then
    echo Remove Gibbs Ringing Artifacts with mrdegibbs
    # Gibbs 
    mrdegibbs -axes 0,1 dwi_den.mif dwi_den_unr.mif -nthreads $threads
    #calculate residuals
    mrcalc dwi_den.mif  dwi_den_unr.mif -subtract unring/dwi_den_unr_residuals.mif
    echo Check the residuals! Should not contain anatomical structure
fi

cd $currdir

##################################################################################
# 3. TOPUP and EDDY for Motion- and susceptibility distortion correction
# Do Topup and Eddy with dwifslpreproc and use topup/b0APPA.mif as SE-pair for TOPUP
#
cd $datadir/dwi/preproc

scratchdir=dwifslpreproc

if [ ! -f dwi_den_unr_eddy.mif ];then

	case $protocol in
		NEW) # We have NEW protocol and can use all our b0s
			echo "We have NEW protocol"    
			dwifslpreproc -se_epi topup/b0APPA.mif -rpe_header -align_seepi \
					-nocleanup \
					-scratch $scratchdir \
					-topup_options " --iout=field_mag_unwarped" \
					-eddy_options " --slm=linear --repol --mporder=8 --s2v_niter=10 --s2v_interp=trilinear --s2v_lambda=1 --estimate_move_by_susceptibility --mbs_niter=20 --mbs_ksp=10 --mbs_lambda=10 " \
					-eddyqc_all eddy \
					-nthreads $threads \
					dwi_den_unr.mif \
					dwi_den_unr_eddy.mif;
					;;
		ORIG) # We don't have b0APPA and cannot run TOPUP, and instead EDDY only with motion- and EC-correction
			TRT=`mrinfo -property TotalReadoutTime dwi_den_unr.mif`
			PEdir=`mrinfo -property PhaseEncodingDirection dwi_den_unr.mif`
			dwifslpreproc -rpe_none -pe_dir $PEdir -readout_time $TRT \
					-nocleanup \
					-scratch $scratchdir \
					-eddy_options " --slm=linear --repol --mporder=8 --s2v_niter=10 --s2v_interp=trilinear --s2v_lambda=1 --mbs_niter=20 --mbs_ksp=10 --mbs_lambda=10 " \
					-eddyqc_all eddy \
					-nthreads $threads \
					dwi_den_unr.mif \
					dwi_den_unr_eddy.mif;
					;;
	esac;
# Now cleanup by transferring relevant files to topup folder and deleting scratch folder
    if [ -d eddy/quad ]; then 
		mv eddy/quad ../../qc/. 
	fi
    cp $scratchdir/command.txt $scratchdir/log.txt $scratchdir/eddy_*.txt $scratchdir/applytopup_*.txt $scratchdir/slspec.txt eddy/.
    mv $scratchdir/field_* $scratchdir/topup_* topup/.
    rm -rf $scratchdir;
fi

cd $currdir

##################################################################################
# 3a. Mask generation, (N4 biasfield correction), b0-normalisation and meanb0/1000/2000 generation

cd $datadir/dwi/preproc

echo "Pre-processing with mask generation N4 biasfield correction"

# point to right filebase
dwi=dwi_den_unr_eddy

# Create mask and dilate (to ensure usage with ACT)
if [ ! -f mask.mif ]; then
    dwiextract -bzero $dwi.mif - | mrmath -force -axis 3 - mean meanb0tmp.nii
    bet meanb0tmp.nii meanb0tmp_brain.nii -m -f 0.25 -R #-f 0.25 from dHCP dMRI pipeline
    # Check result
    # echo mrview meanb0tmp.nii -roi.load meanb0tmp_brain_mask.nii -roi.opacity 0.5 -mode 2
    mrconvert meanb0tmp_brain_mask.nii mask.mif
    #rm meanb0tmp*
fi

## Do B1-correction. Use ANTs N4
## Finn 2023-04-13: Not working!! Cannot figure out why. This is the internal error message
#dwibiascorrect: [ERROR] N4BiasFieldCorrection -d 3 -i mean_bzero.nii -w mask.nii -o [corrected.nii,init_bias.nii] -s 4 -b [100,3] -c [1000,0.0] (ants.py:75)
#dwibiascorrect: [ERROR] Information from failed command:
#dwibiascorrect:
#                ERROR:  Invalid flag provided nt
#                ERROR:  Invalid command line flags found! Aborting execution.
#
## Uncomment below if to use again
if [ ! -f  ${dwi}_N4.mif ]; then
    if [ ! -d N4 ]; then mkdir N4; fi
    # Add number of threads used
    dwibiascorrect ants -mask mask.mif -bias N4/bias.mif -nthreads $threads $dwi.mif ${dwi}_N4.mif
fi
# update $dwi
dwi=dwi_den_unr_eddy_N4

dwipreproclast=${dwi}.mif

cd $currdir

##################################################################################
# 3b. b0-normalisation and meanb0/1000/2000 generation

cd $datadir/dwi

echo "Performing b0-normalisation and meanb0, meanb1000 and meanb2000 generation"

# Create symbolic link to last file in /preproc and copy mask.mif to $datadir/dwi
if [ ! -f sub-${sID}_ses-${ssID}_dir-AP_desc-preproc_dwi.mif ]; then 
	mrconvert preproc/$dwipreproclast sub-${sID}_ses-${ssID}_dir-AP_desc-preproc_dwi.mif
fi
if [ ! -f sub-${sID}_ses-${ssID}_space-dwi_mask.mif ]; then 
	mrconvert preproc/mask.mif sub-${sID}_ses-${ssID}_space-dwi_mask.mif
fi

dwisuffix=sub-${sID}_ses-${ssID}_dir-AP_desc-preproc
mask=sub-${sID}_ses-${ssID}_space-dwi_mask

# B0-normalisation
if [ ! -f ${dwisuffix}-inorm_dwi.mif ]; then
    dwinormalise individual ${dwisuffix}_dwi.mif $mask.mif ${dwisuffix}-inorm_dwi.mif
fi

# Update dwisuffix
dwisuffix=sub-${sID}_ses-${ssID}_dir-AP_desc-preproc-inorm

# Extract mean b0, b1000 and b2000
bvalues=`mrinfo -shell_bvalues ${dwisuffix}_dwi.mif`
for bvalue in $bvalues; do
    bfile=meanb$bvalue
    if [ ! -f ${dwisuffix}_$bfile.mif ]; then
		dwiextract -shells $bvalue ${dwisuffix}_dwi.mif - |  mrmath -force -axis 3 - mean ${dwisuffix}_$bfile.mif
		mrcalc -force ${dwisuffix}_$bfile.mif $mask.mif -mul ${dwisuffix}-brain_$bfile.mif
		echo "Visually check the ${dwisuffix}-brain_$bfile.mif"
		echo mrview ${dwisuffix}-brain_$bfile.mif -mode 2
	fi
done

# Finally, make NIfTI-versions of ${dwi}_inorm.mif and mask.mif
if [ ! -f ${dwisuffix}_dwi.nii ]; then
	mrconvert -json_export ${dwisuffix}_dwi.json -export_grad_fsl ${dwisuffix}_dwi.bvec ${dwisuffix}_dwi.bval ${dwisuffix}_dwi.mif ${dwisuffix}_dwi.nii
fi
if [ ! -f $mask.nii ]; then
	mrconvert -json_export $mask.json $mask.mif $mask.nii
fi

cd $currdir

##################################################################################
