import random,time

FIRE_COLORS=((255,0,0),(255,80,0),(255,160,0))
STARRY_COLORS=((255,255,255),(200,200,255),(255,255,200))
CHASE_COLORS=((255,0,0),(0,255,0),(0,0,255))
SPARKLE_COLORS=((255,0,0),(0,255,0),(0,0,255),(255,255,0),(255,0,255),(0,255,255),(255,255,255))
WAVE_LEVELS=b'\x00\x04\x09\r\x12\x16\x1b\x1f#(,159>BFKOSW[`dhlptx|\x7f\x83\x87\x8b\x8f\x92\x96\x99\x9d\xa0\xa4\xa7\xab\xae\xb1\xb4\xb7\xba\xbe\xc0\xc3\xc6\xc9\xcc\xce\xd1\xd3\xd6\xd8\xdb\xdd\xdf\xe1\xe3\xe5\xe7\xe9\xeb\xec\xee\xf0\xf1\xf3\xf4\xf5\xf6\xf7\xf8\xf9\xfa\xfb\xfc\xfd\xfd\xfe\xfe\xfe\xff\xff\xff\xff'

def wave_level(a):
    a%=360
    if a<=90:return WAVE_LEVELS[a]
    if a<=180:return WAVE_LEVELS[180-a]
    if a<=270:return-WAVE_LEVELS[a-180]
    return-WAVE_LEVELS[360-a]
def rainbow(np,led_count,setb,wheel,frame_count):
    j=frame_count%256
    for i in range(led_count):np[i]=setb(wheel((i*256//led_count+j)&255))
    np.write();time.sleep_ms(20);return frame_count+1
def breath(np,setb,anim_state):
    if"s"not in anim_state:anim_state={"s":0,"d":1,"c":0}
    a=anim_state;np.fill(setb((255,0,0)));np.write();a["s"]+=a["d"]
    if a["s"]>=50:a["d"]=-1
    elif a["s"]<=0:
        a["d"]=1;a["c"]+=1
        if a["c"]>=3:anim_state={}
    time.sleep_ms(20);return anim_state
def fire(np,led_count,setb,frame_count):
    np.fill((0,0,0))
    for i in range(led_count):
        if random.getrandbits(16)/65535.0<0.3:np[i]=setb(FIRE_COLORS[random.getrandbits(8)%3])
    np.write();time.sleep_ms(50);return frame_count+1
def starry(np,led_count,setb,frame_count):
    np.fill((0,0,0))
    for i in range(led_count):
        if random.getrandbits(16)/65535.0<0.1:np[i]=setb(STARRY_COLORS[random.getrandbits(8)%3])
    np.write();time.sleep_ms(200);return frame_count+1
def wave(np,led_count,setb,frame_count,wave_level_fn):
    o=(frame_count*3)%360
    for i in range(led_count):
        a=(o+i*12)%360;s=wave_level_fn(a)
        if a==180 and s==0:np[i]=setb((254,0,0))
        elif s>0:np[i]=setb((255-s,s,0))
        else:np[i]=setb((0,255+s,-s))
    np.write();time.sleep_ms(30);return frame_count+1
def chase(np,led_count,setb,anim_state):
    if"p"not in anim_state:anim_state={"p":0}
    p=anim_state["p"];np.fill((0,0,0))
    for ci,x in enumerate(CHASE_COLORS):
        for i in range(5):
            s=5-i;pos=(p-ci*5-i)%led_count
            np[pos]=setb((x[0]*s//5,x[1]*s//5,x[2]*s//5))
    np.write();anim_state["p"]=(p+1)%40;time.sleep_ms(80);return anim_state
def sparkle(np,led_count,setb,frame_count):
    np.fill((0,0,0))
    for _ in range(led_count//5):np[random.getrandbits(8)%led_count]=setb(SPARKLE_COLORS[random.getrandbits(8)%7])
    np.write();time.sleep_ms(80);return frame_count+1
def snake(np,led_count,setb,anim_state):
    if"pos"not in anim_state:anim_state={"pos":list(range(8)),"d":1,"fp":20,"w":0}
    s=anim_state;s["w"]+=1
    if s["w"]<10:time.sleep_ms(10);return anim_state
    s["w"]=0;np.fill((0,0,0));s["pos"].append((s["pos"][-1]+s["d"])%led_count)
    if len(s["pos"])>8:s["pos"].pop(0)
    if random.getrandbits(16)/65535.0<0.05:s["d"]*=-1
    for i,p in enumerate(s["pos"]):np[p]=setb((0,int(255*(i+1)/8),0))
    np[s["fp"]]=setb((255,0,0))
    if s["pos"][-1]==s["fp"]:s["fp"]=random.getrandbits(8)%led_count
    np.write();time.sleep_ms(10);return anim_state
