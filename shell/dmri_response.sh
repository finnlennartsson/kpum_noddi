#!/bin/bash
# KPUM NODDI
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base sID ssID studydir [options]
Estimation of response function

Arguments:
  sID                           Subject ID (e.g. 001) 
  ssID                          Session ID (e.g. MR2)
  studydir                      Studydir with full path (e.g. \$PWD or /mnt/e/Finn/KPUM_NODDI/Data)
Options:
  -dwi				dMRI preprocessed data in MRtrix .mif format (default: \$datadir/dwi/sub-sID_ses-ssID_dir-AP_desc-preproc-inorm_dwi.mif
  -mask				Brain mask in .mif format (default: \$datadir/dwi/sub-sID_ses-ssID_space-dwi_mask.mif)
  -response			Response function (tournier or dhollander) (default: dhollander)
  -threads                      Number of CPU cores/threads to run commands in (default: 4)
  -d / -data-dir  <directory>   The directory used to output the preprocessed files (default: \$studydir/derivatives/dMRI/sub-sID/ses-ssID)
  -h / -help / --help           Print usage.
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
dwi=""; mask=""  # See below - Defaults cont'd
response=dhollander
threads=4

# check whether the different tools are set and load parameters
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

while [ $# -gt 0 ]; do
    case "$1" in
	-dwi) shift; dwi=$1; ;;
	-mask) shift; mask=$1; ;;
	-response) shift; response=$1; ;;
	-threads) shift; threads=$1; ;;
	-d|-data-dir)  shift; datadir=$1; ;;
	-h|-help|--help) usage; ;;
	-*) echo "$0: Unrecognized option $1" >&2; usage; ;;
	*) break ;;
    esac
    shift
done

# Defaults cont'd
if [ $dwi=="" ]; then
  dwi=$datadir/dwi/sub-${sID}_ses-${ssID}_dir-AP_desc-preproc-inorm_dwi.mif
fi
if [ $mask=="" ]; then
  mask=$datadir/dwi/sub-${sID}_ses-${ssID}_space-dwi_mask.mif
fi

# Check if images exist, else put in No_image
if [ ! -f $dwi ]; then dwi="No_image"; fi
if [ ! -f $mask ]; then dwi="No_image"; fi

echo "Response estimation of dMRI 
Subject:        $sID 
Session:        $ssID
Studydir:       $studydir
DWI (AP):       $dwi
Mask:           $mask
Response:       $response
Data directory: $datadir
Threads:        $threads

Codedir:        $codedir
$BASH_SOURCE   	$command
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
# 0. Copy to files to datadir (incl .json if present at original location)

for file in $dwi $mask; do
    origdir=`dirname $file`
    filebase=`basename $file .mif`
    outdir=$datadir/dwi
    
    if [ ! -d $outdir ]; then mkdir -p $outdir; fi
    
    if [ ! -f $outdir/$filebase.mif ];then
        cp $file $outdir/.
	    if [ -f $origdir/$filebase.json ];then
	        cp $origdir/$filebase.json $outdir/.
	    fi
    fi

done

# Update variables to point at corresponding filebases in $datadir
dwi=`basename $dwi .mif`
mask=`basename $mask .mif`

##################################################################################
## Make Response Function estimation and then CSD calcuation

cd $datadir/dwi

filebase_meanb0_brain=`echo $dwi | sed 's/\-inorm/\-inorm\-brain/g' | sed 's/\_dwi/\_meanb0/g' `

## ---- Tournier ----
if [[ $response = tournier ]]; then

    # response fcn
    responsedir=response #Becomes as sub-folder in $datadir/dwi
    if [ ! -d $responsedir ]; then mkdir -p $responsedir; fi    

    if [ ! -f response/${response}_${dwi}_response.txt ]; then
	    echo "Estimating response function use $response method"
	    dwi2response tournier -force -mask  $mask.mif -voxels $responsedir/${response}_${dwi}_sf.mif $dwi.mif $responsedir/${response}_${dwi}_response.txt
    fi

    echo Check results: response fcn and sf voxels
    echo shview  response/${response}_${dwi}_response.txt
    echo mrview  ${filebase_meanb0_brain}.mif -roi.load $responsedir/${response}_${dwi}_sf.mif -roi.opacity 0.5 -mode 2
fi


## ---- dhollander ----
if [[ $response = dhollander ]]; then
    responsedir=response #Becomes as sub-folder in $datadir/dwi
    if [ ! -d $responsedir ]; then mkdir -p $responsedir; fi
    if [ ! -f $responsedir/${response}_${dwi}_wm.txt ]; then
        # Estimate dhollander msmt response functions (use FA < 0.10 according to Blesa et al Cereb Cortex 2021)
        echo "Estimating response function use $response method"
        dwi2response dhollander -force -mask $mask.mif -voxels $responsedir/${response}_${dwi}_sf.mif -fa 0.1 $dwi.mif $responsedir/${response}_${dwi}_wm.txt $responsedir/${response}_${dwi}_gm.txt $responsedir/${response}_${dwi}_csf.txt
    fi
    echo "Check results for response fcns (wm, gm and csf) and single-fibre voxels (sf)"
    echo shview  $responsedir/${response}_${dwi}_wm.txt
    echo shview  $responsedir/${response}_${dwi}_gm.txt
    echo shview  $responsedir/${response}_${dwi}_csf.txt
    echo mrview  ${filebase_meanb0_brain}.mif -overlay.load $responsedir/${response}_${dwi}_sf.mif -overlay.opacity 0.5 -mode 2
fi
cd $currdir
