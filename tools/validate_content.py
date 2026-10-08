#!/usr/bin/env python3
"""Validate real content invariants without third-party dependencies."""
import collections
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
data = json.loads((root / 'data/catalog.json').read_text())
entries = data['species']
by_id = {s['id']: s for s in entries}
assert len(entries) == len(by_id) == 200
assert len({s['name'] for s in entries}) == 200
families = collections.Counter(s['family'] for s in entries)
assert collections.Counter(families.values()) == {3: 40, 2: 30, 1: 20}
assert len(data['regions']) == 9
assert collections.Counter(s['region'] for s in entries) == dict(enumerate([18,20,22,22,24,24,24,26,20]))
slots = dict(D=1, C=2, B=3, A=4, S=4)
for s in entries:
    assert s['slots'] == slots[s['rank']]
    assert len(s['base_stats']) == 6 and all(v > 0 for v in s['base_stats'])
    assert s['related_species'] in by_id and by_id[s['related_species']]['family'] != s['family']
    for pool in s['skill_pools']:
        assert len(pool) == len(set(pool)) == 2
        for mid in pool:
            skill = data['skills'][mid]
            assert skill['id'] == mid and skill['windup'] > 0 and skill['cooldown'] > skill['windup']
    if s['evolves_to']:
        target = by_id[s['evolves_to']]
        assert target['family'] == s['family'] and target['stage'] == s['stage'] + 1
        assert target['slots'] >= s['slots']
    assert s['sprite_status'] in ('integrated_concept', 'missing_final', 'approved_final')
assert sum(s['sprite_status'] == 'approved_final' for s in entries) == 0
assert all(s['sprite_status'] == 'missing_final' and s['sprite_row'] == -1 for s in entries), 'Rejected art was deleted; no active sprite attribution is valid'
print('PASS: 200 unique IDs/names; 90 families; 9 region allocations; evolution, move and lore references; honest art status.')
