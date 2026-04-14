# ESP8266 LED Controller - UDP WiFi Config
import neopixel
from machine import Pin
import time
import random
import network
import socket
import gc
import machine

# ==================== 配置 ====================
LED_PIN = 2
LED_COUNT = 30
CTRL_PORT = 8888    # UDP 控制端口
CFG_PORT = 8889     # UDP 配置端口

# AP 配置
AP_SSID = "LED_Config"

# 全局状态
mode = "rainbow"
brightness = 180
np = None
frame_count = 0
anim_state = {}

# 效果列表
EFFECTS = ['rainbow','breath','fire','starry','wave','chase','sparkle','snake']

# ==================== 工具函数 ====================
def setb(c):return tuple(int(x*brightness/255) for x in c)
def rnd():return random.getrandbits(16)/65535.0
def wheel(p):
    p=255-p
    if p<85:return(255-p*3,0,p*3)
    if p<170:p-=85;return(0,p*3,255-p*3)
    p-=170;return(p*3,255-p*3,0)
def init_anim():
    global frame_count,anim_state
    frame_count=0
    anim_state={}
def get_mode_idx(m):
    try:return EFFECTS.index(m)
    except:return 0

# ==================== WiFi 配置 ====================
def save_cfg(ssid,pwd):
    try:
        with open('w.cfg','w')as f:
            f.write(ssid+'\n'+pwd)
        return True
    except:return False

def load_cfg():
    try:
        with open('w.cfg','r')as f:
            return f.readline().strip(),f.readline().strip()
    except:return None,None

def try_wifi():
    s,p=load_cfg()
    if not s:return False
    print(f"WiFi: {s}")
    wlan=network.WLAN(network.STA_IF)
    wlan.active(True)
    wlan.connect(s,p)
    for _ in range(50):
        if wlan.isconnected():
            print(f"OK! {wlan.ifconfig()[0]}")
            return True
        time.sleep(0.1)
    print("Fail")
    wlan.disconnect()
    return False

def scan_wifis():
    wlan=network.WLAN(network.STA_IF)
    wlan.active(True)
    for _ in range(20):
        try:
            n=wlan.scan()
            if n:return sorted(n,key=lambda x:x[3],reverse=True)[:5]  # 只返回前5个
        except:time.sleep(0.1)
    return []

# ==================== 配置模式 (UDP 广播) ====================
def config_mode():
    network.WLAN(network.STA_IF).active(False)
    ap=network.WLAN(network.AP_IF)
    ap.active(True)
    ap.config(essid=AP_SSID,security=0)
    print("="*40)
    print("CONFIG MODE")
    print("="*40)
    print(f"1. Join WiFi: {AP_SSID}")
    print("2. Send: config:SSID:PASSWORD")
    print("   to port 8889")
    print("")

    sock=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
    sock.bind(('0.0.0.0',CFG_PORT))
    sock.setsockopt(socket.SOL_SOCKET,socket.SO_BROADCAST,1)
    sock.settimeout(1)

    last_bcast=0
    ssids=[]

    while True:
        try:
            data,addr=sock.recvfrom(128)
            cmd=data.decode().strip().lower()
            print(f"<- {cmd}")

            if cmd.startswith('config:'):
                parts=cmd.split(':',2)
                if len(parts)==3:
                    s,p=parts[1],parts[2]
                    print(f"Save: {s}")
                    if save_cfg(s,p):
                        sock.sendto(b"OK!Rebooting...",addr)
                        time.sleep(1)
                        machine.reset()
                    else:sock.sendto(b"Save Failed",addr)
                else:sock.sendto(b"Error: use config:SSID:PWD",addr)
            elif cmd=='status':
                sock.sendto(b"CONFIG_MODE",addr)
            elif cmd=='list':
                if ssids:
                    sock.sendto(f"WIFIS:{','.join(ssids)}".encode(),addr)
                else:sock.sendto(b"Scanning...",addr)
            else:sock.sendto(b"Commands:config:SSID:PWD, status, list",addr)
            gc.collect()
        except:
            pass

        # 每5秒广播 WiFi 列表
        if time.time()-last_bcast>5:
            ssids=[n[0].decode('utf-8','ignore')for n in scan_wifis()]
            if ssids:
                msg=f"WIFIS:{','.join(ssids)}"
                sock.sendto(msg.encode(),('255.255.255.255',CFG_PORT))
                print(f"-> Broadcast: {len(ssids)} networks")
            last_bcast=time.time()

# ==================== 控制模式 (UDP 控制) ====================
def control_mode():
    sock=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
    sock.bind(('0.0.0.0',CTRL_PORT))
    sock.settimeout(0.05)

    print("="*40)
    print("CONTROL MODE")
    print("="*40)
    print(f"Port: {CTRL_PORT}")
    print(f"Effects: {','.join(EFFECTS)}")

    while True:
        try:
            data,addr=sock.recvfrom(64)
            cmd=data.decode().strip().lower()
            print(f"<- {cmd}")

            global mode,brightness
            if cmd.startswith('mode:'):
                m=cmd.split(':')[1]
                if m=='next':
                    mode=EFFECTS[(get_mode_idx(mode)+1)%len(EFFECTS)]
                    init_anim()
                elif m=='prev':
                    mode=EFFECTS[(get_mode_idx(mode)-1)%len(EFFECTS)]
                    init_anim()
                elif m in ANIM_FUNCS:
                    mode=m
                    init_anim()
                sock.sendto(f"OK:{mode}".encode(),addr)
            elif cmd.startswith('bright:'):
                try:
                    brightness=max(0,min(255,int(cmd.split(':')[1])))
                    sock.sendto(f"OK:{brightness}".encode(),addr)
                except:sock.sendto(b"ERROR",addr)
            elif cmd=='status':
                sock.sendto(f"MODE:{mode};BRIGHT:{brightness}".encode(),addr)
            elif cmd=='help':
                sock.sendto(f"mode:({'|'.join(EFFECTS)}|next|prev),bright:0-255,status".encode(),addr)
            else:sock.sendto(b"Error",addr)
            gc.collect()
        except:pass

        try:ANIM_FUNCS[mode]()
        except:pass

# ==================== 动画函数 ====================
def rainbow():
    global frame_count
    j=frame_count%256
    for i in range(LED_COUNT):np[i]=setb(wheel((i*256//LED_COUNT+j)&255))
    np.write();frame_count+=1;time.sleep_ms(20)
def breath():
    global anim_state
    if 's' not in anim_state:anim_state={'s':0,'d':1,'c':0}
    a=anim_state;np.fill(setb((255,0,0)));np.write()
    a['s']+=a['d']
    if a['s']>=50:a['d']=-1
    elif a['s']<=0:
        a['d']=1;a['c']+=1
        if a['c']>=3:anim_state={}
    time.sleep_ms(20)
def fire():
    global frame_count;frame_count+=1;np.fill((0,0,0))
    c=[(255,0,0),(255,80,0),(255,160,0)]
    for i in range(LED_COUNT):
        if rnd()<0.3:np[i]=setb(c[random.getrandbits(8)%3])
    np.write();time.sleep_ms(50)
def starry():
    global frame_count;frame_count+=1;np.fill((0,0,0))
    c=[(255,255,255),(200,200,255),(255,255,200)]
    for i in range(LED_COUNT):
        if rnd()<0.1:np[i]=setb(c[random.getrandbits(8)%3])
    np.write();time.sleep_ms(200)
def wave():
    global frame_count;o=(frame_count*3)%360;frame_count+=1
    for i in range(LED_COUNT):
        s=__import__('math').sin(__import__('math').radians((o+i*12)%360))
        if s>0:np[i]=setb((int(255*(1-s)),int(255*s),0))
        else:np[i]=setb((0,int(255*(1+s)),int(255*(-s))))
    np.write();time.sleep_ms(30)
def chase():
    global anim_state
    if 'p' not in anim_state:anim_state={'p':0}
    p=anim_state['p'];c=[(255,0,0),(0,255,0),(0,0,255)];np.fill((0,0,0))
    for ci,x in enumerate(c):
        for i in range(5):
            pos=(p-ci*5-i)%LED_COUNT
            np[pos]=setb([int(y*(5-i)/5)for y in x])
    np.write();anim_state['p']=(p+1)%40;time.sleep_ms(80)
def sparkle():
    global frame_count;frame_count+=1;np.fill((0,0,0))
    c=[(255,0,0),(0,255,0),(0,0,255),(255,255,0),(255,0,255),(0,255,255),(255,255,255)]
    for _ in range(int(LED_COUNT*0.2)):
        np[random.getrandbits(8)%LED_COUNT]=setb(c[random.getrandbits(8)%7])
    np.write();time.sleep_ms(80)
def snake():
    global anim_state
    if 'pos'not in anim_state:anim_state={'pos':list(range(8)),'d':1,'fp':20,'w':0}
    s=anim_state;s['w']+=1
    if s['w']<10:time.sleep_ms(10);return
    s['w']=0;np.fill((0,0,0))
    s['pos'].append((s['pos'][-1]+s['d'])%LED_COUNT)
    if len(s['pos'])>8:s['pos'].pop(0)
    if rnd()<0.05:s['d']*=-1
    for i,p in enumerate(s['pos']):np[p]=setb((0,int(255*(i+1)/8),0))
    np[s['fp']]=setb((255,0,0))
    if s['pos'][-1]==s['fp']:s['fp']=random.getrandbits(8)%LED_COUNT
    np.write();time.sleep_ms(10)

ANIM_FUNCS={'rainbow':rainbow,'breath':breath,'fire':fire,'starry':starry,'wave':wave,'chase':chase,'sparkle':sparkle,'snake':snake}

# ==================== 主程序 ====================
def main():
    global np
    np=neopixel.NeoPixel(Pin(LED_PIN,Pin.OUT),LED_COUNT)
    np.fill((0,0,0));np.write();init_anim()

    print("="*40)
    print("ESP8266 LED")
    print("="*40)

    if try_wifi():
        control_mode()
    else:
        config_mode()

main()
