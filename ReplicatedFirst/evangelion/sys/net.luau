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
]=]

local expect = require("@game/ReplicatedFirst/evangelion/sys/expect")
local log = require("@game/ReplicatedFirst/evangelion/sys/log")

local signal = require("@game/ReplicatedFirst/evangelion/libs/cuteSignal")

export type Header = {
	sender: string,
	recipent: string,
	timestamp: number
}
export type Payload = { any }

export type NodeMetadata = {
	name: string,
	reliable: boolean?,
	returns: boolean?,
	throttle: number?
}

export type BaseNode = {
	instance: RemoteEvent | UnreliableRemoteEvent | RemoteFunction,
	metadata: NodeMetadata
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
	
	--# its up to you to mark the variable as a CastNode
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
			metadata = metadata
		} :: BaseNode, net)
		
		return self
	end,
}
net.__index = net
return net