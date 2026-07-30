--[=[
	[INFO]
	author: @halosviel
	created: 2026 July 30
	
	[DESCRIPTION]
	The framework's custom networking module that takes the conventional instance-based event
	interface and turns it into a code-based one. Also adds built-in functionality that would otherwise
	see repetition such as throttling.
	
	!! Must be required by both server and client !!
	
	[NOTES]
	- Intellisense can see both the client and server's types.
	- Requires some boolean logic thinking to figure out the `returns` and `reliable`
	  metadata to get the desired event type, but you'll get the hang of it quickly.
	- The `Header` and `Payload` types are duplicated with the `nodes` module - make sure they're synced!
]=]

local expect = require("@game/ReplicatedFirst/eva/sys/expect")
local log = require("@game/ReplicatedFirst/eva/sys/log")

local signal = require("@game/ReplicatedFirst/eva/libs/cuteSignal")

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
	signal: signal.Signal,
	lastFired: number
}

--# Cast Node -> Remote Event
--# Request Node -> Remote Function

export type CastNode = BaseNode & {
	onCast: signal.Signal,
	cast: ( self: CastNode, payload: Payload ) -> nil,
	unicast: ( self: CastNode, player: Player, payload: Payload ) -> nil,
	broadcast: ( self: CastNode, payload: Payload ) -> nil,
	multicast: ( self: CastNode, players: { Player }, payload: Payload ) -> nil,
	anycast: ( self: CastNode, payload: Payload ) -> nil
}

export type RequestNode = BaseNode & {
	onRequest: signal.Signal,
	request: ( self: RequestNode ) -> nil
}

-->

local boundary: string = game.RunService:IsServer() and "Server" or "Client"
local registeredNodes: { BaseNode } = {}


-->

--## Helpers ##--

local function expectServer(action: string)
	if boundary == "Client" then
		log(1, "Wrong boundary", `{action} can only be done on the server`)
	end
end

local function expectClient(action: string)
	if boundary == "Server" then
		log(1, "Wrong boundary", `{action} can only be done on the client`)
	end
end

local function expectInstance(instanceName: string, functionName: string, instance: RemoteEvent | UnreliableRemoteEvent| RemoteFunction)
	if not instance:IsA(instanceName) then
		local nodeType: string = instanceName == "RemoteEvent" and "request" or "cast"
		log(1, "Illegal call", `Cannot call \`{functionName}\` on a {nodeType} node. Did you get confused?`)
		return
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
		if boundary == "Server" and not game.ReplicatedStorage:FindFirstChild("events") then
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
			signal = signal.new(),
			lastFired = 0,
		} :: BaseNode, net)
		
		registeredNodes[self.metadata.name] = self
		
		self.onRequest = self.signal
		self.onCast = self.signal
		
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
				--print("no throttle set")
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
			local function handleIncomingCast(player: Player, header: Header, payload: Payload) : any
				local isCastValid: boolean = validateCast(header, payload)
				if isCastValid == false then
					player:Kick("Remote tampering")
					return
				end
				
				local throttled: boolean = validateThrottle()
				if throttled == true then
					--print("throttled server")
					return
				end
				
				self.lastFired = workspace:GetServerTimeNow()
				return self.signal:Fire(player, header, payload)
			end
			
			if instance.ClassName == "RemoteFunction" then
				instance.OnServerInvoke = handleIncomingCast
			else
				instance.OnServerEvent:Connect(handleIncomingCast)
			end
		else
			local function handleIncomingCast(header: Header, payload: Payload) : any
				local throttled: boolean = validateThrottle()
				if throttled == true then
					--print("throttled client")
					return
				end
				
				self.lastFired = workspace:GetServerTimeNow()
				return self.signal:Fire(header, payload)
			end
			
			if instance.ClassName == "RemoteFunction" then
				instance.OnClientInvoke = handleIncomingCast()
			else
				instance.OnClientEvent:Connect(handleIncomingCast)
			end
		end
		
		return self
	end,
	
	--## Server Only ##--
	
	unicast = function(self: BaseNode, player: Player, payload: Payload)
		expectServer("Unicasting")
		expectInstance("RemoteEvent", "unicast()", self.instance)
		
		expect("Player", player, "Cast recipent must be a player")
		expect("table", payload, "Payload must be a table")
		
		local header: Header = createHeader(tostring(player))
		self.instance:FireClient(player, header, payload)
	end,
	
	broadcast = function(self: BaseNode, payload: Payload)
		expectServer("Broadcasting")
		expectInstance("RemoteEvent", "broadcast()", self.instance)
		expect("table", payload, "Payload must be a table")
		
		local header: Header = createHeader("All players")
		self.instance:FireAllClients(header, payload)
	end,
	
	multicast = function(self: BaseNode, players: { Player }, payload: Payload)
		expectServer("Multicasting")
		expectInstance("RemoteEvent", "multicast()", self.instance)
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
		expectInstance("RemoteEvent", "anycast()", self.instance)
		expect("table", payload, "Payload must be a table")
		
		local players: { Player } = game.Players:GetPlayers()
		if #players > 0 then
			local randomPlayer: Player = players[math.random(1, #players)]
			local header: Header = createHeader("Random")
			self.instance:FireClient(randomPlayer, header, payload)
		end
	end,
	
	--## Client Only ##--
	
	cast = function(self: BaseNode, payload: Payload)
		expectClient("Casting")
		expectInstance("RemoteEvent", "cast()", self.instance)
		expect("table", payload, "Payload must be a table")
		
		local header: Header = createHeader(boundary == "Server" and "Client" or "Server")
		self.instance:FireServer(header, payload)
	end,
	
	--## Remote Function ##--
	
	request = function(self: BaseNode, payload: Payload)
		expectInstance("RemoteFunction", "request()", self.instance)
		expect("table", payload, "Payload must be a table")
		
		if boundary == "Server" then
			
		else
			local header: Header = createHeader("Server")
			local returnPayload: Payload = self.instance:InvokeServer(header, payload)
			expect("table", returnPayload, "`returnPayload` must be a table")
			
			self.signal:Fire(returnPayload)
		end
	end,
}
net.__index = net
return net