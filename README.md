# MMO2 Godot 4 migration tools

This repository contains Godot network codecs, a loopback session test, and Python converters for local source assets. The Godot project is an offline test harness. It contains synthetic packet fixtures and requires no game server.

## Run the checks

Use Godot 4.7.2 and Python 3.

```sh
for test in tests/*.gd; do
    godot --headless --path . --script "res://$test" || exit 1
done
python3 -m py_compile tools/*.py
```

The tests cover framing, character creation and selection, login, and initial world state. The session test binds a temporary port on 127.0.0.1.

## Convert local assets

```sh
python3 tools/convert_map.py /path/to/source/BT100 /path/to/project/assets/BT100
python3 tools/convert_movie_clip.py /path/to/source/CT001/CT001.json /path/to/project
```

The map converter verifies that CMDT and SMDT agree before copying textures. The MovieClip converter preserves frame regions and offsets from the atlas and creates a Godot scene. Original assets are kept outside this repository.
