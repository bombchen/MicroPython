# ESP8266 LED Controller - UDP WiFi Config
import neopixel
from machine import Pin
import time
import random
import math
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
FIRE_COLORS = ((255, 0, 0), (255, 80, 0), (255, 160, 0))
STARRY_COLORS = ((255, 255, 255), (200, 200, 255), (255, 255, 200))
CHASE_COLORS = ((255, 0, 0), (0, 255, 0), (0, 0, 255))
SPARKLE_COLORS = (
    (255, 0, 0),
    (0, 255, 0),
    (0, 0, 255),
    (255, 255, 0),
    (255, 0, 255),
    (0, 255, 255),
    (255, 255, 255),
)
WAVE_LEVELS = tuple(int(round(math.sin(math.radians(angle))*255)) for angle in range(91))

# 效果列表
EFFECTS = ('rainbow','breath','fire','starry','wave','chase','sparkle','snake')
EFFECTS_TEXT = "|".join(EFFECTS)
CONTROL_HELP_TEXT = f"mode:({EFFECTS_TEXT}|next|prev),bright:0-255,status"
CONFIG_COMMANDS_TEXT = "Commands:config:SSID:PWD, status, list"

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
def clamp_u8(value):return max(0,min(255,int(value)))
def wave_level(angle):
    angle%=360
    if angle<=90:return WAVE_LEVELS[angle]
    if angle<=180:return WAVE_LEVELS[180-angle]
    if angle<=270:return -WAVE_LEVELS[angle-180]
    return -WAVE_LEVELS[360-angle]
def parse_control_command(cmd):
    cmd=cmd.strip().lower()
    if cmd.startswith('mode:'):return('mode',cmd.split(':',1)[1])
    if cmd.startswith('bright:'):
        try:return('brightness',clamp_u8(cmd.split(':',1)[1]))
        except:return('brightness_error',None)
    if cmd=='status':return('status',None)
    if cmd=='help':return('help',None)
    return('error',None)
def parse_config_command(cmd):
    raw=cmd.strip()
    cmd=raw.lower()
    if cmd.startswith('config:'):
        parts=raw.split(':',2)
        if len(parts)==3:return('config',(parts[1],parts[2]))
        return('error',None)
    if cmd=='status':return('status',None)
    if cmd=='list':return('list',None)
    return('error',None)
def is_timeout_error(exc):
    code=exc.args[0] if exc.args else None
    if code in (110,'timed out','ETIMEDOUT'):return True
    if isinstance(code,str):return'timed out'in code.lower()
    if len(exc.args)>1 and isinstance(exc.args[1],str):return'timed out'in exc.args[1].lower()
    return False
def recv_udp_command(sock,bufsize):
    try:
        data,addr=sock.recvfrom(bufsize)
    except OSError as exc:
        if is_timeout_error(exc):return None
        raise
    try:return data.decode().strip().lower(),addr
    except UnicodeError:return None

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
    ssid,pwd=load_cfg()
    if not ssid:return False
    print(f"WiFi: {ssid}")
    wlan=network.WLAN(network.STA_IF)
    wlan.active(True)
    wlan.connect(ssid,pwd)
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
            networks=wlan.scan()
        except OSError:
            time.sleep(0.1)
            continue
        if networks:return sorted(networks,key=lambda x:x[3],reverse=True)[:5]  # 只返回前5个
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
        packet=recv_udp_command(sock,128)
        if packet is not None:
            cmd,addr=packet
            print(f"<- {cmd}")
            cmd_type,payload=parse_config_command(cmd)

            if cmd_type=='config':
                s,p=payload
                print(f"Save: {s}")
                if save_cfg(s,p):
                    sock.sendto(b"OK!Rebooting...",addr)
                    gc.collect()
                    time.sleep(1)
                    machine.reset()
                else:sock.sendto(b"Save Failed",addr)
            elif cmd_type=='status':
                sock.sendto(b"CONFIG_MODE",addr)
            elif cmd_type=='list':
                if ssids:
                    sock.sendto(f"WIFIS:{','.join(ssids)}".encode(),addr)
                else:sock.sendto(b"Scanning...",addr)
            elif cmd.startswith('config:'):
                sock.sendto(b"Error: use config:SSID:PWD",addr)
            else:sock.sendto(CONFIG_COMMANDS_TEXT.encode(),addr)
            gc.collect()

        # 每5秒广播 WiFi 列表
        if time.time()-last_bcast>5:
            ssids=[n[0].decode('utf-8','ignore')for n in scan_wifis()]
            if ssids:
                msg=f"WIFIS:{','.join(ssids)}"
                sock.sendto(msg.encode(),('255.255.255.255',CFG_PORT))
                print(f"-> Broadcast: {len(ssids)} networks")
            last_bcast=time.time()
            gc.collect()

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
    idle_cycles=0

    while True:
        packet=recv_udp_command(sock,64)
        if packet is not None:
            cmd,addr=packet
            print(f"<- {cmd}")

            global mode,brightness
            cmd_type,payload=parse_control_command(cmd)

            if cmd_type=='mode':
                m=payload
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
            elif cmd_type=='brightness':
                brightness=payload
                sock.sendto(f"OK:{brightness}".encode(),addr)
            elif cmd_type=='brightness_error':
                sock.sendto(b"ERROR",addr)
            elif cmd_type=='status':
                sock.sendto(f"MODE:{mode};BRIGHT:{brightness}".encode(),addr)
            elif cmd_type=='help':
                sock.sendto(CONTROL_HELP_TEXT.encode(),addr)
            else:sock.sendto(b"Error",addr)
            gc.collect()

        try:ANIM_FUNCS[mode]()
        except:pass
        idle_cycles=(idle_cycles+1)&31
        if idle_cycles==0:gc.collect()

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
    for i in range(LED_COUNT):
        if rnd()<0.3:np[i]=setb(FIRE_COLORS[random.getrandbits(8)%len(FIRE_COLORS)])
    np.write();time.sleep_ms(50)
def starry():
    global frame_count;frame_count+=1;np.fill((0,0,0))
    for i in range(LED_COUNT):
        if rnd()<0.1:np[i]=setb(STARRY_COLORS[random.getrandbits(8)%len(STARRY_COLORS)])
    np.write();time.sleep_ms(200)
def wave():
    global frame_count;o=(frame_count*3)%360;frame_count+=1
    for i in range(LED_COUNT):
        a=(o+i*12)%360;s=wave_level(a)
        if a==180 and s==0:np[i]=setb((254,0,0))
        elif s>0:np[i]=setb((255-s,s,0))
        else:np[i]=setb((0,255+s,-s))
    np.write();time.sleep_ms(30)
def chase():
    global anim_state
    if 'p' not in anim_state:anim_state={'p':0}
    p=anim_state['p'];np.fill((0,0,0))
    for ci,x in enumerate(CHASE_COLORS):
        for i in range(5):
            pos=(p-ci*5-i)%LED_COUNT
            scale=5-i
            np[pos]=setb((x[0]*scale//5,x[1]*scale//5,x[2]*scale//5))
    np.write();anim_state['p']=(p+1)%40;time.sleep_ms(80)
def sparkle():
    global frame_count;frame_count+=1;np.fill((0,0,0))
    for _ in range(int(LED_COUNT*0.2)):
        np[random.getrandbits(8)%LED_COUNT]=setb(SPARKLE_COLORS[random.getrandbits(8)%len(SPARKLE_COLORS)])
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
    np = neopixel.NeoPixel(Pin(LED_PIN, Pin.OUT), LED_COUNT)
    np.fill((0, 0, 0))
    np.write()
    init_anim()

    print("=" * 40)
    print("ESP8266 LED")
    print("=" * 40)

    if try_wifi():
        control_mode()
    else:
        config_mode()


if __name__ == "__main__":
    main()
