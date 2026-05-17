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


if __name__ == "__main__":
    unittest.main()
