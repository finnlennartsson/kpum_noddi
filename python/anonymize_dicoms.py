import pydicom as pm
from glob import glob
import os

def anonymize_dicom(in_path, out_path, PatientName='Anonymous'):
    # Anonymouses input DCM according to data_elements in list
    
    dicom_file = pm.dcmread(in_path)
    
    # DCM tags to anonymize
    data_elements = ['PatientName',
                     'PatientBirthDate',
                     'PatientID']
    for de in data_elements:
        if de in dicom_file:
            dicom_file.data_element(de).value = 'Anonymous'
            dicom_file.save_as(out_path)
    

if __name__ == '__main__':
    cdir=os.getcwd()
    in_slices = glob(os.path.join(cdir, '*.dcm'))
    for in_slice_ in in_slices:
        slicebase = os.path.basename(in_slice_)
        slicedir = os.path.dirname(in_slice_)
        out_slice_ = os.path.join(slicedir, f'ANONYMOUS_{slicebase}') # writing to file ANONYMOUS_slicebase
        anonymize_dicom(in_slice_, out_slice_)
        
