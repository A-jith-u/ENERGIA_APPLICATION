import os, sys, traceback
sys.path.insert(0, os.path.dirname(__file__))
from alert_mail_service import AlertMailService
m=AlertMailService()
print('CONFIGURED:', m.is_configured(), m.smtp_host, m.smtp_port, m.smtp_user, 'ssl=', m.smtp_use_ssl)
try:
    m.send_html_email(subject='ENERGIA Test', html_body='<b>Test</b>', recipients=['chavarananickel@gmail.com'])
    print('SEND_OK')
except Exception as e:
    print('SEND_ERR', type(e).__name__, str(e))
    traceback.print_exc()
