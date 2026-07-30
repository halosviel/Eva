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
		nodes.nodeA.onRequest:Connect(function(player: Player, header: nodes.Header, payload: nodes.Payload) : { message1: string, message2: string}
			warn("server received", header, payload)
			return {
				message1 = "Server params",
				message2 = "Ws in the chat"
			}
		end)
	end,
}