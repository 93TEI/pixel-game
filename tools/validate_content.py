#!/usr/bin/env python3
"""Validate real content invariants without third-party dependencies."""
import collections
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
data = json.loads((root / 'data/catalog.json').read_text())
entries = data['species']
by_id = {s['id']: s for s in entries}
assert len(entries) == len(by_id) == 649
assert len({s['name'] for s in entries}) == 649
families = collections.Counter(s['family'] for s in entries)
assert len(families) >= 80
assert len(data['regions']) == 9
assert collections.Counter(s['region'] for s in entries) == {r['index']: r['allocation'] for r in data['regions']}
slots = dict(D=1, C=2, B=3, A=4, S=4)
for region in data['regions']:
    assert region['boss_species'] in by_id
    for key in ('boss_hp_multiplier', 'boss_basic_power', 'boss_wave_power'):
        if key in region:
            assert isinstance(region[key], (int, float)) and 0 < region[key] < 1000
    if 'boss_party' in region:
        party = region['boss_party']
        assert region['boss_kind'] == 'trainer' and 1 <= len(party) <= 6
        assert region['boss_species'] == party[0]
        for sid in party:
            assert sid in by_id and by_id[sid]['region'] == region['index']
            previous = next((s for s in entries if s['evolves_to'] == sid), None)
            assert previous is None or region['boss_level'] >= previous['evolution_level']
for s in entries:
    assert s['slots'] == slots[s['rank']]
    assert len(s['base_stats']) == 6 and all(v > 0 for v in s['base_stats'])
    assert s['related_species'] in by_id
    for pool in s['skill_pools']:
        assert len(pool) == len(set(pool)) == 2
        for mid in pool:
            skill = data['skills'][mid]
            assert skill['id'] == mid and skill['windup'] > 0 and skill['cooldown'] > skill['windup']
    if s['evolves_to']:
        target = by_id[s['evolves_to']]
        assert target['family'] == s['family'] and target['stage'] == s['stage'] + 1
        assert target['slots'] >= s['slots']
    assert s['sprite_status'] == 'external_original'
assert sum(s['sprite_status'] == 'approved_final' for s in entries) == 0
assert [s['dex'] for s in entries] == list(range(1, 650))
assert data['content_id'] == 'pokemon-black-white-2010'
assert by_id['m001']['name'] == '이상해씨' and by_id['m649']['name'] == '게노세크트'
print('PASS: 649 Pokemon IDs/names; 9 prototype regions; evolution/move references; external original asset status.')
