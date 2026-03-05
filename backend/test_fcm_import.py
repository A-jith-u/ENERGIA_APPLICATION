import traceback
import sys

sys.path.insert(0, '.')

try:
    import fcm_api
    print('[OK] FCM API loaded')
except Exception as e:
    print('[ERROR] FCM API import failed:')
    traceback.print_exc()
