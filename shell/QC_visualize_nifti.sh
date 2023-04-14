#!/bin/bash
# KPUM NODDI
# Script for QC eye-balling of images in a nifti folder
# Creates (unless already present) a session_QC.tsv file for QC purposes
#

################ SUB-FUNCTIONS ################

usage()
{
  base=$(basename "$0")
  echo "usage: $base subjectID sessionID [options]
Visualize NIfTIs in BIDS rawdata folder 
Arguments:
  sID                   Subject ID (e.g. 002) 
  ssID                  Session ID (e.g. MR2)
Options:
  -f / -tsv_file        File with scans to visualise (default: $studydir/nifti/sub-\$sID/ses-\$ssID/sub-\$sID/ses-\$ssID_sourcedata2nifti.tsv)
  -h / -help / --help   Print usage.
"
  exit;
}

dMRI_rawdata_visualisation ()
{
    # get input file
    file=$1;

    filebase=`basename $file .nii`
    filedir=`dirname $file`

    # check if SBRef file
    issbref=`echo $file | grep sbref`

    # if sbref file, then just visualise this
    if [[ $issbref ]]; then
	mrview $file -mode 2 
    else #is dwi file
	# Launch viewer and load all images
	mrconvert -quiet -fslgrad $filedir/$filebase.bvec $filedir/$filebase.bval $file tmp.mif
	shell_bvalues=`mrinfo -shell_bvalues tmp.mif`;
	shell_nbs=`mrinfo -shell_sizes tmp.mif`;
	echo b-values $shell_bvalues with dMRI-volumes $shell_nbs
	for shell in $shell_bvalues; do
	    echo Inspecting shell with b-value=$shell
	    if [ $shell == 0 ]; then echo b0 have this volume indices; mrinfo -shell_indices tmp.mif | awk '{print $1}'; fi
	    dwiextract -quiet -shell $shell tmp.mif - | mrview - -mode 2 -colourmap 1
	done
	rm tmp.mif
    fi
}

################ ARGUMENTS ################

[ $# -ge 2 ] || { usage; }
command=$@
sID=$1
ssID=$2
shift; shift

codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
studydir=$PWD 
niftidir=$studydir/nifti
tsvfile=$niftidir/sub-$sID/ses-$ssID/sub-${sID}_ses-${ssID}_sourcedata2nifti.tsv

# Read arguments
while [ $# -gt 0 ]; do
    case "$1" in
	-f|-tsv_file)  shift; tsvfile=$1; ;;
	-h|-help|--help) usage; ;;
	-*) echo "$0: Unrecognized option $1" >&2; usage; ;;
	*) break ;;
    esac
    shift
done

################ START ################

# Go to rawdata dir
cd $niftidir/sub-$sID/ses-$ssID

# Create $niftidir/sub-$sID/ses-$ssID/session_QC.tsv file is not present
if [ ! -f session_QC.tsv ]; then
    {
	echo "Creating session_QC.tsv file from $tsvfile"
	echo -e "participant_id\tsession_id\tfilename\tqc_pass_fail\tqc_signature\tdMRI_DKI\tdMRI_DTI\tdMRI_vol_for_b0AP\tdMRI_vol_for_b0PA" > session_QC.tsv

	read;
	while IFS= read -r line
	do
	    file=`echo "$line" | awk '{ print $2 }'`
	    echo -e "sub-$sID\tses-$ssID\t$file\t0/1\tFL/KA\t-\t-\t-\t-" >> session_QC.tsv
	done
    } < "$tsvfile"
fi 

# Eye-ball data in session.tsv 
echo "QC eye-balling of BIDS rawdata given by session_QC.tsv file"
# Read input file line by line, but skip first line
{
    read;
    counter=2; #Keeps track of line number to display on I/O to make it easier to detect corresponding line in session_QC.tsv file
    while IFS= read -r line
    do
	file=`echo "$line" | awk '{ print $3 }'`
	filedir=`dirname $file`
	echo $counter $file
	if [ $filedir == "dwi" ]; then
	    dMRI_rawdata_visualisation $file;
	else
	    mrview $file -mode 2 -colourmap 1
	fi
        let counter++
    done
} < session_QC.tsv

cd $studydir
