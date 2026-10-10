"""Validate active vocabulary, stable relations, photographs and duplicate copy."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

def validate():
    path = ROOT / 'assets/data/identification_traits.json'
    data = json.loads(path.read_text())
    active = [t for t in data['traits'] if t.get('active', True)]
    assert len(active) == 23
    assert sum(len(t['options']) for t in active) == 341
    trait_ids, option_ids = set(), set()
    owners = {}
    for trait in data['traits']:
        assert trait['id'] not in trait_ids
        trait_ids.add(trait['id'])
        codes = set()
        for option in trait['options']:
            assert option['id'] not in option_ids
            assert option['code'] not in codes
            codes.add(option['code']); option_ids.add(option['id'])
            owners[option['id']] = trait['id']
            assert all(option['labels'].get(l, '').strip() for l in ['nl','en','de'])
            image = ROOT / option['image']
            assert image.is_file(), image
            assert image.read_bytes()[:8] == b'\x89PNG\r\n\x1a\n', image
            assert option['image_scope'] in ['state_example', 'group_example', 'context_only']
    supplement = json.loads((ROOT / 'assets/data/species_traits_europe.json').read_text())
    for relation in data['species_traits'] + supplement['species_traits']:
        assert owners[relation['option_id']] == relation['trait_id']
    assert (ROOT / 'determination_wheel/assets/data/identification_traits.json').read_bytes() == path.read_bytes()
    print('PASS: 23 active groups, 341 choices, valid photos and preserved relation identifiers.')

if __name__ == '__main__': validate()
