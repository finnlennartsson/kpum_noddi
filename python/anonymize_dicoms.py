import os
import pydicom as pm
from glob import glob

def anonymize_dicom(in_path, out_path, PatientName='Anonymous'):
    # Anonymouses input DCM according to data_elements in list
    
    dicom_file = pm.dcmread(in_path)
    
    # DCM tags to anonymize
    data_elements = ['PatientName',
                     'PatientID']
    for de in data_elements:
        if de in dicom_file:
            dicom_file.data_element(de).value = 'Anonymous'
    time_elements = ['PatientBirthDate']
    for de in time_elements:
        if de in dicom_file:
            dicom_file.data_element(de).value = '19010101'
        
    dicom_file.save_as(out_path)
    

if __name__ == '__main__':
    cdir=os.getcwd()
    in_slices = glob(os.path.join(cdir, '*.dcm'))
    for in_slice_ in in_slices:

        # write to the same file, i.e. anonymizing the file directly
        anonymize_dicom(in_slice_, in_slice_) 
        
        # or writing to file ANONYMOUS_slicebase
        slicebase = os.path.basename(in_slice_)
        slicedir = os.path.dirname(in_slice_)
        out_slice_ = os.path.join(slicedir, f'ANONYMIZED_{slicebase}') # writing to file ANONYMOUS_slicebase
        #anonymize_dicom(in_slice_, out_slice_) # write to file defined by out_slice 
        
