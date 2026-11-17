trait_name HitReactive
extends Node3D

## Something an OnHitEffect can react with: it takes impulses (knockback) and shows a tint (hit flashes, white for
## none). The adopter overrides both.


func apply_impulse(_impulse: Impulse) -> void:
	push_error("%s doesn't implement HitReactive.apply_impulse" % name)


func show_tint(_color: Color) -> void:
	push_error("%s doesn't implement HitReactive.show_tint" % name)
