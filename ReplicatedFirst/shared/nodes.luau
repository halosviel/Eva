local ipcast = require("@game/ReplicatedFirst/eva/sys/ipcast")
local nodeTypes = require("@game/ReplicatedFirst/client/types/nodes")

return {
	nodeA = ipcast.newCastNode({
		name = "NodeA",
		rateLimit = 0,
		reliable = true,
	} :: ipcast.Metadata),

	nodeB = ipcast.newRequestNode({
		name = "NodeB",
		rateLimit = 1,
	} :: ipcast.Metadata)
}