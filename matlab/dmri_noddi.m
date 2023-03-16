% cd data
SubjPATH = '/media/finn/HD-PCFSU3-A/Finn/KPUM_NODDI/Test3Data/derivatives/dMRI/sub-001/ses-MR2/dwi/noddi';
cd(SubjPATH );

addpath(genpath('/home/finn/Software/NODDI_toolbox_v1.05/'))
addpath('/home/finn/Software/nifti_matlab/matlab/')

%
CreateROI('dwi_preproc_inorm.nii', 'mask.nii', 'NODDI_mask.mat');
protocol = FSL2Protocol('dwi_preproc_inorm.bval', 'dwi_preproc_inorm.bvec');
noddi = MakeModel('WatsonSHStickTortIsoV_B0');
batch_fitting('NODDI_mask.mat', protocol, noddi, 'FittedParams_sub-001_ses-MR2.mat', 6);
SaveParamsAsNIfTI('FittedParams_sub-001_ses-MR2.mat', 'NODDI_mask.mat', 'mask.nii', 'sub-001_ses-MR2_desc-noddi')