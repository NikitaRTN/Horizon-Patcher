import json
import tempfile
import unittest
from pathlib import Path
from prune_translations import REMOVED, prune


class PruneTranslationsTests(unittest.TestCase):
    def test_removes_only_obsolete_entries(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'ru.json'
            table = {key: 'translation' for key in REMOVED}
            table['Settings'] = 'settings translation'
            path.write_text(json.dumps(table), encoding='utf-8')
            self.assertEqual(prune(Path(folder)), 1)
            self.assertEqual(json.loads(path.read_text(encoding='utf-8')), {'Settings': 'settings translation'})

    def test_missing_key_does_not_modify_any_file(self):
        with tempfile.TemporaryDirectory() as folder:
            folder = Path(folder)
            good = folder / 'a.json'
            bad = folder / 'z.json'
            data = json.dumps({key: 'translation' for key in REMOVED})
            good.write_text(data, encoding='utf-8')
            bad.write_text('{}', encoding='utf-8')
            with self.assertRaises(ValueError):
                prune(folder)
            self.assertEqual(good.read_text(encoding='utf-8'), data)

    def test_missing_tables_fails(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaises(ValueError):
                prune(Path(folder))


if __name__ == '__main__':
    unittest.main()
