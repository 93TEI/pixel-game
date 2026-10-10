#!/usr/bin/env python3
"""Losslessly decode original BW GIFs/sheets and original OBJ geometry. No new art."""
import hashlib
import json
import math
from pathlib import Path
from PIL import Image, ImageSequence

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT/'assets/pokemon'
SOURCE = BASE/'source/bw'
OUT = BASE/'black-white/decoded'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    records = []
    def save(image, name, source, operation):
        p = OUT/name
        image.save(p)
        records.append(dict(path=name,sha256=digest(p),source=source,operation=operation))
    animations = {}
    for path in sorted((BASE/'black-white/animated').glob('*.gif')):
        original = Image.open(path)
        frames, durations = [], []
        for frame in ImageSequence.Iterator(original):
            frames.append(frame.convert('RGBA'))
            durations.append(max(10,frame.info.get('duration',100)))
        w,h = original.size
        atlas = Image.new('RGBA',(w*8,h*math.ceil(len(frames)/8)))
        for i,frame in enumerate(frames): atlas.paste(frame,(i%8*w,i//8*h))
        name = path.stem+'-animation.png'
        save(atlas,name,str(path.relative_to(BASE)),'GIF RGBA decode; 8-column packing; no resampling')
        animations[path.stem] = dict(width=w,height=h,durations=durations,frames=len(frames),foot=[w//2,h],file=name)
    (OUT/'animations.json').write_text(json.dumps(animations,separators=(',',':'))+'\n')
    sheet = Image.open(SOURCE/'trainers.png').convert('RGBA')
    trainer = Image.new('RGBA',(96,128))
    # The first block is the original male walk cycle: up/down/left/right, three frames.
    for row in range(4):
        for col in range(3):
            frame = sheet.crop((4+col*32,4+row*32,36+col*32,36+row*32))
            background = frame.getpixel((0,0))
            frame.putdata([(0,0,0,0) if p==background else p for p in frame.getdata()])
            trainer.paste(frame,(col*32,row*32))
    save(trainer,'trainer.png','source/bw/trainers.png','crop first 3x4 walk block; remove solid sheet background only')
    # Decode OBJ positions/UVs/material groups without modifying the original source.
    for number in (1,2):
        folder=SOURCE/'houses'/f'Nuvema Town House {number}'
        obj=folder/f'Nuvema Town House {number}.obj'
        vertices,uvs,groups=[],[],{}
        material=''
        for line in obj.read_text().splitlines():
            parts=line.split()
            if not parts: continue
            if parts[0]=='v': vertices.append([float(v) for v in parts[1:4]])
            elif parts[0]=='vt': uvs.append([float(parts[1]),1-float(parts[2])])
            elif parts[0]=='usemtl': material=parts[1]
            elif parts[0]=='f':
                face=[tuple(int(i)-1 for i in v.split('/')[:2]) for v in parts[1:]]
                for i in range(1,len(face)-1):
                    for vi,ti in (face[0],face[i],face[i+1]):
                        groups.setdefault(material,[]).append(vertices[vi]+uvs[ti])
        (OUT/f'house-{number}.json').write_text(json.dumps(dict(source=str(obj.relative_to(BASE)),groups=groups),separators=(',',':'))+'\n')
    (OUT/'sources.json').write_text(json.dumps(dict(game='Pokemon Black/White (2010)',files=records),indent=2)+'\n')
    print(f'Decoded {len(animations)} original GIF animations, trainer walk frames and 2 original OBJ models.')

if __name__=='__main__': main()
