This folder contains a set of Jupyter Notebooks for processing of dMRI files

## Organization and Anonymization of DCMs
Image data from the MR-scanner is exported (non-anonymized) to external HD. This is then organized and anonymized.  
This image shows and overview to the process  
![image](https://user-images.githubusercontent.com/20419258/229979202-ae11f342-3022-4e8d-806f-4c22774f4c74.png)

### Implementation
This uses the notebook `dicomdir2sourcedata.ipynb`  

Input: 
Output: 

## Conversion into NIfTI (and NRRD) data
Anonymized DCM data is converted into NIfTI (and/or NRRD) data Image data from the MR-scanner is exported (non-anonymized) to external HD. This is then organized and anonymized.  
This image shows and overview to the process  
![image](https://user-images.githubusercontent.com/20419258/229981318-dd598a06-9709-42b4-9064-47b2b2dfc7f1.png)

### Implementation
This uses the notebook `sourcedata2nifti.ipynb`  
Input:
Output:

## dMRI pipeline

### Implementation
This uses the notebook `sourcedata2nifti.ipynb`  
Input:
Output:
