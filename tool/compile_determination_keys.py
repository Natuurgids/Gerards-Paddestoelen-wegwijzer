#!/usr/bin/env python3
"""Compile the two user-supplied field-guide keys; retain page provenance."""
import argparse,hashlib,json,re
from pathlib import Path
from import_fieldguide_keys import extract,compile_book,validate,image

# Corrections to OCR of italic type, checked against the cited PDF pages.
OCR_NAMES={'Fomítopsis':'Fomitopsis','/nonotus':'Inonotus','Postía':'Postia','Ceríporia':'Ceriporia','Auriíscalpium':'Auriscalpium','Peníophora':'Peniophora','Athelía':'Athelia','Phlebiía':'Phlebia','Peníiophora':'Peniophora','Cíboria':'Ciboria','Dísciotis':'Disciotis','Catíinella':'Catinella','Crocíicreas':'Crocicreas','lodophanus':'Iodophanus','Mutínus':'Mutinus','/sariía':'Isaria','Xylaría':'Xylaria','Clavaría':'Clavaria','Ramaría':'Ramaria','Aurícularia':'Auricularia','Myriostomna':'Myriostoma','Daldínia':'Daldinia','Díatrype':'Diatrype','Diíatrype':'Diatrype','Gnomoniía':'Gnomonia','Taphríina':'Taphrina'}

def main():
 p=argparse.ArgumentParser();p.add_argument('first_pdf',type=Path);p.add_argument('second_pdf',type=Path);a=p.parse_args()
 keys,records=extract(a.first_pdf);nodes,endpoints=compile_book(keys,records)
 second=json.loads(Path('tool/source_review/fieldguide_ii_transcription.json').read_text())
 patches=[]
 for r in second['records']:
  before=r['destination']
  for bad,good in OCR_NAMES.items():r['destination']=r['destination'].replace(bad,good)
  r['destination']=re.sub(r'\s+(?:mn|nn|®)$','',r['destination'])
  r['destination']=r['destination'].removeprefix('(jonge exemplaren van) ')
  r['condition']=re.sub(r'[©®@]|\b[09à]\s+(?=[A-Z])','',r['condition']).strip(' _')
  if before!=r['destination']:patches.append(dict(page=r['page'],before=before,after=r['destination']))
 keys2={int(k):v.replace('Stekelzwwammen','Stekelzwammen').strip(' ®') for k,v in second['keys'].items()}
 keys2[10]='Overige vormen';keys2[11]='Bijzonder substraat'
 ns,es=compile_book(keys2,second['records'],'veldguide-ii')
 # Explicit reference to the bolete key of volume I, not a genus inference.
 for n in ns.values():
  for c in n['choices']:
   e=es.get(c['target'])
   if e and e['detail']=='Boleten (Veldgids, deel 1)': c['target']='veldguide-i/2/1'
 nodes.update(ns);endpoints.update(es)
 nodes['entry']=dict(id='entry',title='Kies de passende sleutel',source='entry',couplet=1,choices=[
  dict(id='a',text='Plaatjeszwammen en boleten: kies de startsleutel van Veldgids I.',target='veldguide-i/1/1',page=0,image='assets/images/traits/hymenium/gills.png'),
  dict(id='b',text='Andere vormen en taaie houtzwammen: kies de vormgroepensleutel van Veldgids II.',target='veldguide-ii/0/1',page=0,image='assets/images/traits/hymenium/spines.png')])
 for n in nodes.values():
  assert len(n['choices']) in [2,3]
  for c in n['choices']:
   assert c['target'] in nodes or c['target'] in endpoints,(n['id'],c)
   assert Path(c['image']).is_file(),c['image']
 sources=[dict(id='entry',title='Sleutelingang',authored=True)]
 for id,path,title,authors in [('veldguide-i',a.first_pdf,'Veldgids Paddenstoelen I · sleutels','Nico Dam en Thomas W. Kuyper'),('veldguide-ii',a.second_pdf,'Veldgids Paddenstoelen II · sleutels','Nico Dam, Marjo Dam en Thomas W. Kuyper')]:
  sources.append(dict(id=id,title=title,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),file_name=path.name))
 out=dict(version=1,start='entry',language='nl',sources=sources,nodes=list(nodes.values()),endpoints=list(endpoints.values()),ocr_corrections=patches)
 Path('assets/data/determination_keys.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
 species={e['name'] for e in endpoints.values() if e['kind']=='species'}
 print(len(nodes),'questions',len(endpoints),'endpoints',len(species),'distinct species-name endpoints')
 # Reachability proves source jumps, including non-first-couplet cross references.
 reached=set();todo=['entry']
 while todo:
  current=todo.pop()
  if current in reached:continue
  reached.add(current)
  if current in nodes:todo.extend(c['target'] for c in nodes[current]['choices'])
 print('unreachable questions',len(set(nodes)-reached))
 print('gaps',[(e['source'],e['page'],e['id']) for e in endpoints.values() if e['kind']=='source_gap'])
if __name__=='__main__':main()
