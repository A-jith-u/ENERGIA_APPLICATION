#!/usr/bin/env python3
"""Fix malformed UTF-16 CSV and prepare for Prophet training."""

import pandas as pd

# Read raw file and remove outer quotes from quoted rows
lines = []
with open('sensor_data_export.csv', 'r', encoding='utf-16') as f:
    raw = f.read()

for line in raw.strip().split('\n'):
    # Remove outer quotes if the entire line is quoted
    if line.startswith('"') and line.endswith('"'):
        line = line[1:-1]
    lines.append(line)

# Save clean CSV
with open('sensor_data_clean.csv', 'w', encoding='utf-8') as fw:
    fw.write('\n'.join(lines))

# Load and verify
df = pd.read_csv('sensor_data_clean.csv')
print(f"✅ Clean CSV created: {len(df)} rows, {len(df.columns)} columns")
print(f"Columns: {df.columns.tolist()}")
print(f"\nFirst 3 rows:")
print(df[['ds', 'value', 'power']].head(3))

# Convert types
df['ds'] = pd.to_datetime(df['ds'], errors='coerce')
df['value'] = pd.to_numeric(df['value'], errors='coerce')

# Check for NaN
print(f"\nData quality:")
print(f"  ds nulls: {df['ds'].isna().sum()}")
print(f"  value nulls: {df['value'].isna().sum()}")
print(f"  value range: {df['value'].min():.2f} - {df['value'].max():.2f}")

# Save clean version with only ds and value
df[['ds', 'value']].to_csv('sensor_data_prophet_ready.csv', index=False)
print(f"\n✅ Prophet-ready CSV saved: sensor_data_prophet_ready.csv")
