# [UE5] Building a Third-Person Camera with Spring Arm: Follow, Wall Avoidance, and Over-the-Shoulder (uhiyama-lab)
https://uhiyama-lab.com/en/notes/ue/camera-spring-arm-guide/
Fetched 14 Nov 2026 (WebFetch, quoted passages). Epic's own pages (dev.epicgames.com, docs.unrealengine.com, unrealengine.com) failed TLS verification from this machine, so this third-party guide stands in.

- Do Collision Test: "checks for obstacles from the arm's base to where the camera wants to be"
- Probe Size: "Radius of the test sphere. 12 cm here"
- Probe Channel: "The channel asking walls "do you stop the camera?""
- Camera Lag Speed: "Above 0, larger catches up faster. `0` is the exception, meaning no lag"
- Shoulder: "set CameraBoom's `Socket Offset` to `(X=0, Y=55, Z=30)`. With a level camera, that shifts 55 cm right and 30 cm up."
- ""Just entering a narrow corridor" may change nothing, because no wall enters the camera's path."
- "Once the wall is gone, the arm can extend back to the configured length."
- "The over-the-shoulder switch changes length and Offset from the same Alpha."
