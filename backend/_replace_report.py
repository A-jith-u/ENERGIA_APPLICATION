import os
import shutil

old_file = r'E:\Flutter\flutter_application_1\backend\monthly_report_api.py'
new_file = r'E:\Flutter\flutter_application_1\backend\monthly_report_api_new.py'

try:
    os.remove(old_file)
    print(f"Removed: {old_file}")
except Exception as e:
    print(f"Error removing: {e}")

try:
    shutil.move(new_file, old_file)
    print(f"Moved {new_file} to {old_file}")
except Exception as e:
    print(f"Error moving: {e}")

print("Done!")
