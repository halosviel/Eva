--[=[
	[INFO]
	author: @halosviel
	created: 2026 July 30
	
	[DESCRIPTION]
	The framework's custom networking module.
	
	!! Must be required by both server and client !!
	
	[NOTES]
	- Intellisense can see both the client and server's types.
	- Requires some boolean logic thinking to figure out the `returns` and `reliable`
	  metadata to get the desired event type, but you'll get the hang of it quickly.
	- The `Header` and `Payload` types are duplicated with the `nodes` module - make sure they're synced!
]=]

local expect = require("@game/ReplicatedFirst/evangelion/sys/expect")
local log = require("@game/ReplicatedFirst/evangelion/sys/log")

local signal = require("@game/ReplicatedFirst/evangelion/libs/cuteSignal")

--# same types as nodes!!
export type Header = {
	sender: string,
	recipent: string,
	timestamp: number
}
export type Payload = { [string]: any }
-------------------------

export type NodeMetadata = {
	name: string,
	reliable: boolean?,
	returns: boolean?,
	throttle: number?
}

export type BaseNode = {
	instance: RemoteEvent | UnreliableRemoteEvent | RemoteFunction,
	metadata: NodeMetadata,
	onCast: signal.Signal,
	lastFired: number
}

--# Cast Node -> Remote Event
--# Request Node -> Remote Function

export type CastNode = BaseNode & {
	onCast: signal.Signal,
	cast: ( self: BaseNode, payload: Payload ) -> nil,
	unicast: ( self: BaseNode, player: Player, payload: Payload ) -> nil,
	broadcast: ( self: BaseNode, payload: Payload ) -> nil,
	multicast: ( self: BaseNode, players: { Player }, payload: Payload ) -> nil,
	anycast: ( self: BaseNode, payload: Payload ) -> nil
}

export type RequestNode = BaseNode & {
	onRequest: signal.Signal,
	request: ( self: BaseNode ) -> nil
}

-->

local boundary: string = game.RunService:IsServer() and "Server" or "Client"
local registeredNodes: { BaseNode } = {}


-->

--## Helpers ##--

local function expectServer(action: string)
	if boundary == "Client" then
		log(1, "Wrong boundary", `{action} can only be done on the client`)
	end
end

local function expectClient(action: string)
	if boundary == "Server" then
		log(1, "Wrong boundary", `{action} can only be done on the server`)
	end
end

local function createHeader(recipent: string?) : Header
	return {
		sender = boundary == "Client" and game.Players.LocalPlayer.Name or "Server",
		recipent = recipent or "?",
		timestamp = workspace:GetServerTimeNow()
	}
end


-->

local net
net = {
	--# must be called on runtime by index on server & client
	setup = function()
		if boundary == "Server" then
			local eventsFolder: Folder = Instance.new("Folder")
			eventsFolder.Name = "events"
			eventsFolder.Parent = game.ReplicatedStorage
		end
	end,
	
	--# its up to the caller to mark the node variable as a CastNode
	--# or a RequestNode type
	newNode = function(metadata: NodeMetadata) : BaseNode
		
		--## Validate Metadata ##--
		
		expect("table", metadata)
		expect("string", metadata.name)
		
		if metadata.reliable == nil and metadata.returns == nil then
			log(1, "Unable to infer instance", "Either `reliable` or `returns` fields must exist")
		end
		
		if metadata.reliable ~= nil then
			expect("boolean", metadata.reliable)
		end
		if metadata.returns ~= nil then
			expect("boolean", metadata.returns)
		end
		if metadata.throttle ~= nil then
			expect("number", metadata.throttle)
		end
		
		if registeredNodes[metadata.name] ~= nil then
			log(1, "Duplicate entry", `Entry \`{metadata.name}\` already exists`)
		end
		
		
		--## Create Instance ##--
		
		local eventsFolder: Folder = game.ReplicatedStorage:WaitForChild("events")
		local instance: ( RemoteEvent | UnreliableRemoteEvent | RemoteFunction )?
		
		if boundary == "Server" then
			if metadata.reliable == false then
				instance = Instance.new("UnreliableRemoteEvent")
			elseif metadata.returns == true then
				instance = Instance.new("RemoteFunction")
			else
				instance = Instance.new("RemoteEvent")
			end
		else
			--# WARNING: yields!!
			--# should be fine tho
			instance = eventsFolder:WaitForChild(metadata.name)
		end
		
		instance.Name = metadata.name
		instance.Parent = eventsFolder
		--print("created", instance.ClassName, instance.Name)
		
		
		--## Construct Object ##--
		
		local self: BaseNode = setmetatable({
			instance = instance,
			metadata = metadata,
			onCast = signal.new(),
			lastFired = 0,
		} :: BaseNode, net)
		
		registeredNodes[self.metadata.name] = self
		
		--## Local Helpers ##--

		local function validateCast(header: Header, payload: Payload) : boolean
			if typeof(header) ~= "table" then
				return false
			end
			if typeof(header.sender) ~= "string" then
				return false
			end
			if typeof(header.recipent) ~= "string" then
				return false
			end
			if typeof(header.timestamp) ~= "number" then
				return false
			end
			
			if typeof(payload) ~= "table" then
				return false
			end
			
			return true
		end

		local function validateThrottle() : boolean
			if self.metadata.throttle == 0 then
				print("no throttle set")
				return false
			end

			if workspace:GetServerTimeNow() - self.lastFired < self.metadata.throttle then
				return true
			else
				return false
			end
		end

		--## Event Handling ##--

		if game.RunService:IsServer() then
			instance.OnServerEvent:Connect(function(player: Player, header: Header, payload: Payload)
				local isCastValid: boolean = validateCast(header, payload)
				if isCastValid == false then
					player:Kick("Remote tampering")
					return
				end

				local throttled: boolean = validateThrottle()
				if throttled == true then
					print("throttled server")
					return
				end

				self.lastFired = workspace:GetServerTimeNow()
				self.onCast:Fire(player, header, payload)
			end)
		else
			instance.OnClientEvent:Connect(function(header: Header, payload: Payload)
				local throttled: boolean = validateThrottle()
				if throttled == true then
					print("throttled client")
					return
				end

				self.lastFired = workspace:GetServerTimeNow()
				self.onCast:Fire(header, payload)
			end)
		end
		
		return self
	end,
	
	--## Server Only ##--
	
	unicast = function(self: BaseNode, player: Player, payload: Payload)
		expectServer("Unicasting")
		expect("Player", player, "Cast recipent must be a player")
		expect("table", payload, "Payload must be a table")
		
		local header: Header = createHeader(tostring(player))
		self.instance:FireClient(player, header, payload)
	end,
	
	broadcast = function(self: BaseNode, payload: Payload)
		expectServer("Broadcasting")
		expect("table", payload, "Payload must be a table")
		
		local header: Header = createHeader("All players")
		self.instance:FireAllClients(header, payload)
	end,
	
	multicast = function(self: BaseNode, players: { Player }, payload: Payload)
		expectServer("Multicasting")
		expect("table", players, "Cast recipents must be a table of players")
		expect("table", payload, "Payload must be a table")
		
		local names: { string } = {}
		for _, player: Player in players do
			table.insert(names, player.Name)
		end
		
		for _, player: Player in players do
			expect("Player", player)
			local header: Header = createHeader(table.concat(names, ", "))
			self.instance:FireClient(player, header, payload)
		end
	end,
	
	--# NOTE: Nothing happens if there are no players
	anycast = function(self: BaseNode, payload: Payload)
		expectServer("Anycasting")
		expect("table", payload, "Payload must be a table")
		
		local players: { Player } = game.Players:GetPlayers()
		if #players > 0 then
			local randomPlayer: Player = players[math.random(1, #players)]
			local header: Header = createHeader("Random")
			self.instance:FireClient(randomPlayer, header, payload)
		end
	end,
	
	--## Server & Client ##--
	
	cast = function(self: BaseNode, payload: Payload)
		expectClient("Casting")
		expect("table", payload, "Payload must be a table")
		
		local header: Header = createHeader(boundary == "Server" and "Client" or "Server")
		self.instance:FireServer(header, payload)
	end,
}
net.__index = net
return net