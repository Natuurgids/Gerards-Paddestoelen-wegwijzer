#!/usr/bin/env python3
"""Report explicit threat-status values exposed by the live NSR DwC archive.

Diagnostic only: this does not infer legal protection or mutate application data.
"""
from __future__ import annotations

import csv
import io
import tempfile
import urllib.request
import xml.etree.ElementTree as ET
import zipfile
from collections import Counter
from pathlib import Path

URL = "https://api.biodiversitydata.nl/v2/taxon/dwca/getDataSet/nsr"


def _local(term: str) -> str:
    return term.rsplit("/", 1)[-1].rsplit("#", 1)[-1]


def _char(value: str | None, default: str) -> str:
    if not value:
        return default
    return bytes(value, "utf-8").decode("unicode_escape")


def _spec(element):
    location = next((c.text for c in element.iter() if c.tag.endswith("location")), None)
    if not location:
        raise ValueError("Darwin Core table has no location")
    fields = {}
    id_index = None
    for child in element:
        if child.tag.endswith("field"):
            fields[int(child.attrib["index"])] = _local(child.attrib.get("term", ""))
        elif child.tag.endswith("id") or child.tag.endswith("coreid"):
            id_index = int(child.attrib["index"])
    return (
        location,
        _char(element.attrib.get("fieldsTerminatedBy"), "\t"),
        _char(element.attrib.get("fieldsEnclosedBy"), '"'),
        int(element.attrib.get("ignoreHeaderLines", "0")),
        fields,
        id_index,
    )


def _rows(zf, spec):
    location, delimiter, quote, skip, fields, id_index = spec
    reader = csv.reader(
        io.StringIO(zf.read(location).decode("utf-8-sig", errors="replace")),
        delimiter=delimiter,
        quotechar=quote or None,
    )
    for _ in range(skip):
        next(reader, None)
    for values in reader:
        row = {name: values[index].strip() if index < len(values) else "" for index, name in fields.items()}
        if id_index is not None and id_index < len(values):
            row["_id"] = values[id_index].strip()
        yield row


def main() -> None:
    temp = tempfile.NamedTemporaryFile(suffix=".zip", delete=False)
    temp.close()
    path = Path(temp.name)
    try:
        request = urllib.request.Request(URL, headers={"User-Agent": "Gerards-Paddestoelen-Wegwijzer/1.0"})
        with urllib.request.urlopen(request, timeout=120) as response, path.open("wb") as out:
            out.write(response.read())
        with zipfile.ZipFile(path) as zf:
            meta = next(name for name in zf.namelist() if name.lower().endswith("meta.xml"))
            root = ET.fromstring(zf.read(meta))
            all_fields = Counter()
            values = Counter()
            fungi_values = Counter()
            core_taxa = {}
            for table in root:
                if not (table.tag.endswith("core") or table.tag.endswith("extension")):
                    continue
                spec = _spec(table)
                for field in spec[4].values():
                    if "status" in field.casefold() or "threat" in field.casefold() or "protect" in field.casefold():
                        all_fields[field] += 1
                rows = list(_rows(zf, spec))
                if table.tag.endswith("core"):
                    for row in rows:
                        key = row.get("_id", "") or row.get("taxonID", "")
                        if key:
                            core_taxa[key] = row
                for row in rows:
                    status = (row.get("threatStatus") or "").strip()
                    if not status:
                        continue
                    values[status] += 1
                    taxon = row if table.tag.endswith("core") else core_taxa.get(row.get("_id", ""), {})
                    if str(taxon.get("kingdom", "")).casefold() == "fungi":
                        fungi_values[status] += 1
            print(f"NSR candidate status fields: {sorted(all_fields)}")
            print(f"NSR threatStatus values: {dict(values)}")
            print(f"NSR Fungi threatStatus values: {dict(fungi_values)}")
    finally:
        path.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
