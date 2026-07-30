local net = require("@game/ReplicatedFirst/evangelion/sys/net")

return {
	nodeA = net.newNode({
		name = "NodeA",
		reliable = true,
		returns = false,
		throttle = 0
	} :: net.NodeMetadata) :: net.CastNode
}