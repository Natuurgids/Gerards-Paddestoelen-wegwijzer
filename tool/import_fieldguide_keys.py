#!/usr/bin/env python3
"""Compile a supplied Veldgids I PDF into auditable, page-cited key data.

Requires PyMuPDF only for this offline authoring tool; runtime uses JSON.
The PDF is user-supplied and is not redistributed by this repository.
"""
import argparse,hashlib,json,re
from pathlib import Path

def extract(path):
 import fitz
 doc=fitz.open(path); keys={};records=[];pending=None;key=None
 for index in range(2,26):
  page=doc[index]; width=page.rect.width
  for left,right in [(0,width/2),(width/2,width)]:
   for line in page.get_text(clip=fitz.Rect(left,34,right,page.rect.height-28)).splitlines():
    header=re.match(r'SLEUTEL (\d+): (.+)',line)
    item=re.match(r'^(\d+)\.?([ab])\.?\s*(.*)',line)
    if header:
     if pending: records.append(pending);pending=None
     key=int(header[1]);keys[key]=header[2]
    elif item:
     if pending: records.append(pending)
     pending=dict(key=key,number=int(item[1]),letter=item[2],page=index+1,lines=[item[3]])
    elif pending: pending['lines'].append(line)
 if pending: records.append(pending)
 for r in records:
  value=re.sub(r'\s+',' ',' '.join(r.pop('lines')).replace('\x07','')).strip()
  parts=re.split('[\uf0d2→]',value,maxsplit=1)
  r['condition']=parts[0].strip();r['destination']=parts[1].strip() if len(parts)>1 else ''
 return keys,records

def image(condition):
 t=condition.lower()
 if any(s in t for s in ['microscop','cystid','sporen','basidi']):return 'determination_wheel/assets/interface/spore-microscope.png'
 for word,path in [('buisjes','hymenium/pores'),('poriën','hymenium/pores'),('stekel','hymenium/spines'),('plaatjes','hymenium/gills'),('lamellen','hymenium/gills'),('plooien','hymenium/ridges'),('ring','ring/present'),('hout','substrate/wood'),('gras','substrate/grassland_soil'),('mos','substrate/moss'),('hoed','cap_shape/broad_convex')]:
  if word in t:return 'assets/images/traits/'+path+'.png'
 return 'determination_wheel/assets/interface/woodland-background.png'

def compile_book(keys,records,source='veldguide-i'):
 nodes={};endpoints={}
 for r in records:
  nid=f'{source}/{r["key"]}/{r["number"]}'
  node=nodes.setdefault(nid,dict(id=nid,title=keys[r['key']],source=source,couplet=r['number'],choices=[]))
  dest=r['destination'];other=re.search(r'sleutel (\d+)(?:,? couplet (\d+))?',dest,re.I);same=re.match(r'(?:terug naar )?(\d+)',dest)
  if other: target=f'{source}/{other[1]}/{other[2] or 1}'
  elif same:target=f'{source}/{r["key"]}/{same[1]}'
  elif dest.startswith('Parasola (zie Sleutel 35)'):target=f'{source}/35/1'
  else:
   target=f'{nid}/{r["letter"]}'
   latin=re.match(r'^([A-Z][a-zëïéäöü-]+ [a-zëïéäöü-]+)(?= |$|\()',dest)
   broad=bool(re.search(r'groep|ss?\. lat|s\.l\.|\ben\b|\bof\b|\bsoorten\b|\bvar\.',dest))
   endpoints[target]=dict(id=target,name=latin[1] if latin and not broad else dest or 'Onvolledige bronregel',kind='species' if latin and not broad else 'group' if dest else 'source_gap',detail=dest or 'De aangeleverde sleutel bevat hier geen volledige voorwaarde of bestemming. Controleer de volledige bron.',source=source,page=r['page'])
  node['choices'].append(dict(id=r['letter'],text=r['condition'],target=target,page=r['page'],image=image(r['condition']),image_scope='context_only'))
 return nodes,endpoints

def validate(nodes,endpoints):
 for n in nodes.values():
  assert sorted(x['id'] for x in n['choices'])==['a','b'],n['id']
  for c in n['choices']:
   assert c['target'] in nodes or c['target'] in endpoints,(n['id'],c['target'])
   assert Path(c['image']).is_file(),c['image']
 return True

def main():
 p=argparse.ArgumentParser();p.add_argument('pdf',type=Path);p.add_argument('--output',type=Path,default=Path('assets/data/determination_keys.json'));a=p.parse_args()
 keys,records=extract(a.pdf);nodes,endpoints=compile_book(keys,records);validate(nodes,endpoints)
 book=dict(version=1,start='veldguide-i/1/1',language='nl',sources=[dict(id='veldguide-i',title='Veldgids Paddenstoelen I · sleutels',authors='Nico Dam en Thomas W. Kuyper',sha256=hashlib.sha256(a.pdf.read_bytes()).hexdigest(),file_name=a.pdf.name)],nodes=list(nodes.values()),endpoints=list(endpoints.values()))
 a.output.write_text(json.dumps(book,ensure_ascii=False,indent=2)+'\n')
 print(len(nodes),'questions',len(endpoints),'endpoints')
if __name__=='__main__':main()
