--[=[
	[INFO]
	author: @halosviel
	created: 2026 August 06
	
	[DESCRIPTION]
	Third prototype for Eva's networking system. Fixes a lot of problems from the old version
	by splitting cast and request nodes into two different objects.
	
	This module aims to pivot from the default instance-based event system, where pointers are
	hardcoded and organisation becomes hefty with scale. It also provides built-in functionality
	like rate limiting and selective casting.
	
	The system is inspired from the Internet Protocol, where a packet/datagram contains a `header`
	and a `payload`. It also follows the API of the `Packet` library, albeit a bit differently.
	The header exists to transport information that all event listeners would want to receive. A
	good example of this is the timestamp.
	
	[NOTES]
	- There is no lifecycle handling for the node objects - they are events!
]=]

--## Config ##--

local EVENTS_FOLDER_NAME = "events"

--## Imports ##--

local expect = require("./expect")
local log = require("./log")

local signal = require("@game/ReplicatedFirst/eva/libs/cuteSignal")

--## Variables ##--

local runContext: string = game.RunService:IsServer() and "Server" or "Client"

--## Types ##--

export type Header = {
	sender: string,
	recipient: string,
	timestamp: number
}
export type Payload = { [string]: any }

-->

--# this type is used for both nodes
type Metadata = {
	name: string,
	rateLimit: number?,
	reliable: boolean?
}

type CastNode = {
	instance: RemoteEvent | UnreliableRemoteEvent,
	metadata: Metadata,
	onCast: signal.Signal
}

type RequestNode = {
	instance: RemoteFunction,
	metadata: Metadata
}

type Net = {
	setup: () -> nil,
	newCastNode: ( self: Net ) -> CastNode,
	newRequestNode: ( self: Net ) -> RequestNode
}
type self = Net

--## Helper Functions ##--

--# for dynamic use, each param is optional, but will be validated again anyway
local function createHeader(sender: string, recipient: string) : Header
	expect("string", sender)
	expect("string", recipient)
	
	local newHeader: Header = {
		sender = sender,
		recipient = recipient,
		timestamp = workspace:GetServerTimeNow()
	}
	
	return newHeader
end

--# REMINDER FOR ME: `payload` is a hashmap.
local function validatePayload(payload: string)
	expect("table", payload, "Payload must be a table")
	
	for key: string, _: any in payload do
		expect("string", key, "The keys of data in a payload must be a string")
	end
end

local function expectServer(callbackName: string)
	if runContext ~= "Server" then
		log(1, `\`{callbackName}\` cannot be called on the client`)
	end
end

local function expectClient(callbackName: string)
	if runContext ~= "Client" then
		log(1, `\`{callbackName}\` cannot be called on the server`)
	end
end

--## OOP Setup ##--
--# constructor functions are in the Net section below

local CastNodeTable: CastNode?
CastNodeTable = {
	--## Client -> Server ##--
	
	cast = function(self: CastNode, payload: Payload)
		expectClient()
		validatePayload(payload)
		
		local header: Header = createHeader(game.Players.LocalPlayer.Name, "Server")
		self.instance:FireServer(header, payload)
	end,
	
	--## Server -> Client ##--
	--# (selective casting)
	--# 
	--# client can infer which cast type was used based on the
	--# `recipient` entry in the header if needed, i guess
	
	--# To one player
	Unicast = function(self: CastNode, targetPlayer: Player, payload: Payload)
		expectServer()
		expect("Player", targetPlayer)
		validatePayload(payload)
		
		local header: Header = createHeader("Server", targetPlayer.Name)
		self.instance:FireClient(targetPlayer, header, payload)
	end,
	
	--# To everyone
	Broadcast = function(self: CastNode, payload: Payload)
		expectServer()
		validatePayload(payload)
		
		local header: Header = createHeader("Server", "All Players")
		self.instance:FireAllClients(header, payload)
	end,
	
	--# To selected players
	--# If client needs to see if the cast was a multicast, they can use
	--# string find on "Multicast" in the `recipient` entry
	Multicast = function(self: CastNode, targetPlayers: { Player }, payload: Payload)
		expectServer()
		expect("table", targetPlayers)
		for _, player: Player in targetPlayers do
			expect("Player", player)
		end
		validatePayload(payload)
		
		local header: Header = createHeader("Server", `{game.Players.LocalPlayer.Name} (Multicast)`)
		for _, player: Player in targetPlayers do
			self.instance:FireClient(player, header, payload)
		end
	end,
	
	--# To random player
	Anycast = function(self: CastNode, payload: Payload)
		expectServer()
		validatePayload(payload)
		
		local players: { Player } = game.Players:GetPlayers()
		if #players == 0 then
			log(4, "Anycast dropped (No players)")
			return
		end
		
		local randomPlayer: Player = players[math.random(1, # players)]
		
		local header: Header = createHeader("Server", randomPlayer.Name)
		self.instance:FireClient(randomPlayer, header, payload)
	end,
}
CastNodeTable.__index = CastNodeTable

local RequestNodeTable: RequestNode?
RequestNodeTable = {
	
}
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
		--## Validation ##--
		
		if runContext == "Client" then
			return
		end
		
		expect("table", metadata)
		expect("string", metadata.name)
		expect("boolean", metadata.reliable)
		
		if metadata.rateLimit ~= nil then
			expect("number", metadata.rateLimit)
		end
		
		--## Create Node ##--
		
		local instanceName: string = metadata.reliable == true and "RemoteEvent" or "UnreliableRemoteEvent"
		local instance: RemoteEvent | UnreliableRemoteEvent = Instance.new(instanceName)
		instance.Name = metadata.name
		instance.Parent = game.ReplicatedStorage:WaitForChild(EVENTS_FOLDER_NAME)
		
		local self: CastNode = setmetatable({
			instance = instance,
			metadata = metadata,
			onCast = signal.new()
		} :: CastNode, CastNodeTable)
		
		--## Event Handling ##--
		
		if runContext == "Server" then
			self.instance.OnServerEvent:Connect(function(player: Player, header: Header, payload: Payload)
				--# TODO: note that we might have to create a header right here idk
				self.onCast:Fire(header, payload)
			end)
		elseif runContext == "Client" then
			self.instance.OnClientEvent:Connect(function(header: Header, payload: Payload)
				self.onCast:Fire(header, payload)
			end)
		end
		
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