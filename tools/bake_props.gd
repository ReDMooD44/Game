extends SceneTree
## Bakes the canyon pack's rocks and plants into one resource the game owns.
##
## The pack ships its meshes inside .tscn scenes that point at compressed
## .material files, and those hold the shader path the pack was authored with:
## res://Assets, capital A. Android is case sensitive, so every one of them
## would fail to load on a phone while looking perfectly fine on Windows.
## Re-saving the materials does not clear it - the path is baked into the
## compressed resource.
##
## So nothing from the pack is loaded at runtime. The meshes are lifted out
## here, once, and written to resources/canyon_props.tres with materials this
## project builds itself from the pack's plain texture files. The pack folder
## is then excluded from the export, which also keeps 47 MB out of the APK.

const OUT := "res://resources/canyon_props.tres"
const BASE := "res://assets/LoafbrrAssets/CanyonSet/scenes/"

## Folder -> which of the three looks its meshes should be given.
const GROUPS := {
	"rocks/rock_boulders": PropLibrary.Kind.ROCK,
	"rocks/rock_formation": PropLibrary.Kind.ROCK,
	"rocks/rock_platforms": PropLibrary.Kind.ROCK,
	"Plants/cactus": PropLibrary.Kind.PLANT,
	"Plants/tree": PropLibrary.Kind.PLANT,
	"Plants/sticks": PropLibrary.Kind.PLANT,
	"Plants/Grass": PropLibrary.Kind.GRASS,
	"Plants/leafs": PropLibrary.Kind.GRASS,
}

func _init() -> void:
	var lib := PropLibrary.new()
	for folder in GROUPS:
		var kind: int = GROUPS[folder]
		# Dictionary keys come back untyped, which makes everything downstream
		# a Variant and the parser refuse to infer.
		var dir: String = BASE + str(folder)
		var d := DirAccess.open(dir)
		if d == null:
			print("MISSING ", dir)
			continue
		var files := []
		for f in d.get_files():
			if f.ends_with(".tscn"):
				files.append(f)
		files.sort()
		for f in files:
			var packed: PackedScene = load(dir + "/" + f)
			if packed == null:
				continue
			var root := packed.instantiate()
			var mesh := _flatten(root)
			root.free()
			if mesh == null or mesh.get_surface_count() == 0:
				continue
			lib.add(f.replace(".tscn", ""), kind, mesh)
	var err := ResourceSaver.save(lib, OUT)
	print("baked %d props -> %s (%s)" % [lib.meshes.size(), OUT, "ok" if err == OK else str(err)])
	for k in [PropLibrary.Kind.ROCK, PropLibrary.Kind.PLANT, PropLibrary.Kind.GRASS]:
		print("  kind %d: %d meshes, %d triangles"
			% [k, lib.count_of(k), lib.triangles_of(k)])
	quit()

## Collapses a scene's MeshInstance3D nodes into one ArrayMesh with the node
## transforms baked in, dropping the pack's own materials: the game assigns
## its own, so nothing has to resolve a res://Assets path on a phone.
func _flatten(root: Node) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for entry in _mesh_nodes(root, Transform3D.IDENTITY):
		var mi: MeshInstance3D = entry[0]
		var xf: Transform3D = entry[1]
		var m: Mesh = mi.mesh
		for s in m.get_surface_count():
			var arrays: Array = m.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if verts.is_empty():
				continue
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if idx.is_empty():
				idx = PackedInt32Array(range(verts.size()))
			for i in idx:
				if i < uvs.size():
					st.set_uv(uvs[i])
				if i < normals.size():
					st.set_normal((xf.basis * normals[i]).normalized())
				st.add_vertex(xf * verts[i])
			any = true
	if not any:
		return null
	st.index()
	return st.commit()

func _mesh_nodes(node: Node, parent: Transform3D) -> Array:
	var here := parent
	if node is Node3D:
		here = parent * node.transform
	var out := []
	if node is MeshInstance3D and node.mesh != null:
		out.append([node, here])
	for c in node.get_children():
		out.append_array(_mesh_nodes(c, here))
	return out
