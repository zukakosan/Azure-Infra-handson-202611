const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const pptxgen = require("pptxgenjs");

// The design guide takes precedence over the template's smaller default type sizes.
const P = {
  ink: "16232E", primary: "0B4C8C", teal: "1470C4", cyan: "4FA3E3",
  amber: "E0873A", green: "2E7D57", muted: "5E6B74", line: "D6E1EC",
  soft: "EAF2FB", softer: "F4F9FE", white: "FFFFFF",
};
const FONT = "Yu Gothic UI";
const W = 13.33;
const H = 7.5;
const MX = 0.62;
const CW = W - 2 * MX;
const ROOT = path.resolve(__dirname, "..", "..", "..");

function text(slide, value, x, y, w, h, opts = {}) {
  slide.addText(value, {
    x, y, w, h, fontFace: FONT, fontSize: 18, color: P.ink,
    margin: 0, valign: "mid", breakLine: false, ...opts,
  });
}

function line(slide, x1, y1, x2, y2, opts = {}) {
  slide.addShape("line", {
    x: Math.min(x1, x2), y: Math.min(y1, y2),
    w: Math.abs(x2 - x1), h: Math.abs(y2 - y1),
    flipH: x2 < x1, flipV: y2 < y1,
    line: { color: P.line, width: 1, ...opts },
  });
}

function rect(slide, x, y, w, h, fill = P.softer, border = P.line) {
  slide.addShape("rect", { x, y, w, h, fill: { color: fill }, line: { color: border, width: 1 } });
}

function footer(slide, label, page) {
  line(slide, MX, 7.02, W - MX, 7.02);
  text(slide, label, MX, 7.08, 10.8, 0.25, { fontSize: 12, color: P.muted });
  text(slide, String(page), W - MX - 0.65, 7.08, 0.65, 0.25, {
    fontSize: 12, color: P.muted, align: "right",
  });
}

function header(slide, chapter, data, page) {
  slide.background = { color: P.white };
  text(slide, `${chapter.label}  ${chapter.title}${data.supplemental ? "（補足）" : ""}`,
    MX, 0.42, CW, 0.27, { fontSize: 12, color: P.muted });
  text(slide, data.title, MX, 0.78, CW, 0.55, { fontSize: 28, bold: true, color: P.primary });
  line(slide, MX, 1.45, W - MX, 1.45);
  text(slide, data.lead, MX, 1.65, CW, 0.68, { fontSize: 18, color: P.teal, bold: true });
  footer(slide, `Azure BCDR ワークショップ ／ ${chapter.label} ${chapter.title}`, page);
}

function sources(slide, urls) {
  urls.forEach((url, index) => {
    text(slide, [
      { text: `[${index + 1}] `, options: { bold: true, color: P.muted } },
      { text: url, options: { color: P.muted, hyperlink: { url } } },
    ], MX, 6.34 + index * 0.29, CW, 0.25, { fontSize: 10, color: P.muted });
  });
}

function conclusion(slide, value, warning) {
  text(slide, value, MX, 5.67, CW, 0.49, {
    fontSize: 16, bold: true, color: warning ? P.primary : P.ink,
  });
  if (warning) {
    slide.addShape("rect", {
      x: MX - 0.17, y: 5.69, w: 0.06, h: 0.45,
      fill: { color: P.amber }, line: { color: P.amber },
    });
  }
}

function table(slide, data) {
  const widths = data.widths ?? Array(data.headers.length).fill(CW / data.headers.length);
  const rowHeight = data.rowHeight ?? Math.min(0.75, 3.0 / (data.rows.length + 1));
  const cells = [
    data.headers.map((value) => ({
      text: value, options: { bold: true, color: P.white, fill: P.primary },
    })),
    ...data.rows.map((row, index) => row.map((value, column) => ({
      text: value,
      options: {
        color: column === 0 ? P.primary : P.ink,
        bold: column === 0, fill: index % 2 ? P.softer : P.white,
      },
    }))),
  ];
  slide.addTable(cells, {
    x: MX, y: 2.53, w: CW, colW: widths, rowH: rowHeight,
    fontFace: FONT, fontSize: data.fontSize ?? 16, color: P.ink,
    border: { pt: 0.75, color: P.line }, margin: [5, 7, 5, 7],
    valign: "middle", autoPage: false,
  });
}

function columns(slide, data) {
  const gap = 0.45;
  const width = (CW - gap * (data.groups.length - 1)) / data.groups.length;
  data.groups.forEach((group, index) => {
    const x = MX + index * (width + gap);
    text(slide, group.title, x, 2.56, width, 0.5, { fontSize: 21, bold: true, color: P.primary });
    line(slide, x, 3.15, x + width, 3.15);
    const rowHeight = Math.min(0.82, 2.2 / group.items.length);
    group.items.forEach((item, i) => {
      text(slide, `・${item}`, x, 3.29 + i * rowHeight, width, rowHeight, { fontSize: 18, valign: "top" });
    });
  });
}

function flow(slide, data) {
  const gap = 0.43;
  const width = (CW - gap * (data.steps.length - 1)) / data.steps.length;
  data.steps.forEach((step, index) => {
    const x = MX + index * (width + gap);
    rect(slide, x, 2.88, width, 1.91, P.softer);
    text(slide, step.title, x + 0.14, 3.05, width - 0.28, 0.52, {
      fontSize: 19, bold: true, color: P.primary, align: "center",
    });
    text(slide, step.body, x + 0.14, 3.74, width - 0.28, 0.85, {
      fontSize: 18, align: "center",
    });
    if (index < data.steps.length - 1) {
      line(slide, x + width, 3.8, x + width + gap, 3.8, { color: P.teal, width: 1.5, endArrowType: "triangle" });
    }
  });
}

function diagram(slide, data) {
  data.edges.forEach((edge) => {
    line(slide, ...edge.points, {
      color: edge.warning ? P.amber : P.teal, width: 1.5,
      ...(edge.arrow === false ? {} : { endArrowType: "triangle" }),
      ...(edge.dashed ? { dashType: "dash" } : {}),
    });
  });
  data.nodes.forEach((node) => {
    rect(slide, node.x, node.y, node.w, node.h, node.warning ? P.soft : P.softer,
      node.warning ? P.amber : P.line);
    text(slide, node.title, node.x + 0.13, node.y + 0.09, node.w - 0.26, 0.41, {
      fontSize: node.size ?? 18, bold: true, color: P.primary, align: "center",
    });
    if (node.body) {
      text(slide, node.body, node.x + 0.13, node.y + 0.59, node.w - 0.26, node.h - 0.69, {
        fontSize: 16, align: "center",
      });
    }
  });
  (data.labels ?? []).forEach((label) => {
    text(slide, label.text, label.x, label.y, label.w, label.h ?? 0.4, {
      fontSize: label.size ?? 16, color: label.warning ? P.primary : P.muted,
      align: label.align ?? "center",
    });
  });
}

function timeline(slide, data) {
  const axisY = 3.55;
  const positions = [MX + 0.7, MX + 4.0, W - MX - 0.9];
  line(slide, positions[0], axisY, positions[2], axisY, { color: P.teal, width: 2 });
  data.events.forEach((event, index) => {
    const x = positions[index];
    line(slide, x, axisY - 0.1, x, axisY + 0.12, { color: P.primary, width: 2 });
    text(slide, event.time, x - 0.65, 2.71, 1.3, 0.42, { fontSize: 26, bold: true, color: P.primary, align: "center" });
    text(slide, event.label, Math.max(MX, x - 1.1), 3.92, 2.2, 0.68, { fontSize: 18, align: "center" });
  });
  text(slide, "時系列の概念図（横軸は時間に比例しない）", MX, 4.63, CW, 0.25, {
    fontSize: 12, color: P.muted, align: "center",
  });
  text(slide, data.leftMetric, MX, 4.99, 5.7, 0.45, { fontSize: 20, bold: true, color: P.teal, align: "center" });
  text(slide, data.rightMetric, MX + 6.35, 4.99, 5.7, 0.45, { fontSize: 20, bold: true, color: P.primary, align: "center" });
}

function cover(pptx) {
  const slide = pptx.addSlide();
  slide.background = { color: P.primary };
  slide.addShape("rect", { x: 0, y: 0, w: W, h: 0.16, fill: { color: P.cyan }, line: { color: P.cyan } });
  text(slide, "Azure BCDR ワークショップ", 0.9, 1.43, 11.5, 0.55, { fontSize: 20, color: P.white });
  text(slide, "AzureのDR設計と\nリージョンフェールオーバー", 0.9, 2.13, 11.5, 1.55, {
    fontSize: 38, bold: true, color: P.white,
  });
  text(slide, "業務の復旧目標から方式を選び、切り替えと復旧結果を確認する", 0.9, 4.11, 11.5, 0.72, {
    fontSize: 20, color: P.white,
  });
  text(slide, "座学・デモ・演習前解説 ／ 全体3時間（休憩・演習を含む）", 0.9, 6.48, 11.4, 0.4, {
    fontSize: 16, color: P.white,
  });
  text(slide, "1", W - MX - 0.65, 7.08, 0.65, 0.25, { fontSize: 12, color: P.white, align: "right" });
  slide.addNotes("この資料は既存のBCDR座学Markdownを投影用に再構成したものです。第0章の共有は最初の15分枠内で行います。演習のPortal操作手順は含みません。");
}

const layouts = { table, columns, flow, diagram, timeline };

function validate(chapters) {
  const ids = new Set();
  for (const chapter of chapters) {
    if (ids.has(chapter.id)) throw new Error(`Duplicate chapter: ${chapter.id}`);
    ids.add(chapter.id);
    if (!chapter.goal || !chapter.scope || !chapter.source || !chapter.slides.length) {
      throw new Error(`${chapter.id}: missing chapter purpose, scope, source, or slides`);
    }
    if (!fs.existsSync(path.resolve(__dirname, chapter.source))) throw new Error(`Missing source: ${chapter.source}`);
    for (const data of chapter.slides) {
      if (!data.title || !data.lead || !data.reason || !data.notes || !data.conclusion || !layouts[data.layout]) {
        throw new Error(`${chapter.id}/${data.title}: missing slide content or unsupported layout`);
      }
      const urls = data.sources ?? [];
      if (urls.length > 2 || new Set(urls).size !== urls.length || urls.some((url) => !url.startsWith("https://"))) {
        throw new Error(`${data.title}: invalid source URLs`);
      }
      const content = JSON.stringify({ ...data, sources: undefined, notes: undefined, reason: undefined });
      const refs = [...content.matchAll(/\[(\d+)\]/g)].map((match) => Number(match[1]));
      if (new Set(refs).size !== urls.length || refs.some((ref) => ref < 1 || ref > urls.length)) {
        throw new Error(`${data.title}: unmatched source references`);
      }
      if (data.layout === "table") {
        if (data.rows.some((row) => row.length !== data.headers.length)) throw new Error(`${data.title}: invalid table shape`);
        if (data.fontSize && data.fontSize < 16) throw new Error(`${data.title}: body text below 16pt`);
        if (data.widths && Math.abs(data.widths.reduce((sum, value) => sum + value, 0) - CW) > 0.02) {
          throw new Error(`${data.title}: table widths must sum to ${CW}`);
        }
      }
    }
  }
}

function createPresentation(chapters, includeCover) {
  const pptx = new pptxgen();
  pptx.defineLayout({ name: "OPUS", width: W, height: H });
  pptx.layout = "OPUS";
  pptx.author = "Azure BCDR Workshop";
  pptx.title = includeCover ? "Azure BCDR 座学" : `${chapters[0].label} ${chapters[0].title}`;
  pptx.subject = chapters.map((chapter) => chapter.goal).join("\n");
  pptx.theme = { headFontFace: FONT, bodyFontFace: FONT, lang: "ja-JP" };
  if (includeCover) cover(pptx);
  let page = includeCover ? 2 : 1;
  for (const chapter of chapters) {
    for (const data of chapter.slides) {
      const slide = pptx.addSlide();
      header(slide, chapter, data, page++);
      layouts[data.layout](slide, data);
      conclusion(slide, data.conclusion, data.warning);
      sources(slide, data.sources ?? []);
      slide.addNotes([
        `章の目的：${chapter.goal}`, `対象範囲：${chapter.scope}`,
        `ページの必要性：${data.reason}`, `原稿：${chapter.source}`,
        data.supplemental ? "補足：25分の講義では必要に応じて省略し、復習用に利用します。" : "",
        data.notes, ...(data.sources ?? []).map((url, index) => `[${index + 1}] ${url}`),
      ].filter(Boolean).join("\n\n"));
    }
  }
  return { pptx, count: page - 1 };
}

async function main() {
  const args = process.argv.slice(2);
  const replace = args.includes("--replace");
  const requested = args.find((arg) => /^\d{2}$/.test(arg));
  const versionIndex = args.indexOf("--version");
  const version = versionIndex < 0 ? "v1" : args[versionIndex + 1];
  if (!/^v\d+$/.test(version ?? "")) throw new Error("Specify a version such as --version v2");
  const specPath = path.join(__dirname, "chapters.json");
  const chapters = JSON.parse(fs.readFileSync(specPath, "utf8"));
  validate(chapters);
  const selected = requested ? chapters.filter((chapter) => chapter.id === requested) : chapters;
  if (!selected.length) throw new Error(`Unknown chapter: ${requested}`);
  const jobs = selected.map((chapter) => ({
    chapters: [chapter], cover: false,
    output: path.join(__dirname, chapter.folder, version, `${version}-${chapter.folder}.pptx`),
  }));
  if (!requested) jobs.push({
    chapters, cover: true, output: path.join(__dirname, version, `${version}-Azure-BCDR-座学.pptx`),
  });
  for (const job of jobs) {
    if (!replace && (fs.existsSync(job.output) || fs.existsSync(job.output.replace(/\.pptx$/, ".pdf")))) {
      throw new Error(`Output exists; select a new version or explicitly use --replace: ${job.output}`);
    }
  }
  const results = [];
  for (const job of jobs) {
    fs.mkdirSync(path.dirname(job.output), { recursive: true });
    const { pptx, count } = createPresentation(job.chapters, job.cover);
    await pptx.writeFile({ fileName: job.output });
    results.push({ file: path.relative(__dirname, job.output), slides: count });
    console.log(`Created ${count} slides: ${job.output}`);
  }
  const hashes = {};
  for (const filename of [specPath, ...chapters.map((chapter) => path.resolve(__dirname, chapter.source))]) {
    hashes[path.relative(ROOT, filename)] = crypto.createHash("sha256").update(fs.readFileSync(filename)).digest("hex");
  }
  const manifest = {
    version, designGuide: path.relative(ROOT, path.join(ROOT, "template", "design-template.md")),
    generatorTemplate: path.relative(ROOT, path.join(ROOT, "template", "generate-opus.template.js")),
    rules: {
      font: FONT, bodyMinimum: 16, noteMinimum: 12, sourceMinimum: 10,
      sources: "本文番号と同ページ下部の完全URLを対応付ける。URL文字列のみクリック可能。ノートにも完全URLを記録する。",
      linkColorAndUnderline: "ガイドで未規定。テンプレートの出典色とPowerPointのハイパーリンク表示を使用する。",
      template: "指定フォルダにPPTXはないため、生成テンプレートの寸法・配色・フッターを基準にする。架空のロゴは追加しない。",
      overrides: "デザインガイドに従い小さい本文・出典を拡大し、装飾バッジと過剰なカードを使用しない。",
    },
    hashes, results,
  };
  fs.mkdirSync(path.join(__dirname, version), { recursive: true });
  fs.writeFileSync(path.join(__dirname, version, "build-manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`);
}

main().catch((error) => { console.error(error); process.exitCode = 1; });
