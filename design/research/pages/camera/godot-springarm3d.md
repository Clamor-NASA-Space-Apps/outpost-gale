# Godot SpringArm3D class reference (4.7)
https://raw.githubusercontent.com/godotengine/godot-docs/4.7/classes/class_springarm3d.rst
Fetched 14 Nov 2026 (WebFetch, quoted passages)

- "SpringArm3D casts a ray or a shape along its Z axis and moves all its direct children to the collision point, with an optional margin. This is useful for 3rd person cameras that move closer to the player when inside a tight space (you may need to exclude the player's collider from the SpringArm3D's collision check)."
- margin: "When the collision check is made, a candidate length for the SpringArm3D is given. The margin is then subtracted to this length and the translation is applied to the child objects of the SpringArm3D."
- shape: "When the shape is set, the SpringArm3D will cast the Shape3D on its z axis instead of performing a ray cast."
- get_hit_length: "Returns the spring arm's current length."
Note: no smoothing in the node itself; it snaps to the hit each physics frame.
