import os
import shutil
import json
import numpy as np
import pandas as pd
from glob import glob
import argparse

def perform_process(processcall):
    import subprocess
    p = subprocess.Popen(processcall, stdout=subprocess.PIPE, shell=True)
    while True:
        output = p.stdout.readline()
        if p.poll() is not None:
            break
        if output:
            print(output.strip().decode("utf-8"))
    p.poll()

def main(derivatives, session):
    # List sub-sID/ses-ssID that have done quad
    quadfolders = glob(os.path.join(derivatives, 'sub-*', f'ses-{session}', 'qc/quad'))

    # Create squad folder in sub-GROUP/ses-{session}/qc/squad
    squadfolder = os.path.join(derivatives, f'sub-GRP/ses-{session}/qc/squad')
    if not os.path.exists(squadfolder):
        os.makedirs(squadfolder)

    # Write the squadlist file to this folder
    squadlistfile = os.path.join(squadfolder, 'squad_list.txt')
    with open(squadlistfile, "w") as outfile:
        outfile.write("\n".join(quadfolders))

    # Run SQUAD (eddy_squad)
    squadtmpoutputfolder = os.path.join(squadfolder, 'tmp')
    processcall = f"eddy_squad {squadlistfile} -u -o {squadtmpoutputfolder}"
    perform_process(processcall)

    # Move the output in /tmp up to squadfolder
    for file in os.listdir(squadtmpoutputfolder):
        shutil.move(os.path.join(squadtmpoutputfolder, file), squadfolder)

    # Delete tmp output folder
    if os.path.isdir(squadtmpoutputfolder):
        shutil.rmtree(squadtmpoutputfolder)

    # Read SQUAD output (GROUP JSON-file)
    with open(os.path.join(squadfolder, 'group_db.json'), 'r') as f:
        squad = json.load(f)

    # Create dataframes
    df1 = pd.DataFrame(squad["qc_motion"], columns=['qc_motion_abs', 'qc_motion_rel'], dtype=float)
    df2 = pd.DataFrame(squad["qc_cnr"], columns=['qc_snr_b0', 'qc_cnr_b1000', 'qc_cnr_b2000'], dtype=float)
    df3 = pd.DataFrame(squad["qc_outliers"], columns=['qc_outliers_tot', 'qc_outliers_b1000', 'qc_outliers_b2000', 'qc_outliers_pe'], dtype=float)
    df = pd.concat([df1, df2, df3['qc_outliers_tot']], axis=1, join='outer')

    # Create QC dataframe
    dfqc = pd.DataFrame(np.zeros(df.shape))  # same shape as df but filled with zeros
    dfqc.columns = df.columns
    dfqc[abs(df.mean(axis=0) - df) < (2 * df.std(axis=0))] = 0.5
    dfqc[abs(df.mean(axis=0) - df) < (1 * df.std(axis=0))] = 1

    # Get sID and ssID:s from quadfolders
    sID_ssID = [s.replace(derivatives + "/", "") for s in quadfolders]
    sID = [s.replace(f"/ses-{session}/qc/quad", "") for s in sID_ssID]
    df_sID_ssID = pd.DataFrame(sID, columns=["participant_id"])
    df_sID_ssID["session_id"] = f"ses-{session}"
    df_sID_ssID["qc_all_pass_fail"] = dfqc.min(axis=1)

    # Rename columns
    dfqc.rename(columns={
        'qc_motion_abs': 'qc_motion_abs_pass_fail',
        'qc_motion_rel': 'qc_motion_rel_pass_fail',
        'qc_snr_b0': 'qc_snr_b0_pass_fail',
        'qc_cnr_b1000': 'qc_cnr_b1000_pass_fail',
        'qc_cnr_b2000': 'qc_cnr_b2000_pass_fail',
        'qc_outliers_tot': 'qc_outliers_tot_pass_fail'
    }, inplace=True)

    dfqc = pd.concat([df_sID_ssID, dfqc], axis=1, join='outer')
    dfqc = dfqc.sort_values(by='participant_id')

    # Write to output file
    squadqctsv = os.path.join(squadfolder, f'sub-GRP_ses-{session}_pipeline_QC_SQUAD.tsv')
    dfqc.to_csv(squadqctsv, sep="\t", index=False)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run dmri_SQUAD pipeline.")
    parser.add_argument("--derivatives", required=True, help="Path to the derivatives folder.")
    parser.add_argument("--session", required=True, help="Session identifier.")
    args = parser.parse_args()
    main(args.derivatives, args.session)