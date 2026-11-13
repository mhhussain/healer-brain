import { TIME_LIMIT, type SimEvent, type World } from '../sim/world';

// The Last Vespers: what the game says, and when.

export const OPENING = [
  'A hundred years ago, Abbot Sulmar rang the great bell against the storm. The sea answered.',
  'Tonight the tide draws back for fourteen minutes.',
  'Three lamps wait in the dark. Light them, and the abbey may finally sleep.',
];

export const ENDING_IN_TIME = 'You climb the sea stair with dry boots. Below you, for the first time in a hundred years, the abbey sleeps.';
export const ENDING_LATE = 'The tide caught you on the stair and you came home soaked to the collar. But the lamps hold, and the abbey sleeps.';

type Moment = 'pull' | 'krogg' | 'velisse' | 'sulmar' | 'lamp' | 'fallen' | 'late';

// One short line each, said in a speech bubble. Nobody says the same thing twice in a run.
const LINES: Record<string, Record<Moment, string[]>> = {
  mender: {
    pull: ['Stay close to the light.', 'Hold still. This only stings if you argue.', 'They were brothers once. Be gentle.'],
    krogg: ['Brother Krogg. We have come to relieve you.'],
    velisse: ['She is still nursing them. Oh, Sister.'],
    sulmar: ['Father Abbot. You can stop ringing now.'],
    lamp: ['One more light against the dark.', 'There. Rest now.'],
    fallen: ['No, no, no. Up you get!'],
    late: ['The tide is turning. I can hear it.'],
  },
  warden: {
    pull: ['Behind me. All of you. Yes, you too.', 'Steady. I have seen worse weather.', 'My knees remember these stairs.'],
    krogg: ['A gatekeeper. I know the type.'],
    velisse: ['Mind the little ones. They nip.'],
    sulmar: ['When that bell swings, find a pillar.'],
    lamp: ['Now that is a proper harbour light.'],
    fallen: ['Hold the line. We will fetch them after.'],
    late: ['Water is coming in. Pick up your feet.'],
  },
  bloomweaver: {
    pull: ['The sea takes. It also gives back, if you ask nicely.', 'Kelp does not hurry. Neither do I.', 'Smells like low tide. Lovely.'],
    krogg: ['Poor lamb. Rusted to his post.'],
    velisse: ['A ward full of crabs. She would be mortified.'],
    sulmar: ['He never could leave that rope alone.'],
    lamp: ['There. That will keep the damp off.'],
    fallen: ['Up, dear. The kelp has you.'],
    late: ['She is coming home, the sea. Quick now.'],
  },
  duelist: {
    pull: ['I am only here for the candlesticks.', 'Nobody mentioned they would still be home.', 'Is any of this silver?'],
    krogg: ['Big keys. Must be a big lock.'],
    velisse: ['I have robbed worse hospitals.'],
    sulmar: ['That bell would fetch a fortune. I am only saying.'],
    lamp: ['...Fine. It is a bit lovely.'],
    fallen: ['I am not carrying anyone.'],
    late: ['I cannot swim in these boots.'],
  },
  ranger: {
    pull: ['Mine.', 'Left one.', 'Quiet.'],
    krogg: ['Big.'],
    velisse: ['Too many legs.'],
    sulmar: ['Loud.'],
    lamp: ['Good.'],
    fallen: ['Get up.'],
    late: ['Tide.'],
  },
  pyromancer: {
    pull: ['Sorry. Sorry! That one got away from me.', 'Six generations of candles and nobody mentioned this.', 'Is it meant to be this damp?'],
    krogg: ['Excuse us! We have an appointment?'],
    velisse: ['I am sure she is a very good nurse.'],
    sulmar: ['My great-great-grandfather made his candles.'],
    lamp: ['Oh! It caught first time.'],
    fallen: ['Was that my fault? That felt like my fault.'],
    late: ['Wet wicks. This is my nightmare.'],
  },
};

export class Story {
  private used = new Set<string>();
  private turn = 0;
  private lateSaid = false;
  private lampIn = -1;
  private fallenAt = -99;

  constructor(private world: World, private say: (unitId: number, text: string) => void) {}

  frame(evs: SimEvent[], dt: number) {
    const w = this.world;
    for (const e of evs) {
      if (e.k === 'engage' && e.id != null) {
        const def = w.packs[e.id].def;
        if (def.boss) this.speak(def.enemies[0] as Moment);
        else if (e.id % 3 !== 1 || this.turn === 0) this.speak('pull');
      } else if (e.k === 'clear' && e.id != null && w.packs[e.id].def.boss) {
        this.lampIn = 1.8;
      } else if (e.k === 'death' && e.id != null && w.unit(e.id)?.team === 'hero' && w.time - this.fallenAt > 15) {
        this.fallenAt = w.time;
        this.speak('fallen');
      }
    }
    if (this.lampIn > 0 && (this.lampIn -= dt) <= 0) this.speak('lamp');
    if (!this.lateSaid && w.started && w.totalTime() > TIME_LIMIT - 120) {
      this.lateSaid = true;
      this.speak('late');
    }
  }

  // The next party member in turn who still has something new to say about this.
  private speak(moment: Moment) {
    const alive = this.world.heroes.filter((h) => h.alive);
    for (let i = 0; i < alive.length; i++) {
      const h = alive[(this.turn + i) % alive.length];
      const line = LINES[h.hero!.id]?.[moment]?.find((l) => !this.used.has(h.hero!.id + l));
      if (!line) continue;
      this.used.add(h.hero!.id + line);
      this.turn += i + 1;
      this.say(h.id, line);
      return;
    }
  }
}
