The repository can go inside the `/code` folder within of a [BIDS](https://bids.neuroimaging.io/) "studyfolder"

# Original DICOMs

Original DICOMs are exported from the SECTRA PACS

You can use the "Minimal Anonymisation Routine"

# DICOM to BIDS conversion

Bash and python scripts to convert DICOM data into BIDS-organised NIfTI data, in `studydir/rawdata`.
All scripts working on the BIDS rawdata have prefix `bids_`

To complete the conversion:
1. Run script `bids_dicomdir2sourcedata.sh`  
This prepares the DICOMS by re-naming and organizing them into `/sourcedata_non-anonym` and then anonymizes them into /sourcedata 
2. Run script `bids_sourcedata2rawdata_generate_dicominfo.sh`  
This converts the dicoms in /sourcedata to BIDS-organised NIfTIs in `/rawdata` using the heudiconv routine.
3. Run script `bids_sourcedata2rawdata.sh`  
Performs the actual conversion. Also runs the BIDS validator

# Raw data quality control (QC)
1. Run script `bids_QC_visualize_rawdata.sh`

# Diffusion pipeline
Bash scripts to process dMRI data in `derivatives`
All scripts working on the BIDS rawdata have prefix `dmri_`

1. Run script `dmri_prepare_pipeline.sh`
This prepares the pipeline by copying the relavant files into 
2. Run script `dmri_preprocess.sh`
3. Run script `dmri_dtidki.sh`
4. Run script `dmri_noddi.sh`

