import ast
import importlib.util
import sys
import threading
import time
import types
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
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
        raise RuntimeError("no more packets")

    def sendto(self, payload, addr):
        self.sent.append((payload, addr))


def _run_control_mode_with_packet(monkeypatch, packet):
    module, _calls = _load_main_module(monkeypatch)
    fake_sock = _FakeSocket((packet, ("127.0.0.1", 12345)))

    module.socket.socket = lambda *_args, **_kwargs: fake_sock
    module.ANIM_FUNCS = {name: (lambda: None) for name in module.EFFECTS}

    thread = threading.Thread(target=module.control_mode, daemon=True)
    thread.start()

    deadline = time.time() + 0.5
    while time.time() < deadline:
        if fake_sock.sent:
            return module, fake_sock
        time.sleep(0.01)

    raise AssertionError("control_mode did not send a response")


def _run_config_mode_with_packet(monkeypatch, packet, configure_module=None):
    module, _calls = _load_main_module(monkeypatch)
    fake_sock = _FakeSocket((packet, ("127.0.0.1", 12345)))

    module.socket.socket = lambda *_args, **_kwargs: fake_sock
    if configure_module is not None:
        configure_module(module)

    thread = threading.Thread(target=module.config_mode, daemon=True)
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


def test_control_mode_returns_error_for_malformed_brightness(monkeypatch):
    _module, fake_sock = _run_control_mode_with_packet(monkeypatch, b"bright:abc")

    assert fake_sock.sent == [(b"ERROR", ("127.0.0.1", 12345))]


def test_control_mode_returns_exact_help_text(monkeypatch):
    module, fake_sock = _run_control_mode_with_packet(monkeypatch, b"help")

    assert fake_sock.sent == [(module.CONTROL_HELP_TEXT.encode(), ("127.0.0.1", 12345))]


def test_control_mode_unknown_command_returns_error(monkeypatch):
    _module, fake_sock = _run_control_mode_with_packet(monkeypatch, b"bogus")

    assert fake_sock.sent == [(b"Error", ("127.0.0.1", 12345))]


def test_config_mode_malformed_config_returns_usage_error(monkeypatch):
    _module, fake_sock = _run_config_mode_with_packet(monkeypatch, b"config:missing")

    assert fake_sock.sent == [(b"Error: use config:SSID:PWD", ("127.0.0.1", 12345))]


def test_config_mode_unknown_command_returns_command_list(monkeypatch):
    module, fake_sock = _run_config_mode_with_packet(monkeypatch, b"bogus")

    assert fake_sock.sent == [
        (module.CONFIG_COMMANDS_TEXT.encode(), ("127.0.0.1", 12345))
    ]


def test_config_mode_lowercases_mixed_case_credentials_before_saving(monkeypatch):
    saved = {}

    def configure_module(module):
        def fake_save_cfg(ssid, pwd):
            saved["values"] = (ssid, pwd)
            return True

        module.save_cfg = fake_save_cfg

    _module, fake_sock = _run_config_mode_with_packet(
        monkeypatch,
        b"config:HomeWiFi:SecretPass",
        configure_module=configure_module,
    )

    assert saved["values"] == ("homewifi", "secretpass")
    assert fake_sock.sent == [(b"OK!Rebooting...", ("127.0.0.1", 12345))]
