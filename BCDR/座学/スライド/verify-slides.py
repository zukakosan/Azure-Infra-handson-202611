import argparse
import hashlib
import json
import re
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

from PIL import Image, ImageDraw
from pypdf import PdfReader


NS = {
    "a": "http://schemas.openxmlformats.org/drawingml/2006/main",
    "p": "http://schemas.openxmlformats.org/presentationml/2006/main",
    "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
}
REL = "{http://schemas.openxmlformats.org/package/2006/relationships}"
BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[2]


def compact(value):
    return re.sub(r"\s+", "", value)


def slide_strings(data):
    values = [data["title"], data["lead"], data["conclusion"]]
    for group in data.get("groups", []):
        values.extend([group["title"], *["・" + item for item in group["items"]]])
    for step in data.get("steps", []):
        values.extend([step["title"], step["body"]])
    values.extend(data.get("headers", []))
    for row in data.get("rows", []):
        values.extend(row)
    for node in data.get("nodes", []):
        values.extend([node["title"], node.get("body", "")])
    for label in data.get("labels", []):
        values.append(label["text"])
    for event in data.get("events", []):
        values.extend([event["time"], event["label"]])
    if data["layout"] == "timeline":
        values.extend([data["leftMetric"], data["rightMetric"]])
    return [value for value in values if value]


def check_deck(pptx, expected, cover=False):
    problems = []
    with zipfile.ZipFile(pptx) as archive:
        names = archive.namelist()
        slide_files = sorted(
            [name for name in names if re.fullmatch(r"ppt/slides/slide\d+\.xml", name)],
            key=lambda name: int(re.search(r"slide(\d+)", name).group(1)),
        )
        if len(slide_files) != len(expected) + int(cover):
            problems.append(f"{pptx.name}: unexpected slide count")
        pdf = PdfReader(pptx.with_suffix(".pdf"))
        if len(pdf.pages) != len(slide_files):
            problems.append(f"{pptx.name}: PDF page count differs")
        for page, filename in enumerate(slide_files, 1):
            tree = ET.fromstring(archive.read(filename))
            texts = tree.findall(".//a:t", NS)
            plain = "".join(node.text or "" for node in texts)
            if re.search(r"スライドタイトルを具体的|小見出し|項目A|章タイトル|lorem|ipsum", plain, re.I):
                problems.append(f"{pptx.name}/{page}: placeholder text")
            for extent in tree.findall(".//a:xfrm/a:ext", NS):
                if int(extent.get("cx")) < 0 or int(extent.get("cy")) < 0:
                    problems.append(f"{pptx.name}/{page}: negative shape dimensions")
            for run in tree.findall(".//a:rPr", NS):
                size = run.get("sz")
                if size and int(size) < 1000:
                    problems.append(f"{pptx.name}/{page}: font below 10pt")
                for kind in ("latin", "ea"):
                    font = run.find(f"a:{kind}", NS)
                    if font is not None and font.get("typeface") not in ("Yu Gothic UI", "Consolas"):
                        problems.append(f"{pptx.name}/{page}: unexpected font")
            for cell in tree.findall(".//a:tc", NS):
                if any(int(run.get("sz", "1600")) < 1600 for run in cell.findall(".//a:rPr", NS)):
                    problems.append(f"{pptx.name}/{page}: table text below 16pt")
            for shape in tree.findall(".//p:sp", NS):
                offset = shape.find("p:spPr/a:xfrm/a:off", NS)
                if offset is None:
                    continue
                top = int(offset.get("y")) / 914400
                shape_text = "".join(node.text or "" for node in shape.findall(".//a:t", NS))
                if not shape_text:
                    continue
                minimum = 10 if 6.3 <= top < 7 else 12
                if 1.6 <= top < 6.2:
                    minimum = 12 if shape_text.startswith("時系列の概念図") else 16
                if any(
                    int(run.get("sz", str(minimum * 100))) < minimum * 100
                    for run in shape.findall(".//a:rPr", NS)
                ):
                    problems.append(f"{pptx.name}/{page}: text below {minimum}pt in its role")
            number_shapes = [
                shape for shape in tree.findall(".//p:sp", NS)
                if "".join(node.text or "" for node in shape.findall(".//a:t", NS)) == str(page)
            ]
            if not any(
                (offset := shape.find("p:spPr/a:xfrm/a:off", NS)) is not None
                and int(offset.get("x")) > 10_000_000 and int(offset.get("y")) > 6_000_000
                for shape in number_shapes
            ):
                problems.append(f"{pptx.name}/{page}: page number is not at bottom right")
            notes_path = f"ppt/notesSlides/notesSlide{page}.xml"
            notes = ""
            if notes_path in names:
                notes = "".join(node.text or "" for node in ET.fromstring(archive.read(notes_path)).findall(".//a:t", NS))
            if not notes.strip():
                problems.append(f"{pptx.name}/{page}: missing notes")
            if cover and page == 1:
                continue
            data = expected[page - 1 - int(cover)]
            for value in slide_strings(data):
                if compact(value) not in compact(plain):
                    problems.append(f"{pptx.name}/{page}: missing projected content: {value}")
            relationships_path = f"ppt/slides/_rels/slide{page}.xml.rels"
            relations = {
                node.get("Id"): node.get("Target")
                for node in ET.fromstring(archive.read(relationships_path)).findall(REL + "Relationship")
            }
            linked = []
            for run in tree.findall(".//a:r", NS):
                click = run.find("a:rPr/a:hlinkClick", NS)
                if click is None:
                    continue
                displayed = "".join(node.text or "" for node in run.findall("a:t", NS))
                target = relations[click.get("{" + NS["r"] + "}id")]
                if displayed != target or not displayed.startswith("https://"):
                    problems.append(f"{pptx.name}/{page}: hyperlink not limited to matching full URL")
                linked.append(target)
            urls = data.get("sources", [])
            if sorted(linked) != sorted(urls):
                problems.append(f"{pptx.name}/{page}: PPTX source links differ")
            pdf_urls = []
            for annotation in pdf.pages[page - 1].get("/Annots", []):
                action = annotation.get_object().get("/A")
                if action and action.get("/URI"):
                    pdf_urls.append(str(action["/URI"]))
            if not set(urls).issubset(pdf_urls):
                problems.append(f"{pptx.name}/{page}: PDF hyperlinks missing")
            for url in urls:
                if url not in notes:
                    problems.append(f"{pptx.name}/{page}: source URL missing from notes")
            if tree.findall(".//p:pic", NS):
                problems.append(f"{pptx.name}/{page}: content unexpectedly rasterized")
    return problems


def contact_sheets(directory):
    images = sorted(directory.glob("slide-*.png"))
    for start in range(0, len(images), 12):
        group = images[start:start + 12]
        sheet = Image.new("RGB", (1440, 900), "white")
        draw = ImageDraw.Draw(sheet)
        for index, filename in enumerate(group):
            x = (index % 3) * 480
            y = (index // 3) * 225
            with Image.open(filename) as image:
                image.thumbnail((464, 261))
                image = image.resize((360, 202))
                sheet.paste(image, (x + 58, y + 20))
            draw.text((x + 6, y + 3), filename.stem, fill="black")
        sheet.save(directory / f"contact-{start // 12 + 1:02}.png")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", default="v1")
    parser.add_argument("--verification-directory", type=Path, required=True)
    args = parser.parse_args()
    chapters = json.loads((BASE / "chapters.json").read_text(encoding="utf-8"))
    problems = []
    projected = []
    for chapter in chapters:
        projected.extend(chapter["slides"])
        pptx = BASE / chapter["folder"] / args.version / f"{args.version}-{chapter['folder']}.pptx"
        problems.extend(check_deck(pptx, chapter["slides"]))
    combined = BASE / args.version / f"{args.version}-Azure-BCDR-座学.pptx"
    problems.extend(check_deck(combined, projected, cover=True))
    manifest = json.loads((BASE / args.version / "build-manifest.json").read_text(encoding="utf-8"))
    for filename, digest in manifest["hashes"].items():
        if hashlib.sha256((ROOT / filename).read_bytes()).hexdigest() != digest:
            problems.append(f"Build input changed: {filename}")
    contact_sheets(args.verification_directory)
    report = {
        "combinedSlides": len(projected) + 1,
        "chapterDecks": len(chapters),
        "checks": ["projected content", "slide counts", "notes", "full URL hyperlinks",
                   "PDF hyperlinks", "page numbers", "fonts", "native shapes", "input hashes"],
        "problems": problems,
    }
    (args.verification_directory / "file-verification.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    if problems:
        raise SystemExit("\n".join(problems))
    print(f"PASS: {len(projected) + 1} combined slides, {len(chapters)} chapter decks; PPTX/PDF/notes/links verified.")


if __name__ == "__main__":
    main()
