"""Convert a single Egret MovieClip atlas into a Godot scene."""
import argparse
import json
import shutil
import struct
from pathlib import Path


def convert(source: Path, project: Path) -> None:
    atlas = json.loads(source.read_text(encoding="utf-8-sig"))
    name = source.stem
    clip = atlas["mc"][name]
    frames = clip["frames"]
    if not frames or clip["frameRate"] <= 0:
        raise ValueError("Expected animation frames and a positive frame rate")
    image = source.with_suffix(".png")
    with image.open("rb") as png:
        header = png.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise ValueError(f"Invalid PNG header: {image}")
    width, height = struct.unpack(">II", header[16:24])
    rectangles = [atlas["res"][frame["res"]] for frame in frames]
    for rect in rectangles:
        x, y, w, h = (rect[key] for key in ("x", "y", "w", "h"))
        if x < 0 or y < 0 or w <= 0 or h <= 0 or x + w > width or y + h > height:
            raise ValueError(f"Frame outside atlas: {rect}")
    offsets = [(frame["x"], frame["y"]) for frame in frames]
    left = min(x for x, _ in offsets)
    top = min(y for _, y in offsets)
    right = max(x + rect["w"] for (x, _), rect in zip(offsets, rectangles))
    bottom = max(y + rect["h"] for (_, y), rect in zip(offsets, rectangles))
    relative = Path("characters") / name
    destination = project / relative
    destination.mkdir(parents=True, exist_ok=False)
    shutil.copyfile(image, destination / image.name)
    lines = [
        "[gd_scene format=3]",
        f'[ext_resource type="Texture2D" path="res://{relative.as_posix()}/{image.name}" id="atlas"]',
    ]
    frame_lines = []
    for index, (frame, rect, (x, y)) in enumerate(zip(frames, rectangles, offsets)):
        w, h = rect["w"], rect["h"]
        duration = frame.get("duration", 1)
        lines.extend([
            f'[sub_resource type="AtlasTexture" id="frame_{index}"]',
            'atlas = ExtResource("atlas")',
            f'region = Rect2({rect["x"]}, {rect["y"]}, {w}, {h})',
            f'margin = Rect2({x-left}, {y-top}, {right-left-w}, {bottom-top-h})',
            'filter_clip = true',
        ])
        frame_lines.append(f'{{"duration": {float(duration)}, "texture": SubResource("frame_{index}")}}')
    lines.extend([
        '[sub_resource type="SpriteFrames" id="frames"]',
        f'animations = [{{"frames": [{", ".join(frame_lines)}], "loop": true, '
        f'"name": &"{name}", "speed": {float(clip["frameRate"])}}}]',
        f'[node name="{name}" type="Node2D"]',
        '[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]',
        f'position = Vector2({left}, {top})',
        'centered = false',
        'sprite_frames = SubResource("frames")',
        f'animation = &"{name}"',
        f'autoplay = "{name}"',
    ])
    (destination / f"{name}.tscn").write_text("\n\n".join(lines) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("project", type=Path)
    arguments = parser.parse_args()
    convert(arguments.source, arguments.project)
