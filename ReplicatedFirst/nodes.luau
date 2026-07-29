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

export type _RemoteEvent = {
	instance: RemoteEvent,
	metadata: NodeMetadata,
	onCast: signal.Signal,
	lastFired: number,
	unicast: ( self: _RemoteEvent, player: Player, payload: Payload ) -> nil,
	broadcast: ( self: _RemoteEvent, payload: Payload ) -> nil,
	multicast: ( self: _RemoteEvent, players: { Player }, payload: Payload ) -> nil,
	anycast: ( self: _RemoteEvent, payload: Payload ) -> nil,
	cast: ( self: _RemoteEvent, payload: Payload ) -> nil
}

return {
	myNode = {
		reliable = true, -- determines whether the node is a RemoteEvent or an UnreliableRemoteEvent (overrides `returns`)
		returns = false, -- determines whether the node is a RemoteEvent or RemoteFunction
		throttle = 1
	} :: _RemoteEvent,
}