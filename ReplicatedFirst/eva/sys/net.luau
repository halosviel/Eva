--[=[
	[INFO]
	author: @halosviel
	created: 2026 August 06
	
	[DESCRIPTION]
	Third prototype for Eva's networking system. Fixes a lot of problems from the old version
	by splitting cast and request nodes into two different objects.
]=]

--## Imports ##--

local expect = require("./expect")
local log = require("./log")

--## Variables ##--

local runContext: string = game.RunService:IsServer() and "Server" or "Client"

--## Net ##--

--# this type is used for both nodes
type Metadata = {
	name: string,
	rateLimit: number?,
	reliable: boolean?
}

type CastNode = {
	metadata: Metadata
}

type RequestNode = {
	metadata: Metadata
}

type Net = {
	setup: () -> nil,
	newCastNode: ( self: self ) -> CastNode,
	newRequestNode: ( self: self ) -> RequestNode
}
type self = Net

local Net
Net = {
	
	--# called by client & server index scripts
	setup = function()
		if runContext == "Server" then
			--## Server Setup ##--
			
			local eventsFolder: Folder = Instance.new("Folder")
			eventsFolder.Parent = game.ReplicatedStorage
		else
			--## Client Setup ##--
			
		end
	end,
	
	
}

return Net