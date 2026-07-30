--[=[
	[INFO]
	author: @halosviel
	created: 2026 July 15
	
	[DESCRIPTION]
	Module template.
]=]

local nodes = require("@game/ReplicatedFirst/shared/nodes")

local types = require("../types/services")
type self = types.Module

return {
	runsFirst = false,
	dependencies = {},
	
	constructor = function(self: self)
	end,
	
	ready = function(self: self)
		warn("client sent")
		nodes.nodeA:request({
			entry1 = "These",
			entry2 = "are",
			entry3 = "client",
			entry4 = "params",
		})
	end,
}