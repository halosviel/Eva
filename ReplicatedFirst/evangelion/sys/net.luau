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

local signal = require("@game/ReplicatedFirst/evangelion/libs/cuteSignal")

export type Header = {
	sender: string,
	recipent: string,
	timestamp: number
}
export type Payload = { any }

export type NodeMetadata = {
	reliable: boolean?,
	returns: boolean?,
	throttle: number?
}

--# Cast Node -> Remote Event
--# Request Node -> Remote Function

export type CastNode = {
	instance: RemoteEvent,
	metadata: NodeMetadata,
	onCast: signal.Signal,
	lastFired: number,
	unicast: ( self: CastNode, player: Player, payload: Payload ) -> nil,
	broadcast: ( self: CastNode, payload: Payload ) -> nil,
	multicast: ( self: CastNode, players: { Player }, payload: Payload ) -> nil,
	anycast: ( self: CastNode, payload: Payload ) -> nil,
	cast: ( self: CastNode, payload: Payload ) -> nil
}

export type RequestNode = {
	onRequest: signal.Signal,
	request: ( self: RequestNode ) -> nil
}

-->

local net
net = {
	newNode = function(metadata: NodeMetadata)
		local self = setmetatable({
			
		}, net)
		return self
	end,
}
net.__index = net
return net