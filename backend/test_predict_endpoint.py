#!/usr/bin/env python3
"""Test prediction endpoint to capture the exact error."""

import sys
sys.path.insert(0, 'backend')

from serve_prophet import _predict_payload_with_live_data, _predict_detailed_15min
import traceback
import json

print("=" * 80)
print("Testing _predict_payload_with_live_data (5min)...")
print("=" * 80)

try:
    result = _predict_payload_with_live_data(horizon_minutes=5)
    print("✅ Success:")
    print(json.dumps(result, indent=2, default=str))
except Exception as e:
    print(f"❌ Error: {e}")
    traceback.print_exc()

print("\n" + "=" * 80)
print("Testing _predict_detailed_15min...")
print("=" * 80)

try:
    result = _predict_detailed_15min()
    print("✅ Success:")
    print(json.dumps(result, indent=2, default=str))
except Exception as e:
    print(f"❌ Error: {e}")
    traceback.print_exc()
