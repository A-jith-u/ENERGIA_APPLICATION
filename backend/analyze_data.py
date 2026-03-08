import pandas as pd
from sqlalchemy import create_engine
import numpy as np

engine = create_engine('postgresql+psycopg2://postgres:ajith%40@localhost:5432/energia')
df = pd.read_sql('SELECT ds, value, voltage FROM sensor_data ORDER BY ds', engine)

print('Total rows:', len(df))
print('\nVALUE column stats:')
print(df['value'].describe())
print('Unique values:', df['value'].nunique())
print('Missing:', df['value'].isna().sum())
print('Zeros:', (df['value'] == 0).sum())
print('Non-zero:', (df['value'] != 0).sum())

print('\n\nVOLTAGE column stats:')
non_null_volt = df['voltage'].dropna()
print('Non-null:', len(non_null_volt), '/', len(df))
if len(non_null_volt) > 0:
    print(non_null_volt.describe())

# Check time gaps
df['ds'] = pd.to_datetime(df['ds'])
df = df.sort_values('ds')
time_diffs = df['ds'].diff()
print('\n\nTIME GAP ANALYSIS:')
print('Date range:', df['ds'].min(), 'to', df['ds'].max())
print('Max gap:', time_diffs.max())
print('Mean gap:', time_diffs.mean())
print('Gaps > 1 hour:', (time_diffs > pd.Timedelta(hours=1)).sum())

# Distribution of values
print('\n\nVALUE DISTRIBUTION:')
value_ranges = {
    '0': (df['value'] == 0).sum(),
    '0-10': ((df['value'] > 0) & (df['value'] <= 10)).sum(),
    '10-50': ((df['value'] > 10) & (df['value'] <= 50)).sum(),
    '50-100': ((df['value'] > 50) & (df['value'] <= 100)).sum(),
    '100-200': ((df['value'] > 100) & (df['value'] <= 200)).sum(),
    '>200': (df['value'] > 200).sum(),
}
for range_name, count in value_ranges.items():
    pct = 100 * count / len(df)
    print(f'  {range_name}: {count} ({pct:.1f}%)')
