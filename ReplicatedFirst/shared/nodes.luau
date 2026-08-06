local net = require("@game/ReplicatedFirst/eva/sys/net")
return {
	nodeA = net.newCastNode({
		name = "NodeA",
		rateLimit = 1,
		reliable = true,
	})
}