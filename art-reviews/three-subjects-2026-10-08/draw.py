#!/usr/bin/env python3
"""New authored pixel rows and deliberate cluster placements. Read ../../dote.md.
No deleted sources, imported artwork, stochastic texture, vector rasterizer or APIs.
"""
from pathlib import Path
import struct,zlib,json,hashlib
OUT=Path(__file__).resolve().parent
P={'.':(0,0,0,0),
   'k':'#252830', 'a':'#46352f','b':'#704631','c':'#9f6b3c','d':'#c79652','e':'#e8bd77',
   'n':'#1f304b','o':'#304d73','p':'#4b7095','q':'#799baa',
   'r':'#a16450','s':'#d19364','f':'#edbb83','w':'#f5dba1',
   'u':'#394c59','v':'#5c7580',
   'h':'#2b4438','i':'#41623e','j':'#678a43','l':'#91b452','m':'#bad471','t':'#e0e3a0',
   'z':'#b89a5e','x':'#866c48'}
def rgba(c):
    c=P.get(c,c)
    return c if isinstance(c,tuple) else tuple(bytes.fromhex(c.removeprefix('#')))+(255,)
class Image:
    def __init__(self,w,h,c='.'):
        self.w,self.h=w,h;self.p=[rgba(c)]*(w*h)
    def dot(self,x,y,c):
        assert 0<=x<self.w and 0<=y<self.h,(x,y,self.w,self.h)
        self.p[y*self.w+x]=rgba(c)
    def row(self,x,y,s):
        for n,c in enumerate(s):
            if c!='.':self.dot(x+n,y,c)
    def span(self,y,x1,x2,c):
        for x in range(x1,x2+1):self.dot(x,y,c)
    def patch(self,x,y,rows):
        for dy,row in enumerate(rows.split()):self.row(x,y+dy,row)
    def paste(self,im,x,y,scale=1):
        for yy in range(im.h):
            for xx in range(im.w):
                c=im.p[yy*im.w+xx]
                if c[3]:
                    for dy in range(scale):
                        for dx in range(scale):self.dot(x+xx*scale+dx,y+yy*scale+dy,c)
    def save(self,name):
        def chunk(k,b):return struct.pack('>I',len(b))+k+b+struct.pack('>I',zlib.crc32(k+b)&0xffffffff)
        b=b''.join(b'\0'+bytes(v for c in self.p[y*self.w:(y+1)*self.w] for v in c) for y in range(self.h))
        (OUT/name).write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',self.w,self.h,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(b,9))+chunk(b'IEND',b''))
    def mapped(self,fn):
        out=Image(self.w,self.h);out.p=[fn(c) if c[3] else c for c in self.p];return out

def trainer():
    a=Image(32,44)
    # Cap/head: upper-left light, brim projects in front of the forehead.
    for y,x,s in [
      (2,12,'nnnnnnnn'),
      (3,9, 'nnopppppoonnn'),
      (4,8, 'nopppqqppooonnn'),
      (5,7, 'nopppqpppooooonnn'),
      (6,7, 'noppppppoooooonnn'),
      (7,6, 'nooppopoooooooonnn'),
      (8,6, 'nooooddddoooooonnnk'),
      (9,6, 'nnnndeeedddooooonnk'),
      (10,7,'nnddeeeeeedddoonk'),
      (11,7,'kdddddddddddbbnnk'),
      (12,7,'kabbbbbbbbbbbakk'),
      (13,7,'kabffwwwwfffbbak'),
      (14,7,'kasfwwwwwwfffak'),
      (15,8,'ksfwkffwwkffsak'),
      (16,8,'ksffkffwwkfsak'),
      (17,9,'ksffffwffffrak'),
      (18,10,'ksfffsfffsrak'),
      (19,11,'krsffffsrak'),
      (20,10,'kabrsrrsbak'),
      (21,8,'kabdccwwcbbakk'),
      (22,7,'kbcddbcwcbbbbak'),
      (23,6,'kbcdcbcwcbccbbak'),
      (24,5,'kbcdcbcwcbddcbbak'),
      (25,5,'kbcdcbbwbbddcbbak'),
      (26,5,'kbccbbuubbcccbak'),
      (27,5,'kbcbbbuubbcccbbak'),
      (28,5,'kbcbkbuvubccbkbbak'),
      (29,5,'krsbkbuuvbbbkkrsak'),
      (30,5,'ksffkbuuvbbbkkfsak'),
      (31,6,'ksfkbuuvubbbkfsak'),
      (32,7,'kkkbuuvuuubbkkk'),
      (33,9,'kuvvuukuvvvuk'),
      (34,9,'kuvvuukuvvuk'),
      (35,9,'kuvvukkkuvuk'),
      (36,9,'kuvuk..kuvuk'),
      (37,9,'kuukk..kuukk'),
      (38,8,'kbcak...kbbak'),
      (39,7,'kbcdak...kbcbbk'),
      (40,7,'kbbbak...kbbbak'),
      (41,7,'kkkkkk...kkkkkk')]:a.row(x,y,s)
    return a

def leafling():
    a=Image(40,36)
    # Folded broad leaves above a dormouse's wide cheeks and compact haunches.
    for y,x,row in [
      (2,6,'hhhh'),(3,5,'hjmmhh'),(4,5,'hjmttmlh'),
      (5,6,'hjmttmllh'),(6,7,'hjmmlljih'),(7,8,'hjjliiih'),
      (8,8,'hjlljih'),(9,9,'hjjjhh'),
      (3,27,'hhhh'),(4,24,'hhllmmjh'),(5,23,'hllmttmlh'),
      (6,22,'hjllmmljih'),(7,22,'hjlljjih'),(8,21,'hjjjiih'),
      (9,12,'hhhjjlllljih'),
      (10,10,'hjlllmmmmllljih'),
      (11,8,'hjllmmmmmmlllljjih'),
      (12,7,'hjlllmmmmlllllljjjih'),
      (13,6,'hjlllmmmlllllllkkjjih'),
      (14,5,'hjllkkllllllllkwkkjih'),
      (15,5,'hjlkwkklllllllkkkkjjih'),
      (16,4,'hjllkkklllllllkkjjjjih'),
      (17,4,'hjllwwwlllwwwwlljjjjih'),
      (18,4,'hjllwwwwwwwwwwwwljjjih'),
      (19,5,'hjllwwwwwkwwwwwwjjjih'),
      (20,5,'hjllwwwwfffwwwwljjjih'),
      (21,6,'hjjllwwwwwwwwwljjiih'),
      (22,7,'hijjlllwwwwllljjiih'),
      (23,7,'hjjlljllllllljjjiah'),
      (24,6,'hjlmljllwwwlljjiaedbh'),
      (25,6,'hjlmjjlwwwwlljjaeddbh'),
      (26,7,'hjjijlwwwwwljjiadccbh'),
      (27,7,'hijjllwwwwljjiiabbbh'),
      (28,7,'hijjlllllljjjjiihaah'),
      (29,7,'hjlljjjjjjjjlljjih'),
      (30,6,'hjmmlljjhhhjjllmjih'),
      (31,6,'hjjjjjih...hjjjjjih'),
      (32,6,'hhhhhhh.....hhhhhhh'),
      (23,32,'hh'),(24,31,'hmlh'),(25,31,'hmljh'),
      (26,30,'hjljih'),(27,29,'hjljih'),(28,28,'hjjjih'),
      (29,27,'hjjjih'),(30,27,'hiiih'),(31,28,'hhh')]:a.row(x,y,row)
    return a

def tree():
    a=Image(64,80)
    # Broad trunk with two visible branches; bark follows these bends.
    a.patch(21,40,"""
        aa..............aa
        abaa...........aba
        abbba.........abca
        .abcca.......abcca
        ..abcca.....abcca
        ...abccaa..abccba
        ....abccaaabccba
        .....abccccccba
        ......abccdcba
        ......abccdcba
        ......abcdccba
        ......abcdccba
        ......abcdccba
        ......abcdccba
        .....aabcdccba
        .....abbcdccba
        .....abbcdccba
        .....abbcdccba
        .....abbcdccba
        .....abbccbcba
        .....abbccbcba
        ....aabccbbcba
        ...aabcccbcccbaa
        ..aabccccbbccbbbaa
        .aabccbbbbbccbbbbaa
        aabbbbaaaabbbbbbbbaa
        .aaaaa....aaaaaaaa
    """)
    # One hand-authored foliage bundle. Each connected stair-step describes a
    # layered leaf plane, with open-ended highlights instead of little rings.
    bundle="""
        ..........jjjj..............
        .......jjjlllljj............
        ......jlllmmmllljj..........
        ....jjllmmmmmmllllj.........
        ...jllmmmmtmmmllmllj........
        ..jllmmtmmmmllllmmlljj......
        ..jllmmmmllllllmmmllllj.....
        .jllllmlljjllmmmmlllmljj....
        jlllmmlljjjlllmmlllmmljj....
        jllmmmlllljjllllllmmlljij...
        .jllmlllllljjllllmmlllljjii..
        .jlllljjlllllljjlllmmlljjji.
        jjllljjjjlllljjjllmmmlljjii.
        jlllljjjjjlljjjjlllllljjjii.
        .jjllljjjjjjjjjlllmljjjjii..
        ..jjjlljjjjlljjjlllmljjjii..
        ...ijjlljjlllajjlllljjjjii...
        ...iijjjjjjlljjjjlljjjii....
        ....iiijjjjjjjjjjjjjjii.....
        ......iijjjjjjjjjjjiii......
        .......iiijjjjjjjiii........
        .........iiijjiiii..........
        ...........iiii.............
    """.replace('a','j').split()
    # Branch masses overlap instead of each being outlined like a separate ball.
    # Dark rear branches -> middle side branches -> upper-left lit crown.
    ramp='hijlmt'
    for x,y,shift in [(31,24,-2),(23,36,-2),(5,31,-1),
                       (3,20,-1),(32,15,-1),(18,24,-1),
                       (21,6,-1),(9,12,0)]:
        for dy,row in enumerate(bundle):
            for dx,c in enumerate(row):
                if c!='.':a.dot(x+dx,y+dy,ramp[max(0,ramp.index(c)+shift)])
    # Merge touching branches and clean the few exposed single-pixel contacts.
    for y,x,row in [(31,28,'jjj'),(32,29,'jji'),(42,16,'ijj'),
                    (44,36,'iij'),(52,30,'hii'),(53,29,'hhi'),
                    (57,28,'dd'),(58,28,'dc'),(59,32,'bb'),
                    (60,32,'ab'),(61,32,'ab'),(63,28,'dc')]:a.row(x,y,row)
    return a

# Review lettering is a presentation aid, not a fourth sprite.
FONT={
 'A':['01110','10001','10001','11111','10001','10001','10001'],
 'C':['01111','10000','10000','10000','10000','10000','01111'],
 'D':['11110','10001','10001','10001','10001','10001','11110'],
 'E':['11111','10000','10000','11110','10000','10000','11111'],
 'F':['11111','10000','10000','11110','10000','10000','10000'],
 'G':['01111','10000','10000','10111','10001','10001','01111'],
 'I':['111','010','010','010','010','010','111'],
 'L':['10000','10000','10000','10000','10000','10000','11111'],
 'N':['10001','11001','11001','10101','10011','10011','10001'],
 'O':['01110','10001','10001','10001','10001','10001','01110'],
 'R':['11110','10001','10001','11110','10100','10010','10001'],
 'S':['01111','10000','10000','01110','00001','00001','11110'],
 'T':['11111','00100','00100','00100','00100','00100','00100'],
 'V':['10001','10001','10001','10001','10001','01010','00100'],
 'W':['10001','10001','10001','10101','10101','10101','01010'],
 'X':['10001','10001','01010','00100','01010','10001','10001'],
 '1':['010','110','010','010','010','010','111'],
 '4':['10010','10010','10010','11111','00010','00010','00010'],
 ' ':['000']*7, '/':['00001','00001','00010','00100','01000','10000','10000'],
 '-':['00000','00000','00000','11111','00000','00000','00000']}
def label(im,s,x,y,scale=2,c='#ded1ac'):
    for ch in s:
        rows=FONT[ch]
        for yy,row in enumerate(rows):
            for xx,n in enumerate(row):
                if n=='1':
                    for dy in range(scale):
                        for dx in range(scale):im.dot(x+xx*scale+dx,y+yy*scale+dy,c)
        x+=(len(rows[0])+1)*scale

def main():
    subjects={'trainer':trainer(),'leafling':leafling(),'tree':tree()}
    for name,im in subjects.items():im.save(name+'.png')
    sheet=Image(960,640,'#b59b64')
    for y in range(54):sheet.span(y,0,959,'#282b2c')
    label(sheet,'TRAINER / LEAFLING / TREE',26,19)
    for s,x in [('TRAINER',88),('LEAFLING',344),('TREE',701)]:label(sheet,s,x,68,2,'#433b30')
    positions=[(87,158),(337,194),(621,62)]
    # Feet aligned by nontransparent bounds, not by unequal empty frame padding.
    for (name,im),(x,y) in zip(subjects.items(),positions):sheet.paste(im,x,y,4)
    label(sheet,'4X',26,349,2,'#433b30')
    for y in (376,507):sheet.span(y,24,935,'#968154')
    label(sheet,'1X',26,406,2,'#433b30')
    for (name,im),x in zip(subjects.items(),(132,397,718)):
        last=max(y for y in range(im.h) if any(c[3] for c in im.p[y*im.w:(y+1)*im.w]))
        sheet.paste(im,x,476-last)
    label(sheet,'STATIC REVIEW - NOT INTEGRATED',26,552,2,'#433b30')
    sheet.save('review.png')
    native=Image(208,92,'#b59b64')
    for im,x in zip(subjects.values(),(16,72,136)):
        bottom=max(y for y in range(im.h) if any(c[3] for c in im.p[y*im.w:(y+1)*im.w]))
        native.paste(im,x,81-bottom)
    native.save('native.png')
    check=Image(768,320,'#ddd2b5')
    for y in range(160,320):check.span(y,0,767,'#353c3b')
    for i,im in enumerate(subjects.values()):
        gray=im.mapped(lambda c:(round(.2126*c[0]+.7152*c[1]+.0722*c[2]),)*3+(255,))
        sil=im.mapped(lambda c:(37,40,48,255))
        check.paste(gray,i*256+30,8,2)
        check.paste(sil,i*256+160,25,1)
        check.paste(im,i*256+60,160,2)
    check.save('diagnostics.png')
    record={'status':'new static studies awaiting user review; not approved or integrated',
      'date':'2026-10-08','rules':'../../dote.md','method':'New authored pixel rows and hand-positioned leaf clusters; standard library PNG writer; no API or deleted artwork/source',
      'subjects':{k:{'frame':[v.w,v.h]} for k,v in subjects.items()},
      'palette':P,'files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.glob('*.png')}}
    (OUT/'manifest.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
    print('Three subjects rendered: trainer, leafling, tree; review, native, diagnostics.')
if __name__=='__main__':main()
