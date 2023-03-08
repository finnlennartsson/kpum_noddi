# Heuristics file
# KPUM NODDI
# Author: Finn Lennartsson 
# Date: 2023-03-07
#
# In this template,
# 1. adjust so it works with for the individual sub-sID_ses-ssID,
# 2. save file as "sub-sID_ses-ssID_kpum_noddi.py"
# 3. use it/used when calling bids_sourcedata2rawdata.sh
#

import os


def create_key(template, outtype=('nii.gz',), annotation_classes=None):
    if template is None or not template:
        raise ValueError('Template must be a valid format string')
    return template, outtype, annotation_classes

def infotodict(seqinfo):
    """Heuristic evaluator for determining which runs belong where

    allowed template fields - follow python string module:

    item: index within category
    subject: participant id
    seqitem: run number during scanning
    subindex: sub index within group
    """
    # ANATOMY
    t1wmprage = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_acq-MPRAGE_run-{item:01d}_T1w')
    t2starw = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_acq-t2star_run-{item:01d}_T2starw')
    swi = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_acq-swi_run-{item:01d}_T2starw')
    swi_mnip = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_acq-swi_rec-mnip_run-{item:01d}_T2starw')
    t2wtraclin = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_acq-tra_run-{item:01d}_T2w')
    flair = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_run-{item:01d}_FLAIR')
    
    # DWI
    dki_ap = create_key('sub-{subject}/{session}/dwi/sub-{subject}_{session}_acq-dki_dir-AP_run-{item:01d}_dwi')
    dti_ap = create_key('sub-{subject}/{session}/dwi/sub-{subject}_{session}_acq-dti_dir-AP_run-{item:01d}_dwi')

    info = {t1wmprage: [], t2starw: [], swi: [], swi_mnip: [], t2wtraclin: [], flair: [], dki_ap: [], dti_ap: []}
    last_run = len(seqinfo)

    for idx, s in enumerate(seqinfo):
        """
        The namedtuple `s` contains the following fields:

        * total_files_till_now
        * example_dcm_file
        * series_id
        * dcm_dir_name
        * unspecified2
        * unspecified3
        * dim1
        * dim2
        * dim3
        * dim4
        * TR
        * TE
        * protocol_name
        * is_motion_corrected
        * is_derived
        * patient_id
        * study_description
        * referring_physician_name
        * series_description
        * image_type
        """


        # ANATOMY
        # 3D T1w Clinical scan (in collected in SAG plane)
        if ('MPRAGE' in s.protocol_name) and ('ORIGINAL' in s.image_type): 
            info[t1wmprage].append(s.series_id) # append if multiple series meet criteria   
        # T2w Ax Clinical scan (in TRA plane)
        if ('T2W_TRA' in s.protocol_name) and ('ORIGINAL' in s.image_type): 
            info[t2wtraclin].append(s.series_id) # assign if a single series meets
        # T2starw Clinical scan (in COR plane)
        if ('T2starW_COR' in s.protocol_name) and ('ORIGINAL' in s.image_type): 
            info[t2starw].append(s.series_id) # append if multiple series meet criteria
        # SWI Clinical scan (in TRA plane)
        if ('SWI_TRA' in s.protocol_name) and ('ORIGINAL' in s.image_type) and ('SWI' in s.image_type): 
            info[swi].append(s.series_id) # append if multiple series meet criteria
        # SWI Clinical scan (in TRA plane)
        if ('SWI_TRA' in s.protocol_name) and ('ORIGINAL' in s.image_type) and ('MNIP' in s.image_type): 
            info[swi_mnip].append(s.series_id) # append if multiple series meet criteria
        # FLAIR
        if ('FLAIR' in s.protocol_name) and ('ORIGINAL' in s.image_type): # takes normalized images
            info[flair].append(s.series_id) # append if multiple series meet criteria
        
        # DIFFUSION
        # DKI NODDI (dir-AP)
        if ('DKI_2.5mm_NODDI_73dir' in s.protocol_name) and ('ORIGINAL' in s.image_type):
            info[dki_ap].append(s.series_id) # append if multiple series meet criteria
        # DTI Clinical scan (in TRA plane)
        if ('DTI_2.5mm_iso' in s.protocol_name) and ('ORIGINAL' in s.image_type):
            info[dti_ap].append(s.series_id) # append if multiple series meet criteria
                       
    return info
