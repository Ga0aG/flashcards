// Vercel Serverless Function: 给日语句子叠加 furigana。
// 用 kuroshiro + kuroshiro-analyzer-kuromoji，纯本地分词，无 API key。
// 输入: POST { "text": "日本語の文章" }
// 输出: 200 { "text": "日本語(にほんご)の文章" }
// 失败: 4xx/5xx 含 { "error": "..." }，前端会降级为原句。

const path = require('path');
const Kuroshiro = require('kuroshiro').default;
const KuromojiAnalyzer = require('kuroshiro-analyzer-kuromoji');

// kuromoji 需要一个目录路径来加载 .dat.gz 字典。
// 这个包在 node_modules 内的 dict 目录就是字典所在地。
const dictPath = path.dirname(require.resolve('kuromoji/package.json')) + '/dict';

let kuroshiroPromise = null;
function getKuroshiro() {
  if (kuroshiroPromise) return kuroshiroPromise;
  const k = new Kuroshiro();
  kuroshiroPromise = k.init(new KuromojiAnalyzer({ dictPath })).then(() => k);
  return kuroshiroPromise;
}

const KANJI_RE = /[一-鿿㐀-䶿]/;

module.exports = async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'method not allowed' });
    return;
  }
  try {
    const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : (req.body || {});
    const text = typeof body.text === 'string' ? body.text : '';
    if (!text.trim()) {
      res.status(400).json({ error: 'missing text' });
      return;
    }
    if (!KANJI_RE.test(text)) {
      res.status(200).json({ text });
      return;
    }
    const k = await getKuroshiro();
    // mode='okurigana' 输出: 食(た)べる、漢字(かんじ)
    const out = await k.convert(text, { to: 'hiragana', mode: 'okurigana' });
    res.status(200).json({ text: out || text });
  } catch (err) {
    console.error('[furigana] error', err);
    res.status(500).json({ error: 'internal error' });
  }
};
