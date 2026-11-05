'use strict';
/*
 * engram live graph for Obsidian.
 *
 * Shows Claude Code's work on the vault as activity in the graph view: a note Claude reads
 * or writes ignites and keeps glowing while Claude works, signals run along its links, a note
 * a search only found glows faintly, the rest of the graph dims, and when Claude finishes its
 * turn everything fades out slowly.
 *
 * The engram Claude Code plugin has a hook (hooks/live.sh) that appends one JSON line per
 * touched note, and one per finished turn, to live.jsonl in this plugin's folder. This
 * plugin creates that file while it is enabled (the file is also the hook's switch), reads
 * new lines from it and removes it when it is disabled. Nothing goes over the network.
 *
 * The graph renderer is internal to Obsidian and undocumented (checked on 1.15, PIXI 7).
 * Every call into it is guarded: where it differs, the plugin stays dark instead of
 * breaking the graph. Plain CommonJS, no build step.
 */

const obsidian = require('obsidian');
const { Plugin, PluginSettingTab, Setting, Notice } = obsidian;
const fs = require('fs');
const fsp = fs.promises;
const nodePath = require('path');

const LOG = 'live.jsonl';
const PLUGIN_DIR = '.obsidian/plugins/engram-live';
const POLL_MS = 120;
const TRUNCATE_AT = 256 * 1024;
const RISE_MS = 700; // the graph dims in this long when work starts
const IGNITE_MS = 600; // a note brightens in this long
const FADE_HOLD_MS = 1200; // pause between Claude finishing and the fade
const BREATH_MS = 2800;
const FIRE_MS = 1400; // the soft wave around a note when it is hit
const LATE_MS = 3000; // events from a session this soon after its stop do not revive it
const RANK = { match: 0, read: 1, write: 2 };
const MATCH_STRENGTH = 0.5; // a search match glows at half the strength of a read

const DEFAULTS = {
  readColor: '#f5b83d',
  writeColor: '#4fd1a5',
  matchColor: '#cfe0ff',
  matches: true,
  fadeSeconds: 6,
  signals: true,
  dim: true,
  dimPercent: 25,
  counter: true,
  idleMinutes: 3,
};

const STRINGS = {
  en: {
    read: 'notes read',
    written: 'written',
    matched: 'matched in search',
    matchColor: 'Search color',
    matchColorDesc: 'A note a search found but Claude did not open.',
    matches: 'Show search matches',
    matchesDesc: 'Notes whose lines a search returned (the Grep tool, or grep and rg in the shell) glow faintly.',
    reset: 'Reset the live graph',
    wrongDir: 'engram live graph: install it in .obsidian/plugins/engram-live, or Claude Code\'s hook cannot find it.',
    readColor: 'Read color',
    readColorDesc: 'A note Claude reads.',
    writeColor: 'Write color',
    writeColorDesc: 'A note Claude edits or creates.',
    fade: 'Fade out',
    fadeDesc: 'Seconds the lit notes take to fade after Claude finishes.',
    signals: 'Signals along links',
    signalsDesc: 'While Claude works, sparks run from lit notes along their links. Only lit notes count as touched.',
    dim: 'Dim the other notes',
    dimDesc: 'While Claude works, notes it has not touched fall back.',
    dimPercent: 'Brightness of the other notes',
    dimPercentDesc: 'Percent, while dimmed.',
    counter: 'Counter',
    counterDesc: 'Shows how many notes Claude read, out of all notes in the vault.',
    idle: 'Fade without a finish signal after',
    idleDesc: 'Minutes without Claude touching a note, for turns that end without a finish signal (for example when interrupted).',
  },
  tr: {
    read: 'okunan not',
    written: 'yazılan',
    matched: 'aramada eşleşti',
    matchColor: 'Arama rengi',
    matchColorDesc: 'Bir aramanın bulduğu ama Claude\'un açmadığı not.',
    matches: 'Arama eşleşmelerini göster',
    matchesDesc: 'Bir aramanın satırlarını döndürdüğü notlar (Grep aracı ya da kabuktaki grep ve rg) soluk yanar.',
    reset: 'Canlı grafiği sıfırla',
    wrongDir: 'engram live graph: .obsidian/plugins/engram-live klasörüne kurun, yoksa Claude Code\'un hook\'u eklentiyi bulamaz.',
    readColor: 'Okuma rengi',
    readColorDesc: 'Claude\'un okuduğu not.',
    writeColor: 'Yazma rengi',
    writeColorDesc: 'Claude\'un düzenlediği ya da oluşturduğu not.',
    fade: 'Sönme',
    fadeDesc: 'Claude işini bitirince yanan notların kaç saniyede söneceği.',
    signals: 'Bağlantılarda sinyal',
    signalsDesc: 'Claude çalışırken yanan notlardan bağlantıları boyunca kıvılcımlar akar. Dokunulmuş sayılan yalnızca yanan notlardır.',
    dim: 'Diğer notları karart',
    dimDesc: 'Claude çalışırken dokunmadığı notlar geri çekilir.',
    dimPercent: 'Diğer notların parlaklığı',
    dimPercentDesc: 'Yüzde, kararmışken.',
    counter: 'Sayaç',
    counterDesc: 'Kasadaki notların kaçını Claude\'un okuduğunu gösterir.',
    idle: 'Bitiş sinyali gelmezse sönme',
    idleDesc: 'Claude bu kadar dakika hiçbir nota dokunmazsa notlar söner; bitiş sinyali gelmeyen turlar için (örneğin yarıda kesilince).',
  },
};

function language() {
  try {
    const l = typeof obsidian.getLanguage === 'function' ? obsidian.getLanguage() : window.localStorage.getItem('language');
    if (l && String(l).toLowerCase().startsWith('tr')) return 'tr';
  } catch (e) { /* default below */ }
  return 'en';
}

function hexToRgb(hex, fallback) {
  const m = /^#?([0-9a-f]{6})$/i.exec(String(hex || '').trim());
  return m ? parseInt(m[1], 16) : fallback;
}

function mixRgb(a, b, t) {
  const ch = (shift) => Math.round(((a >> shift) & 255) * (1 - t) + ((b >> shift) & 255) * t);
  return (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

function clamp01(x) {
  return x < 0 ? 0 : x > 1 ? 1 : x;
}

function smooth(x) {
  x = clamp01(x);
  return x * x * (3 - 2 * x);
}

function easeOut(x) {
  x = clamp01(x);
  return 1 - Math.pow(1 - x, 3);
}

class EngramLive extends Plugin {
  async onload() {
    this.settings = Object.assign({}, DEFAULTS, await this.loadData());
    this.t = STRINGS[language()];
    this.notes = new Map(); // vault path -> { at, lastAt, kind, read, write, phase }
    this.sessions = new Map(); // session id -> { stoppedAt }
    this.mode = 'idle'; // idle | active | fading
    this.activeSince = 0;
    this.fadeAt = 0;
    this.fadeHold = FADE_HOLD_MS;
    this.fadeMs = 0;
    this.lastAt = 0;
    this.nextSparkAt = 0;
    this.pulses = []; // { r, from, to, start, dur, color }
    this.glows = new Map(); // graph node -> PIXI.Graphics
    this.pulseLayers = new Map(); // renderer -> PIXI.Graphics
    this.patches = [];
    this.counterHosts = new Map();
    this.raf = 0;
    this.pending = Buffer.alloc(0);
    this.offset = 0;
    this.stopped = false;
    this.tick = this.tick.bind(this);
    this.applyColors();

    this.addSettingTab(new LiveSettings(this.app, this));
    this.addCommand({ id: 'reset', name: this.t.reset, callback: () => this.beginFade(performance.now(), 0, 800) });

    const adapter = this.app.vault.adapter;
    if (!adapter || typeof adapter.getBasePath !== 'function') return;
    if (this.manifest.dir !== PLUGIN_DIR) new Notice(this.t.wrongDir, 10000);
    const dir = nodePath.join(adapter.getBasePath(), this.manifest.dir || PLUGIN_DIR);
    this.logPath = nodePath.join(dir, LOG);
    try {
      const ignore = nodePath.join(dir, '.gitignore');
      if (!fs.existsSync(ignore)) await fsp.writeFile(ignore, LOG + '\n');
      await fsp.writeFile(this.logPath, '');
    } catch (e) {
      console.warn('engram live graph: cannot write ' + LOG, e);
      return;
    }

    this.registerInterval(window.setInterval(() => this.poll(), POLL_MS));
    this.registerEvent(this.app.workspace.on('layout-change', () => {
      this.ensurePatched();
      this.updateCounters(performance.now());
    }));
    this.app.workspace.onLayoutReady(() => this.ensurePatched());
  }

  onunload() {
    this.stopped = true;
    if (this.raf) window.cancelAnimationFrame(this.raf);
    this.raf = 0;
    this.clearState();
    this.unpatch();
    for (const r of this.renderers()) this.safe(() => r.changed());
    if (this.logPath) {
      try { fs.unlinkSync(this.logPath); } catch (e) { /* already gone */ }
    }
  }

  async saveSettings() {
    await this.saveData(this.settings);
    this.applyColors();
    this.updateCounters(performance.now());
    this.kick();
  }

  applyColors() {
    this.readRgb = hexToRgb(this.settings.readColor, 0xf5b83d);
    this.writeRgb = hexToRgb(this.settings.writeColor, 0x4fd1a5);
    this.matchRgb = hexToRgb(this.settings.matchColor, 0xcfe0ff);
  }

  colorOf(st) {
    return st.kind === 'write' ? this.writeRgb : st.kind === 'match' ? this.matchRgb : this.readRgb;
  }

  strengthOf(st) {
    return st.kind === 'match' ? MATCH_STRENGTH : 1;
  }

  safe(fn) {
    try { return fn(); } catch (e) { return undefined; }
  }

  // ---- log file --------------------------------------------------------------------

  async poll() {
    if (this.busy || this.stopped) return;
    this.busy = true;
    try {
      let st = null;
      try { st = await fsp.stat(this.logPath); } catch (e) { st = null; }
      if (this.stopped) return;
      if (!st) {
        await fsp.writeFile(this.logPath, '');
        this.offset = 0;
        this.pending = Buffer.alloc(0);
      } else {
        if (st.size < this.offset) {
          this.offset = 0;
          this.pending = Buffer.alloc(0);
        }
        if (st.size > this.offset) {
          const fh = await fsp.open(this.logPath, 'r');
          try {
            const buf = Buffer.alloc(st.size - this.offset);
            const { bytesRead } = await fh.read(buf, 0, buf.length, this.offset);
            this.offset += bytesRead;
            this.consume(buf.subarray(0, bytesRead));
          } finally {
            await fh.close();
          }
        }
        if (this.offset >= TRUNCATE_AT && this.pending.length === 0) {
          const now = await fsp.stat(this.logPath);
          if (now.size === this.offset) {
            await fsp.truncate(this.logPath, 0);
            this.offset = 0;
          }
        }
      }
      this.checkIdle(performance.now());
    } catch (e) {
      /* stay quiet; the next poll tries again */
    } finally {
      this.busy = false;
    }
  }

  consume(chunk) {
    let data = this.pending.length ? Buffer.concat([this.pending, chunk]) : chunk;
    let nl;
    while ((nl = data.indexOf(10)) !== -1) {
      const line = data.subarray(0, nl).toString('utf8').trim();
      data = data.subarray(nl + 1);
      if (line) this.handle(line);
    }
    this.pending = Buffer.from(data);
  }

  handle(line) {
    let ev;
    try { ev = JSON.parse(line); } catch (e) { return; }
    if (!ev || typeof ev !== 'object') return;
    const session = typeof ev.session === 'string' ? ev.session : '';
    if (ev.event === 'stop') {
      this.finish(session, performance.now());
      return;
    }
    if (typeof ev.path !== 'string' || typeof ev.tool !== 'string') return;
    const kind = ev.tool === 'Read' ? 'read'
      : /^(Edit|Write|MultiEdit)$/.test(ev.tool) ? 'write'
      : /^(Grep|Bash)$/.test(ev.tool) && this.settings.matches ? 'match' : null;
    if (!kind) return;
    const path = this.resolve(ev.path);
    if (!path || !/\.md$/i.test(path)) return;
    this.touch(path, kind, session, performance.now());
  }

  resolve(p) {
    const vault = this.app.vault;
    const nfc = p.normalize('NFC');
    for (const c of [p, nfc, p.normalize('NFD')]) {
      const f = vault.getAbstractFileByPath(c);
      if (f) return f.path;
    }
    const lower = nfc.toLowerCase();
    const hit = vault.getMarkdownFiles().find((f) => f.path.normalize('NFC').toLowerCase() === lower);
    return hit ? hit.path : nfc;
  }

  // ---- activity ----------------------------------------------------------------------

  touch(path, kind, session, now) {
    const s = this.sessions.get(session);
    const late = !!(s && s.stoppedAt && now - s.stoppedAt < LATE_MS); // a hook that ran after the stop
    if (late && this.mode === 'idle') return;
    if (!late) {
      if (this.mode === 'idle') {
        this.mode = 'active';
        this.activeSince = now;
        this.nextSparkAt = now + 500;
      } else if (this.mode === 'fading') {
        // Back to work: rise again from wherever the fade got to.
        const level = this.intensity(now);
        this.mode = 'active';
        this.activeSince = now - RISE_MS * level;
      }
      this.sessions.set(session, { stoppedAt: 0 });
    }

    let st = this.notes.get(path);
    if (!st) {
      st = { at: now, lastAt: now, kind, read: false, write: false, match: false, phase: Math.random() * Math.PI * 2 };
      this.notes.set(path, st);
    }
    st[kind] = true;
    // A read or a write outranks a search match; a later match never dims a read note.
    if (RANK[kind] > RANK[st.kind]) st.kind = kind;
    if (RANK[kind] >= RANK[st.kind]) st.lastAt = now;
    this.lastAt = now;

    this.ensurePatched();
    if (this.settings.signals && kind !== 'match') this.fireFrom(path, 6, now);
    this.updateCounters(now);
    this.kick();
  }

  finish(session, now) {
    if (this.mode !== 'active') return;
    const s = this.sessions.get(session);
    if (!s) return; // that session touched no note
    s.stoppedAt = now;
    for (const x of this.sessions.values()) if (!x.stoppedAt) return;
    this.beginFade(now, FADE_HOLD_MS, this.fadeSetting());
  }

  checkIdle(now) {
    const idle = Math.max(0.25, Number(this.settings.idleMinutes) || DEFAULTS.idleMinutes) * 60000;
    if (this.mode === 'active' && now - this.lastAt > idle) this.beginFade(now, 0, this.fadeSetting());
  }

  fadeSetting() {
    return Math.max(0.5, Number(this.settings.fadeSeconds) || DEFAULTS.fadeSeconds) * 1000;
  }

  beginFade(now, hold, ms) {
    if (this.mode === 'idle') return;
    if (this.mode === 'fading') {
      // Already fading: only ever speed it up, never jump back up.
      const left = this.fadeAt + this.fadeHold + this.fadeMs - now;
      if (hold + ms >= left) return;
      const level = this.intensity(now);
      this.activeSince = now - RISE_MS * level;
    }
    this.mode = 'fading';
    this.fadeAt = now;
    this.fadeHold = hold;
    this.fadeMs = ms;
    this.kick();
  }

  // 0 when idle, rises when work starts, 1 while Claude works, falls to 0 after it finishes.
  intensity(now) {
    if (this.mode === 'idle') return 0;
    const up = smooth((now - this.activeSince) / RISE_MS);
    if (this.mode === 'active') return up;
    return up * (1 - smooth((now - this.fadeAt - this.fadeHold) / this.fadeMs));
  }

  // How bright one lit note is, before the overall intensity: ignites, then breathes.
  glowOf(st, now) {
    const ignite = smooth((now - st.at) / IGNITE_MS);
    const breath = 0.88 + 0.12 * Math.sin((now / BREATH_MS) * Math.PI * 2 + st.phase);
    return ignite * breath;
  }

  // A swell each time the note is hit again.
  burstOf(st, now) {
    const t = now - st.lastAt;
    return t < 0 ? 0 : smooth(t / 160) * Math.exp(-t / 700);
  }

  clearState() {
    this.mode = 'idle';
    this.notes.clear();
    this.sessions.clear();
    this.pulses = [];
    for (const g of this.glows.values()) this.destroyGraphics(g);
    this.glows.clear();
    for (const g of this.pulseLayers.values()) this.destroyGraphics(g);
    this.pulseLayers.clear();
    this.removeCounters();
  }

  // ---- animation loop: keeps the graph rendering while anything is lit --------------

  kick() {
    if (!this.stopped && !this.raf) this.raf = window.requestAnimationFrame(this.tick);
  }

  tick() {
    this.raf = 0;
    if (this.stopped) return;
    const now = performance.now();
    if (this.mode === 'fading' && now > this.fadeAt + this.fadeHold + this.fadeMs) {
      this.clearState();
      this.settle = now + 1500; // let Obsidian ease the colors back
    }
    if (this.mode === 'active' && this.settings.signals && now >= this.nextSparkAt) this.spark(now);
    const renderers = this.renderers();
    for (const r of renderers) {
      this.safe(() => r.changed());
      this.safe(() => this.drawPulses(r, now));
    }
    this.pulses = this.pulses.filter((p) => now - p.start < p.dur);
    for (const [r, g] of this.pulseLayers) {
      if (!renderers.includes(r)) {
        this.destroyGraphics(g);
        this.pulseLayers.delete(r);
      }
    }
    for (const [node, g] of this.glows) {
      if (!node.rendered || !this.notes.has(node.id)) {
        this.destroyGraphics(g);
        this.glows.delete(node);
      }
    }
    this.updateCounterOpacity(now);
    if (this.mode !== 'idle' || now < (this.settle || 0)) this.raf = window.requestAnimationFrame(this.tick);
  }

  // ---- signals along links -------------------------------------------------------------

  linksOf(node) {
    const out = [];
    for (const side of [node.forward, node.reverse]) {
      if (!side) continue;
      for (const k of Object.keys(side)) if (side[k]) out.push(side[k]);
    }
    return out;
  }

  fireFrom(path, count, now) {
    for (const r of this.renderers()) {
      const node = r.nodeLookup[path];
      if (!node) continue;
      const links = this.linksOf(node);
      for (let i = links.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [links[i], links[j]] = [links[j], links[i]];
      }
      const st = this.notes.get(path);
      for (const link of links.slice(0, count)) {
        const to = link.source === node ? link.target : link.source;
        if (!to) continue;
        this.pulses.push({
          r, from: node, to,
          start: now + Math.random() * 250,
          dur: 750 + Math.random() * 650,
          color: st ? this.colorOf(st) : this.readRgb,
        });
      }
    }
  }

  // While Claude works, a lit note now and then sends a spark along one or two links.
  spark(now) {
    this.nextSparkAt = now + 280 + Math.random() * 520;
    if (!this.notes.size || this.pulses.length > 60) return;
    const paths = [...this.notes.keys()].filter((p) => this.notes.get(p).kind !== 'match');
    if (!paths.length) return;
    const path = paths[Math.floor(Math.random() * paths.length)];
    this.fireFrom(path, 1 + Math.floor(Math.random() * 2), now);
  }

  pulseLayer(r) {
    let g = this.pulseLayers.get(r);
    if (g && !g.destroyed) return g;
    const sample = r.nodes.find((n) => n && n.circle);
    if (!sample || !r.hanger) return null;
    g = this.newGraphics(sample.circle);
    if (!g) return null;
    r.hanger.addChild(g);
    this.pulseLayers.set(r, g);
    return g;
  }

  drawPulses(r, now) {
    const mine = this.pulses.filter((p) => p.r === r);
    const g = mine.length || this.pulseLayers.has(r) ? this.pulseLayer(r) : null;
    if (!g) return;
    g.clear();
    const level = this.intensity(now);
    const unit = r.nodeScale || 1;
    for (const p of mine) {
      const q = (now - p.start) / p.dur;
      if (q < 0 || q > 1 || !p.from.rendered || !p.to.rendered) continue;
      const fade = Math.sin(Math.PI * q) * level;
      for (let k = 0; k < 6; k++) {
        const qq = smooth(q - k * 0.03);
        if (qq <= 0) continue;
        const x = p.from.x + (p.to.x - p.from.x) * qq;
        const y = p.from.y + (p.to.y - p.from.y) * qq;
        if (k === 0) {
          g.beginFill(p.color, 0.22 * fade);
          g.drawCircle(x, y, 9 * unit);
          g.endFill();
        }
        g.beginFill(p.color, 0.95 * fade * (1 - k * 0.16));
        g.drawCircle(x, y, (4.2 - k * 0.6) * unit);
        g.endFill();
      }
    }
  }

  // ---- graph renderer ----------------------------------------------------------------

  renderers() {
    const out = [];
    for (const type of ['graph', 'localgraph']) {
      for (const leaf of this.app.workspace.getLeavesOfType(type)) {
        const r = leaf.view && leaf.view.renderer;
        if (r && r.nodeLookup && Array.isArray(r.nodes) && typeof r.changed === 'function') out.push(r);
      }
    }
    return out;
  }

  newGraphics(circle) {
    if (!circle || typeof circle.constructor !== 'function') return null;
    const g = new circle.constructor();
    if (typeof g.beginFill !== 'function' || typeof g.drawCircle !== 'function' || typeof g.clear !== 'function') {
      if (typeof g.destroy === 'function') g.destroy();
      return null;
    }
    g.eventMode = 'none';
    const pixi = window.PIXI;
    if (pixi && pixi.BLEND_MODES && pixi.BLEND_MODES.ADD !== undefined) g.blendMode = pixi.BLEND_MODES.ADD;
    return g;
  }

  destroyGraphics(g) {
    this.safe(() => {
      if (g.parent) g.parent.removeChild(g);
      if (!g.destroyed) g.destroy();
    });
  }

  ensurePatched() {
    if (this.stopped) return;
    for (const r of this.renderers()) {
      const node = r.nodes[0];
      if (node) this.safe(() => this.patchNode(Object.getPrototypeOf(node)));
      const link = Array.isArray(r.links) ? r.links[0] : null;
      if (link) this.safe(() => this.patchLink(Object.getPrototypeOf(link)));
    }
  }

  patchNode(proto) {
    if (!proto || this.patches.some((p) => p.proto === proto)) return;
    if (typeof proto.getFillColor !== 'function' || typeof proto.getSize !== 'function' || typeof proto.render !== 'function') return;
    const self = this;
    const orig = { getFillColor: proto.getFillColor, getSize: proto.getSize, render: proto.render };
    const mine = {
      getFillColor: function () {
        const base = orig.getFillColor.apply(this, arguments);
        if (self.stopped || self.mode === 'idle') return base;
        try { return self.fill(this, base); } catch (e) { return base; }
      },
      getSize: function () {
        const base = orig.getSize.apply(this, arguments);
        if (self.stopped || self.mode === 'idle') return base;
        try { return self.size(this, base); } catch (e) { return base; }
      },
      render: function () {
        const out = orig.render.apply(this, arguments);
        if (!self.stopped && self.mode !== 'idle') {
          try { self.afterRender(this); } catch (e) { /* leave the node as Obsidian drew it */ }
        }
        return out;
      },
    };
    Object.assign(proto, mine);
    this.patches.push({ proto, orig, mine });
  }

  patchLink(proto) {
    if (!proto || this.patches.some((p) => p.proto === proto)) return;
    if (typeof proto.render !== 'function') return;
    const self = this;
    const orig = { render: proto.render };
    const mine = {
      render: function () {
        const line = this.line;
        const arrow = this.arrow;
        // Obsidian eases link alpha from its last value, so undo the dimming before it runs.
        if (line && line.engramAlpha !== undefined) line.alpha = line.engramAlpha;
        if (arrow && arrow.engramAlpha !== undefined) arrow.alpha = arrow.engramAlpha;
        const out = orig.render.apply(this, arguments);
        let k = 1;
        if (!self.stopped && self.mode !== 'idle') {
          try { k = self.linkDim(this); } catch (e) { k = 1; }
        }
        for (const g of [line, arrow]) {
          if (!g) continue;
          if (k !== 1) {
            g.engramAlpha = g.alpha;
            g.alpha = Math.min(1, g.alpha * k);
          } else if (g.engramAlpha !== undefined) {
            g.engramAlpha = undefined;
          }
        }
        return out;
      },
    };
    Object.assign(proto, mine);
    this.patches.push({ proto, orig, mine });
  }

  unpatch() {
    for (const { proto, orig, mine } of this.patches) {
      for (const key of Object.keys(orig)) {
        if (proto[key] === mine[key]) proto[key] = orig[key];
      }
    }
    this.patches = [];
  }

  isHovered(node) {
    const r = node.renderer;
    return !!(r && typeof r.getHighlightNode === 'function' && r.getHighlightNode() === node);
  }

  dimOthers(level) {
    return this.settings.dim ? 1 - (1 - clamp01(this.settings.dimPercent / 100)) * level : 1;
  }

  fill(node, base) {
    if (!base || typeof base.rgb !== 'number') return base;
    if (this.isHovered(node)) return base;
    const now = performance.now();
    const level = this.intensity(now);
    if (level <= 0) return base;
    const st = this.notes.get(node.id);
    if (st) {
      const g = clamp01((this.glowOf(st, now) + this.burstOf(st, now)) * level * this.strengthOf(st));
      const a = base.a * this.dimOthers(level);
      return { a: a + (1 - a) * g, rgb: mixRgb(base.rgb, this.colorOf(st), clamp01(g * 1.15)) };
    }
    const d = this.dimOthers(level);
    return d < 1 ? { a: base.a * d, rgb: base.rgb } : base;
  }

  size(node, base) {
    const st = this.notes.get(node.id);
    if (!st) return base;
    const now = performance.now();
    const level = this.intensity(now);
    return base * (1 + (0.3 * this.glowOf(st, now) + 0.45 * this.burstOf(st, now)) * level * this.strengthOf(st));
  }

  // Links of lit notes brighten, the others dim with their notes.
  linkDim(link) {
    const level = this.intensity(performance.now());
    if (level <= 0) return 1;
    const litEnd = (n) => { const st = n && this.notes.get(n.id); return !!st && st.kind !== 'match'; };
    return litEnd(link.source) || litEnd(link.target) ? 1 + 1.2 * level : this.dimOthers(level);
  }

  afterRender(node) {
    if (!node.rendered) return;
    const now = performance.now();
    const level = this.intensity(now);
    const st = this.notes.get(node.id);
    if (!st) {
      const d = this.dimOthers(level);
      if (d < 1 && node.text && node.text.visible) node.text.alpha *= d;
      return;
    }
    this.drawGlow(node, st, now, level);
  }

  // A soft halo behind a lit note, made of stacked translucent circles drawn additively.
  drawGlow(node, st, now, level) {
    const circle = node.circle;
    const r = node.renderer;
    if (!circle || !r || !r.hanger) return;
    let g = this.glows.get(node);
    if (!g || g.destroyed) {
      g = this.newGraphics(circle);
      if (!g) return;
      if (typeof r.hanger.addChildAt === 'function') r.hanger.addChildAt(g, 0);
      else r.hanger.addChild(g);
      this.glows.set(node, g);
    }
    const color = this.colorOf(st);
    const strength = this.strengthOf(st);
    const amount = clamp01(this.glowOf(st, now) + 0.6 * this.burstOf(st, now)) * level * strength;
    const size = node.getSize();
    g.clear();
    g.visible = circle.visible;
    g.x = node.x;
    g.y = node.y;
    g.scale.x = g.scale.y = r.nodeScale || 1;
    for (const [k, a] of [[3.4, 0.035], [2.6, 0.05], [1.95, 0.08], [1.45, 0.13]]) {
      g.beginFill(color, a * amount);
      g.drawCircle(0, 0, size * k);
      g.endFill();
    }
    const t = now - st.lastAt;
    if (t >= 0 && t < FIRE_MS) {
      const q = t / FIRE_MS;
      g.beginFill(color, 0.16 * (1 - q) * (1 - q) * level * strength);
      g.drawCircle(0, 0, size * (1.2 + 3.2 * easeOut(q)));
      g.endFill();
    }
  }

  // ---- counter -----------------------------------------------------------------------

  updateCounters(now) {
    if (this.stopped) return;
    const show = this.settings.counter && this.notes.size > 0;
    const leaves = show ? this.app.workspace.getLeavesOfType('graph') : [];
    const live = new Set();
    for (const leaf of leaves) {
      const host = leaf.view && leaf.view.contentEl;
      if (!host) continue;
      live.add(host);
      let el = this.counterHosts.get(host);
      if (!el || !el.isConnected) {
        if (window.getComputedStyle(host).position === 'static') host.style.position = 'relative';
        el = host.createDiv({ cls: 'engram-live-counter' });
        this.counterHosts.set(host, el);
      }
      this.renderCounter(el);
    }
    for (const [host, el] of this.counterHosts) {
      if (!live.has(host)) {
        el.remove();
        this.counterHosts.delete(host);
      }
    }
    this.updateCounterOpacity(now);
  }

  updateCounterOpacity(now) {
    if (!this.counterHosts.size) return;
    // The counter outlasts the lights a little, then goes with them.
    const o = String(Math.round(clamp01(Math.sqrt(this.intensity(now)) * 1.4) * 100) / 100);
    for (const el of this.counterHosts.values()) if (el.style.opacity !== o) el.style.opacity = o;
  }

  renderCounter(el) {
    let reads = 0;
    let writes = 0;
    let matches = 0;
    for (const st of this.notes.values()) {
      if (st.read) reads++;
      if (st.write) writes++;
      if (st.match) matches++;
    }
    const total = this.app.vault.getMarkdownFiles().length;
    el.style.setProperty('--engram-live-read', this.settings.readColor);
    el.style.setProperty('--engram-live-write', this.settings.writeColor);
    el.style.setProperty('--engram-live-match', this.settings.matchColor);
    el.empty();
    const count = el.createDiv({ cls: 'engram-live-count' });
    count.createSpan({ cls: 'engram-live-reads', text: String(reads) });
    count.createSpan({ cls: 'engram-live-total', text: ' / ' + total });
    const label = el.createDiv({ cls: 'engram-live-label', text: this.t.read });
    if (matches) label.createSpan({ cls: 'engram-live-matches', text: ' · ' + matches + ' ' + this.t.matched });
    if (writes) label.createSpan({ cls: 'engram-live-writes', text: ' · ' + writes + ' ' + this.t.written });
  }

  removeCounters() {
    for (const el of this.counterHosts.values()) el.remove();
    this.counterHosts.clear();
  }
}

class LiveSettings extends PluginSettingTab {
  constructor(app, plugin) {
    super(app, plugin);
    this.plugin = plugin;
  }

  display() {
    const { containerEl, plugin } = this;
    const s = plugin.settings;
    const t = plugin.t;
    const save = () => plugin.saveSettings();
    containerEl.empty();

    new Setting(containerEl).setName(t.readColor).setDesc(t.readColorDesc)
      .addColorPicker((c) => c.setValue(s.readColor).onChange((v) => { s.readColor = v; save(); }));
    new Setting(containerEl).setName(t.writeColor).setDesc(t.writeColorDesc)
      .addColorPicker((c) => c.setValue(s.writeColor).onChange((v) => { s.writeColor = v; save(); }));
    new Setting(containerEl).setName(t.matchColor).setDesc(t.matchColorDesc)
      .addColorPicker((c) => c.setValue(s.matchColor).onChange((v) => { s.matchColor = v; save(); }));
    new Setting(containerEl).setName(t.matches).setDesc(t.matchesDesc)
      .addToggle((c) => c.setValue(s.matches).onChange((v) => { s.matches = v; save(); }));
    new Setting(containerEl).setName(t.fade).setDesc(t.fadeDesc)
      .addSlider((c) => c.setLimits(1, 20, 1).setValue(s.fadeSeconds).setDynamicTooltip()
        .onChange((v) => { s.fadeSeconds = v; save(); }));
    new Setting(containerEl).setName(t.signals).setDesc(t.signalsDesc)
      .addToggle((c) => c.setValue(s.signals).onChange((v) => { s.signals = v; save(); }));
    new Setting(containerEl).setName(t.dim).setDesc(t.dimDesc)
      .addToggle((c) => c.setValue(s.dim).onChange((v) => { s.dim = v; save(); }));
    new Setting(containerEl).setName(t.dimPercent).setDesc(t.dimPercentDesc)
      .addSlider((c) => c.setLimits(5, 90, 5).setValue(s.dimPercent).setDynamicTooltip()
        .onChange((v) => { s.dimPercent = v; save(); }));
    new Setting(containerEl).setName(t.counter).setDesc(t.counterDesc)
      .addToggle((c) => c.setValue(s.counter).onChange((v) => { s.counter = v; save(); }));
    new Setting(containerEl).setName(t.idle).setDesc(t.idleDesc)
      .addSlider((c) => c.setLimits(1, 30, 1).setValue(s.idleMinutes).setDynamicTooltip()
        .onChange((v) => { s.idleMinutes = v; save(); }));
  }
}

module.exports = EngramLive;
