#!/usr/bin/env node
// Claude Code status line: line 1 shows session info, line 2 shows git info (omitted outside a git repo)
import { spawnSync } from 'node:child_process';
import { basename, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const CYAN = '\x1b[36m', GREEN = '\x1b[32m', YELLOW = '\x1b[33m', RED = '\x1b[31m', GRAY = '\x1b[90m', RESET = '\x1b[0m';
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

// Bar plus value; a missing value shows a gray empty bar and N/A
const percent = (pct) =>
  pct != null ? `${bar(pct)} ${Math.round(pct)}%` : `${GRAY}${'░'.repeat(10)}${RESET} N/A`;

function git(dir, ...args) {
  const r = spawnSync('git', ['-C', dir, ...args], { encoding: 'utf8', windowsHide: true });
  return r.status === 0 ? r.stdout.trim() : null;
}

function gitInfo(dir) {
  // Reads refs only (no working-tree scan), so the cost doesn't grow with repo size.
  // --points-at limits the ahead/behind computation to branches at HEAD.
  const out = git(dir, 'for-each-ref', '--points-at=HEAD',
    '--format=%(HEAD)%00%(refname:short)%00%(objectname)%00%(upstream)%00%(upstream:track,nobracket)', 'refs/heads');
  if (out == null) {
    // Not a repo, or an unborn branch (HEAD has no commit yet)
    const branch = git(dir, 'symbolic-ref', '--short', '-q', 'HEAD');
    return branch ? { branch } : null;
  }
  const row = out.split('\n').map((l) => l.split('\0')).find((f) => f[0] === '*');
  if (!row) return { branch: 'detached', hash: git(dir, 'rev-parse', '--short=8', 'HEAD') };
  const [, branch, hash, upstream, track] = row;
  return {
    branch,
    hash: hash.slice(0, 8),
    upstream: !!upstream,
    gone: track === 'gone',
    ahead: Number(/ahead (\d+)/.exec(track)?.[1] ?? 0),
    behind: Number(/behind (\d+)/.exec(track)?.[1] ?? 0),
  };
}

// Branch suffix: "(local)" without upstream, "(gone)" when the upstream ref was pruned, else ↑ahead ↓behind
function syncState(g) {
  if (g.upstream === undefined) return ''; // detached or unborn
  if (!g.upstream) return ` ${GRAY}(local)${RESET}`;
  if (g.gone) return ` ${RED}(gone)${RESET}`;
  return (g.ahead ? ` ${GREEN}↑${g.ahead}${RESET}` : '') + (g.behind ? ` ${YELLOW}↓${g.behind}${RESET}` : '');
}

// Time left until epoch seconds as "Xd Xh Xm", dropping leading zero units
function timeLeft(epoch) {
  const mins = Math.floor((epoch * 1000 - Date.now()) / 60000);
  if (mins < 1) return '<1m';
  const d = Math.floor(mins / 1440), h = Math.floor((mins % 1440) / 60), m = mins % 60;
  return d ? `${d}d ${h}h ${m}m` : h ? `${h}h ${m}m` : `${m}m`;
}

// Home directory from the environment; paths compare case-insensitively on Windows
function isHome(dir) {
  const home = process.env.USERPROFILE ?? process.env.HOME;
  if (!home) return false;
  const norm = (p) => (process.platform === 'win32' ? resolve(p).toLowerCase() : resolve(p));
  return norm(dir) === norm(home);
}

// Repo host and owner/name from the origin remote (https, scp-style git@host:path, or ssh://)
function originRepo(dir) {
  const url = git(dir, 'config', '--get', 'remote.origin.url');
  const m = url && /^(?:[a-z+]+:\/\/)?(?:[^@/]+@)?([^/:]+)(?::\d+)?[:/](.+?)(?:\.git)?\/?$/i.exec(url);
  return m ? { host: m[1], slug: m[2] } : null;
}

let input = '';
process.stdin.on('data', (c) => (input += c));
process.stdin.on('end', () => {
  const d = JSON.parse(input);

  // Launch directory; current_dir follows `cd` inside tool calls
  const dir = d.workspace?.project_dir ?? d.workspace?.current_dir ?? d.cwd;
  const cwdIsLaunchDir = dir === (d.workspace?.current_dir ?? d.cwd);

  const line1 = [];
  if (dir) line1.push(`📁 ${link(pathToFileURL(dir).href, isHome(dir) ? '~' : basename(dir))}`);
  const model = d.model?.display_name;
  if (model) {
    const effort = d.effort?.level;
    line1.push(`✨ ${CYAN}${model}${effort ? ' ' + (EFFORT[effort] ?? effort) : ''}${RESET}`);
  }
  line1.push(`📜 ${percent(d.context_window?.used_percentage)}`);
  // 5-hour usage with bar, 7-day usage and time left until reset in parentheses
  const sevenDay = d.rate_limits?.seven_day;
  let weekly = 'N/A';
  if (sevenDay?.used_percentage != null) {
    weekly = `${Math.round(sevenDay.used_percentage)}%`;
    if (sevenDay.resets_at != null) weekly += ` - ${timeLeft(sevenDay.resets_at)}`;
  }
  line1.push(`⛽ ${percent(d.rate_limits?.five_hour?.used_percentage)} (${weekly})`);

  const lines = [line1.join(SEP)];

  const g = dir && gitInfo(dir);
  if (g) {
    const line2 = [];
    // workspace.repo may follow current_dir, so read origin ourselves once cwd has moved away
    const r = d.workspace?.repo;
    const repo = cwdIsLaunchDir ? (r?.owner && r?.name ? { host: r.host, slug: `${r.owner}/${r.name}` } : null) : originRepo(dir);
    if (repo) line2.push(`📦 ${link(`https://${repo.host}/${repo.slug}`, repo.slug)}`);
    if (g.branch) line2.push(`🌿 ${g.branch}${syncState(g)}`);
    if (g.hash) line2.push(`🔖 ${g.hash}`);
    if (line2.length) lines.push(line2.join(SEP));
  }

  process.stdout.write(lines.join('\n') + '\n');
});
