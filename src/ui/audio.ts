import { TIME_LIMIT, type SimEvent, type World } from '../sim/world';

// Every sound in the game is synthesised here with Web Audio: there are no audio files.
// Music is scheduled a bar at a time from the state of the run, so it follows the fight.

const BEAT = 0.8;
const BAR = BEAT * 4;
const mf = (n: number) => 440 * Math.pow(2, (n - 69) / 12);

interface Chord { root: number; tri: number[] }
// D minor. The Infirmary's progression ends on a major dominant, which keeps it uneasy.
const PROG: Chord[][] = [
  [{ root: 38, tri: [50, 53, 57] }, { root: 34, tri: [46, 50, 53] }, { root: 41, tri: [48, 53, 57] }, { root: 36, tri: [48, 52, 55] }],
  [{ root: 38, tri: [50, 53, 57] }, { root: 43, tri: [46, 50, 55] }, { root: 34, tri: [46, 50, 53] }, { root: 33, tri: [45, 49, 52] }],
  [{ root: 38, tri: [50, 53, 57] }, { root: 34, tri: [46, 50, 53] }, { root: 41, tri: [48, 53, 57] }, { root: 36, tri: [48, 52, 55] }],
];
const BELL_PARTIALS = [[0.5, 0.6, 1.4], [1, 1, 1], [1.19, 0.45, 0.8], [1.56, 0.25, 0.6], [2, 0.3, 0.5], [2.51, 0.15, 0.35], [4.1, 0.06, 0.2]];
// the note each kind of drowned monk sings while casting
const CAST_NOTE: Record<string, number> = { hexer: 57, shaman: 60, hatchling: 69, velisse: 55, sulmar: 45 };

const FIRE = new Set(['firebolt', 'ignite', 'burst']);
const SHOT = new Set(['quickshot', 'piercing', 'volley', 'jarring']);
const SWING = new Set(['strike', 'sweep', 'slash', 'whirl', 'thrust', 'jab', 'bash']);
const GUARD = new Set(['brace', 'ward', 'bark', 'bramble', 'ember', 'riposte', 'tumble', 'unbreakable']);
const SURGE = new Set(['sanctuary', 'tide', 'bloodrush', 'hawk', 'kindled', 'bloom']);

interface CastVoice { gain: GainNode; stop: () => void; t: number; total: number; hide: boolean; tolls: number }

export class Sound {
  volume = 0.6;
  muted = false;
  private ac: AudioContext | null = null;
  private master!: GainNode;
  private music!: GainNode;
  private sfx!: GainNode;
  private wet!: GainNode;
  private surf!: GainNode;
  private noiseBuf!: AudioBuffer;
  private nextBar = 0;
  private bar = 0;
  private gates = new Map<string, number>();
  private voices = new Map<number, CastVoice>();
  private lastAlert: unknown = null;
  private timers = { drip: 2, gull: 5, creak: 8, heart: 1 };
  // what the last frame saw, for the bar scheduler
  private state = { zone: 0, combat: false, boss: -1, lit: 0, late: 0, menu: true };

  get ready() { return !!this.ac; }

  // Browsers only allow sound after a click or key press, so this is called from one.
  unlock() {
    if (this.ac) { void this.ac.resume(); return; }
    const AC = (globalThis as { AudioContext?: typeof AudioContext }).AudioContext;
    if (!AC) return;
    const ac = (this.ac = new AC());
    const comp = ac.createDynamicsCompressor();
    comp.connect(ac.destination);
    this.master = ac.createGain();
    this.master.connect(comp);
    this.music = ac.createGain();
    this.music.gain.value = 0.9;
    this.sfx = ac.createGain();
    this.music.connect(this.master);
    this.sfx.connect(this.master);
    // a long stone room for everything to ring in
    const rev = ac.createConvolver();
    const n = Math.floor(ac.sampleRate * 3.2), imp = ac.createBuffer(2, n, ac.sampleRate);
    for (let ch = 0; ch < 2; ch++) {
      const d = imp.getChannelData(ch);
      for (let i = 0; i < n; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / n, 2.8);
    }
    rev.buffer = imp;
    this.wet = ac.createGain();
    this.wet.gain.value = 0.5;
    this.wet.connect(rev);
    rev.connect(this.master);
    this.noiseBuf = ac.createBuffer(1, ac.sampleRate * 2, ac.sampleRate);
    const nd = this.noiseBuf.getChannelData(0);
    for (let i = 0; i < nd.length; i++) nd[i] = Math.random() * 2 - 1;
    // the sea: looped noise that swells and falls
    const src = ac.createBufferSource();
    src.buffer = this.noiseBuf;
    src.loop = true;
    const lp = ac.createBiquadFilter();
    lp.type = 'lowpass';
    lp.frequency.value = 520;
    const swell = ac.createGain();
    swell.gain.value = 0.6;
    const lfo = ac.createOscillator(), depth = ac.createGain();
    lfo.frequency.value = 0.11;
    depth.gain.value = 0.4;
    lfo.connect(depth);
    depth.connect(swell.gain);
    this.surf = ac.createGain();
    this.surf.gain.value = 0;
    src.connect(lp); lp.connect(swell); swell.connect(this.surf); this.surf.connect(this.master);
    src.start(); lfo.start();
    this.nextBar = ac.currentTime + 0.15;
    this.apply();
  }

  setVolume(v: number) { this.volume = Math.max(0, Math.min(1, v)); this.apply(); }
  setMuted(m: boolean) { this.muted = m; this.apply(); }
  private apply() {
    if (this.ac) this.master.gain.setTargetAtTime(this.muted ? 0 : this.volume, this.ac.currentTime, 0.05);
  }

  // ---------- building blocks

  private gate(name: string, ms: number) {
    const now = performance.now();
    if (now - (this.gates.get(name) ?? -1e9) < ms) return false;
    this.gates.set(name, now);
    return true;
  }

  private env(t: number, attack: number, dur: number, vol: number, dest: AudioNode, wet = 0) {
    const g = this.ac!.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.linearRampToValueAtTime(vol, t + attack);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    g.connect(dest);
    if (wet > 0) { const w = this.ac!.createGain(); w.gain.value = wet; g.connect(w); w.connect(this.wet); }
    return g;
  }

  private osc(type: OscillatorType, f: number, t: number, dur: number, dest: AudioNode, f2 = 0, detune = 0) {
    const o = this.ac!.createOscillator();
    o.type = type;
    o.frequency.setValueAtTime(f, t);
    if (f2) o.frequency.exponentialRampToValueAtTime(f2, t + dur);
    o.detune.value = detune;
    o.connect(dest);
    o.start(t);
    o.stop(t + dur + 0.05);
    return o;
  }

  private noise(t: number, dur: number, vol: number, type: BiquadFilterType, f1: number, f2 = 0, q = 1, wet = 0, dest: AudioNode = this.sfx) {
    const ac = this.ac!;
    const src = ac.createBufferSource();
    src.buffer = this.noiseBuf;
    const flt = ac.createBiquadFilter();
    flt.type = type;
    flt.Q.value = q;
    flt.frequency.setValueAtTime(f1, t);
    if (f2) flt.frequency.exponentialRampToValueAtTime(f2, t + dur);
    src.connect(flt);
    flt.connect(this.env(t, 0.005, dur, vol, dest, wet));
    src.start(t, Math.random());
    src.stop(t + dur + 0.05);
  }

  private bell(t: number, f: number, vol: number, long = 1, dest: AudioNode = this.music) {
    for (const [ratio, amp, decay] of BELL_PARTIALS) {
      const d = 3.2 * decay * long;
      this.osc('sine', f * ratio, t, d, this.env(t, 0.004, d, vol * amp, dest, 0.5));
    }
  }

  private pad(t: number, f: number, dur: number, vol: number, cut: number, dest: AudioNode = this.music) {
    const ac = this.ac!;
    const lp = ac.createBiquadFilter();
    lp.type = 'lowpass';
    lp.frequency.value = cut;
    const g = ac.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.linearRampToValueAtTime(vol, t + dur * 0.35);
    g.gain.linearRampToValueAtTime(0.0001, t + dur);
    lp.connect(g); g.connect(dest);
    const w = ac.createGain(); w.gain.value = 0.4; g.connect(w); w.connect(this.wet);
    this.osc('sawtooth', f, t, dur, lp, 0, -8);
    this.osc('sawtooth', f, t, dur, lp, 0, 7);
  }

  // One voice of the drowned choir: a sawtooth pair sung through a vowel-shaped filter.
  private choir(t: number, f: number, dur: number, vol: number) {
    const ac = this.ac!;
    const bp = ac.createBiquadFilter();
    bp.type = 'bandpass';
    bp.frequency.value = 760;
    bp.Q.value = 1.6;
    const g = ac.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.linearRampToValueAtTime(vol, t + dur * 0.3);
    g.gain.setValueAtTime(vol, t + dur * 0.75);
    g.gain.linearRampToValueAtTime(0.0001, t + dur);
    bp.connect(g); g.connect(this.music);
    const w = ac.createGain(); w.gain.value = 0.7; g.connect(w); w.connect(this.wet);
    for (const d of [-9, 0, 8]) {
      const o = this.osc('sawtooth', f, t, dur, bp, 0, d);
      const vib = ac.createOscillator(), depth = ac.createGain();
      vib.frequency.value = 4.6 + d * 0.03;
      depth.gain.value = 5;
      vib.connect(depth); depth.connect(o.detune);
      vib.start(t); vib.stop(t + dur + 0.05);
    }
  }

  private thump(t: number, vol: number, dest: AudioNode = this.music) {
    this.osc('sine', 82, t, 0.28, this.env(t, 0.004, 0.3, vol, dest), 38);
  }

  // ---------- music

  private scheduleBar(t: number) {
    const s = this.state;
    const ch = PROG[s.zone][this.bar % 4];
    const pick = <T>(a: T[]) => a[Math.floor(Math.random() * a.length)];
    const fight = s.combat && !s.menu;
    this.pad(t, mf(ch.root), BAR + 0.8, fight ? 0.07 : 0.1, s.zone === 1 ? 260 : 340);
    this.pad(t, mf(ch.root + 7), BAR + 0.8, 0.04, 340);
    if (!fight) {
      // wandering: a bell or two, wherever they fall
      const n = s.zone === 1 ? 1 : 1 + Math.floor(Math.random() * 2);
      for (let i = 0; i < n; i++) this.bell(t + Math.floor(Math.random() * 4) * BEAT + Math.random() * 0.06, mf(pick(ch.tri) + (Math.random() < 0.6 ? 12 : 24)), 0.085);
      if (s.zone === 2 && s.lit < 3) this.choir(t, mf(ch.tri[0]), BAR + 0.4, 0.02);
    } else {
      // a fight: a running figure in the bells and a drum underneath
      const order = [0, 1, 2, 1, 0, 2, 1, 2];
      for (let i = 0; i < 8; i++) this.bell(t + i * BEAT * 0.5, mf(ch.tri[order[i]] + 12), i % 4 ? 0.028 : 0.05, 0.3);
      this.bell(t, mf(pick(ch.tri) + 24), 0.07);
      const boss = s.boss >= 0;
      for (let i = 0; i < 4; i++) {
        if (boss || i % 2 === 0) this.thump(t + i * BEAT, boss ? 0.34 : 0.26);
        this.noise(t + i * BEAT + BEAT * 0.5, 0.07, 0.03, 'highpass', 5000, 0, 1, 0, this.music);
      }
      if (boss) {
        // the choir sings for its keeper, and has lost a voice for every lamp already lit
        const voices = Math.max(1, 3 - s.boss);
        this.choir(t, mf(ch.root + 12), BAR + 0.3, 0.075);
        if (voices >= 2) this.choir(t, mf(ch.tri[1]), BAR + 0.3, 0.06);
        if (voices >= 3) {
          this.choir(t, mf(ch.tri[2] + 12), BAR * 0.5 + 0.2, 0.05);
          this.choir(t + BAR * 0.5, mf(ch.tri[0] + 24), BAR * 0.5 + 0.2, 0.05);
        }
      }
    }
    // the tide bell: one low stroke a bar once the water is coming back
    if (s.late > 0 && !s.menu) this.bell(t, mf(50), 0.1 + 0.08 * s.late, 0.8);
    this.bar++;
  }

  // Called every frame. zone is where the player stands; world is null on the menus.
  frame(world: World | null, zone: number, dt: number, paused: boolean) {
    const ac = this.ac;
    if (!ac) return;
    const s = this.state;
    s.menu = !world;
    s.zone = world ? zone : 0;
    if (world) {
      const fightPack = world.packs.find((p) => p.engaged && !p.cleared);
      s.combat = !!fightPack;
      s.boss = fightPack && fightPack.def.boss ? fightPack.def.zone : -1;
      s.lit = world.packs.filter((p) => p.def.boss && p.cleared).length;
      s.late = Math.max(0, Math.min(1, (world.totalTime() - (TIME_LIMIT - 120)) / 120));
    } else {
      s.combat = false; s.boss = -1; s.late = 0;
    }
    if (this.nextBar < ac.currentTime - 1) this.nextBar = ac.currentTime + 0.1;
    while (this.nextBar < ac.currentTime + 0.35) { this.scheduleBar(this.nextBar); this.nextBar += BAR; }
    this.music.gain.setTargetAtTime(paused ? 0.3 : 0.9, ac.currentTime, 0.2);
    this.surf.gain.setTargetAtTime([0.085, 0.03, 0.02][s.zone] + 0.16 * s.late, ac.currentTime, 0.8);
    if (paused) return;

    // small sounds of the place
    const tm = this.timers, now = ac.currentTime + 0.02;
    if ((tm.drip -= dt) <= 0) {
      tm.drip = (s.zone === 0 ? 3 : 1) + Math.random() * 3;
      const f = 900 + Math.random() * 900;
      this.osc('sine', f, now, 0.07, this.env(now, 0.002, 0.09, 0.05, this.sfx, 1.2), f * 0.6);
    }
    if (s.zone === 0 && (tm.gull -= dt) <= 0) {
      tm.gull = 7 + Math.random() * 9;
      for (let i = 0; i < 2 + Math.floor(Math.random() * 2); i++) {
        const t = now + i * 0.32;
        this.osc('sawtooth', 1500 + Math.random() * 200, t, 0.22, this.bandpass(1800, 6, this.env(t, 0.03, 0.24, 0.018, this.sfx, 0.8)), 1050);
      }
    }
    if (s.zone === 2 && (tm.creak -= dt) <= 0) {
      tm.creak = 8 + Math.random() * 9;
      this.osc('sawtooth', 62, now, 0.7, this.bandpass(420, 9, this.env(now, 0.2, 0.75, 0.05, this.sfx, 0.6)), 74);
    }
    if (s.zone === 1 && world && (tm.heart -= dt) <= 0) {
      tm.heart = 1.7;
      this.thump(now, 0.1, this.sfx);
      this.thump(now + 0.3, 0.06, this.sfx);
    }
    if (world) this.castVoices(world, dt);
  }

  private bandpass(f: number, q: number, dest: AudioNode) {
    const bp = this.ac!.createBiquadFilter();
    bp.type = 'bandpass';
    bp.frequency.value = f;
    bp.Q.value = q;
    bp.connect(dest);
    return bp;
  }

  // An enemy's cast is a sung note that swells until it lands. Silencing it cuts the note off.
  private castVoices(world: World, dt: number) {
    const ac = this.ac!;
    for (const e of world.enemies) {
      const c = e.alive ? e.cast : null;
      const v = this.voices.get(e.id);
      if (c && !v && c.total >= 1 && this.voices.size < 4) {
        const hide = !!c.ab?.hide;
        const g = ac.createGain();
        g.gain.setValueAtTime(0.0001, ac.currentTime);
        g.gain.exponentialRampToValueAtTime(hide ? 0.05 : 0.085, ac.currentTime + c.total);
        const bp = this.bandpass(hide ? 500 : 880, 2.2, g);
        g.connect(this.sfx);
        const w = ac.createGain(); w.gain.value = 0.8; g.connect(w); w.connect(this.wet);
        const f = mf(CAST_NOTE[e.enemy!.id] ?? 52);
        const oscs = [-10, 9].map((d) => { const o = ac.createOscillator(); o.type = 'sawtooth'; o.frequency.value = f; o.detune.value = d; o.connect(bp); o.start(); return o; });
        this.voices.set(e.id, { gain: g, stop: () => oscs.forEach((o) => o.stop(ac.currentTime + 0.3)), t: 0, total: c.total, hide, tolls: 0 });
      } else if (c && v) {
        v.t = c.t;
        // The Last Toll: the great bell, struck harder each time
        if (v.hide && c.t >= v.tolls * 1.2) { v.tolls++; this.bell(ac.currentTime, mf(38), 0.2 + 0.07 * v.tolls, 1.2, this.sfx); }
      } else if (!c && v) {
        v.gain.gain.cancelScheduledValues(ac.currentTime);
        v.gain.gain.setTargetAtTime(0, ac.currentTime, 0.03);
        v.stop();
        if (v.hide && v.t + dt * 4 >= v.total) {
          this.bell(ac.currentTime, mf(26), 0.6, 1.6, this.sfx);
          this.bell(ac.currentTime, mf(38), 0.45, 1.6, this.sfx);
          this.noise(ac.currentTime, 1.2, 0.3, 'lowpass', 900, 120, 1, 0.8);
        }
        this.voices.delete(e.id);
      }
    }
    for (const [id, v] of this.voices) {
      if (world.unit(id)) continue;
      v.gain.gain.setTargetAtTime(0, ac.currentTime, 0.03);
      v.stop();
      this.voices.delete(id);
    }
  }

  // Leaving a run: stop anything that is tied to it.
  hush() {
    if (!this.ac) return;
    for (const v of this.voices.values()) { v.gain.gain.setTargetAtTime(0, this.ac.currentTime, 0.03); v.stop(); }
    this.voices.clear();
    this.lastAlert = null;
  }

  // ---------- effects

  events(world: World, evs: SimEvent[]) {
    const ac = this.ac;
    if (!ac) return;
    const t = ac.currentTime + 0.01;
    for (const e of evs) {
      const u = e.id != null ? world.unit(e.id) : null, src = e.src != null ? world.unit(e.src) : null;
      if (e.k === 'hit' && u && (e.amt ?? 0) > 0) {
        if (u.team === 'hero') {
          const big = e.amt! / u.maxHp;
          if (this.gate('hurt', big > 0.15 ? 60 : 140)) {
            this.osc('sine', 150, t, 0.16, this.env(t, 0.003, 0.18, Math.min(0.4, 0.1 + big * 0.9) * (u.isPlayer ? 1 : 0.7), this.sfx), 60);
            this.noise(t, 0.08, 0.07, 'lowpass', 700);
          }
        } else if (this.gate('hit', src?.isPlayer ? 60 : 110)) {
          const vol = src?.isPlayer ? 0.12 : 0.06;
          if (e.s === 'magic') this.noise(t, 0.12, vol, 'bandpass', 1400, 500, 2);
          else { this.noise(t, 0.05, vol, 'lowpass', 1200); this.osc('triangle', 190, t, 0.08, this.env(t, 0.002, 0.09, vol, this.sfx), 110); }
        }
      } else if (e.k === 'heal' && (e.amt ?? 0) >= 40 && this.gate('heal', 90)) {
        // glass chimes, higher for bigger heals
        const f = mf(74 + Math.min(12, Math.round((e.amt! / 420) * 7)));
        const vol = (src?.isPlayer ? 0.1 : 0.05) * (e.amt! >= 200 ? 1 : 0.6);
        this.bell(t, f, vol, 0.25, this.sfx);
        if (e.amt! >= 200) this.bell(t + 0.07, f * 1.5, vol * 0.7, 0.25, this.sfx);
      } else if (e.k === 'death' && u) {
        if (u.team === 'hero') {
          this.bell(t, mf(53), 0.22, 0.7, this.sfx);
          this.bell(t + 0.3, mf(50), 0.22, 0.9, this.sfx);
        } else if (this.gate('rest', 120)) {
          // a sigh of bubbles
          const boss = !!u.enemy?.boss;
          this.noise(t, boss ? 1.6 : 0.6, 0.07, 'highpass', 1800, 4200, 1, 0.6);
          for (let i = 0; i < (boss ? 12 : 5); i++) {
            const bt = t + i * 0.07 + Math.random() * 0.05, f = 500 + i * 90 + Math.random() * 200;
            this.osc('sine', f, bt, 0.07, this.env(bt, 0.005, 0.08, 0.06, this.sfx, 0.5), f * 1.6);
          }
        }
      } else if (e.k === 'interrupt') {
        this.osc('square', 520, t, 0.07, this.env(t, 0.002, 0.08, 0.1, this.sfx), 180);
        this.noise(t, 0.05, 0.1, 'highpass', 3000);
      } else if (e.k === 'dispel') {
        [79, 83, 86, 91].forEach((n, i) => this.bell(t + i * 0.05, mf(n), 0.05, 0.2, this.sfx));
      } else if (e.k === 'ability' && u && e.s) {
        const vol = u.isPlayer ? 1 : 0.45;
        if (FIRE.has(e.s) && this.gate('fire', 80)) {
          this.noise(t, 0.35, 0.12 * vol, 'bandpass', 500, 2600, 1.5, 0.3);
          for (let i = 0; i < 4; i++) this.noise(t + 0.05 + Math.random() * 0.25, 0.02, 0.06 * vol, 'highpass', 4000);
        } else if (SHOT.has(e.s) && this.gate('shot', 80)) {
          this.osc('sawtooth', 240, t, 0.12, this.env(t, 0.002, 0.14, 0.09 * vol, this.sfx), 150);
          this.noise(t + 0.09, 0.05, 0.1 * vol, 'lowpass', 500);
        } else if (SWING.has(e.s) && this.gate('swing', 80)) {
          this.noise(t, 0.11, 0.1 * vol, 'bandpass', 2400, 900, 1.2);
        } else if (e.s === 'challenge') {
          // the pilot's hail: a fog horn
          for (const d of [-6, 6]) this.osc('sawtooth', mf(50), t, 0.55, this.bandpass(360, 1.5, this.env(t, 0.06, 0.6, 0.14 * vol, this.sfx, 0.7)), 0, d);
        } else if (GUARD.has(e.s) && this.gate('guard', 80)) {
          this.osc('sine', 520, t, 0.3, this.env(t, 0.02, 0.32, 0.07 * vol, this.sfx, 0.6), 1040);
          this.osc('sine', 780, t, 0.3, this.env(t, 0.02, 0.32, 0.04 * vol, this.sfx, 0.6), 1560);
        } else if (SURGE.has(e.s)) {
          [62, 65, 69, 74].forEach((n, i) => this.bell(t + i * 0.06, mf(n), 0.09 * vol, 0.6, this.sfx));
        } else if (e.s === 'rebuke') {
          this.bell(t, mf(69), 0.05 * vol, 0.15, this.sfx);
        }
      } else if (e.k === 'engage' && e.id != null) {
        const boss = world.packs[e.id].def.boss;
        this.thump(t, boss ? 0.5 : 0.3, this.sfx);
        if (boss) { this.bell(t, mf(38), 0.3, 1.4, this.sfx); this.choir(t, mf(50), 2.4, 0.08); }
      } else if (e.k === 'clear' && e.id != null && world.packs[e.id].def.boss) {
        this.lampLit();
      } else if (e.k === 'wipe') {
        [57, 53, 50, 45].forEach((n, i) => this.bell(t + i * 0.35, mf(n), 0.16, 0.8, this.sfx));
      } else if (e.k === 'boom' && this.gate('boom', 120)) {
        this.osc('sine', 110, t, 0.3, this.env(t, 0.004, 0.32, 0.22, this.sfx), 40);
        this.noise(t, 0.3, 0.1, 'lowpass', 1600, 300, 1, 0.4);
      }
    }
    // boss warnings: the great bell
    const alert = world.alerts[world.alerts.length - 1];
    if (alert && alert !== this.lastAlert) {
      this.lastAlert = alert;
      if (!evs.some((e) => e.k === 'clear' || e.k === 'wipe') && this.gate('toll', 400)) this.bell(t, mf(38), 0.32, 1.3, this.sfx);
    }
  }

  // A lamp is lit: the key turns major for a moment.
  lampLit() {
    if (!this.ac) return;
    const t = this.ac.currentTime + 0.05;
    [50, 54, 57, 62, 66, 69, 74].forEach((n, i) => this.bell(t + i * 0.14, mf(n), 0.14, 1.1, this.sfx));
    for (const n of [38, 50, 54, 57]) this.pad(t, mf(n), 5, 0.07, 900, this.sfx);
  }

  finale(timed: boolean) {
    if (!this.ac) return;
    const t = this.ac.currentTime + 0.3;
    const notes = timed ? [50, 57, 62, 66, 69, 74, 78] : [50, 57, 62, 65, 69, 74];
    notes.forEach((n, i) => this.bell(t + i * 0.28, mf(n), 0.13, 1.4, this.sfx));
    for (const n of timed ? [38, 50, 54, 57] : [38, 50, 53, 57]) this.pad(t, mf(n), 8, 0.06, 800, this.sfx);
  }

  ui(kind: 'click' | 'error' | 'start') {
    if (!this.ac) return;
    const t = this.ac.currentTime + 0.005;
    if (kind === 'click' && this.gate('ui', 40)) {
      // a knuckle on wood
      this.osc('sine', 330, t, 0.05, this.env(t, 0.002, 0.06, 0.12, this.sfx), 190);
      this.noise(t, 0.02, 0.05, 'bandpass', 1800, 0, 2);
    } else if (kind === 'error' && this.gate('err', 250)) {
      this.osc('sine', 140, t, 0.1, this.env(t, 0.003, 0.12, 0.14, this.sfx), 90);
    } else if (kind === 'start') {
      this.bell(t, mf(50), 0.25, 1.3, this.sfx);
      this.bell(t + 0.5, mf(57), 0.16, 1.1, this.sfx);
    }
  }
}

export const sound = new Sound();
