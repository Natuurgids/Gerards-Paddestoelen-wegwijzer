import base64
import os
import time

from openai import OpenAI

client = OpenAI(api_key=os.environ.get("OPENAI_API_KEY"))

# Bestanden komen rechtstreeks in de bestaande assets-map terecht.
output_dir = "assets"
os.makedirs(output_dir, exist_ok=True)

ITEMS_TO_GENERATE = [
    # 1. Cap shape (Hoedvormen)
    {"filename": "cap_bell_shaped.png", "prompt": "A clean studio macro photograph of a single bell-shaped mushroom cap (klokvormig)."},
    {"filename": "cap_conical.png", "prompt": "A clean studio macro photograph of a single conical mushroom cap with a pointed top (kegelvormig)."},
    {"filename": "cap_convex.png", "prompt": "A clean studio macro photograph of a single convex dome-shaped mushroom cap (bolvormig)."},
    {"filename": "cap_flat.png", "prompt": "A clean studio macro photograph of a single planar flat mushroom cap (vlak)."},
    {"filename": "cap_depressed.png", "prompt": "A clean studio macro photograph of a single depressed mushroom cap with a sunken center (ingedrukt)."},
    {"filename": "cap_umbonate.png", "prompt": "A clean studio macro photograph of a single umbonate mushroom cap with a central bump (met bult)."},
    {"filename": "cap_funnel.png", "prompt": "A clean studio macro photograph of a single funnel-shaped mushroom cap (trechtervormig)."},

    # 2. Gill attachment (Lamellenaanhechting)
    {"filename": "gill_free.png", "prompt": "A macro photograph of the underside of a mushroom showing free gills not attached to the stem."},
    {"filename": "gill_adnate.png", "prompt": "A macro photograph of the underside of a mushroom showing adnate gills broadly attached to the stem."},
    {"filename": "gill_decurrent.png", "prompt": "A macro photograph of the underside of a mushroom showing decurrent gills running down the stem."},

    # 3. Stem ring (Ring)
    {"filename": "stem_ring_present.png", "prompt": "A macro photograph of a mushroom stem with a clear skirt-like ring (annulus)."},
    {"filename": "stem_ring_absent.png", "prompt": "A macro photograph of a smooth mushroom stem without any ring."},
]

BASE_PROMPT_SUFFIX = (
    " Isolated on a seamless solid white background, high-detail scientific reference photo, "
    "soft even studio lighting, crisp focus, centered subject, no text, no labels, no border, "
    "no background objects, minimal background shadow."
)

for item in ITEMS_TO_GENERATE:
    filename = item["filename"]
    file_path = os.path.join(output_dir, filename)

    # Exacte bestandsnamen worden door deze lijst bepaald.
    if os.path.exists(file_path):
        print(f"Bestaat al, overgeslagen: {filename}")
        continue

    full_prompt = item["prompt"] + BASE_PROMPT_SUFFIX
    print(f"Genereren: {filename}...")

    try:
        response = client.images.generate(
            model="gpt-image-2",
            prompt=full_prompt,
            n=1,
            size="1024x1024",
            quality="high",
        )

        image_base64 = response.data[0].b64_json
        if not image_base64:
            raise RuntimeError("De API gaf geen afbeeldingsdata terug.")

        with open(file_path, "wb") as f:
            f.write(base64.b64decode(image_base64))

        print(f"Opslaan gelukt: {file_path}")
        time.sleep(1)

    except Exception as e:
        print(f"Fout bij genereren van {filename}: {e}")

print("Klaar met het verwerken van de lijst!")
