# Advanced Third Person Camera (UE plugin) docs: Camera Volumes, Object Fading
https://forrgit.gitbook.io/advanced-third-person-camera/advanced-camera-techniques/camera-volumes
https://forrgit.gitbook.io/advanced-third-person-camera/advanced-camera-techniques/object-fading
Fetched 14 Nov 2026 (WebFetch, quoted passages)

- "Camera Volumes are specialized Actor objects you place in your level" "to define regions where a particular camera mode should be active."
- "you might create a Camera Volume around a narrow corridor to trigger a more claustrophobic camera mode"
- bChangeCameraModeWithInterp "controls whether the camera mode transition is interpolated (smooth) or instant."
- Fading: "When the fading system detects an obstruction, it will smoothly lerp the "Opacity" parameter between 0 and 1"
- FadeChannel: "Specifies the collision channel used for line traces to detect objects between the camera and the character."
- "Enables fading for the character itself when the camera collides with it."
