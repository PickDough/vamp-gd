class_name TreeQuery

## Lookups for nodes whose place in the tree isn't known in advance, such as spawned nodes: a depth-first search
## from a node (itself included) for the first node of a type, optionally with an exact name. A script's own
## children use typed @onready variables instead.


static func find_under(node: Node?, type: Variant, name: String? = null) -> Node?:
	if node == null:
		return null
	if is_instance_of(node, type) and (name == null or node.name == name):
		return node

	for child in node.get_children():
		var found: Node? = find_under(child, type, name)
		if found != null:
			return found

	return null
