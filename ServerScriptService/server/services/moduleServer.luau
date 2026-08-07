--[=[
	[INFO]
	author: @halosviel
	created: 2026 July 15
	
	[DESCRIPTION]
	Module template.
]=]

local nodes = require("@game/ReplicatedFirst/shared/nodes")
local nodeTypes = require("@game/ReplicatedFirst/client/types/nodes")

local types = require("../types/services")
type self = types.Module

return {
	runsFirst = false,
	dependencies = {},
	
	constructor = function(self: self)
	end,
	
	ready = function(self: self)
		task.spawn(function()
			for i = 3, 0, -1 do
				print("starting in", i)
				task.wait(1)
			end
			
			warn("server sent")
			--[[nodes.nodeA:Broadcast({
				value1 = true,
				value2 = false
			} :: nodeTypes.MyPayload)
			task.wait(0.1)]]
		end)
	end,
}