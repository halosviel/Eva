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
	
	The system is inspired from the Internet Protocol, where all event listeners are passed a `header`
	and a `payload` (and `player` for the server). It also follows the API of the `Packet` library
	with the use of the `nodes` module. The header exists to transport information that all event
	listeners would want to receive, such as the timestamp.
	
	The term `node` refers to both `cast nodes` (RemoteEvents) and `request nodes` (RemoteFunctions).
	
	[NOTES]
	- There is no lifecycle handling for the node objects - they are events!
	- Cannot have 2 nodes of any type with the same name.
]=]

--## Config ##--

local EVENTS_FOLDER_NAME = "events"

--## Imports ##--

local expect = require("./expect")
local log = require("./log")

local nodeTypes = require("@game/ReplicatedFirst/client/types/nodes")
local signal = require("@game/ReplicatedFirst/eva/libs/cuteSignal")

--## Variables ##--

local runContext: string = game.RunService:IsServer() and "Server" or "Client"

--## Types ##--

--# this type is used for both nodes
export type Metadata = {
	name: string,
	rateLimit: number?,
	reliable: boolean?
}

type CastNode = {
	instance: RemoteEvent | UnreliableRemoteEvent,
	metadata: Metadata,
	lastCast: number,
	onCast: signal.Signal,
	Cast: ( self: CastNode, payload: nodeTypes.Payload ) -> nil,
	Unicast: ( self: CastNode, targetPlayer: Player, payload: nodeTypes.Payload ) -> nil,
	Broadcast: ( self: CastNode, payload: nodeTypes.Payload ) -> nil,
	Multicast: ( self: CastNode, targetPlayers: { Player }, payload: nodeTypes.Payload ) -> nil,
	Anycast: ( self: CastNode, payload: nodeTypes.Payload ) -> nil
}

type RequestNode = {
	instance: RemoteFunction,
	metadata: Metadata,
	lastRequest: number,
	callback: ( player: Player, header: nodeTypes.Header, payload: nodeTypes.Payload ) -> nil
}

type Net = {
	setup: () -> nil,
	newCastNode: ( self: Net, metadata: Metadata ) -> CastNode,
	newRequestNode: ( self: Net, Metadata: Metadata ) -> RequestNode
}
type self = Net

--## Helper Functions ##--

--# for dynamic use, each param is optional, but will be validated again anyway
local function createHeader(sender: string, recipient: string) : nodeTypes.Header
	expect("string", sender)
	expect("string", recipient)
	
	local newHeader: nodeTypes.Header = {
		sender = sender,
		recipient = recipient,
		timestamp = workspace:GetServerTimeNow()
		--# add new header values here. make sure to update the `Header` type above ^^
	}
	
	return newHeader
end

--# used in `on server` events to replace sender & recipient values
--# bc we cannot trust the client
local function secureHeader(header: nodeTypes.Header, player: Player) : nodeTypes.Header
	header.sender = player.Name
	header.recipient = "Server"
	return header
end

--# REMINDER FOR ME: `payload` is a hashmap AND can be empty.
local function validatePayload(payload: nodeTypes.Payload)
	expect("table", payload, "Payload must be a table")
	
	for key: string, _: any in payload do
		expect("string", key, "The keys of data in a payload must be a string")
	end
end

--# check if client-sent header is safe (server only)
local function validateHeaderInsecure(header: nodeTypes.Header?) : boolean
	if typeof(header) ~= "table" then
		return false
	end
	
	if typeof(header.sender) ~= "string" then
		return false
	end
	
	if typeof(header.recipient) ~= "string" then
		return false
	end
	
	if typeof(header.timestamp) ~= "number" then
		return false
	end
	
	if math.isnan(header.timestamp) then
		return false
	end
	
	if header.timestamp < 0 then
		return false
	end
	
	return true
end

--# check if client-sent payload is safe (server only)
local function validatePayloadInsecure(payload: nodeTypes.Payload?) : boolean
	if typeof(payload) ~= "table" then
		return false
	end
	
	for key: string?, _: any in payload do
		if typeof(key) ~= "string" then
			return false
		end
	end
end

local function handleRateLimit(node: CastNode | RequestNode) : boolean
	local entryName: string = node.instance == "RemoteFunction"  and "lastRequest" or "lastCast"
	local lastTriggered: number = node[entryName]
	local isRateLimited: boolean = (os.clock() - lastTriggered < node.metadata.rateLimit) and node.metadata.rateLimit > 0
	
	if not isRateLimited then
		node[entryName] = os.clock()
	end
	
	return isRateLimited
end

local function expectServer(callbackName: string)
	if runContext ~= "Server" then
		log(1, `\`{callbackName}\` cannot be called on the client`)
		return
	end
end

local function expectClient(callbackName: string)
	if runContext ~= "Client" then
		log(1, `\`{callbackName}\` cannot be called on the server`)
		return
	end
end

--## OOP Setup ##--
--# constructor functions are in the Net section below

local CastNodeTable: CastNode?
CastNodeTable = {
	--## Client -> Server ##--
	
	Cast = function(self: CastNode, payload: nodeTypes.Payload)
		expectClient("Cast()")
		validatePayload(payload)
		
		local header: nodeTypes.Header = createHeader(game.Players.LocalPlayer.Name, "Server")
		self.instance:FireServer(header, payload)
	end,
	
	--## Server -> Client ##--
	--# (selective casting)
	--# 
	--# client can infer which cast type was used based on the
	--# `recipient` entry in the header if needed, i guess
	
	--# To one player
	Unicast = function(self: CastNode, targetPlayer: Player, payload: nodeTypes.Payload)
		expectServer("Unicast()")
		expect("Player", targetPlayer)
		validatePayload(payload)
		
		local header: nodeTypes.Header = createHeader("Server", targetPlayer.Name)
		self.instance:FireClient(targetPlayer, header, payload)
	end,
	
	--# To everyone
	Broadcast = function(self: CastNode, payload: nodeTypes.Payload)
		expectServer("Broadcast()")
		validatePayload(payload)
		
		local header: nodeTypes.Header = createHeader("Server", "All Players")
		self.instance:FireAllClients(header, payload)
	end,
	
	--# To selected players
	Multicast = function(self: CastNode, targetPlayers: { Player }, payload: nodeTypes.Payload)
		expectServer("Multicast()")
		expect("table", targetPlayers)
		
		for i: number, player: Player in targetPlayers do
			if typeof(i) ~= "number" then
				log(1, "Cannot have a non-number key in an array", "Reading from `targetPlayers`", {{ "invalidKey", tostring(i) }})
				return
			end
 			expect("Player", player)
		end
		if #targetPlayers == 0 then
			log(1, "`targetPlayers` cannot be empty")
			return
		end
		
		validatePayload(payload)
		
		local playerNamesList: { string } = {}
		for _, player: Player in targetPlayers do
			table.insert(playerNamesList, player.Name)
		end
		local playerNamesConcat: string = table.concat(playerNamesList, ", ")
		
		local header: nodeTypes.Header = createHeader("Server", playerNamesConcat)
		for _, player: Player in targetPlayers do
			self.instance:FireClient(player, header, payload)
		end
	end,
	
	--# To random player
	--# TODO: retry behaviour?
	Anycast = function(self: CastNode, payload: nodeTypes.Payload)
		expectServer("Anycast()")
		validatePayload(payload)
		
		local players: { Player } = game.Players:GetPlayers()
		if #players == 0 then
			log(4, "Anycast dropped (No players)")
			return
		end
		
		local randomPlayer: Player = players[math.random(1, # players)]
		if not randomPlayer then
			log(4, "Anycast dropped (select player failed)")
			return
		end
		
		local header: nodeTypes.Header = createHeader("Server", randomPlayer.Name)
		self.instance:FireClient(randomPlayer, header, payload)
	end,
}
CastNodeTable.__index = CastNodeTable

local RequestNodeTable: RequestNode?
RequestNodeTable = {
	onRequest = function(self: RequestNode, callback: () -> nil)
		self.callback = callback
	end,
}
RequestNodeTable.__index = RequestNodeTable

--## Net ##--

local Net
Net = {
	
	--# called by client & server index scripts
	setup = function()
		if runContext == "Client" then
			log(1, "setup() cannot be called on the client!")
			return
		end
		
		local eventsFolder: Folder = Instance.new("Folder")
		eventsFolder.Name = EVENTS_FOLDER_NAME
		eventsFolder.Parent = game.ReplicatedStorage
	end,
	
	newCastNode = function(metadata: Metadata) : CastNode
		--## Validation ##--
		
		expect("table", metadata, "`metadata` must be a table")
		expect("string", metadata.name, "`name` must be a string")
		expect("boolean", metadata.reliable, "`reliable` must be a boolean")
		
		if metadata.rateLimit ~= nil then
			expect("number", metadata.rateLimit, "`rateLimit` must be a number")
		end
		
		--## Create Node ##--
		
		local instance: RemoteEvent | UnreliableRemoteEvent
		if runContext == "Server" then
			local eventsFolder: Folder = game.ReplicatedStorage:WaitForChild(EVENTS_FOLDER_NAME)
			if eventsFolder:FindFirstChild(metadata.name) then
				log(1, `Instance {metadata.name} already exists`, "Building events folder")
				return
			end
			
			local instanceType: string = metadata.reliable == true and "RemoteEvent" or "UnreliableRemoteEvent"
			instance = Instance.new(instanceType)
			instance.Name = metadata.name
			instance.Parent = eventsFolder
		elseif runContext == "Client" then
			local eventsFolder: Folder = game.ReplicatedStorage:WaitForChild(EVENTS_FOLDER_NAME)
			instance = eventsFolder:WaitForChild(metadata.name)
		end
		
		local self: CastNode = setmetatable({
			instance = instance,
			metadata = metadata,
			lastCast = os.clock(),
			onCast = signal.new()
		} :: CastNode, CastNodeTable)
		
		--## Event Handling ##--
		--#  probs not safe to print flagged header/payload due to
		--#  possibility of large string spam
		
		if runContext == "Server" then
			self.instance.OnServerEvent:Connect(function(player: Player, header: nodeTypes.Header, payload: nodeTypes.Payload)
				local isHeaderValid: boolean = validateHeaderInsecure(header)
				if isHeaderValid == false then
					log(4, "Cast entry dropped (Invalid header)")
					return
				end
				
				local isPayloadValid: boolean = validatePayloadInsecure(payload)
				if isPayloadValid == false then
					log(4, "Cast entry dropped (Invalid payload)")
					return
				end
				
				--# this block is duplicated like 4 times btw
				local isRateLimited: boolean = handleRateLimit(self)
				if isRateLimited then
					return
				end
				
				secureHeader(header, player)
				self.onCast:Fire(player, header, payload)
			end)
		elseif runContext == "Client" then
			self.instance.OnClientEvent:Connect(function(header: nodeTypes.Header, payload: nodeTypes.Payload)
				local isRateLimited: boolean = handleRateLimit(self)
				if isRateLimited then
					return
				end
				
				self.onCast:Fire(header, payload)
			end)
		end
		
		return self
	end,
	
	--# basically duplicate code from above idc
	newRequestNode = function(metadata: Metadata) : RequestNode
		
		--## Validation ##--
		
		expect("table", metadata, "`metadata` must be a table")
		expect("string", metadata.name, "`name` must be a string")
		
		if metadata.rateLimit ~= nil then
			expect("number", metadata.rateLimit, "`rateLimit` must be a number")
		end
		
		--## Create Node ##--
		
		local instance: RemoteFunction = Instance.new("RemoteFunction")
		instance.Name = metadata.name
		instance.Parent = game.ReplicatedStorage:WaitForChild(EVENTS_FOLDER_NAME)
		
		if runContext == "Server" then
			local eventsFolder: Folder = game.ReplicatedStorage:WaitForChild(EVENTS_FOLDER_NAME)
			if eventsFolder:FindFirstChild(metadata.name) then
				log(1, `Instance {metadata.name} already exists`, "Building events folder")
				return
			end
			
			instance = Instance.new("RemoteFunction")
			instance.Name = metadata.name
			instance.Parent = eventsFolder
		elseif runContext == "Client" then
			local eventsFolder: Folder = game.ReplicatedStorage:WaitForChild(EVENTS_FOLDER_NAME)
			instance = eventsFolder:WaitForChild(metadata.name)
		end
		
		local self: RequestNode = setmetatable({
			instance = instance,
			metadata = metadata,
			lastRequest = os.clock(),
			callback = nil
		} :: RequestNode, RequestNodeTable)
		
		--## Event Handling ##--
		
		if runContext == "Server" then
			self.instance.OnServerInvoke = function(player: Player, header: nodeTypes.Header, payload: nodeTypes.Payload) : ( nodeTypes.Header, nodeTypes.Payload )
				local isHeaderValid: boolean = validateHeaderInsecure(header)
				if isHeaderValid == false then
					log(4, "Request entry dropped (Invalid header)")
					return
				end
				
				local isPayloadValid: boolean = validatePayloadInsecure(payload)
				if isPayloadValid == false then
					log(4, "Request entry dropped (Invalid payload)")
					return
				end
				
				local isRateLimited: boolean = handleRateLimit(self)
				if isRateLimited then
					return
				end
				
				secureHeader(header, player)
				return self.callback(player, header, payload)
			end
		elseif runContext == "Client" then
			self.instance.OnClientInvoke = function(header: nodeTypes.Header, payload: nodeTypes.Payload) : ( nodeTypes.Header, nodeTypes.Payload )
				local isRateLimited: boolean = handleRateLimit(self)
				if isRateLimited then
					return
				end
				
				return self.callback(header, payload)
			end
		end
		
		return self
	end,
}

return Net