--[=[
	[INFO]
	author: @halosviel
	created: 2026 July 15
	
	[DESCRIPTION]
	Module template.
]=]

local nodes = require("@game/ReplicatedFirst/nodes")

local types = require("../types/services")
type self = types.Module

return {
	runsFirst = false,
	dependencies = {},
	
	constructor = function(self: self)
	end,
	
	ready = function(self: self)
		nodes.myNode.onCast:Connect(function(header, payload)
			warn("client receive", header, payload)
			
			nodes.myNode:cast(payload)
			task.wait(0.1)
			nodes.myNode:cast(payload)
			task.wait(0.1)
			nodes.myNode:cast(payload)
			task.wait(0.1)
			nodes.myNode:cast(payload)
			task.wait(0.1)
			nodes.myNode:cast(payload)
			task.wait(0.1)
			nodes.myNode:cast(payload)
			task.wait(0.1)
			nodes.myNode:cast(payload)
			task.wait(0.1)
			nodes.myNode:cast(payload)
			task.wait(0.1)
			nodes.myNode:cast(payload)
			task.wait(0.1)
			nodes.myNode:cast(payload)
			task.wait(0.1)
			nodes.myNode:cast(payload)
			task.wait(0.1)
			nodes.myNode:cast(payload)
			task.wait(0.1)
			nodes.myNode:cast(payload)
			task.wait(0.1)
			nodes.myNode:cast(payload)
			task.wait(0.1)
			nodes.myNode:cast(payload)
			task.wait(0.1)
			nodes.myNode:cast(payload)
			task.wait(0.1)
			nodes.myNode:cast(payload)
			task.wait(0.1)
			nodes.myNode:cast(payload)
			task.wait(0.1)
			nodes.myNode:cast(payload)
			task.wait(0.1)
			nodes.myNode:cast(payload)
			task.wait(0.1)
			nodes.myNode:cast(payload)
			task.wait(0.1)
			nodes.myNode:cast(payload)
			task.wait(0.1)
		end)
	end,
}