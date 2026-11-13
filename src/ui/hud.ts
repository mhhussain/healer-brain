import type { AbilityDef, HeroDef, Unit } from '../sim/types';
import { TIME_LIMIT, DEATH_PENALTY, type World } from '../sim/world';
import { comboOf } from './save';

export function el(tag: string, cls = '', text = '') {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text) e.textContent = text;
  return e;
}

// 'Sister Wren' is Wren, 'Hale Dunmarrow' is Hale.
export const short = (name: string) => (/^(Sister|Old) /.test(name) ? name.split(' ')[1] : name.split(' ')[0]);

export const fmtTime = (s: number) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, '0')}`;

export function abilityMeta(ab: AbilityDef, hero: HeroDef) {
  const parts: string[] = [];
  if (ab.cost) parts.push(`${ab.cost} ${hero.resName.toLowerCase()}`);
  parts.push(ab.cast ? `${ab.cast} s cast` : 'instant');
  if (ab.cd) parts.push(`${ab.cd >= 60 ? ab.cd / 60 + ' min' : ab.cd + ' s'} cooldown`);
  if (ab.offGcd) parts.push('any time');
  if (ab.target !== 'self') parts.push(ab.range && ab.range < 5 ? 'melee' : '30 m');
  return parts.join(' · ');
}

interface Frame { root: HTMLElement; hp: HTMLElement; shield: HTMLElement; txt: HTMLElement; res: HTMLElement; auras: HTMLElement; last: string }
interface Button { root: HTMLElement; cd: HTMLElement; num: HTMLElement; key: HTMLElement }

// How the player's abilities are bound. clicks: ability id -> click combo on a party frame, for healers.
export interface Binds { clicks: Record<string, string> | null; label: (abilityId: string) => string }

export class Hud {
  root = el('div', 'hud');
  frameHover = -1;
  private frames: Frame[] = [];
  private buttons: Button[] = [];
  private timer = el('div', 'timer');
  private timerFill = el('div', 'fill');
  private progress = el('div', 'progress');
  private target = el('div', 'target');
  private tName = el('div', 'tname');
  private tHp = el('div', 'fill');
  private tCast = el('div', 'tcast');
  private tCastFill = el('div', 'fill');
  private tCastName = el('span');
  private tAim = el('div', 'taim');
  private tAuras = el('div', 'auras');
  private tLast = '';
  private alerts = el('div', 'alerts');
  private error = el('div', 'error');
  private cast = el('div', 'castbar');
  private castFill = el('div', 'fill');
  private castName = el('span');
  private selfHp = el('div', 'fill');
  private selfHpTxt = el('span');
  private selfRes = el('div', 'fill');
  private selfResTxt = el('span');
  private combo = el('div', 'combo');
  private tip = el('div', 'tooltip');

  constructor(parent: HTMLElement, private world: World, private binds: Binds) {
    parent.append(this.root);
    const p = world.player, def = p.hero!;

    const run = el('div', 'runbar');
    const bar = el('div', 'bar');
    bar.append(this.timerFill);
    run.append(el('div', 'level', `Level ${world.level}`), this.timer, bar, this.progress);
    this.root.append(run);

    // a click on a frame casts the spell bound to that click; anything else is left for the mouse bindings
    const clickCast = (e: MouseEvent, allyId: number) => {
      e.preventDefault();
      if (!this.binds.clicks) return;
      const combo = comboOf(e);
      const idx = def.abilities.findIndex((a) => this.binds.clicks![a.id] === combo);
      if (idx < 0) return;
      e.stopPropagation();
      world.press(idx, allyId);
    };
    const hoverable = (root: HTMLElement, id: number) => {
      root.addEventListener('mouseenter', () => (this.frameHover = id));
      root.addEventListener('mouseleave', () => { if (this.frameHover === id) this.frameHover = -1; });
      root.addEventListener('mousedown', (e) => clickCast(e, id));
    };

    const party = el('div', 'party');
    for (const h of world.heroes) {
      const root = el('div', 'frame' + (h.isPlayer ? ' me' : ''));
      const name = el('div', 'fname', h.hero!.name + (h.isPlayer ? ' (you)' : ''));
      name.style.color = h.hero!.color;
      const hpBar = el('div', 'bar hp'), hp = el('div', 'fill'), shield = el('div', 'shield'), txt = el('span');
      hpBar.append(hp, shield, txt);
      const resBar = el('div', 'bar res'), res = el('div', 'fill');
      res.style.background = h.hero!.resColor;
      resBar.append(res);
      const auras = el('div', 'auras');
      root.append(name, hpBar, resBar, auras);
      hoverable(root, h.id);
      party.append(root);
      this.frames.push({ root, hp, shield, txt, res, auras, last: '' });
    }

    const tBar = el('div', 'bar hp');
    tBar.append(this.tHp);
    this.tCast.append(this.tCastFill, this.tCastName);
    const tHead = el('div', 'thead');
    tHead.append(this.tName, this.tAim);
    this.target.append(tHead, tBar, this.tCast, this.tAuras);
    this.root.append(this.alerts);

    // Bottom of the screen, from the top down: your frame and the target's, the party, the action bar.
    const bottom = el('div', 'bottom');
    this.cast.append(this.castFill, this.castName);
    const self = el('div', 'self');
    const selfHead = el('div', 'fname', def.name);
    selfHead.style.color = def.color;
    if (def.id === 'duelist') selfHead.append(this.combo);
    const hpBar = el('div', 'bar hp');
    hpBar.append(this.selfHp, this.selfHpTxt);
    const resBar = el('div', 'bar res');
    this.selfRes.style.background = def.resColor;
    resBar.append(this.selfRes, this.selfResTxt);
    self.append(selfHead, hpBar, resBar);
    hoverable(self, p.id);
    const mid = el('div', 'mid');
    mid.append(this.error, this.cast);
    const units = el('div', 'units');
    units.append(self, mid, this.target);
    const actions = el('div', 'actions');
    def.abilities.forEach((ab, i) => {
      const root = el('div', 'ability');
      const cd = el('div', 'cd'), num = el('div', 'num'), key = el('div', 'key', this.binds.label(ab.id));
      root.append(key, el('div', 'aname', ab.name), cd, num);
      root.addEventListener('mousedown', (e) => { if (e.button !== 0) return; e.preventDefault(); e.stopPropagation(); world.press(i); });
      root.addEventListener('mouseenter', () => {
        this.tip.innerHTML = '';
        this.tip.append(el('b', '', ab.name), el('div', 'meta', abilityMeta(ab, def)), el('div', '', ab.desc));
        this.tip.style.display = 'block';
      });
      root.addEventListener('mouseleave', () => (this.tip.style.display = 'none'));
      actions.append(root);
      this.buttons.push({ root, cd, num, key });
    });
    bottom.append(this.tip, units, party, actions);
    this.root.append(bottom);
  }

  // Bindings changed in the pause menu.
  relabel() {
    this.world.player.hero!.abilities.forEach((ab, i) => (this.buttons[i].key.textContent = this.binds.label(ab.id)));
  }

  update() {
    const w = this.world, p = w.player;

    const t = w.totalTime();
    this.timer.textContent = `${fmtTime(t)} / ${fmtTime(TIME_LIMIT)}`;
    this.timer.classList.toggle('over', t > TIME_LIMIT);
    this.timerFill.style.width = Math.min(100, (t / TIME_LIMIT) * 100) + '%';
    this.timerFill.classList.toggle('over', t > TIME_LIMIT);
    const packs = w.packs.filter((k) => !k.def.boss), bosses = w.packs.filter((k) => k.def.boss);
    const next = w.nextPack();
    this.progress.textContent =
      `Rooms ${packs.filter((k) => k.cleared).length}/${packs.length} · Lamps ${bosses.filter((k) => k.cleared).length}/${bosses.length}` +
      ` · Falls ${w.deaths}${w.deaths ? ` (+${w.deaths * DEATH_PENALTY} s)` : ''}` +
      (next ? ` · Next: ${next.def.name}` : '');

    w.heroes.forEach((h, i) => {
      const f = this.frames[i];
      f.root.classList.toggle('dead', !h.alive);
      f.hp.style.width = (h.hp / h.maxHp) * 100 + '%';
      f.hp.classList.toggle('low', h.hp / h.maxHp < 0.35);
      const shield = h.auras.reduce((n, a) => n + (a.absorb ?? 0), 0);
      f.shield.style.width = Math.min(100, (shield / h.maxHp) * 100) + '%';
      f.txt.textContent = h.alive ? `${Math.ceil(h.hp)}` : 'Down';
      f.res.style.width = (h.res / h.resMax) * 100 + '%';
      const key = h.auras.filter((a) => a.dur < 100).map((a) => `${a.id}:${Math.ceil(a.t)}`).join(',');
      if (key !== f.last) {
        f.last = key;
        f.auras.innerHTML = '';
        for (const a of h.auras) {
          if (a.dur >= 100) continue;
          f.auras.append(el('span', a.dispellable ? 'aura dispel' : a.debuff ? 'aura debuff' : 'aura', `${a.name} ${Math.ceil(a.t)}`));
        }
      }
      f.root.classList.toggle('needs-dispel', h.auras.some((a) => a.dispellable));
    });

    const tg = w.unit(p.targetId);
    const show = !!tg && tg.alive && tg.team === 'enemy';
    this.target.style.visibility = show ? 'visible' : 'hidden';
    if (show) this.updateTarget(tg!);

    const alert = w.alerts[w.alerts.length - 1];
    this.alerts.textContent = alert ? alert.text : '';
    this.alerts.style.opacity = alert ? String(Math.min(1, (3.5 - alert.t) / 0.8)) : '0';
    this.error.textContent = w.error ? w.error.text : '';

    const c = p.cast;
    this.cast.style.visibility = c ? 'visible' : 'hidden';
    if (c) {
      this.castFill.style.width = (c.t / c.total) * 100 + '%';
      this.castName.textContent = `${c.name} ${(c.total - c.t).toFixed(1)}`;
    }
    this.selfHp.style.width = (p.hp / p.maxHp) * 100 + '%';
    this.selfHp.classList.toggle('low', p.hp / p.maxHp < 0.35);
    this.selfHpTxt.textContent = `${Math.ceil(p.hp)} / ${p.maxHp}`;
    this.selfRes.style.width = (p.res / p.resMax) * 100 + '%';
    this.selfResTxt.textContent = `${Math.floor(p.res)} ${p.hero!.resName}`;
    if (p.hero!.id === 'duelist') this.combo.textContent = '●'.repeat(p.combo) + '○'.repeat(5 - p.combo);

    this.buttons.forEach((b, i) => {
      const s = w.abilityState(p, i);
      b.cd.style.height = s.cd > 0 ? Math.min(100, (s.cd / s.cdMax) * 100) + '%' : '0';
      b.num.textContent = s.cd > 1.5 ? String(Math.ceil(s.cd)) : '';
      b.root.classList.toggle('dim', !s.usable);
    });
  }

  private updateTarget(t: Unit) {
    this.tName.textContent = `${t.name} · ${Math.ceil((t.hp / t.maxHp) * 100)}%`;
    this.tHp.style.width = (t.hp / t.maxHp) * 100 + '%';
    const aim = this.world.unit(t.targetId);
    this.tAim.textContent = t.engaged && aim && aim.alive ? `After ${aim.isPlayer ? 'you' : short(aim.name)}` : 'At their post';
    this.tAim.classList.toggle('loose', t.engaged && !!aim && aim.alive && aim.hero?.role !== 'tank');
    // what is on it and for how long; yours are marked
    const me = this.world.player.id;
    const key = t.id + '|' + t.auras.map((a) => `${a.id}:${a.dur < 100 ? Math.ceil(a.t) : ''}`).join(',');
    if (key !== this.tLast) {
      this.tLast = key;
      this.tAuras.innerHTML = '';
      for (const a of [...t.auras].sort((a, b) => Number(b.srcId === me) - Number(a.srcId === me))) {
        const cls = a.debuff ? 'aura debuff' + (a.srcId === me ? ' mine' : '') : 'aura buff';
        this.tAuras.append(el('span', cls, a.dur < 100 ? `${a.name} ${Math.ceil(a.t)}` : a.name));
      }
    }
    const c = t.cast;
    this.tCast.style.visibility = c ? 'visible' : 'hidden';
    if (c) {
      this.tCastFill.style.width = (c.t / c.total) * 100 + '%';
      this.tCast.classList.toggle('kickable', !!c.interruptible);
      this.tCastName.textContent = c.name + (c.interruptible ? '' : ' (cannot be silenced)');
    }
  }
}
