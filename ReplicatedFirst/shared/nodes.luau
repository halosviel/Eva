local net = require("@game/ReplicatedFirst/eva/sys/net")
local nodeTypes = require("@game/ReplicatedFirst/client/types/nodes")

return {
	nodeA = net.newCastNode({
		name = "NodeA",
		rateLimit = 1,
		reliable = true,
	} :: net.Metadata)
}