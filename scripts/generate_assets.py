import base64
import getpass
import os
import time
from openai import OpenAI

# Client initialiseren met een lokale API-key. De key wordt niet opgeslagen.
api_key = os.environ.get("OPENAI_API_KEY") or getpass.getpass("OpenAI API key (wordt niet opgeslagen): ")
if not api_key:
    raise RuntimeError("Geen OpenAI API key opgegeven.")
client = OpenAI(api_key=api_key)

# Bestanden komen rechtstreeks in de assets-map terecht.
output_dir = "assets"
os.makedirs(output_dir, exist_ok=True)

BASE_PROMPT_SUFFIX = " Isolated on a seamless solid white background, high-detail scientific reference photo, soft even studio lighting, crisp focus, centered subject, no text, no labels, no border, no background objects, minimal background shadow."

# COMPLETE LIJST VAN ALLE 23 KARAKTERGROEPEN MET HUN OPTIES
ITEMS_TO_GENERATE = [
    # 1. Cap colour (24 states)
    {"filename": "cap_colour_white.png", "prompt": "Macro photo of a white mushroom cap surface"},
    {"filename": "cap_colour_cream.png", "prompt": "Macro photo of a cream colored mushroom cap surface"},
    {"filename": "cap_colour_yellow.png", "prompt": "Macro photo of a bright yellow mushroom cap surface"},
    {"filename": "cap_colour_orange.png", "prompt": "Macro photo of an orange mushroom cap surface"},
    {"filename": "cap_colour_red.png", "prompt": "Macro photo of a red mushroom cap surface"},
    {"filename": "cap_colour_pink.png", "prompt": "Macro photo of a pink mushroom cap surface"},
    {"filename": "cap_colour_lilac.png", "prompt": "Macro photo of a lilac purple mushroom cap surface"},
    {"filename": "cap_colour_violet.png", "prompt": "Macro photo of a deep violet mushroom cap surface"},
    {"filename": "cap_colour_blue.png", "prompt": "Macro photo of a bluish mushroom cap surface"},
    {"filename": "cap_colour_green.png", "prompt": "Macro photo of an olive green mushroom cap surface"},
    {"filename": "cap_colour_light_brown.png", "prompt": "Macro photo of a light tan brown mushroom cap surface"},
    {"filename": "cap_colour_dark_brown.png", "prompt": "Macro photo of a dark chestnut brown mushroom cap surface"},
    {"filename": "cap_colour_red_brown.png", "prompt": "Macro photo of a reddish brown mushroom cap surface"},
    {"filename": "cap_colour_yellow_brown.png", "prompt": "Macro photo of a yellowish brown mushroom cap surface"},
    {"filename": "cap_colour_grey.png", "prompt": "Macro photo of a grey mushroom cap surface"},
    {"filename": "cap_colour_black.png", "prompt": "Macro photo of a black mushroom cap surface"},
    {"filename": "cap_colour_hygrophanous.png", "prompt": "Macro photo of a two-toned hygrophanous mushroom cap surface"},
    {"filename": "cap_colour_concentric.png", "prompt": "Macro photo of a concentrically ringed colored mushroom cap surface"},
    {"filename": "cap_colour_spotted.png", "prompt": "Macro photo of a spotted mushroom cap surface"},
    {"filename": "cap_colour_streaked.png", "prompt": "Macro photo of a radially streaked mushroom cap surface"},
    {"filename": "cap_colour_metallic.png", "prompt": "Macro photo of a metallic sheen mushroom cap surface"},
    {"filename": "cap_colour_bicolour.png", "prompt": "Macro photo of a bicolour mushroom cap surface"},
    {"filename": "cap_colour_pale.png", "prompt": "Macro photo of a pale buff mushroom cap surface"},
    {"filename": "cap_colour_ochre.png", "prompt": "Macro photo of an ochre yellow-brown mushroom cap surface"},

    # 2. Cap shape (14 states)
    {"filename": "cap_shape_campanulate.png", "prompt": "A single bell-shaped (campanulate) mushroom cap"},
    {"filename": "cap_shape_conical.png", "prompt": "A single conical mushroom cap with pointed tip"},
    {"filename": "cap_shape_convex.png", "prompt": "A single convex dome-shaped mushroom cap"},
    {"filename": "cap_shape_planar.png", "prompt": "A single flat planar mushroom cap"},
    {"filename": "cap_shape_depressed.png", "prompt": "A single depressed mushroom cap with sunken center"},
    {"filename": "cap_shape_umbonate.png", "prompt": "A single umbonate mushroom cap with central bump"},
    {"filename": "cap_shape_papillate.png", "prompt": "A single papillate mushroom cap with small nipple-like bump"},
    {"filename": "cap_shape_funnel.png", "prompt": "A single funnel-shaped infundibuliform mushroom cap"},
    {"filename": "cap_shape_hemispherical.png", "prompt": "A single hemispherical half-round mushroom cap"},
    {"filename": "cap_shape_disc.png", "prompt": "A single disc-shaped thin mushroom cap"},
    {"filename": "cap_shape_ovate.png", "prompt": "A single egg-shaped ovate mushroom cap"},
    {"filename": "cap_shape_irregular.png", "prompt": "A single irregular wavy-edged mushroom cap"},
    {"filename": "cap_shape_offset.png", "prompt": "A single eccentric kidney-shaped mushroom cap"},
    {"filename": "cap_shape_spherical.png", "prompt": "A single round spherical young mushroom cap"},

    # 3. Cap surface (15 states)
    {"filename": "cap_surface_smooth.png", "prompt": "Macro texture photo of a completely smooth mushroom cap surface"},
    {"filename": "cap_surface_scaly.png", "prompt": "Macro texture photo of a scaly flaking mushroom cap surface"},
    {"filename": "cap_surface_fibrillose.png", "prompt": "Macro texture photo of a fibrous hairy mushroom cap surface"},
    {"filename": "cap_surface_warty.png", "prompt": "Macro texture photo of a warty spotted mushroom cap surface"},
    {"filename": "cap_surface_grooved.png", "prompt": "Macro texture photo of a radially grooved striate mushroom cap surface"},
    {"filename": "cap_surface_viscid.png", "prompt": "Macro texture photo of a slimy sticky shiny mushroom cap surface"},
    {"filename": "cap_surface_velvety.png", "prompt": "Macro texture photo of a velvety fine-haired mushroom cap surface"},
    {"filename": "cap_surface_wrinkled.png", "prompt": "Macro texture photo of a wrinkled reticulate mushroom cap surface"},
    {"filename": "cap_surface_cracked.png", "prompt": "Macro texture photo of a cracked rimose mushroom cap surface"},
    {"filename": "cap_surface_silky.png", "prompt": "Macro texture photo of a silky shiny mushroom cap surface"},
    {"filename": "cap_surface_zonate.png", "prompt": "Macro texture photo of a concentrically ringed zone surface"},
    {"filename": "cap_surface_hairy.png", "prompt": "Macro texture photo of a coarse hairy shaggy cap surface"},
    {"filename": "cap_surface_pitted.png", "prompt": "Macro texture photo of a pitted indented cap surface"},
    {"filename": "cap_surface_powdery.png", "prompt": "Macro texture photo of a powdery mealy coating cap surface"},
    {"filename": "cap_surface_gelatinous.png", "prompt": "Macro texture photo of a gelatinous thick rubbery cap surface"},

    # 4. Underside type (7 states)
    {"filename": "underside_gills.png", "prompt": "Macro photo of mushroom underside with thin bladelike gills"},
    {"filename": "underside_pores.png", "prompt": "Macro photo of mushroom underside with sponge-like pores (bolete style)"},
    {"filename": "underside_spines.png", "prompt": "Macro photo of mushroom underside with hanging tooth-like spines"},
    {"filename": "underside_ridges.png", "prompt": "Macro photo of mushroom underside with blunt false gill ridges (chanterelle style)"},
    {"filename": "underside_smooth.png", "prompt": "Macro photo of mushroom underside with completely smooth surface"},
    {"filename": "underside_enclosed.png", "prompt": "Macro photo of closed gleba puffball internal structure"},
    {"filename": "underside_fold.png", "prompt": "Macro photo of mushroom underside with shallow vein-like folds"},

    # 5. Gill attachment (9 states)
    {"filename": "gill_attach_free.png", "prompt": "Macro view of mushroom gills strictly free from the stem"},
    {"filename": "gill_attach_adnate.png", "prompt": "Macro view of mushroom gills broadly attached (adnate) to the stem"},
    {"filename": "gill_attach_decurrent.png", "prompt": "Macro view of mushroom gills running down the stem (decurrent)"},
    {"filename": "gill_attach_sinuate.png", "prompt": "Macro view of mushroom gills notched near the stem (sinuate)"},
    {"filename": "gill_attach_emarginate.png", "prompt": "Macro view of mushroom gills sharply indented before stem"},
    {"filename": "gill_attach_adnexed.png", "prompt": "Macro view of mushroom gills narrowly attached to the stem"},
    {"filename": "gill_attach_seceding.png", "prompt": "Macro view of mushroom gills pulling away from stem as cap expands"},
    {"filename": "gill_attach_collariate.png", "prompt": "Macro view of mushroom gills attached to a collar around stem"},
    {"filename": "gill_attach_subdecurrent.png", "prompt": "Macro view of mushroom gills slightly running down stem"},

    # 6. Gill spacing (6 states)
    {"filename": "gill_space_crowded.png", "prompt": "Macro photo showing extremely tightly packed, crowded mushroom gills"},
    {"filename": "gill_space_close.png", "prompt": "Macro photo showing close together mushroom gills"},
    {"filename": "gill_space_moderate.png", "prompt": "Macro photo showing moderately spaced mushroom gills"},
    {"filename": "gill_space_distant.png", "prompt": "Macro photo showing widely spaced distant mushroom gills"},
    {"filename": "gill_space_very_distant.png", "prompt": "Macro photo showing sparse very distant mushroom gills"},
    {"filename": "gill_space_forked.png", "prompt": "Macro photo showing branching forked mushroom gills"},

    # 7. Gill colour (12 states)
    {"filename": "gill_colour_white.png", "prompt": "Macro photo of white mushroom gills"},
    {"filename": "gill_colour_cream.png", "prompt": "Macro photo of cream mushroom gills"},
    {"filename": "gill_colour_yellow.png", "prompt": "Macro photo of yellow mushroom gills"},
    {"filename": "gill_colour_pink.png", "prompt": "Macro photo of pinkish salmon mushroom gills"},
    {"filename": "gill_colour_red.png", "prompt": "Macro photo of reddish orange mushroom gills"},
    {"filename": "gill_colour_purple.png", "prompt": "Macro photo of violet purple mushroom gills"},
    {"filename": "gill_colour_brown.png", "prompt": "Macro photo of cinnamon brown mushroom gills"},
    {"filename": "gill_colour_dark_brown.png", "prompt": "Macro photo of dark chocolate brown mushroom gills"},
    {"filename": "gill_colour_grey.png", "prompt": "Macro photo of grey mushroom gills"},
    {"filename": "gill_colour_black.png", "prompt": "Macro photo of black mushroom gills"},
    {"filename": "gill_colour_mottled.png", "prompt": "Macro photo of spotted mottled multi-toned mushroom gills"},
    {"filename": "gill_colour_olive.png", "prompt": "Macro photo of olive-greenish mushroom gills"},

    # 8. Stem ring (4 states)
    {"filename": "stem_ring_present.png", "prompt": "Mushroom stem with a distinct ring (annulus)"},
    {"filename": "stem_ring_absent.png", "prompt": "Mushroom stem without any ring"},
    {"filename": "stem_ring_remnant.png", "prompt": "Mushroom stem with faint ring zone remnants"},
    {"filename": "stem_ring_double.png", "prompt": "Mushroom stem with a thick double-layered ring"},

    # 9. Ring form (7 states)
    {"filename": "ring_form_pendant.png", "prompt": "Mushroom ring hanging down like a skirt (pendant)"},
    {"filename": "ring_form_skirted.png", "prompt": "Mushroom ring flaring widely flared outward"},
    {"filename": "ring_form_zone.png", "prompt": "Mushroom ring appearing only as a narrow faint band"},
    {"filename": "ring_form_cobwebby.png", "prompt": "Mushroom ring formed by cobweb-like curtain (cortina)"},
    {"filename": "ring_form_flaring.png", "prompt": "Mushroom ring pointing upward"},
    {"filename": "ring_form_movable.png", "prompt": "Mushroom ring loose and sliding on stem"},
    {"filename": "ring_form_fragile.png", "prompt": "Mushroom ring delicate and torn"},

    # 10. Volva presence (4 states)
    {"filename": "volva_present.png", "prompt": "Mushroom stem base enclosed in a distinct cup-like volva"},
    {"filename": "volva_absent.png", "prompt": "Mushroom stem base completely lacking a volva"},
    {"filename": "volva_saccate.png", "prompt": "Mushroom base with a large sack-like sheath"},
    {"filename": "volva_remnant.png", "prompt": "Mushroom base with concentric volval rings or flakes"},

    # 11. Volva form (6 states)
    {"filename": "volva_form_saccate.png", "prompt": "Saccate sack-like white volva around stem base"},
    {"filename": "volva_form_cuplike.png", "prompt": "Cup-like tight volva structure"},
    {"filename": "volva_form_sheathing.png", "prompt": "Sheathing volva hugging stem base"},
    {"filename": "volva_form_mealy.png", "prompt": "Friable powdery granular volva remnants"},
    {"filename": "volva_form_membranous.png", "prompt": "Membranous thin volva cup"},
    {"filename": "volva_form_zonate.png", "prompt": "Volva broken into ringed bands on stem base"},

    # 12. Stem surface (10 states)
    {"filename": "stem_surf_smooth.png", "prompt": "Macro photo of a completely smooth mushroom stem surface"},
    {"filename": "stem_surf_fibrillose.png", "prompt": "Macro photo of a streaky fibrous mushroom stem"},
    {"filename": "stem_surf_scaly.png", "prompt": "Macro photo of a scaly rough mushroom stem"},
    {"filename": "stem_surf_reticulate.png", "prompt": "Macro photo of a netted pattern (reticulate) mushroom stem"},
    {"filename": "stem_surf_striate.png", "prompt": "Macro photo of a vertically grooved mushroom stem"},
    {"filename": "stem_surf_velvety.png", "prompt": "Macro photo of a velvety fuzzy dark mushroom stem"},
    {"filename": "stem_surf_punctate.png", "prompt": "Macro photo of a dotted gland-spotted stem surface"},
    {"filename": "stem_surf_mealy.png", "prompt": "Macro photo of a dusted powdery top mushroom stem"},
    {"filename": "stem_surf_viscid.png", "prompt": "Macro photo of a slimy glistening mushroom stem"},
    {"filename": "stem_surf_grooved.png", "prompt": "Macro photo of deeply channeled grooved stem"},

    # 13. Stem colour (18 states)
    {"filename": "stem_col_white.png", "prompt": "Pure white mushroom stem"},
    {"filename": "stem_col_cream.png", "prompt": "Cream ivory mushroom stem"},
    {"filename": "stem_col_yellow.png", "prompt": "Bright yellow mushroom stem"},
    {"filename": "stem_col_orange.png", "prompt": "Vibrant orange mushroom stem"},
    {"filename": "stem_col_red.png", "prompt": "Red tinted mushroom stem"},
    {"filename": "stem_col_pink.png", "prompt": "Pink hue mushroom stem"},
    {"filename": "stem_col_violet.png", "prompt": "Purple violet mushroom stem"},
    {"filename": "stem_col_brown.png", "prompt": "Tan brown mushroom stem"},
    {"filename": "stem_col_dark_brown.png", "prompt": "Dark chocolate brown mushroom stem"},
    {"filename": "stem_col_grey.png", "prompt": "Grey silver mushroom stem"},
    {"filename": "stem_col_black.png", "prompt": "Blackened mushroom stem"},
    {"filename": "stem_col_olive.png", "prompt": "Olive tint mushroom stem"},
    {"filename": "stem_col_bicolour.png", "prompt": "Gradient stem brown at base white at top"},
    {"filename": "stem_col_spotted.png", "prompt": "Brown spotted mushroom stem"},
    {"filename": "stem_col_streaked.png", "prompt": "Red streaked mushroom stem"},
    {"filename": "stem_col_bluing.png", "prompt": "Blue bruised staining stem"},
    {"filename": "stem_col_ochre.png", "prompt": "Ochre yellow-brown stem"},
    {"filename": "stem_col_translucent.png", "prompt": "Translucent watery glasslike stem"},

    # 14. Stem base shape (6 states)
    {"filename": "stem_base_equal.png", "prompt": "Straight cylindrical mushroom stem of uniform thickness"},
    {"filename": "stem_base_clavate.png", "prompt": "Club-shaped mushroom stem thickening toward base"},
    {"filename": "stem_base_bulbous.png", "prompt": "Mushroom stem with a swollen bulbous base"},
    {"filename": "stem_base_tapering.png", "prompt": "Mushroom stem tapering narrow toward base"},
    {"filename": "stem_base_rhizomorphs.png", "prompt": "Mushroom base with root-like white mycelial cords"},
    {"filename": "stem_base_rooting.png", "prompt": "Mushroom base with a long taproot extension"},

    # 15. Flesh colour (10 states)
    {"filename": "flesh_col_white.png", "prompt": "Cross section of mushroom showing solid white internal flesh"},
    {"filename": "flesh_col_cream.png", "prompt": "Cross section of mushroom showing cream internal flesh"},
    {"filename": "flesh_col_yellow.png", "prompt": "Cross section showing yellow internal flesh"},
    {"filename": "flesh_col_pink.png", "prompt": "Cross section showing light pink internal flesh"},
    {"filename": "flesh_col_brown.png", "prompt": "Cross section showing watery brown internal flesh"},
    {"filename": "flesh_col_grey.png", "prompt": "Cross section showing greyish internal flesh"},
    {"filename": "flesh_col_orange.png", "prompt": "Cross section showing bright orange flesh"},
    {"filename": "flesh_col_red.png", "prompt": "Cross section showing red flesh"},
    {"filename": "flesh_col_purple.png", "prompt": "Cross section showing purple violet flesh"},
    {"filename": "flesh_col_black.png", "prompt": "Cross section showing dark blackish flesh"},

    # 16. Bruising reaction (8 states)
    {"filename": "bruise_none.png", "prompt": "Mushroom flesh cross section showing no color change when cut"},
    {"filename": "bruise_blue.png", "prompt": "Mushroom flesh instantly bruising vivid blue when cut"},
    {"filename": "bruise_green.png", "prompt": "Mushroom flesh bruising olive green when damaged"},
    {"filename": "bruise_yellow.png", "prompt": "Mushroom flesh bruising chrome yellow when scraped"},
    {"filename": "bruise_red.png", "prompt": "Mushroom flesh bruising slowly reddish pink when cut"},
    {"filename": "bruise_brown.png", "prompt": "Mushroom flesh bruising dark brown when pressed"},
    {"filename": "bruise_black.png", "prompt": "Mushroom flesh bruising jet black when exposed to air"},
    {"filename": "bruise_purple.png", "prompt": "Mushroom flesh staining deep purple"},

    # 17. Odour (14 states)
    {"filename": "odour_none.png", "prompt": "Symbolic macro shot representing odorless neutral mushroom"},
    {"filename": "odour_fruity.png", "prompt": "Macro composition of mushroom next to fresh apricot slice"},
    {"filename": "odour_almond.png", "prompt": "Macro photo of mushroom next to fresh whole almonds"},
    {"filename": "odour_anise.png", "prompt": "Macro photo of mushroom next to star anise pod"},
    {"filename": "odour_foul.png", "prompt": "Macro photo of stinkhorn style fungus"},
    {"filename": "odour_fishy.png", "prompt": "Macro photo of old russula mushroom"},
    {"filename": "odour_phenolic.png", "prompt": "Macro representation of chemical ink-scented mushroom"},
    {"filename": "odour_mealy.png", "prompt": "Macro photo of mushroom next to fresh flour dust"},
    {"filename": "odour_radish.png", "prompt": "Macro photo of mushroom next to fresh cut radish"},
    {"filename": "odour_garlic.png", "prompt": "Macro photo of mushroom next to garlic clove"},
    {"filename": "odour_honey.png", "prompt": "Macro photo of mushroom with sweet glistening drop"},
    {"filename": "odour_mushroomy.png", "prompt": "Classic earthy forest floor mushroom photo"},
    {"filename": "odour_spicy.png", "prompt": "Macro photo of mushroom next to cedar wood flakes"},
    {"filename": "odour_bleach.png", "prompt": "Clean white mycena mushroom species"},

    # 18. Taste (6 states)
    {"filename": "taste_mild.png", "prompt": "Iconic edible mushroom cross section"},
    {"filename": "taste_bitter.png", "prompt": "Bitter bolete cross section with yellow tube mouth"},
    {"filename": "taste_sharp.png", "prompt": "Acred peppery Russula cap fragment"},
    {"filename": "taste_acrid.png", "prompt": "Hot acrid milkcap with white latex drop"},
    {"filename": "taste_sweet.png", "prompt": "Sweet wood mushroom sample"},
    {"filename": "taste_salty.png", "prompt": "Coastal mushroom specimen"},

    # 19. Spore print colour (16 states)
    {"filename": "spore_white.png", "prompt": "Macro circular white spore print on dark paper"},
    {"filename": "spore_cream.png", "prompt": "Macro circular cream colored spore print"},
    {"filename": "spore_yellow.png", "prompt": "Macro circular yellow spore print"},
    {"filename": "spore_olive.png", "prompt": "Macro circular olive spore print"},
    {"filename": "spore_ochre.png", "prompt": "Macro circular ochre yellow-brown spore print"},
    {"filename": "spore_brown.png", "prompt": "Macro circular rusty brown spore print"},
    {"filename": "spore_redbrown.png", "prompt": "Macro circular reddish brown spore print"},
    {"filename": "spore_purple.png", "prompt": "Macro circular purple-brown spore print"},
    {"filename": "spore_black.png", "prompt": "Macro circular jet black spore print"},
    {"filename": "spore_pink.png", "prompt": "Macro circular salmon pink spore print"},
    {"filename": "spore_cinnamon.png", "prompt": "Macro circular cinnamon spore print"},
    {"filename": "spore_chocolate.png", "prompt": "Macro circular chocolate brown spore print"},
    {"filename": "spore_grey.png", "prompt": "Macro circular greyish spore print"},
    {"filename": "spore_buff.png", "prompt": "Macro circular buff pale spore print"},
    {"filename": "spore_green.png", "prompt": "Macro circular rare pale green spore print"},
    {"filename": "spore_violet.png", "prompt": "Macro circular dark violet black spore print"},

    # 20. Spore shape (7 states)
    {"filename": "spore_ellipsoid.png", "prompt": "Microscopic rendering 3D view of an ellipsoid smooth mushroom spore"},
    {"filename": "spore_ovoid.png", "prompt": "Microscopic 3D rendering of an ovoid egg-shaped spore"},
    {"filename": "spore_oblong.png", "prompt": "Microscopic 3D rendering of an oblong elongated spore"},
    {"filename": "spore_amyloid.png", "prompt": "Microscopic 3D rendering of a spherical warty ornament spore"},
    {"filename": "spore_cylindrical.png", "prompt": "Microscopic 3D rendering of a long narrow cylindrical spore"},
    {"filename": "spore_allantoid.png", "prompt": "Microscopic 3D rendering of a curved sausage-shaped allantoid spore"},
    {"filename": "spore_irregular.png", "prompt": "Microscopic 3D rendering of a star-shaped angular irregular spore"},

    # 21. Substrate (12 states)
    {"filename": "subst_soil.png", "prompt": "Macro ground photo of mushroom growing directly out of dark soil"},
    {"filename": "subst_leaflitter.png", "prompt": "Mushroom growing from autumn fallen forest leaf litter"},
    {"filename": "subst_wood.png", "prompt": "Mushroom growing out of a decaying mossy tree branch"},
    {"filename": "subst_stump.png", "prompt": "Mushrooms growing on a cut hardwood tree stump"},
    {"filename": "subst_dung.png", "prompt": "Small mushroom growing on herbivore dung"},
    {"filename": "subst_sand.png", "prompt": "Mushroom growing in sandy coastal dune habitat"},
    {"filename": "subst_peat.png", "prompt": "Mushroom growing in wet peat bog moss"},
    {"filename": "subst_grassland.png", "prompt": "Mushroom growing in lush green meadow grass"},
    {"filename": "subst_moss.png", "prompt": "Mushroom growing in deep green forest moss"},
    {"filename": "subst_burnt.png", "prompt": "Mushroom growing on charred burnt wood ground"},
    {"filename": "subst_fungus.png", "prompt": "Parasitic mushroom growing directly on another larger fungus"},
    {"filename": "subst_bark.png", "prompt": "Mushroom growing vertically on living tree bark"},

    # 22. Tree association (11 states)
    {"filename": "tree_pine.png", "prompt": "Scots pine needle litter on forest floor"},
    {"filename": "tree_spruce.png", "prompt": "Norway spruce needle floor with cones"},
    {"filename": "tree_oak.png", "prompt": "Fallen oak leaves with acorns"},
    {"filename": "tree_beech.png", "prompt": "Smooth grey beech tree bark and beech nuts"},
    {"filename": "tree_birch.png", "prompt": "White birch tree bark background"},
    {"filename": "tree_alder.png", "prompt": "Wet forest floor with alder cones"},
    {"filename": "tree_willow.png", "prompt": "Damp soil near willow leaves"},
    {"filename": "tree_poplar.png", "prompt": "Poplar forest soil"},
    {"filename": "tree_mixed.png", "prompt": "Mixed deciduous and coniferous forest floor"},
    {"filename": "tree_fir.png", "prompt": "Silver fir needle litter"},
    {"filename": "tree_chestnut.png", "prompt": "Sweet chestnut burrs on ground"},

    # 23. Growth form (9 states)
    {"filename": "growth_cap_stem.png", "prompt": "Classic mushroom shape with distinct cap and central stem"},
    {"filename": "growth_bracket.png", "prompt": "Bracket shelf fungus growing horizontally on wood"},
    {"filename": "growth_cup.png", "prompt": "Cup-shaped peziza fungus"},
    {"filename": "growth_coral.png", "prompt": "Branched coral-like clavarioid fungus"},
    {"filename": "growth_club.png", "prompt": "Single unbranched club-shaped fungus"},
    {"filename": "growth_puffball.png", "prompt": "Round spherical puffball without stem"},
    {"filename": "growth_crust.png", "prompt": "Flat crust-like resupinate fungus spread on wood"},
    {"filename": "growth_jelly.png", "prompt": "Translucent rubbery jelly fungus"},
    {"filename": "growth_enclosed.png", "prompt": "Underground truffellike closed round fungus"}
]

for item in ITEMS_TO_GENERATE:
    file_path = os.path.join(output_dir, item["filename"])

    if os.path.exists(file_path):
        print(f"Bestaat al, overgeslagen: {item['filename']}")
        continue

    full_prompt = item["prompt"] + BASE_PROMPT_SUFFIX
    print(f"Genereren: {item['filename']}...")

    try:
        response = client.images.generate(
            model="gpt-image-2",
            prompt=full_prompt,
            n=1,
            size="1024x1024",
            quality="high"
        )

        image_base64 = response.data[0].b64_json
        if not image_base64:
            raise RuntimeError("De API gaf geen afbeeldingsdata terug.")

        with open(file_path, "wb") as f:
            f.write(base64.b64decode(image_base64))

        print(f"Opslaan gelukt: {file_path}")
        time.sleep(1)

    except Exception as e:
        print(f"Fout bij genereren van {item['filename']}: {e}")

print(f"Klaar. {len(ITEMS_TO_GENERATE)} assets verwerkt.")
