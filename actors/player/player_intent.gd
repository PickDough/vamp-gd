struct_name PlayerIntent:
## What the player wants to do this physics frame, read from input: the direction to move in and whether to jump.
	var direction: Vector3 = Vector3.ZERO
	var jump: bool = false
