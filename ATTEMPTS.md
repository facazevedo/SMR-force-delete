# Compatibility work

## 2026-10-05 - Game 1.1.1 compatibility

Compared official Steam announcements and local ModTools APIs with the version 10 payload. The installed retail log `Mars.exe-20261005-12.36.21-6aad2d75.log` reports Lua revision 405907 and build 1.1.1.405907.

Six of eight initial isolated Lua regressions failed before changes: reserved meals were not returned by forced colonist cleanup, native ticket cancellation was skipped, and replaced shortcut classes, selection-message registries, and engine methods lost their hooks or guards. Added a ninth regression for reloaded colonist lifecycle handlers. All nine pass after the fixes.

The live harness reports an untracked game process on its debug port; read-only state access refused the connection. No deployment, game reload, process termination, or in-game deletion was attempted. Full in-game validation remains pending. Supply pods already inherit supported rocket classes and did not need a detection change.

Incremented mod version to 11, recorded the current target build honestly, retained the minimum Lua revision and marketplace IDs, and removed the stale editor-generated code hash for recalculation by the Mod Editor.
