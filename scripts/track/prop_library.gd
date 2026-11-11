class_name PropLibrary
extends Resource
## The canyon pack's rocks and plants, baked into one resource this project
## owns. Built by tools/bake_props.gd; see that file for why the pack is not
## loaded directly at runtime.

enum Kind { ROCK, PLANT, GRASS }

@export var names: PackedStringArray = PackedStringArray()
@export var kinds: PackedInt32Array = PackedInt32Array()
@export var meshes: Array[ArrayMesh] = []

func add(prop_name: String, kind: int, mesh: ArrayMesh) -> void:
	names.append(prop_name)
	kinds.append(kind)
	meshes.append(mesh)

## Indices of every mesh of one kind, in the order they were baked.
func of_kind(kind: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in kinds.size():
		if kinds[i] == kind:
			out.append(i)
	return out

func count_of(kind: int) -> int:
	return of_kind(kind).size()

func triangles_of(kind: int) -> int:
	var total := 0
	for i in of_kind(kind):
		total += triangles(i)
	return total

func triangles(index: int) -> int:
	if index < 0 or index >= meshes.size():
		return 0
	var mesh := meshes[index]
	var count := 0
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		count += (idx.size() if idx.size() > 0 else verts.size()) / 3
	return count

func aabb_of(index: int) -> AABB:
	if index < 0 or index >= meshes.size():
		return AABB()
	return meshes[index].get_aabb()
