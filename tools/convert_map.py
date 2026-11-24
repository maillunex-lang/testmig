"""Convert a verified legacy map directory into a Godot asset directory."""
import argparse
import json
import shutil
import struct
from pathlib import Path

from read_cmdt import read_cmdt


def convert(source: Path, output: Path) -> None:
    name = source.name
    data = read_cmdt(source / f"{name}.cmdt")
    grid_file = source / f"{name}.smdt"
    grid = grid_file.read_bytes()
    width, height = struct.unpack_from(">HH", grid)
    rows = data.pop("paths")
    if (width, height) != (data["tileX"], data["tileY"]):
        raise ValueError("SMDT and CMDT grid dimensions disagree")
    if len(rows) != height or any(len(row) != width for row in rows):
        raise ValueError("Invalid CMDT grid shape")
    if bytes(cell for row in rows for cell in row) != grid[4:]:
        raise ValueError("SMDT and CMDT grid values disagree")
    tile_width = data["mapPieceWidth"]
    tile_height = data["mapPieceHeight"]
    columns, remainder_x = divmod(data["width"], tile_width)
    lines, remainder_y = divmod(data["height"], tile_height)
    if remainder_x or remainder_y:
        raise ValueError("Expected a whole number of image fragments")
    tiles = []
    for row in range(lines):
        for column in range(columns):
            file = f"{name}_{row}_{column}.jpg"
            if not (source / file).is_file():
                raise FileNotFoundError(source / file)
            tiles.append({"file": file, "x": column * tile_width, "y": row * tile_height})
    output.mkdir(parents=True, exist_ok=True)
    for filename in [grid_file.name, *(tile["file"] for tile in tiles)]:
        if output.resolve() != source.resolve():
            shutil.copyfile(source / filename, output / filename)
    data["tiles"] = tiles
    data["grid"] = grid_file.name
    (output / "map.json").write_text(json.dumps(data, indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    options = parser.parse_args()
    convert(options.source, options.output)
