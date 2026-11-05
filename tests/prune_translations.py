"""Remove translations made obsolete by the source privacy patch, fail closed on drift."""
import json
import sys
from pathlib import Path

REMOVED = frozenset({
    'Always on',
    'Got it',
    'Partner',
    "This build of the launcher has no Microsoft sign-in (HORIZON_MSA_CLIENT_ID), so it can't start the game.",
    "While you play, the game sends an anonymous \"I'm playing\" ping once a minute, so the launcher can show how many people play Horizon right now. It holds: a random number made when the game starts and forgotten when it closes, the Horizon version, your OS (Linux, macOS or Windows), and whether you have a world open to LAN or friends. It doesn't hold: your account, your install ID, world or server names, or anything you do in the game, and the server doesn't keep your IP address. It is sent whatever the switches say.",
})


def prune(directory: Path) -> int:
    files = sorted(directory.glob('*.json'))
    if not files:
        raise ValueError(f'No translation tables found in {directory}')
    updated = []
    for path in files:
        table = json.loads(path.read_text(encoding='utf-8'))
        if not isinstance(table, dict):
            raise ValueError(f'{path}: expected a translation object')
        missing = REMOVED - table.keys()
        if missing:
            raise ValueError(f'{path}: expected obsolete translations missing: {sorted(missing)}')
        for key in REMOVED:
            del table[key]
        updated.append((path, json.dumps(table, ensure_ascii=False, indent=2) + '\n'))
    # Validate all inputs before modifying any file.
    for path, data in updated:
        path.write_text(data, encoding='utf-8', newline='\n')
    return len(updated)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('Usage: python tests/prune_translations.py <launcher/lang>')
    print(f'Updated {prune(Path(sys.argv[1]))} translation tables')
