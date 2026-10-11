# Photographic wheel fitting and colour observations

The main observation wheel retains 23 groups and 341 choices. The number of segments follows
the actual choices in the current group, so 3, 9 or 5 choices produce 3, 9 or 5
segments. Every value is visible and selectable. A larger centre preview keeps
the selected photo readable when a group has many narrow sectors. Each complete
photo is contained in a radial image panel inside its wedge. The panel turns with
the wheel and becomes upright at the selected top position. The outer annulus is
wider, its text label remains in the confirmation control, and gold pointers no
longer cover the subject. Unselected photographs are not tinted green.

Colour groups use six generated, transparent, neutral photographic textures:
detached cap, gills, stem, flesh cross-section, spore deposit, and an irregular
fibrous bruise patch. These are photographic feature illustrations, not verified
photographs of named species. Flutter colours the observed structure using an
explicit palette while retaining its texture and transparency. Bruising colours
only a local patch of the white cross-section. No change leaves the cross-section
white; red-then-black shows both stages. Unknown and not-applicable observations
use explicit symbols instead of an unrelated coloured example.

The 120 observation styles cover cap, gill, stem, flesh, spore-print and bruising
colour. Palette metadata lives with each observation in identification_traits.json;
tool/build_colour_observation_mapping.py compiles the runtime map and its readable
JSON companion. The --check workflow guard rejects stale generated mappings.
Original option identifiers, relations and determination logic remain unchanged.

The textures were generated using the built-in image-generation tool. Their full
prompts and hashes are recorded alongside them. They are bundled under
determination_wheel/assets/colour_photographs/ and declared in both Flutter asset
bundles. Main-app widgets render the palette; the standalone legacy wheel's
existing photographic choices and routing remain intact.

Tests check the selected full-photo rectangle against the inner and outer ring
bounds at five viewport/text sizes, preserve rotation and confirmation behaviour,
and verify rendered green pixels against white unbruised pixels. Actual Flutter
screens are also captured for green bruising, purple gills and a blue stem.
