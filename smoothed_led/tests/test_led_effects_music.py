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
