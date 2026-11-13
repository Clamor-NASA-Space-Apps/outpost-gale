# Outpost Gale: the story book

Draft 1, 13 Nov 2026, for the team to read, change and argue with. Then the facts get checked again, and the words are
wired into the game in Colombo. Every number has a row in `research/junior-astronaut/factcheck.md` (shown as `#row`);
the survival mechanics were checked on 13 Nov (`research/junior-astronaut/story-feasibility.md`, rows 251 to 280); ⚠️ marks our own maths or inference. Systems that make it
work are already built: rules sim, PIP's beats, HUD, use spots, cinematics (`design/plans/event-ready.md`).

## 0. TL;DR 🚀
You are the commander of a 2-person crew at Gale crater on Mars for 30 sols. Your job: find out whether Gale could once
have supported life, collect the best rock samples, and fly them home. Mars does not fight you. It is simply Mars: thin
air, a weak sun, dust, cold nights, radiation, and Earth 11 minutes away by radio. Every choice costs something. PIP,
the base's little robot, teaches you by letting you **feel things first** and naming them after.

**Kid version:** "You live on Mars for a month. Keep your air, power and friends safe, find the coolest rocks, and get
home with them."

## 1. How each mission is written 🧾
Every mission card follows the same five lines:

| Line | Meaning |
|---|---|
| **You do** | the action, in the kid's hands |
| **You gain** | what gets better (science, power, a crop, safety) |
| **You lose** | what it costs (power, suit air, time, battery, dose) |
| **You feel first** | what the body or the eyes find out before any word |
| **You learn** | the one line PIP says after, with its fact row |

## 2. The cast 👩‍🚀
- **You, the Commander.** Always in the suit outside, visor down: no face, ever.
- **Your crewmate** (name: the team picks; idea: *Nila*). Mostly inside: runs the lab and the radio. Talks to you on
  the suit radio. In trouble, the crewmate is the one who can come and get you, which is why you never go far alone.
- **PIP.** The base's helper robot. Curious, kind, a little funny, always honest about danger. Never says more than one
  short line at a time. PIP's voice is chirps and a speech bubble (a real voice later, if there's time).
- **Mission Control.** Real people on Earth. Every message takes about 11 minutes to arrive (#250), so they can
  advise, never rescue.
- **Curiosity.** NASA's real rover, alone at Gale since 2012 and still working (#228).
  The old friend you visit, but never touch.

## 3. The survival rules the kid feels 🫁
These are systems, not lectures. Each one shows on the HUD and each one can end a mission.

| Rule | What the kid sees and feels | How it goes wrong | Fact |
|---|---|---|---|
| **Suit air** | The suit air timer on the visor while outside | Run out far from a hatch | suit 6.5 to 8 h (factcheck EVA rows) |
| **Effort** | Sprinting is possible, but breathing gets loud, a heart-rate number climbs (a feel meter only), the suit air and cooling drain about 2.5 times faster, and the hero overheats and slows until they rest. Riding the rover is the cheapest way to travel | Sprint everywhere and the walk home becomes impossible | #254 (hard walk 599 vs calm 233 kcal/h, O₂ 0.4 vs 0.15 lb/h), #255, #258, #259, #260 |
| **Suit battery** | A small battery icon on the visor that drains with time (fans, pump, radio), not with effort | Rarely the first limit: air and cooling run out sooner | #262, #263 ⚠️, #264 |
| **Rover battery** | The rover's charge (200 kWh for long trips, about 1 kWh per km plus the cabin's life support) and a range ring on the map. The reactor refills it in about 2 sols | The battery also runs the cabin's air: run it flat and you lose both your ride and your shelter. NASA always keeps a drive-home reserve | #270, #271 ⚠️, #272, #216 |
| **The walk-home ring** | The map shows how far you could walk back (Apollo's rule: 6 miles, about 9.7 km, "the distance we could walk back in a pinch"). Mont Mercou is inside it, Curiosity is outside. NASA's plan keeps all trips within 20 km | Rover breaks outside the ring | #266, #267, #268 |
| **Base power** | Sun, dust on the panels, battery bank, the reactor | Dark, cold night with an empty battery | #21, #160, #180, #210 |
| **Oxygen, water, food** | The life support meter, the morning check | Choices that starve the oxygen maker | #23, #25, #112, #163 |
| **Radiation** | The crew health meter, the flare alert | Staying outside during a flare | #37 (not deadly, "30 chest X-rays"), #35 |
| **Sleep** | Tired crew make slower choices next sol | Skipping sleep to do more | rows 187 to 208 |

**Losing is PG.** A mission never ends in death. It ends with Mission Control calling the crew home early ("Mission
lost"), then the replay of the three choices that caused it (built: `top_causes(3)`).

## 4. The 30 sols in five chapters 📅
About 8 sols are played in full; the rest pass in the sleep time-lapse with a ledger card (a whole 30 sols with no
skips would be 10 hours, #186). Chapter titles are working names.

### Chapter 1: Arrival (Sols 1 to 3) 🌅
**Sol 1, "Good morning, Commander."** (built as beats) The airlock hisses, the hatch opens on the dawn, zen music.
Footsteps fade outside. PIP rolls up. Walk to PIP, look around, try a jump: you float, and a faint Earth ghost jumps
beside you, only a third as high (#249). Lift a cargo bag the size of you. The solar wings turn to the sun.
First choice: this morning there is power for the oxygen maker **or** the greenhouse lights.
- You do: choose. You gain: air **or** growing time. You lose: the other. You learn: "Every choice costs something."

**Sol 2, "A weak sun."** The power meter is lower than yesterday. PIP leads you to the solar farm: a thin film of dust.
Brush one wing; the power number jumps at once.
- You gain: power. You lose: suit air and time outside. You feel first: the number rising under your brush.
- You learn: "Mars gets less than half of Earth's sunlight" (#15), and "Dust ended the Opportunity rover"
  (#16, #17). Then PIP shows the reactor: "This works day, night and in storms. That's why NASA chose it." (#210)

**Sol 3, "The robots' garden."** The greenhouse is already green: the robots that built the outpost planted lettuce
before you came (it takes 33 days, #29). You plant your own tray of microgreens and radish seeds.
- You gain: a crop that will be ready before you leave (microgreens 7 to 18 days, radish 25, #119, #121).
- You lose: water and lamp power. You learn: "Plants give vitamins and smiles, not most of your food" (#122).

### Chapter 2: Learning Mars (Sols 4 to 10) 📡
**Sol 4, "Eleven minutes."** You ask Earth a question. The reply arrives 22 minutes later, while you work. Meanwhile a
small problem (a valve warning) has to be solved now.
- You do: decide without Earth. You learn: "Light takes 11 minutes to cross from Earth today" (#250).

**Sol 5, "The sun sneezes."** (real data: the 20 May 2024 flare, ARCHIVED) An alert: a solar storm is coming. You have
under an hour to get everyone into the storm shelter.
- You do: walk fast, but not too fast (effort uses air). You gain: half the dose (built, #35, #37).
- You lose: a day of work. You learn: "Water walls block radiation."

**Sols 6 to 8: quiet sols.** Skipped in the time-lapse. The ledger card shows what the base used, and that the panels
got dustier.

**Sol 9, "First field trip: Mont Mercou."** (8.8 km, built as a field site) Plan the trip on the map: battery charge,
the walk-home ring, suit air. Drive, fade: "Sol 9, 8.8 km later". Layered rock like the pages of a book. Pick
pebbles with tongs into a sealed tube.
- You gain: your first samples (score). You lose: rover battery, suit air. You learn: "These layers formed in water,
  long ago" (#246).

**Sol 10, "Sound on Mars."** (optional, short) PIP asks you to listen: inside the HAB is loud, outside is quiet.
⏳ needs the Perseverance microphone source.

### Chapter 3: The storm (Sols 11 to 18) 🌪️
**Sol 12, "The sky turns orange."** Dust storm warning. Tau climbs over two sols (built events).
- Choices every sol: heat **or** oxygen maker **or** greenhouse lights; clean the panels (they get dusty again) **or**
  save suit air; keep the rover charged for later **or** use its battery for the base.
- The reactor keeps the base alive; the solar wings give almost nothing. You feel first: a dark noon.
- You learn: "In a storm, the sun is too dim. That's why the reactor matters" (#210), "Opportunity's storm reached
  tau 10.8" (#16).

**Sols 13 to 16:** played as two short sols and a skip. The crewmate gets a cough of dust in the airlock: PIP explains
why you brush off dust before going in (perchlorate, "likely toxic").

**Sol 17, "Clear sky."** The storm settles. Dust devils dance on the plain (#176). Your microgreens are ready: the
first harvest, a tiny salad. Reward moment, music swells.

### Chapter 4: Curiosity (Sols 19 to 25) 🤖
**Sol 20, "The long drive."** The big trip: Curiosity is 14.3 km away and about 1 km higher, up Mount Sharp. Within
NASA's 20 km radius (#216), but outside the walk-home ring. PIP: "If the rover stops out there, we can't walk back.
Charge it full."
- You do: plan charge, food, suit air; the crew sleeps a night in the pressurised rover, as NASA's plan does (#269). NASA would also bring a small open rover as a backup; ours is the crewmate on the radio and the reserve charge (#268).
- You lose: battery, time. You gain: the climax.

**Sol 21, "The old friend."** Drive up the slope at dawn. A shape on the ridge: Curiosity, dusty, still working after
14 years. Music. PIP is quiet for once. Rules: look, take photos, don't touch (planetary protection, a working rover).
Take samples from the layers it studied.
- You gain: the best samples of the mission. You learn: "Curiosity found that Gale once had a lake with all the
  ingredients life needs. It didn't find life." (NASA wording, #246)

**Sol 22, "Low battery."** The drive home costs more than planned (the climb, the cold). The kid chooses: drive now and
arrive with almost nothing, or wait for the crewmate to plan a safer route (time and food).
- This is where an earlier careless choice (sprinting, skipping the charge) can come back.

### Chapter 5: Going home (Sols 26 to 31) 🛸
**Sol 26, "Only 100 kg."** The ascent rocket carries 2 crew and 100 kg of cargo (#213). Lay out every sample tube and
pick which go home. A small puzzle: the best science for the weight.

**Sol 28, "Leave it clean."** Trash into the disposal can by the lander. The dusty suits stay on Mars; you board in
clean suits (#218).

**Sol 30, "Last sunset."** A free evening. PIP points out everything one last time: the blue glow near the sun at
sunset (#168), Phobos rising in the west (#178), Earth as a bright point low in the west after Venus sets (lane W's
sky, 14 Nov 2026).

**Sol 31, "Liftoff."** The empty rover drives 1 km away (#218). Launch from outside, then the window: the base shrinks,
Gale shrinks. 2.5 sols to the ship in orbit (SAC21), then about a year home (DRA 5.0 example). The result card: what
your samples can tell Earth's labs, in one line a kid can repeat.

## 5. Little wonders (PIP points each out once) ✨
Only when you are outside and near PIP; a small "PIP shows you" moment, never forced.
- Blue near the sun at sunset; butterscotch sky by day (#167, #168).
- Phobos rises in the **west**, crosses in about 4 hours, twice a sol; Deimos is a slow star (#178, #179, #225).
  **The "satellite" moving across our sky at night is Phobos**, and that is a great PIP moment.
- Earth: a bright point after sunset (W's sky). "Everyone you know is on that dot."
- A faint Milky Way high overhead on clear nights; dust dims stars near the horizon by 3 to 4 magnitudes (#278, #279, #280 ⚠️).
- Dust devils on the plain (#176).
- The sol is 39 minutes longer than an Earth day (#198).
- Your jump, your shadow, the quiet outside.
- The ship waiting in orbit: once every 5 sols it swoops low (250 km) and could show as a fast bright point for about
  an hour and a half; the rest of the time it is too far to see (#273, #274, #275 ⚠️, #277 ⚠️). Make it a rare event:
  "Look! That's our ride home."

## 6. Corrections to our first ideas 🧭
- **The night "satellite"** is Phobos, a real moon of Mars (#178). The mothership in orbit is real in NASA's plan, but
  you could see it only around its low pass, once every 5 sols (#277 ⚠️).
- **"Blue sky at dawn and dusk":** the whole sky is not blue. The glow **near the sun** is blue at sunset (#168).
- **Lettuce for food:** it takes 33 days, longer than the stay, so robots planted it before us; the kid's own crop is
  microgreens and radishes (#119, #121, #29).
- **The trip home is about a year**, not 7 months. Getting there is about 7 months.
- **Curiosity and Mont Mercou are a drive away** (14.3 km and 8.8 km), not next to the base.
- **NASA's newest plan sends 4 crew** (#209); ours follows the 2022 plan for 2 crew (#132). One honest line on a card.
- **Flares are not deadly:** "30 chest X-rays" (#37). The danger is the total dose over time.

## 7. Open questions for the team ❓
1. The crewmate's name and voice (adult only).
2. Which sols are played and which are skipped (section 4 proposes 9 played).
3. Should the low-battery choice on Sol 22 be able to lose the mission, or only cost time and food?
4. Does the sample puzzle on Sol 26 feel fun or like homework? Playtest it.
5. The final line on the result card.
6. Heart rate: real crews' heart rates rose with excitement too (#257, #260), so in the game it is a feel meter and the
   air use follows effort. Keep it, or drop it to keep the HUD calm?
