#!/usr/bin/env python3
"""Render four deterministic physics review sheets from a JSON spec."""

from __future__ import annotations

import argparse
import json
import os
import re
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont, ImageOps


WIDTH, HEIGHT = 1240, 1754
MARGIN = 64
FILES = [
    "page-1-paper-map.png",
    "page-2-models-and-formulas.png",
    "page-3-methods-and-solutions.png",
    "page-4-errors-and-transfer.png",
]
COLORS = {
    "bg": "#F4F7FA",
    "ink": "#17263A",
    "muted": "#65758B",
    "navy": "#173B63",
    "blue": "#2E6EA6",
    "pale_blue": "#EAF2F8",
    "amber": "#F2A93B",
    "pale_amber": "#FFF4DF",
    "white": "#FFFFFF",
    "line": "#D8E1EA",
    "danger": "#B64B4B",
}
SCRIPT_CHARS = str.maketrans(
    {
        "₀": "_0", "₁": "_1", "₂": "_2", "₃": "_3", "₄": "_4",
        "₅": "_5", "₆": "_6", "₇": "_7", "₈": "_8", "₉": "_9",
        "ₐ": "_a", "ₑ": "_e", "ₒ": "_o", "ₓ": "_x", "ₕ": "_h",
        "ₖ": "_k", "ₗ": "_l", "ₘ": "_m", "ₙ": "_n", "ₚ": "_p",
        "ₛ": "_s", "ₜ": "_t", "ᵢ": "_i", "ⱼ": "_j", "ᵣ": "_r",
        "ᵤ": "_u", "ᵥ": "_v", "ᵦ": "_b", "ᵧ": "_y",
    }
)
SUPERSCRIPT_CHARS = {
    "⁰": "0", "¹": "1", "²": "2", "³": "3", "⁴": "4",
    "⁵": "5", "⁶": "6", "⁷": "7", "⁸": "8", "⁹": "9",
    "⁺": "+", "⁻": "-", "⁼": "=", "⁽": "(", "⁾": ")",
}


def font_path(bold: bool = False) -> str:
    candidates = [
        "/System/Library/Fonts/STHeiti Medium.ttc" if bold else "/System/Library/Fonts/STHeiti Light.ttc",
        "/System/Library/Fonts/PingFang.ttc",
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc" if bold else "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "C:/Windows/Fonts/msyhbd.ttc" if bold else "C:/Windows/Fonts/msyh.ttc",
    ]
    for candidate in candidates:
        if os.path.exists(candidate):
            return candidate
    raise RuntimeError("No usable CJK font found.")


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(font_path(bold), size=size)


def safe_text(text: Any) -> str:
    """Replace script glyphs commonly absent from CJK fonts with ASCII notation."""
    value = str(text)
    value = re.sub(
        r"[⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻⁼⁽⁾]+",
        lambda match: "^" + "".join(SUPERSCRIPT_CHARS[ch] for ch in match.group()),
        value,
    )
    return value.translate(SCRIPT_CHARS)


def tokens(text: str) -> list[str]:
    return re.findall(r"[\u3400-\u9fff]|[^\u3400-\u9fff\s]+|\s+", safe_text(text))


def wrap(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.FreeTypeFont, max_width: int) -> list[str]:
    lines: list[str] = []
    current = ""
    for token in tokens(text):
        candidate = current + token
        if current and draw.textlength(candidate, font=fnt) > max_width:
            lines.append(current.rstrip())
            current = token.lstrip()
        else:
            current = candidate
    if current.strip() or not lines:
        lines.append(current.rstrip())
    return lines


def text_block(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int],
    text: str,
    fnt: ImageFont.FreeTypeFont,
    color: str,
    max_width: int,
    line_gap: int = 8,
    prefix: str = "",
) -> int:
    x, y = xy
    line_height = fnt.size + line_gap
    lines = wrap(draw, prefix + str(text), fnt, max_width)
    for line in lines:
        draw.text((x, y), line, font=fnt, fill=color)
        y += line_height
    return y


def validate(spec: dict[str, Any]) -> None:
    if not str(spec.get("paper_title", "")).strip():
        raise ValueError("paper_title is required.")
    if spec.get("input_mode") not in {"blank", "answered", "marked"}:
        raise ValueError("input_mode must be blank, answered, or marked.")
    pages = spec.get("pages")
    if not isinstance(pages, list) or len(pages) != 4:
        raise ValueError("Spec must contain exactly four pages.")
    for page_index, page in enumerate(pages, 1):
        sections = page.get("sections")
        if not isinstance(sections, list) or not 3 <= len(sections) <= 6:
            raise ValueError(f"Page {page_index} must contain 3–6 sections.")
        for section_index, section in enumerate(sections, 1):
            if not section.get("heading") or not isinstance(section.get("items"), list):
                raise ValueError(f"Page {page_index}, section {section_index} needs heading and items.")
            path = str(section.get("image_path", "")).strip()
            if path and not Path(path).is_file():
                raise ValueError(f"Missing image_path: {path}")


def draw_header(draw: ImageDraw.ImageDraw, spec: dict[str, Any], page: dict[str, Any], page_no: int) -> int:
    draw.rounded_rectangle((MARGIN, 52, WIDTH - MARGIN, 238), radius=30, fill=COLORS["navy"])
    draw.text((MARGIN + 34, 74), str(page.get("title", "")), font=font(42, True), fill=COLORS["white"])
    draw.text((MARGIN + 36, 134), str(page.get("subtitle", "")), font=font(24), fill="#D7E7F5")
    scope = str(spec.get("scope", "")).strip()
    source = str(spec["paper_title"]) + (f" · {scope}" if scope else "")
    draw.text((MARGIN + 36, 193), source, font=font(19), fill="#AEC8DF")
    draw.rounded_rectangle((WIDTH - MARGIN - 104, 78, WIDTH - MARGIN - 26, 156), radius=20, fill=COLORS["amber"])
    draw.text((WIDTH - MARGIN - 74, 92), f"{page_no:02d}", font=font(34, True), fill=COLORS["navy"], anchor="ma")
    return 262


def draw_metrics(draw: ImageDraw.ImageDraw, metrics: list[dict[str, Any]], top: int) -> int:
    if not metrics:
        return top
    count = min(len(metrics), 4)
    gap = 16
    width = (WIDTH - 2 * MARGIN - gap * (count - 1)) // count
    for index, metric in enumerate(metrics[:4]):
        x = MARGIN + index * (width + gap)
        draw.rounded_rectangle((x, top, x + width, top + 116), radius=20, fill=COLORS["white"], outline=COLORS["line"], width=2)
        draw.text((x + 20, top + 18), str(metric.get("label", "")), font=font(19), fill=COLORS["muted"])
        value = safe_text(metric.get("value", ""))
        value_font = font(28 if len(value) <= 9 else 23, True)
        draw.text((x + 20, top + 55), value, font=value_font, fill=COLORS["blue"])
    return top + 140


def draw_card(
    canvas: Image.Image,
    draw: ImageDraw.ImageDraw,
    box: tuple[int, int, int, int],
    section: dict[str, Any],
) -> None:
    x1, y1, x2, y2 = box
    draw.rounded_rectangle(box, radius=24, fill=COLORS["white"], outline=COLORS["line"], width=2)
    draw.rounded_rectangle((x1, y1, x1 + 14, y2), radius=7, fill=COLORS["blue"])
    tag = str(section.get("tag", "")).strip()
    heading_x = x1 + 34
    if tag:
        tag_width = int(draw.textlength(tag, font=font(17, True))) + 28
        draw.rounded_rectangle((heading_x, y1 + 22, heading_x + tag_width, y1 + 58), radius=12, fill=COLORS["pale_amber"])
        draw.text((heading_x + 14, y1 + 29), tag, font=font(17, True), fill=COLORS["danger"])
        heading_x += tag_width + 16
    draw.text((heading_x, y1 + 18), str(section["heading"]), font=font(27, True), fill=COLORS["ink"])
    refs = str(section.get("question_refs", "")).strip()
    if refs:
        refs_width = int(draw.textlength(refs, font=font(17))) + 26
        draw.rounded_rectangle((x2 - refs_width - 22, y1 + 22, x2 - 22, y1 + 56), radius=10, fill=COLORS["pale_blue"])
        draw.text((x2 - refs_width - 9, y1 + 29), refs, font=font(17), fill=COLORS["blue"])

    image_path = str(section.get("image_path", "")).strip()
    content_x = x1 + 36
    content_y = y1 + 76
    content_right = x2 - 30
    if image_path:
        image_width = min(330, int((x2 - x1) * 0.31))
        image_box = (x2 - image_width - 28, content_y, x2 - 28, y2 - 26)
        with Image.open(image_path) as source:
            picture = ImageOps.contain(source.convert("RGB"), (image_box[2] - image_box[0], image_box[3] - image_box[1]))
        px = image_box[0] + (image_box[2] - image_box[0] - picture.width) // 2
        py = image_box[1] + (image_box[3] - image_box[1] - picture.height) // 2
        canvas.paste(picture, (px, py))
        draw.rounded_rectangle(image_box, radius=14, outline=COLORS["line"], width=2)
        content_right = image_box[0] - 22

    body_width = content_right - content_x
    body_size = 23
    formula_size = 27
    note_size = 20
    for trial in range(6):
        cursor = content_y
        body_font = font(body_size - trial)
        for item in section.get("items", []):
            cursor += len(wrap(draw, "• " + str(item), body_font, body_width)) * (body_font.size + 7) + 4
        formula_text = str(section.get("formula", "")).strip()
        if formula_text:
            cursor += len(wrap(draw, formula_text, font(formula_size - trial, True), body_width - 24)) * (formula_size - trial + 8) + 22
        note_text = str(section.get("note", "")).strip()
        if note_text:
            cursor += len(wrap(draw, note_text, font(note_size - trial), body_width - 24)) * (note_size - trial + 7) + 22
        if cursor <= y2 - 20:
            break
    else:
        raise ValueError(f"Card overflow: {section['heading']}. Shorten its content.")

    body_font = font(body_size - trial)
    cursor = content_y
    for item in section.get("items", []):
        cursor = text_block(draw, (content_x, cursor), str(item), body_font, COLORS["ink"], body_width, 7, "• ")
        cursor += 4
    formula_text = str(section.get("formula", "")).strip()
    if formula_text:
        cursor += 4
        formula_font = font(formula_size - trial, True)
        formula_lines = wrap(draw, formula_text, formula_font, body_width - 24)
        formula_height = len(formula_lines) * (formula_font.size + 8) + 16
        draw.rounded_rectangle((content_x, cursor, content_right, cursor + formula_height), radius=12, fill=COLORS["pale_blue"])
        line_y = cursor + 8
        for line in formula_lines:
            draw.text((content_x + 14, line_y), line, font=formula_font, fill=COLORS["navy"])
            line_y += formula_font.size + 8
        cursor += formula_height + 8
    note_text = str(section.get("note", "")).strip()
    if note_text:
        note_font = font(note_size - trial)
        note_lines = wrap(draw, note_text, note_font, body_width - 24)
        note_height = len(note_lines) * (note_font.size + 7) + 16
        draw.rounded_rectangle((content_x, cursor, content_right, cursor + note_height), radius=12, fill=COLORS["pale_amber"])
        line_y = cursor + 8
        for line in note_lines:
            draw.text((content_x + 14, line_y), line, font=note_font, fill=COLORS["danger"])
            line_y += note_font.size + 7


def render_page(spec: dict[str, Any], page: dict[str, Any], page_no: int, out_path: Path) -> None:
    canvas = Image.new("RGB", (WIDTH, HEIGHT), COLORS["bg"])
    draw = ImageDraw.Draw(canvas)
    top = draw_header(draw, spec, page, page_no)
    top = draw_metrics(draw, list(page.get("metrics", [])), top)
    sections = page["sections"]
    bottom = HEIGHT - 66
    gap = 18
    card_height = (bottom - top - gap * (len(sections) - 1)) // len(sections)
    if card_height < 190:
        raise ValueError(f"Page {page_no} has too many sections for readable rendering.")
    for index, section in enumerate(sections):
        y1 = top + index * (card_height + gap)
        draw_card(canvas, draw, (MARGIN, y1, WIDTH - MARGIN, y1 + card_height), section)
    draw.text((MARGIN, HEIGHT - 38), f"HG PHYSICS REVIEW · {page_no}/4", font=font(16, True), fill=COLORS["muted"])
    canvas.save(out_path, format="PNG", optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--spec", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    with args.spec.open("r", encoding="utf-8") as handle:
        spec = json.load(handle)
    validate(spec)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for index, (page, filename) in enumerate(zip(spec["pages"], FILES), 1):
        render_page(spec, page, index, args.output_dir / filename)
    print(str(args.output_dir.resolve()))


if __name__ == "__main__":
    main()
