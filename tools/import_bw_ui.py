#!/usr/bin/env python3
"""Decode exact doubled pixels from the locally sourced original BW dex archive."""
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'assets/pokemon'
SOURCE = BASE / 'source/bw'
OUT = BASE / 'black-white/ui'
FILES = {
    'dex-background.png': 'pokedexEntry/Info/Top Screen/background_sliding.PNG',
    'dex-heading.png': 'pokedexbg/Top Screen/top_bar.PNG',
    'dex-entry.png': 'pokedexEntry/Info/pokedexEntry.PNG',
    'dex-row.png': 'pokedexbg/pokedexSel.png',
    'dex-selected.png': 'pokedexbg/pokedexSel2.png',
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def native_pixels(image):
    """Reject any sheet that cannot round-trip through exact 2x pixel replication."""
    image = image.convert('RGBA')
    if image.width % 2 or image.height % 2:
        raise ValueError('Source dimensions are not even')
    native = image.resize((image.width // 2, image.height // 2), Image.Resampling.NEAREST)
    if native.resize(image.size, Image.Resampling.NEAREST).tobytes() != image.tobytes():
        raise ValueError('Source contains detail beyond exact 2x pixel replication')
    return native


def main():
    manifest = json.loads((SOURCE / 'sources.json').read_text())
    archive = SOURCE / 'pokedex.zip'
    expected = next(entry for entry in manifest['files'] if entry['path'] == archive.name)
    if digest(archive.read_bytes()) != expected['sha256']:
        raise ValueError('Original dex archive hash does not match provenance')
    decoded = []
    with ZipFile(archive) as contents:
        for name, relative in FILES.items():
            member = 'BW Pokedex rip/' + relative
            original = SOURCE / 'pokedex' / member
            if original.read_bytes() != contents.read(member):
                raise ValueError(f'Extracted source differs from original archive: {member}')
            with Image.open(original) as image:
                decoded.append((name, native_pixels(image), original))
    OUT.mkdir(parents=True, exist_ok=True)
    records = []
    for name, image, original in decoded:
        target = OUT / name
        image.save(target)
        records.append(dict(path=name, sha256=digest(target.read_bytes()),
                            source=str(original.relative_to(BASE)),
                            source_sha256=digest(original.read_bytes()),
                            operation='Exact 2x replicated pixels decoded to native size; RGBA round-trip verified'))
    (OUT / 'sources.json').write_text(json.dumps(dict(
        game='Pokemon Black/White (2010)', archive_sha256=expected['sha256'], files=records), indent=2) + '\n')
    print(f'Decoded {len(records)} original BW UI sheets with exact pixel round-trip verification.')


if __name__ == '__main__':
    main()
