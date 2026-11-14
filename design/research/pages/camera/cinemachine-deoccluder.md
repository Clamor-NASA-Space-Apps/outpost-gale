# Cinemachine Deoccluder (3.1) and Cinemachine Collider (2.8)
https://docs.unity3d.com/Packages/com.unity.cinemachine@3.1/manual/CinemachineDeoccluder.html
https://docs.unity3d.com/Packages/com.unity.cinemachine@2.8/manual/CinemachineCollider.html
Fetched 14 Nov 2026 (WebFetch, quoted passages)

## 3.1 Deoccluder
- Pull Camera Forward: "Move the camera forward along its Z axis until it is in front of the obstacle that is nearest to the target."
- Preserve Camera Height: "Move the camera to an alternate point of view while attempting to keep the camera at its original height."
- Preserve Camera Distance: "Move the camera to an alternate point of view while attempting to keep the camera at its original distance from the target."
- Damping: "How quickly to return the camera to its normal position after an occlusion has gone away."
- Damping When Occluded: "How quickly to move the camera to avoid an obstacle."
- Smoothing Time: "Minimum number of seconds to hold the camera at the nearest point to the target."
- Minimum Distance From Target: "Ignore obstacles that are less than this distance from the target's pivot point."
- Camera Radius: "Distance to maintain from any obstacle."
- Minimum Occlusion Time: "Do not take action unless the occulsion has lasted at least this long." (sic)
- Transparent Layers: "Objects on these layers will never obstruct the view of the target."

## 2.8 Collider (same component, older name)
- "It post-processes the final position of the Virtual Camera to attempt to preserve the line of sight"
- Camera Radius: "Distance to maintain from any obstacle. Try to keep this value small for best results." "Increase it if you are seeing inside obstacles due to a large FOV on the camera."
- Smoothing Time: "Can be used to reduce excess camera movement in environments with lots of obstacles."
- Damping / Damping When Occluded: "Small numbers make the camera more responsive." "Larger numbers make the camera respond more slowly."
