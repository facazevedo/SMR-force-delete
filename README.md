# Force Delete

Version 11 targets Surviving Mars: Relaunched **1.1.1.405907** on Windows.

Copy this folder into `%AppData%\Surviving Mars Relaunched\Mods\ForceDelete`, then enable **Force Delete** in the game's Mod Manager.

- **Ctrl+Delete:** force-delete standard demolishable objects, including stuck tracks.
- **Ctrl+Shift+Delete:** advanced deletion for colonists, deposits, decorations, domes, and live transport units.

Advanced dome deletion can cause crashes, as described in the mod's in-game description.

## Compatibility changes

The Services & Science update introduced meal reservations owned by colonists during visits and transport. Forced cleanup now returns those reservations before removing assignments or stopping command destructors, and uses native train-ticket cancellation before pruning stale references.

Shortcut bindings, selection hooks, and colonist compatibility guards are reinstalled when Lua reloads replace game classes or the message registry. Repeated registration remains idempotent. Older colonists without the meal-return API retain their existing cleanup path.

The latest gameplay patch is [1.1.1](https://store.steampowered.com/news/app/3215050/view/689769594581155952). The September 30 Steam patch addresses a Linux crash.

## Validation

Run `lua tests/compatibility.lua` from this directory with Lua 5.4. The fixtures cover reserved meals, native ticket cancellation, older game APIs, shortcut rebuilds, replacement classes, and message-registry reloads. They do not connect to a running game.

Compatibility APIs were checked against the installed ModTools source. The installed game's log reports Lua revision 405907 and build 1.1.1.405907. Full in-game regression testing on that build is pending; the existing game session was left untouched. Earlier in-game testing was on 1.0.7.

The stale editor-generated code hash was removed. The Mod Editor calculates a fresh hash when saving the updated mod. Steam and Paradox publication IDs remain unchanged; a GitHub push does not update either marketplace.
