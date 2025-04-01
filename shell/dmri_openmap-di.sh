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
if [ ! -f $dwi ]; then dwi="No_image"; echo "No_image - quitting"; exit 1; fi
if [ ! -f $mask ]; then mask="No_image"; echo "No_image - quitting"; exit 1; fi

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

# Input files for DTI parametric maps FA, MD, AD and RD
fafile=`ls $dti_folder/${dwibase}_dwi_FA.nii`
if [ -z "$fafile" ]; then
  echo "FA file not found"
  exit 1
fi
mdfile=`ls $dti_folder/${dwibase}_dwi_MD.nii`
if [ -z "$mdfile" ]; then
  echo "MD file not found"
  exit 1
fi
adfile=`ls $dti_folder/${dwibase}_dwi_AD.nii`
if [ -z "$adfile" ]; then
  echo "AD file not found"
  exit 1
fi
rdfile=`ls $dti_folder/${dwibase}_dwi_RD.nii`
if [ -z "$rdfile" ]; then
  echo "RD file not found"
  exit 1
fi

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
      fa_stats=$(mrstats -mask "$temp_mask" "$fafile" | awk 'NR==2 {print $4, $6}' | sed 's/\ /\t/')
      md_stats=$(mrstats -mask "$temp_mask" "$mdfile" | awk 'NR==2 {print $4, $6}' | sed 's/\ /\t/')
      ad_stats=$(mrstats -mask "$temp_mask" "$adfile" | awk 'NR==2 {print $4, $6}' | sed 's/\ /\t/')
      rd_stats=$(mrstats -mask "$temp_mask" "$rdfile" | awk 'NR==2 {print $4, $6}' | sed 's/\ /\t/')

      # Append the stats to the TSV file
      echo -e "$label\t$region\t$fa_stats\t$md_stats\t$ad_stats\t$rd_stats" >> "$output_tsv"

      # Remove the temporary mask
      rm -f "$temp_mask"
    fi
  done < <(tail -n +2 "$lut_file")  # Skip the header of the LUT file
else
  echo "DTI stats already calculated for this subject and saved in $output_tsv"
fi

if [ ! -f $output_json ]; then
  echo "Converting DTI stats to JSON format..."
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

# Add file names used for mrstats
file_names = {
    "FA": "$fafile",
    "MD": "$mdfile",
    "AD": "$adfile",
    "RD": "$rdfile"
}

# Convert to JSON
json_output = {
    "data": df.to_dict(orient="records"),
    "units": units,
    "file_names": file_names
}

# Save JSON to file
with open("$output_json", "w") as f:
    json.dump(json_output, f, indent=4)
EOF

echo "DTI stats saved to $output_tsv and $output_json"
fi


# 3.2. DKI
dki_folder=$datadir/dki
output_tsv_dki="$dki_folder/${dwibase}_dki_stats.tsv"
output_json_dki="$dki_folder/${dwibase}_dki_stats.json"

# DKI parametric maps MK, AK and RK
mkfile=`ls $dki_folder/${dwibase}_dwi_mk.nii`
if [ -z "$mkfile" ]; then
  echo "MK file not found"
  exit 1
fi
akfile=`ls $dki_folder/${dwibase}_dwi_ak.nii`
if [ -z "$akfile" ]; then
  echo "AK file not found"
  exit 1
fi
rkfile=`ls $dki_folder/${dwibase}_dwi_rk.nii`
if [ -z "$rkfile" ]; then
  echo "RK file not found"
  exit 1
fi

if [ ! -f $output_tsv_dki ]; then
  echo "Calculating DKI stats..."
  
  # Initialize the TSV file with a header
  echo -e "Label\tRegion\tMK_mean\tMK_std\tAK_mean\tAK_std\tRK_mean\tRK_std" > "$output_tsv_dki"

  # Loop through each label in the LUT
  while IFS=$'\t' read -r label region _; do
    # Skip the header or invalid lines
    if [[ "$label" =~ ^[0-9]+$ ]]; then
      # Create a temporary binary mask for the current label
      temp_mask="$dki_folder/temp_mask_label_${label}.mif"
      mrcalc "$segmentation_file" "$label" -eq "$temp_mask" -quiet

      # Calculate stats for each DKI map using the temporary mask
      echo "Calculating DKI stats for label $label ($region)"
      mk_stats=$(mrstats -mask "$temp_mask" "$mkfile" | awk 'NR==2 {print $4, $6}' | sed 's/\ /\t/')
      ak_stats=$(mrstats -mask "$temp_mask" "$akfile" | awk 'NR==2 {print $4, $6}' | sed 's/\ /\t/')
      rk_stats=$(mrstats -mask "$temp_mask" "$rkfile" | awk 'NR==2 {print $4, $6}' | sed 's/\ /\t/')

      # Append the stats to the TSV file
      echo -e "$label\t$region\t$mk_stats\t$ak_stats\t$rk_stats" >> "$output_tsv_dki"

      # Remove the temporary mask
      rm -f "$temp_mask"
    fi
  done < <(tail -n +2 "$lut_file")  # Skip the header of the LUT file
else
  echo "DKI stats already calculated for this subject and saved in $output_tsv_dki"
fi
# Convert the TSV to JSON format
if [ ! -f $output_json_dki ]; then
  echo "Converting DKI stats to JSON format..."
  # Convert the TSV to JSON format
  python3 - <<EOF
import pandas as pd
import json

# Load the TSV file
df = pd.read_csv("$output_tsv_dki", sep="\t")

# Add units for each map
units = {
    "MK": "unitless",
    "AK": "unitless",
    "RK": "unitless"
}

# Add file names used for mrstats
file_names = {
    "MK": "$mkfile",
    "AK": "$akfile",
    "RK": "$rkfile"
}

# Convert to JSON
json_output = {
    "data": df.to_dict(orient="records"),
    "units": units,
    "file_names": file_names
}

# Save JSON to file
with open("$output_json_dki", "w") as f:
    json.dump(json_output, f, indent=4)
EOF
  echo "DKI stats saved to $output_tsv_dki and $output_json_dki"
else
  echo "DKI stats already calculated for this subject and saved in $output_json_dki"
fi


# 3.3. NODDI
noddi_folder=$datadir/noddi
output_tsv_noddi="$noddi_folder/${dwibase}_noddi_stats.tsv"
output_json_noddi="$noddi_folder/${dwibase}_noddi_stats.json"

# NODDI parametric maps NDI, ODI and FWF
ndifile=`ls $noddi_folder/${dwibase}_*ICVF.nii`
if [ -z "$ndifile" ]; then
  echo "NODDI file not found for label $label"
  exit 1
fi  
odifile=`ls $noddi_folder/${dwibase}_*OD.nii`
if [ -z "$odifile" ]; then
  echo "ODI file not found for label $label"
  exit 1
fi  
fwffile=`ls $noddi_folder/${dwibase}_*ISOVF.nii`
if [ -z "$fwffile" ]; then
  echo "FWF file not found for label $label"
  exit 1
fi  

if [ ! -f $output_tsv_noddi ]; then
  echo "Calculating NODDI stats..."
  
  # Initialize the TSV file with a header
  echo -e "Label\tRegion\tNDI_mean\tNDI_std\tODI_mean\tODI_std\tFWF_mean\tFWF_std" > "$output_tsv_noddi"

  # Loop through each label in the LUT
  while IFS=$'\t' read -r label region _; do
    # Skip the header or invalid lines
    if [[ "$label" =~ ^[0-9]+$ ]]; then
      # Create a temporary binary mask for the current label
      temp_mask="$noddi_folder/temp_mask_label_${label}.mif"
      mrcalc "$segmentation_file" "$label" -eq "$temp_mask" -quiet

      # Calculate stats for each NODDI map using the temporary mask
      echo "Calculating NODDI stats for label $label ($region)"
      ndi_stats=$(mrstats -mask "$temp_mask" "$ndifile" | awk 'NR==2 {print $4, $6}' | sed 's/\ /\t/')
      odi_stats=$(mrstats -mask "$temp_mask" "$odifile" | awk 'NR==2 {print $4, $6}' | sed 's/\ /\t/')
      fwf_stats=$(mrstats -mask "$temp_mask" "$fwffile" | awk 'NR==2 {print $4, $6}' | sed 's/\ /\t/')

      # Append the stats to the TSV file
      echo -e "$label\t$region\t$ndi_stats\t$odi_stats\t$fwf_stats" >> "$output_tsv_noddi"

      # Remove the temporary mask
      rm -f "$temp_mask"
    fi
  done < <(tail -n +2 "$lut_file")  # Skip the header of the LUT file
else
  echo "NODDI stats already calculated for this subject and saved in $output_tsv_noddi"
fi

if [ ! -f $output_json_noddi ]; then
  echo "Converting NODDI stats to JSON format..."
  # Convert the TSV to JSON format
  python3 - <<EOF
import pandas as pd
import json

# Load the TSV file
df = pd.read_csv("$output_tsv_noddi", sep="\t")

# Add units for each map
units = {
    "NDI": "unitless",
    "ODI": "unitless",
    "FWF": "unitless"
}

# Add file names used for mrstats
file_names = {
    "NDI": "$ndifile",
    "ODI": "$odifile",
    "FWF": "$fwffile"
}

# Convert to JSON
json_output = {
    "data": df.to_dict(orient="records"),
    "units": units,
    "file_names": file_names
}

# Save JSON to file
with open("$output_json_noddi", "w") as f:
    json.dump(json_output, f, indent=4)
EOF

  echo "NODDI stats saved to $output_tsv_noddi and $output_json_noddi"

else
  echo "NODDI stats already calculated for this subject and saved in $output_json_noddi"
fi

