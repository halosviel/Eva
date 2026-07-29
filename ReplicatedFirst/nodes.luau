local signal = require("@game/ReplicatedFirst/evangelion/libs/cuteSignal")

export type Header = {
	sender: string,
	recipent: string,
	timestamp: number
}
export type Payload = { any }

export type _RemoteEvent = {
	instance: RemoteEvent,
	unicast: ( self: _RemoteEvent, player: Player, payload: Payload ) -> nil,
	broadcast: ( self: _RemoteEvent, payload: Payload ) -> nil,
	multicast: ( self: _RemoteEvent, players: { Player }, payload: Payload ) -> nil,
	anycast: ( self: _RemoteEvent, payload: Payload ) -> nil,
	cast: ( self: _RemoteEvent, payload: Payload ) -> nil,
	onCast: signal.Signal,
}

return {
	myNode = {
		reliable = true, -- determines whether the node is a RemoteEvent or an UnreliableRemoteEvent (overrides `returns`)
		returns = false, -- determines whether the node is a RemoteEvent or RemoteFunction
		throttle = 1,
		paramCount = 1,
	} :: _RemoteEvent,
}