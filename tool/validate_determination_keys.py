#!/usr/bin/env python3
import json
from pathlib import Path

def validate(root=Path('.')):
 book=json.loads((root/'assets/data/determination_keys.json').read_text())
 nodes={n['id']:n for n in book['nodes']};ends={e['id']:e for e in book['endpoints']}
 assert len(nodes)==len(book['nodes']) and len(ends)==len(book['endpoints'])
 assert not nodes.keys() & ends.keys()
 assert book['start'] in nodes
 sources={s['id'] for s in book['sources']}
 for n in nodes.values():
  assert n['source'] in sources
  assert len(n['choices'])>=2
  assert len({c['id'] for c in n['choices']})==len(n['choices'])
  for c in n['choices']:
   assert c['text'].strip() and c['target'] in nodes.keys()|ends.keys()
   assert (root/c['image']).is_file()
   assert 0<=c['page']<=45
 for e in ends.values():
  assert e['kind'] in ['species','group','source_gap'] and e['source'] in sources
 reached=set();todo=[book['start']]
 while todo:
  current=todo.pop()
  if current in reached:continue
  reached.add(current)
  if current in nodes:todo.extend(c['target'] for c in nodes[current]['choices'])
 assert nodes.keys()<=reached, 'Orphan questions'
 # Orphan endpoint can only be an explicitly replaced external key reference.
 assert [e['id'] for e in ends.values() if e['kind']=='source_gap']==['veldguide-i/5/37/a']
 # These source references enter a later couplet, not the target key's start.
 for nid,dest in [('veldguide-ii/4/3','veldguide-ii/5/11'),('veldguide-ii/10/35','veldguide-ii/9/41')]:
  assert nodes[nid]['choices'][0]['target']==dest
 print(f"PASS: {len(nodes)} questions; every source destination, image and page valid; all questions reachable.")
 return book
if __name__=='__main__':validate()
