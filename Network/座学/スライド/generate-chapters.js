const fs = require("node:fs");
const path = require("node:path");

const pptxgen = require("pptxgenjs");

const DESIGN = {
  width: 13.333,
  height: 7.5,
  margin: 0.62,
  ink: "16232E",
  primary: "0B4C8C",
  teal: "1470C4",
  cyan: "4FA3E3",
  amber: "E0873A",
  green: "2E7D57",
  muted: "5E6B74",
  line: "D6E1EC",
  soft: "EAF2FB",
  softer: "F4F9FE",
  white: "FFFFFF",
  jp: "Yu Gothic UI",
  mono: "Consolas",
  titleSize: 24,
  leadSize: 17,
  bodySize: 16,
  supplementalSize: 12,
  sourceSize: 10,
};

const CONTENT_WIDTH = DESIGN.width - DESIGN.margin * 2;
const RIGHT = DESIGN.width - DESIGN.margin;
const SHAPE = { rect: "rect", roundRect: "roundRect", line: "line", oval: "ellipse" };

function addText(slide, text, box, options = {}) {
  slide.addText(text, {
    x: box.x,
    y: box.y,
    w: box.w,
    h: box.h,
    fontFace: DESIGN.jp,
    fontSize: DESIGN.bodySize,
    color: DESIGN.ink,
    margin: 0,
    valign: "mid",
    ...options,
  });
}

function addFooter(slide, chapter, page) {
  slide.addShape(SHAPE.line, {
    x: DESIGN.margin,
    y: 7.02,
    w: CONTENT_WIDTH,
    h: 0,
    line: { color: DESIGN.line, width: 1 },
  });
  addText(slide, chapter.footer, { x: DESIGN.margin, y: 7.06, w: 10.1, h: 0.26 }, {
    fontSize: DESIGN.supplementalSize,
    color: DESIGN.muted,
    valign: "mid",
  });
  addText(slide, String(page), { x: RIGHT - 0.6, y: 7.06, w: 0.6, h: 0.26 }, {
    fontSize: DESIGN.supplementalSize,
    color: DESIGN.muted,
    align: "right",
    valign: "mid",
  });
}

function addHeader(slide, chapter, page, kicker, title) {
  slide.background = { color: DESIGN.white };
  addText(slide, kicker, {
    x: DESIGN.margin,
    y: 0.43,
    w: CONTENT_WIDTH,
    h: 0.28,
  }, {
    fontSize: DESIGN.supplementalSize,
    bold: true,
    color: DESIGN.cyan,
    charSpacing: 1,
  });
  addText(slide, title, {
    x: DESIGN.margin,
    y: 0.72,
    w: CONTENT_WIDTH,
    h: 0.48,
  }, {
    fontSize: DESIGN.titleSize,
    bold: true,
    color: DESIGN.primary,
    valign: "mid",
  });
  slide.addShape(SHAPE.line, {
    x: DESIGN.margin,
    y: 1.42,
    w: CONTENT_WIDTH,
    h: 0,
    line: { color: DESIGN.line, width: 1.25 },
  });
  addFooter(slide, chapter, page);
}

function addLead(slide, text) {
  addText(slide, text, { x: DESIGN.margin, y: 1.63, w: CONTENT_WIDTH, h: 0.55 }, {
    fontSize: DESIGN.leadSize,
    bold: true,
    color: DESIGN.teal,
    valign: "mid",
  });
}

function addSources(slide, sources) {
  (sources ?? []).forEach((source, index) => {
    slide.addText([
      { text: `[${index + 1}] `, options: { color: DESIGN.muted, bold: true } },
      { text: source.url, options: { color: DESIGN.muted, hyperlink: { url: source.url } } },
    ], {
      x: DESIGN.margin,
      y: 6.18 + index * 0.23,
      w: CONTENT_WIDTH,
      h: 0.21,
      fontFace: DESIGN.jp,
      fontSize: DESIGN.sourceSize,
      color: DESIGN.muted,
      margin: 0,
      valign: "mid",
      breakLine: false,
    });
  });
}

function addCallout(slide, text, color = DESIGN.amber) {
  slide.addShape(SHAPE.rect, {
    x: DESIGN.margin,
    y: 5.57,
    w: CONTENT_WIDTH,
    h: 0.5,
    fill: { color: DESIGN.soft },
    line: { color: DESIGN.soft },
  });
  slide.addShape(SHAPE.rect, {
    x: DESIGN.margin,
    y: 5.57,
    w: 0.08,
    h: 0.5,
    fill: { color },
    line: { color },
  });
  addText(slide, text, {
    x: DESIGN.margin + 0.24,
    y: 5.58,
    w: CONTENT_WIDTH - 0.45,
    h: 0.48,
  }, {
    fontSize: DESIGN.bodySize,
    bold: true,
    color: DESIGN.ink,
  });
}

function addBulletLayout(slide, items) {
  if (items.length < 1 || items.length > 5) throw new Error("Bullet slides require 1-5 items.");
  const top = 2.28;
  const gap = 0.1;
  const rowHeight = Math.min(0.82, (3.15 - gap * (items.length - 1)) / items.length);
  items.forEach((item, index) => {
    const y = top + index * (rowHeight + gap);
    slide.addShape(SHAPE.oval, {
      x: DESIGN.margin + 0.03,
      y: y + rowHeight / 2 - 0.21,
      w: 0.42,
      h: 0.42,
      fill: { color: index % 2 === 0 ? DESIGN.primary : DESIGN.teal },
      line: { color: index % 2 === 0 ? DESIGN.primary : DESIGN.teal },
    });
    addText(slide, String(index + 1), {
      x: DESIGN.margin + 0.03,
      y: y + rowHeight / 2 - 0.21,
      w: 0.42,
      h: 0.42,
    }, {
      fontSize: DESIGN.supplementalSize,
      bold: true,
      color: DESIGN.white,
      align: "center",
    });
    addText(slide, `・${item}`, {
      x: DESIGN.margin + 0.65,
      y,
      w: CONTENT_WIDTH - 0.75,
      h: rowHeight,
      fontSize: DESIGN.bodySize,
      valign: "mid",
    });
  });
}

function addColumnsLayout(slide, groups) {
  if (groups.length < 2 || groups.length > 3) throw new Error("Column slides require 2-3 groups.");
  const gap = 0.28;
  const columnWidth = (CONTENT_WIDTH - gap * (groups.length - 1)) / groups.length;
  groups.forEach((group, index) => {
    const x = DESIGN.margin + index * (columnWidth + gap);
    slide.addShape(SHAPE.line, {
      x,
      y: 2.34,
      w: 0,
      h: 2.95,
      line: { color: index === 1 ? DESIGN.cyan : DESIGN.primary, width: 2.5 },
    });
    addText(slide, group.title, { x: x + 0.18, y: 2.28, w: columnWidth - 0.25, h: 0.62 }, {
      fontSize: 18,
      bold: true,
      color: DESIGN.primary,
      valign: "mid",
    });
    const itemHeight = Math.min(0.84, 2.45 / group.items.length);
    group.items.forEach((item, itemIndex) => {
      addText(slide, `・${item}`, {
        x: x + 0.18,
        y: 3.03 + itemIndex * itemHeight,
        w: columnWidth - 0.25,
        h: itemHeight,
        fontSize: DESIGN.bodySize,
        valign: "top",
      });
    });
  });
}

function addFlowLayout(slide, steps) {
  if (steps.length < 2 || steps.length > 4) throw new Error("Flow slides require 2-4 steps.");
  const gap = 0.42;
  const width = (CONTENT_WIDTH - gap * (steps.length - 1)) / steps.length;
  const y = 2.64;
  const height = 1.75;
  steps.forEach((step, index) => {
    const x = DESIGN.margin + index * (width + gap);
    slide.addShape(SHAPE.roundRect, {
      x,
      y,
      w: width,
      h: height,
      rectRadius: 0.06,
      fill: { color: index % 2 === 0 ? DESIGN.softer : DESIGN.soft },
      line: { color: DESIGN.line, width: 1 },
    });
    addText(slide, step.title, { x: x + 0.16, y: y + 0.14, w: width - 0.32, h: 0.48 }, {
      fontSize: 18,
      bold: true,
      color: DESIGN.primary,
      align: "center",
    });
    addText(slide, step.body, { x: x + 0.16, y: y + 0.68, w: width - 0.32, h: 0.94 }, {
      fontSize: DESIGN.bodySize,
      align: "center",
      valign: "mid",
    });
    if (index < steps.length - 1) {
      slide.addShape(SHAPE.line, {
        x: x + width,
        y: y + height / 2,
        w: gap,
        h: 0,
        line: { color: DESIGN.teal, width: 2, endArrowType: "triangle" },
      });
    }
  });
}

function addCompareLayout(slide, groups) {
  if (groups.length !== 2) throw new Error("Comparison slides require exactly 2 groups.");
  const gap = 0.42;
  const width = (CONTENT_WIDTH - gap) / 2;
  groups.forEach((group, index) => {
    const x = DESIGN.margin + index * (width + gap);
    slide.addShape(SHAPE.rect, {
      x,
      y: 2.34,
      w: width,
      h: 2.96,
      fill: { color: index === 0 ? DESIGN.softer : DESIGN.soft },
      line: { color: DESIGN.line, width: 1 },
    });
    addText(slide, group.title, { x: x + 0.2, y: 2.48, w: width - 0.4, h: 0.52 }, {
      fontSize: 19,
      bold: true,
      color: index === 0 ? DESIGN.primary : DESIGN.teal,
    });
    const itemHeight = Math.min(0.82, 2.15 / group.items.length);
    group.items.forEach((item, itemIndex) => {
      addText(slide, `・${item}`, {
        x: x + 0.2,
        y: 3.15 + itemIndex * itemHeight,
        w: width - 0.4,
        h: itemHeight,
        fontSize: DESIGN.bodySize,
        valign: "top",
      });
    });
  });
}

function addTableLayout(slide, table) {
  const columns = table.headers.length;
  if (columns < 2 || columns > 4) throw new Error("Tables require 2-4 columns.");
  if (table.rows.length < 2 || table.rows.length > 5) throw new Error("Tables require 2-5 rows.");
  const columnWidth = CONTENT_WIDTH / columns;
  const rowHeight = Math.min(0.72, 3.25 / (table.rows.length + 1));
  const data = [
    table.headers.map((header) => ({
      text: header,
      options: {
        fill: { color: DESIGN.primary },
        color: DESIGN.white,
        bold: true,
        fontFace: DESIGN.jp,
        fontSize: DESIGN.bodySize,
        valign: "middle",
        align: "left",
      },
    })),
    ...table.rows.map((row, rowIndex) => row.map((cell, cellIndex) => ({
      text: cell,
      options: {
        fill: { color: rowIndex % 2 === 0 ? DESIGN.white : DESIGN.softer },
        color: cellIndex === 0 ? DESIGN.primary : DESIGN.ink,
        bold: cellIndex === 0,
        fontFace: DESIGN.jp,
        fontSize: DESIGN.bodySize,
        valign: "middle",
        align: "left",
      },
    }))),
  ];
  slide.addTable(data, {
    x: DESIGN.margin,
    y: 2.3,
    w: CONTENT_WIDTH,
    colW: Array(columns).fill(columnWidth),
    rowH: rowHeight,
    border: { pt: 0.75, color: DESIGN.line },
    margin: [3, 6, 3, 6],
    valign: "middle",
    autoPage: false,
  });
}

function addCover(pptx, chapter) {
  const slide = pptx.addSlide();
  slide.background = { color: DESIGN.primary };
  slide.addShape(SHAPE.rect, {
    x: 0,
    y: 0,
    w: DESIGN.width,
    h: 0.16,
    fill: { color: DESIGN.cyan },
    line: { color: DESIGN.cyan },
  });
  addText(slide, chapter.label, { x: 0.9, y: 1.5, w: 6, h: 0.52 }, {
    fontSize: 18,
    bold: true,
    color: DESIGN.cyan,
    charSpacing: 2,
  });
  addText(slide, chapter.title, { x: 0.9, y: 2.05, w: 11.5, h: 1.2 }, {
    fontSize: 44,
    bold: true,
    color: DESIGN.white,
    valign: "mid",
  });
  addText(slide, chapter.subtitle, { x: 0.9, y: 3.3, w: 11.5, h: 0.64 }, {
    fontSize: 17,
    color: "BFE6EC",
    valign: "mid",
  });
  let x = 0.9;
  chapter.chips.forEach((chip) => {
    const width = 0.5 + chip.length * 0.2;
    slide.addShape(SHAPE.roundRect, {
      x,
      y: 4.35,
      w: width,
      h: 0.56,
      rectRadius: 0.25,
      fill: { color: "12508C" },
      line: { color: DESIGN.cyan, width: 1 },
    });
    addText(slide, chip, { x, y: 4.35, w: width, h: 0.56 }, {
      fontSize: DESIGN.bodySize,
      color: DESIGN.white,
      align: "center",
    });
    x += width + 0.2;
  });
  addText(slide, chapter.meta, { x: 0.9, y: 6.5, w: 10.8, h: 0.32 }, {
    fontSize: DESIGN.supplementalSize,
    color: "BFE6EC",
  });
  addText(slide, "1", { x: 12.1, y: 7.06, w: 0.6, h: 0.26 }, {
    fontSize: DESIGN.supplementalSize,
    color: "BFE6EC",
    align: "right",
  });
}

function addQuiz(pptx, chapter, page) {
  const slide = pptx.addSlide();
  addHeader(slide, chapter, page, "理解度の確認", `${chapter.title}の確認問題`);
  addLead(slide, "各問について、根拠と次に確認する情報を説明してください。");
  const height = 0.86;
  const gap = 0.13;
  chapter.quiz.forEach((question, index) => {
    const y = 2.32 + index * (height + gap);
    slide.addShape(SHAPE.roundRect, {
      x: DESIGN.margin,
      y,
      w: CONTENT_WIDTH,
      h: height,
      rectRadius: 0.06,
      fill: { color: DESIGN.softer },
      line: { color: DESIGN.line, width: 1 },
    });
    slide.addShape(SHAPE.rect, {
      x: DESIGN.margin,
      y,
      w: 0.08,
      h: height,
      fill: { color: DESIGN.teal },
      line: { color: DESIGN.teal },
    });
    addText(slide, String(index + 1), { x: DESIGN.margin + 0.24, y: y + 0.2, w: 0.42, h: 0.42 }, {
      fontSize: DESIGN.bodySize,
      bold: true,
      color: DESIGN.primary,
      align: "center",
    });
    addText(slide, question, { x: DESIGN.margin + 0.82, y: y + 0.04, w: CONTENT_WIDTH - 1.1, h: height - 0.08 }, {
      fontSize: DESIGN.bodySize,
      valign: "mid",
    });
  });
}

function validateChapter(chapter) {
  if (chapter.slides.length === 0 || chapter.quiz.length < 2 || chapter.quiz.length > 4) {
    throw new Error(`${chapter.id}: expected content slides and 2-4 quiz questions.`);
  }
  chapter.slides.forEach((slide) => {
    if (!slide.title || !slide.lead || !slide.notes) {
      throw new Error(`${chapter.id}/${slide.title || "untitled"}: title, lead, and notes are required.`);
    }
    const sources = slide.sources ?? [];
    if (!Array.isArray(sources) || sources.length > 3) {
      throw new Error(`${chapter.id}/${slide.title}: sources must be an array of at most 3 entries.`);
    }
    const urls = sources.map((source) => source.url);
    if (new Set(urls).size !== urls.length) {
      throw new Error(`${chapter.id}/${slide.title}: duplicate source URL.`);
    }
    const content = JSON.stringify({
      title: slide.title,
      lead: slide.lead,
      items: slide.items,
      groups: slide.groups,
      steps: slide.steps,
      headers: slide.headers,
      rows: slide.rows,
      callout: slide.callout,
    });
    const refs = [...content.matchAll(/\[(\d+)\]/g)].map((match) => Number(match[1]));
    const used = new Set(refs);
    if (refs.some((ref) => ref < 1 || ref > urls.length) || used.size !== urls.length) {
      throw new Error(`${chapter.id}/${slide.title}: source references and source URLs do not match.`);
    }
    if (sources.some((source) => !/^https:\/\//.test(source.url))) {
      throw new Error(`${chapter.id}/${slide.title}: sources must be complete HTTPS URLs.`);
    }
    if (!["bullets", "columns", "flow", "compare", "table"].includes(slide.layout)) {
      throw new Error(`${chapter.id}/${slide.title}: unsupported layout '${slide.layout}'.`);
    }
  });
}

async function buildChapter(chapter, replace, version) {
  validateChapter(chapter);
  const folder = path.join(__dirname, chapter.folder);
  const outputFolder = path.join(folder, version);
  const pptxPath = path.join(outputFolder, `${version}-${chapter.folder}.pptx`);
  const pdfPath = path.join(outputFolder, `${version}-${chapter.folder}.pdf`);
  fs.mkdirSync(outputFolder, { recursive: true });

  if (!replace && (fs.existsSync(pptxPath) || fs.existsSync(pdfPath))) {
    throw new Error(`Output already exists; use --replace only when replacing generated files: ${pptxPath}`);
  }

  const pptx = new pptxgen();
  pptx.defineLayout({ name: "OPUS", width: DESIGN.width, height: DESIGN.height });
  pptx.layout = "OPUS";
  pptx.author = "Azure Network Workshop";
  pptx.subject = chapter.goal;
  pptx.title = `${chapter.label} ${chapter.title}`;
  pptx.theme = { headFontFace: DESIGN.jp, bodyFontFace: DESIGN.jp, lang: "ja-JP" };

  addCover(pptx, chapter);
  chapter.slides.forEach((data, index) => {
    const page = index + 2;
    const slide = pptx.addSlide();
    addHeader(slide, chapter, page, data.kicker, data.title);
    addLead(slide, data.lead);
    switch (data.layout) {
      case "bullets":
        addBulletLayout(slide, data.items);
        break;
      case "columns":
        addColumnsLayout(slide, data.groups);
        break;
      case "flow":
        addFlowLayout(slide, data.steps);
        break;
      case "compare":
        addCompareLayout(slide, data.groups);
        break;
      case "table":
        addTableLayout(slide, data);
        break;
    }
    if (data.callout) addCallout(slide, data.callout, data.calloutColor);
    const sources = data.sources ?? [];
    addSources(slide, sources);
    const notes = [
      data.notes.trim(),
      ...sources.map((source, sourceIndex) => `[${sourceIndex + 1}] ${source.url}`),
    ].filter(Boolean).join("\n\n");
    slide.addNotes(notes);
  });
  addQuiz(pptx, chapter, chapter.slides.length + 2);

  await pptx.writeFile({ fileName: pptxPath });
  return { chapter: chapter.id, slides: chapter.slides.length + 2, pptxPath, pdfPath };
}

async function main() {
  const dataPath = path.join(__dirname, "chapters.json");
  const chapters = JSON.parse(fs.readFileSync(dataPath, "utf8"));
  const args = process.argv.slice(2);
  const replace = args.includes("--replace");
  const versionIndex = args.indexOf("--version");
  const version = versionIndex >= 0 ? args[versionIndex + 1] : "v1";
  if (!/^v\d+$/.test(version ?? "")) {
    throw new Error("Specify an output version such as --version v2.");
  }
  const requestedChapter = args.find((arg, index) =>
    !arg.startsWith("--") && (versionIndex < 0 || index !== versionIndex + 1));
  const selected = requestedChapter
    ? chapters.filter((chapter) => chapter.id === requestedChapter)
    : chapters;
  if (selected.length === 0) throw new Error(`Unknown chapter: ${requestedChapter}`);
  selected.forEach(validateChapter);
  for (const chapter of selected) {
    const result = await buildChapter(chapter, replace, version);
    console.log(`Created ${result.slides} slides: ${result.pptxPath}`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
