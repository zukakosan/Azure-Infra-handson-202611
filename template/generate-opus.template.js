// スライド生成テンプレート（Opus デザイン）
// -------------------------------------------------------------------------
// 使い方:
//   1. このファイルを対象章へコピーする。
//        docs/sections/<章フォルダ>/generate-opus.js
//   2. 先頭の CFG ブロックだけを章に合わせて書き換える。
//   3. s01..sNN に各スライドの内容を実装する（下部にサンプルあり）。
//   4. 生成・複製・描画:
//        node docs/sections/<章フォルダ>/generate-opus.js
//        Copy-Item docs/sections/<章フォルダ>/slides.md docs/sections/<章フォルダ>/v1/v1-slides.md -Force
//        pwsh -File docs/sections/<章フォルダ>/render-opus.ps1
//
// デザインの基準は docs/template/design-template.md に従う。
// 共通ヘルパー（P/header/footer/lead/sources/callout/tableAt/codeBox/connect/node）は
// 章をまたいで同一にし、章ごとの実装ブレをなくすこと。
// =========================================================================

const pptxgen = require("pptxgenjs");

// ===== 章ごとに変更する設定（ここだけ書き換える） =========================
const CFG = {
  no: "00",                                   // 章番号（2桁ゼロ埋め）。PNG/フッターに使う
  jp: "第0章",                                // 表紙の章ラベル
  title: "章タイトル",                        // 表紙の大見出し
  subtitle: "この章で説明する内容を一文で示す", // 表紙のサブタイトル
  footer: "第0章  章タイトル — サブトピックの列挙", // フッター左に出す文字列
  chips: ["トピックA", "トピックB", "トピックC", "トピックD"], // 表紙下部のチップ
  meta: "Azure IoT ワークショップ ／ 本編 15 分・8 枚",         // 表紙下部のメタ表記
  // 出力パス（章フォルダに合わせる）
  out: "docs/sections/00-chapter/v1/v1-00-chapter.pptx",
  titleSize: 24, // タイトルが長く折り返す場合のみ 23 などへ下げる
};

// ===== デザイン定数（全章共通・変更しない） ===============================
const P = {
  ink: "16232E",
  primary: "0B4C8C",   // 深い Azure ブルー（ドミナント）
  teal: "1470C4",      // 中間の Azure ブルー（リード文・矢印・アクセント）
  cyan: "4FA3E3",      // 明るいアズール（表紙アクセント）
  amber: "E0873A",     // 温色アクセント（注意・強調に限定）
  green: "2E7D57",     // 肯定・必須以外の分類に限定（任意）
  muted: "5E6B74",
  line: "D6E1EC",
  soft: "EAF2FB",
  softer: "F4F9FE",
  white: "FFFFFF",
};
const JP = "Yu Gothic UI";
const MONO = "Consolas";
const MX = 0.62;
const CW = 13.33 - MX * 2;
const RIGHT = 13.33 - MX;

const pptx = new pptxgen();
pptx.defineLayout({ name: "W", width: 13.33, height: 7.5 });
pptx.layout = "W";
pptx.author = "Azure IoT Workshop";
pptx.title = `${CFG.jp} ${CFG.title}`;

const S = { rect: "rect", roundRect: "roundRect", line: "line", oval: "ellipse" };

// ---- 共通パーツ（全章共通・変更しない） ----------------------------------
function footer(slide, n) {
  slide.addShape(S.line, { x: MX, y: 7.02, w: CW, h: 0, line: { color: P.line, width: 1 } });
  slide.addText(CFG.footer, {
    x: MX, y: 7.06, w: 9.5, h: 0.3, fontFace: JP, fontSize: 9, color: P.muted, margin: 0, valign: "middle",
  });
  slide.addText(String(n), {
    x: RIGHT - 0.6, y: 7.06, w: 0.6, h: 0.3, fontFace: JP, fontSize: 10, color: P.muted, align: "right", margin: 0, valign: "middle",
  });
}

function header(slide, no, kicker, title) {
  slide.background = { color: P.white };
  slide.addShape(S.rect, { x: MX, y: 0.5, w: 0.62, h: 0.62, fill: { color: P.primary }, line: { type: "none" } });
  slide.addText(no, { x: MX, y: 0.5, w: 0.62, h: 0.62, fontFace: JP, fontSize: 16, bold: true, color: P.white, align: "center", valign: "middle", margin: 0 });
  slide.addText(kicker.toUpperCase(), { x: MX + 0.82, y: 0.46, w: 9, h: 0.24, fontFace: JP, fontSize: 11, bold: true, color: P.cyan, charSpacing: 2, margin: 0, valign: "middle" });
  slide.addText(title, { x: MX + 0.82, y: 0.68, w: CW - 0.9, h: 0.5, fontFace: JP, fontSize: CFG.titleSize, bold: true, color: P.primary, margin: 0, valign: "middle" });
  slide.addShape(S.line, { x: MX, y: 1.42, w: CW, h: 0, line: { color: P.line, width: 1.25 } });
}

function lead(slide, text, y = 1.62) {
  slide.addText(text, { x: MX, y, w: CW, h: 0.4, fontFace: JP, fontSize: 15, bold: true, color: P.teal, margin: 0, valign: "middle" });
}

// 出典（横一列）。URL が短く 1〜2 件のときに使う。
function sourcesRow(slide, arr) {
  if (!arr || !arr.length) return;
  const runs = [];
  arr.forEach((u, i) => {
    runs.push({ text: `[${i + 1}] `, options: { color: P.muted, bold: true } });
    runs.push({ text: u, options: { color: P.muted, hyperlink: { url: u } } });
    if (i < arr.length - 1) runs.push({ text: "   ", options: {} });
  });
  slide.addText(runs, { x: MX, y: 6.62, w: CW, h: 0.34, fontFace: JP, fontSize: 8, margin: 0, valign: "middle" });
}

// 出典（縦積み）。URL が長い／件数が多いときに使う。下端をフッター直上へ揃える。
function sourcesStack(slide, arr) {
  if (!arr || !arr.length) return;
  const lineH = 0.16;
  const startY = 6.98 - arr.length * lineH;
  arr.forEach((u, i) => {
    slide.addText([
      { text: `[${i + 1}] `, options: { color: P.muted, bold: true } },
      { text: u, options: { color: P.muted, hyperlink: { url: u } } },
    ], { x: MX, y: startY + i * lineH, w: CW, h: lineH, fontFace: JP, fontSize: 8, margin: 0, valign: "middle" });
  });
}

// 既定の出典スタイル。章の出典量に応じて sourcesRow / sourcesStack を直接呼んでもよい。
const sources = sourcesStack;

// URL の無い出典（社内資料など）。
function noteSource(slide, text, y = 6.66) {
  slide.addText(text, { x: MX, y, w: CW, h: 0.3, fontFace: JP, fontSize: 9, italic: true, color: P.muted, margin: 0, valign: "middle" });
}

function callout(slide, text, y, w = CW, x = MX, color = P.amber) {
  const h = 0.62;
  slide.addShape(S.rect, { x, y, w, h, fill: { color: P.soft }, line: { type: "none" } });
  slide.addShape(S.rect, { x, y, w: 0.09, h, fill: { color }, line: { type: "none" } });
  slide.addText(text, { x: x + 0.24, y, w: w - 0.4, h, fontFace: JP, fontSize: 12.5, bold: true, color: P.ink, margin: 0, valign: "middle" });
  return y + h;
}

function tableAt(slide, head, rows, y, opts = {}) {
  const colW = opts.colW;
  const body = [];
  body.push(head.map((h) => ({ text: h, options: { fill: { color: P.primary }, color: P.white, bold: true, fontFace: JP, fontSize: opts.hsize || 12.5, align: "left", valign: "middle" } })));
  rows.forEach((r, ri) => {
    body.push(r.map((c, ci) => ({
      text: c,
      options: {
        fill: { color: ri % 2 ? P.softer : P.white },
        color: ci === 0 ? P.primary : P.ink,
        bold: ci === 0,
        fontFace: JP, fontSize: opts.size || 12, align: "left", valign: "middle",
      },
    })));
  });
  slide.addTable(body, {
    x: MX, y, w: CW, colW, rowH: opts.rowH || 0.42,
    border: { pt: 0.75, color: P.line }, margin: [3, 6, 3, 6], valign: "middle", autoPage: false,
  });
}

function codeBox(slide, code, x, y, w, h) {
  slide.addShape(S.rect, { x, y, w, h, fill: { color: "0A2A44" }, line: { type: "none" } });
  slide.addText(code, { x: x + 0.16, y: y + 0.08, w: w - 0.3, h: h - 0.16, fontFace: MONO, fontSize: 12.5, color: "DCEBFA", margin: 0, valign: "middle" });
}

// 2 点を結ぶ矢印。始点(x1,y1)→終点(x2,y2)。矢頭は終点側。opts.arrow=false で線のみ。
function connect(slide, x1, y1, x2, y2, opts = {}) {
  const x = Math.min(x1, x2), y = Math.min(y1, y2);
  const w = Math.abs(x2 - x1), h = Math.abs(y2 - y1);
  slide.addShape(S.line, {
    x, y, w, h, flipH: x2 < x1, flipV: y2 < y1,
    line: { color: opts.color || P.teal, width: opts.width || 2, endArrowType: opts.arrow === false ? "none" : "triangle" },
  });
}

// 汎用ノード（角丸ボックス + タイトル + 補足）。
function node(slide, x, y, w, h, title, sub, opts = {}) {
  const border = opts.border || P.teal;
  slide.addShape(S.roundRect, { x, y, w, h, rectRadius: 0.06, fill: { color: opts.fill || P.softer }, line: { color: border, width: opts.lw || 1.25 } });
  const ty = sub ? y + 0.08 : y;
  const th = sub ? 0.34 : h;
  slide.addText(title, { x: x + 0.12, y: ty, w: w - 0.24, h: th, fontFace: JP, fontSize: opts.size || 12.5, bold: true, color: opts.color || P.primary, align: "center", valign: "middle", margin: 0 });
  if (sub) slide.addText(sub, { x: x + 0.12, y: y + 0.36, w: w - 0.24, h: h - 0.42, fontFace: JP, fontSize: 10.5, color: P.muted, align: "center", valign: "top", margin: 0 });
}

// ---- 表紙（CFG から描画・変更しない） ------------------------------------
function cover() {
  const s = pptx.addSlide();
  s.background = { color: P.primary };
  s.addShape(S.rect, { x: 0, y: 0, w: 13.33, h: 0.16, fill: { color: P.cyan }, line: { type: "none" } });
  s.addText(CFG.jp, { x: 0.9, y: 1.5, w: 6, h: 0.5, fontFace: JP, fontSize: 18, bold: true, color: P.cyan, charSpacing: 3, margin: 0 });
  s.addText(CFG.title, { x: 0.9, y: 2.05, w: 11.5, h: 1.2, fontFace: JP, fontSize: 44, bold: true, color: P.white, margin: 0 });
  s.addText(CFG.subtitle, { x: 0.9, y: 3.25, w: 11.5, h: 0.5, fontFace: JP, fontSize: 17, color: "BFE6EC", margin: 0 });
  s.addShape(S.line, { x: 0.92, y: 3.95, w: 3.2, h: 0, line: { color: P.cyan, width: 2.5 } });
  let cx = 0.9;
  CFG.chips.forEach((t) => {
    const w = 0.5 + t.length * 0.2;
    s.addShape(S.roundRect, { x: cx, y: 4.35, w, h: 0.5, rectRadius: 0.25, fill: { color: "12508C" }, line: { color: P.cyan, width: 1 } });
    s.addText(t, { x: cx, y: 4.35, w, h: 0.5, fontFace: JP, fontSize: 13, color: P.white, align: "center", valign: "middle", margin: 0 });
    cx += w + 0.25;
  });
  s.addText(CFG.meta, { x: 0.9, y: 6.5, w: 11, h: 0.4, fontFace: JP, fontSize: 12, color: "9FC7D1", margin: 0 });
}

// =========================================================================
// ---- 本文スライド（章ごとに実装する） ------------------------------------
// 下は「表 + 注意喚起 + 出典」の基本形サンプル。実際の内容へ差し替えること。
// header の第2引数(kicker)は小見出し、第3引数はスライドタイトル。
// footer(s, n) の n は「ページ番号」で、表紙が 1 のため本文は 2 から始める。
// =========================================================================

function s01() {
  const s = pptx.addSlide();
  header(s, "01", "小見出し", "スライドタイトルを具体的に書く");
  lead(s, "このスライドで伝える結論や要点を一文で示す。");
  tableAt(s, ["観点", "説明", "例"], [
    ["項目A", "何を決めるか", "具体例"],
    ["項目B", "何を決めるか", "具体例"],
    ["項目C", "何を決めるか", "具体例"],
  ], 2.35, { colW: [3.0, 4.5, 4.59], rowH: 0.6 });
  callout(s, "注意点や判断基準を一文で示す。強調色は結論・注意・選択対象に限定する。", 5.4);
  sources(s, [
    "https://learn.microsoft.com/ja-jp/azure/iot-hub/",
  ]);
  footer(s, 2);
}

// ---- 確認問題スライドの基本形（章末に置く） ------------------------------
function sQuiz() {
  const s = pptx.addSlide();
  header(s, "08", "理解度の確認", "学んだ内容を事例で選び分ける");
  lead(s, "次の場面で、どう判断するか説明してください。");
  const qs = [
    "確認したい観点を問う設問1。",
    "確認したい観点を問う設問2。",
    "確認したい観点を問う設問3。",
    "確認したい観点を問う設問4。",
  ];
  const y = 2.35, h = 0.74, gap = 0.18;
  qs.forEach((q, i) => {
    const yy = y + i * (h + gap);
    s.addShape(S.roundRect, { x: MX, y: yy, w: CW, h, rectRadius: 0.06, fill: { color: P.softer }, line: { color: P.line, width: 1 } });
    s.addShape(S.rect, { x: MX, y: yy, w: 0.09, h, fill: { color: P.teal }, line: { type: "none" } });
    s.addShape(S.oval, { x: MX + 0.28, y: yy + h / 2 - 0.23, w: 0.46, h: 0.46, fill: { color: P.primary }, line: { type: "none" } });
    s.addText(String(i + 1), { x: MX + 0.28, y: yy + h / 2 - 0.23, w: 0.46, h: 0.46, fontFace: JP, fontSize: 16, bold: true, color: P.white, align: "center", valign: "middle", margin: 0 });
    s.addText(q, { x: MX + 1.0, y: yy, w: CW - 1.3, h, fontFace: JP, fontSize: 13, color: P.ink, valign: "middle", margin: 0 });
  });
  callout(s, "次章の予告や、この章のまとめを一文で示す。", 6.05, CW, MX, P.cyan);
  footer(s, 9);
}

// ---- 描画順（章の枚数に合わせて増減する） --------------------------------
cover();
s01();
// s02(); s03(); s04(); s05(); s06(); s07();
sQuiz();

pptx.writeFile({ fileName: CFG.out }).then((f) => console.log("written:", f));
