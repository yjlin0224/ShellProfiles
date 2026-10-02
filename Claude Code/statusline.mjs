#!/usr/bin/env node
// Claude Code status line: line 1 shows session info, line 2 shows git info (omitted outside a git repo)
import { spawnSync } from 'node:child_process';
import { basename } from 'node:path';
import { pathToFileURL } from 'node:url';

const CYAN = '\x1b[36m', GREEN = '\x1b[32m', YELLOW = '\x1b[33m', RED = '\x1b[31m', RESET = '\x1b[0m';
const SEP = ' | ';

// OSC 8 clickable link
const link = (url, text) => `\x1b]8;;${url}\x07${text}\x1b]8;;\x07`;

const EFFORT = { low: 'Low', medium: 'Medium', high: 'High', xhigh: 'XHigh', max: 'Max' };

// 10-cell bar: floor(x / 10) full blocks, then one cell picked by x mod 10 (░ ▒ ▓ █)
function bar(pct) {
  const x = Math.min(100, Math.max(0, pct));
  const color = x >= 90 ? RED : x >= 70 ? YELLOW : GREEN;
  if (x >= 100) return color + '█'.repeat(10) + RESET;
  const full = Math.floor(x / 10);
  const y = x - full * 10;
  const partial = y < 2.5 ? '░' : y < 5 ? '▒' : y < 7.5 ? '▓' : '█';
  return color + '█'.repeat(full) + partial + '░'.repeat(9 - full) + RESET;
}

const percent = (pct) => `${bar(pct)} ${Math.round(pct)}%`;

function git(dir, ...args) {
  const r = spawnSync('git', ['-C', dir, ...args], { encoding: 'utf8', windowsHide: true });
  return r.stdout ? r.stdout.trim().split('\n') : [];
}

function gitInfo(dir) {
  // One call: inside-work-tree flag, full HEAD hash, branch name ("HEAD" when detached)
  const out = git(dir, 'rev-parse', '--is-inside-work-tree', 'HEAD', '--abbrev-ref', 'HEAD');
  if (out[0] !== 'true') return null;
  const hash = out.find((l) => /^[0-9a-f]{40,64}$/.test(l));
  let branch = out.at(-1);
  if (!hash) branch = git(dir, 'symbolic-ref', '--short', '-q', 'HEAD')[0]; // unborn branch (no commits yet)
  else if (branch === 'HEAD') branch = 'detached';
  return { branch, hash: hash?.slice(0, 8) };
}

let input = '';
process.stdin.on('data', (c) => (input += c));
process.stdin.on('end', () => {
  const d = JSON.parse(input);

  const dir = d.workspace?.current_dir ?? d.cwd;

  const line1 = [];
  if (dir) line1.push(`📁 ${link(pathToFileURL(dir).href, basename(dir))}`);
  const model = d.model?.display_name;
  if (model) {
    const effort = d.effort?.level;
    line1.push(`✨ ${CYAN}${model}${effort ? ' ' + (EFFORT[effort] ?? effort) : ''}${RESET}`);
  }
  const ctx = d.context_window?.used_percentage;
  if (ctx != null) line1.push(`📜 ${percent(ctx)}`);
  const fiveHour = d.rate_limits?.five_hour?.used_percentage;
  if (fiveHour != null) line1.push(`⛽ ${percent(fiveHour)}`);

  const lines = [line1.join(SEP)];

  const g = dir && gitInfo(dir);
  if (g) {
    const line2 = [];
    const repo = d.workspace?.repo;
    if (repo?.owner && repo?.name) {
      const slug = `${repo.owner}/${repo.name}`;
      line2.push(`📦 ${link(`https://${repo.host}/${slug}`, slug)}`);
    }
    if (g.branch) line2.push(`🌿 ${g.branch}`);
    if (g.hash) line2.push(`🔖 ${g.hash}`);
    if (line2.length) lines.push(line2.join(SEP));
  }

  process.stdout.write(lines.join('\n') + '\n');
});
