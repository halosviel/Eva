local net = require("@game/ReplicatedFirst/eva/sys/net")
local nodeTypes = require("@game/ReplicatedFirst/client/types/nodes")

return {
	nodeA = net.newCastNode({
		name = "NodeA",
		rateLimit = 0,
		reliable = true,
	} :: net.Metadata),

	nodeB = net.newCastNode({
		name = "NodeB",
		rateLimit = 1,
		reliable = true,
	} :: net.Metadata)
}