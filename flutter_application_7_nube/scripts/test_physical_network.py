"""Prueba de radios Android; restaura su estado aunque falle Flutter."""
import os
import subprocess

ADB = '/home/job-valenzuela/Android/Sdk/platform-tools/adb'
DEVICE = '5d88cfa1'
def adb(*args):
    return subprocess.check_output([ADB, '-s', DEVICE, 'shell', *args], text=True).strip()

wifi = adb('settings', 'get', 'global', 'wifi_on') == '1'
data = adb('settings', 'get', 'global', 'mobile_data') == '1'
def restore():
    adb('svc', 'wifi', 'enable' if wifi else 'disable')
    adb('svc', 'data', 'enable' if data else 'disable')

process = None
try:
    env = dict(os.environ, JAVA_HOME='/snap/android-studio/current/jbr')
    process = subprocess.Popen(['flutter', 'test', 'integration_test/physical_network_test.dart',
        '-d', DEVICE, '--dart-define-from-file=config/supabase.json'],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env)
    for line in process.stdout:
        print(line, end='', flush=True)
        if 'SYNCLAB_DISABLE_NETWORK' in line:
            adb('svc', 'wifi', 'disable')
            adb('svc', 'data', 'disable')
            print('ADB: Wi-Fi y datos apagados.', flush=True)
        if 'SYNCLAB_RESTORE_NETWORK' in line:
            restore()
            print('ADB: radios restauradas al estado original.', flush=True)
    result = process.wait()
finally:
    restore()
    if process is not None and process.poll() is None:
        process.terminate()
raise SystemExit(result)
