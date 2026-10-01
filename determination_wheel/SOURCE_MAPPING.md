# Source mapping

This file records which statements from the supplied documents have been encoded, so app logic can be reviewed against the source rather than silently expanded from general knowledge.

## General architecture

The source describes a hoofdsleutel + detailsleutel approach and macroscopische determinatie, including comparison with gelijkende soorten. The app therefore treats the 24 positions as branching observations and does not require every specimen to traverse every position.

The 2015 presentation says to pay attention to: hoedoppervlak, lamelaanhechting, velum, hygrofaan and sporenkleur. Those are first-class wheel traits.

## Spore colour

The supplied Mycologisch Woordenboek explains a sporée/sporenfiguur and groups plaatjeszwammen artificially into Witsporige, Roodsporige, Donkersporige and Bruinsporige classes. The app data preserves these broad source categories rather than inventing a finer colour scale.

## 2015 genus/group profiles encoded

- Parasolzwammen (+): Lepiota, Cystolepiota, Macrolepiota, Leucoagaricus, Leucocoprinus.
- Fopzwammen: Laccaria.
- Wasplaten/Slijmkoppen: Hygrocybe/Hygrophorus.
- Trechtertjes: Omphalina/Rickenella.
- Taailingen (+): Marasmius, Crinipellis, Gymnopus, Rhodocollybia, Marasmiellus.
- Hertenzwammen: Pluteus.
- Bundelzwammen (+): Pholiota/Kuehneromyces.
- Kaalkopjes/Stropharia (+): Stropharia, Hypholoma, Psilocybe, Deconica.
- Schelpzwammen: source-listed shell-shaped genera.
- Mosklokjes: Galerina.
- Vaalhoeden: Hebeloma.
- Leemhoeden: Agrocybe.

The presentation's genus list is larger than the groups described in its 2015 detail slides. Unencoded groups remain pending rather than being filled from model knowledge.

## Russulaceae split

The supplied Mycologisch Woordenboek describes Russulaceae as hoed+steel fruitbodies with hard/fleshy/brittle tissue due to sferocysten and a white-to-ochre-yellow spore print. It explicitly separates Russula (no milk when damaged) from Lactarius (milk when damaged). This split is safe to encode as a genus-level branch because it is directly stated in the supplied source.

## Species endpoints

The presentations contain example species and photo captions, but those examples are not themselves complete species-level dichotomous keys. They must not be converted into guaranteed terminal identifications without the actual supporting detail-key criteria. Until those criteria are available in the supplied material, the app should return a candidate group/genus plus `verdere detailsleutel/microscopie nodig` where appropriate.
