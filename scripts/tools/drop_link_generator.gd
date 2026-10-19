@tool
class_name DropLinkGenerator
extends Node3D
## Phase 2 item 12b-1b: an editor tool that proposes drop links (item 12b-1a) along the edges of a baked navmesh.
##
## Put this node in an arena (identity transform), set `region` to the NavigationRegion3D, bake the navmesh, then
## press "Generate drop links" in the Inspector. For every outer edge of a walkable area it samples points and
## looks for another walkable surface `landing_offset` m outward that is `min_drop` to `max_drop` m lower; where
## there is one it adds a one-way `NavigationLink3D` (navigation layer 2, the layer an enemy with `use_nav_links`
## takes) from the edge to that landing. It reads only the navmesh data, no physics.
##
## All generated links are children of this node and are saved in the scene. Generate and Clear remove only the
## NavigationLink3D children of this node, never links placed elsewhere by hand. Rebake after the geometry changes,
## then Generate again. `max_drop` must match `nav_drop_max_height` in the enemy's `ai` preset.

## The region whose baked navigation mesh is read. Required.
@export var region: NavigationRegion3D
## Shortest fall (m) that gets a link: just above the edge guard's depth (`edge_probe_depth`, 1.4), because an
## enemy already walks off anything lower.
@export var min_drop: float = 1.5
## Longest fall (m) that gets a link. Keep it equal to `nav_drop_max_height`.
@export var max_drop: float = 6.0
## No two generated links start closer than this (m).
@export var link_spacing: float = 4.0
## How far (m) outward from the mesh edge the landing is looked for. The mesh edge sits about one agent radius
## inside the real edge, so the default lands roughly 1 m past it.
@export var landing_offset: float = 1.5
@export_tool_button("Generate drop links", "NavigationLink3D") var _generate_button: Callable = generate
@export_tool_button("Clear generated links", "Remove") var _clear_button: Callable = clear

const LINK_LAYERS: int = 2 # the navigation layer an enemy with `use_nav_links` takes (EnemyNavigation.LINK_LAYER_BIT)
const SAMPLE_STEP: float = 0.5 # m between candidate points along an edge
const EPSILON: float = 0.001


## Removes the old generated links, then makes new ones from the region's current navigation mesh.
func generate() -> void:
	if not Engine.is_editor_hint():
		return
	if region == null:
		push_error("DropLinkGenerator: set `region` to the NavigationRegion3D first.")
		return
	var nav_mesh: NavigationMesh = region.navigation_mesh
	if nav_mesh == null or nav_mesh.get_polygon_count() == 0:
		push_error("DropLinkGenerator: the region has no baked navigation mesh. Bake it first.")
		return
	var scene_owner: Node = owner if owner != null else get_tree().edited_scene_root
	if scene_owner == null:
		push_error("DropLinkGenerator: the node must be inside the edited scene.")
		return
	clear()
	var verts: PackedVector3Array = nav_mesh.get_vertices()
	var polygons: Array[PackedInt32Array] = []
	var bounds: Array[Rect2] = []
	var edge_uses: Dictionary = {}
	for p in range(nav_mesh.get_polygon_count()):
		var poly: PackedInt32Array = nav_mesh.get_polygon(p)
		polygons.append(poly)
		var rect := Rect2(Vector2(verts[poly[0]].x, verts[poly[0]].z), Vector2.ZERO)
		for i in range(poly.size()):
			rect = rect.expand(Vector2(verts[poly[i]].x, verts[poly[i]].z))
			var key := _edge_key(poly[i], poly[(i + 1) % poly.size()])
			edge_uses[key] = int(edge_uses.get(key, 0)) + 1
		bounds.append(rect.grow(EPSILON))
	var region_to_local: Transform3D = global_transform.affine_inverse() * region.global_transform
	var starts: Array[Vector3] = []
	var no_landing: int = 0
	for poly in polygons:
		var centroid := Vector2.ZERO
		for index in poly:
			centroid += Vector2(verts[index].x, verts[index].z)
		centroid /= float(poly.size())
		for i in range(poly.size()):
			var ia: int = poly[i]
			var ib: int = poly[(i + 1) % poly.size()]
			if int(edge_uses[_edge_key(ia, ib)]) != 1:
				continue # shared with another polygon: not an outer edge
			var a: Vector3 = verts[ia]
			var b: Vector3 = verts[ib]
			var edge := Vector2(b.x - a.x, b.z - a.z)
			var length: float = edge.length()
			if length < 0.01:
				continue
			var outward := Vector2(-edge.y, edge.x) / length
			if outward.dot(centroid - Vector2(a.x, a.z)) > 0.0:
				outward = -outward # always points away from the polygon
			var steps: int = maxi(int(floorf(length / SAMPLE_STEP)), 1)
			for s in range(steps):
				var entry: Vector3 = a.lerp(b, (float(s) + 0.5) / float(steps))
				if _near_any(entry, starts, link_spacing):
					continue
				var landing_xz: Vector2 = Vector2(entry.x, entry.z) + outward * landing_offset
				var landing_y: float = _surface_below(landing_xz, entry.y, verts, polygons, bounds)
				if is_nan(landing_y):
					no_landing += 1
					continue
				starts.append(entry)
				var link := NavigationLink3D.new()
				link.navigation_layers = LINK_LAYERS
				link.bidirectional = false
				add_child(link, true)
				link.owner = scene_owner
				link.start_position = region_to_local * entry
				link.end_position = region_to_local * Vector3(landing_xz.x, landing_y, landing_xz.y)
	if not starts.is_empty():
		EditorInterface.mark_scene_as_unsaved()
	print("DropLinkGenerator: made %d drop links (%d edge samples had no lower walkable ground)." % [starts.size(), no_landing])


## Removes the NavigationLink3D children of this node (the generated links) and nothing else.
func clear() -> void:
	if not Engine.is_editor_hint():
		return
	var removed: int = 0
	for child in get_children():
		if child is NavigationLink3D:
			remove_child(child)
			child.queue_free()
			removed += 1
	if removed > 0:
		EditorInterface.mark_scene_as_unsaved()
		print("DropLinkGenerator: cleared %d generated links." % removed)


func _edge_key(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a, b), maxi(a, b))


func _near_any(point: Vector3, others: Array[Vector3], distance: float) -> bool:
	for other in others:
		if point.distance_to(other) < distance:
			return true
	return false


## The height of the nearest navmesh surface below `from_y` at `xz` that lies `min_drop` to `max_drop` lower, or NAN.
func _surface_below(xz: Vector2, from_y: float, verts: PackedVector3Array, polygons: Array[PackedInt32Array],
		bounds: Array[Rect2]) -> float:
	var best_drop: float = INF
	for p in range(polygons.size()):
		if not bounds[p].has_point(xz):
			continue
		var poly: PackedInt32Array = polygons[p]
		for i in range(1, poly.size() - 1):
			var y: float = _triangle_y(xz, verts[poly[0]], verts[poly[i]], verts[poly[i + 1]])
			if is_nan(y):
				continue
			var drop: float = from_y - y
			if drop >= min_drop and drop <= max_drop and drop < best_drop:
				best_drop = drop
	return from_y - best_drop if best_drop < INF else NAN


## The height of the triangle (a, b, c) at `p` on the ground plane (x, z), or NAN when `p` is outside it.
func _triangle_y(p: Vector2, a: Vector3, b: Vector3, c: Vector3) -> float:
	var pa := Vector2(a.x, a.z)
	var pb := Vector2(b.x, b.z)
	var pc := Vector2(c.x, c.z)
	var d: float = (pb.y - pc.y) * (pa.x - pc.x) + (pc.x - pb.x) * (pa.y - pc.y)
	if absf(d) < 0.000001:
		return NAN
	var w1: float = ((pb.y - pc.y) * (p.x - pc.x) + (pc.x - pb.x) * (p.y - pc.y)) / d
	var w2: float = ((pc.y - pa.y) * (p.x - pc.x) + (pa.x - pc.x) * (p.y - pc.y)) / d
	var w3: float = 1.0 - w1 - w2
	if w1 < -EPSILON or w2 < -EPSILON or w3 < -EPSILON:
		return NAN
	return w1 * a.y + w2 * b.y + w3 * c.y
