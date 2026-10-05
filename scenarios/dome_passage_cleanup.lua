-- Run in an isolated game session after loading United States of Mars.savegame.sav.
-- This changes only the in-memory colony; never save the test session.
HARNESS.scenario("dome_passage_cleanup", function(ctx)
	local FD = Mods.ForceDelete.env.ForceDelete
	local dome = HandleToObject[1812]
	ctx:assert(IsValid(dome) and IsKindOf(dome, "Dome"), "saved dome 1812 is present")
	if not IsValid(dome) then return end
	local passages = FD.Dome.CollectConnectedPassageControllers(dome)
	ctx:assert(#passages == 4, "fixture has four connected passages")
	local deletes, nested, method_errors = {}, {}, {}
	for _, passage in ipairs(passages) do
		local original, handle = passage.delete, passage.handle
		local depth = 0
		passage.delete = function(self, ...)
			deletes[tostring(handle)] = (deletes[tostring(handle)] or 0) + 1
			depth = depth + 1
			if depth > 1 then nested[#nested + 1] = handle end
			local result = original(self, ...)
			depth = depth - 1
			return result
		end
	end
	local original_call = FD.CallObjectMethod
	FD.CallObjectMethod = function(obj, method, ...)
		local fn = FD.ReadField(obj, method)
		if type(fn) ~= "function" then return false end
		local ok, err = pcall(fn, obj, ...)
		if not ok then method_errors[#method_errors + 1] = method .. ": " .. tostring(err) end
		return ok
	end
	local ok, err = pcall(FD.Dome.Delete, dome)
	FD.CallObjectMethod = original_call
	ctx:record("passage_deletes", deletes)
	ctx:record("nested_deletes", nested)
	ctx:record("method_errors", method_errors)
	ctx:assert(ok, "dome deletion returned without throwing: " .. tostring(err))
	ctx:assert(not IsValid(dome), "dome removed")
	ctx:expect_eq(#nested, 0, "passage destruction is not recursive")
	ctx:expect_eq(#method_errors, 0, "native cleanup methods succeed")
	for _, passage in ipairs(passages) do
		ctx:assert(not IsValid(passage), "connected passage removed")
	end
end)
