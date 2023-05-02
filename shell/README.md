The repository can go inside the `/code` folder within of a [BIDS](https://bids.neuroimaging.io/) "studyfolder"

# Original DICOMs

Original DICOMs are exported from the SECTRA PACS using the "Minimal Anonymisation Routine" when exporting, or directly from the MR-scanner console (saved on DVD). 

# DICOM to BIDS conversion

Bash and python scripts to convert DICOM data into BIDS-organised NIfTI data, in `studydir/rawdata`.
All scripts working on the BIDS rawdata have prefix `bids_`

To complete the conversion:
1. Run script `bids_dicomdir2sourcedata.sh`  
This prepares the DICOMS by re-naming and organizing them into `/sourcedata_non-anonym` and then anonymizes them into /sourcedata  
Here is an example for 001/MR1 and 002/MR1  
```sh
$ bash code/kpum_noddi/shell/bids_dicomdir2sourcedata.sh rawdicomdir 001_MR1_8175665_20210322/DICOM_NODDI 001 MR1
```
or if multiple DICOM-folder then run `DICOM_fromPACS` first followed the non-anonymized `DICOM_NODDI` last   
```
$ bash code/kpum_noddi/shell/bids_dicomdir2sourcedata.sh rawdicomdir 002_MR1_8193760_20210512/DICOM_fromPACS 002 MR1
$ bash code/kpum_noddi/shell/bids_dicomdir2sourcedata.sh rawdicomdir 002_MR1_8193760_20210512/DICOM_NODDI 002 MR1
```
2. Run script `bids_sourcedata2rawdata_generate_dicominfo.sh`  
This converts the dicoms in `/sourcedata` to BIDS-organised NIfTIs in `/rawdata` using the heudiconv routine.
3. Run script `bids_sourcedata2rawdata.sh`  
Performs the actual conversion the dicoms in `/sourcedata` to BIDS-organised NIfTIs in `/rawdata` using the heudiconv routine.  
Also runs the BIDS validator.

# Raw data quality control (QC)
1. Run script `bids_QC_visualize_rawdata.sh`

# Diffusion pipeline
Bash scripts to process dMRI data in `derivatives`
All scripts working on the BIDS rawdata have prefix `dmri_`

## Running invidivdual scripts
Run scripts in the following order
1. Run script `dmri_prepare_pipeline.sh`  
2. Run script `dmri_preprocess.sh`
3. Run script `dmri_dtidki.sh`
4. Run script `dmri_noddi.sh`

## Running wrapper script
Run script `dmri_pipeline.sh`  
E.g. using these input variables
```sh
bash    /home/finn/Code/kpum_noddi/shell/dmri_pipeline_test.sh \
        035 MR1 /mnt/s/Research/Projects/KPUM_NODDI/Data \
        -derivatives /mnt/s/Research/Projects/KPUM_NODDI/Data/derivatives/dMRI_Testing7_dmri_pipeline \
        -protocol ORIG
```



