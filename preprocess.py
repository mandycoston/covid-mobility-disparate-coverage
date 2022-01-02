# This file: handles preprocessing data before matching 
import pandas as pd

def load_tsv(fpath):
    with open(fpath, 'rb') as f:
        contents = f.read()
    lines = contents.decode('utf-16').split("\n")
    
    data = []
    header = []
    for i, l in enumerate(lines):
        if i == 0:
            header = l.strip().split("\t")
        else:
            data.append(l.strip().split("\t"))
    
    return pd.DataFrame(data, columns=header)

df = load_tsv("polling_place_20181106.csv")
print("Loaded data:", df.shape)
# Looks like this: 
# Index(['election_dt', 'county_name', 'polling_place_id', 'polling_place_name', 
# 'precinct_name', 'house_num', 'street_name', 'city', 'state', 'zip'], 
# dtype='object')
print(df.columns)

# Output schema: 
# safegraph_poi
# Precinct
# election_date 
# State (abbreviation)
# County 
# City 

df['street_address'] = df['house_num'] +" "+ df['street_name']

df = df.rename(columns={
    "precinct_name": "Precinct",
    "election_dt": "election_date",
    "state": "State",
    "county_name": "County",
    "city": "City"
})
print("New columns:", df.columns)
df.to_csv("polling_place_20181106_preprocessed.csv", sep=",", index=False)