# 音乐律动模式 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 ESP8266 灯带固件新增基于 `MAX4466 + A0` 的 `music` 音乐律动模式，并让 Flutter 控制端可以切换和显示该模式。

**Architecture:** 固件侧把音乐模式拆成“采样/能量计算”和“渲染”两个步骤，核心逻辑集中在 `led_effects.py`，`main.py` 只负责模式注册、ADC 初始化和调度。移动端只做最小支持：补充 `music` 枚举和展示文案，继续沿用现有 UDP `mode:<name>` 协议，不扩展实时音频传输。

**Tech Stack:** MicroPython、ESP8266 ADC、NeoPixel、Python `unittest`、Flutter、Riverpod、Flutter widget/unit tests

---

## 文件边界

### 固件

- Create: `tests/test_led_effects_music.py`
  责任：在宿主机上验证音乐模式的纯算法和渲染行为，不依赖 `machine` 或真机。
- Modify: `led_effects.py`
  责任：新增音乐模式状态、能量计算、颜色映射、灯带渲染和统一入口。
- Modify: `main.py`
  责任：注册 `music` 模式、初始化 `ADC(0)`、在主循环里调度音乐模式。
- Modify: `README.md`
  责任：补充新模式说明和 `MAX4466 -> A0` 接线约束。

### Flutter 控制端

- Modify: `mobile_app/led_controller/lib/features/devices/domain/effect_mode.dart`
  责任：增加 `music` 枚举值。
- Modify: `mobile_app/led_controller/lib/features/devices/presentation/device_control_page.dart`
  责任：增加 `music` 的中文展示文案。
- Modify: `mobile_app/led_controller/test/core/network/udp_led_protocol_test.dart`
  责任：验证 `music` 模式的协议拼装和状态解析。
- Modify: `mobile_app/led_controller/test/features/devices/presentation/device_control_page_test.dart`
  责任：验证页面能展示并切换到 `music` 模式。

### 计划执行顺序

1. 先写宿主机固件算法测试，锁定音乐能量算法的外部行为。
2. 再实现 `led_effects.py` 中的音乐状态与渲染逻辑。
3. 然后接入 `main.py` 并更新文档。
4. 最后补 Flutter 模式支持和回归测试。

### Task 1: 宿主机固件测试骨架与能量算法

**Files:**
- Create: `tests/test_led_effects_music.py`
- Modify: `led_effects.py`

- [ ] **Step 1: 写失败的宿主机单元测试，先锁定静音过滤和强输入增益行为**

```python
import unittest

import led_effects as fx


class FakeADC:
    def __init__(self, values):
        self._values = list(values)
        self._index = 0

    def read(self):
        value = self._values[self._index % len(self._values)]
        self._index += 1
        return value


class MusicUpdateStateTest(unittest.TestCase):
    def setUp(self):
        self._orig_sleep_ms = getattr(fx.time, "sleep_ms", None)
        fx.time.sleep_ms = lambda _: None

    def tearDown(self):
        if self._orig_sleep_ms is None:
            delattr(fx.time, "sleep_ms")
        else:
            fx.time.sleep_ms = self._orig_sleep_ms

    def test_music_update_state_filters_steady_noise(self):
        state = fx.music_state()
        adc = FakeADC([512, 513, 512, 511, 512, 513, 512, 511])

        updated = fx.music_update_state(adc, state, sample_count=8)

        self.assertLessEqual(updated["energy"], 8)
        self.assertEqual(updated["flash"], 0)

    def test_music_update_state_detects_strong_frame(self):
        state = fx.music_state()
        quiet = FakeADC([512] * 8)
        fx.music_update_state(quiet, state, sample_count=8)
        loud = FakeADC([512, 650, 388, 630, 400, 640, 395, 620])

        updated = fx.music_update_state(loud, state, sample_count=8)

        self.assertGreater(updated["energy"], 64)
        self.assertGreater(updated["peak"], 0)
        self.assertGreater(updated["flash"], 0)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 运行测试，确认因为音乐函数尚未实现而失败**

Run: `python3 -m unittest discover -s tests -p 'test_led_effects_music.py' -v`

Expected:

```text
ERROR: test_music_update_state_filters_steady_noise ...
AttributeError: module 'led_effects' has no attribute 'music_state'
```

- [ ] **Step 3: 在 `led_effects.py` 中补最小可测的音乐状态和能量算法**

```python
MUSIC_SAMPLES=12
MUSIC_NOISE_FLOOR=8
MUSIC_BASELINE_SHIFT=5
MUSIC_RISE_SHIFT=1
MUSIC_FALL_SHIFT=3
MUSIC_PEAK_MIN=24
MUSIC_PEAK_DECAY=2
MUSIC_FLASH_STRENGTH=160
MUSIC_FLASH_DECAY=24

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
```

- [ ] **Step 4: 重新运行宿主机测试，确认能量算法通过**

Run: `python3 -m unittest discover -s tests -p 'test_led_effects_music.py' -v`

Expected:

```text
test_music_update_state_detects_strong_frame ... ok
test_music_update_state_filters_steady_noise ... ok
```

- [ ] **Step 5: 提交 Task 1**

```bash
git add tests/test_led_effects_music.py led_effects.py
git commit -m "test: cover music energy extraction"
```

### Task 2: 音乐渲染与统一入口

**Files:**
- Modify: `tests/test_led_effects_music.py`
- Modify: `led_effects.py`

- [ ] **Step 1: 为中心扩散渲染和统一入口补失败测试**

```python
class FakeNeoPixel:
    def __init__(self, count):
        self.buf = [(0, 0, 0)] * count
        self.write_count = 0

    def __setitem__(self, index, value):
        self.buf[index] = value

    def __getitem__(self, index):
        return self.buf[index]

    def fill(self, value):
        for index in range(len(self.buf)):
            self.buf[index] = value

    def write(self):
        self.write_count += 1


class MusicRenderTest(unittest.TestCase):
    def setUp(self):
        self._orig_sleep_ms = getattr(fx.time, "sleep_ms", None)
        fx.time.sleep_ms = lambda _: None

    def tearDown(self):
        if self._orig_sleep_ms is None:
            delattr(fx.time, "sleep_ms")
        else:
            fx.time.sleep_ms = self._orig_sleep_ms

    def test_music_render_expands_from_center(self):
        np = FakeNeoPixel(10)
        state = fx.music_state()
        state.update({"energy": 180, "flash": 90})

        fx.music_render(np, 10, lambda c: c, state)

        self.assertEqual(np.write_count, 1)
        self.assertNotEqual(np[4], (0, 0, 0))
        self.assertNotEqual(np[5], (0, 0, 0))
        self.assertGreater(sum(np[4]), sum(np[0]))

    def test_music_entry_updates_state_and_renders(self):
        np = FakeNeoPixel(8)
        adc = FakeADC([512, 620, 410, 600, 420, 610, 405, 590])

        state = fx.music(np, 8, lambda c: c, adc, {})

        self.assertIn("baseline", state)
        self.assertGreaterEqual(np.write_count, 1)
```

- [ ] **Step 2: 运行测试，确认因为渲染入口未实现而失败**

Run: `python3 -m unittest discover -s tests -p 'test_led_effects_music.py' -v`

Expected:

```text
ERROR: test_music_render_expands_from_center ...
AttributeError: module 'led_effects' has no attribute 'music_render'
```

- [ ] **Step 3: 在 `led_effects.py` 中补颜色映射、渲染函数和统一入口**

```python
MUSIC_BACKGROUND=(0,2,6)

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
```

- [ ] **Step 4: 重新运行宿主机测试，确认音乐模式算法与渲染均通过**

Run: `python3 -m unittest discover -s tests -p 'test_led_effects_music.py' -v`

Expected:

```text
test_music_entry_updates_state_and_renders ... ok
test_music_render_expands_from_center ... ok
test_music_update_state_detects_strong_frame ... ok
test_music_update_state_filters_steady_noise ... ok
```

- [ ] **Step 5: 提交 Task 2**

```bash
git add tests/test_led_effects_music.py led_effects.py
git commit -m "feat: add music reactive led effect"
```

### Task 3: 固件主循环接入与文档更新

**Files:**
- Modify: `main.py`
- Modify: `README.md`

- [ ] **Step 1: 先在 `main.py` 里加失败前置检查点，锁定模式表和调度入口要一起出现**

Run: `rg -n '"music"|def music|machine.ADC\\(0\\)|"music": music' main.py`

Expected:

```text
no matches found
```

- [ ] **Step 2: 修改 `main.py`，注册 `music` 模式并初始化 `ADC(0)`**

```python
mode = "rainbow"
brightness = 180
np = None
adc = None
frame_count = 0
anim_state = {}

EFFECTS = (
    "rainbow",
    "breath",
    "fire",
    "starry",
    "wave",
    "chase",
    "sparkle",
    "snake",
    "music",
)

def music():
    global anim_state
    anim_state = fx.music(np, LED_COUNT, setb, adc, anim_state)

ANIM_FUNCS = {
    "rainbow": rainbow,
    "breath": breath,
    "fire": fire,
    "starry": starry,
    "wave": wave,
    "chase": chase,
    "sparkle": sparkle,
    "snake": snake,
    "music": music,
}

def main():
    global np, adc
    np = neopixel.NeoPixel(Pin(LED_PIN, Pin.OUT), LED_COUNT)
    adc = machine.ADC(0)
    np.fill((0, 0, 0))
    np.write()
```

- [ ] **Step 3: 修改 `README.md`，补充新模式和 MAX4466 接线注意事项**

```markdown
## 音乐律动模式接线

- `MAX4466 VCC -> ESP8266 3V3`
- `MAX4466 GND -> ESP8266 GND`
- `MAX4466 OUT -> ESP8266 A0`

注意：

- 不同 NodeMCU 开发板的 `A0` 分压设计不同，接线前必须确认开发板允许的最大输入电压。
- `music` 模式是基于音量包络的实时律动，不做精确鼓点识别或频谱分析。

## 内置灯效

- `rainbow`：彩虹渐变循环。
- `breath`：红色全灯呼吸状态机。
- `fire`：随机火焰闪烁。
- `starry`：随机星点闪烁。
- `wave`：基于正弦波的颜色流动。
- `chase`：多色追逐尾迹。
- `sparkle`：随机彩色闪光。
- `snake`：带“食物”目标的贪吃蛇式移动效果。
- `music`：读取 `MAX4466` 声音包络并做中心扩散与峰值闪击。
```

- [ ] **Step 4: 重新检查固件入口是否全部接通**

Run: `rg -n '"music"|def music|machine.ADC\\(0\\)|"music": music' main.py README.md`

Expected:

```text
main.py:...
README.md:...
```

- [ ] **Step 5: 提交 Task 3**

```bash
git add main.py README.md
git commit -m "feat: wire music mode into firmware"
```

### Task 4: Flutter 模式枚举、协议与页面文案

**Files:**
- Modify: `mobile_app/led_controller/lib/features/devices/domain/effect_mode.dart`
- Modify: `mobile_app/led_controller/lib/features/devices/presentation/device_control_page.dart`
- Modify: `mobile_app/led_controller/test/core/network/udp_led_protocol_test.dart`
- Modify: `mobile_app/led_controller/test/features/devices/presentation/device_control_page_test.dart`

- [ ] **Step 1: 先补失败测试，覆盖协议和页面对 `music` 的识别**

```dart
test('music 模式可被拼装和解析', () {
  final protocol = UdpLedProtocol();

  expect(protocol.modeCommand(EffectMode.music), 'mode:music');

  final status = protocol.parseStatus('MODE:music;BRIGHT:210');
  expect(status.mode, EffectMode.music);
  expect(status.brightness, 210);
});
```

```dart
testWidgets('控制页展示音乐律动模式文案', (tester) async {
  final udpClient = FakeUdpClient();
  udpClient.responses
    ..clear()
    ..addAll(<String>['MODE:music;BRIGHT:120']);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        udpClientProvider.overrideWithValue(udpClient),
        deviceRepositoryProvider.overrideWithValue(FakeDeviceRepository()),
      ],
      child: MaterialApp(
        home: DeviceControlPage(device: buildDevice()),
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('音乐律动'), findsWidgets);
});
```

```dart
testWidgets('点击音乐律动后发送 mode:music 命令', (tester) async {
  final udpClient = FakeUdpClient();
  udpClient.responses
    ..clear()
    ..addAll(<String>[
      'MODE:rainbow;BRIGHT:180',
      'ok',
      'MODE:music;BRIGHT:180',
    ]);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        udpClientProvider.overrideWithValue(udpClient),
        deviceRepositoryProvider.overrideWithValue(FakeDeviceRepository()),
      ],
      child: MaterialApp(
        home: DeviceControlPage(device: buildDevice()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('音乐律动'));
  await tester.pumpAndSettle();

  expect(udpClient.payloads, contains('mode:music'));
  expect(find.text('音乐律动'), findsWidgets);
});
```

- [ ] **Step 2: 运行 Flutter 测试，确认因为枚举和文案尚未补充而失败**

Run: `flutter test test/core/network/udp_led_protocol_test.dart test/features/devices/presentation/device_control_page_test.dart`

Expected:

```text
Failed to compile test...
Error: Member not found: 'music'
```

- [ ] **Step 3: 修改枚举与页面文案，让 `music` 沿用现有协议路径工作**

```dart
enum EffectMode {
  rainbow,
  breath,
  fire,
  starry,
  wave,
  chase,
  sparkle,
  snake,
  music,
}
```

```dart
      case EffectMode.music:
        return '音乐律动';
```

- [ ] **Step 4: 重新运行 Flutter 测试，确认协议解析和 UI 展示通过**

Run: `flutter test test/core/network/udp_led_protocol_test.dart test/features/devices/presentation/device_control_page_test.dart`

Expected:

```text
00:00 +0: loading ...
00:01 +N: All tests passed!
```

- [ ] **Step 5: 提交 Task 4**

```bash
git add \
  mobile_app/led_controller/lib/features/devices/domain/effect_mode.dart \
  mobile_app/led_controller/lib/features/devices/presentation/device_control_page.dart \
  mobile_app/led_controller/test/core/network/udp_led_protocol_test.dart \
  mobile_app/led_controller/test/features/devices/presentation/device_control_page_test.dart
git commit -m "feat: add music mode to flutter controller"
```

### Task 5: 回归验证与真机检查

**Files:**
- Modify: none expected

- [ ] **Step 1: 运行宿主机固件测试，确认音乐模式核心逻辑稳定**

Run: `python3 -m unittest discover -s tests -p 'test_led_effects_music.py' -v`

Expected:

```text
Ran 4 tests in ...
OK
```

- [ ] **Step 2: 运行 Flutter 相关测试，确认 App 支持没有回归**

Run: `flutter test`

Expected:

```text
All tests passed!
```

- [ ] **Step 3: 做固件静态核对，确认帮助文本、状态与模式列表一致**

Run: `rg -n 'EFFECTS =|CONTROL_HELP_TEXT|MODE:%s;BRIGHT:%d|music' main.py README.md mobile_app/led_controller/lib/features/devices/domain/effect_mode.dart`

Expected:

```text
main.py:...
README.md:...
effect_mode.dart:...
```

- [ ] **Step 4: 按真机清单验证 MAX4466 驱动的音乐律动模式**

```text
1. 将 MAX4466 按 README 接到 3V3 / GND / A0。
2. 烧录更新后的 main.py 和 led_effects.py。
3. 通过 UDP 或 Flutter 切换到 mode:music。
4. 在安静环境观察 10 秒，确认灯带基本不乱闪。
5. 播放音乐并逐步增大音量，确认灯从中心向两侧扩张。
6. 对着麦克风拍手或播放强节拍，确认中心出现短时高亮冲击。
7. 切回 wave、fire 等旧模式，确认不残留 music 状态。
```

- [ ] **Step 5: 检查最终工作区状态**

```bash
git status --short
```

Expected:

```text
nothing to commit, working tree clean
```
