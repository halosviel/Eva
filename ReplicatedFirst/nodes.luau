local Node = require("")

return {
	myNode = {
		reliable = true, -- determines whether the node is a RemoteEvent or an UnreliableRemoteEvent (overrides `returns`)
		returns = false, -- determines whether the node is a RemoteEvent or RemoteFunction
		throttle = 1
	} :: _RemoteEvent,
}