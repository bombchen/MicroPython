import gc
import machine
import network
import neopixel
import os
import socket
import time
from machine import Pin

import led_effects as fx
import led_proto as proto

LED_PIN = 2
LED_COUNT = 30
CTRL_PORT = 8888
CFG_PORT = 8889
AP_SSID = "LED_Config"
WIFI_CONNECT_ATTEMPTS = 150

mode = "rainbow"
brightness = 180
np = None
frame_count = 0
anim_state = {}

FIRE_COLORS = fx.FIRE_COLORS
STARRY_COLORS = fx.STARRY_COLORS
CHASE_COLORS = fx.CHASE_COLORS
SPARKLE_COLORS = fx.SPARKLE_COLORS
WAVE_LEVELS = fx.WAVE_LEVELS
EFFECTS = ("rainbow", "breath", "fire", "starry", "wave", "chase", "sparkle", "snake")
EFFECTS_TEXT = "|".join(EFFECTS)
CONTROL_HELP_TEXT = "mode:(%s|next|prev),bright:0-255,status" % EFFECTS_TEXT
CONFIG_COMMANDS_TEXT = "Commands:config:SSID:PWD, status, list, diag, reset"

clamp_u8 = proto.clamp_u8
wave_level = fx.wave_level
parse_control_command = proto.parse_control_command
parse_config_command = proto.parse_config_command
is_timeout_error = proto.is_timeout_error
recv_udp_command = proto.recv_udp_command


def setb(c):
    b = brightness
    return (c[0] * b // 255, c[1] * b // 255, c[2] * b // 255)


def wheel(p):
    p = 255 - p
    if p < 85:
        return (255 - p * 3, 0, p * 3)
    if p < 170:
        p -= 85
        return (0, p * 3, 255 - p * 3)
    p -= 170
    return (p * 3, 255 - p * 3, 0)


def init_anim():
    global frame_count, anim_state
    frame_count = 0
    anim_state = {}


def get_mode_idx(m):
    try:
        return EFFECTS.index(m)
    except ValueError:
        return 0


def save_cfg(ssid, pwd):
    try:
        with open("w.cfg", "w") as f:
            f.write(ssid + "\n" + pwd)
        return True
    except OSError:
        return False


def load_cfg():
    try:
        with open("w.cfg", "r") as f:
            return f.readline().strip(), f.readline().strip()
    except OSError:
        return None, None


def delete_cfg():
    try:
        os.remove("w.cfg")
    except OSError as exc:
        if exc.args and exc.args[0] == 2:
            return True
        return False
    return True


def safe_wifi_status(wlan):
    try:
        return wlan.status()
    except Exception:
        return None


def safe_ifconfig(wlan):
    try:
        return wlan.ifconfig()
    except Exception:
        return None


def decode_ssid(value):
    try:
        return value.decode("utf-8", "ignore")
    except Exception:
        return ""


def format_ifconfig(cfg):
    if not cfg:
        return "?"
    return ",".join(cfg)


def scan_wifis():
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    for _ in range(20):
        try:
            networks = wlan.scan()
        except OSError:
            time.sleep(0.1)
            continue
        if networks:
            networks.sort(key=lambda item: item[3], reverse=True)
            return networks[:5]
    return []


def list_visible_ssids():
    ssids = []
    for entry in scan_wifis():
        ssid = decode_ssid(entry[0])
        if ssid:
            ssids.append(ssid)
    return ssids


def build_wifi_diag():
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    status = safe_wifi_status(wlan)
    cfg = safe_ifconfig(wlan)
    return "DIAG:status=%s;ifconfig=%s" % (
        status if status is not None else "?",
        format_ifconfig(cfg),
    )


def handle_config_packet(sock, raw, addr):
    print("<- %s" % raw.lower())
    kind, payload = parse_config_command(raw)

    if kind == "config":
        ssid, password = payload
        print("Save: %s" % ssid)
        if save_cfg(ssid, password):
            sock.sendto(b"OK!Rebooting...", addr)
            gc.collect()
            time.sleep(1)
            machine.reset()
        else:
            sock.sendto(b"Save Failed", addr)
    elif kind == "status":
        sock.sendto(b"CONFIG_MODE", addr)
    elif kind == "list":
        ssids = list_visible_ssids()
        if ssids:
            sock.sendto(("WIFIS:" + ",".join(ssids)).encode(), addr)
        else:
            sock.sendto(b"Scanning...", addr)
    elif kind == "diag":
        sock.sendto(build_wifi_diag().encode(), addr)
    elif kind == "reset":
        if delete_cfg():
            sock.sendto(b"OK!Rebooting...", addr)
            gc.collect()
            time.sleep(1)
            machine.reset()
        else:
            sock.sendto(b"Reset Failed", addr)
    elif raw.lower().startswith("config:"):
        sock.sendto(b"Error: use config:SSID:PWD", addr)
    else:
        sock.sendto(CONFIG_COMMANDS_TEXT.encode(), addr)
    gc.collect()


def try_wifi():
    ssid, password = load_cfg()
    if not ssid:
        return False
    print("WiFi: %s" % ssid)
    wlan = network.WLAN(network.STA_IF)
    wlan.active(False)
    time.sleep(0.1)
    wlan.active(True)
    time.sleep(0.1)
    gc.collect()
    wlan.connect(ssid, password)
    for _ in range(WIFI_CONNECT_ATTEMPTS):
        if wlan.isconnected():
            print("OK! %s" % wlan.ifconfig()[0])
            return True
        time.sleep(0.1)
    print("Fail")
    status = safe_wifi_status(wlan)
    if status is not None:
        print("WiFi status: %s" % status)
    cfg = safe_ifconfig(wlan)
    if cfg is not None:
        print("ifconfig: %s" % (cfg,))
    wlan.disconnect()
    return False


def config_mode():
    network.WLAN(network.STA_IF).active(False)
    ap = network.WLAN(network.AP_IF)
    ap.active(True)
    ap.config(essid=AP_SSID, security=0)
    print("=" * 40)
    print("CONFIG MODE")
    print("=" * 40)
    print("1. Join WiFi: %s" % AP_SSID)
    print("2. Send: config:SSID:PASSWORD")
    print("   to port 8889")
    print("3. Optional: status | list | diag")
    print("")

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("0.0.0.0", CFG_PORT))
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.settimeout(1)

    while True:
        pkt = recv_udp_command(sock, 128)
        if pkt is None:
            continue

        raw, addr = pkt
        handle_config_packet(sock, raw, addr)


def control_mode():
    global mode, brightness
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("0.0.0.0", CTRL_PORT))
    sock.settimeout(0.05)
    cfg_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    cfg_sock.bind(("0.0.0.0", CFG_PORT))
    cfg_sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    cfg_sock.settimeout(0.0)
    print("=" * 40)
    print("CONTROL MODE")
    print("=" * 40)
    print("Port: %d" % CTRL_PORT)
    print("Effects: %s" % ",".join(EFFECTS))
    idle = 0
    while True:
        cfg_pkt = recv_udp_command(cfg_sock, 128)
        if cfg_pkt is not None:
            raw, addr = cfg_pkt
            handle_config_packet(cfg_sock, raw, addr)

        pkt = recv_udp_command(sock, 64)
        if pkt is not None:
            cmd, addr = pkt
            print("<- %s" % cmd)
            kind, payload = parse_control_command(cmd)
            if kind == "mode":
                if payload == "next":
                    mode = EFFECTS[(get_mode_idx(mode) + 1) % len(EFFECTS)]
                    init_anim()
                elif payload == "prev":
                    mode = EFFECTS[(get_mode_idx(mode) - 1) % len(EFFECTS)]
                    init_anim()
                elif payload in ANIM_FUNCS:
                    mode = payload
                    init_anim()
                sock.sendto(("OK:%s" % mode).encode(), addr)
            elif kind == "brightness":
                brightness = payload
                sock.sendto(("OK:%d" % brightness).encode(), addr)
            elif kind == "brightness_error":
                sock.sendto(b"ERROR", addr)
            elif kind == "status":
                sock.sendto(("MODE:%s;BRIGHT:%d" % (mode, brightness)).encode(), addr)
            elif kind == "help":
                sock.sendto(CONTROL_HELP_TEXT.encode(), addr)
            else:
                sock.sendto(b"Error", addr)
            gc.collect()
        try:
            ANIM_FUNCS[mode]()
        except Exception:
            pass
        idle = (idle + 1) & 31
        if not idle:
            gc.collect()


def rainbow():
    global frame_count
    frame_count = fx.rainbow(np, LED_COUNT, setb, wheel, frame_count)


def breath():
    global anim_state
    anim_state = fx.breath(np, setb, anim_state)


def fire():
    global frame_count
    frame_count = fx.fire(np, LED_COUNT, setb, frame_count)


def starry():
    global frame_count
    frame_count = fx.starry(np, LED_COUNT, setb, frame_count)


def wave():
    global frame_count
    frame_count = fx.wave(np, LED_COUNT, setb, frame_count, wave_level)


def chase():
    global anim_state
    anim_state = fx.chase(np, LED_COUNT, setb, anim_state)


def sparkle():
    global frame_count
    frame_count = fx.sparkle(np, LED_COUNT, setb, frame_count)


def snake():
    global anim_state
    anim_state = fx.snake(np, LED_COUNT, setb, anim_state)


ANIM_FUNCS = {
    "rainbow": rainbow,
    "breath": breath,
    "fire": fire,
    "starry": starry,
    "wave": wave,
    "chase": chase,
    "sparkle": sparkle,
    "snake": snake,
}


def main():
    global np
    np = neopixel.NeoPixel(Pin(LED_PIN, Pin.OUT), LED_COUNT)
    np.fill((0, 0, 0))
    np.write()
    init_anim()
    gc.collect()
    print("=" * 40)
    print("ESP8266 LED")
    print("=" * 40)
    if try_wifi():
        control_mode()
    else:
        gc.collect()
        config_mode()


if __name__ == "__main__":
    main()
