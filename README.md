# Force Delete

Version 13 targets Surviving Mars: Relaunched **1.1.1.405907** on Windows.

Copy this folder into `%AppData%\Surviving Mars Relaunched\Mods\ForceDelete`, then enable **Force Delete** in the game's Mod Manager.

- **Ctrl+Delete:** force-delete standard demolishable objects, including stuck tracks.
- **Ctrl+Shift+Delete:** advanced deletion for colonists, deposits, decorations, domes, and live transport units.

Advanced dome deletion can cause crashes, as described in the mod's in-game description.

## Compatibility changes

Version 13 fixes the mod warning when removing domes connected to passages or passage hubs. Forced passage removal prevents recursive controller destruction and uses native cleanup without waiting for interrupted traversal commands. Colonist recovery releases passage registrations and old migration destinations. Rocket passenger unloading discards deleted domes from its saved destination list before choosing housing.

Dome deletion restarts the command system for surviving colonists, drones, rovers, and shuttles so they can choose their normal next actions. Drones retain surviving controllers; rover recovery retains their own repair/resource requests. Rocket cleanup also detaches and restarts surviving passengers and rovers. Units still need reachable housing, controllers, or available work to move.

The Services & Science update introduced meal reservations owned by colonists during visits and transport. Forced cleanup now returns those reservations before removing assignments or stopping command destructors, and uses native train-ticket cancellation before pruning stale references.

Shortcut bindings, selection hooks, and colonist compatibility guards are reinstalled when Lua reloads replace game classes or the message registry. Repeated registration remains idempotent. Older colonists without the meal-return API retain their existing cleanup path.

The latest gameplay patch is [1.1.1](https://store.steampowered.com/news/app/3215050/view/689769594581155952). The September 30 Steam patch addresses a Linux crash.

## Validation

Run `lua tests/compatibility.lua` from this directory with Lua 5.4. The 23 fixtures cover reserved meals, native ticket cancellation, older game APIs, shortcut/class/message-registry reloads, survivor recovery, recursive passage deletion, stale arrival destinations, and duplicate recovery scans. They do not connect to a running game.

Native validation used `MarsDebug.exe` revision 405907 and the supplied `United States of Mars.savegame.sav`, without saving the test colony. The scenario in `scenarios/dome_passage_cleanup.lua` deletes dome 1812 and its four passages, verifies one destruction per passage, and checks cleanup calls. A second dome (3341) was removed through the actual Ctrl+Shift+Delete shortcut, with no Lua errors or native assertions in the final test log. Run the scenario with the SMR harness after loading a fresh copy of that save in an isolated session. This is a targeted regression test, not exhaustive coverage of every deletion type.

The stale editor-generated code hash was removed. The Mod Editor calculates a fresh hash when saving the updated mod. Steam and Paradox publication IDs remain unchanged; a GitHub push does not update either marketplace.
