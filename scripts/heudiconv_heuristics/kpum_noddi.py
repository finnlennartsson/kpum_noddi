# Heuristics file 
# Author: Finn Lennartsson 
# Date: 2023-03-06

import os

def create_key(template, outtype=('nii',), annotation_classes=None):
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
    #t1wmprage = create_key('sub-{subject}/anat/sub-{subject}_run-{item:01d}_T1w')
    #flair = create_key('sub-{subject}/anat/sub-{subject}_run-{item:01d}_FLAIR')
    
    # DWI
    dwi_ap = create_key('sub-{subject}/dwi/sub-{subject}_dir-AP_run-{item:01d}_dwi')
    
    # FMAPs
    
    # SBRefs


    info = {dwi_ap: []}
    
    #info = {t1wmprage: [], flair: [], dwi_ap: []}
    #info = {t1wmprage: [], t2w: [], dwi: [], dwi_sbref: [], rest: [], rest_sbref: [], fmap_se}
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
        # 3D T1w
        #if ('t1_mprage_sag' in s.protocol_name) and ('NORM' in s.image_type): # takes normalized images:
        #    info[t1wmprage].append(s.series_id) # append if multiple series meet criteria
        #
        # FLAIR
        #if ('t2_space_dark-fluid_sag' in s.protocol_name) and ('NORM' in s.image_type): # takes normalized images
        #    info[flair].append(s.series_id) # append if multiple series meet criteria
        
        # DIFFUSION
        # dir AP
        if ('DKI_2.5mm_NODDI_73dir' in s.protocol_name) and ('ORIGINAL' in s.image_type):
            info[dwi_ap].append(s.series_id) # append if multiple series meet criteria
                    
    return info
