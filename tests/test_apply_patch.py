import subprocess
import tempfile
import unittest
from pathlib import Path
from apply_patch import apply


def run(repo, *args):
    return subprocess.check_output(['git', '-C', str(repo), *map(str, args)], stderr=subprocess.STDOUT)


class AdaptationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='adapt-test-')
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.origin = root / 'origin'
        self.origin.mkdir()
        run(self.origin, 'init', '-q')
        run(self.origin, 'config', 'user.name', 'Test')
        run(self.origin, 'config', 'user.email', 'test@example.invalid')
        run(self.origin, 'config', 'core.autocrlf', 'false')
        self.original = [f'line-{i}' for i in range(20)]
        f = self.origin / 'example.txt'
        f.write_text('\n'.join(self.original) + '\n', encoding='utf-8', newline='\n')
        run(self.origin, 'add', '.')
        run(self.origin, 'commit', '-qm', 'base')
        self.base = run(self.origin, 'rev-parse', 'HEAD').decode().strip()
        edited = self.original.copy()
        edited[10] = 'patched-10'
        f.write_text('\n'.join(edited) + '\n', encoding='utf-8', newline='\n')
        self.patch = root / 'privacy.patch'
        self.patch.write_bytes(run(self.origin, 'diff', '--binary'))
        run(self.origin, 'checkout', '--', 'example.txt')
        self.clone = root / 'target'

    def clone_with_upstream_change(self, index=None):
        if index is not None:
            edited = self.original.copy()
            edited[index] = f'upstream-{index}'
            (self.origin / 'example.txt').write_text('\n'.join(edited) + '\n', encoding='utf-8', newline='\n')
            run(self.origin, 'add', '.')
            run(self.origin, 'commit', '-qm', 'upstream change')
        subprocess.run(['git', '-c', 'core.autocrlf=false', 'clone', '-q', str(self.origin), str(self.clone)], check=True)

    def test_direct_application(self):
        self.clone_with_upstream_change()
        self.assertEqual(apply(self.clone, self.patch, self.base), 'direct')
        self.assertIn('patched-10', (self.clone / 'example.txt').read_text())

    def test_three_way_keeps_both_nonconflicting_changes(self):
        self.clone_with_upstream_change(7)
        self.assertEqual(apply(self.clone, self.patch, self.base), 'three-way')
        text = (self.clone / 'example.txt').read_text()
        self.assertIn('upstream-7', text)
        self.assertIn('patched-10', text)

    def test_conflicts_stop_the_adaptation(self):
        self.clone_with_upstream_change(10)
        with self.assertRaises(subprocess.CalledProcessError):
            apply(self.clone, self.patch, self.base)

    def test_base_must_be_a_full_commit(self):
        self.clone_with_upstream_change()
        with self.assertRaises(ValueError):
            apply(self.clone, self.patch, 'main')


if __name__ == '__main__':
    unittest.main()