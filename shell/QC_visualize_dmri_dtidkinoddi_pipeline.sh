#!/bin/bash
# KPUM NODDI
# Script for QC eye-balling of output generated in dmri_dtidkinoddi_pipeline
# Creates $datadir/sub-$sID_ses-$ssID_pipeline_QC.tsv for book-keeping
#

################ SUB-FUNCTIONS ################

usage()
{
  base=$(basename "$0")
  echo "usage: $base sID ssID studydir derivatives [options]
Visualize selected output in dmri_dtidkinoddi_pipeline for QC evaluation
Creates \$datadir/sub-\$sID_ses-\$ssID_pipeline_QC.tsv for QC book-keeping

Arguments:
  sID                   Subject ID (e.g. 002) 
  ssID                  Session ID (e.g. MR2)
  studydir              Studydir with full path (e.g. \$PWD or /mnt/e/Finn/KPUM_NODDI/Data)
  derivatives			Derivatives folder in \$studydir (e.g. derivatives/dMRI_op)				
Options:
  -h / -help / --help   Print usage.
"
  exit;
}

dMRI_visualisation ()
{
    # get input file
    file=$1;
	shell_bvalues=`mrinfo -shell_bvalues $file`;
	shell_nbs=`mrinfo -shell_sizes $file`;
	echo b-values $shell_bvalues with dMRI-volumes $shell_nbs
	for shell in $shell_bvalues; do
	    echo Inspecting shell with b-value=$shell
	    dwiextract -quiet -shell $shell $file - | mrview - -mode 2 -colourmap 1
	done
}

################ ARGUMENTS ################

[ $# -ge 4 ] || { usage; }
command=$@
sID=$1
ssID=$2
studydir=$3
derivatives=$4
shift; shift; shift; shift

datadir=$studydir/$derivatives/sub-$sID/ses-$ssID

codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
scriptname=`basename $0 .sh`

# Read arguments
while [ $# -gt 0 ]; do
    case "$1" in
	-h|-help|--help) usage; ;;
	-*) echo "$0: Unrecognized option $1" >&2; usage; ;;
	*) break ;;
    esac
    shift
done

echo "QC of dmri_dtidkinoddi_pipeline
----------------------------
Subject:       	$sID 
Session:        $ssID
Studydir:		$studydir
Derivatives: 	$derivatives
DataDirectory:	$datadir

Codedir:	$codedir
$BASH_SOURCE   	$command
----------------------------"
echo 

################ START ################


# Create $datadir/pipeline_QC.tsv file is not present
cd $datadir
if [ ! -f sub-${sID}_ses-${ssID}_pipeline_QC.tsv ]; then
	echo "Creating $datadir/sub-${sID}_ses-${ssID}_pipeline_QC.tsv for QC according to $BASH_SOURCE"
	echo -e "participant_id\tsession_id\tqc_signature\tqc_PREPROC_pass_fail\tqc_PREPROC_comment\tqc_DTI_pass_fail\tqc_DTI_comment\tqc_DKI_pass_fail\tqc_DKI_comment\tqc_NODDI_pass_fail\tqc_NODDI_comment\tqc_OPENMAP-DI_pass_fail\tqc_OPENMAP-DI_comment\tqc_REGISTRATION_pass_fail\tqc_REGISTRATION_comment\tqc_TRACTOGRAPHY_pass_fail\tqc_TRACTOGRAPHY_comment" > sub-${sID}_ses-${ssID}_pipeline_QC.tsv
	echo -e "sub-$sID\tses-$ssID\tFL/KA\t0/1\t\t0/1\t\t0/1\t\t0/1\t\t0/1\t\t0/1\t\t0/1\t\t0/1\t" >> sub-${sID}_ses-${ssID}_pipeline_QC.tsv
fi 
cd $studydir

#######################################
# Preprocess
echo "############## QC of Process: Preprocess
"
cd $datadir/dwi/preproc

# MP PCA-denosing with dwidenoise
echo QC of MP PCA-denosing with dwidenoise
echo Check the residuals! Should not contain anatomical structure in brain parenchyma
mrview denoise/dwi_den_residuals.mif -mode 2
echo

# Gibbs Ringing Artifacts removal with mrdegibbs
echo QC of Gibbs Ringing Artifacts removal with mrdegibbs
echo Check the residuals! Should not contain anatomical structure brain parenchyma
mrview unring/dwi_den_unr_residuals.mif -mode 2
echo

#  EDDY (ORIG protocol) or TOPUP+EDDY (NEW protocol) 
dwi=dwi_den_unr_eddy.mif 
echo "QC of EDDY (ORIG protocol) or TOPUP+EDDY (NEW protocol)"
echo "Check corrected dMRI, shell by shell, for residual motion, signal dropout, (excessive) image distortions"
dMRI_visualisation $dwi;
echo

# POSSIBLY INCLUDE SQUAD HERE

# Brain Mask (NOTE - dilated to ensure usage with ACT - Can be a problem for JHU-registration)
dwi=dwi_den_unr_eddy.mif 
echo "QC of BET Brain Mask (dilated to ensure usage with ACT - NOTE can be a problem for the JHU-registration)"
echo Check the so that brain mask is covering the whole brain but not excessively extends into the extra-axial tissue
echo Visualisation of Brain Mask as an ROI-overlay on meanb0
dwiextract -quiet $dwi - -bzero | mrmath -quiet - mean - -axis 3 | mrview - -roi.load mask.mif -roi.opacity 0.5 -mode 2
echo

# Final output (N4-biasfield corrected and B0-intensity normalised)
cd $datadir/dwi
dwibase=sub-${sID}_ses-${ssID}_dir-AP_desc-preproc-inorm-brain
echo "QC of final preprocessing output (N4-biasfield corrected and B0-intensity normalised)"
for bvalue in b0 b1000 b2000; do
	echo "Visualization of skull-stripped mean$bvalue"
	mrview ${dwibase}_mean$bvalue.mif -mode 2
done
echo

cd $studydir
#######################################


#######################################
# DTI and DKI
echo "############## QC of Process: DTI and DKI
"
cd $datadir/dwi/dti
dwibase=sub-${sID}_ses-${ssID}_dir-AP_desc-preproc-inorm_dwi
echo "QC of generated DTI maps (FA, MD, AD, RD, RGB, Trace)"
for map in FA MD AD RD RGB Trace; do
	echo "Visualization of DTI map: $map"
	mrview ${dwibase}_$map.nii -mode 2
done
echo

cd $datadir/dwi/dki
dwibase=sub-${sID}_ses-${ssID}_dir-AP_desc-preproc-inorm_dwi
echo "QC of generated DKI maps (AK, RK, MK)"
for map in ak rk mk; do
	echo "Visualization of DKI map: $map"
	mrview ${dwibase}_$map.nii -mode 2
done
echo

cd $studydir

#######################################


#######################################
# NODDI
echo "############## QC of Process: NODDI 
"
cd $datadir/dwi/noddi
dwibase=sub-${sID}_ses-${ssID}_dir-AP_desc-preproc-inorm_recon-NODDI-dPar
echo "QC of generated NODDI maps (ICVF, ISOVF, OD)"
for map in ICVF ISOVF OD; do
	echo "Visualization of NODDI map: $map"
	mrview ${dwibase}-*_$map.nii -mode 2
done
echo

cd $studydir

#######################################


#######################################
# OpenMAP-Di segmentation 
echo "############## QC of Process: OpenMAP-Di
"
cd $datadir/dwi/OpenMAP-Di

dwibase=sub-${sID}_ses-${ssID}_dir-AP_desc-preproc-inorm
b0=${dwibase}_0000.nii.gz
openmap_seg=${dwibase}_space-dwi_seg-JHU-MNI_dseg.nii.gz

echo "QC of OpenMAP-Di segmentation"
echo "OpenMAP-Di segmentation is overlaid on the b0 - check for consistency and misclassified voxels"
mrview $b0 -overlay.load $openmap_seg -overlay.opacity 0.5 -overlay.interpolation 0 -mode 2

cd $studydir

#######################################


#######################################
# Registration 

#######################################


#######################################
# Tractography 

#######################################