#!/usr/bin/env python3
"""Fetch pinned original assets/data at no cost; never generate replacement art."""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'assets/pokemon'
COMMITS = {'sprites': '35fdbe9bdec8f519f882c3edc3c0185f08af4d86',
           'pokeapi': '2fe95532d27a9bf340575253aff50868319d8182'}

def fetch(item):
    relative, url = item
    path = DEST / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists():
        temp = path.with_suffix(path.suffix + '.download')
        subprocess.run(['curl', '--fail', '--location', '--silent', '--show-error',
                        '--retry', '2', '--max-time', '40', url, '-o', str(temp)], check=True)
        temp.replace(path)
    return dict(path=relative, url=url, sha256=hashlib.sha256(path.read_bytes()).hexdigest())

def main():
    prefix = f"https://raw.githubusercontent.com/PokeAPI/sprites/{COMMITS['sprites']}/sprites/pokemon/versions"
    # Only the 649 species present in BW (2010); later fan-made Gen-V-style sprites are excluded.
    jobs = [(f'black-white/front/m{i:03}.png', f'{prefix}/generation-v/black-white/{i}.png') for i in range(1, 650)]
    jobs += [(f'black-white/back/m{i:03}.png', f'{prefix}/generation-v/black-white/back/{i}.png') for i in range(1, 650)]
    jobs += [(f'black-white/animated/m{i:03}.gif', f'{prefix}/generation-v/black-white/animated/{i}.gif') for i in range(1, 650)]
    for name in ['pokemon_species', 'pokemon_species_names', 'pokemon_stats', 'pokemon_types', 'pokemon_evolution']:
        jobs.append((f'source/pokeapi/{name}.csv', f"https://raw.githubusercontent.com/PokeAPI/pokeapi/{COMMITS['pokeapi']}/data/v2/csv/{name}.csv"))
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        records = list(pool.map(fetch, jobs))
    (DEST / 'source/.gdignore').touch()
    (DEST / 'source/commits.json').write_text(json.dumps(COMMITS, indent=2) + '\n')
    (DEST / 'sources.json').write_text(json.dumps({'game': 'Pokemon Black/White (2010)', 'commits': COMMITS, 'files': records,
        'rights': 'Pokemon graphics/characters belong to their respective rights holders. Not project-created and not covered by this project MIT license.'}, indent=2) + '\n')
    print(f'Fetched and hashed {len(records)} original asset/data files.')

if __name__ == '__main__':
    main()
