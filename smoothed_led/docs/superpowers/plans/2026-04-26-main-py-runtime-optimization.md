# `main.py` 运行时优化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在保持 UDP 协议、端口、灯效名称和单文件运行时结构不变的前提下，优化 `main.py` 的热点路径，降低 ESP8266 上的内存压力和逐帧 CPU 开销。

**Architecture:** 继续使用 `main.py` 作为唯一运行时入口，但把高频分配、动态导入、重复拼接和宽泛异常处理收敛为少量可测试的纯辅助函数、模块级常量和更轻量的状态更新逻辑。自动化验证聚焦在 CPython 下可运行的纯逻辑和假对象回归测试，硬件相关行为通过最终的设备手工回归收口。

**Tech Stack:** MicroPython、ESP8266 NodeMCU、NeoPixel、UDP socket、CPython `pytest`

---

## File Structure

### Existing files to modify

- `main.py`
  - 在文件底部加导入保护，避免主机侧测试导入时直接启动运行时
  - 提升高频静态文本和颜色表为模块级常量
  - 新增纯辅助函数，收敛命令解析、亮度钳位和波形计算
  - 优化 `control_mode()` / `config_mode()` 中的命令分支、异常边界和 `gc.collect()` 时机
  - 重写热点动画函数，减少循环内临时对象、动态导入和高频全局查找

- `README.md`
  - 只在最终实现确实改变了本地开发验证方式时才补一小节“主机侧回归测试”
  - 如果实现过程中没有新增可运行的本地测试命令，则不修改此文件

### New files to create

- `tests/test_main_runtime.py`
  - 在 CPython 下为 `main.py` 提供可运行的回归测试
  - 内置 MicroPython 依赖桩、假 `NeoPixel` 和可复用的模块加载器
  - 锁定命令解析、亮度/波形辅助函数、动画基础行为、WiFi 扫描排序和连接回退逻辑

### No new runtime files

- 不新增运行时模块
- 不拆分 `main.py`
- 不新增持久化文件格式

---

### Task 1: 建立可导入入口和主机侧测试支点

**Files:**
- Create: `tests/test_main_runtime.py`
- Modify: `main.py`

- [ ] **Step 1: 先写失败测试，锁定 `main.py` 可导入且不会自动启动运行时**

在 `tests/test_main_runtime.py` 中先创建主机侧桩和两个最小回归测试。当前 `main.py` 底部直接调用 `main()`，所以导入测试会失败，这正是本任务要先锁定的问题。

```python
import importlib.util
import sys
import types
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
MAIN_PY = PROJECT_ROOT / "main.py"


def install_micropython_stubs(monkeypatch):
    class DummyPin:
        OUT = 0

        def __init__(self, *args, **kwargs):
            self.args = args
            self.kwargs = kwargs

    fake_machine = types.ModuleType("machine")
    fake_machine.Pin = DummyPin
    fake_machine.reset = lambda: None

    fake_network = types.ModuleType("network")
    fake_network.STA_IF = 0
    fake_network.AP_IF = 1
    fake_network.WLAN = lambda *_args, **_kwargs: None

    fake_neopixel = types.ModuleType("neopixel")
    fake_neopixel.NeoPixel = lambda *_args, **_kwargs: None

    monkeypatch.setitem(sys.modules, "machine", fake_machine)
    monkeypatch.setitem(sys.modules, "network", fake_network)
    monkeypatch.setitem(sys.modules, "neopixel", fake_neopixel)


def load_main_module(monkeypatch):
    install_micropython_stubs(monkeypatch)
    spec = importlib.util.spec_from_file_location("led_main", MAIN_PY)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_main_module_uses_import_guard():
    source = MAIN_PY.read_text(encoding="utf-8")
    assert 'if __name__ == "__main__":' in source


def test_main_module_can_be_imported_without_starting_runtime(monkeypatch):
    module = load_main_module(monkeypatch)
    assert module.mode == "rainbow"
    assert module.brightness == 180
```

- [ ] **Step 2: 运行聚焦测试，确认它先失败**

Run:

```bash
python3 -m pytest tests/test_main_runtime.py -k "import_guard or imported_without_starting_runtime" -v
```

Expected:

- `test_main_module_uses_import_guard` FAIL，因为源码里还没有 `if __name__ == "__main__":`
- `test_main_module_can_be_imported_without_starting_runtime` FAIL，因为导入时会直接执行 `main()`

- [ ] **Step 3: 写最小实现，在不改变设备启动行为的前提下加导入保护**

把 `main.py` 底部的直接调用改成标准导入保护；运行在设备上时仍会执行 `main()`，但主机侧 `pytest` 导入时不再直接启动硬件逻辑。

```python
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
```

- [ ] **Step 4: 重新运行聚焦测试，确认导入保护生效**

Run:

```bash
python3 -m pytest tests/test_main_runtime.py -k "import_guard or imported_without_starting_runtime" -v
```

Expected:

- `test_main_module_uses_import_guard` PASS
- `test_main_module_can_be_imported_without_starting_runtime` PASS

- [ ] **Step 5: 提交导入保护和测试支点**

```bash
git add main.py tests/test_main_runtime.py
git commit -m "test: add host-side import guard coverage"
```

---

### Task 2: 提升静态常量并收敛命令解析

**Files:**
- Modify: `main.py`
- Modify: `tests/test_main_runtime.py`

- [ ] **Step 1: 先写失败测试，锁定控制命令、配置命令和帮助文本常量**

把下面这组测试追加到 `tests/test_main_runtime.py`。它们要求 `main.py` 提供可复用的纯解析函数和预构建帮助文本，当前实现还没有这些入口，所以会先失败。

```python
def test_parse_control_command_covers_existing_protocol(monkeypatch):
    module = load_main_module(monkeypatch)

    assert module.parse_control_command("mode:next") == ("mode", "next")
    assert module.parse_control_command("mode:prev") == ("mode", "prev")
    assert module.parse_control_command("mode:rainbow") == ("mode", "rainbow")
    assert module.parse_control_command("bright:12") == ("brightness", 12)
    assert module.parse_control_command("bright:999") == ("brightness", 255)
    assert module.parse_control_command("bright:-5") == ("brightness", 0)
    assert module.parse_control_command("status") == ("status", None)
    assert module.parse_control_command("help") == ("help", None)
    assert module.parse_control_command("bogus") == ("error", None)


def test_parse_config_command_covers_existing_protocol(monkeypatch):
    module = load_main_module(monkeypatch)

    assert module.parse_config_command("config:HomeWiFi:secret") == (
        "config",
        ("HomeWiFi", "secret"),
    )
    assert module.parse_config_command("status") == ("status", None)
    assert module.parse_config_command("list") == ("list", None)
    assert module.parse_config_command("config:missing") == ("error", None)


def test_control_help_text_is_prebuilt(monkeypatch):
    module = load_main_module(monkeypatch)

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
```

- [ ] **Step 2: 运行命令解析测试，确认它们先失败**

Run:

```bash
python3 -m pytest tests/test_main_runtime.py -k "parse_control_command or parse_config_command or control_help_text" -v
```

Expected:

- 三个测试全部 FAIL
- 失败原因应是 `main.py` 里还没有 `parse_control_command`、`parse_config_command` 或 `CONTROL_HELP_TEXT`

- [ ] **Step 3: 写最小实现，把高频静态文本和解析逻辑提成纯函数**

先把效果列表改成元组，顺手生成高频文本常量，再添加两个纯解析函数和一个 `clamp_u8()` 辅助函数；最后把 `control_mode()` / `config_mode()` 切换到这些入口，避免在循环中反复 `split()`、`join()` 和格式化。

```python
EFFECTS = (
    "rainbow",
    "breath",
    "fire",
    "starry",
    "wave",
    "chase",
    "sparkle",
    "snake",
)
EFFECTS_TEXT = ",".join(EFFECTS)
CONTROL_HELP_TEXT = "mode:(%s|next|prev),bright:0-255,status" % "|".join(EFFECTS)
CONFIG_COMMANDS_TEXT = "Commands:config:SSID:PWD, status, list"


def clamp_u8(value):
    if value < 0:
        return 0
    if value > 255:
        return 255
    return value


def parse_control_command(cmd):
    if cmd.startswith("mode:"):
        value = cmd[5:]
        if value:
            return "mode", value
        return "error", None

    if cmd.startswith("bright:"):
        try:
            return "brightness", clamp_u8(int(cmd[7:]))
        except ValueError:
            return "error", None

    if cmd == "status":
        return "status", None
    if cmd == "help":
        return "help", None
    return "error", None


def parse_config_command(cmd):
    if cmd.startswith("config:"):
        parts = cmd.split(":", 2)
        if len(parts) == 3 and parts[1]:
            return "config", (parts[1], parts[2])
        return "error", None

    if cmd == "status":
        return "status", None
    if cmd == "list":
        return "list", None
    return "error", None
```

`control_mode()` 里把原来直接 `split()` 的分支改成：

```python
kind, value = parse_control_command(cmd)

if kind == "mode":
    if value == "next":
        mode = EFFECTS[(get_mode_idx(mode) + 1) % len(EFFECTS)]
        init_anim()
    elif value == "prev":
        mode = EFFECTS[(get_mode_idx(mode) - 1) % len(EFFECTS)]
        init_anim()
    elif value in ANIM_FUNCS:
        mode = value
        init_anim()
    sock.sendto(("OK:%s" % mode).encode(), addr)
elif kind == "brightness":
    brightness = value
    sock.sendto(("OK:%d" % brightness).encode(), addr)
elif kind == "status":
    sock.sendto(("MODE:%s;BRIGHT:%d" % (mode, brightness)).encode(), addr)
elif kind == "help":
    sock.sendto(CONTROL_HELP_TEXT.encode(), addr)
else:
    sock.sendto(b"Error", addr)
```

`config_mode()` 里按同样方式切换到 `parse_config_command()`，并把兜底帮助文本换成 `CONFIG_COMMANDS_TEXT.encode()`。

- [ ] **Step 4: 运行解析测试，确认协议行为被锁定**

Run:

```bash
python3 -m pytest tests/test_main_runtime.py -k "parse_control_command or parse_config_command or control_help_text" -v
```

Expected:

- 三个测试全部 PASS
- 原始协议字和帮助文本保持不变

- [ ] **Step 5: 提交常量提升和命令解析重构**

```bash
git add main.py tests/test_main_runtime.py
git commit -m "refactor: hoist command parsing helpers"
```

---

### Task 3: 优化动画热点路径和轻量状态更新

**Files:**
- Modify: `main.py`
- Modify: `tests/test_main_runtime.py`

- [ ] **Step 1: 先写失败测试，锁定动画辅助函数、颜色常量和基础帧行为**

把下面这组测试追加到 `tests/test_main_runtime.py`。它们锁定三个点：颜色表必须是模块级常量、`wave()` 不再依赖循环内动态导入、基础动画帧必须还能输出像素并推进状态。

```python
class FakeNeoPixel:
    def __init__(self, count):
        self.pixels = [(0, 0, 0)] * count
        self.write_count = 0

    def __getitem__(self, index):
        return self.pixels[index]

    def __setitem__(self, index, value):
        self.pixels[index] = tuple(value)

    def fill(self, value):
        color = tuple(value)
        for index in range(len(self.pixels)):
            self.pixels[index] = color

    def write(self):
        self.write_count += 1


def test_wave_level_uses_integer_quadrants(monkeypatch):
    module = load_main_module(monkeypatch)

    assert module.wave_level(0) == 0
    assert module.wave_level(90) == 255
    assert module.wave_level(180) == 0
    assert module.wave_level(270) == -255


def test_animation_palettes_are_module_constants(monkeypatch):
    module = load_main_module(monkeypatch)

    assert module.FIRE_COLORS == ((255, 0, 0), (255, 80, 0), (255, 160, 0))
    assert module.STARRY_COLORS == (
        (255, 255, 255),
        (200, 200, 255),
        (255, 255, 200),
    )
    assert module.SPARKLE_COLORS[-1] == (255, 255, 255)


def test_rainbow_renders_a_frame(monkeypatch):
    module = load_main_module(monkeypatch)
    module.np = FakeNeoPixel(8)
    module.LED_COUNT = 8
    module.brightness = 255
    module.frame_count = 0
    module.anim_state = {}
    monkeypatch.setattr(module.time, "sleep_ms", lambda _ms: None)

    module.rainbow()

    assert module.frame_count == 1
    assert module.np.write_count == 1
    assert any(pixel != (0, 0, 0) for pixel in module.np.pixels)


def test_wave_source_no_longer_uses_dynamic_import():
    source = MAIN_PY.read_text(encoding="utf-8")
    assert "__import__('math')" not in source
    assert '__import__("math")' not in source
```

- [ ] **Step 2: 运行动画测试，确认它们先失败**

Run:

```bash
python3 -m pytest tests/test_main_runtime.py -k "wave_level or animation_palettes or rainbow_renders_a_frame or dynamic_import" -v
```

Expected:

- `test_wave_level_uses_integer_quadrants` FAIL，因为还没有 `wave_level()`
- `test_animation_palettes_are_module_constants` FAIL，因为颜色表仍在函数内局部创建
- `test_wave_source_no_longer_uses_dynamic_import` FAIL，因为源码里仍有 `__import__('math')`
- `test_rainbow_renders_a_frame` 可以先 PASS，也可以因后续重构带来的临时问题 FAIL，但最终必须 PASS

- [ ] **Step 3: 写最小实现，减少每帧分配、浮点和重复查找**

在 `main.py` 顶部增加动画常量和整数波形辅助函数，然后把热点动画改成直接复用这些常量；`wave()` 使用整数波形近似，`chase()` 直接整数缩放，`fire()` / `starry()` / `sparkle()` 不再在函数里重建列表。

```python
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


def wave_level(angle):
    angle %= 360
    if angle < 90:
        return angle * 255 // 90
    if angle < 180:
        return 255 - ((angle - 90) * 255 // 90)
    if angle < 270:
        return -((angle - 180) * 255 // 90)
    return -255 + ((angle - 270) * 255 // 90)
```

把 `wave()` 改成整数近似版本：

```python
def wave():
    global frame_count
    offset = (frame_count * 3) % 360
    pixels = np
    scale = setb

    for i in range(LED_COUNT):
        level = wave_level(offset + i * 12)
        if level >= 0:
            pixels[i] = scale((255 - level, level, 0))
        else:
            neg = -level
            pixels[i] = scale((0, 255 - neg, neg))

    pixels.write()
    frame_count += 1
    time.sleep_ms(30)
```

把 `fire()` / `starry()` / `sparkle()` 改成复用常量：

```python
def fire():
    np.fill((0, 0, 0))
    scale = setb
    for i in range(LED_COUNT):
        if rnd() < 0.3:
            np[i] = scale(FIRE_COLORS[random.getrandbits(8) % 3])
    np.write()
    time.sleep_ms(50)
```

把 `chase()` 里临时列表推导改成直接整数计算：

```python
def chase():
    global anim_state
    if "p" not in anim_state:
        anim_state = {"p": 0}

    pos = anim_state["p"]
    np.fill((0, 0, 0))

    for color_index, color in enumerate(CHASE_COLORS):
        red, green, blue = color
        for tail in range(5):
            led = (pos - color_index * 5 - tail) % LED_COUNT
            factor = 5 - tail
            np[led] = setb(
                (
                    red * factor // 5,
                    green * factor // 5,
                    blue * factor // 5,
                )
            )

    np.write()
    anim_state["p"] = (pos + 1) % LED_COUNT
    time.sleep_ms(80)
```

`snake()` 不要求完全复制旧实现，只要求保持“蛇身移动 + 目标点 + 吃到后刷新”的可见风格，并把状态收敛为固定键，例如：

```python
anim_state = {
    "snake_body": [0, 1, 2, 3, 4, 5, 6, 7],
    "snake_dir": 1,
    "snake_food": 20,
    "snake_wait": 0,
}
```

如果最终需要保留列表来表示蛇身，也要保证长度有上界，不允许无限增长。

- [ ] **Step 4: 运行动画测试，确认热点重构后行为稳定**

Run:

```bash
python3 -m pytest tests/test_main_runtime.py -k "wave_level or animation_palettes or rainbow_renders_a_frame or dynamic_import" -v
```

Expected:

- 四个测试全部 PASS
- `wave()` 不再使用循环内动态导入
- 热点动画可在主机侧假对象环境下成功渲染至少一帧

- [ ] **Step 5: 提交动画热点优化**

```bash
git add main.py tests/test_main_runtime.py
git commit -m "refactor: optimize animation hot paths"
```

---

### Task 4: 收紧 WiFi / UDP 循环并完成回归验证

**Files:**
- Modify: `main.py`
- Modify: `tests/test_main_runtime.py`
- Modify: `README.md` (only if host-side test instructions need documenting)

- [ ] **Step 1: 先写失败测试，锁定扫描排序、连接回退和配置文件读写**

把下面测试追加到 `tests/test_main_runtime.py`。这组测试覆盖能在主机侧稳定验证的网络辅助逻辑：扫描结果只保留前 5 个、连接失败会主动断开、配置文件读写仍保持旧格式。

```python
class FakeWLAN:
    def __init__(self, *, scan_results=None, connect_after=None):
        self.scan_results = scan_results or []
        self.connect_after = connect_after
        self.active_calls = []
        self.connect_calls = []
        self.disconnect_called = False
        self.isconnected_calls = 0

    def active(self, value):
        self.active_calls.append(value)

    def connect(self, ssid, password):
        self.connect_calls.append((ssid, password))

    def isconnected(self):
        self.isconnected_calls += 1
        return self.connect_after is not None and self.isconnected_calls >= self.connect_after

    def ifconfig(self):
        return ("192.168.1.9", "255.255.255.0", "192.168.1.1", "8.8.8.8")

    def disconnect(self):
        self.disconnect_called = True

    def scan(self):
        return self.scan_results


def test_scan_wifis_sorts_and_limits_to_top_five(monkeypatch):
    module = load_main_module(monkeypatch)
    fake_wlan = FakeWLAN(
        scan_results=[
            (b"a", b"", 1, -80, 0, 0),
            (b"b", b"", 1, -20, 0, 0),
            (b"c", b"", 1, -50, 0, 0),
            (b"d", b"", 1, -10, 0, 0),
            (b"e", b"", 1, -30, 0, 0),
            (b"f", b"", 1, -40, 0, 0),
        ]
    )
    module.network.WLAN = lambda *_args: fake_wlan

    result = module.scan_wifis()

    assert [item[0] for item in result] == [b"d", b"b", b"e", b"f", b"c"]


def test_try_wifi_returns_true_after_successful_connect(monkeypatch):
    module = load_main_module(monkeypatch)
    fake_wlan = FakeWLAN(connect_after=3)
    module.network.WLAN = lambda *_args: fake_wlan
    monkeypatch.setattr(module, "load_cfg", lambda: ("HomeWiFi", "secret"))
    monkeypatch.setattr(module.time, "sleep", lambda _seconds: None)

    assert module.try_wifi() is True
    assert fake_wlan.connect_calls == [("HomeWiFi", "secret")]
    assert fake_wlan.disconnect_called is False


def test_try_wifi_disconnects_after_timeout(monkeypatch):
    module = load_main_module(monkeypatch)
    fake_wlan = FakeWLAN(connect_after=None)
    module.network.WLAN = lambda *_args: fake_wlan
    monkeypatch.setattr(module, "load_cfg", lambda: ("HomeWiFi", "secret"))
    monkeypatch.setattr(module.time, "sleep", lambda _seconds: None)

    assert module.try_wifi() is False
    assert fake_wlan.disconnect_called is True


def test_save_cfg_and_load_cfg_round_trip(monkeypatch, tmp_path):
    module = load_main_module(monkeypatch)
    monkeypatch.chdir(tmp_path)

    assert module.save_cfg("HomeWiFi", "secret") is True
    assert module.load_cfg() == ("HomeWiFi", "secret")
```

- [ ] **Step 2: 运行网络辅助测试，确认它们先失败**

Run:

```bash
python3 -m pytest tests/test_main_runtime.py -k "scan_wifis or try_wifi or save_cfg_and_load_cfg" -v
```

Expected:

- 至少有一个 `try_wifi` 或 `scan_wifis` 测试 FAIL，暴露当前实现中的宽泛异常、重复逻辑或不可测试路径
- `save_cfg_and_load_cfg_round_trip` 应该尽量保持 PASS；如果失败，先修复回归再继续

- [ ] **Step 3: 写最小实现，收紧网络辅助路径并明确 GC 时机**

先把 `try_wifi()` / `scan_wifis()` 收敛成更容易推理和测试的结构，再把 `control_mode()` / `config_mode()` 的异常处理范围缩到实际 I/O 边界，并在命令处理完或周期任务后再调用 `gc.collect()`。

```python
def try_wifi():
    ssid, password = load_cfg()
    if not ssid:
        return False

    print("WiFi: %s" % ssid)
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    wlan.connect(ssid, password)

    for _ in range(50):
        if wlan.isconnected():
            print("OK! %s" % wlan.ifconfig()[0])
            return True
        time.sleep(0.1)

    print("Fail")
    wlan.disconnect()
    return False


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
```

把 `control_mode()` 命令接收收敛成“接包 / 解码”和“命令执行 / 动画帧”两个边界，不再用一个大 `except:` 包住所有逻辑，并直接复用 Task 2 中已经引入的 `parse_control_command()`：

```python
while True:
    cmd = None
    addr = None

    try:
        data, addr = sock.recvfrom(64)
        cmd = data.decode().strip().lower()
    except OSError:
        cmd = None
    except UnicodeError:
        cmd = ""

    if cmd is not None:
        kind, value = parse_control_command(cmd)

        if kind == "mode":
            if value == "next":
                mode = EFFECTS[(get_mode_idx(mode) + 1) % len(EFFECTS)]
                init_anim()
            elif value == "prev":
                mode = EFFECTS[(get_mode_idx(mode) - 1) % len(EFFECTS)]
                init_anim()
            elif value in ANIM_FUNCS:
                mode = value
                init_anim()
            sock.sendto(("OK:%s" % mode).encode(), addr)
        elif kind == "brightness":
            brightness = value
            sock.sendto(("OK:%d" % brightness).encode(), addr)
        elif kind == "status":
            sock.sendto(("MODE:%s;BRIGHT:%d" % (mode, brightness)).encode(), addr)
        elif kind == "help":
            sock.sendto(CONTROL_HELP_TEXT.encode(), addr)
        else:
            sock.sendto(b"Error", addr)

        gc.collect()

    ANIM_FUNCS[mode]()
```

配置模式同样按“接包边界”和“周期广播边界”拆开；广播刷新后再 `gc.collect()`，不要在每个分支顺手回收。

如果此任务新增了稳定可用的主机侧回归命令，再把下面这段补到 `README.md` 末尾；如果没有新增使用方式，就跳过 `README.md` 改动：

```md
## 主机侧回归测试

在不连接 ESP8266 硬件的情况下，可以先运行：

    python3 -m pytest tests/test_main_runtime.py -v
```

- [ ] **Step 4: 运行完整主机侧测试，并执行设备回归清单**

Run:

```bash
python3 -m pytest tests/test_main_runtime.py -v
```

Expected:

- `tests/test_main_runtime.py` 全部 PASS

然后把优化后的 `main.py` 烧录到设备，按下面清单做一次手工回归：

```text
1. 删除设备上的 w.cfg，重启后确认进入 CONFIG MODE
2. 向 8889 发送 status，确认返回 CONFIG_MODE
3. 向 8889 发送 list，确认能收到 WIFIS:... 或 Scanning...
4. 向 8889 发送 config:SSID:PASSWORD，确认设备保存配置并重启
5. 设备连上家庭 WiFi 后，确认进入 CONTROL MODE
6. 向 8888 发送 status，确认返回 MODE:<mode>;BRIGHT:<value>
7. 向 8888 发送 help，确认帮助文本与旧协议一致
8. 连续发送 mode:next、mode:prev 和 bright:64，确认 8 种灯效都还能切换
9. 观察 3-5 分钟，确认没有明显卡死、异常重启或帧率退化
```

可用的手工发包示例：

```bash
printf 'status' | nc -u -w1 <device-ip> 8888
printf 'help' | nc -u -w1 <device-ip> 8888
printf 'mode:next' | nc -u -w1 <device-ip> 8888
printf 'bright:64' | nc -u -w1 <device-ip> 8888
```

- [ ] **Step 5: 提交网络循环优化和最终回归**

```bash
git add main.py tests/test_main_runtime.py README.md
git commit -m "refactor: tighten runtime network loops"
```

---

## Self-Review

### Spec coverage

- “保持 `main.py` 单文件为主”:
  - Task 1-4 全部只修改 `main.py`，没有新增运行时模块
- “UDP 控制/配置行为不变”:
  - Task 2 锁定控制/配置命令解析和帮助文本
  - Task 4 锁定 `try_wifi()` / `scan_wifis()` / 配置文件读写及设备手工 UDP 回归
- “动画允许轻微视觉差异，但不能改掉整体风格”:
  - Task 3 锁定颜色表、波形辅助函数和动画至少一帧可渲染
  - Task 4 设备回归里包含 8 种灯效切换和连续观察
- “减少内存压力和 CPU 开销”:
  - Task 2 通过常量提升和纯解析函数减少字符串与列表临时对象
  - Task 3 通过颜色表提升、整数波形和去动态导入优化动画热点
  - Task 4 通过缩小异常边界和集中 GC 时机降低运行时抖动

### Placeholder scan

- 没有 `TODO`、`TBD` 或 “稍后实现” 一类占位语
- 每个代码步骤都提供了明确代码块
- 每个验证步骤都提供了明确命令和预期结果

### Type / naming consistency

- 计划里新增的函数名保持一致：
  - `clamp_u8`
  - `parse_control_command`
  - `parse_config_command`
  - `wave_level`
- 测试文件路径始终为 `tests/test_main_runtime.py`
- 运行时主文件始终为 `main.py`
