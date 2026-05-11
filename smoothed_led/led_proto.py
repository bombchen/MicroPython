def clamp_u8(v):
    try:v=int(v)
    except:raise
    return 0 if v<0 else 255 if v>255 else v
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
    if low=="diag":return("diag",None)
    if low=="reset":return("reset",None)
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
