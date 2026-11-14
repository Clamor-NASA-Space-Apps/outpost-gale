# Mission 1: Arrival (Sols 1 to 10), script and plan

Draft for the team's approval, 14 Nov 2026. Nothing here is built yet. Numbers with a row are from
`research/junior-astronaut/factcheck.md`; "sim" means a game value still to be read from `data/sim.json`.

## 0. TL;DR 🚀
- Mission 1 is the first 10 sols: five played in full (Sols 1 to 5), three quiet ones skipped with a ledger (6 to 8),
  the first rover trip (Sol 9), and a short close (Sol 10). The dust storm (Sol 12) opens Mission 2.
- Every sol asks one question, and the kid can answer it because they felt it and read it first:
  **feel it, read the page, answer the check, then decide.**
- A **handbook** collects every lesson as a page with a real NASA photo. It is also a tool: on Sol 4 the kid fixes
  an alarm by reading it.
- **PIP says each thing once**, then stays quiet while the kid is doing it.
- Two decisions with a cost (Sols 1 and 5), two trade-offs the kid makes with their hands (Sols 2 and 9).

**Kid version:** "PIP shows you something real, your handbook keeps it, and then you choose."

## 1. The loop every sol follows 🔁
| Step | What happens | Stops the game? |
|---|---|---|
| Feel | The kid does or sees the real thing (jumps, brushes dust, hears the alarm) | no |
| Read | PIP says one line. A page lands in the handbook with a "New page" note | no |
| Check | One question, three answers, asked once per sol. The pages it needs open first | yes |
| Decide | On the sols that have one: a card showing what each option gains and loses | yes |
| Result | Next morning PIP reads the result off the meters | no |

Rules for the check:
- Wrong answers are things a kid might really believe, never jokes. The order is shuffled.
- Right: the page is stamped "Learned". Wrong: PIP says "Not quite. Look again.", the page reopens, the kid tries
  again. No meter is ever hurt by a wrong answer.
- A check is a choice card with three options and no rule behind it, so it needs no new card.

## 2. PIP, less talk 🤖
What annoys now: while leading, PIP calls "This way!" every 6 seconds whether or not the kid follows
(`data/beats.json` `pip.call_s`), and pleads at 10, 25 and 45 seconds, then loops.

| # | New rule |
|---|---|
| 1 | One line per step, said once. The task list and the waypoint carry the rest |
| 2 | While the kid is doing the step (getting nearer, holding the right key, within reach), PIP is silent |
| 3 | One reminder after 20 s with no progress, one more after 60 s, then none. No sad bounce |
| 4 | Leading: PIP waits when the kid falls behind (it does already) and calls only if the kid walks away |
| 5 | A fact is said once and never repeated. It lives in the handbook |
| 6 | Free time: silent, except a danger or the day's deadline |

## 3. The handbook 📖
The layout idea comes from the reference pictures (a two-page survival guide). The look is ours, from `DESIGN.md`
and `ui/theme.tres`: nothing is copied from that game.

- **Opens with** Tab, or a book button on the HUD (touch). The game pauses while it is open.
- **Top left:** the path, for example `HANDBOOK / OUR BASE`, and the tab's big title.
- **Top right:** four tab icons. A tab with an unread page shows a "!" mark.
- **Left page:** the picture, large. A real NASA photo with its credit line, or the game's own model (PIP, the hab).
- **Right page:** the list of pages in the tab. Picking one shows its title and text in a dark panel.
- **A page holds:** a title, at most three short lines, one "kid version" line, the source, and "Learned" once its
  check is passed.
- **Bottom right:** Back.

| Tab | Pages in Mission 1 |
|---|---|
| Mars | Light on Mars, Almost no air, A weak sun, Cold nights, Dust, Solar storms, Gale's ancient lake |
| Our base | Air in tanks, The air maker, The garden, Seeds for 30 sols, Water, Solar wings, The reactor, The oxygen valve, The radio, The storm shelter, The rover |
| Explorers | PIP, Mission Control, Opportunity, InSight, Curiosity |
| Mission log | The sol, pages found (for example 14 of 23), each decision made and what it cost |

All pages come from one data file (`data/handbook.json`). Photos are copied from
`research/junior-astronaut/images/` with their credits; each one is checked for NASA logos before it ships.

## 4. The sols 📅

### Sol 1: "Good morning, Commander". Where does my air come from?
**Story.** The hatch opens on a blue dawn. You step out, meet PIP, learn to move, and tour the base. Power is short,
so you make your first choice.

**Tasks:** Step outside · Learn to move · Tour the base with PIP · Choose: air or plants · Sleep in HAB 1

**Moved out of today's Sol 1:** the map lesson (to Sol 9, where the map is needed) and the hurry step (to Sol 5).
The cargo bag lift stays only if carrying looks right; the jump already teaches gravity.

| PIP says (once) | Page | Lines on the page | Picture |
|---|---|---|---|
| "Now jump!" | Light on Mars | Mars pulls 0.38 as hard as Earth. You jump almost three times as high (row 249) | the Earth ghost, in game |
| "Outside, the air is very thin." | Almost no air | Mars air presses 6 millibars. Earth's presses 1,013. Your suit is a tiny spaceship | `iss058e015351` |
| "Our power comes from this small sun." | A weak sun | Mars gets 43% of Earth's sunlight (row 15). Power is always short here | `PIA22205` |
| "Your air came from Earth, in these tanks." | Air in tanks | One person breathes 0.84 kg of oxygen a day (row 23). Two of you for 30 sols: about 52 kg (row 163). The tanks hold 54 kg (sim) | `KSC-20200716-PH-KLS01_0007` |
| "This makes more. It drinks water and power." | The air maker | It splits water into oxygen. 1 kg of oxygen costs 1.1 kg of water. It needs about 4 kW | `iss020e033496` |
| "Three more days of light, then salad!" | The garden | Robots planted this lettuce 30 days ago. Lettuce takes 33 days (row 29). Plants give vitamins and smiles, not your air | `iss040e009126` |
| (at dusk) "Brr. Heaters on for the night." | Cold nights | Gale's nights can drop to minus 100 °C. The heaters run on power all night | to pick |

**Check:** Where does our air come from today? Tanks from Earth ✔ · The garden · The Mars air

**Decision: "Power for one today"**
| Option | You gain | You lose |
|---|---|---|
| Run the air maker | spare oxygen (sim) | water, and the lettuce waits a day |
| Light the garden | salad on time, a happier crew (sim) | no spare air |

### Sol 2: "A weak sun". Why is my power lower?
**Story.** PIP reads out what yesterday's choice did. The power meter is lower than last night. At the solar wings a
film of dust covers the glass. You brush one and the number jumps.

**Tasks:** Check the power meter · Brush the solar wings · See the reactor · Sleep

**Trade-off, made by hand:** there are six wings. Each one brushed adds power and costs time outside, which is suit
air. PIP says it once: "One clean. Five dusty. Your call."

| PIP says (once) | Page | Lines on the page | Picture |
|---|---|---|---|
| "Night wind dropped dust on the wings." | Dust | Dust takes about 0.2% of your power every sol (row 180). A clean panel can make half as much again (row 181) | `PIA25287` |
| "Dust stopped two explorers before us." | Opportunity | A storm was spotted on 30 May 2018. Opportunity's last signal came on 10 June (row 16) | `PIA22521` |
| (same) | InSight | Its panels fell from 5,000 to 500 watt-hours a sol under dust (row 160) | `PIA25287` |
| "This works day, night and in storms." | The reactor | NASA picked fission power for the first Mars crews (row 210). Ours gives 10 kW | `GRC-2015-C-06315` |

**Check:** Why did the power drop overnight? Dust on the wings ✔ · The sun got smaller · The reactor stopped

### Sol 3: "The robots' garden". Can plants feed us?
**Story.** The greenhouse is already green: robots planted it before you landed. You plant your own tray and learn
what a garden can and cannot do on a 30-sol stay.

**Tasks:** Visit the greenhouse · Plant a seed tray · Sleep

| PIP says (once) | Page | Lines on the page | Picture |
|---|---|---|---|
| "Your turn: plant a seed tray!" | Seeds for 30 sols | Microgreens are ready in 7 to 18 days, radishes in 25 (rows 119, 121). Both are ready before we leave | to pick |
| "Seeds drink our water too." | Water | Each of you needs 3.2 kg of water a day (row 25). All of it came from Earth: this short stay recycles none (row 132) | `iss047e013845` |

**Check:** What do our plants give us? Vitamins and fresh bites ✔ · All our food · All our air

**Optional decision (needs a small new rule):** which seeds. Microgreens: a small fresh bite soon. Radishes: a bigger
harvest, late, with more water. Without the rule the kid plants one tray and there is no card.

### Sol 4: "Earth is far". Who helps when something breaks?
**Story.** You radio a question to Earth. While the answer is still travelling, the oxygen alarm rings. Earth cannot
answer in time, so you open the handbook, read what to do, and fix it yourself. Then Earth's answer arrives.

**Tasks:** Ask Earth a question · Fix the oxygen valve · Read Earth's answer · Sleep

| PIP says (once) | Page | Lines on the page | Picture |
|---|---|---|---|
| "Sent! Now we wait." | The radio | Today a message takes about 11 minutes each way (row 250). It can take 3 to 22 | to pick |
| (same) | Mission Control | Real people on Earth. They can advise. They cannot rescue | to pick |
| "Alarm! Check your handbook!" | The oxygen valve | If the oxygen alarm rings, turn the valve beside the air maker | the valve, in game |

**Check:** Why couldn't Earth help with the alarm? The answer takes too long to arrive ✔ · Earth was asleep · The radio broke

### Sol 5: "Solar storm". What protects me from the Sun?
**Story.** A quiet morning, then a warning: a solar storm is coming. You hurry to the shelter (hurrying burns suit
air, which PIP teaches here). Inside, you decide how long to stay.

**Tasks:** Get to the storm shelter · Decide: stay or go · Sleep

| PIP says (once) | Page | Lines on the page | Picture |
|---|---|---|---|
| "Solar storm coming! To the shelter!" | Solar storms | On 20 May 2024 Curiosity measured one: like 30 chest X-rays (row 37). Not deadly, but doses add up | `PIA26302` |
| "Water walls cut the dose in half." | The storm shelter | Water stops radiation better than metal. About 5 cm of it halves a storm's dose (row 90). A crew can stay up to a day (row 35) | the shelter, in game |

**Check:** What makes the shelter safer? Water in its walls ✔ · Thick metal walls · Being underground

**Decision: "The storm lasts all day"**
| Option | You gain | You lose |
|---|---|---|
| Stay in the shelter | half the dose (sim) | the day's work: the wings stay dusty |
| Go out and work | clean wings, more power | the full dose on crew health (sim) |

### Sols 6 to 8: quiet sols
Skipped in the sleep time-lapse. The ledger card shows what three sols cost: oxygen, water and food used, dust
gained. No lesson, no question.

### Sol 9: "The old lake". How far is too far?
**Story.** The first trip. You plan it on the map, drive 8.8 km to Mont Mercou, take a rock sample from a 6 m rock
wall, and drive home. The map lesson happens here.

**Tasks:** Plan the trip on the map · Drive to Mont Mercou · Take a rock sample · Drive home · Sleep

**Trade-off, made by hand:** the suit air timer runs while you are out of the rover.

| PIP says (once) | Page | Lines on the page | Picture |
|---|---|---|---|
| "See the ring? We can walk back from inside it." | The rover | Apollo crews stayed within about 9.7 km: the distance they could walk back (rows 266 to 268). Mont Mercou is 8.8 km away | `jsc2008e138993` |
| "Long ago, this was a lake." | Gale's ancient lake | Billions of years ago Gale held a lake with what life needs. Nobody has found life here | to pick |
| "An old friend lives in this crater." | Curiosity | NASA's rover has worked at Gale since 2012 (row 228) | to pick |

**Check:** Why is Mont Mercou a safe trip? We could walk back from it ✔ · The rover is fast · It is downhill

### Sol 10: close
A quiet morning and the **Mission 1 report** card: pages found, checks passed, both decisions and what they cost, the
three meters. PIP's last line sets up Mission 2: "The sky looks strange tonight."

## 5. Build order 🔧
Rough sizes, my estimates. The cut line, if time runs short, is after step 4.

| # | Work | Size |
|---|---|---|
| 1 | PIP's quiet rules (section 2) | about 1 h |
| 2 | The handbook screen, its data file, the "New page" note | 3 to 4 h |
| 3 | The check card (right, wrong, reopen the page) | about 1 h |
| 4 | Sols 1 and 2: lines, pages, card costs | about 2 h |
| 5 | Sols 3, 4, 5 and 9: lines, pages, checks; Sol 5's decision | about 3 h |
| 6 | The Mission 1 report card | about 1 h |

## 6. To decide ❓
1. Is Mission 1 the first 10 sols, with Sols 1 to 5 and 9 played?
2. Sol 2: the hand-made trade-off (brush as many as you like), or a card?
3. Sol 3: build the seed decision, or leave it out?
4. Sol 1: agree to move the map and the hurry step out, and drop the bag lift if carrying still looks wrong?
5. The handbook key: Tab?
6. The crewmate from the story book does not appear in this mission. Should they?

**Still to source before it ships:** the 4 kW for the air maker (the station's oxygen generator, 3.6 to 4 kW), the
1.1 kg of water per kg of oxygen and "water beats metal" (both in the workspace's verified table, rows not looked up),
Mont Mercou's 6 m, and "thin air makes sound quiet" (no row found, so it is left out).
