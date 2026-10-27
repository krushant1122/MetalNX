"""Provisional memory layouts must leave room for the game's initial heap."""
from pathlib import Path
import sys
import unittest

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / 'dm/games'))
import profile_guess as pg


class UnrealMemory(unittest.TestCase):
    def test_initial_heap_fits_beside_the_engine_region(self):
        facts = {
            'mods': {'main': {'imports': {'nvnBootstrapLoader', pg.HEAP_API}, 'bss': 0, 'far': False}},
            'romfs': {'root': set(), 'exts': {'.pak': 1}},
            'sysres': 40 * pg.MiB,
            'main_markers': {'Unreal 4'},
        }
        keys = pg.guess(facts, hooks=set())
        reserve, alias, stack = (int(keys[k][0], 0) for k in ('mem_reserve', 'mem_alias', 'mem_stack'))
        self.assertGreaterEqual(alias, 64 * 1024**3)
        # mem_init puts the modules before the alias region, then stacks and the heap.
        heap = reserve - 0x10000000 - alias - stack
        self.assertGreaterEqual(heap, 128 * pg.MiB)

    def test_dynsyms_missing_tags(self):
        import nso_syms
        self.assertEqual(nso_syms.dynsyms(b''), [])
        # Image with MOD0 but missing DT_SYMTAB tag 6 and DT_STRTAB tag 5
        img = bytearray(0x100)
        img[4:8] = (0x20).to_bytes(4, 'little')
        img[0x20:0x24] = b'MOD0'
        img[0x24:0x28] = (0x10).to_bytes(4, 'little', signed=True)
        self.assertEqual(nso_syms.dynsyms(bytes(img)), [])


if __name__ == '__main__':
    unittest.main()
