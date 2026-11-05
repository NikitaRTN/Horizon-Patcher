"""Apply a source patch, allowing a conflict-free three-way merge from its pinned base."""
import re
import subprocess
import sys
import tempfile
from pathlib import Path


def git(repo, *args, check=True):
    return subprocess.run(['git', '-C', str(repo), *map(str, args)], check=check)


def apply(repo, patch, base):
    repo, patch = Path(repo).resolve(), Path(patch).resolve()
    if not re.fullmatch(r'[0-9a-f]{40}', base):
        raise ValueError('Patch base must be a full lowercase commit SHA')
    if git(repo, 'apply', '--check', patch, check=False).returncode == 0:
        git(repo, 'apply', patch)
        print('Applied patch directly', flush=True)
        return 'direct'
    print('Direct apply failed; trying a verified three-way merge', flush=True)
    git(repo, 'fetch', '--depth', '1', 'origin', base)
    with tempfile.TemporaryDirectory(prefix='horizon-patch-base-') as tmp:
        worktree = Path(tmp) / 'base'
        git(repo, 'worktree', 'add', '--detach', worktree, base)
        try:
            git(worktree, 'apply', '--check', patch)
            git(repo, 'apply', '--3way', patch)
            result = subprocess.check_output(['git', '-C', str(repo), 'diff', '--name-only', '--diff-filter=U'], text=True)
            if result.strip():
                raise RuntimeError('Unresolved merge conflicts: ' + result)
        finally:
            git(repo, 'worktree', 'remove', '--force', worktree)
    print('Applied patch using a conflict-free three-way merge', flush=True)
    return 'three-way'


if __name__ == '__main__':
    if len(sys.argv) != 4:
        raise SystemExit('Usage: apply_patch.py <repo> <patch> <base-sha>')
    try:
        apply(sys.argv[1], sys.argv[2], sys.argv[3])
    except (ValueError, RuntimeError, subprocess.CalledProcessError) as exc:
        raise SystemExit(f'Patch adaptation failed safely: {exc}')