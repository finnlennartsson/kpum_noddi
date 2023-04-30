#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
@author: finn
Script for calculating NODDI maps using the AMICO Python package
"""

import argparse, os, pathlib

parser = argparse.ArgumentParser(description='Script for performing AMICO NODDI estimation. Output written into folder AMICO/NODDI_dPar')
parser.add_argument('--studydir', help='Studydir for study (e.g. /mnt/e/Finn/KPUM_NODDI/Data) (default: current directory = $PWD)', default=os.getcwd())
parser.add_argument('--derivatives', help='Derivatives folder (e.g. derivatives/dMRI_op)', required=True)
parser.add_argument('--subjectdata', help='Subject datafolder in derivatives folder containing the dMRI data (e.g. sub-sID/ses-ssID/dwi)', required=True)
parser.add_argument('--dwi', help='dMRI NIfTI file in subject datafolder (e.g. sub-sID_ses-ssID_dir-AP_desc-preproc-inorm_dwi.nii)', required=True)
parser.add_argument('--bvec', help='dMRI bvecs file in subject datafolder (e.g. sub-sID_ses-ssID_dir-AP_desc-preproc-inorm_dwi.bvec)', required=True)
parser.add_argument('--bval', help='dMRI bvals file in subject datafolder (e.g. sub-sID_ses-ssID_dir-AP_desc-preproc-inorm_dwi.bval)', required=True)
parser.add_argument('--mask', help='Brain mask NIfTI file in subject datafolder (e.g. sub-sID_ses-ssID_space-dwi_mask.nii)', required=True)
parser.add_argument('--dPar', help='Axial diffusivity to use in the NODDI model. (default: 1.7e-3)', default=1.7e-3, type=float)
args = vars(parser.parse_args())

studydir = args['studydir']
derivatives = args['derivatives']
subjectdata = args['subjectdata']
datadir = os.path.join(studydir, derivatives, subjectdata)
dwi = args['dwi']
dwifilebase = pathlib.Path(dwi).stem
bvec = args['bvec']
bval = args['bval']
mask = args['mask']
dPar = args['dPar']

import amico
import numpy as np

#amico.setup() # to be run only once and saves in ~/.dipy

# Save gradient scheme
amico.util.fsl2scheme(os.path.join(datadir, bval),os.path.join(datadir, bvec))
ae = amico.Evaluation( derivatives, subjectdata )
ae.load_data( dwi_filename=os.path.join(datadir, dwi), scheme_filename=os.path.join(datadir, f"{dwifilebase}.scheme"), mask_filename=os.path.join(datadir, mask), b0_thr=0 )
# Set model to NODDI and use dPar as the axial diffusivity
ae.set_model( "NODDI" )
ae.model.set(
    dPar=dPar,
    dIso=3.0E-3,
    IC_VFs=np.linspace(0.1,0.99,12),
    IC_ODs=np.hstack((np.array([0.03, 0.06]),np.linspace(0.09,0.99,10))),
    isExvivo=False)
# Generate kernels
ae.generate_kernels( regenerate=True ) # Save kernel in datadirbasefolder
ae.load_kernels()
# Fit NODDI model
ae.fit()
# Save the results
ae.save_results()
#ae.save_results(path_suffix='dPar=%s' % (dPar))
#dParstr = str(dPar).replace('.','p')
#ae.save_results(path_suffix=f'dPar-{dParstr}')