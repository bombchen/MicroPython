import ast
import importlib.util
import math
import pytest
import sys
import threading
import time
import types
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BOOT_PATH = ROOT / "boot.py"
MAIN_PATH = ROOT / "main.py"


def _load_main_module(monkeypatch):
    calls = {
        "pin_inits": 0,
        "neopixel_inits": 0,
        "wlan_inits": 0,
        "machine_reset_calls": 0,
    }
    machine = types.ModuleType("machine")

    class Pin:
        OUT = "out"

        def __init__(self, *_args, **_kwargs):
            calls["pin_inits"] += 1

    machine.Pin = Pin

    def reset():
        calls["machine_reset_calls"] += 1

    machine.reset = reset

    network = types.ModuleType("network")
    network.STA_IF = 0
    network.AP_IF = 1

    class WLAN:
        def __init__(self, *_args, **_kwargs):
            calls["wlan_inits"] += 1

        def active(self, *_args, **_kwargs):
            return None

        def connect(self, *_args, **_kwargs):
            return None

        def isconnected(self):
            return False

        def ifconfig(self):
            return ("0.0.0.0", "", "", "")

        def disconnect(self):
            return None

        def scan(self):
            return []

        def config(self, **_kwargs):
            return None

    network.WLAN = WLAN

    neopixel = types.ModuleType("neopixel")

    class NeoPixel:
        def __init__(self, *_args, **_kwargs):
            calls["neopixel_inits"] += 1

    neopixel.NeoPixel = NeoPixel

    monkeypatch.setitem(sys.modules, "machine", machine)
    monkeypatch.setitem(sys.modules, "network", network)
    monkeypatch.setitem(sys.modules, "neopixel", neopixel)

    spec = importlib.util.spec_from_file_location("runtime_main", MAIN_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module, calls


def _load_boot_module(monkeypatch):
    calls = {"main_calls": 0}
    fake_main = types.ModuleType("main")
    monkeypatch.setitem(sys.modules, "network", types.ModuleType("network"))
    monkeypatch.setitem(sys.modules, "time", types.ModuleType("time"))

    def start_main():
        calls["main_calls"] += 1

    fake_main.main = start_main
    monkeypatch.setitem(sys.modules, "main", fake_main)

    spec = importlib.util.spec_from_file_location("runtime_boot", BOOT_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module, calls


class _FakeSocket:
    def __init__(self, packet):
        self.packet = packet
        self.sent = []
        self.recv_count = 0

    def bind(self, *_args, **_kwargs):
        return None

    def settimeout(self, *_args, **_kwargs):
        return None

    def setsockopt(self, *_args, **_kwargs):
        return None

    def recvfrom(self, _bufsize):
        if self.recv_count == 0:
            self.recv_count += 1
            return self.packet
        time.sleep(0.01)
        raise OSError(110, "timed out")

    def sendto(self, payload, addr):
        self.sent.append((payload, addr))


class _EmptySocket(_FakeSocket):
    def __init__(self):
        super().__init__((b"", ("127.0.0.1", 0)))

    def recvfrom(self, _bufsize):
        time.sleep(0.01)
        raise OSError(110, "timed out")


def _run_control_mode_with_packet(monkeypatch, packet):
    module, _calls = _load_main_module(monkeypatch)
    control_sock = _FakeSocket((packet, ("127.0.0.1", 12345)))
    config_sock = _EmptySocket()
    sockets = [control_sock, config_sock]
    packet_consumed = {"value": False}

    class _StopLoop(Exception):
        pass

    module.socket.socket = lambda *_args, **_kwargs: sockets.pop(0)
    module.ANIM_FUNCS = {name: (lambda: None) for name in module.EFFECTS}
    module.recv_udp_command = lambda sock, _size: (
        (_ for _ in ()).throw(_StopLoop())
        if sock is control_sock and packet_consumed["value"]
        else (
            packet_consumed.__setitem__("value", True)
            or (packet.decode().strip(), ("127.0.0.1", 12345))
        )
        if sock is control_sock
        else None
    )

    def run():
        try:
            module.control_mode()
        except _StopLoop:
            return None

    thread = threading.Thread(target=run, daemon=True)
    thread.start()

    deadline = time.time() + 0.5
    while time.time() < deadline:
        if control_sock.sent:
            return module, control_sock
        time.sleep(0.01)

    raise AssertionError("control_mode did not send a response")


def _run_control_mode_with_config_packet(monkeypatch, packet, configure_module=None):
    module, calls = _load_main_module(monkeypatch)
    control_sock = _EmptySocket()
    config_sock = _FakeSocket((packet, ("127.0.0.1", 12345)))
    sockets = [control_sock, config_sock]
    config_consumed = {"value": False}

    class _StopLoop(Exception):
        pass

    module.socket.socket = lambda *_args, **_kwargs: sockets.pop(0)
    module.ANIM_FUNCS = {name: (lambda: None) for name in module.EFFECTS}
    module.recv_udp_command = lambda sock, _size: (
        (_ for _ in ()).throw(_StopLoop())
        if sock is config_sock and config_consumed["value"]
        else (
            config_consumed.__setitem__("value", True)
            or (packet.decode().strip(), ("127.0.0.1", 12345))
        )
        if sock is config_sock
        else None
    )
    if configure_module is not None:
        configure_module(module)

    def run():
        try:
            module.control_mode()
        except _StopLoop:
            return None

    thread = threading.Thread(target=run, daemon=True)
    thread.start()

    deadline = time.time() + 0.5
    while time.time() < deadline:
        if config_sock.sent:
            return module, calls, config_sock
        time.sleep(0.01)

    raise AssertionError("control_mode did not send a config response")


def _run_config_mode_with_packet(monkeypatch, packet, configure_module=None):
    module, _calls = _load_main_module(monkeypatch)
    fake_sock = _FakeSocket((packet, ("127.0.0.1", 12345)))
    packet_consumed = {"value": False}

    class _StopLoop(Exception):
        pass

    module.socket.socket = lambda *_args, **_kwargs: fake_sock
    module.recv_udp_command = (
        lambda sock, _size: (
            (_ for _ in ()).throw(_StopLoop())
            if packet_consumed["value"]
            else packet_consumed.__setitem__("value", True)
            or (packet.decode().strip(), ("127.0.0.1", 12345))
        )
    )
    if configure_module is not None:
        configure_module(module)

    def run():
        try:
            module.config_mode()
        except _StopLoop:
            return None

    thread = threading.Thread(target=run, daemon=True)
    thread.start()

    deadline = time.time() + 0.5
    while time.time() < deadline:
        if fake_sock.sent:
            return module, fake_sock
        time.sleep(0.01)

    raise AssertionError("config_mode did not send a response")


def test_main_module_uses_import_guard():
    tree = ast.parse(MAIN_PATH.read_text(), filename=str(MAIN_PATH))

    def is_name_main_guard(node):
        return (
            isinstance(node, ast.If)
            and isinstance(node.test, ast.Compare)
            and isinstance(node.test.left, ast.Name)
            and node.test.left.id == "__name__"
            and len(node.test.ops) == 1
            and isinstance(node.test.ops[0], ast.Eq)
            and len(node.test.comparators) == 1
            and isinstance(node.test.comparators[0], ast.Constant)
            and node.test.comparators[0].value == "__main__"
        )

    guard_nodes = [node for node in tree.body if is_name_main_guard(node)]

    assert len(guard_nodes) == 1
    guard = guard_nodes[0]
    assert len(guard.body) == 1
    assert isinstance(guard.body[0], ast.Expr)
    assert isinstance(guard.body[0].value, ast.Call)
    assert isinstance(guard.body[0].value.func, ast.Name)
    assert guard.body[0].value.func.id == "main"
    assert not guard.body[0].value.args
    assert not guard.body[0].value.keywords


def test_main_module_can_be_imported_without_starting_runtime(monkeypatch):
    module, calls = _load_main_module(monkeypatch)

    assert module.mode == "rainbow"
    assert module.brightness == 180
    assert calls == {
        "pin_inits": 0,
        "neopixel_inits": 0,
        "wlan_inits": 0,
        "machine_reset_calls": 0,
    }


def test_boot_module_starts_main_runtime_once(monkeypatch):
    _module, calls = _load_boot_module(monkeypatch)

    assert calls["main_calls"] == 1


def test_parse_control_command_supports_expected_inputs(monkeypatch):
    module, _calls = _load_main_module(monkeypatch)

    assert module.parse_control_command("mode:next") == ("mode", "next")
    assert module.parse_control_command("mode:prev") == ("mode", "prev")
    assert module.parse_control_command("mode:rainbow") == ("mode", "rainbow")
    assert module.parse_control_command("bright:12") == ("brightness", 12)
    assert module.parse_control_command("bright:999") == ("brightness", 255)
    assert module.parse_control_command("bright:-5") == ("brightness", 0)
    assert module.parse_control_command("bright:abc") == ("brightness_error", None)
    assert module.parse_control_command("status") == ("status", None)
    assert module.parse_control_command("help") == ("help", None)
    assert module.parse_control_command("bogus") == ("error", None)


def test_parse_config_command_supports_expected_inputs(monkeypatch):
    module, _calls = _load_main_module(monkeypatch)

    assert module.parse_config_command("config:HomeWiFi:secret") == (
        "config",
        ("HomeWiFi", "secret"),
    )
    assert module.parse_config_command("status") == ("status", None)
    assert module.parse_config_command("list") == ("list", None)
    assert module.parse_config_command("diag") == ("diag", None)
    assert module.parse_config_command("reset") == ("reset", None)
    assert module.parse_config_command("config:missing") == ("error", None)


def test_control_help_text_and_effects_constants(monkeypatch):
    module, _calls = _load_main_module(monkeypatch)

    assert module.EFFECTS == (
        "rainbow",
        "breath",
        "fire",
        "starry",
        "wave",
        "chase",
        "sparkle",
        "snake",
    )
    assert (
        module.CONTROL_HELP_TEXT
        == "mode:(rainbow|breath|fire|starry|wave|chase|sparkle|snake|next|prev),bright:0-255,status"
    )


def test_wave_level_cardinal_angles(monkeypatch):
    module, _calls = _load_main_module(monkeypatch)

    assert module.wave_level(0) == 0
    assert module.wave_level(90) == 255
    assert module.wave_level(180) == 0
    assert module.wave_level(270) == -255


def test_animation_palettes(monkeypatch):
    module, _calls = _load_main_module(monkeypatch)

    assert module.FIRE_COLORS == ((255, 0, 0), (255, 80, 0), (255, 160, 0))
    assert module.STARRY_COLORS == (
        (255, 255, 255),
        (200, 200, 255),
        (255, 255, 200),
    )
    assert module.SPARKLE_COLORS[-1] == (255, 255, 255)


class _FakeNeoPixel:
    def __init__(self, count):
        self.pixels = [(0, 0, 0)] * count
        self.write_calls = 0

    def __setitem__(self, index, value):
        self.pixels[index] = value

    def __getitem__(self, index):
        return self.pixels[index]

    def fill(self, value):
        self.pixels = [value] * len(self.pixels)

    def write(self):
        self.write_calls += 1


def test_rainbow_renders_a_frame(monkeypatch):
    module, _calls = _load_main_module(monkeypatch)
    fake_np = _FakeNeoPixel(module.LED_COUNT)

    monkeypatch.setattr(module.time, "sleep_ms", lambda *_args, **_kwargs: None, raising=False)
    module.np = fake_np
    module.frame_count = 0

    module.rainbow()

    assert module.frame_count == 1
    assert fake_np.write_calls == 1
    assert any(pixel != (0, 0, 0) for pixel in fake_np.pixels)


def test_wave_renders_sine_like_frame(monkeypatch):
    module, _calls = _load_main_module(monkeypatch)
    fake_np = _FakeNeoPixel(30)
    original_wave_level = module.wave_level
    wave_level_calls = []

    monkeypatch.setattr(module.time, "sleep_ms", lambda *_args, **_kwargs: None, raising=False)
    monkeypatch.setattr(
        module,
        "wave_level",
        lambda angle: wave_level_calls.append(angle) or original_wave_level(angle),
    )
    module.np = fake_np
    module.brightness = 255
    module.LED_COUNT = 30
    module.frame_count = 0

    module.wave()

    def expected_pixel(index):
        angle = (index * 12) % 360
        level = math.sin(math.radians(angle))
        if level > 0:
            return (int(255 * (1 - level)), int(255 * level), 0)
        return (0, int(255 * (1 + level)), int(255 * (-level)))

    def assert_pixel_close(actual, expected, tolerance=1):
        assert len(actual) == len(expected)
        for actual_channel, expected_channel in zip(actual, expected):
            assert abs(actual_channel - expected_channel) <= tolerance

    assert module.frame_count == 1
    assert fake_np.write_calls == 1
    assert len(wave_level_calls) == module.LED_COUNT
    assert wave_level_calls[:4] == [0, 12, 24, 36]
    assert_pixel_close(fake_np[0], expected_pixel(0))
    assert_pixel_close(fake_np[7], expected_pixel(7))
    assert fake_np[15] == expected_pixel(15)
    assert_pixel_close(fake_np[16], expected_pixel(16))
    assert_pixel_close(fake_np[23], expected_pixel(23))


def test_dynamic_import_not_used_for_math():
    source = MAIN_PATH.read_text()

    assert "__import__('math')" not in source
    assert '__import__("math")' not in source


def test_control_mode_returns_error_for_malformed_brightness(monkeypatch):
    _module, fake_sock = _run_control_mode_with_packet(monkeypatch, b"bright:abc")

    assert fake_sock.sent == [(b"ERROR", ("127.0.0.1", 12345))]


def test_control_mode_returns_exact_help_text(monkeypatch):
    module, fake_sock = _run_control_mode_with_packet(monkeypatch, b"help")

    assert fake_sock.sent == [(module.CONTROL_HELP_TEXT.encode(), ("127.0.0.1", 12345))]


def test_control_mode_unknown_command_returns_error(monkeypatch):
    _module, fake_sock = _run_control_mode_with_packet(monkeypatch, b"bogus")

    assert fake_sock.sent == [(b"Error", ("127.0.0.1", 12345))]


def test_handle_config_packet_preserves_mixed_case_credentials_when_saving(monkeypatch):
    module, _calls = _load_main_module(monkeypatch)
    saved = {}

    def fake_save_cfg(ssid, pwd):
        saved["values"] = (ssid, pwd)
        return True

    module.save_cfg = fake_save_cfg
    module.time.sleep = lambda *_args, **_kwargs: None
    module.machine.reset = lambda: (_ for _ in ()).throw(SystemExit)
    fake_sock = _FakeSocket((b"", ("127.0.0.1", 0)))

    with pytest.raises(SystemExit):
        module.handle_config_packet(
            fake_sock,
            "config:HomeWiFi:SecretPass",
            ("127.0.0.1", 12345),
        )

    assert saved["values"] == ("HomeWiFi", "SecretPass")
    assert fake_sock.sent == [(b"OK!Rebooting...", ("127.0.0.1", 12345))]


def test_handle_config_packet_reset_deletes_cfg_and_reboots(monkeypatch):
    module, _calls = _load_main_module(monkeypatch)
    events = {"delete_calls": 0}

    def fake_delete_cfg():
        events["delete_calls"] += 1
        return True

    module.delete_cfg = fake_delete_cfg
    module.time.sleep = lambda *_args, **_kwargs: None
    module.machine.reset = lambda: (_ for _ in ()).throw(SystemExit)
    fake_sock = _FakeSocket((b"", ("127.0.0.1", 0)))

    with pytest.raises(SystemExit):
        module.handle_config_packet(
            fake_sock,
            "reset",
            ("127.0.0.1", 12345),
        )

    assert events["delete_calls"] == 1
    assert fake_sock.sent == [(b"OK!Rebooting...", ("127.0.0.1", 12345))]


def test_config_mode_malformed_config_returns_usage_error(monkeypatch):
    _module, fake_sock = _run_config_mode_with_packet(monkeypatch, b"config:missing")

    assert fake_sock.sent == [(b"Error: use config:SSID:PWD", ("127.0.0.1", 12345))]


def test_config_mode_unknown_command_returns_command_list(monkeypatch):
    module, fake_sock = _run_config_mode_with_packet(monkeypatch, b"bogus")

    assert fake_sock.sent == [
        (module.CONFIG_COMMANDS_TEXT.encode(), ("127.0.0.1", 12345))
    ]


def test_config_mode_preserves_mixed_case_credentials_when_saving(monkeypatch):
    module, _calls = _load_main_module(monkeypatch)
    saved = {}

    def fake_save_cfg(ssid, pwd):
        saved["values"] = (ssid, pwd)
        return True

    module.save_cfg = fake_save_cfg
    module.time.sleep = lambda *_args, **_kwargs: None
    module.machine.reset = lambda: (_ for _ in ()).throw(SystemExit)
    fake_sock = _FakeSocket((b"", ("127.0.0.1", 0)))

    with pytest.raises(SystemExit):
        module.handle_config_packet(
            fake_sock,
            "config:HomeWiFi:SecretPass",
            ("127.0.0.1", 12345),
        )

    assert saved["values"] == ("HomeWiFi", "SecretPass")
    assert fake_sock.sent == [(b"OK!Rebooting...", ("127.0.0.1", 12345))]


def test_config_mode_diag_returns_detailed_wifi_data(monkeypatch):
    def configure_module(module):
        module.load_cfg = lambda: ("HomeWiFi", "secretpass")
        events = {"scan_calls": 0}

        class FakeWLAN:
            def __init__(self, interface):
                self.interface = interface

            def active(self, *_args, **_kwargs):
                return None

            def config(self, **_kwargs):
                return None

            def status(self):
                return -3

            def ifconfig(self):
                return ("0.0.0.0", "255.255.255.0", "0.0.0.0", "0.0.0.0")

            def scan(self):
                events["scan_calls"] += 1
                return []

        module.network.WLAN = lambda interface: FakeWLAN(interface)
        module._diag_events = events

    module, fake_sock = _run_config_mode_with_packet(
        monkeypatch,
        b"diag",
        configure_module=configure_module,
    )

    assert fake_sock.sent == [
        (
            b"DIAG:status=-3;ifconfig=0.0.0.0,255.255.255.0,0.0.0.0,0.0.0.0",
            ("127.0.0.1", 12345),
        )
    ]
    assert module._diag_events["scan_calls"] == 0


def test_scan_wifis_sorts_by_rssi_descending_and_limits_to_top_five(monkeypatch):
    module, _calls = _load_main_module(monkeypatch)
    scans = [
        (b"weak", b"", 1, -90, 0, 0),
        (b"strong", b"", 1, -20, 0, 0),
        (b"mid", b"", 1, -50, 0, 0),
        (b"mid2", b"", 1, -60, 0, 0),
        (b"mid3", b"", 1, -40, 0, 0),
        (b"mid4", b"", 1, -30, 0, 0),
    ]

    class FakeWLAN:
        def __init__(self, *_args, **_kwargs):
            self.active_calls = []

        def active(self, value):
            self.active_calls.append(value)

        def scan(self):
            return list(scans)

    fake_wlan = FakeWLAN()
    monkeypatch.setattr(module.network, "WLAN", lambda *_args, **_kwargs: fake_wlan)

    result = module.scan_wifis()

    assert fake_wlan.active_calls == [True]
    assert [entry[0] for entry in result] == [
        b"strong",
        b"mid4",
        b"mid3",
        b"mid",
        b"mid2",
    ]


def test_try_wifi_connects_with_loaded_credentials_and_returns_true(monkeypatch):
    module, _calls = _load_main_module(monkeypatch)
    events = {"connect": [], "disconnect_calls": 0}

    class FakeWLAN:
        def active(self, *_args, **_kwargs):
            return None

        def connect(self, ssid, pwd):
            events["connect"].append((ssid, pwd))

        def isconnected(self):
            return True

        def ifconfig(self):
            return ("192.168.0.8", "", "", "")

        def disconnect(self):
            events["disconnect_calls"] += 1

    monkeypatch.setattr(module, "load_cfg", lambda: ("HomeWiFi", "secretpass"))
    monkeypatch.setattr(module.network, "WLAN", lambda *_args, **_kwargs: FakeWLAN())

    assert module.try_wifi() is True
    assert events["connect"] == [("HomeWiFi", "secretpass")]
    assert events["disconnect_calls"] == 0


def test_try_wifi_resets_station_interface_before_connecting(monkeypatch):
    module, _calls = _load_main_module(monkeypatch)
    events = {"active_calls": [], "connect": [], "disconnect_calls": 0}

    class FakeWLAN:
        def __init__(self):
            self.connected = False

        def active(self, value):
            events["active_calls"].append(value)
            return None

        def connect(self, ssid, pwd):
            events["connect"].append((ssid, pwd))
            self.connected = events["active_calls"][:2] == [False, True]

        def isconnected(self):
            return self.connected

        def ifconfig(self):
            return ("192.168.0.8", "", "", "")

        def disconnect(self):
            events["disconnect_calls"] += 1

    monkeypatch.setattr(module, "load_cfg", lambda: ("HomeWiFi", "secretpass"))
    monkeypatch.setattr(module.network, "WLAN", lambda *_args, **_kwargs: FakeWLAN())
    monkeypatch.setattr(module.time, "sleep", lambda *_args, **_kwargs: None)

    assert module.try_wifi() is True
    assert events["active_calls"][:2] == [False, True]
    assert events["connect"] == [("HomeWiFi", "secretpass")]


def test_try_wifi_disconnects_and_returns_false_after_timeout(monkeypatch):
    module, _calls = _load_main_module(monkeypatch)
    events = {"connect": [], "disconnect_calls": 0, "sleep_calls": 0}

    class FakeWLAN:
        def active(self, *_args, **_kwargs):
            return None

        def connect(self, ssid, pwd):
            events["connect"].append((ssid, pwd))

        def isconnected(self):
            return False

        def disconnect(self):
            events["disconnect_calls"] += 1

    monkeypatch.setattr(module, "load_cfg", lambda: ("HomeWiFi", "secretpass"))
    monkeypatch.setattr(module.network, "WLAN", lambda *_args, **_kwargs: FakeWLAN())
    monkeypatch.setattr(
        module.time,
        "sleep",
        lambda *_args, **_kwargs: events.__setitem__(
            "sleep_calls", events["sleep_calls"] + 1
        ),
    )

    assert module.try_wifi() is False
    assert events["connect"] == [("HomeWiFi", "secretpass")]
    assert events["disconnect_calls"] == 1
    assert events["sleep_calls"] == 152


def test_try_wifi_failure_prints_lightweight_status_without_scanning(
    monkeypatch, capsys
):
    module, _calls = _load_main_module(monkeypatch)
    events = {"disconnect_calls": 0, "scan_calls": 0}

    class FakeWLAN:
        def active(self, *_args, **_kwargs):
            return None

        def connect(self, *_args, **_kwargs):
            return None

        def isconnected(self):
            return False

        def ifconfig(self):
            return ("0.0.0.0", "255.255.255.0", "0.0.0.0", "0.0.0.0")

        def status(self):
            return -3

        def scan(self):
            events["scan_calls"] += 1
            return []

        def disconnect(self):
            events["disconnect_calls"] += 1

    monkeypatch.setattr(module, "load_cfg", lambda: ("HomeWiFi", "secretpass"))
    monkeypatch.setattr(module.network, "WLAN", lambda *_args, **_kwargs: FakeWLAN())
    monkeypatch.setattr(module.time, "sleep", lambda *_args, **_kwargs: None)

    assert module.try_wifi() is False
    output = capsys.readouterr().out

    assert "Fail" in output
    assert "WiFi status: -3" in output
    assert "ifconfig: ('0.0.0.0', '255.255.255.0', '0.0.0.0', '0.0.0.0')" in output
    assert "Visible WiFi:" not in output
    assert events["disconnect_calls"] == 1
    assert events["scan_calls"] == 0


def test_save_cfg_and_load_cfg_round_trip(tmp_path, monkeypatch):
    module, _calls = _load_main_module(monkeypatch)
    monkeypatch.chdir(tmp_path)

    assert module.save_cfg("HomeWiFi", "secretpass") is True
    assert module.load_cfg() == ("HomeWiFi", "secretpass")


def test_delete_cfg_succeeds_when_file_is_missing(tmp_path, monkeypatch):
    module, _calls = _load_main_module(monkeypatch)
    monkeypatch.chdir(tmp_path)

    assert module.delete_cfg() is True


def test_is_timeout_error_only_accepts_timeout_style_oserror(monkeypatch):
    module, _calls = _load_main_module(monkeypatch)

    assert module.is_timeout_error(OSError(110, "timed out")) is True
    assert module.is_timeout_error(OSError("timed out")) is True
    assert module.is_timeout_error(OSError(111, "connection refused")) is False


def test_recv_udp_command_returns_none_for_timeout(monkeypatch):
    module, _calls = _load_main_module(monkeypatch)

    class TimeoutSocket:
        def recvfrom(self, _bufsize):
            raise OSError(110, "timed out")

    assert module.recv_udp_command(TimeoutSocket(), 64) is None


def test_recv_udp_command_propagates_fatal_oserror(monkeypatch):
    module, _calls = _load_main_module(monkeypatch)

    class FatalSocket:
        def recvfrom(self, _bufsize):
            raise OSError(111, "connection refused")

    try:
        module.recv_udp_command(FatalSocket(), 64)
    except OSError as exc:
        assert exc.args[0] == 111
    else:
        raise AssertionError("fatal OSError should not be swallowed")
