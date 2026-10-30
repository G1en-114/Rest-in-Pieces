# Photo Characters Implementation Plan

> **For agentic workers:** Use subagent-driven-development to implement and review the tasks below.

**Goal:** 用户在游戏中使用自己的 AHOLO API key，从照片生成可游玩的角色，并获得准确的作品描述。

**Architecture:** Native Godot HTTP client → character workshop → validated character cache and visual adapters. Existing gameplay physics remains authoritative. Stable autoload handles model cache across scene reloads; network exchanges only validated GLB data.

**Tech Stack:** Godot 4.7.2, GDScript, Python standard-library fixture HTTP servers.

**Spec:** `docs/superpowers/specs/2026-10-26-photo-characters-design.md`

## Global Constraints

- User supplies their own API key, kept only in memory and never sent to peers.
- No extra runtime dependencies or backend deployment.
- Keep existing uncommitted changes and user artifacts.
- Do not submit paid API calls during development without an actual user image.
- Preserve six corpse bodies and existing snapshot order.

### Task 1: Native API pipeline

Files: `game/scripts/lux3d_client.gd`, API fixture tests under `tools/tests` or `game/tests`.

Produces `class_name Lux3DClient extends Node`, `progress(message: String)`, `task_created(task_id: String, stage: String)`, async `generate(image_path: String, api_key: String, region := "cn", resume_id := "", resume_stage := "generate") -> Dictionary` returning `{ok, data}` on success or `{ok, error}`. `cancel()` stops local waiting only. API endpoints and upload protocol must match installed official SDK and current official docs. Task stages are `generate` and `rig`.

- [ ] Run failing local HTTP fixture pipeline test.
- [ ] Implement OUS upload, async creation/polling, automatic rigging, bounded GLB download, safe error messages, resume and cancellation.
- [ ] Run fixture success, failure, cancellation and resume checks without real API calls.

### Task 2: Model cache and physics visual adapters

Files: `game/scripts/character_models.gd`, optional helper, `bearer.gd`, `corpse.gd`, Godot tests.

Produces autoload `Characters`: signal `changed(target: String)`, methods `set_model(target: String, data: PackedByteArray) -> String` (empty means success), `get_model(target: String) -> PackedByteArray`, `clear_model(target: String)`, `make_model(target: String) -> Node3D`. Targets `player1`, `player2`, `corpse`. `Bearer` has `character_slot` string set before add_child. Cache in `user://characters`. Validate GLB and bone compatibility before replacing old data. Both new bearers and existing nodes listen to changes and apply visuals. Default asset is fallback. Keep body/render-layer and corpse ragdoll contracts.

- [ ] Demonstrate missing runtime customization in a Godot test using the packaged humanoid GLB.
- [ ] Implement cache, validation, normalized appearance, bearer swapping and corpse bone driving.
- [ ] Check valid/custom/corrupt inputs, unchanged rigid-body counts, rendering layers and restoration.

### Task 3: Character workshop UI

Files: `game/scripts/character_workshop.gd`, `menu.gd`.

Produces `class_name CharacterWorkshop extends Control`, a persistent root overlay instantiated by Main. `open()` and signal `closed`; `busy` generation state lives outside menu pages. Menu emits `customize` and provides title button C. UI uses Lux3DClient and Characters contracts above. Includes target selection, masked key entry, region, native photo picker/preview, progress, generate-and-rig button, resume, local cancel, cache reset and GLB import. Returns to menu without losing active task. No key persistence.

- [ ] Implement native Godot controls following existing typography and palette.
- [ ] Check generation state, duplicate-submit prevention, failure/resume and cache reset.

### Task 4: Integration, model-only network sync and descriptions

Files: `project.godot`, `main.gd`, new model sync module if needed, `README.md`, Lux3D integration notes and submission Markdown.

- [ ] Register Characters autoload, create workshop, wire menu and assign bearer slots.
- [ ] Synchronize validated models over bounded reliable chunks; authenticate sender role; keep API key local. Keep autoload RPC node stable across reloads. Update network version.
- [ ] Run import, model, UI and API tests; dual-player, solo, default and customized network smoke checks.
- [ ] Write short and full Chinese work descriptions and update implementation status honestly.

## Execution record

Ruling: implement in current `feature/levels` checkout because prior-turn changes are uncommitted and form the integration baseline; preserve them rather than creating a checkout without them. User has authorized implementation and selected user-provided API keys. No commit, push or paid generation is part of this request.

### Verification update — 2026-10-27

- API pipeline, cache/adapters, workshop and runtime wiring are implemented. Pending-create stages are saved before billable POSTs; manual platform task-ID recovery is now available in the workshop.
- Python discovery: 22 tests passed (CLI, native API fixtures and real ENet model exchange). Native model adapter: 47 checks passed. Native workshop state/input/persistence tests passed.
- The workshop and duo gameplay started cleanly using the real OpenGL renderer. Single-player testing identified the same pre-tree debug-log access already fixed for duo; guarded its logger as well.
- Network fixture uses two independent SceneMultiplayer/ENet instances in one engine because this environment serializes startup of separate Godot engines. It validates chunking, sender roles, reset/default exchange and separation of local versus session choices; it does not claim a remote Internet session was tested.
- No real photo or paid platform generation was submitted. Existing exported EXE/ZIP files have not been rebuilt; use the current source project via play.bat.
