#!/usr/bin/env bash
# Builds every file in audio/ from the downloads in assets-cache (and our own synthesis), once, with ffmpeg.
# Usage (from the project folder): nice -n 10 bash audio/make.sh [music|radio|sfx]   (only audio/music/, only the radio
# sounds, or only the use-spot sounds)
# Why baked: a Godot web build plays audio in Sample mode, where bus effects do not run (design/research/alive.md 4.3),
# so every muffle is in the file. `<name>.ogg` is the clear copy (Habitat bus, full air), `<name>_out.ogg` the one
# heard on Mars through a helmet (Outside bus). Credits: ASSETS.md, Sound.
set -euo pipefail
cd "$(dirname "$0")"
S=../../../../assets-cache/sounds
K=../../../../assets-cache/kenney
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

# Mars through a visor: thin air keeps only the low end (NASA/JPL 2022). The cutoff is a starting guess by ear
# (Ravindu's notes: 800 to 1500 Hz), not a sourced number.
OUT="lowpass=f=900,lowpass=f=900"
# a boot heard through the body, not the air: only the thud
BODY="lowpass=f=450,lowpass=f=450,bass=g=6:f=120"

enc() { ffmpeg -v error -y -i "$1" -ac 1 -ar 32000 -c:a libvorbis -q:a 2 "$2"; }

# One-shots to a -3 dBFS peak, so the mix lives in data/tuning.json and not in the files.
shot() { # in filter out.ogg
	ffmpeg -v error -y -i "$1" -af "$2" -ac 1 -ar 32000 "$T/s.wav"
	local peak
	peak=$(ffmpeg -i "$T/s.wav" -af volumedetect -f null - 2>&1 | sed -n 's/.*max_volume: \(-*[0-9.]*\) dB/\1/p')
	ffmpeg -v error -y -i "$T/s.wav" -af "volume=$(python3 -c "print(-3 - $peak)")dB" "$T/n.wav"
	enc "$T/n.wav" "$3"
}

# A seamless loop: the last `xf` seconds fade into the first, and the loop starts after them. Loudness to -20 LUFS.
# Godot loops it because its .ogg.import says loop=true (kept when this script rewrites the .ogg).
loop() { # in.wav xf out.ogg
	local len cut
	len=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$1")
	cut=$(python3 -c "print($len - $2)")
	ffmpeg -v error -y -i "$1" -filter_complex "[0]loudnorm=I=-20:TP=-2,aresample=32000,asplit=3[a][b][c];\
[a]atrim=$2:$cut,asetpts=N/SR/TB[mid];\
[b]atrim=$cut:$len,asetpts=N/SR/TB,afade=t=out:d=$2[t];\
[c]atrim=0:$2,asetpts=N/SR/TB,afade=t=in:d=$2[h];\
[t][h]amix=inputs=2:normalize=0[x];[mid][x]concat=n=2:v=0:a=1" -ac 1 "$T/l.wav"
	enc "$T/l.wav" "$3"
}

# Music (design/research/alive.md 5: rare, a few earned moments, silence the rest of the time). Stereo 44.1 kHz and
# clear: music is not a sound in the Mars air, so nothing here is muffled. About -16 LUFS under a -1.5 dBFS ceiling;
# the level in play is data/tuning.json `audio.music`. Picks and licences: assets-cache/music/README.md.
M=../../../../assets-cache/music
tune() { # in filter out.ogg [vorbis quality, 3]
	ffmpeg -v error -y -i "$1" -af "$2" -ar 44100 -ac 2 "$T/m.wav"
	local i
	i=$(ffmpeg -nostats -i "$T/m.wav" -af ebur128 -f null - 2>&1 | sed -n 's/^ *I: *\(-*[0-9.]*\) LUFS/\1/p' | tail -1)
	ffmpeg -v error -y -i "$T/m.wav" -af "volume=$(python3 -c "print(-16 - $i)")dB,alimiter=limit=0.84:attack=5:release=80:level=false" \
		-c:a libvorbis -q:a "${4:-3}" "music/$3"
}
music() {
	mkdir -p music
	# ours (Apache-2.0, assets-cache/music/ours/make_motifs.py): a 20 ms fade in against a click, 0.3 s out at the end
	END="areverse,afade=t=in:d=0.3,areverse"
	for f in first_step airlock_sealed discovery mission_lost quiet dawn sleep storm; do
		tune "$M/ours/$f.ogg" "afade=t=in:d=0.02,$END" "$f.ogg"
	done
	# Kilua Boy's Sunset Walk is 48 bars of 1.6 s (its hits land on 12.8, 25.6, 49.6, 51.2 s, measured from the
	# loudness envelope). Its first 16 bars: the soft intro and the first melody, which ends in a quiet bar before
	# the downbeat at 25.6 s. Cut just before that downbeat, and fade the quiet bar out after the last hits (22.2 s).
	tune "$M/oga-kiluaboy-sunset-walk/SunsetWalk.ogg" "atrim=0:25.55,asetpts=N/SR/TB,afade=t=in:d=0.02,afade=t=out:st=22.75:d=2.8" sunset.ogg
	# The beds (audio.gd `bed()`): one phrase now and then, minutes of rest between, so they stay rare. Played far
	# under the cues, so Vorbis q1 is plenty. Exploration Theme is 56 bars of 2.4 s; its sections turn at 41.7 and
	# 80.4 s (the loudness envelope dips there), so three phrases of about 16 bars each.
	local ex="$M/oga-cleytonkauffman-exploration-theme/Exploration Theme/Exploration Theme.ogg"
	bedcut "$ex" 0 41.6 bed_eva_1.ogg
	bedcut "$ex" 41.7 80.3 bed_eva_2.ogg
	bedcut "$ex" 80.4 118.8 bed_eva_3.ogg
	# Lifewave 2k breathes in phrases of about 12 s with quiet dips between; its music starts at 4.8 s, and its
	# dips at 47.2 and 86.6 s close the first two long phrases.
	local lw="$M/oga-cynicmusic-lifewave-2k/006_lifeWave2k_0.mp3"
	bedcut "$lw" 4.8 47.2 bed_hab_1.ogg
	bedcut "$lw" 47.3 86.6 bed_hab_2.ogg
	du -ch music/*.ogg | tail -1
}
bedcut() { # in from to out.ogg: a phrase eased in over 1.5 s and out over 3 s
	local d
	d=$(python3 -c "print($3 - $2)")
	tune "$1" "atrim=$2:$3,asetpts=N/SR/TB,afade=t=in:d=1.5,afade=t=out:st=$(python3 -c "print($d - 3)"):d=3" "$4" 1
}

# The suit radio (our own synthesis, wordless): heard through the headset, so clear, but squeezed into a radio's
# voice band (300 Hz to 3 kHz, art direction). The base: a key-down click, Apollo's Quindar intro tone (2,525 Hz,
# 250 ms), an open carrier's hiss, the outro tone (2,475 Hz, 250 ms) and the squelch tail as the carrier drops
# (design/research/pages/alive/rover-spring-and-radio.md). PIP: a click, two quick rising chirps, the tail.
radio() {
	local band="highpass=f=300,highpass=f=300,lowpass=f=3000,lowpass=f=3000"
	local f="aformat=sample_rates=32000:channel_layouts=mono"
	ffmpeg -v error -y -f lavfi -i "anoisesrc=c=white:d=0.012:a=0.8:seed=11:r=32000" \
		-f lavfi -i "sine=f=2525:d=0.25:r=32000" -f lavfi -i "anoisesrc=c=white:d=0.45:a=0.1:seed=12:r=32000" \
		-f lavfi -i "sine=f=2475:d=0.25:r=32000" -f lavfi -i "anoisesrc=c=white:d=0.18:a=0.5:seed=13:r=32000" \
		-filter_complex "[0]$f[c];[1]$f,volume=0.5,afade=t=in:d=0.005,afade=t=out:st=0.245:d=0.005[i];\
[2]$f,afade=t=in:d=0.02[h];[3]$f,volume=0.5,afade=t=in:d=0.005,afade=t=out:st=0.245:d=0.005[o];\
[4]$f,afade=t=out:st=0.03:d=0.15[s];[c][i][h][o][s]concat=n=5:v=0:a=1" -ac 1 "$T/rb.wav"
	shot "$T/rb.wav" "$band" radio_base.ogg
	ffmpeg -v error -y -f lavfi -i "anoisesrc=c=white:d=0.012:a=0.8:seed=21:r=32000" \
		-f lavfi -i "aevalsrc='0.5*sin(2*PI*(1300*t+3000*t*t))':d=0.09:s=32000" -f lavfi -i "anullsrc=r=32000:cl=mono:d=0.05" \
		-f lavfi -i "aevalsrc='0.5*sin(2*PI*(1500*t+4000*t*t))':d=0.11:s=32000" -f lavfi -i "anoisesrc=c=white:d=0.14:a=0.45:seed=22:r=32000" \
		-filter_complex "[0]$f[c];[1]$f,afade=t=in:d=0.005,afade=t=out:st=0.08:d=0.01[a];[2]$f[g];\
[3]$f,afade=t=in:d=0.005,afade=t=out:st=0.09:d=0.02[b];[4]$f,afade=t=out:st=0.02:d=0.12[s];[c][a][g][b][s]concat=n=5:v=0:a=1" -ac 1 "$T/rp.wav"
	shot "$T/rp.wav" "$band" radio_pip.ogg
}

# The use spots' sounds (design/plans/next-lanes.md 4.4), named in audio.gd SOUNDS. Spots indoors (the galley, the
# greenhouse, the toilet, the desk) get only the clear copy; ones that can happen outside also get `_out`.
sfx() {
	nice -n 10 python3 -I make_sfx.py "$T"
	for f in curtain pour sip crinkle rattle leaf suction brush beep; do
		shot "$T/$f.wav" "anull" "$f.ogg"
	done
	for f in latch ratchet valve zip; do
		shot "$T/$f.wav" "anull" "$f.ogg"
		shot "$T/$f.wav" "$OUT" "${f}_out.ogg"
	done
	# a rock sample knocked loose (rubberduck bfh1_rock_hit_01, CC0)
	shot "$S/oga-rubberduck-breaking-falling-hit/bfh1_rock_hit_01.ogg" "anull" rock.ogg
	shot "$S/oga-rubberduck-breaking-falling-hit/bfh1_rock_hit_01.ogg" "$OUT" rock_out.ogg
	# a knee on gravel (TinyWorlds gravel step, CC0): through the suit outside, like the boots
	shot "$S/oga-tinyworlds-different-steps/gravel.ogg" "anull" kneel.ogg
	shot "$S/oga-tinyworlds-different-steps/gravel.ogg" "$BODY" kneel_out.ogg
	# soil patted over a seed: a Fantozzi sand step slowed to 0.7
	shot "$S/oga-fantozzi-footsteps/Fantozzi-footsteps/flac/Fantozzi-SandL1.flac" "aresample=44100,asetrate=44100*0.7,aresample=44100" pat.ogg
	# the O2 valve venting (bart's steam hiss #1, CC0)
	shot "$S/oga-bart-steam-hisses/steam hisses - Marker #1.wav" "afade=t=out:st=1.2:d=0.6" vent.ogg
	shot "$S/oga-bart-steam-hisses/steam hisses - Marker #1.wav" "afade=t=out:st=1.2:d=0.6,$OUT" vent_out.ogg
	# the suit's air refilling: 0new4y's gas leak loop (CC0), softened, 3.2 s
	shot "$S/oga-0new4y-gas-leak/compressed_gas_leak.ogg" "aloop=loop=1:size=88200,atrim=0:3.2,lowpass=f=2500,afade=t=in:d=0.3,afade=t=out:st=2.6:d=0.6" refill.ogg
	# the hose connector: a click, then the coupling seats (Kenney click_001, rubberduck bfh1_metal_hit_01)
	ffmpeg -v error -y -i "$K/interface-sounds/Audio/click_001.ogg" -i "$S/oga-rubberduck-breaking-falling-hit/bfh1_metal_hit_01.ogg" \
		-filter_complex "[0]aresample=32000,pan=mono|c0=c0[a];[1]aresample=32000,pan=mono|c0=c0,volume=0.3,adelay=40[b];[a][b]amix=inputs=2:normalize=0:duration=longest" "$T/c.wav"
	shot "$T/c.wav" "anull" connect.ogg
	# the desk screens waking (Kenney computerNoise_000, CC0), its first 1.5 s
	shot "$K/sci-fi-sounds/Audio/computerNoise_000.ogg" "atrim=0:1.5,afade=t=out:st=1.0:d=0.5" screens.ogg
	# the suit check's three ticks (Kenney confirmation_001..003, CC0), half a second apart
	ffmpeg -v error -y -i "$K/interface-sounds/Audio/confirmation_001.ogg" -i "$K/interface-sounds/Audio/confirmation_002.ogg" \
		-i "$K/interface-sounds/Audio/confirmation_003.ogg" -filter_complex \
		"[0]aresample=32000,pan=mono|c0=c0[a];[1]aresample=32000,pan=mono|c0=c0,adelay=500[b];[2]aresample=32000,pan=mono|c0=c0,adelay=1000[c];[a][b][c]amix=inputs=3:normalize=0:duration=longest" "$T/t.wav"
	shot "$T/t.wav" "anull" ticks.ogg
	# hard work in the suit: craigsmith's respirator loop (Freesound 675559, CC0) under the breaths, a seamless loop
	ffmpeg -v error -y -i "$S/freesound-craigsmith-675559/675559__craigsmith__s26-03-respirator-loopable.wav" -af "lowpass=f=3000" -ac 1 "$T/x.wav"
	loop "$T/x.wav" 1 exert.ogg
}

if [ "${1:-}" = music ]; then
	music
	exit 0
fi
if [ "${1:-}" = radio ]; then
	radio
	exit 0
fi
if [ "${1:-}" = sfx ]; then
	sfx
	exit 0
fi

# Footsteps, left and right sets (Fantozzi, CC0): through the suit on sand and rock, clear on the habitat floor.
for f in L1 L2 L3 R1 R2 R3; do
	lr=$(echo "${f:0:1}" | tr LR lr)
	shot "$S/oga-fantozzi-footsteps/Fantozzi-footsteps/flac/Fantozzi-Sand$f.flac" "$BODY" "step_sand_$lr${f:1}.ogg"
	shot "$S/oga-fantozzi-footsteps/Fantozzi-footsteps/flac/Fantozzi-Stone$f.flac" "$BODY" "step_rock_$lr${f:1}.ogg"
	shot "$S/oga-fantozzi-footsteps/Fantozzi-footsteps/flac/Fantozzi-Stone$f.flac" "highpass=f=60" "step_in_$lr${f:1}.ogg"
done

# Wind: NASA Perseverance's first Mars audio (rover noise filtered out), the gusty middle 13 s.
ffmpeg -v error -y -ss 2.5 -t 13 -i "$S/nasa-perseverance/45704_1st_Sounds_from_Mars_filters_out_rover_self-noise.wav" -af "$OUT" -ac 1 "$T/w.wav"
loop "$T/w.wav" 1.5 wind_out.ogg

# Rover wheels: Perseverance driving, sol 16 (metal wheels on rock), its steady loud stretch.
ffmpeg -v error -y -ss 39.5 -t 7 -i "$S/nasa-perseverance/45856_FILTERED_HIGHLIGHTS_-_Sol16RoverDriveHighlights.wav" -ac 1 "$T/r.wav"
ffmpeg -v error -y -i "$T/r.wav" -af "$OUT" "$T/ro.wav"
loop "$T/r.wav" 1 wheels.ogg
loop "$T/ro.wav" 1 wheels_out.ogg

# Machine hum: YCbCr's generator loop (CC0), clear inside the habitat, muffled at the machines outside.
ffmpeg -v error -y -i "$S/oga-ycbcr-generator-loop/loop_generator_1.mp3" -af "atrim=0.05,lowpass=f=3000" -ac 1 "$T/h.wav"
ffmpeg -v error -y -i "$T/h.wav" -af "$OUT" "$T/ho.wav"
loop "$T/h.wav" 0.6 hum.ogg
loop "$T/ho.wav" 0.6 hum_out.ogg

# Our own synthesis (no honest recording on disk). Suit fan: brown noise through a duct plus the fan motor's
# 118 Hz and its harmonic (whole cycles in the 5 s loop, so the tones stay seamless).
ffmpeg -v error -y -f lavfi -i "anoisesrc=c=brown:d=6:a=0.6:seed=3" -f lavfi -i "anoisesrc=c=pink:d=6:a=0.15:seed=4" \
	-f lavfi -i "sine=f=118:d=6" -f lavfi -i "sine=f=236:d=6" \
	-filter_complex "[0]lowpass=f=700[n];[1]bandpass=f=2200:width_type=h:w=1500[p];[2]volume=0.12[s1];[3]volume=0.05[s2];\
[n][p][s1][s2]amix=inputs=4:normalize=0,tremolo=f=0.4:d=0.08" -ac 1 -ar 32000 "$T/f.wav"
loop "$T/f.wav" 1 suit_fan.ogg

# Breath inside a helmet: Kodack's "mask breathing" (Freesound 256519, CC0), one breath of its second cycle, the
# loud valve pull as the inhale and the softer push after it as the exhale (cut by its loudness envelope).
B="$S/freesound-kodack-256519/256519__kodack__mask-breathing-sound.wav"
shot "$B" "atrim=3.25:4.7,asetpts=N/SR/TB,afade=t=in:d=0.08,afade=t=out:st=1.25:d=0.2" breath_in.ogg
shot "$B" "atrim=4.7:5.8,asetpts=N/SR/TB,afade=t=in:d=0.05,afade=t=out:st=0.8:d=0.3" breath_out.ogg

# Panel servo: a motor whine that speeds up and slows down over the tween (0.6 s, ease in and out), then the end
# stop clunks (Kenney impactMetal_000, CC0).
ffmpeg -v error -y -f lavfi -i "aevalsrc='(0.4*sin(2*PI*(500*t-350*0.7/PI*cos(PI*t/0.7)))+0.2*sin(4*PI*(500*t-350*0.7/PI*cos(PI*t/0.7))))':d=0.7:s=32000" \
	-i "$K/sci-fi-sounds/Audio/impactMetal_000.ogg" \
	-filter_complex "[0]afade=t=in:d=0.1,afade=t=out:st=0.5:d=0.2[w];[1]aresample=32000,volume=0.3,adelay=620[c];[w][c]amix=inputs=2:normalize=0:duration=longest" -ac 1 "$T/v.wav"
shot "$T/v.wav" "anull" servo.ogg
shot "$T/v.wav" "$OUT" servo_out.ogg

# Rover drive motor: an electric whine (320 Hz and harmonics, whole cycles in 2 s) over a little noise.
ffmpeg -v error -y -f lavfi -i "aevalsrc='0.3*sin(2*PI*320*t)+0.12*sin(2*PI*640*t)+0.06*sin(2*PI*960*t)':d=3:s=32000" \
	-f lavfi -i "anoisesrc=c=brown:d=3:a=0.3:seed=7:r=32000" -filter_complex "[1]lowpass=f=500[n];[0][n]amix=inputs=2:normalize=0" -ac 1 "$T/m.wav"
loop "$T/m.wav" 1 motor.ogg
ffmpeg -v error -y -i "$T/m.wav" -af "$OUT" "$T/mo.wav"
loop "$T/mo.wav" 1 motor_out.ogg

# Airlock door close motor (Kenney doorClose_000), bag lift and set-down
# (a Fantozzi sand scuff slowed down, rubberduck's hit_01 slowed down for the weight), the suit chirp (Kenney
# Interface confirmation_001). Clear and outside copies.
# the airlock opening: NeoSpica's pressurised door (Freesound 425090, CC0)
shot "$S/freesound-neospica-425090/425090__neospica__pressurized-door-opening.wav" "anull" door_open.ogg
shot "$S/freesound-neospica-425090/425090__neospica__pressurized-door-opening.wav" "$OUT" door_open_out.ogg
for pair in "doorClose_000:door_close"; do
	shot "$K/sci-fi-sounds/Audio/${pair%%:*}.ogg" "anull" "${pair##*:}.ogg"
	shot "$K/sci-fi-sounds/Audio/${pair%%:*}.ogg" "$OUT" "${pair##*:}_out.ogg"
done
# the pressure hiss: unfa's (Freesound 211096, CC0), its first 2 s
H="$S/freesound-unfa-211096/211096__unfa__pressure-hiss.flac"
shot "$H" "atrim=0:2,afade=t=in:d=0.05,afade=t=out:st=1.4:d=0.6" hiss.ogg
shot "$H" "atrim=0:2,afade=t=in:d=0.05,afade=t=out:st=1.4:d=0.6,$OUT" hiss_out.ogg
LIFT="aresample=44100,asetrate=44100*0.75,aresample=44100"
shot "$S/oga-fantozzi-footsteps/Fantozzi-footsteps/flac/Fantozzi-SandR2.flac" "$LIFT" bag_lift.ogg
shot "$S/oga-fantozzi-footsteps/Fantozzi-footsteps/flac/Fantozzi-SandR2.flac" "$LIFT,$OUT" bag_lift_out.ogg
DROP="aresample=44100,asetrate=44100*0.8,aresample=44100"
shot "$S/oga-rubberduck-breaking-falling-hit/bfh1_hit_01.ogg" "$DROP" bag_drop.ogg
shot "$S/oga-rubberduck-breaking-falling-hit/bfh1_hit_01.ogg" "$DROP,$OUT" bag_drop_out.ogg
shot "$K/interface-sounds/Audio/confirmation_001.ogg" "anull" chirp.ogg

# PIP's beeps (Kenney Interface Sounds, CC0): a rising "off I go" when it sets out, a questioning one when it
# notices the hero. Clear and outside copies.
for pair in "maximize_003:pip_go" "question_002:pip_hello"; do
	shot "$K/interface-sounds/Audio/${pair%%:*}.ogg" "anull" "${pair##*:}.ogg"
	shot "$K/interface-sounds/Audio/${pair%%:*}.ogg" "$OUT" "${pair##*:}_out.ogg"
done

radio
sfx
music
du -ch ./*.ogg | tail -1
