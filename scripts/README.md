The repository can go inside the `/code` folder within of a [BIDS](https://bids.neuroimaging.io/) "studyfolder"

# Original DICOMs

Original DICOMs are exported from the SECTRA PACS 

# Data organisation - BIDS conversion

Bash and python scripts to convert DICOM data into BIDS-organised NIfTI data, in /rawdata.

All scripts working on the BIDS rawdata have prefix bids_

To complete the conversion:

Run script `bids_dicomdir2sourcedata.sh`
This prepares the DICOMS by re-naming and organizing them into /sourcedata

Run script `bids_sourcedata2bids_generate_dicominfo.sh`
This converts the dicoms in /sourcedata to BIDS-organised NIfTIs in /rawdatausing the heudiconv routine.
Run BIDS validator

# Raw data quality control (QC)
