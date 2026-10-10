"""Ensure every encoded choice has a real, bundled raster asset."""
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'lib/photographic_assets.dart').read_text()
constants = dict(re.findall(r"const (\w+)='(assets/[^']+)';", source))
entries = re.findall(r"  '([^']+)':(?:'([^']+)'|(\w+)),", source)
images = {label: path or constants[constant] for label, path, constant in entries}
steps = (ROOT / 'lib/wheel_steps.dart').read_text()
labels = set(re.findall(r"WheelOption\('([^']+)'", steps))
for match in re.finditer(r"q\(.*?\[(.*?)\]", steps):
    labels.update(re.findall(r"'([^']+)'", match.group(1)))
labels.update(re.findall(r"DetailOption\('([^']+)'", (ROOT / 'lib/detail_keys.dart').read_text()))
missing = labels - images.keys()
assert not missing, f'Unmapped observation choices: {sorted(missing)}'
paths = set(images.values()) | set(constants.values())
for path in sorted(paths):
    data = (ROOT / path).read_bytes()
    assert data.startswith(b'\x89PNG\r\n\x1a\n'), f'Not a PNG: {path}'
    width, height = struct.unpack('>II', data[16:24])
    assert min(width, height) >= 128, f'Insufficient image resolution: {path}'
    assert data[-12:-8] == b'\x00\x00\x00\x00' and data[-8:-4] == b'IEND', f'Incomplete PNG: {path}'
print(f'PASS: {len(labels)} unique observation/detail choices, {len(paths)} bundled photographs/textures; all mappings and PNGs valid.')
