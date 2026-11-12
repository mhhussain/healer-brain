// Headless all-AI runs for balance tuning: npm run sim -- [levels] [seeds]
import { World, DT, TIME_LIMIT } from '../src/sim/world';

const levels = (process.argv[2] ?? '1').split(',').map(Number);
const seeds = Number(process.argv[3] ?? 1);
const verbose = process.argv.includes('-v');
const healers = ['mender', 'bloomweaver'];
const dps = [['duelist', 'ranger'], ['duelist', 'pyromancer'], ['ranger', 'pyromancer']];
const fmt = (s: number) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, '0')}`;

for (const level of levels) {
  for (const h of healers) for (const d of dps) {
    for (let seed = 1; seed <= seeds; seed++) {
      const w = new World({ level, party: ['warden', h, ...d], playerSlot: 0, seed, autoplay: true });
      const marks: string[] = [];
      let cleared = 0;
      while (!w.finished && w.time < 40 * 60) {
        w.tick(DT);
        const n = w.packs.filter((p) => p.cleared).length;
        if (n !== cleared) { cleared = n; marks.push(fmt(w.totalTime())); }
      }
      const t = w.totalTime();
      const stats = w.heroes.map((u) => `${u.hero!.id.slice(0, 4)} ${Math.round(u.stats.dmg / Math.max(1, w.elapsed))}d/${Math.round(u.stats.heal / Math.max(1, w.elapsed))}h/${u.stats.interrupts}k/${u.stats.deaths}x`).join('  ');
      console.log(`L${level} ${h.slice(0, 5)}+${d.map((x) => x.slice(0, 4)).join('+')} s${seed}: ${w.finished ? fmt(t) : 'STUCK ' + cleared + '/9'} ${t <= TIME_LIMIT && w.finished ? 'timed' : 'over '} deaths ${w.deaths} | ${stats}`);
      if (verbose) console.log('   packs at ' + marks.join(' '));
    }
  }
}
