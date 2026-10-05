# Compatibility work

## 2026-10-05 - Game 1.1.1 compatibility

Compared official Steam announcements and local ModTools APIs with the version 10 payload. The installed retail log `Mars.exe-20261005-12.36.21-6aad2d75.log` reports Lua revision 405907 and build 1.1.1.405907.

Six of eight initial isolated Lua regressions failed before changes: reserved meals were not returned by forced colonist cleanup, native ticket cancellation was skipped, and replaced shortcut classes, selection-message registries, and engine methods lost their hooks or guards. Added a ninth regression for reloaded colonist lifecycle handlers. All nine pass after the fixes.

The live harness reports an untracked game process on its debug port; read-only state access refused the connection. No deployment, game reload, process termination, or in-game deletion was attempted. Full in-game validation remains pending. Supply pods already inherit supported rocket classes and did not need a detection change.

Incremented mod version to 11, recorded the current target build honestly, retained the minimum Lua revision and marketplace IDs, and removed the stale editor-generated code hash for recalculation by the Mod Editor.

## 2026-10-05 - Units staying still after dome deletion

User reported that surviving units no longer moved after deleting a dome. Nine additional regressions failed against version 11: stop-only cleanup did not start new command threads for drones, rovers, or shuttles; rocket cleanup restarted only drones; dome cleanup omitted rovers; healthy drone controllers and rover repair requests were discarded; colonist position checks ignored the object's native IsValidPos method; stale uninterruptable state and a sparse thread array could prevent restart.

Version 12 clears stopped-command state, checks native object positions, releases physical attachment/holder state, and starts fresh Idle commands for survivors. Dome cleanup includes affected rovers, retains healthy drone controllers, and leaves unrelated units alone. A complete dome deletion fixture verifies survivor command threads after removal. All 19 isolated tests pass.

The harness again reports untracked debug-game sessions. No live session was reloaded, interrupted, or used for deletion tests. Full native gameplay validation remains pending; source files are deployed for the user's next game restart.

## 2026-10-05 - Passage deletion warning on United States of Mars

The user's retail log `Mars.exe-20261005-13.45.57-6aad2d75.log` flags Force Delete v12. Its stack enters Passage destruction through DeletePassageSequentially -> DeleteObjectDirect and subsequently calls GetMap/ClearFlags on a destroyed native object. PassageGridElement:Done can recursively delete its controller when the last segment goes away. Native PassageBase:OnDemolish normally sets CanDelete to false, but waits for hub evacuation before installing that guard. Force Delete's fallback skipped it.

Version 13 guards direct PassageBase destruction before invoking native Done. Advanced dome cleanup uses that path directly instead of entering the native evacuation wait after stopping colonist commands. Interrupted traversal registrations and migration destinations are released. A ChooseDome wrapper filters invalid objects from the destination snapshots retained by rocket unloading; the populated save exposed native scoring and arrival errors after deletion without that guard. Valid destination lists and native return values are preserved.

Used only harness-owned `C:\Games\Surviving Mars Relaunched\MarsDebug.exe` processes, revision 405907. Loaded `United States of Mars.savegame.sav` in memory; both original save files retain their pre-test timestamp (2026-10-05 00:35:33 UTC) and size (75,780,411 bytes). No test save was written. The initial real-time scenario stalled in native passage hub evacuation. A plain Lua coroutine was also tried, but causes native thread assertions and instruction-limit errors and is not a valid substitute for shortcut execution; it was removed from the scenario.

The final native scenario removes dome 1812 and passages 3032, 3053, 3160, 3249, with exactly one controller destruction each and zero failed cleanup calls. Continued simulation exposed stale rocket destinations; after filtering them, no colonists retained invalid emigration destinations. Actual Ctrl+Shift+Delete testing on dome 3341 additionally exposed excessive repeated predicates across overlapping city labels. Marking every examined candidate, including nonmatches, reduces this work and lets the shortcut complete. The final shortcut removed dome 3341 (nine domes became eight). Its flushed log contains zero Lua errors, native assertions, or mod warnings. Test artifacts remain in ignored `.harness/`; the reusable native scenario is under `scenarios/`.

All 23 isolated regressions pass. New tests were observed failing before their respective fixes (recursive controller deletion, stale destination selection, migration cleanup, and duplicate candidate evaluation). This validates the reported populated-save path, not every advanced deletion case.
