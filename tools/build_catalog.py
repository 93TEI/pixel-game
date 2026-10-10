#!/usr/bin/env python3
"""Build 649 Pokémon available in BW (2010) from pinned data; combat/progression are prototype adaptations."""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/pokemon/source/pokeapi'
ELEMENTS = {1:'normal',2:'fight',3:'wind',4:'poison',5:'stone',6:'stone',7:'bug',8:'shade',9:'metal',10:'flame',11:'water',12:'nature',13:'electric',14:'psychic',15:'frost',16:'dragon',17:'shade',18:'normal'}
TYPE_NAMES = {1:'노말',2:'격투',3:'비행',4:'독',5:'땅',6:'바위',7:'벌레',8:'고스트',9:'강철',10:'불꽃',11:'물',12:'풀',13:'전기',14:'에스퍼',15:'얼음',16:'드래곤',17:'악',18:'노말'}
COLORS = dict(normal='a8a878',fight='c03028',wind='a890f0',poison='a040a0',stone='b8a038',bug='a8b820',shade='705898',metal='b8b8d0',flame='f08030',water='6890f0',nature='78c850',electric='f8d030',psychic='f85888',frost='98d8d8',dragon='7038f8')
TOWNS = ['마름꽃마을','넝쿨마을','성신시티','칠보시티','구름시티','뇌문시티','물풍경시티','설화시티','포켓몬리그']
FIELDS = ['1번도로','2번도로','꿈터','바람개비숲','4번도로','5번도로','6번도로','7번도로','챔피언로드']

def rows(name):
    with (SOURCE / f'{name}.csv').open() as file:
        return list(csv.DictReader(file))

def main():
    source = {int(s['id']):s for s in rows('pokemon_species') if int(s['id']) <= 649}
    names = {int(n['pokemon_species_id']):n['name'] for n in rows('pokemon_species_names') if n['local_language_id'] == '3'}
    stats = {}
    for row in rows('pokemon_stats'):
        stats.setdefault(int(row['pokemon_id']), {})[int(row['stat_id'])] = int(row['base_stat'])
    types = {}
    for row in rows('pokemon_types'):
        if row['slot'] == '1': types[int(row['pokemon_id'])] = int(row['type_id'])
    for number in [35,36,39,40,173,174,175]: types[number] = 1
    types[122] = 14
    children = {}
    for number, definition in source.items():
        parent = definition['evolves_from_species_id']
        if parent and int(parent) in source: children.setdefault(int(parent), []).append(number)
    levels = {}
    for row in rows('pokemon_evolution'):
        if row['minimum_level'] and int(row['evolved_species_id']) <= 649:
            levels.setdefault(int(row['evolved_species_id']), int(row['minimum_level']))
    def stage(number):
        parent = source[number]['evolves_from_species_id']
        return stage(int(parent)) + 1 if parent and int(parent) in source else 0
    early_families = {source[i]['evolution_chain_id'] for i in [495,498,501,504,506,509,519,540,522]}
    regions = [dict(id=f'r{i}',index=i,town=town,name=FIELDS[i],boss_name='트레이너의 시험' if i%2==0 else '야생 포켓몬의 시험',boss_kind='trainer' if i%2==0 else 'wild',allocation=0,grass='b5ff52',path='deffde',level_min=2+i*4,level_max=6+i*4,boss_level=6+i*4,description=f'{town} 주변 실시간 전투 원형 구역입니다.') for i,town in enumerate(TOWNS)]
    species, skills = [], {}
    for number, definition in source.items():
        sid = f'm{number:03}'
        depth = stage(number)
        rare = definition['is_legendary']=='1' or definition['is_mythical']=='1'
        rank = 'S' if rare else ['D','C','B'][min(depth,2)]
        slots = {'D':1,'C':2,'B':3,'S':4}[rank]
        region = 0 if definition['evolution_chain_id'] in early_families else 1 + int(definition['evolution_chain_id']) % 8
        element = ELEMENTS[types[number]]
        pools = []
        for slot in range(4):
            pool = []
            for variant in range(2):
                mid = f'{sid}_s{slot}_{variant}'
                effect = ['damage','heal','shield','slow'][slot] if variant==0 else ['slow','damage','damage','heal'][slot]
                label = ['몸통박치기','회복','방어','견제'][slot] if variant==0 else ['견제 공격','집중 공격','돌파 공격','회복'][slot]
                skills[mid] = dict(id=mid,name=label,element=element,effect=effect,power=11+depth*3+slot*4+variant*3,windup=round(.3+slot*.15,2),cooldown=3.5+slot*1.5+variant,range=88+slot*12,color=COLORS[element])
                pool.append(mid)
            pools.append(pool)
        targets = sorted(children.get(number, []))
        target = targets[0] if targets else None
        level = levels.get(target, 20+depth*10) if target else 0
        species.append(dict(id=sid,dex=number,name=names[number],english_name=definition['identifier'],family='p'+definition['evolution_chain_id'],stage=depth,element=element,role='balanced',rank=rank,slots=slots,region=region,base_stats=[stats[number][i] for i in range(1,7)],catch_rate=max(.2,min(.85,int(definition['capture_rate'])/255)),skill_pools=pools,evolves_to=f'm{target:03}' if target else '',evolution_level=level,evolution_options=[f'm{i:03}' for i in targets],sprite_row=-1,sprite_status='external_original',concept=f'{int(definition["generation_id"])}세대 · {TYPE_NAMES[types[number]]} 타입',ecology='원본 그림: 포켓몬스터 블랙/화이트(2010). 전투·기술·진화는 이 실시간 원형의 규칙입니다.',lore='',lore_status='external_roster',related_species=f'm{target:03}' if target else sid,color=COLORS[element]))
        regions[region]['allocation'] += 1
    for r in regions:
        candidates = [s['id'] for s in species if s['region']==r['index'] and s['stage']==0]
        r['boss_species'] = candidates[-1]
        if r['boss_kind']=='trainer':
            r['boss_party'] = candidates[:3]
            r['boss_species'] = r['boss_party'][0]
    regions[0].update(wild_species=['m504','m506','m509','m519','m540','m522'],boss_species='m504',boss_party=['m504','m506','m509'],boss_hp_multiplier=1.15,boss_basic_power=8,boss_wave_power=14)
    catalog = dict(schema_version=3,content_id='pokemon-black-white-2010',regions=regions,species=species,skills=skills)
    (ROOT/'data/catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
    (ROOT/'docs/CONTENT_BIBLE.md').write_text('# Pokémon Black/White (2010) roster\n\n649 species from pinned PokéAPI CSV data. Original character designs and images replace all rejected studies. Combat, rank, region distribution and automatic evolution are prototype adaptations. Branching and non-level evolutions use the prototype’s simplified automatic progression.\n\nSee assets/pokemon/sources.json and tools/build_catalog.py.\n')
    print(f'Wrote {len(species)} Pokemon, {len(skills)} prototype moves and 9 prototype regions.')

if __name__ == '__main__':
    main()
