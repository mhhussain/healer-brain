import './style.css';
import { DPS, HEALERS, HEROES, TANKS } from './sim/heroes';
import { DT, TIME_LIMIT, World } from './sim/world';
import { Hud, abilityMeta, el, fmtTime } from './ui/hud';
import { Renderer } from './ui/render';
import { COMBOS, comboLabel, loadSave, storeSave, type Save } from './ui/save';

const app = document.getElementById('app')!;
const save: Save = loadSave();
const params = new URLSearchParams(location.search);
const SLOTS = [
  { label: 'Tank', options: TANKS },
  { label: 'Healer', options: HEALERS },
  { label: 'Damage', options: DPS },
  { label: 'Damage', options: DPS },
];

function button(text: string, cls: string, onClick: () => void) {
  const b = el('button', cls, text);
  b.addEventListener('click', onClick);
  return b;
}

// Click-to-cast editor for a healer's ally spells.
function bindingsEditor(heroId: string) {
  const def = HEROES[heroId];
  const map = save.bindings[heroId];
  const box = el('div', 'bindings');
  box.append(el('h3', '', 'Click-to-cast on party frames'));
  for (const ab of def.abilities) {
    if (ab.target !== 'ally') continue;
    const row = el('label', 'bind-row');
    const sel = document.createElement('select');
    for (const c of ['', ...COMBOS]) {
      const o = document.createElement('option');
      o.value = c;
      o.textContent = c ? comboLabel(c) : 'Not bound';
      sel.append(o);
    }
    sel.value = map[ab.id] ?? '';
    sel.addEventListener('change', () => {
      for (const k in map) if (map[k] === sel.value) delete map[k];
      if (sel.value) map[ab.id] = sel.value; else delete map[ab.id];
      storeSave(save);
      box.replaceWith(bindingsEditor(heroId));
    });
    row.append(el('span', '', ab.name), sel);
    box.append(row);
  }
  return box;
}

function showSetup() {
  app.innerHTML = '';
  const root = el('div', 'screen setup');
  const head = el('header');
  head.append(el('h1', '', 'Fourfold'), el('p', 'tag', 'Fourteen minutes of low tide. Three lamps to light. Pick who you play; the other three look after themselves.'));
  root.append(head);

  const party = el('div', 'slots');
  SLOTS.forEach((slot, i) => {
    const card = el('div', 'slot' + (save.slot === i ? ' mine' : ''));
    card.append(el('div', 'slot-label', slot.label));
    const opts = el('div', 'opts');
    for (const id of slot.options) {
      const def = HEROES[id];
      const b = button(def.name, 'opt' + (save.party[i] === id ? ' on' : ''), () => { save.party[i] = id; storeSave(save); showSetup(); });
      b.style.setProperty('--c', def.color);
      opts.append(b);
    }
    card.append(opts, el('div', 'sub', `${HEROES[save.party[i]].title} · ${HEROES[save.party[i]].sub}`));
    card.append(button(save.slot === i ? 'You play this hero' : 'Play this hero', 'play' + (save.slot === i ? ' on' : ''), () => { save.slot = i; storeSave(save); showSetup(); }));
    party.append(card);
  });
  root.append(party);

  const cols = el('div', 'cols');
  const def = HEROES[save.party[save.slot]];
  const kit = el('section', 'kit');
  const title = el('h2', '', def.name);
  title.style.color = def.color;
  kit.append(title, el('p', 'how', def.howTo));
  def.abilities.forEach((ab, i) => {
    const row = el('div', 'kit-row');
    const body = el('div');
    body.append(el('b', '', ab.name), el('span', 'meta', abilityMeta(ab, def)), el('div', '', ab.desc));
    row.append(el('div', 'key', String(i + 1)), body);
    kit.append(row);
  });
  const best = save.bests[def.id];
  kit.append(el('p', 'best', best ? `Best with ${def.name}: level ${best.level} in ${fmtTime(best.time)}` : `No timed run with ${def.name} yet.`));
  cols.append(kit);

  const side = el('section', 'side');
  side.append(el('h3', '', 'Level'));
  save.level = Math.min(save.level, save.unlocked);
  const levels = el('div', 'levels');
  for (let l = 1; l <= save.unlocked; l++) {
    levels.append(button(String(l), 'lvl' + (l === save.level ? ' on' : ''), () => { save.level = l; storeSave(save); showSetup(); }));
  }
  side.append(levels, el('p', 'note', 'Each level gives enemies 8% more health and damage. They gain new abilities at levels 3, 6 and 9. Beat the 14:00 timer to unlock the next level.'));
  side.append(el('h3', '', 'Controls'));
  const controls = el('ul', 'controls');
  const lines = [
    'A D — move along the hall · W S — move in depth',
    'Space — jump (just for fun)',
    'Tab or left click — target an enemy',
    '1–6 — abilities',
    def.role === 'healer' ? 'Heals land on the ally under the mouse, or on you' : 'Enemy abilities with no target use the tank\'s target',
    'Esc — clear target, then pause · P — pause',
  ];
  for (const l of lines) controls.append(el('li', '', l));
  side.append(controls);
  if (def.role === 'healer') side.append(bindingsEditor(def.id));
  side.append(button(`Descend into the Drowned Abbey · level ${save.level}`, 'start', () => startRun(save.level)));
  cols.append(side);
  root.append(cols);
  app.append(root);
}

function startRun(level: number) {
  app.innerHTML = '';
  const autoplay = params.has('autoplay');
  const speed = Number(params.get('speed') ?? 1);
  const world = new World({ level, party: [...save.party], playerSlot: save.slot, autoplay });
  const root = el('div', 'game');
  const canvas = document.createElement('canvas');
  root.append(canvas);
  app.append(root);
  const renderer = new Renderer(canvas);
  const heroId = world.player.hero!.id;
  const hud = new Hud(root, world, world.player.hero!.role === 'healer' ? save.bindings[heroId] : null);
  renderer.resize();
  // ?debug exposes the run to the console and to browser tests.
  if (params.has('debug')) Object.assign(window, { fourfold: { world, renderer } });

  const ac = new AbortController();
  const on = { signal: ac.signal };
  const keys = new Set<string>();
  let hoverId = -1;
  let paused = false;
  let overlay: HTMLElement | null = null;
  let raf = 0;

  const end = () => { ac.abort(); cancelAnimationFrame(raf); };

  const setPaused = (p: boolean) => {
    paused = p;
    overlay?.remove();
    overlay = null;
    if (!p) return;
    keys.clear();
    overlay = el('div', 'overlay');
    const panel = el('div', 'panel');
    panel.append(el('h2', '', 'Paused'));
    if (world.player.hero!.role === 'healer') panel.append(bindingsEditor(heroId));
    panel.append(
      button('Resume', 'start', () => setPaused(false)),
      button('Abandon run', 'ghost', () => { end(); showSetup(); }),
    );
    overlay.append(panel);
    root.append(overlay);
  };

  window.addEventListener('resize', () => renderer.resize(), on);
  window.addEventListener('blur', () => keys.clear(), on);
  window.addEventListener('contextmenu', (e) => e.preventDefault(), on);
  window.addEventListener('keyup', (e) => keys.delete(e.code), on);
  window.addEventListener('keydown', (e) => {
    if (e.code === 'Tab' || e.code === 'Space') e.preventDefault();
    if (e.repeat) return;
    if (e.code === 'KeyP') return setPaused(!paused);
    if (e.code === 'Escape') {
      if (paused) setPaused(false);
      else if (world.player.targetId >= 0) world.player.targetId = -1;
      else setPaused(true);
      return;
    }
    if (paused) return;
    keys.add(e.code);
    if (e.code === 'Tab') world.tabTarget();
    if (e.code === 'Space') world.jump();
    const m = /^Digit([1-6])$/.exec(e.code);
    if (m) world.press(Number(m[1]) - 1);
  }, on);

  const unitAt = (px: number, py: number) => {
    const rect = canvas.getBoundingClientRect();
    return renderer.pick(world, px - rect.left, py - rect.top);
  };
  canvas.addEventListener('mousemove', (e) => (hoverId = unitAt(e.clientX, e.clientY)), on);
  canvas.addEventListener('mouseleave', () => (hoverId = -1), on);
  canvas.addEventListener('mousedown', (e) => {
    if (e.button !== 0 || paused) return;
    const u = world.unit(unitAt(e.clientX, e.clientY));
    if (u && u.team === 'enemy') world.player.targetId = u.id;
  }, on);

  let last = performance.now(), acc = 0;
  const frame = (now: number) => {
    const real = Math.min(0.1, (now - last) / 1000);
    last = now;
    if (!paused) {
      world.input.mx = (keys.has('KeyD') ? 1 : 0) - (keys.has('KeyA') ? 1 : 0);
      world.input.my = (keys.has('KeyS') ? 1 : 0) - (keys.has('KeyW') ? 1 : 0);
      const hover = world.unit(hoverId);
      world.hoverAllyId = hud.frameHover >= 0 ? hud.frameHover : hover && hover.team === 'hero' ? hover.id : -1;
      acc += real * speed;
      while (acc >= DT) { world.tick(DT); acc -= DT; }
    }
    renderer.draw(world, hoverId);
    hud.update();
    if (world.finished) { end(); showSummary(world); return; }
    raf = requestAnimationFrame(frame);
  };
  raf = requestAnimationFrame(frame);
}

function showSummary(world: World) {
  const t = world.totalTime();
  const timed = world.timed();
  const hero = world.player.hero!;
  let unlockedNow = false;
  if (timed && !world.autoplay) {
    if (world.level >= save.unlocked) { save.unlocked = world.level + 1; unlockedNow = true; }
    const b = save.bests[hero.id];
    if (!b || world.level > b.level || (world.level === b.level && t < b.time)) save.bests[hero.id] = { level: world.level, time: t };
    storeSave(save);
  }

  app.innerHTML = '';
  const root = el('div', 'screen summary');
  root.append(el('h1', timed ? 'good' : 'bad', timed ? `Level ${world.level} timed` : `Level ${world.level} completed over time`));
  root.append(el('p', 'tag',
    `${fmtTime(t)} against ${fmtTime(TIME_LIMIT)} · ${world.deaths} death${world.deaths === 1 ? '' : 's'}` +
    (unlockedNow ? ` · Level ${world.level + 1} unlocked` : '')));

  const table = el('table');
  const headRow = el('tr');
  for (const h of ['Hero', 'Damage', 'Per second', 'Healing', 'Interrupts', 'Dispels', 'Deaths']) headRow.append(el('th', '', h));
  table.append(headRow);
  for (const h of world.heroes) {
    const row = el('tr', h.isPlayer ? 'me' : '');
    const name = el('td', '', h.hero!.name + (h.isPlayer ? ' (you)' : ''));
    name.style.color = h.hero!.color;
    row.append(name);
    const s = h.stats;
    for (const v of [s.dmg, s.dmg / Math.max(1, world.elapsed), s.heal, s.interrupts, s.dispels, s.deaths]) {
      row.append(el('td', '', Math.round(v).toLocaleString()));
    }
    table.append(row);
  }
  root.append(table);

  const actions = el('div', 'row');
  if (timed) actions.append(button(`Level ${world.level + 1}`, 'start', () => { save.level = world.level + 1; storeSave(save); startRun(save.level); }));
  actions.append(
    button('Run it again', timed ? 'ghost' : 'start', () => startRun(world.level)),
    button('Party setup', 'ghost', showSetup),
  );
  root.append(actions);
  app.append(root);
}

// ?autostart skips the setup screen; with ?autoplay the AI also plays your hero (for demos and checks).
if (params.has('autostart')) startRun(Math.min(save.level, save.unlocked));
else showSetup();
