const fs = require('fs');
const vm = require('vm');
const assert = require('assert');
const path = require('path');

const BASE = require('path').resolve(__dirname, '..', '..');
const sandbox = {};
vm.createContext(sandbox);

function load(rel) {
  vm.runInContext(fs.readFileSync(path.join(BASE, rel), 'utf8'), sandbox, { filename: rel });
}

load('js/data/words.js');
load('js/data/categories.js');
load('js/data/sentences.js');
load('js/data/relations.js');
load('js/data/verbs.js');
load('js/data/ladders.js');
load('js/data/emojiWords.js');
load('js/data/idioms.js');
load('js/data/partsOfSpeech.js');
load('js/data/reading.js');
load('js/data/crosswords.js');

const get = (name) => vm.runInContext(name, sandbox);

let failures = 0;
function check(label, fn) {
  try {
    fn();
    console.log('PASS:', label);
  } catch (e) {
    failures++;
    console.log('FAIL:', label, '-', e.message);
  }
}

// ---- categories.js ----
check('CATEGORY_LIST: every category has exactly 4 unique words', () => {
  const CATEGORY_LIST = get('CATEGORY_LIST');
  CATEGORY_LIST.forEach((c) => {
    assert.strictEqual(c.words.length, 4, `${c.id} has ${c.words.length} words`);
    assert.strictEqual(new Set(c.words).size, 4, `${c.id} has duplicate words`);
  });
});
check('CATEGORY_LIST: no word reused across categories within the same band', () => {
  const CATEGORY_LIST = get('CATEGORY_LIST');
  const byBand = {};
  CATEGORY_LIST.forEach((c) => {
    byBand[c.difficulty] = byBand[c.difficulty] || new Set();
    c.words.forEach((w) => {
      assert.ok(!byBand[c.difficulty].has(w), `word ${w} reused within ${c.difficulty}`);
      byBand[c.difficulty].add(w);
    });
  });
});
check('CATEGORY_LIST: at least 6 categories per band, unique ids', () => {
  const CATEGORY_LIST = get('CATEGORY_LIST');
  const counts = {};
  const ids = new Set();
  CATEGORY_LIST.forEach((c) => {
    counts[c.difficulty] = (counts[c.difficulty] || 0) + 1;
    assert.ok(!ids.has(c.id), `duplicate id ${c.id}`);
    ids.add(c.id);
  });
  Object.entries(counts).forEach(([band, n]) => assert.ok(n >= 6, `${band} only has ${n} categories`));
});

// ---- sentences.js ----
check('SENTENCE_BANK: exactly one "___" per template, answer in options exactly once, no dup options, unique ids', () => {
  const SENTENCE_BANK = get('SENTENCE_BANK');
  const ids = new Set();
  SENTENCE_BANK.forEach((s) => {
    const blanks = (s.template.match(/___/g) || []).length;
    assert.strictEqual(blanks, 1, `${s.id} has ${blanks} blanks`);
    const occurrences = s.options.filter((o) => o === s.answer).length;
    assert.strictEqual(occurrences, 1, `${s.id} answer appears ${occurrences} times in options`);
    assert.strictEqual(new Set(s.options).size, s.options.length, `${s.id} has duplicate options`);
    assert.ok(!ids.has(s.id), `duplicate id ${s.id}`);
    ids.add(s.id);
  });
});

// ---- relations.js ----
check('WORD_RELATIONS: word !== related, unique ids, valid type', () => {
  const WORD_RELATIONS = get('WORD_RELATIONS');
  const ids = new Set();
  WORD_RELATIONS.forEach((r) => {
    assert.notStrictEqual(r.word, r.related, `${r.id} word === related`);
    assert.ok(['synonym', 'antonym'].includes(r.type), `${r.id} bad type ${r.type}`);
    assert.ok(!ids.has(r.id), `duplicate id ${r.id}`);
    ids.add(r.id);
  });
});

// ---- verbs.js ----
check('IRREGULAR_VERBS: unique ids, all fields non-empty', () => {
  const IRREGULAR_VERBS = get('IRREGULAR_VERBS');
  const ids = new Set();
  IRREGULAR_VERBS.forEach((v) => {
    ['base', 'past', 'participle', 'translation', 'difficulty'].forEach((f) => assert.ok(v[f], `${v.id} missing ${f}`));
    assert.ok(!ids.has(v.id), `duplicate id ${v.id}`);
    ids.add(v.id);
  });
});

// ---- ladders.js ----
check('WORD_LADDERS: consecutive words equal length, differ by exactly 1 letter', () => {
  const WORD_LADDERS = get('WORD_LADDERS');
  function diffOne(a, b) {
    if (a.length !== b.length) return false;
    let diff = 0;
    for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) diff++;
    return diff === 1;
  }
  WORD_LADDERS.forEach((p) => {
    for (let i = 0; i < p.chain.length - 1; i++) {
      assert.ok(diffOne(p.chain[i], p.chain[i + 1]), `${p.id}: ${p.chain[i]} -> ${p.chain[i + 1]} not a valid single-letter step`);
    }
  });
});

// ---- emojiWords.js ----
check('EMOJI_WORDS: unique ids, non-empty fields', () => {
  const EMOJI_WORDS = get('EMOJI_WORDS');
  const ids = new Set();
  EMOJI_WORDS.forEach((e) => {
    ['emoji', 'word', 'translation', 'difficulty'].forEach((f) => assert.ok(e[f], `${e.id} missing ${f}`));
    assert.ok(!ids.has(e.id), `duplicate id ${e.id}`);
    ids.add(e.id);
  });
});

// ---- idioms.js ----
check('IDIOMS: exactly one "___" each, unique ids', () => {
  const IDIOMS = get('IDIOMS');
  const ids = new Set();
  IDIOMS.forEach((i) => {
    const blanks = (i.idiom.match(/___/g) || []).length;
    assert.strictEqual(blanks, 1, `${i.id} has ${blanks} blanks`);
    assert.ok(!ids.has(i.id), `duplicate id ${i.id}`);
    ids.add(i.id);
  });
});

// ---- partsOfSpeech.js ----
check('POS_WORDS: valid pos values, unique ids', () => {
  const POS_WORDS = get('POS_WORDS');
  const ids = new Set();
  POS_WORDS.forEach((p) => {
    assert.ok(['noun', 'verb', 'adjective'].includes(p.pos), `${p.id} bad pos ${p.pos}`);
    assert.ok(!ids.has(p.id), `duplicate id ${p.id}`);
    ids.add(p.id);
  });
});

// ---- reading.js ----
check('READING_PASSAGES: answerIndex in range, 4 options, unique ids', () => {
  const READING_PASSAGES = get('READING_PASSAGES');
  const ids = new Set();
  READING_PASSAGES.forEach((r) => {
    assert.strictEqual(r.options.length, 4, `${r.id} has ${r.options.length} options`);
    assert.ok(r.answerIndex >= 0 && r.answerIndex < 4, `${r.id} bad answerIndex`);
    assert.ok(!ids.has(r.id), `duplicate id ${r.id}`);
    ids.add(r.id);
  });
});

// ---- crosswords.js ----
check('CROSSWORD_PUZZLES: every across/down answer matches the solution grid, no orphan cells', () => {
  const CROSSWORD_PUZZLES = get('CROSSWORD_PUZZLES');
  CROSSWORD_PUZZLES.forEach((p) => {
    const covered = Array.from({ length: p.size.rows }, () => Array(p.size.cols).fill(false));
    [...p.across.map((w) => ({ ...w, dr: 0, dc: 1 })), ...p.down.map((w) => ({ ...w, dr: 1, dc: 0 }))].forEach((w) => {
      let r = w.row, c = w.col;
      for (let i = 0; i < w.length; i++) {
        const cell = p.solution[r][c];
        assert.strictEqual(cell, w.answer[i], `${p.id} word ${w.answer} mismatch at [${r},${c}]: grid has ${cell}`);
        covered[r][c] = true;
        r += w.dr; c += w.dc;
      }
    });
    for (let r = 0; r < p.size.rows; r++) {
      for (let c = 0; c < p.size.cols; c++) {
        const cell = p.solution[r][c];
        if (cell !== null) {
          assert.ok(covered[r][c], `${p.id}: orphan letter cell at [${r},${c}] not covered by any word`);
        } else {
          assert.ok(!covered[r][c], `${p.id}: word claims null cell at [${r},${c}]`);
        }
      }
    }
  });
});

console.log(failures === 0 ? '\nALL DATA VALIDATORS PASSED' : `\n${failures} VALIDATOR(S) FAILED`);
process.exit(failures === 0 ? 0 : 1);
