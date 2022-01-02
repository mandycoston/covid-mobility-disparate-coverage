import argparse
import glob 
import os
import pandas as pd
import dask.dataframe as dd
import time
import numpy as np

parser = argparse.ArgumentParser(description='Process matches')
parser.add_argument('--data', type=str, required=True, help = "Name of data folder to post-process")
parser.add_argument('--poi_data', type=str, default="path_to_poi_data")
args = parser.parse_args()

def diff_letters(a,b):
    return sum ( a[i] != b[i] for i in range(len(a)) )


matched_files = glob.glob(os.path.join(args.data, "*_matched.csv"))
print(f"Found file: {matched_files}")

assert len(matched_files) == 1, 'Multiple files with the suffix \'matched\' are found. Which do you want to use?'

f = matched_files[0]
poll_places = pd.read_csv(f)
print("Columns", poll_places.columns)
print(f"{poll_places.shape[0]} rows")

print("Loading safegraph data")


sg_poi = pd.DataFrame()
for i in range(1, 5): 
    start = time.time()
    sg_poi = sg_poi.append(pd.read_csv(os.path.join(args.poi_data, f"core_poi-part{i}.csv.gz"), compression='infer'))
    print(f"Loaded POI file {i}/{5}. {time.time() - start} seconds.")


out_df = poll_places.set_index('safegraph_place_id').join(sg_poi.set_index('safegraph_place_id'), how='left')
print("Shape after joining:", out_df.shape)

# filter out matches where the street address differs by more than threshold words  
threshold = 3
filt = []
for i in range(out_df.shape[0]):
    pp_addr = set(str(out_df.iloc[i]['customer_street_address']).lower().split())
    sg_addr = set(str(out_df.iloc[i]['street_address']).lower().split())
    common = pp_addr.intersection(sg_addr)
    filt.append(
        abs(len(common) - len(pp_addr)) < threshold and abs(len(common) - len(sg_addr)) < threshold
    )

out_df = out_df[np.array(filt)]
print("Shape after filtering:", out_df.shape)
out_file = f.replace("_matched", "_filtered")
out_df.to_csv(out_file)

