#!/bin/bash



########################################
## START


# Create subjecttrackertsv-file if not exists

## Process to perform - dmri_prepare_pipeline
process = 'dmri_prepare_pipeline'
processfile = 'dmri_prepare_pipeline.sh'
processfilepath = os.path.join(codedir,'shell', processfile)
processcall = f"bash {processfilepath} {subject} {session} -d {datadir}" 
print(f'Start - Process to perform {process}')
print(f'End - Process perform {process}')


## Process to perform - dmri_preprocess
process = 'dmri_preprocess'
processfile = 'dmri_preprocess.sh'
processfilepath = os.path.join(codedir,'shell', processfile)
sessionQCfile = os.path.join(datadir,'session_QC.tsv')
threads = 4
processcall = f"bash {processfilepath} {subject} {session} -d {datadir} -protocol {protocol} -s {sessionQCfile} -threads {threads}" 
print(f'Start - Process to perform {process}')
print(f'End - Process perform {process}')

## Process to perform - dmri_dtidk
process = 'dmri_dtidki'
processfile = 'dmri_dtidki.sh'
processfilepath = os.path.join(codedir,'shell', processfile)
dwi = os.path.join(datadir, 'dwi', f'sub-{subject}_ses-{session}_dir-AP_desc-preproc-inorm_dwi.mif')
mask = os.path.join(datadir, 'dwi', f'sub-{subject}_ses-{session}_space-dwi_mask.mif')
threads = 4
processcall = f"bash {processfilepath} {subject} {session} -d {datadir} -dwi {dwi} -threads {threads} -mask {mask}" 
print(f'Start - Process to perform {process}')
print(f'End - Process perform {process}')

## Process to perform - dmri_noddi
process = 'dmri_noddi'
processfile = 'dmri_noddi.sh'
processfilepath = os.path.join(codedir,'shell', processfile)
dwi = os.path.join(datadir, 'dwi', f'sub-{subject}_ses-{session}_dir-AP_desc-preproc-inorm_dwi.mif')
mask = os.path.join(datadir, 'dwi', f'sub-{subject}_ses-{session}_space-dwi_mask.mif')
threads = 4
processcall = f"bash {processfilepath} {subject} {session} -derivatives {datadirbasefolder} -subjectdata sub-${subject}/ses-{session}/dwi -dwi {dwi} -mask {mask} -dPar {dPar} -threads {threads}" 
print(f'Start - Process to perform {process}')
print(f'End - Process perform {process}')

# If NEW protocol then carry on pipeline 
