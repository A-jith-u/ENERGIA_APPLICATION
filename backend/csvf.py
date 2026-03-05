import pandas as pd
import io
from sqlalchemy import create_engine

# 1. SETTINGS
file_path = r'C:\Users\aswathys\Downloads\sensor_data_export.csv' 
DB_URL = 'postgresql://postgres:aswathy2004@localhost:5432/energia'

def clean_and_upload():
    try:
        print("Reading and cleaning the file...")
        
        # Try UTF-16 first (since it caused the 0xff error), then fallback to others
        content = None
        for enc in ['utf-16', 'utf-8-sig', 'utf-8', 'cp1252']:
            try:
                with open(file_path, 'r', encoding=enc) as f:
                    content = f.readlines()
                print(f"Successfully read file using {enc} encoding.")
                break
            except (UnicodeDecodeError, UnicodeError):
                continue

        if content is None:
            print("Error: Could not decode the file with any standard encoding.")
            return

        cleaned_lines = []
        for line in content:
            line = line.strip()
            if not line:
                continue
            
            # Remove the double quotes that wrap the entire row
            if line.startswith('"') and line.endswith('"'):
                line = line[1:-1]
            
            cleaned_lines.append(line)
        
        # Convert to DataFrame
        csv_data = "\n".join(cleaned_lines)
        df = pd.read_csv(io.StringIO(csv_data))

        print("--- Data Preview ---")
        print(df.head(3))
        print("--------------------")

        # 2. CONNECT AND UPLOAD
        print("Connecting to PostgreSQL...")
        engine = create_engine(DB_URL)
        df.to_sql('sensor', engine, if_exists='replace', index=False)
        
        print(f"Success! {len(df)} rows uploaded to 'sensor' table.")

    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    clean_and_upload()