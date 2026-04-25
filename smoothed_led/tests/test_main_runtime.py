import ast
import importlib.util
import sys
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
