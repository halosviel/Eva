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
		task.wait(2)
		print("fired")
		nodes.myNode:unicast(game.Players.halosviel, {"hi", "lol", 123})
		
		nodes.myNode.onCast:Connect(function(player, header, payload)
			warn("server recieve", header, payload)
		end)
	end,
}