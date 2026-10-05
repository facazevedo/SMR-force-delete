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
