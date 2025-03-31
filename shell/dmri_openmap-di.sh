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
  -d / -data-dir         Derivatives folder (default: \$studydir/derivatives/dMRI/sub-sID/ses-ssID/dwi)
  -dwi                  Preprocessed and intensity normalised dMRI in .mif format (default: \$datadir/sub-sID_ses-ssID_dir-AP_desc-preproc-inorm_dwi.mif)
  -mask                 Brain mask in .mif format (default: \$derivatives/\$subjectdata/sub-sID_ses-ssID_space-dwi_mask.mif)
  -openmap_path         Path to OpenMap-Di installation (default: $HOME/software/OpenMAP-Di)  
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
openmap_path=$HOME/software/OpenMAP-Di
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
	  -d|-data-dir)  shift; datadir=$1; ;;
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
if [ ! -f $dwi ]; then dwi="No_image"; echo "No_image - quitting"; break; fi
if [ ! -f $mask ]; then mask="No_image"; echo "No_image - quitting"; break; fi

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

openmap_folder=$datadir/OpenMAP-Di # also output folder
dwibase=`basename $dwi _dwi.mif`

if [ ! -d $openmap_folder ]; then mkdir -p $openmap_folder; fi

# Convert 3axis-DWI to _0000.nii.gz
if [ ! -f $openmap_folder/${dwibase}_0000.nii.gz ]; then
  isodwi=$datadir/sub-${sID}_ses-${ssID}_dir-AP_desc-preproc-inorm-brain_meanb1000.mif
  mrconvert $isodwi $openmap_folder/${dwibase}_0000.nii.gz
fi
# Convert b0 to _0001.nii.gz
if [ ! -f $openmap_folder/${dwibase}_0001.nii.gz ]; then
  b0=$datadir/sub-${sID}_ses-${ssID}_dir-AP_desc-preproc-inorm-brain_meanb0.mif
  mrconvert $b0 $openmap_folder/${dwibase}_0001.nii.gz
fi
# Convert to RGB as: R => _0002.nii.gz G => _0003.nii.gz; B => _0004.nii.gz
rgb=$datadir/dti/sub-${sID}_ses-${ssID}_dir-AP_desc-preproc-inorm_dwi_RGB.nii
for idx in 0 1 2; do
  index=$((idx + 2))
  if [ ! -f $openmap_folder/${dwibase}_000${index}.nii.gz ]; then
    mrconvert -coord 3 $idx $rgb - | mrcalc - -abs $openmap_folder/${dwibase}_000${index}.nii.gz
  fi
done

##################################################################################
# 2. Run OpenMap-Di on subject

if [ ! -f $openmap_folder/${dwibase}_space-dwi_seg-JHU-MNI_dseg.nii.gz ]; then
  echo "Running OpenMAP-Di on this subject"
  python $openmap_path/parcellate_neonatal_brain.py  -i $openmap_folder -o $openmap_folder -m $openmap_path/nnUNetTrainerNoMirroring__nnUNetPlans__3d_fullres -device $device
  # Now change the name so that it is BIDS compatible 
  #   sub-<subID>_ses-<sesID>_space-<space>_seg-<seg>_dseg.nii.gz
  mv $openmap_folder/${dwibase}.nii.gz $openmap_folder/${dwibase}_space-dwi_seg-JHU-MNI_dseg.nii.gz
else
  echo "OpenMAP-Di already run on this subject"
fi

##################################################################################
# 3. Evalute DTI, DKI and NODDI maps on the OpenMap-Di segmentation

# 3.1. DTI
dti_folder=$datadir/dti
# Define the segmentation file and LUT
segmentation_file="$openmap_folder/${dwibase}_space-dwi_seg-JHU-MNI_dseg.nii.gz"
lut_file="$openmap_path/neonate_multilevel_lookup_table_170labels_v2.txt"

# Define the output files
output_tsv="$dti_folder/${dwibase}_dti_stats.tsv"
output_json="$dti_folder/${dwibase}_dti_stats.json"

if [ ! -f $output_tsv ]; then 
  echo "Calculating DTI stats..."
# Initialize the TSV file with a header
echo -e "Label\tRegion\tFA_mean\tFA_std\tMD_mean\tMD_std\tAD_mean\tAD_std\tRD_mean\tRD_std" > "$output_tsv"

# Loop through each label in the LUT
while IFS=$'\t' read -r label region _; do
  # Skip the header or invalid lines
  if [[ "$label" =~ ^[0-9]+$ ]]; then
    # Create a temporary binary mask for the current label
    temp_mask="$dti_folder/temp_mask_label_${label}.mif"
    mrcalc "$segmentation_file" "$label" -eq "$temp_mask" -quiet

    # Calculate stats for each DTI map using the temporary mask
    echo "Calculating DTI stats for label $label ($region)"
    fa_stats=$(mrstats -mask "$temp_mask" "$dti_folder/${dwibase}_dwi_FA.nii" | awk 'NR==2 {print $4, $6}')
    md_stats=$(mrstats -mask "$temp_mask" "$dti_folder/${dwibase}_dwi_MD.nii" | awk 'NR==2 {print $4, $6}')
    ad_stats=$(mrstats -mask "$temp_mask" "$dti_folder/${dwibase}_dwi_AD.nii" | awk 'NR==2 {print $4, $6}')
    rd_stats=$(mrstats -mask "$temp_mask" "$dti_folder/${dwibase}_dwi_RD.nii" | awk 'NR==2 {print $4, $6}')

    # Append the stats to the TSV file
    echo -e "$label\t$region\t$fa_stats\t$md_stats\t$ad_stats\t$rd_stats" >> "$output_tsv"

    # Remove the temporary mask
    rm -f "$temp_mask"
  fi
done < <(tail -n +2 "$lut_file")  # Skip the header of the LUT file

# Convert the TSV to JSON format
python3 - <<EOF
import pandas as pd
import json

# Load the TSV file
df = pd.read_csv("$output_tsv", sep="\t")

# Add units for each map
units = {
    "FA": "unitless",
    "MD": "mm^2/s",
    "AD": "mm^2/s",
    "RD": "mm^2/s"
}

# Convert to JSON
json_output = {
    "data": df.to_dict(orient="records"),
    "units": units
}

# Save JSON to file
with open("$output_json", "w") as f:
    json.dump(json_output, f, indent=4)
EOF

echo "DTI stats saved to $output_tsv and $output_json"

else
  echo "DTI stats already calculated for this subject"
fi
