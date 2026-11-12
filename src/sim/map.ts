import type { Vec } from './types';

export interface Pillar { id: number; x: number; y: number; w: number; h: number; alive: boolean }

// Grid of 1 m cells. Everything is wall until carved.
export class GameMap {
  cells: Uint8Array;
  pillarAt: Int16Array;
  pillars: Pillar[] = [];
  version = 0;
  private g: Float32Array;
  private from: Int32Array;
  private seen: Uint32Array;
  private done: Uint32Array;
  private run = 0;

  constructor(public w: number, public h: number) {
    this.cells = new Uint8Array(w * h).fill(1);
    this.pillarAt = new Int16Array(w * h).fill(-1);
    this.g = new Float32Array(w * h);
    this.from = new Int32Array(w * h);
    this.seen = new Uint32Array(w * h);
    this.done = new Uint32Array(w * h);
  }

  wall(cx: number, cy: number) {
    return cx < 0 || cy < 0 || cx >= this.w || cy >= this.h || this.cells[cy * this.w + cx] === 1;
  }

  carve(x0: number, y0: number, x1: number, y1: number) {
    for (let y = y0; y < y1; y++) for (let x = x0; x < x1; x++) this.cells[y * this.w + x] = 0;
  }

  addPillar(x: number, y: number, w: number, h: number) {
    const id = this.pillars.length;
    this.pillars.push({ id, x, y, w, h, alive: true });
    for (let cy = y; cy < y + h; cy++) for (let cx = x; cx < x + w; cx++) {
      this.cells[cy * this.w + cx] = 1;
      this.pillarAt[cy * this.w + cx] = id;
    }
  }

  destroyPillar(id: number) {
    const p = this.pillars[id];
    if (!p || !p.alive) return;
    p.alive = false;
    for (let cy = p.y; cy < p.y + p.h; cy++) for (let cx = p.x; cx < p.x + p.w; cx++) {
      this.cells[cy * this.w + cx] = 0;
      this.pillarAt[cy * this.w + cx] = -1;
    }
    this.version++;
  }

  restorePillars() {
    for (const p of this.pillars) {
      if (p.alive) continue;
      p.alive = true;
      for (let cy = p.y; cy < p.y + p.h; cy++) for (let cx = p.x; cx < p.x + p.w; cx++) {
        this.cells[cy * this.w + cx] = 1;
        this.pillarAt[cy * this.w + cx] = p.id;
      }
      this.version++;
    }
  }

  canStand(x: number, y: number, r = 0.45) {
    const x0 = Math.floor(x - r), x1 = Math.floor(x + r), y0 = Math.floor(y - r), y1 = Math.floor(y + r);
    for (let cy = y0; cy <= y1; cy++) for (let cx = x0; cx <= x1; cx++) if (this.wall(cx, cy)) return false;
    return true;
  }

  // Index of the first wall cell between two points, or -1.
  private firstWall(ax: number, ay: number, bx: number, by: number) {
    const d = Math.hypot(bx - ax, by - ay);
    const n = Math.ceil(d / 0.2);
    for (let i = 1; i < n; i++) {
      const cx = Math.floor(ax + ((bx - ax) * i) / n), cy = Math.floor(ay + ((by - ay) * i) / n);
      if (this.wall(cx, cy)) return cy * this.w + cx;
    }
    return -1;
  }

  los(ax: number, ay: number, bx: number, by: number) {
    return this.firstWall(ax, ay, bx, by) < 0;
  }

  pillarBlocking(ax: number, ay: number, bx: number, by: number) {
    const i = this.firstWall(ax, ay, bx, by);
    return i < 0 ? -1 : this.pillarAt[i];
  }

  clearWalk(ax: number, ay: number, bx: number, by: number) {
    const d = Math.hypot(bx - ax, by - ay);
    const n = Math.max(1, Math.ceil(d / 0.5));
    for (let i = 1; i <= n; i++) {
      if (!this.canStand(ax + ((bx - ax) * i) / n, ay + ((by - ay) * i) / n)) return false;
    }
    return true;
  }

  move(u: Vec, dx: number, dy: number) {
    if (this.canStand(u.x + dx, u.y + dy)) {
      u.x += dx; u.y += dy;
      return dx !== 0 || dy !== 0;
    }
    if (dx && this.canStand(u.x + dx, u.y)) { u.x += dx; return true; }
    if (dy && this.canStand(u.x, u.y + dy)) { u.y += dy; return true; }
    return false;
  }

  private openCell(x: number, y: number) {
    const cx = Math.floor(x), cy = Math.floor(y);
    if (!this.wall(cx, cy)) return cy * this.w + cx;
    for (let r = 1; r <= 3; r++) {
      for (let dy = -r; dy <= r; dy++) for (let dx = -r; dx <= r; dx++) {
        if (!this.wall(cx + dx, cy + dy)) return (cy + dy) * this.w + cx + dx;
      }
    }
    return -1;
  }

  // A* over cells, 8 directions, no corner cutting. Returns waypoints ending at the goal.
  findPath(ax: number, ay: number, bx: number, by: number): Vec[] | null {
    const W = this.w;
    const start = this.openCell(ax, ay), goal = this.openCell(bx, by);
    if (start < 0 || goal < 0) return null;
    if (start === goal) return [{ x: bx, y: by }];
    const run = ++this.run;
    const gx = goal % W, gy = Math.floor(goal / W);
    const hf: number[] = [], hi: number[] = [];
    const push = (f: number, i: number) => {
      let n = hf.length;
      hf.push(f); hi.push(i);
      while (n > 0) {
        const p = (n - 1) >> 1;
        if (hf[p] <= hf[n]) break;
        [hf[p], hf[n]] = [hf[n], hf[p]];
        [hi[p], hi[n]] = [hi[n], hi[p]];
        n = p;
      }
    };
    const pop = () => {
      const top = hi[0];
      const lf = hf.pop()!, li = hi.pop()!;
      if (hf.length) {
        hf[0] = lf; hi[0] = li;
        let n = 0;
        for (;;) {
          const l = n * 2 + 1, r = l + 1;
          let m = n;
          if (l < hf.length && hf[l] < hf[m]) m = l;
          if (r < hf.length && hf[r] < hf[m]) m = r;
          if (m === n) break;
          [hf[m], hf[n]] = [hf[n], hf[m]];
          [hi[m], hi[n]] = [hi[n], hi[m]];
          n = m;
        }
      }
      return top;
    };
    const heur = (i: number) => {
      const dx = Math.abs((i % W) - gx), dy = Math.abs(Math.floor(i / W) - gy);
      return Math.max(dx, dy) + 0.414 * Math.min(dx, dy);
    };
    this.g[start] = 0; this.seen[start] = run; this.from[start] = -1;
    push(heur(start), start);
    let found = false;
    for (let steps = 0; hf.length && steps < 40000; steps++) {
      const cur = pop();
      if (this.done[cur] === run) continue;
      this.done[cur] = run;
      if (cur === goal) { found = true; break; }
      const cx = cur % W, cy = Math.floor(cur / W);
      for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
        if (!dx && !dy) continue;
        const nx = cx + dx, ny = cy + dy;
        if (this.wall(nx, ny)) continue;
        if (dx && dy && (this.wall(cx + dx, cy) || this.wall(cx, cy + dy))) continue;
        const ni = ny * W + nx;
        if (this.done[ni] === run) continue;
        const ng = this.g[cur] + (dx && dy ? 1.414 : 1);
        if (this.seen[ni] !== run || ng < this.g[ni]) {
          this.seen[ni] = run; this.g[ni] = ng; this.from[ni] = cur;
          push(ng + heur(ni), ni);
        }
      }
    }
    if (!found) return null;
    const out: Vec[] = [];
    for (let i = goal; i !== -1 && i !== start; i = this.from[i]) out.push({ x: (i % W) + 0.5, y: Math.floor(i / W) + 0.5 });
    out.reverse();
    if (this.canStand(bx, by)) out[out.length - 1] = { x: bx, y: by };
    return out;
  }
}
