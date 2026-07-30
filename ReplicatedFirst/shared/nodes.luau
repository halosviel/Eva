local net = require("@game/ReplicatedFirst/eva/sys/net")

export type Header = {
	sender: string,
	recipent: string,
	timestamp: number
}
export type Payload = { [string]: any }

return {
	nodeA = net.newNode({
		name = "NodeA",
		reliable = true,
		returns = true,
		throttle = 1
	} :: net.NodeMetadata) :: net.RequestNode,
	
	nodeB = net.newNode({
		name = "NodeB",
		reliable = true,
		returns = false,
		throttle = 0
	} :: net.NodeMetadata) :: net.CastNode
}