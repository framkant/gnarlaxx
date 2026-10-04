#!/usr/bin/env python3
"""Prepare the shared game assets. Requires Pillow and ffmpeg, not a game engine."""

import argparse
import hashlib
import json
import re
import subprocess
import tempfile
import wave
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
GRAPHICS = ASSETS / "graphics"
AUDIO = ASSETS / "audio"
NEAREST = Image.Resampling.NEAREST
SOUNDS = {
    "player_shot": "laserRetro_000",
    "enemy_shot": "laserSmall_001",
    "hit": "impactMetal_000",
    "explosion": "explosionCrunch_000",
    "boss_explosion": "lowFrequency_explosion_000",
    "warning": "computerNoise_000",
    "menu_confirm": "forceField_000",
    "boss_ram": "thrusterFire_000",
}
VOICE = {
    "intro_warning": "Enemy Boss reported to prepare invasion.",
    "intro_go": "You must stopp him! Go!",
}


def transparent_color(image, color):
    image = image.convert("RGBA")
    image.putdata([(0, 0, 0, 0) if pixel[:3] == color else pixel
                   for pixel in image.getdata()])
    return image


def load_font():
    source = (ASSETS / "source/font8x8/font8x8_basic.h").read_text()
    rows = re.findall(r"\{\s*((?:0x[0-9A-Fa-f]{2},?\s*){8})\}", source)
    assert len(rows) == 128, "Expected the complete 128-character font"
    font = Image.new("RGBA", (128, 64))
    for code, row in enumerate(rows):
        for y, bits in enumerate(re.findall(r"0x[0-9A-Fa-f]{2}", row)):
            for x in range(8):
                if int(bits, 16) & (1 << x):
                    font.putpixel(((code % 16) * 8 + x, (code // 16) * 8 + y),
                                  (255, 255, 255, 255))
    return font


def text_image(font, text, scale=1, color=(255, 255, 255, 255)):
    result = Image.new("RGBA", (len(text) * 8, 8))
    for i, char in enumerate(text):
        code = ord(char)
        x, y = (code % 16) * 8, (code // 16) * 8
        mask = font.crop((x, y, x + 8, y + 8)).getchannel("A")
        result.paste(color, (i * 8, 0, i * 8 + 8, 8), mask)
    return result.resize((result.width * scale, result.height * scale), NEAREST)


def title_image(font, text, scale):
    lettering = text_image(font, text, scale)
    mask = lettering.getchannel("A")
    for y in range(lettering.height):
        color = (255, 237, 145) if y < lettering.height // 2 else (255, 110, 127)
        for x in range(lettering.width):
            if mask.getpixel((x, y)):
                lettering.putpixel((x, y), color + (255,))
    result = Image.new("RGBA", (lettering.width + 8, lettering.height + 8))
    outline = Image.new("L", result.size)
    outline.paste(mask, (4, 4))
    outline = outline.filter(ImageFilter.MaxFilter(5))
    result.paste((30, 39, 82, 255), (0, 0), outline)
    result.alpha_composite(lettering, (4, 2))
    return result


def make_sprites(font):
    source = Image.open(ASSETS / "source/grafxkid/arcade_space_shooter.png")
    sheet = transparent_color(source, (140, 133, 90))
    sprites = {}

    def crop(name, x, y, width=16, height=16, scale=2):
        assert x + width <= sheet.width and y + height <= sheet.height
        sprite = sheet.crop((x, y, x + width, y + height))
        sprites[name] = sprite.resize((width * scale, height * scale), NEAREST)
        return sprites[name]

    for name, x in [("player_left", 32), ("player_idle", 48), ("player_right", 64)]:
        crop(name, x, 48)
    crop("player_flame_0", 48, 64, 16, 8)
    crop("player_flame_1", 48, 80, 16, 8)
    for frame, x in enumerate([96, 112]):
        crop("pawn_" + str(frame), x, 64)
    for frame, x in enumerate([96, 112, 128]):
        crop("drone_" + str(frame), x, 80)
    crop("player_bullet", 80, 128, 8, 16, 1)
    crop("enemy_bullet", 372, 132, 8, 8, 1)
    crop("enemy_bullet_hot", 404, 132, 8, 8, 1)
    for frame in range(5):
        crop("explosion_" + str(frame), 272 + frame * 16, 128)
    crop("spark", 272, 160)
    crop("life", 288, 48, 16, 16, 1)

    # Keep the boss visibly related to the drone. The gun pods and open core
    # are separate drawables/hit targets; the game supplies their positions.
    hull = crop("boss_body", 144, 80, scale=6)
    draw = ImageDraw.Draw(hull)
    draw.rectangle((31, 25, 64, 62), fill="#25452f", outline="#86c949", width=2)
    draw.rectangle((36, 30, 59, 56), fill="#568d38", outline="#bee976", width=2)
    draw.line((47, 32, 47, 54), fill="#25452f", width=2)
    pod = sheet.crop((144, 48, 160, 64)).resize((32, 32), NEAREST)
    gun = Image.new("RGBA", (32, 48))
    gun.alpha_composite(pod)
    draw = ImageDraw.Draw(gun)
    draw.rectangle((10, 25, 21, 44), fill="#945738", outline="#ffcb58", width=2)
    draw.rectangle((12, 39, 19, 47), fill="#491f34")
    sprites["boss_gun_left"] = gun
    sprites["boss_gun_right"] = gun.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    core = sheet.crop((98, 82, 110, 94)).resize((24, 24), NEAREST)
    exposed = Image.new("RGBA", (32, 40), "#351b38")
    exposed.alpha_composite(core, (4, 1))
    draw = ImageDraw.Draw(exposed)
    draw.rectangle((10, 25, 21, 38), fill="#e94a75", outline="#ffcb58", width=2)
    draw.rectangle((12, 34, 19, 39), fill="#491f34")
    sprites["boss_core"] = exposed

    # Four 32 px tiles per layer. The foreground has transparent space so the
    # two layers can scroll independently; the far layer carries the dark fill.
    for layer, x in [("far", 272), ("near", 352)]:
        background = source.crop((x, 208, x + 64, 272)).convert("RGBA")
        if layer == "near":
            background = transparent_color(background, background.getpixel((0, 0))[:3])
        else:
            background.putdata([(r // 3, g // 3, max(10, b // 3), a)
                                for r, g, b, a in background.getdata()])
        for tile in range(4):
            tx, ty = (tile % 2) * 32, (tile // 2) * 32
            sprites["stars_" + layer + "_" + str(tile)] = background.crop(
                (tx, ty, tx + 32, ty + 32))

    sprites["title"] = title_image(font, "GNARLAXX", 4)
    sprites["level_cleared"] = title_image(font, "LEVEL CLEARED", 2)
    return sprites


def pack_atlas(sprites):
    atlas = Image.new("RGBA", (512, 512))
    rects = {}
    x, y, shelf_height = 2, 2, 0
    for name, sprite in sprites.items():
        if x + sprite.width + 2 > atlas.width:
            x, y, shelf_height = 2, y + shelf_height + 4, 0
        assert y + sprite.height + 2 <= atlas.height, "Atlas overflow"
        assert sprite.getbbox(), "Empty sprite: " + name
        atlas.alpha_composite(sprite, (x, y))
        rects[name] = [x, y, sprite.width, sprite.height]
        x += sprite.width + 4
        shelf_height = max(shelf_height, sprite.height)
    atlas.save(GRAPHICS / "sprites.png")
    return rects


def make_preview(sprites, font):
    # This is a static asset composition, not a screenshot of an implemented game.
    scene = Image.new("RGBA", (400, 500))
    for layer, offset in [("far", 0), ("near", 19)]:
        for row in range(-1, 17):
            for col in range(-1, 14):
                name = "stars_{}_{}".format(layer, (row % 2) * 2 + col % 2)
                scene.alpha_composite(sprites[name], (col * 32 + offset, row * 32 + offset))
    scene.alpha_composite(text_image(font, "SCORE 012500"), (16, 16))
    for x in [326, 346, 366]:
        scene.alpha_composite(sprites["life"], (x, 12))
    scene.alpha_composite(sprites["boss_body"], (152, 62))
    scene.alpha_composite(sprites["boss_gun_left"], (125, 112))
    scene.alpha_composite(sprites["boss_gun_right"], (243, 112))
    scene.alpha_composite(sprites["boss_core"], (184, 88))
    for i in range(5):
        scene.alpha_composite(sprites["pawn_" + str(i % 2)], (55 + i * 65, 222 + abs(2-i)*12))
    scene.alpha_composite(sprites["drone_0"], (79, 321))
    scene.alpha_composite(sprites["explosion_2"], (280, 306))
    for x, y in [(155, 200), (225, 212), (242, 283), (318, 352), (101, 294)]:
        scene.alpha_composite(sprites["enemy_bullet"], (x, y))
    for y in [341, 377]:
        scene.alpha_composite(sprites["player_bullet"], (196, y))
    scene.alpha_composite(sprites["player_idle"], (184, 419))
    scene.alpha_composite(sprites["player_flame_0"], (184, 451))
    scene.alpha_composite(text_image(font, "ASSET COMPOSITION - NOT GAMEPLAY", color=(133, 145, 175, 255)), (76, 481))
    scene.resize((800, 1000), NEAREST).save(ASSETS / "preview.png")

    contact = Image.new("RGBA", (960, 460), "#0b1020")
    contact.alpha_composite(sprites["title"], (24, 18))
    contact.alpha_composite(text_image(font, "SHARED SPRITES / BOSS BODY SHOWN AT HALF SIZE"), (24, 66))
    shown = [name for name in sprites if not name.startswith("stars_")
             and name not in ["title", "level_cleared"]]
    for i, name in enumerate(shown):
        x, y = 24 + (i % 6) * 154, 96 + (i // 6) * 86
        sprite = sprites[name]
        if sprite.height > 60:
            sprite = sprite.resize((sprite.width // 2, sprite.height // 2), NEAREST)
        contact.alpha_composite(sprite, (x, y))
        contact.alpha_composite(text_image(font, name), (x, y + 61))
    contact.save(ASSETS / "contact-sheet.png")


def convert_wav(source, destination):
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(source),
                    "-ac", "1", "-ar", "44100", "-c:a", "pcm_s16le",
                    "-map_metadata", "-1", "-fflags", "+bitexact", str(destination)], check=True)


def prepare_audio(espeak):
    for name, source in SOUNDS.items():
        convert_wav(ASSETS / ("source/kenney/" + source + ".ogg"), AUDIO / (name + ".wav"))
    if espeak:
        with tempfile.TemporaryDirectory() as directory:
            for name, text in VOICE.items():
                wav = Path(directory) / (name + ".wav")
                subprocess.run([espeak, "-v", "en-us", "-s", "145", "-p", "32",
                                "-w", str(wav), text], check=True)
                convert_wav(wav, AUDIO / (name + ".wav"))
    metadata = {}
    for name in list(SOUNDS) + list(VOICE):
        path = AUDIO / (name + ".wav")
        with wave.open(str(path), "rb") as wav:
            assert (wav.getnchannels(), wav.getsampwidth(), wav.getframerate()) == (1, 2, 44100)
            assert wav.getnframes() > 0
            metadata[name] = {"file": "audio/" + path.name,
                              "frames": wav.getnframes(), "sample_rate": 44100,
                              "channels": 1, "format": "s16le"}
    metadata["music"] = {"file": "audio/music.mp3", "loop": True,
                         "note": "Original MP3; honor encoder delay/padding when decoding."}
    return metadata


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--espeak", help="Optional eSpeak NG executable to regenerate checked-in voice WAVs")
    args = parser.parse_args()
    font = load_font()
    sprites = make_sprites(font)
    rectangles = pack_atlas(sprites)
    font.save(GRAPHICS / "font.png")
    sprites["title"].save(GRAPHICS / "title.png")
    sprites["level_cleared"].save(GRAPHICS / "level-cleared.png")
    make_preview(sprites, font)
    audio = prepare_audio(args.espeak)
    manifest = {
        "version": 1,
        "atlas": {"file": "graphics/sprites.png", "size": [512, 512],
                  "format": "RGBA8", "alpha": "straight", "filter": "nearest",
                  "coordinates": "top-left origin, [x, y, width, height] in pixels"},
        "sprites": rectangles,
        "font": {"file": "graphics/font.png", "size": [128, 64], "cell": [8, 8],
                 "columns": 16, "first_codepoint": 0, "count": 128, "advance": 8},
        "boss": {"body_size": [96, 96], "core_offset": [32, 26],
                 "left_gun_offset": [-27, 50], "right_gun_offset": [91, 50],
                 "note": "Offsets from body top-left. Retract pods toward body; show core only in final phase."},
        "background": {"tile_size": 32, "pattern": [[0, 1], [2, 3]],
                       "layers": ["far", "near"], "note": "Each layer repeats a 2x2 tile pattern."},
        "audio": audio,
        "voice_text": VOICE,
    }
    (ASSETS / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    outputs = sorted(GRAPHICS.glob("*.png")) + sorted(AUDIO.glob("*"))
    checksums = {str(path.relative_to(ASSETS)): hashlib.sha256(path.read_bytes()).hexdigest()
                 for path in outputs}
    (ASSETS / "checksums.json").write_text(json.dumps(checksums, indent=2) + "\n")
    print("Prepared {} sprites, a bitmap font, music, {} effects, and {} voice lines.".format(
        len(sprites), len(SOUNDS), len(VOICE)))


if __name__ == "__main__":
    main()
