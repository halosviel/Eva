--[=[
	[INFO]
	author: @halosviel
	created: 2026 July 19
	
	[DESCRIPTION]
	Evangelion's networking system. Inspired by the Internet Protocol.
	
	On runtime, the metadata in the `nodes` module are replaced with an object.
	
	[NOTES]
	- One downside to this system is that all nodes have access to all types.
]=]

local expect = require("./expect")
local log = require("./log")

local nodes = require("@game/ReplicatedFirst/client/nodes")
assert(typeof(nodes) == "table", `Table expected for \`nodes\`, got {typeof(nodes)}`)

local signal = require("../libs/cuteSignal")

type NodeMetadata = {
	reliable: boolean?,
	returns: boolean?,
	throttle: number?,
	paramCount: number?
}

--## Helpers ##--

local function expectServer(action: string)
	if game.RunService:IsClient() then
		log(1, "Wrong boundary", `{action} can only be done on the server`)
	end
end

local function expectClient(action: string)
	if game.RunService:IsServer() then
		log(1, "Wrong boundary", `{action} can only be done on the server`)
	end
end

local function createHeader(recipent: string?)
	return {
		sender = game.RunService:IsServer() and "Server" or "Client",
		recipent = game.RunService:IsClient() and "Server" or recipent or "?",
		timestamp = workspace:GetServerTimeNow()
	}
end

--## RemoteEvent ##--

type _RemoteEvent = {
	instance: RemoteEvent,
	unicast: ( self: _RemoteEvent, player: Player, payload: nodes.Payload ) -> nil,
	broadcast: ( self: _RemoteEvent, payload: nodes.Payload ) -> nil,
	multicast: ( self: _RemoteEvent, players: { Player }, payload: nodes.Payload ) -> nil,
	anycast: ( self: _RemoteEvent, payload: nodes.Payload ) -> nil,
	cast: ( self: _RemoteEvent, payload: nodes.Payload ) -> nil,
	onCast: signal.Signal,
}

local RemoteEvent
RemoteEvent = {
	new = function(instance: Instance) : _RemoteEvent
		local self: _RemoteEvent = setmetatable({
			instance = instance,
			onCast = signal.new()
		}, RemoteEvent)
		
		self.onCast:Connect(function(header: nodes.Header, payload: nodes.Payload)
			if typeof(header) ~= "table" then
				return
			end
			if typeof(header.sender) ~= "string" then
				return
			end
			if typeof(header.recipent) ~= "string" then
				return
			end
			if typeof(header.timestamp) ~= "number" then
				return
			end
			
			if typeof(payload) ~= "table" then
				return
			end
			
			warn("RECIEVED", game.RunService:IsServer() and "Server" or "Client", header, payload)
		end)
		
		return self
	end,
	
	--## Server to Client ##--
	
	unicast = function(self: _RemoteEvent, player: Player, payload: nodes.Payload)
		expectServer("Unicasting")
		expect("Player", player, "Cast recipent must be a player")
		
		self.instance:FireClient(player, createHeader(tostring(player)), payload)
	end,
	
	broadcast = function(self: _RemoteEvent, payload: nodes.Payload)
		expectServer("Broadcasting")
		
		for _, player: Player in game.Players:GetPlayers() do
			self.instance:FireAllClients(createHeader(tostring(player)), payload)
		end
	end,
	
	multicast = function(self: _RemoteEvent, players: { Player }, payload: nodes.Payload)
		expectServer("Multicasting")
		expect("table", players)
		
		for _, player: Player in players do
			expect("Player", player)
			self.instance:FireClient(player, createHeader(tostring(player)), payload)
		end
	end,
	
	--# NOTE: Nothing happens if there are no players
	anycast = function(self: _RemoteEvent, payload: nodes.Payload)
		local players: { Player } = game.Players:GetPlayers()
		if #players > 0 then
			local randomPlayer: Player = players[math.random(1, #players)]
			self.instance:FireClient(randomPlayer, createHeader(tostring(randomPlayer)), payload)
		end
	end,
	
	--## Client to Server ##--
	
	cast = function(self: _RemoteEvent, payload: nodes.Payload)
		expectClient("Casting")
		self.instance:FireServer(createHeader("Server"), payload)
	end,
}
RemoteEvent.__index = RemoteEvent


--## RemoteFunction ##--

type _RemoteFunction = {
	request: ( self: _RemoteFunction, ...any ) -> nil,
	onRequest: ( self: _RemoteFunction, ...any ) -> nil,
}

--## Network ##--

local Network = {}

function Network.setup()
	if game.RunService:IsServer() then
		--## Set up Events Folder ##--
		
		local eventsFolder: Folder = Instance.new("Folder")
		eventsFolder.Name = "events"
		eventsFolder.Parent = game.ReplicatedStorage
		
		--## Create Event Instances ##--
		
		for nodeName: string, metadata: NodeMetadata in nodes do
			--## Validate ##--
			expect("string", nodeName, "Node must have a string key")
			expect("table", metadata, `Node must have a table value`)
			
			if metadata.reliable == nil and metadata.returns == nil then
				log(1, "Missing values", `Node \`{nodeName}\` could not be evaluated; must have \`reliable\` or \`returns\` attributes!`)
			end
			
			--# prep default data
			local instance: string?
			local throttle: number? = 0 --# no cooldown
			local paramCount: number? = math.huge --# inf params
			
			if metadata.reliable ~= nil then
				expect("boolean", metadata.reliable, "`metadata.reliable` must be a boolean")
			end
			if metadata.returns ~= nil then
				expect("boolean", metadata.returns, "`metadata.returns` must be a boolean")
			end
			if metadata.throttle ~= nil then
				expect("number", metadata.throttle, "`metadata.throttle` must be a number")
				throttle = metadata.throttle
			end
			if metadata.paramCount ~= nil then
				expect("number", metadata.paramCount, "`metadata.paramCount` must be a number")
				paramCount = metadata.paramCount
			end
			
			--## Create Instances ##--
			
			if metadata.reliable == false then
				instance = Instance.new("UnreliableRemoteEvent")
			elseif metadata.returns == true then
				instance = Instance.new("RemoteFunction")
			else
				instance = Instance.new("RemoteEvent")
			end
			
			instance.Name = nodeName
			instance.Parent = eventsFolder
			
			--## Overwrite Nodes Module ##--
			
			nodes[nodeName] = instance
		end
	elseif game.RunService:IsClient() then
		--## Find Events Folder ##--
		
		local eventsFolder: Folder = game.ReplicatedStorage:WaitForChild("events")
		
		--## Overwrite Nodes Module ##--
		
		local function overwriteNode(event: Instance)
			nodes[event.Name] = event
		end
		
		eventsFolder.ChildAdded:Connect(overwriteNode)
		for _, event: Instance in eventsFolder:GetChildren() do
			overwriteNode(event)
		end
	end
end

return Network