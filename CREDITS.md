# Credits

## Third-party assets

**Canyon Set** — rocks and plants scattered along the canyon rim and the foot
of the walls. By Loafbrr (https://loafbrr.itch.io/), released under CC0.
Attribution is not required by that licence; it is given here and on the title
screen because the work is theirs.

The pack ships Godot scenes that depend on the Terrain3D and Proton Scatter
plugins. Neither is used: the meshes are lifted out of those scenes once by
`tools/bake_props.gd` and written to `resources/canyon_props.tres`, and the
game scatters them with its own code. The pack's own HDRI (from Poly Haven),
its terrain tile library and its demo scenes are not shipped.

The pack itself is not kept in this repository - it is an input, and the
baked resource is the deliverable. To re-bake it, unzip the Godot version of
the pack to `assets/LoafbrrAssets/`, replace `res://Assets/` with
`res://assets/` throughout it (same length, so it is safe to do to the
binary .material files as well) and run `tools/bake_props.gd`.

**Free Warp Drive Effects** — VOiD1 Gaming. None of the Unity files are used;
the effect is rebuilt in Godot from the package's particle settings.

**Space fighter model** and **laser beam sheet** — supplied by the project
owner for use in this game.

## Generated

The canyon wall and floor textures were generated for this project with
Higgsfield, the wall one from a reference photograph of Antelope Canyon.

Everything else - the canyon geometry, the strata, the flight model, the
audio, the HUD - is produced in code by this project.
