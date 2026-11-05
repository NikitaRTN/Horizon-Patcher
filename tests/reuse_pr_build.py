"""Reuse only a matching, successful same-repository PR's tested launcher.

The protected main workflow validates all recorded inputs and the artifact digest.
Missing/expired artifacts, API failures, changed inputs and untrusted PRs fall back
without changing the release's other signature, patcher and smoke-test checks.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

FIELDS = ('repository', 'pr_number', 'pr_head', 'run_id', 'run_attempt',
          'tree', 'upstream_commit', 'official_sha256', 'launcher_version', 'launcher_key')


def sha256(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def matches(manifest, expected, payload):
    if not isinstance(manifest, dict) or any(manifest.get(k) != expected.get(k) for k in FIELDS):
        return False
    if not payload.is_file() or payload.is_symlink() or not (2 <= payload.stat().st_size <= 150 * 1024 * 1024):
        return False
    digest = manifest.get('payload_sha256')
    if not isinstance(digest, str) or len(digest) != 64 or digest != sha256(payload):
        return False
    with payload.open('rb') as f:
        return f.read(2) == b'MZ'


def api(path):
    return json.loads(subprocess.check_output(['gh', 'api', path], timeout=45))


def trusted_pr(pr, repo, commit):
    return (pr.get('state') == 'closed' and bool(pr.get('merged_at'))
            and pr.get('merge_commit_sha') == commit
            and ((pr.get('base') or {}).get('repo') or {}).get('full_name') == repo
            and ((pr.get('head') or {}).get('repo') or {}).get('full_name') == repo
            and bool((pr.get('head') or {}).get('sha')))


def trusted_run(run, repo, head):
    return (run.get('event') == 'pull_request' and run.get('status') == 'completed'
            and run.get('conclusion') == 'success' and run.get('head_sha') == head
            and (run.get('head_repository') or {}).get('full_name') == repo
            and (run.get('repository') or {}).get('full_name') == repo
            and run.get('path') == '.github/workflows/build.yml'
            and isinstance(run.get('id'), int) and isinstance(run.get('run_attempt'), int))


def common():
    tree = subprocess.check_output(['git', 'rev-parse', 'HEAD^{tree}'], text=True, timeout=20).strip()
    return dict(repository=os.environ['GITHUB_REPOSITORY'], tree=tree,
                upstream_commit=os.environ['UPSTREAM_COMMIT'], official_sha256=os.environ['OFFICIAL_SHA256'],
                launcher_version=os.environ['HORIZON_LAUNCHER_VERSION'], launcher_key=os.environ['LAUNCHER_CACHE_KEY'])


def write_manifest():
    event = json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text(encoding='utf-8'))
    pr = event['pull_request']
    repo = os.environ['GITHUB_REPOSITORY']
    if pr['head']['repo']['full_name'] != repo or pr['base']['repo']['full_name'] != repo:
        raise ValueError('Only same-repository pull requests produce reusable payloads')
    payload = Path('cached-launcher/horizon-launcher.exe')
    info = common() | dict(pr_number=pr['number'], pr_head=pr['head']['sha'],
                           run_id=int(os.environ['GITHUB_RUN_ID']), run_attempt=int(os.environ['GITHUB_RUN_ATTEMPT']),
                           payload_sha256=sha256(payload))
    out = Path('pr-launcher'); out.mkdir(exist_ok=True)
    shutil.copyfile(payload, out/'horizon-launcher.exe')
    (out/'manifest.json').write_text(json.dumps(info, sort_keys=True), encoding='utf-8')


def reuse():
    repo, commit = os.environ['GITHUB_REPOSITORY'], os.environ['GITHUB_SHA']
    prs = api(f'repos/{repo}/commits/{commit}/pulls')
    candidates = [pr for pr in prs if trusted_pr(pr, repo, commit)]
    if len(candidates) != 1:
        print('No unique trusted merged PR; full build required')
        return False
    pr = candidates[0]; head = pr['head']['sha']
    runs = api(f'repos/{repo}/actions/workflows/build.yml/runs?event=pull_request&head_sha={head}&status=success&per_page=20')['workflow_runs']
    for run in runs:
        if not trusted_run(run, repo, head):
            continue
        expected = common() | dict(pr_number=pr['number'], pr_head=head, run_id=run['id'], run_attempt=run['run_attempt'])
        with tempfile.TemporaryDirectory(prefix='horizon-pr-artifact-') as folder:
            result = subprocess.run(['gh', 'run', 'download', str(run['id']), '--repo', repo,
                                     '--name', f"verified-launcher-{run['run_attempt']}", '--dir', folder],
                                    capture_output=True, timeout=180)
            if result.returncode:
                print(f"No reusable artifact for run {run['id']}; trying another run")
                continue
            root = Path(folder); payload = root/'horizon-launcher.exe'
            try:
                manifest = json.loads((root/'manifest.json').read_text(encoding='utf-8'))
                valid = matches(manifest, expected, payload)
            except (ValueError, OSError, TypeError):
                valid = False
            if valid:
                dest = Path('cached-launcher/horizon-launcher.exe'); dest.parent.mkdir(exist_ok=True)
                shutil.copyfile(payload, dest)
                print(f"Reusing tested launcher from PR #{pr['number']}, run {run['id']}")
                return True
            print(f"Artifact inputs or checksum mismatch for run {run['id']}; refusing reuse")
    return False


def main():
    if sys.argv[1:] == ['write']:
        write_manifest(); return
    if sys.argv[1:] != ['reuse']:
        raise SystemExit('Usage: reuse_pr_build.py write|reuse')
    try:
        reused = reuse()
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as e:
        print(f'PR reuse unavailable ({e}); full build required')
        reused = False
    with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as f:
        f.write(f"reused={'true' if reused else 'false'}\n")


if __name__ == '__main__':
    main()
