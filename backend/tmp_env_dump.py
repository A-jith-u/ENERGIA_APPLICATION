import os
keys = [
 'ALERT_SMTP_HOST','ALERT_SMTP_PORT','ALERT_SMTP_USER','ALERT_SMTP_PASSWORD','ALERT_SMTP_FROM','ALERT_SMTP_USE_SSL',
 'SMTP_HOST','SMTP_PORT','SMTP_USER','SMTP_PASSWORD','SMTP_FROM','SMTP_USE_SSL',
 'MAIL_SERVER','MAIL_PORT','MAIL_USERNAME','MAIL_PASSWORD','MAIL_FROM','MAIL_SSL_TLS'
]
for k in keys:
    print(k, '=', os.environ.get(k))
# Also print .env file if exists
p='.'
try:
    with open(os.path.join(os.path.dirname(__file__), '.env'),'r',encoding='utf-8') as f:
        print('\n.env file contents:')
        print(f.read())
except Exception as e:
    print('\n.env not readable:', e)
