import random,time

FIRE_COLORS=((255,0,0),(255,80,0),(255,160,0))
STARRY_COLORS=((255,255,255),(200,200,255),(255,255,200))
CHASE_COLORS=((255,0,0),(0,255,0),(0,0,255))
SPARKLE_COLORS=((255,0,0),(0,255,0),(0,0,255),(255,255,0),(255,0,255),(0,255,255),(255,255,255))
WAVE_LEVELS=b'\x00\x04\x09\r\x12\x16\x1b\x1f#(,159>BFKOSW[`dhlptx|\x7f\x83\x87\x8b\x8f\x92\x96\x99\x9d\xa0\xa4\xa7\xab\xae\xb1\xb4\xb7\xba\xbe\xc0\xc3\xc6\xc9\xcc\xce\xd1\xd3\xd6\xd8\xdb\xdd\xdf\xe1\xe3\xe5\xe7\xe9\xeb\xec\xee\xf0\xf1\xf3\xf4\xf5\xf6\xf7\xf8\xf9\xfa\xfb\xfc\xfd\xfd\xfe\xfe\xfe\xff\xff\xff\xff'
MUSIC_SAMPLES=12
MUSIC_NOISE_FLOOR=8
MUSIC_BASELINE_SHIFT=5
MUSIC_RISE_SHIFT=1
MUSIC_FALL_SHIFT=3
MUSIC_PEAK_MIN=24
MUSIC_PEAK_DECAY=2
MUSIC_FLASH_STRENGTH=160
MUSIC_FLASH_DECAY=24
MUSIC_BACKGROUND=(0,2,6)

def wave_level(a):
    a%=360
    if a<=90:return WAVE_LEVELS[a]
    if a<=180:return WAVE_LEVELS[180-a]
    if a<=270:return-WAVE_LEVELS[a-180]
    return-WAVE_LEVELS[360-a]
def music_state():
    return{"baseline":512,"smoothed":0,"peak":MUSIC_PEAK_MIN,"energy":0,"flash":0}
def music_update_state(adc,anim_state,sample_count=MUSIC_SAMPLES):
    if"baseline"not in anim_state:anim_state=music_state()
    baseline=anim_state["baseline"];total=0;peak_delta=0
    for _ in range(sample_count):
        sample=adc.read()
        baseline=(baseline*((1<<MUSIC_BASELINE_SHIFT)-1)+sample)>>MUSIC_BASELINE_SHIFT
        delta=sample-baseline
        if delta<0:delta=-delta
        total+=delta
        if delta>peak_delta:peak_delta=delta
    raw=(total//sample_count+peak_delta)//2
    if raw<=MUSIC_NOISE_FLOOR:raw=0
    else:raw-=MUSIC_NOISE_FLOOR
    smoothed=anim_state["smoothed"]
    if raw>smoothed:smoothed+=max(1,(raw-smoothed)>>MUSIC_RISE_SHIFT)
    elif smoothed>raw:smoothed-=max(1,(smoothed-raw)>>MUSIC_FALL_SHIFT)
    peak=anim_state["peak"]
    if smoothed>peak:peak=smoothed
    elif peak>MUSIC_PEAK_MIN:
        peak-=MUSIC_PEAK_DECAY
        if peak<MUSIC_PEAK_MIN:peak=MUSIC_PEAK_MIN
    flash=anim_state["flash"]
    if raw>smoothed+12:flash=MUSIC_FLASH_STRENGTH
    elif flash>MUSIC_FLASH_DECAY:flash-=MUSIC_FLASH_DECAY
    else:flash=0
    anim_state["baseline"]=baseline
    anim_state["smoothed"]=smoothed
    anim_state["peak"]=peak
    anim_state["energy"]=0 if peak<=0 else smoothed*255//peak
    anim_state["flash"]=flash
    return anim_state
def music_color(energy):
    if energy<85:return(0,32+energy*2,96+energy)
    if energy<170:
        energy-=85
        return(energy*2,200+energy//2,255-energy)
    energy-=170
    return(255,180-energy,120-energy//2)
def music_render(np,led_count,setb,anim_state):
    energy=anim_state["energy"];flash=anim_state["flash"]
    left=(led_count-1)//2;right=led_count//2
    span=energy*((led_count+1)//2)//255
    if energy and span<1:span=1
    bg=setb(MUSIC_BACKGROUND)
    for i in range(led_count):np[i]=bg
    for offset in range(span):
        fade=255-(offset*180//max(1,span))
        level=energy*fade//255
        rgb=music_color(level)
        if flash:
            boost=flash*(span-offset)//max(1,span)
            rgb=(min(255,rgb[0]+boost),min(255,rgb[1]+boost),min(255,rgb[2]+boost))
        li=left-offset;ri=right+offset
        if 0<=li<led_count:np[li]=setb(rgb)
        if 0<=ri<led_count:np[ri]=setb(rgb)
    np.write();time.sleep_ms(25);return anim_state
def music(np,led_count,setb,adc,anim_state):
    anim_state=music_update_state(adc,anim_state)
    return music_render(np,led_count,setb,anim_state)
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
