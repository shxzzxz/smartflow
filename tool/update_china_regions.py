"""Refresh the offline province/city/district snapshot without runtime dependencies."""

import argparse
import hashlib
import json
from pathlib import Path
from urllib.request import urlopen


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", default="9.0.0")
    args = parser.parse_args()
    source = (
        f"https://unpkg.com/@province-city-china/level@{args.version}/level.json"
    )
    with urlopen(source, timeout=45) as response:
        raw = response.read()

    def normalize(nodes, depth):
        result = []
        for node in nodes:
            item = {"code": str(node["code"]), "name": node["name"]}
            if depth > 1 and node.get("children"):
                item["children"] = normalize(node["children"], depth - 1)
            result.append(item)
        return result

    provinces = normalize(json.loads(raw), 3)
    if len(provinces) < 30:
        raise ValueError("The source does not contain a complete province list.")
    cities = [city for province in provinces for city in province.get("children", [])]
    districts = [district for city in cities for district in city.get("children", [])]
    if len(cities) < 300 or len(districts) < 2000:
        raise ValueError("The source does not contain complete city/district levels.")
    snapshot = {
        "source": source,
        "version": args.version,
        "sourceSha256": hashlib.sha256(raw).hexdigest(),
        "provinces": provinces,
    }
    destination = Path(__file__).resolve().parents[1] / "assets/regions/china_regions.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(
        json.dumps(snapshot, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Saved {len(provinces)} provinces, {len(cities)} cities, {len(districts)} districts.")


if __name__ == "__main__":
    main()
