"""Create Russian SVG figures while preserving the original English charts.

This reuses the geometry and data already rendered by the experiment. Matplotlib
saved its labels as vector paths; this script replaces only those label groups
with editable Cyrillic SVG text. No metrics or plotted shapes are changed.
"""

from __future__ import annotations

import argparse
import copy
import re
import xml.etree.ElementTree as ET
from pathlib import Path


SVG_NS = "http://www.w3.org/2000/svg"
XLINK_NS = "http://www.w3.org/1999/xlink"
ET.register_namespace("", SVG_NS)
ET.register_namespace("xlink", XLINK_NS)

LABELS = {
    "Aeolian": "Эолийская", "Scale": "гамма", "Riff": "Рифф",
    "Pentatonic": "Пентатоника",
    "Basic Pitch default": "По умолчанию",
    "Development-selected decoder": "После подбора",
    "Decoder tuning helps some phrases, but not all": "Настройка помогает не на каждой фразе",
    "Development clips are shaded blue; held-out test clips are shaded sand.":
        "Голубой фон — подбор; песочный — отложенный тест.",
    "DEVELOPMENT": "", "HELD-OUT TEST": "",
    "selected": "выбрано",
    "Melodia trick: ON": "Melodia включён",
    "Melodia trick: OFF": "Melodia выключен",
    "Macro recall on development": "Средняя полнота при подборе",
    "Macro precision on development": "Средняя точность при подборе",
    "Decoder configurations trade recall for precision":
        "Меньше лишних нот — больше риск пропусков",
    "Each point is one configuration. The marked choice maximised mean clip-level F1 under the selection rule.":
        "Точка — набор параметров. Обведён вариант с лучшим средним F1 на трёх записях.",
    "Manual reference": "Ручная разметка",
    "Selected decoder": "После подбора",
    "Matched prediction": "Совпавшая нота",
    "Unmatched prediction": "Лишняя нота",
    "Missed reference": "Пропущенная нота",
    "What changed in the transcription?": "Какие ноты модель нашла и пропустила?",
    "Time (s)": "Время, с",
    "Pitch": "Высота ноты",
    "Pitch range": "Диапазон нот",
    "An acoustic guitar phrase on a musical frequency grid":
        "Гитарная фраза на шкале музыкальных нот",
    "Relative energy (dB)": "Относительная энергия, дБ",
    "Bright horizontal traces include played notes and their harmonics; this is a signal view, not a transcription.":
        "Яркие полосы показывают ноты и обертоны. Это вид сигнала, а не результат модели.",
}


def translate(label: str) -> str | None:
    if label in LABELS:
        return LABELS[label]
    if label.startswith("Onset "):
        return "нач. " + label[6:].replace(".", ",")
    if label.startswith("Frame "):
        return "прод. " + label[6:].replace(".", ",")
    f1_match = re.fullmatch(r"Note F1 \(pitch \+ onset within (\d+) ms\)", label)
    if f1_match:
        return f"F1 по нотам: высота и начало ±{f1_match.group(1)} мс"
    if label.endswith(" notes") and label[:-6].isdigit():
        return label[:-6] + " нот"
    match_label = re.fullmatch(
        r"Exact pitch and onset within (\d+) ms count as a match\. Selected: (.+)",
        label,
    )
    if match_label:
        tolerance_ms, identifier = match_label.groups()
        match = re.fullmatch(r"onset_([\d.]+)__frame_([\d.]+)__melodia_(on|off)", identifier)
        if match:
            onset, frame, melodia = match.groups()
            state = "включён" if melodia == "on" else "выключен"
            return (f"Совпадение: та же высота и начало ±{tolerance_ms} мс. "
                    f"Выбрано: начало {onset.replace('.', ',')}; "
                    f"продолжение {frame.replace('.', ',')}; Melodia {state}.")
        return f"Совпадение: та же высота и начало ±{tolerance_ms} мс. Выбрано: " + identifier
    return None


def localize(source: Path, destination: Path) -> tuple[int, list[str]]:
    parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
    tree = ET.parse(source, parser=parser)
    root_defs = tree.getroot().find(f"{{{SVG_NS}}}defs")
    if root_defs is None:
        root_defs = ET.SubElement(tree.getroot(), f"{{{SVG_NS}}}defs")
    count = 0
    untranslated = []
    for group in tree.getroot().iter(f"{{{SVG_NS}}}g"):
        if not group.get("id", "").startswith("text_"):
            continue
        children = list(group)
        for index, child in enumerate(children[:-1]):
            if child.tag is not ET.Comment or not child.text:
                continue
            old_g = children[index + 1]
            if old_g.tag != f"{{{SVG_NS}}}g":
                continue
            label = child.text.strip()
            replacement = translate(label)
            if replacement is None:
                if re.search(r"[A-Za-z]", label) and not re.fullmatch(r"[A-G](?:#)?\d", label):
                    untranslated.append(label)
                continue
            transform = old_g.get("transform", "")
            size_match = re.search(r"scale\(([\d.]+)\s+-[\d.]+\)", transform)
            if size_match is None:
                raise ValueError(f"Неизвестный масштаб подписи: {label}: {transform}")
            font_size = float(size_match.group(1)) * 100
            transform = re.sub(r"\s*scale\([^)]+\)", "", transform)
            # In the compact one-row piano-roll figure Matplotlib places the
            # subtitle almost on the title baseline. Move only that compact
            # case down; the two-row figure already has enough separation.
            if label.startswith("Exact pitch and onset within "):
                position = re.search(r"translate\(([-\d.]+)\s+([-\d.]+)\)", transform)
                if position and float(position.group(2)) < 25:
                    transform = re.sub(
                        r"translate\(([-\d.]+)\s+([-\d.]+)\)",
                        lambda match: f"translate({match.group(1)} 31.5)",
                        transform,
                        count=1,
                    )
            # Other original labels may reference glyphs defined here.
            for defs in old_g.iter(f"{{{SVG_NS}}}defs"):
                for definition in defs:
                    root_defs.append(copy.deepcopy(definition))
            text = ET.Element(f"{{{SVG_NS}}}text", {
                "transform": transform,
                "font-family": "DejaVu Sans, Arial, sans-serif",
                "font-size": f"{font_size:g}",
                "fill": "#30373d",
            })
            text.text = replacement
            group.remove(old_g)
            group.insert(index + 1, text)
            count += 1
    destination.parent.mkdir(parents=True, exist_ok=True)
    tree.write(destination, encoding="utf-8", xml_declaration=True)
    return count, untranslated


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path,
        default=Path(__file__).resolve().parents[1] / "assets" / "guitar" / "ru")
    args = parser.parse_args()
    source_dir = args.project_root.resolve() / "outputs" / "evaluation_onset_frame_melodia" / "figures"
    output_dir = args.output_dir.resolve()
    for name in ["01_f1_by_clip", "02_precision_recall_grid", "03_piano_roll_examples", "04_cqt_aeolian_scale"]:
        count, untranslated = localize(source_dir / f"{name}.svg", output_dir / f"{name}.svg")
        print(f"{name}: localized {count} labels")
        if untranslated:
            print("  Kept as names or symbols:", ", ".join(sorted(set(untranslated))))


if __name__ == "__main__":
    main()
