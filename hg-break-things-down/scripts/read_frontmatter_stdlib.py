#!/usr/bin/env python3
"""Read SKILL.md frontmatter without external dependencies.

Compatible with Python 3.14+ using only the standard library.
This parser intentionally supports a small subset that is enough for this skill:
- top-level YAML frontmatter delimited by ---
- simple scalar key: value pairs
- quoted or unquoted values on a single line
"""

from __future__ import annotations

from pathlib import Path
import json


def parse_simple_frontmatter(text: str) -> dict[str, str]:
    if not text.startswith("---\n"):
        raise ValueError("missing YAML frontmatter")

    end = text.find("\n---\n", 4)
    if end == -1:
        raise ValueError("frontmatter terminator not found")

    frontmatter = text[4:end].splitlines()
    data: dict[str, str] = {}

    for raw_line in frontmatter:
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if ":" not in line:
            raise ValueError(f"unsupported frontmatter line: {raw_line!r}")
        key, value = line.split(":", 1)
        key = key.strip()
        value = value.strip()
        if value.startswith(('"', "'")) and value.endswith(('"', "'")) and len(value) >= 2:
            value = value[1:-1]
        data[key] = value

    return data


def main() -> None:
    skill_md = Path(__file__).resolve().parents[1] / "SKILL.md"
    text = skill_md.read_text(encoding="utf-8")
    data = parse_simple_frontmatter(text)
    print(json.dumps(data, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
