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


--## Types ##--

--# this type is used for both nodes
type Metadata = {
	name: string,
	rateLimit: number?,
	reliable: boolean?
}

type CastNode = {
	instance: RemoteEvent | UnreliableRemoteEvent,
	metadata: Metadata
}

type RequestNode = {
	instance: RemoteFunction,
	metadata: Metadata
}

type Net = {
	setup: () -> nil,
	newCastNode: ( self: self ) -> CastNode,
	newRequestNode: ( self: self ) -> RequestNode
}
type self = Net


--## OOP Setup ##--

local CastNodeTable = {}
CastNodeTable.__index = CastNodeTable

local RequestNodeTable = {}
RequestNodeTable.__index = RequestNodeTable


--## Net ##--

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
	
	newCastNode = function(self: self, metadata: Metadata) : CastNode
		if runContext == "Client" then
			log(1, "`newCastNode()` can only be called on the server!")
		end
		
		expect("table", metadata)
		expect("string", metadata.name)
		expect("boolean", metadata.reliable)
		
		if metadata.rateLimit ~= nil then
			expect("number", metadata.rateLimit)
		end
		
		local instanceName: string = metadata.reliable == true and "RemoteEvent" or "UnreliableRemoteEvent"
		local instance: RemoteEvent | UnreliableRemoteEvent = Instance.new(instanceName)
		
		local castNode: CastNode = setmetatable({
			instance = instance,
			metadata = metadata
		} :: CastNode, CastNodeTable)
		
		return castNode
	end,
	
	newRequestNode = function(self: self, metadata: Metadata)
		if runContext == "Client" then
			log(1, "`newRequestNode()` can only be called on the server!")
		end
		
		expect("table", metadata)
		expect("string", metadata.name)
		
		if metadata.rateLimit ~= nil then
			expect("number", metadata.rateLimit)
		end
		
		local instance: RemoteFunction = Instance.new("RemoteFunction")
		local requestNode: RequestNode = setmetatable({
			instance = instance,
			metadata = metadata
		} :: RequestNode, RequestNodeTable)

		return requestNode
	end,
}

return Net