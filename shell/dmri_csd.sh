#!/bin/bash
# KPUM NODDI
#
usage()
{
  base=$(basename "$0")
  echo "usage: $base sID ssID studydir [options]
Estimation of CSD

Arguments:
    sID                             Subject ID (e.g. 001) 
    ssID                            Session ID (e.g. MR2)
    studydir                        Studydir with full path (e.g. \$PWD or /mnt/e/Finn/KPUM_NODDI/Data)
Options:
    -dwi                            dMRI preprocessed data in MRtrix .mif format (default: \$datadir/dwi/sub-sID_ses-ssID_dir-AP_desc-preproc-inorm_dwi.mif
    -mask                           Brain mask in .mif format (default: \$datadir/dwi/sub-sID_ses-ssID_space-dwi_mask.mif)
    -response                       Response function (tournier or dhollander) (default: dhollander)
    -responsebase                   Base name with path response function (tournier or dhollander) found in /response (default: \${response}_\${dwibase})
    -d / -data-dir  <directory>     The directory used to output the preprocessed files (default: \$studydir/derivatives/dMRI/sub-sID/ses-ssID)
    -t / -threads                 Number of CPU threads (default: 4) 
    -h / -help / --help             Print usage.
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
dwi=""; mask=""; responsebase=""  # See below - Defaults cont'd
response=dhollander
threads=4

# check whether the different tools are set and load parameters
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

while [ $# -gt 0 ]; do
    case "$1" in
	-dwi) shift; dwi=$1; ;;
	-mask) shift; mask=$1; ;;
	-response) shift; response=$1; ;;
	-responsebase) shift; responsebase=$1; ;;
	-d|-data-dir)  shift; datadir=$1; ;;
    -t|-threads)  shift; threads=$1; ;;
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
if [ $responsebase=="" ]; then
  dwibase=`basename $dwi .mif`
  responsebase=${response}_$dwibase
fi

# Check if images exist, else put in No_image
if [ ! -f $dwi ]; then dwi="No_image"; fi
if [ ! -f $mask ]; then dwi="No_image"; fi


echo "CSD estimation of dMRI 
Subject:        $sID 
Session:        $ssID
Studydir:       $studydir
DWI (AP):       $dwi
Mask:           $mask
Response:       $response
Data directory: $datadir 
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

################ START ###########################################################


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

# output folder for CSD

responsedir=response

# ---- Tournier ----
if [[ $response = tournier ]]; then
    # Do CSD estimation
    csddir=csd #Becomes as sub-folder in $datadir/dwi
    if [ ! -d $csddir ]; then mkdir -p $csddir; fi

    if [ ! -f $csddir/csd_${responsebase}.mif ]; then
        echo "Estimating ODFs with CSD"
        dwi2fod -force -mask $mask.mif csd $dwi.mif $responsedir/${responsebase}_response.txt $csddir/csd_${responsebase}.mif
        echo Check results of ODFs
        echo mrview -load ${filebase_meanb0_brain}.mif -odf.load_sh $csddir/csd_${responsebase}.mif -mode 2
    fi
fi

# ---- MSMT = msmt_5tt and dhollander ----
if [[ $response = dhollander ]]; then
    csddir=csd #Becomes as sub-folder in $datadir/dwi
    if [ ! -d $csddir ];then mkdir -p $csddir;fi
fi
if [[ $response = msmt_5tt ]]; then
        csddir=csd/$method-$atlas #Becomes as sub-folder in $datadir/dwi
    if [ ! -d $csddir ];then mkdir -p $csddir;fi
fi
    
    # Calculate ODFs
if [ ! -f $csddir/csd_${responsebase}_wm_3tt.mif ]; then
    echo "Calculating CSD with 3-tissues (WM, GM, CSF) using ACT and $responsebase"
    # model with all 3 tissue types: WM GM CSF
    dwi2fod msmt_csd -mask $mask.mif $dwi.mif $responsedir/${responsebase}_wm.txt $csddir/csd_${responsebase}_wm_3tt.mif $responsedir/${responsebase}_gm.txt $csddir/csd_${responsebase}_gm_3tt.mif $responsedir/${responsebase}_csf.txt $csddir/csd_${responsebase}_csf_3tt.mif
fi
if [ ! -f $csddir/csd_${responsebase}_wm_2tt.mif ]; then
    echo "Calculating CSD with 2-tissues (WM, CSF) using ACT and $responsebase"
    # model with all 2 tissue types: WM CSF
    dwi2fod msmt_csd -mask $mask.mif $dwi.mif $responsedir/${responsebase}_wm.txt $csddir/csd_${responsebase}_wm_2tt.mif $responsedir/${responsebase}_csf.txt $csddir/csd_${responsebase}_csf_2tt.mif
fi

echo Check the results of ODFs 
echo mrview -load ${filebase_meanb0_brain}.mif -odf.load_sh $csddir/csd_${responsebase}_wm_3tt.mif -odf.load_sh $csddir/csd_${responsebase}_wm_2tt.mif -mode 2;

cd $currdir
