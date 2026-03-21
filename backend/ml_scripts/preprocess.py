import pandas as pd
import numpy as np
import os

# --- Path Logic ---
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
INPUT_PATH = os.path.abspath(os.path.join(SCRIPT_DIR, "..", "sensor_data_export.csv"))
DATA_FOLDER = os.path.dirname(INPUT_PATH)
OUTPUT_PATH = os.path.join(DATA_FOLDER, "preprocessed_energy_data.csv")

def run_preprocessing():
    print(f"Reading data from: {INPUT_PATH}")
    
    # 1. Load the dataset with Encoding Protection
    df = None
    for enc in ['utf-16', 'utf-8', 'latin1']:
        try:
            df = pd.read_csv(INPUT_PATH, encoding=enc, skipinitialspace=True)
            print(f"[OK] Loaded successfully with {enc} encoding.")
            break
        except (UnicodeError, UnicodeDecodeError):
            continue
    
    if df is None:
        print("[ERROR] Failed to load CSV: Could not determine file encoding.")
        return

    # 2. DATA RESCUE: Check if data is trapped in the first column
    # If the first row's second column is empty, the data is likely all in the first column
    if df.shape[1] > 1 and df.iloc[:, 1].isnull().all():
        print("[INFO] Trapped data detected (Quoted Rows). Unpacking...")
        # Take everything in the first column, split it by comma
        new_df = df.iloc[:, 0].str.strip('"').str.split(',', expand=True)
        # Ensure we have the right number of columns
        if new_df.shape[1] == len(df.columns):
            new_df.columns = df.columns
            df = new_df
            print("[OK] Data rows successfully unpacked.")
        else:
            print(f"[WARN] Unpacked column count ({new_df.shape[1]}) doesn't match header ({len(df.columns)})")

    # 3. Numeric Conversion
    numeric_cols = ['power', 'current', 'power_factor', 'voltage']
    for col in numeric_cols:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors='coerce').fillna(0)
    
    # 4. Basic Cleaning
    if 'ds' not in df.columns:
        print(f"[ERROR] 'ds' column missing. Columns found: {df.columns.tolist()}")
        return

    # Clean the timestamp string and convert
    df['ds'] = df['ds'].str.strip('"') if df['ds'].dtype == 'object' else df['ds']
    df['ds'] = pd.to_datetime(df['ds'], errors='coerce')
    df = df.dropna(subset=['ds']).sort_values('ds').reset_index(drop=True)

    # 5. Feature Engineering for Isolation Forest
   # Inside preprocess.py -> run_preprocessing()
# 5. Feature Engineering for Isolation Forest
    processed_df = df[['ds', 'power', 'current', 'power_factor']].copy()
    processed_df['power_change_rate'] = processed_df['power'].diff().fillna(0)
    processed_df['rolling_avg_power'] = processed_df['power'].rolling(window=5).mean().fillna(processed_df['power'])
    processed_df['rolling_std_power'] = processed_df['power'].rolling(window=5).std().fillna(0)
    processed_df['is_holiday'] = processed_df['ds'].dt.dayofweek.apply(lambda x: 1 if x >= 5 else 0)
    processed_df['occupancy'] = (processed_df['power'] > 10).astype(int) # Using 10W as a baseline
    # 6. Save the final file
    processed_df.to_csv(OUTPUT_PATH, index=False)
    print(f"[OK] Success! Preprocessed data stored in: {OUTPUT_PATH}")
    print(f"Sample Row: {processed_df.head(1).to_dict(orient='records')[0]}")

if __name__ == "__main__":
    run_preprocessing()