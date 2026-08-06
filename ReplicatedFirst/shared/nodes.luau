local net = require("@game/ReplicatedFirst/eva/sys/net")

export type Header = {
	sender: string,
	recipent: string,
	timestamp: number
}
export type Payload = { [string]: any }

return {
	nodeA = net.newCastNode({
		name = "NodeA",
		rateLimit = 1,
		reliable = true,
	})
}