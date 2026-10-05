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

dofile("Code/fd_drone.lua")
dofile("Code/fd_rover.lua")
dofile("Code/fd_shuttle.lua")
dofile("Code/fd_rocket.lua")
dofile("Code/fd_dome.lua")

local function mobile_fixture(class)
	local obj = { class = class, command = "Work", command_thread = { running = true }, uninterruptable_importance = 10 }
	function obj:IsValidPos() return not self.invalid_position end
	function obj:GetPos() return self.invalid_position and false or { point = true } end
	function obj:SetPos(pos) self.position = pos; self.invalid_position = false end
	function obj:GetParent() return self.parent end
	function obj:Detach() self.parent = false end
	function obj:SetHolder(holder) self.holder = holder; self.holder_released = true end
	function obj:SetCommand(command)
		assert(not self.uninterruptable_importance, "stale uninterruptable command")
		assert(not self:GetParent(), "unit still physically attached")
		self.command = command
		self.command_thread = { running = true, command = command }
		self.new_command_started = true
		return true
	end
	return obj
end
function IsValidThread(thread) return type(thread) == "table" and thread.running end
function DeleteThread(thread) thread.running = false end

test("stopping a command clears its uninterruptable state", function()
	local obj = mobile_fixture("Colonist")
	FD.StopCommandNoDestructors(obj)
	assert(not obj.uninterruptable_importance, "new command would assert")
end)
test("a destructor thread is stopped even without a command thread", function()
	local thread = { running = true }
	local obj = { thread_running_destructors = thread }
	FD.StopCommandNoDestructors(obj)
	assert(not thread.running, "destructor thread was skipped")
end)
test("colonists use their object position API and start a fresh command", function()
	local old_valid_pos = IsValidPos
	IsValidPos = function(value) return type(value) == "table" and value.point == true end
	local obj = mobile_fixture("Colonist")
	local result = FD.Colonist.IdleForRelatedObjectDelete(obj)
	IsValidPos = old_valid_pos
	assert(result and obj.new_command_started, "colonist command was not restarted")
end)
test("drone cleanup restarts work and retains a surviving controller", function()
	local obj = mobile_fixture("Drone")
	local controller = { drones = { obj } }
	obj.command_center = controller
	assert(FD.Drone.IdleForRelatedObjectDelete(obj, {}))
	assert(obj.command_center == controller, "surviving controller was discarded")
	assert(obj.new_command_started and IsValidThread(obj.command_thread), "drone has no active command")
end)
test("drone cleanup releases a controller that is being deleted", function()
	local obj = mobile_fixture("Drone")
	local controller = { drones = { obj } }
	obj.command_center = controller
	function obj:SetCommandCenter(center) self.command_center = center; controller.drones = {} end
	assert(FD.Drone.IdleForRelatedObjectDelete(obj, { [controller] = true }))
	assert(obj.command_center == false and #controller.drones == 0)
	assert(obj.new_command_started, "orphan drone never searches for a controller")
end)
test("rover recovery starts a command without destroying its repair request", function()
	local obj = mobile_fixture("RCTransport")
	local request = {}
	obj.repair_work_request = request
	assert(FD.Rover.IdleForRelatedObjectDelete(obj))
	assert(obj.repair_work_request == request, "surviving rover lost its repair request")
	assert(obj.new_command_started)
end)
test("shuttle recovery starts a new command after clearing a transport task", function()
	local obj = mobile_fixture("CargoShuttle")
	obj.transport_task = { source_dome = {}, state = "running" }
	obj.is_colonist_transport_task = true
	assert(FD.Shuttle.IdleForRelatedObjectDelete(obj))
	assert(obj.new_command_started)
	assert(not obj.transport_task and not obj.is_colonist_transport_task)
end)
test("rocket deletion detaches and restarts every surviving unit type", function()
	local rocket = { class = "UniversalRocket", pos = { point = true } }
	function rocket:delete() self.deleted = true end
	local rover = mobile_fixture("RCTransport")
	local passenger = mobile_fixture("Colonist")
	local drone = mobile_fixture("Drone")
	for _, unit in ipairs({ rover, passenger, drone }) do
		unit.holder = rocket
		unit.parent = rocket
		unit.invalid_position = true
	end
	rocket.rovers = { rover }
	rocket.boarded = { passenger }
	rocket.drones = { drone }
	assert(FD.Rocket.Delete(rocket))
	for _, unit in ipairs({ rover, passenger, drone }) do
		assert(unit.new_command_started and not unit:GetParent(), unit.class .. " was not restarted/detached")
		assert(unit.holder_released, unit.class .. " skipped native holder cleanup")
	end
end)
test("dome cleanup also finds and restarts affected rovers", function()
	local obj = mobile_fixture("RCTransport")
	local city = { labels = { RCTransport = { obj } } }
	local dome = { class = "Dome", city = city, labels = {} }
	obj.target = dome
	assert(type(FD.Dome.IdleAffectedRovers) == "function", "dome has no rover recovery")
	assert(FD.Dome.IdleAffectedRovers(dome, {}, {}, { [dome] = true }) == 1)
	assert(obj.new_command_started)
end)
test("full dome deletion restarts survivors and leaves unrelated units alone", function()
	local colonist = mobile_fixture("Colonist")
	local drone = mobile_fixture("Drone")
	local rover = mobile_fixture("RCTransport")
	local shuttle = mobile_fixture("CargoShuttle")
	local unrelated = mobile_fixture("Drone")
	local city = { labels = { Colonist = { colonist }, Drone = { drone, unrelated }, RCTransport = { rover }, CargoShuttle = { shuttle } } }
	local dome = { class = "Dome", city = city, labels = { Colonist = { colonist } } }
	function dome:delete() self.deleted = true end
	colonist.dome = dome
	drone.target = dome
	rover.target = dome
	shuttle.dest_dome = dome
	local controller = { drones = { drone } }
	drone.command_center = controller
	assert(FD.Dome.Delete(dome))
	assert(dome.deleted)
	for _, obj in ipairs({ colonist, drone, rover, shuttle }) do
		assert(IsValidThread(obj.command_thread) and obj.new_command_started, obj.class .. " has no fresh command")
	end
	assert(drone.command_center == controller)
	assert(not unrelated.new_command_started and unrelated.command == "Work")
end)

test("direct passage cleanup cannot recursively delete its controller", function()
	local passage = { class = "PassageBase", elements = { {} }, elements_under_construction = {} }
	function passage:CanDelete() return #self.elements == 0 end
	local deletes = 0
	function passage:delete()
		deletes = deletes + 1
		if deletes == 1 then
			-- PassageGridElement:Done calls DoneObject(controller) for the last segment.
			self.elements = {}
			if self:CanDelete() then self:delete() end
		end
		self.deleted = true
	end
	assert(FD.DeleteObjectDirect(passage))
	assert(deletes == 1, "passage controller was destroyed recursively")
end)

test("dome selection drops deleted destinations from an in-flight snapshot", function()
	local deleted, live = { deleted = true }, {}
	local snapshot = { deleted, live }
	local elevator = {}
	ChooseDome = function(colonist, domes, safety, elevators)
		assert(#domes == 1 and domes[1] == live, "deleted destination reached native scoring")
		assert(not safety, "deleted fallback destination survived")
		return domes[1], elevators[domes[1]], "preserved return"
	end
	assert(FD.Colonist.PatchChooseDome())
	local wrapper = ChooseDome
	FD.Colonist.PatchChooseDome()
	assert(ChooseDome == wrapper, "wrapper installed twice")
	local destination, via, extra = ChooseDome({}, snapshot, deleted, { [live] = elevator })
	assert(destination == live and via == elevator and extra == "preserved return")
	assert(snapshot[1] == deleted and #snapshot == 2, "caller-owned snapshot changed")
end)
test("colonist recovery releases its interrupted passage registration", function()
	local obj = colonist_fixture(false)
	local passage = { traversing_colonists = { obj } }
	obj.traversing_passage = passage
	obj.emigration_dome = {}
	assert(FD.Colonist.IdleForRelatedObjectDelete(obj))
	assert(#passage.traversing_colonists == 0 and not obj.traversing_passage)
	assert(not obj.emigration_dome, "stale migration destination survived reset")
end)

test("overlapping city labels evaluate each recovery candidate only once", function()
	local a, b = {}, {}
	local calls = {}
	local city = { labels = { Unit = { a, b }, Worker = { a, b }, Other = { [a] = true } } }
	local objects, seen = {}, {}
	local function matches(obj)
		calls[obj] = (calls[obj] or 0) + 1
		return obj == a
	end
	FD.Dome.CollectAffectedObjectsFromContainer(city, matches, objects, seen)
	FD.Dome.CollectAffectedObjectsFromContainer(city, matches, objects, seen)
	assert(calls[a] == 1 and calls[b] == 1, "duplicate labels repeated expensive recovery predicates")
	assert(#objects == 1 and objects[1] == a)
end)

print(string.format("%d passed, %d failed", passed, failures))
os.exit(failures == 0 and 0 or 1)
