# End of a sol: what the evening could hold

Proposal, 14 Nov 2026 (lane F), for the team to pick from. Nothing here is wired. The story is the team's.

## 0. TL;DR
Playtest, 14 Nov 13:00: "I ended Sol 1 with a question, and I was just sitting there. PIP was silent." That gap is
closed today: once the last task is done, the Today list leaves, PIP says "Today's work is done! Rest in HAB 1." and
leads the kid to the airlock, then the bed opens (`day_done` in `data/beats.json` and `data/sols.json`). Before that,
the bed says "Not sleepy yet! Finish today's tasks first."

What follows is the bigger idea: an evening that is worth staying up for. Three options, each one short (about a
minute), optional, and each with a cost, as the brief asks. They all start the same way: `do: clock:skip` runs the
look clock to sunset (the time-lapse the beats already have), so the evening really is an evening.

**Kid version:** "When the work is done, the sky puts on a show, Earth calls, or you squeeze in one more job."

## 1. Option A: look up with PIP 🌅
- **What the kid does:** at sunset PIP stops by the airlock and points west. The kid turns the view (the `look`
  wait the tutorial already uses) and finds a bright point low in the sky: Earth. On a later sol, Phobos rising in the
  west. One wonder per evening, each only once (story.md section 5 already lists them).
- **Lines (at most 8 words each):**
  - "Look! The sky near the sun is blue." (row 168)
  - "See that bright dot? That's Earth!" (row 224)
  - "Everyone you know lives on that dot." (no number)
  - "Phobos, a moon, rises in the west!" (rows 178, 225)
- **Which sol:** Sol 1 (the first sunset and Earth), Sol 3 (Phobos), Sol 30 (already "Last sunset" in story.md).
- **What it costs:** time outside: the suit air timer keeps running while the kid watches (suit 6.5 to 8 h, EVA
  rows), and the kid sleeps later. Small on purpose: the evening is a reward.
- **Facts:** row 168 ✅ (blue near the sun, true colour), row 224 ✅ ("the brightest point of light in the night sky"
  from Gale, and "two distinct, bright 'evening stars'"), rows 178 ✅ secondary and 225 ✅ (Phobos rises in the west).
  Whether Earth is above the western horizon on the sky date we show is lane W's sky (`tools/sky-stars.mjs --date`):
  **needs a check** for each sol we use it on.

## 2. Option B: the evening call home 📡
- **What the kid does:** PIP: "Earth wants to hear from you!" The kid uses the radio by the airlock (the `radio` use
  spot Sol 4 already has) and picks one of two short messages. The answer arrives after the real delay, in the
  morning's mail (the visor mail Sol 4 built).
- **Lines:**
  - "Tell Mission Control how today went!"
  - "Your words take 11 minutes to arrive." (row 250)
  - "Their answer comes back in the morning." (no number)
- **Which sol:** Sol 1 ("We made it!") and Sol 3. Not Sol 4, which is the radio sol already: B would spoil its
  surprise, so if the team picks B, Sol 4's call becomes the "they answer while you work" twist.
- **What it costs:** the radio runs on base power (**needs a source** for a radio's draw; until then no number is
  shown), and the kid goes to bed later.
- **Facts:** row 250 ⚠️ our computation (14 Nov 2026: 1.32 au, 11.0 min one way). Real crews end the day with a call:
  row 189 ✅ (the ISS "evening" planning conference).

## 3. Option C: one more job before dark 🔧
- **What the kid does:** an optional evening task tied to the sol's choice, so the choice keeps mattering after the
  card closes:
  - picked the oxygen maker on Sol 1: check its tank gauge before night ("Air for tonight: full!");
  - picked the greenhouse lamps: switch them to night mode (the plants rest, the battery keeps its charge);
  - from Sol 2 on: brush one more solar wing before the sun goes down.
- **Lines:**
  - "One more job, or rest? Your choice!"
  - "A clean wing means a fuller battery." (row 181)
  - "Night is coming. Panels stop making power." (no number)
- **Which sol:** Sol 1 (the choice), Sol 2 (the dust), Sol 12 (the storm choice).
- **What it costs:** suit air and a later bedtime; it gains battery for the night. A real trade-off, and the only
  option that changes the meters.
- **Facts:** row 180 ✅ (dust: about 0.2% a sol), row 181 ✅ (Spirit's power up about 50% once its panels were
  clean). The "night mode" saving: **needs a source** (a lamp schedule for space crops) before any number shows.

## 4. Recommendation
Option A on Sol 1 and Sol 30 (the strongest wonder, no new systems: a `clock:skip`, a `point_at`, a `look` wait and
two fact lines), Option C from Sol 2 on (it keeps the trade-offs going, the brief's core). Option B only if the team
wants a gentler Sol 4.

## 5. Open questions for the team ❓
1. Is the evening optional (PIP asks, the kid may go straight to bed) or always played? Optional keeps replays short.
2. Does Earth stand above the western horizon after sunset on the sols we show? Lane W's sky decides.
3. A radio's power draw and a crop lamp's night schedule: no source yet.
