import type { AbilityDef, HeroDef, Unit } from '../sim/types';
import { TIME_LIMIT, DEATH_PENALTY, type World } from '../sim/world';
import { comboOf } from './save';

export function el(tag: string, cls = '', text = '') {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text) e.textContent = text;
  return e;
}

export const fmtTime = (s: number) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, '0')}`;

export function abilityMeta(ab: AbilityDef, hero: HeroDef) {
  const parts: string[] = [];
  if (ab.cost) parts.push(`${ab.cost} ${hero.resName.toLowerCase()}`);
  parts.push(ab.cast ? `${ab.cast} s cast` : 'instant');
  if (ab.cd) parts.push(`${ab.cd >= 60 ? ab.cd / 60 + ' min' : ab.cd + ' s'} cooldown`);
  if (ab.offGcd) parts.push('off GCD');
  if (ab.target !== 'self') parts.push(ab.range && ab.range < 5 ? 'melee' : '30 m');
  return parts.join(' · ');
}

interface Frame { root: HTMLElement; hp: HTMLElement; shield: HTMLElement; txt: HTMLElement; res: HTMLElement; auras: HTMLElement; last: string }
interface Button { root: HTMLElement; cd: HTMLElement; num: HTMLElement }

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

  // bindings: ability id -> click combo, for healers; null otherwise
  constructor(parent: HTMLElement, private world: World, private bindings: Record<string, string> | null) {
    parent.append(this.root);
    const p = world.player, def = p.hero!;

    const run = el('div', 'runbar');
    const bar = el('div', 'bar');
    bar.append(this.timerFill);
    run.append(el('div', 'level', `Level ${world.level}`), this.timer, bar, this.progress);
    this.root.append(run);

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
      root.addEventListener('mouseenter', () => (this.frameHover = h.id));
      root.addEventListener('mouseleave', () => { if (this.frameHover === h.id) this.frameHover = -1; });
      root.addEventListener('mousedown', (e) => {
        e.preventDefault();
        if (!this.bindings) return;
        const combo = comboOf(e);
        const idx = def.abilities.findIndex((a) => this.bindings![a.id] === combo);
        if (idx >= 0) world.press(idx, h.id);
      });
      party.append(root);
      this.frames.push({ root, hp, shield, txt, res, auras, last: '' });
    }
    this.root.append(party);

    const tBar = el('div', 'bar hp');
    tBar.append(this.tHp);
    this.tCast.append(this.tCastFill, this.tCastName);
    this.target.append(this.tName, tBar, this.tCast);
    this.root.append(this.target, this.alerts);

    const bottom = el('div', 'bottom');
    this.cast.append(this.castFill, this.castName);
    const self = el('div', 'self');
    const hpBar = el('div', 'bar hp');
    hpBar.append(this.selfHp, this.selfHpTxt);
    const resBar = el('div', 'bar res');
    this.selfRes.style.background = def.resColor;
    resBar.append(this.selfRes, this.selfResTxt);
    self.append(hpBar, resBar);
    const actions = el('div', 'actions');
    def.abilities.forEach((ab, i) => {
      const root = el('div', 'ability');
      const cd = el('div', 'cd'), num = el('div', 'num');
      root.append(el('div', 'key', String(i + 1)), el('div', 'aname', ab.name), cd, num);
      root.addEventListener('mousedown', (e) => { e.preventDefault(); world.press(i); });
      root.addEventListener('mouseenter', () => {
        this.tip.innerHTML = '';
        this.tip.append(el('b', '', ab.name), el('div', 'meta', abilityMeta(ab, def)), el('div', '', ab.desc));
        this.tip.style.display = 'block';
      });
      root.addEventListener('mouseleave', () => (this.tip.style.display = 'none'));
      actions.append(root);
      this.buttons.push({ root, cd, num });
    });
    bottom.append(this.tip, this.error, this.cast, this.combo, self, actions);
    this.root.append(bottom);
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
      `Packs ${packs.filter((k) => k.cleared).length}/${packs.length} · Bosses ${bosses.filter((k) => k.cleared).length}/${bosses.length}` +
      ` · Deaths ${w.deaths}${w.deaths ? ` (+${w.deaths * DEATH_PENALTY} s)` : ''}` +
      (next ? ` · Next: ${next.def.name}` : '');

    w.heroes.forEach((h, i) => {
      const f = this.frames[i];
      f.root.classList.toggle('dead', !h.alive);
      f.hp.style.width = (h.hp / h.maxHp) * 100 + '%';
      f.hp.classList.toggle('low', h.hp / h.maxHp < 0.35);
      const shield = h.auras.reduce((n, a) => n + (a.absorb ?? 0), 0);
      f.shield.style.width = Math.min(100, (shield / h.maxHp) * 100) + '%';
      f.txt.textContent = h.alive ? `${Math.ceil(h.hp)}` : 'Dead';
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
    this.target.style.display = show ? 'block' : 'none';
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
    this.tName.textContent = `${t.name} — ${Math.ceil((t.hp / t.maxHp) * 100)}%`;
    this.tHp.style.width = (t.hp / t.maxHp) * 100 + '%';
    const c = t.cast;
    this.tCast.style.visibility = c ? 'visible' : 'hidden';
    if (c) {
      this.tCastFill.style.width = (c.t / c.total) * 100 + '%';
      this.tCast.classList.toggle('kickable', !!c.interruptible);
      this.tCastName.textContent = c.name + (c.interruptible ? '' : ' (cannot be interrupted)');
    }
  }
}
