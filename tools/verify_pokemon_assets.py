#!/usr/bin/env python3
"""Verify fetched bytes, complete original sprite sets and rejected-art deletion."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets/pokemon'

def main():
    path = ASSETS / 'sources.json'
    if not path.exists():
        print('SKIP: optional local Pokemon assets are absent.')
        return
    sources = json.loads(path.read_text())
    for entry in sources['files']:
        file = ASSETS / entry['path']
        assert hashlib.sha256(file.read_bytes()).hexdigest() == entry['sha256'], file
    assert sources['game'] == 'Pokemon Black/White (2010)'
    for edition, suffix in [('front', 'png'), ('back', 'png'), ('animated', 'gif')]:
        assert {p.stem for p in (ASSETS/'black-white'/edition).glob('*.'+suffix)} == {f'm{i:03}' for i in range(1,650)}
    for directory in ['source/bw', 'black-white/decoded']:
        manifest = json.loads((ASSETS/directory/'sources.json').read_text())
        assert manifest['game'] == 'Pokemon Black/White (2010)'
        for entry in manifest['files']:
            file = ASSETS/directory/entry['path']
            assert hashlib.sha256(file.read_bytes()).hexdigest() == entry['sha256'], file
    for old in ['crystal', 'red-blue', 'source/pokecrystal', 'crystal_tiles.json']:
        assert not (ASSETS/old).exists(), old
    ui_manifest = ASSETS/'black-white/ui/sources.json'
    if ui_manifest.exists():
        ui = json.loads(ui_manifest.read_text())
        assert ui['game'] == 'Pokemon Black/White (2010)'
        assert hashlib.sha256((ASSETS/'source/bw/pokedex.zip').read_bytes()).hexdigest() == ui['archive_sha256']
        for entry in ui['files']:
            assert hashlib.sha256((ui_manifest.parent/entry['path']).read_bytes()).hexdigest() == entry['sha256']
            assert hashlib.sha256((ASSETS/entry['source']).read_bytes()).hexdigest() == entry['source_sha256']
    deletion = ROOT/'docs/ART_DELETION_2026-10-09.json'
    if deletion.exists():
        record = json.loads(deletion.read_text())
        for entry in record['deleted']:
            assert not (ROOT/entry['path']).exists(), entry['path']
        for relative,digest in record['preserved_user_references'].items():
            assert hashlib.sha256((ROOT/relative).read_bytes()).hexdigest() == digest
    print('PASS: 649 BW front/back/GIF sets and decoded/source hashes; rejected originals absent; user references unchanged.')

if __name__ == '__main__':
    main()
