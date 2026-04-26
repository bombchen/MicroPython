import neopixel,time,random,network,socket,gc,machine
from machine import Pin

LED_PIN=2;LED_COUNT=30;CTRL_PORT=8888;CFG_PORT=8889;AP_SSID="LED_Config"
mode="rainbow";brightness=180;np=None;frame_count=0;anim_state={}
FIRE_COLORS=((255,0,0),(255,80,0),(255,160,0))
STARRY_COLORS=((255,255,255),(200,200,255),(255,255,200))
CHASE_COLORS=((255,0,0),(0,255,0),(0,0,255))
SPARKLE_COLORS=((255,0,0),(0,255,0),(0,0,255),(255,255,0),(255,0,255),(0,255,255),(255,255,255))
WAVE_LEVELS=b'\x00\x04\x09\r\x12\x16\x1b\x1f#(,159>BFKOSW[`dhlptx|\x7f\x83\x87\x8b\x8f\x92\x96\x99\x9d\xa0\xa4\xa7\xab\xae\xb1\xb4\xb7\xba\xbe\xc0\xc3\xc6\xc9\xcc\xce\xd1\xd3\xd6\xd8\xdb\xdd\xdf\xe1\xe3\xe5\xe7\xe9\xeb\xec\xee\xf0\xf1\xf3\xf4\xf5\xf6\xf7\xf8\xf9\xfa\xfb\xfc\xfd\xfd\xfe\xfe\xfe\xff\xff\xff\xff'
EFFECTS=("rainbow","breath","fire","starry","wave","chase","sparkle","snake")
EFFECTS_TEXT="|".join(EFFECTS)
CONTROL_HELP_TEXT="mode:(%s|next|prev),bright:0-255,status"%EFFECTS_TEXT
CONFIG_COMMANDS_TEXT="Commands:config:SSID:PWD, status, list"

def setb(c):
    b=brightness
    return(c[0]*b//255,c[1]*b//255,c[2]*b//255)
def rnd():return random.getrandbits(16)/65535.0
def wheel(p):
    p=255-p
    if p<85:return(255-p*3,0,p*3)
    if p<170:p-=85;return(0,p*3,255-p*3)
    p-=170;return(p*3,255-p*3,0)
def init_anim():
    global frame_count,anim_state
    frame_count=0;anim_state={}
def get_mode_idx(m):
    try:return EFFECTS.index(m)
    except:return 0
def clamp_u8(v):
    try:v=int(v)
    except:raise
    return 0 if v<0 else 255 if v>255 else v
def wave_level(a):
    a%=360
    if a<=90:return WAVE_LEVELS[a]
    if a<=180:return WAVE_LEVELS[180-a]
    if a<=270:return-WAVE_LEVELS[a-180]
    return-WAVE_LEVELS[360-a]
def parse_control_command(cmd):
    cmd=cmd.strip().lower()
    if cmd.startswith("mode:"):return("mode",cmd[5:])
    if cmd.startswith("bright:"):
        try:return("brightness",clamp_u8(cmd[7:]))
        except:return("brightness_error",None)
    if cmd=="status":return("status",None)
    if cmd=="help":return("help",None)
    return("error",None)
def parse_config_command(cmd):
    raw=cmd.strip();low=raw.lower()
    if low.startswith("config:"):
        p=raw.split(":",2)
        return("config",(p[1],p[2])) if len(p)==3 else("error",None)
    if low=="status":return("status",None)
    if low=="list":return("list",None)
    return("error",None)
def is_timeout_error(exc):
    a=exc.args
    if not a:return False
    c=a[0]
    return c in(110,"timed out","ETIMEDOUT")or(isinstance(c,str)and"timed out"in c.lower())or(len(a)>1 and isinstance(a[1],str)and"timed out"in a[1].lower())
def recv_udp_command(sock,n):
    try:data,addr=sock.recvfrom(n)
    except OSError as exc:
        if is_timeout_error(exc):return None
        raise
    try:return data.decode().strip(),addr
    except UnicodeError:return None

def save_cfg(ssid,pwd):
    try:
        with open("w.cfg","w")as f:f.write(ssid+"\n"+pwd)
        return True
    except:return False
def load_cfg():
    try:
        with open("w.cfg","r")as f:return f.readline().strip(),f.readline().strip()
    except:return None,None
def try_wifi():
    s,p=load_cfg()
    if not s:return False
    print("WiFi: %s"%s)
    wlan=network.WLAN(network.STA_IF);wlan.active(True);wlan.connect(s,p)
    for _ in range(50):
        if wlan.isconnected():
            print("OK! %s"%wlan.ifconfig()[0]);return True
        time.sleep(0.1)
    print("Fail");wlan.disconnect();return False
def scan_wifis():
    wlan=network.WLAN(network.STA_IF);wlan.active(True)
    for _ in range(20):
        try:n=wlan.scan()
        except OSError:
            time.sleep(0.1);continue
        if n:return sorted(n,key=lambda x:x[3],reverse=True)[:5]
    return[]

def config_mode():
    network.WLAN(network.STA_IF).active(False)
    ap=network.WLAN(network.AP_IF);ap.active(True);ap.config(essid=AP_SSID,security=0)
    print("="*40);print("CONFIG MODE");print("="*40)
    print("1. Join WiFi: %s"%AP_SSID);print("2. Send: config:SSID:PASSWORD");print("   to port 8889");print("")
    sock=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
    sock.bind(("0.0.0.0",CFG_PORT));sock.setsockopt(socket.SOL_SOCKET,socket.SO_BROADCAST,1);sock.settimeout(1)
    last=0;ssids=[]
    while True:
        pkt=recv_udp_command(sock,128)
        if pkt is not None:
            raw,addr=pkt;cmd=raw.lower();print("<- %s"%cmd);t,p=parse_config_command(raw)
            if t=="config":
                s,w=p;print("Save: %s"%s)
                if save_cfg(s,w):
                    sock.sendto(b"OK!Rebooting...",addr);gc.collect();time.sleep(1);machine.reset()
                else:sock.sendto(b"Save Failed",addr)
            elif t=="status":sock.sendto(b"CONFIG_MODE",addr)
            elif t=="list":sock.sendto(("WIFIS:"+",".join(ssids)).encode() if ssids else b"Scanning...",addr)
            elif cmd.startswith("config:"):sock.sendto(b"Error: use config:SSID:PWD",addr)
            else:sock.sendto(CONFIG_COMMANDS_TEXT.encode(),addr)
            gc.collect()
        if time.time()-last>5:
            ssids=[n[0].decode("utf-8","ignore")for n in scan_wifis()]
            if ssids:
                sock.sendto(("WIFIS:"+",".join(ssids)).encode(),("255.255.255.255",CFG_PORT))
                print("-> Broadcast: %d networks"%len(ssids))
            last=time.time();gc.collect()

def control_mode():
    global mode,brightness
    sock=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
    sock.bind(("0.0.0.0",CTRL_PORT));sock.settimeout(0.05)
    print("="*40);print("CONTROL MODE");print("="*40)
    print("Port: %d"%CTRL_PORT);print("Effects: %s"%(",".join(EFFECTS)))
    idle=0
    while True:
        pkt=recv_udp_command(sock,64)
        if pkt is not None:
            cmd,addr=pkt;print("<- %s"%cmd);t,p=parse_control_command(cmd)
            if t=="mode":
                if p=="next":mode=EFFECTS[(get_mode_idx(mode)+1)%len(EFFECTS)];init_anim()
                elif p=="prev":mode=EFFECTS[(get_mode_idx(mode)-1)%len(EFFECTS)];init_anim()
                elif p in ANIM_FUNCS:mode=p;init_anim()
                sock.sendto(("OK:%s"%mode).encode(),addr)
            elif t=="brightness":brightness=p;sock.sendto(("OK:%d"%brightness).encode(),addr)
            elif t=="brightness_error":sock.sendto(b"ERROR",addr)
            elif t=="status":sock.sendto(("MODE:%s;BRIGHT:%d"%(mode,brightness)).encode(),addr)
            elif t=="help":sock.sendto(CONTROL_HELP_TEXT.encode(),addr)
            else:sock.sendto(b"Error",addr)
            gc.collect()
        try:ANIM_FUNCS[mode]()
        except:pass
        idle=(idle+1)&31
        if not idle:gc.collect()

def rainbow():
    global frame_count
    j=frame_count%256
    for i in range(LED_COUNT):np[i]=setb(wheel((i*256//LED_COUNT+j)&255))
    np.write();frame_count+=1;time.sleep_ms(20)
def breath():
    global anim_state
    if"s"not in anim_state:anim_state={"s":0,"d":1,"c":0}
    a=anim_state;np.fill(setb((255,0,0)));np.write();a["s"]+=a["d"]
    if a["s"]>=50:a["d"]=-1
    elif a["s"]<=0:
        a["d"]=1;a["c"]+=1
        if a["c"]>=3:anim_state={}
    time.sleep_ms(20)
def fire():
    global frame_count
    frame_count+=1;np.fill((0,0,0))
    for i in range(LED_COUNT):
        if rnd()<0.3:np[i]=setb(FIRE_COLORS[random.getrandbits(8)%3])
    np.write();time.sleep_ms(50)
def starry():
    global frame_count
    frame_count+=1;np.fill((0,0,0))
    for i in range(LED_COUNT):
        if rnd()<0.1:np[i]=setb(STARRY_COLORS[random.getrandbits(8)%3])
    np.write();time.sleep_ms(200)
def wave():
    global frame_count
    o=(frame_count*3)%360;frame_count+=1
    for i in range(LED_COUNT):
        a=(o+i*12)%360;s=wave_level(a)
        if a==180 and s==0:np[i]=setb((254,0,0))
        elif s>0:np[i]=setb((255-s,s,0))
        else:np[i]=setb((0,255+s,-s))
    np.write();time.sleep_ms(30)
def chase():
    global anim_state
    if"p"not in anim_state:anim_state={"p":0}
    p=anim_state["p"];np.fill((0,0,0))
    for ci,x in enumerate(CHASE_COLORS):
        for i in range(5):
            s=5-i;pos=(p-ci*5-i)%LED_COUNT
            np[pos]=setb((x[0]*s//5,x[1]*s//5,x[2]*s//5))
    np.write();anim_state["p"]=(p+1)%40;time.sleep_ms(80)
def sparkle():
    global frame_count
    frame_count+=1;np.fill((0,0,0))
    for _ in range(LED_COUNT//5):np[random.getrandbits(8)%LED_COUNT]=setb(SPARKLE_COLORS[random.getrandbits(8)%7])
    np.write();time.sleep_ms(80)
def snake():
    global anim_state
    if"pos"not in anim_state:anim_state={"pos":list(range(8)),"d":1,"fp":20,"w":0}
    s=anim_state;s["w"]+=1
    if s["w"]<10:time.sleep_ms(10);return
    s["w"]=0;np.fill((0,0,0));s["pos"].append((s["pos"][-1]+s["d"])%LED_COUNT)
    if len(s["pos"])>8:s["pos"].pop(0)
    if rnd()<0.05:s["d"]*=-1
    for i,p in enumerate(s["pos"]):np[p]=setb((0,int(255*(i+1)/8),0))
    np[s["fp"]]=setb((255,0,0))
    if s["pos"][-1]==s["fp"]:s["fp"]=random.getrandbits(8)%LED_COUNT
    np.write();time.sleep_ms(10)

ANIM_FUNCS={"rainbow":rainbow,"breath":breath,"fire":fire,"starry":starry,"wave":wave,"chase":chase,"sparkle":sparkle,"snake":snake}

def main():
    global np
    np=neopixel.NeoPixel(Pin(LED_PIN,Pin.OUT),LED_COUNT)
    np.fill((0,0,0));np.write();init_anim()
    print("="*40);print("ESP8266 LED");print("="*40)
    if try_wifi():control_mode()
    else:config_mode()

if __name__=="__main__":
    main()
