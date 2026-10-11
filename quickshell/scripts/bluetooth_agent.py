#!/usr/bin/env python3
"""A BlueZ agent for a single user-requested pairing. Prompts travel over pipes."""
import json, sys, threading
import dbus, dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib
DBusGMainLoop(set_as_default=True)
bus=dbus.SystemBus(); loop=GLib.MainLoop(); pending=[]
def emit(data): print(json.dumps({'pairing':data}),flush=True)
class Rejected(dbus.DBusException): _dbus_error_name='org.bluez.Error.Rejected'
class Agent(dbus.service.Object):
    @dbus.service.method('org.bluez.Agent1', in_signature='', out_signature='')
    def Release(self): loop.quit()
    @dbus.service.method('org.bluez.Agent1', in_signature='', out_signature='')
    def Cancel(self): emit(None); loop.quit()
    def prompt(self,kind,message,reply,error):
        pending[:]=[(kind,reply,error)];emit({'kind':kind,'message':message})
    @dbus.service.method('org.bluez.Agent1',in_signature='ou',out_signature='',async_callbacks=('reply','error'))
    def RequestConfirmation(self,device,passkey,reply,error):self.prompt('confirm',f'Confirm that {passkey:06d} is shown on your device.',reply,error)
    @dbus.service.method('org.bluez.Agent1',in_signature='o',out_signature='s',async_callbacks=('reply','error'))
    def RequestPinCode(self,device,reply,error):self.prompt('pin','Enter the PIN for this device.',reply,error)
    @dbus.service.method('org.bluez.Agent1',in_signature='o',out_signature='u',async_callbacks=('reply','error'))
    def RequestPasskey(self,device,reply,error):self.prompt('passkey','Enter the six-digit passkey.',reply,error)
    @dbus.service.method('org.bluez.Agent1',in_signature='os',out_signature='')
    def DisplayPinCode(self,device,pincode):emit({'kind':'display','message':'Enter this PIN on your device: '+str(pincode)})
    @dbus.service.method('org.bluez.Agent1',in_signature='ouq',out_signature='')
    def DisplayPasskey(self,device,passkey,entered):emit({'kind':'display','message':f'Enter {passkey:06d} on your device ({entered} digits entered).'})
    @dbus.service.method('org.bluez.Agent1',in_signature='o',out_signature='',async_callbacks=('reply','error'))
    def RequestAuthorization(self,device,reply,error):self.prompt('confirm','Allow this device to pair?',reply,error)
    @dbus.service.method('org.bluez.Agent1',in_signature='os',out_signature='',async_callbacks=('reply','error'))
    def AuthorizeService(self,device,uuid,reply,error):self.prompt('confirm','Allow the requested Bluetooth service?',reply,error)
agent=Agent(bus,'/org/island/PairingAgent')
manager=dbus.Interface(bus.get_object('org.bluez','/org/bluez'),'org.bluez.AgentManager1')
manager.RegisterAgent('/org/island/PairingAgent','KeyboardDisplay')
def response(value):
    if value is None:
        if pending:pending.pop()[2](Rejected('Cancelled by user'))
        if path:
            try:dbus.Interface(bus.get_object('org.bluez',path),'org.bluez.Device1').CancelPairing()
            except dbus.DBusException:pass
        emit(None);loop.quit();return False
    if not pending:return False
    kind,reply,error=pending.pop()
    if value is None:error(Rejected('Cancelled by user'))
    elif kind=='confirm':reply()
    elif kind=='passkey':
        try:
            n=int(value)
            if not 0<=n<=999999:raise ValueError()
            reply(dbus.UInt32(n))
        except ValueError:error(Rejected('Invalid passkey'))
    else:reply(str(value))
    return False
def reader():
    for line in sys.stdin:
        try:GLib.idle_add(response,json.loads(line)['value'])
        except (ValueError,KeyError):pass
threading.Thread(target=reader,daemon=True).start()
objects=dbus.Interface(bus.get_object('org.bluez','/'),'org.freedesktop.DBus.ObjectManager').GetManagedObjects()
path=next((p for p,ifs in objects.items() if str(ifs.get('org.bluez.Device1',{}).get('Address','')).lower()==sys.argv[1].lower()),None)
def done():emit(None);loop.quit()
def failed(e):print(json.dumps({'error':'Bluetooth pairing: '+str(e),'pairing':None}),flush=True);loop.quit()
if path:
    emit({'kind':'waiting','message':'Waiting for your Bluetooth device…'})
    dbus.Interface(bus.get_object('org.bluez',path),'org.bluez.Device1').Pair(reply_handler=done,error_handler=failed,timeout=90)
    loop.run()
else:failed('Device not found. Scan again.')
try:manager.UnregisterAgent('/org/island/PairingAgent')
except dbus.DBusException:pass
