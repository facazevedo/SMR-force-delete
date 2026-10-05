-- Run from the mod root: lua tests/compatibility.lua
-- Isolated engine fixtures; these tests never connect to a running game.
local failures, passed = 0, 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed = passed + 1
		print("PASS " .. name)
	else
		failures = failures + 1
		print("FAIL " .. name .. ": " .. tostring(err))
	end
end

local function new_messages()
	local handlers = {}
	local registry = setmetatable({}, { __newindex = function(_, name, fn)
		handlers[name] = handlers[name] or {}
		table.insert(handlers[name], fn)
	end })
	return registry, function(name, ...)
		for _, fn in ipairs(handlers[name] or {}) do fn(...) end
	end
end

OnMsg, Msg = new_messages()
function IsValid(obj) return type(obj) == "table" and not obj.deleted end
function IsKindOf(obj, class) return obj.class == class end
function IsValidPos(obj) return IsValid(obj) end
function IsValidThread() return false end
local host = { actions = {} }
function host:ActionById(id) return self.actions[id] end
XShortcutsTarget = host
XAction = {}
function XAction:new(action, parent)
	assert(not parent.actions[action.ActionId], "duplicate action")
	parent.actions[action.ActionId] = action
	return action
end
GameShortcuts = { Init = function() return "base result" end }
function RequestUnassignUnit() return "original request" end
Colonist = {
	ExitVehicle = function() return "original exit" end,
	EnterBuilding = function() return "original entry" end,
}
dofile("Code/ForceDelete.lua")
dofile("Code/fd_config.lua")
dofile("Code/fd_colonist.lua")
local FD = ForceDelete

local function colonist_fixture(with_meal_api)
	local colonist = { class = "Colonist", meal_amount = 1000, command = "VisitService" }
	function colonist:SetWorkplace() assert(self.meal_amount == 0, "meal reservation leaked") end
	function colonist:SetCommand(command) self.command = command end
	function colonist:delete() self.deleted = true end
	function colonist:DiscardTransportTicket()
		self.ticket_discarded = true
		self.transport_ticket = false
	end
	if with_meal_api then
		function colonist:ReturnOutstandingMeal()
			self.returned_meal = (self.returned_meal or 0) + self.meal_amount
			self.meal_amount = 0
		end
	else
		colonist.meal_amount = 0
	end
	return colonist
end

test("related-object deletion returns a reserved meal before detaching", function()
	local obj = colonist_fixture(true)
	assert(FD.Colonist.IdleForRelatedObjectDelete(obj))
	assert(obj.returned_meal == 1000, "reserved food was not returned")
	assert(obj.command == "Idle")
end)
test("colonist deletion returns a reserved meal before detaching", function()
	local obj = colonist_fixture(true)
	assert(FD.Colonist.Delete(obj))
	assert(obj.returned_meal == 1000, "reserved food was not returned")
	assert(obj.deleted)
end)
test("transport cleanup invokes the native ticket cancellation", function()
	local obj = colonist_fixture(false)
	local station = { waiting_for_train = { obj }, colonists_inbound = { obj } }
	local vehicle = { units = { obj } }
	obj.transport_ticket = { src_station = station, dst_station = station, vehicle = vehicle }
	assert(FD.Colonist.IdleForRelatedObjectDelete(obj))
	assert(obj.ticket_discarded, "native ticket cleanup was skipped")
	assert(#station.waiting_for_train == 0 and #station.colonists_inbound == 0)
	assert(#vehicle.units == 0 and obj.transport_ticket == false)
end)
test("older colonists without the meal API still reset", function()
	assert(FD.Colonist.IdleForRelatedObjectDelete(colonist_fixture(false)))
end)
test("shortcut rebuild registers once and preserves the base initializer", function()
	host.actions = {}
	assert(GameShortcuts:Init(host) == "base result")
	FD.PatchGameShortcuts(host)
	Msg("Shortcuts", host)
	Msg("ShortcutsReloaded")
	local count = 0
	for _ in pairs(host.actions) do count = count + 1 end
	assert(count == 2)
end)
test("replacement shortcut class receives both actions", function()
	GameShortcuts = { Init = function() return "new base" end }
	FD.PatchGameShortcuts()
	local new_host = { actions = {}, ActionById = host.ActionById }
	assert(GameShortcuts:Init(new_host) == "new base")
	assert(new_host.actions[FD.LVL1_ACTION_ID] and new_host.actions[FD.LVL2_ACTION_ID], "replacement initializer was not patched")
end)
test("selection hooks are reinstalled when the message registry changes", function()
	OnMsg, Msg = new_messages()
	local calls = 0
	FD.RefreshSelectionDiagnostics = function() calls = calls + 1 end
	FD.InstallSelectionHooks()
	FD.InstallSelectionHooks()
	Msg("SelectedObjChange")
	assert(calls == 1, "selection handler missing or duplicated")
end)
test("replacement engine methods receive compatibility guards", function()
	Colonist.ExitVehicle = function() return "new exit" end
	Colonist.EnterBuilding = function() return "new entry" end
	RequestUnassignUnit = function() return "new request" end
	FD.Colonist.PatchExitVehicle()
	FD.Colonist.PatchEnterBuilding()
	FD.PatchRequestUnassignUnit()
	assert(Colonist.ExitVehicle({ class = "Colonist" }, false) == false, "replacement exit is unguarded")
	assert(Colonist.EnterBuilding({}, false) == false, "replacement entry is unguarded")
	assert(RequestUnassignUnit(false) == false, "replacement request is unguarded")
	assert(RequestUnassignUnit({ UnassignUnit = function() end }) == "new request")
end)
test("reloaded colonist module reinstalls lifecycle hooks without duplicates", function()
	OnMsg, Msg = new_messages()
	Colonist.ExitVehicle = function() return "reloaded exit" end
	Colonist.EnterBuilding = function() return "reloaded entry" end
	dofile("Code/fd_colonist.lua")
	dofile("Code/fd_colonist.lua")
	-- Classes can be regenerated after mod code is loaded.
	Colonist.ExitVehicle = function() return "finalized exit" end
	Colonist.EnterBuilding = function() return "finalized entry" end
	Msg("ClassesPostprocess")
	assert(Colonist.ExitVehicle({}, false) == false)
	assert(Colonist.EnterBuilding({}, false) == false)
	local wrapped = Colonist.EnterBuilding
	Msg("DataLoaded")
	assert(Colonist.EnterBuilding == wrapped, "guard was wrapped twice")
end)

print(string.format("%d passed, %d failed", passed, failures))
os.exit(failures == 0 and 0 or 1)
