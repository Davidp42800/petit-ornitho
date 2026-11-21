"""Compact JSON catalogues in the built Flutter web bundle, preserving JSON tokens."""
import argparse
import json
import re
from pathlib import Path

# Keep entire string literals, including escapes. Remove JSON whitespace elsewhere.
TOKEN = re.compile(
    rb'"(?:[^"\\]+|\\.)*"|[ \t\n\r]+'
)


def compact(bundle):
    directory = bundle / 'assets/assets/data'
    paths = sorted(directory.glob('*.json'))
    if not paths:
        raise ValueError(f'No built catalogues in {directory}')
    before = after = 0
    for path in paths:
        original = path.read_bytes()
        decoded = json.loads(original)
        packed = TOKEN.sub(lambda m: m[0] if m[0].startswith(b'"') else b'', original)
        if decoded != json.loads(packed):
            raise ValueError(f'JSON mismatch in {path}')
        before += len(original)
        after += len(packed)
        if packed != original:
            temporary = path.with_suffix('.json.tmp')
            temporary.write_bytes(packed)
            temporary.replace(path)
    print(f'{len(paths)} JSON catalogues: {before:,} -> {after:,} bytes')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('bundle', type=Path, nargs='?', default=Path('build/web'))
    compact(parser.parse_args().bundle)
