# Godot 4.7 on the web: what audio can and cannot do (excerpts)
Fetched 2026-11-12 with curl from godot-docs branch 4.7 and the engine source at tag 4.7.2-stable.

## tutorials/export/exporting_for_web.rst, "Audio playback"
URL: https://raw.githubusercontent.com/godotengine/godot-docs/4.7/tutorials/export/exporting_for_web.rst
- "Since Godot 4.3, audio playback is done using the Web Audio API on the web platform. This **Sample** playback mode allows for low latency even when the project is exported without thread support, but it has several limitations:"
  - "AudioEffects are not supported."
  - "Reverberation and doppler effects are not supported."
  - "Procedural audio generation is not supported."
  - "Positional audio may not always work correctly depending on the node's properties."
- "To use Godot's own audio playback system on the web platform, you can change the default playback mode ... or change the **Playback Type** property to **Stream** on an AudioStreamPlayer ... This leads to increased latency (especially when thread support is disabled), but it allows the full suite of Godot's audio features to work."
- "Some browsers restrict autoplay for audio on websites. The easiest way around this limitation is to request the player to click, tap or press a key/button to enable audio"
- "Please note that audio effects aren't yet implemented for samples."

## class_projectsettings.rst, audio/general/default_playback_type.web = 1 (Sample)
- "**Sample** allows for lower latency on the web platform at the cost of flexibility (AudioEffects are not supported)."
- "**Warning:** Forcing **Stream** on the Web platform may cause high audio latency and crackling, especially when exporting a multi-threaded game."

## Engine source: platform/web/js/libs/library_godot_audio.js (4.7.2-stable)
URL: https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/platform/web/js/libs/library_godot_audio.js
- A sample node keeps a playback rate and a pitch scale (`setPitchScale`, `_syncPlaybackRate`).
- `class Bus` has `setVolumeDb`, `setSend`, `mute`, `solo` (gain nodes). No filter nodes. So in a web build a bus can fade, mute and route, and a player can change pitch, but a low-pass must be baked into the file.

## class_audiostreamplayer3d.rst
- `attenuation_filter_cutoff_hz` = 5000.0, `attenuation_filter_db` = -24.0 (a distance high-cut; it is an effect, so expect it to be skipped in Sample mode on the web).
