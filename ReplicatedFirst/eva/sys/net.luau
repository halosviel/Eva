--[=[
	[INFO]
	author: @halosviel
	created: 2026 August 06
	
	[DESCRIPTION]
	Third prototype for Eva's networking system. Fixes a lot of problems from the old version
	by splitting cast and request nodes into two different objects.
]=]

--## Config ##--

local EVENTS_FOLDER_NAME = "events"

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
			eventsFolder.Name = EVENTS_FOLDER_NAME
			eventsFolder.Parent = game.ReplicatedStorage
		else
			--## Client Setup ##--
			
		end
	end,
	
	newCastNode = function(metadata: Metadata) : CastNode
		if runContext == "Client" then
			return
		end
		
		expect("table", metadata)
		expect("string", metadata.name)
		expect("boolean", metadata.reliable)
		
		if metadata.rateLimit ~= nil then
			expect("number", metadata.rateLimit)
		end
		
		local instanceName: string = metadata.reliable == true and "RemoteEvent" or "UnreliableRemoteEvent"
		local instance: RemoteEvent | UnreliableRemoteEvent = Instance.new(instanceName)
		instance.Name = metadata.name
		instance.Parent = game.ReplicatedStorage:WaitForChild(EVENTS_FOLDER_NAME)
		
		local self: CastNode = setmetatable({
			instance = instance,
			metadata = metadata
		} :: CastNode, CastNodeTable)
		
		return self
	end,
	
	newRequestNode = function(metadata: Metadata) : RequestNode
		if runContext == "Client" then
			return
		end
		
		expect("table", metadata)
		expect("string", metadata.name)
		
		if metadata.rateLimit ~= nil then
			expect("number", metadata.rateLimit)
		end
		
		local instance: RemoteFunction = Instance.new("RemoteFunction")
		instance.Name = metadata.name
		instance.Parent = game.ReplicatedStorage:WaitForChild(EVENTS_FOLDER_NAME)
		
		local self: RequestNode = setmetatable({
			instance = instance,
			metadata = metadata
		} :: RequestNode, RequestNodeTable)
		
		return self
	end,
}

return Net