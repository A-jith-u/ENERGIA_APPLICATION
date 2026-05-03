import os, sys, traceback
sys.path.insert(0, os.path.dirname(__file__))
import notify_api
try:
    notify_api._send_email('ENERGIA Fallback Test', '<b>Fallback Test</b>', ['chavarananickel@gmail.com'])
    print('FALLBACK_SEND_OK')
except Exception as e:
    print('FALLBACK_SEND_ERR', type(e).__name__, str(e))
    traceback.print_exc()
