import pydicom as pm
from glob import glob
import os

def anonymize_dicom(in_path, out_path, PatientName='Anonymous'):
    dicom_file = pm.dcmread(in_path)

    # DCM tags to anonymize
    data_elements = ['PatientName',
                     'PatientBirthDate',
                     'PatientID']
    # Go through this list
    for de in data_elements:
        if de in dicom_file:
            dicom_file.data_element(de).value = 'Anonymous'
            dicom_file.save_as(out_path)
    

if __name__ == '__main__':
    cdir=os.getcwd()
    
    # Defined in- and out-puts - suitable for a jupiter notebook
    in_dicoms = 'dicomdir'
    out_dicoms = 'sourcedata'
    subjectID ='sub-001'
    sessionID ='ses-MR1mock'

    in_series = glob(os.path.join(cdir, in_dicoms, subjectID, sessionID, '*'))

    for in_serie_ in in_series:
        seriebase = os.path.basename(in_serie_)
        out_serie_ = os.path.join(cdir, out_dicoms, subjectID, sessionID, seriebase)
        if not os.path.isdir(out_serie_):
            os.makedirs(out_serie_)
        in_slices = glob(os.path.join(in_serie_, '*.dcm'))
        for in_slice_ in in_slices:
            slicebase = os.path.basename(in_slice_)
            out_slice_ = os.path.join(out_serie_, slicebase)
            anonymize_dicom(in_slice_, out_slice_)
