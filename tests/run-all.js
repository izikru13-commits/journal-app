// Runs every *.test.js file under tests/ as a plain Node script (no build step, no dependencies).
// Each test file exits non-zero on failure, so a failing file fails this whole run.
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

function findTests(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) return findTests(full);
    if (entry.name.endsWith('.test.js')) return [full];
    return [];
  });
}

const testFiles = findTests(__dirname);
let failed = 0;

testFiles.forEach((file) => {
  console.log(`\n--- ${path.relative(__dirname, file)} ---`);
  try {
    execFileSync('node', [file], { stdio: 'inherit' });
  } catch (e) {
    failed++;
  }
});

console.log(failed === 0 ? `\nALL ${testFiles.length} TEST FILES PASSED` : `\n${failed}/${testFiles.length} TEST FILE(S) FAILED`);
process.exit(failed === 0 ? 0 : 1);
