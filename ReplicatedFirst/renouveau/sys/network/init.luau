--[=[
	[INFO]
	author: @halosviel
	created: 2026 July 19
	
	[DESCRIPTION]
	Renouveau's networking system. Inspired by the Internet Protocol.
]=]

local expect = require("./expect")

local nodes = require("@game/ReplicatedFirst/client/nodes")
assert(typeof(nodes) == "table", `Table expected for \`nodes\`, got {typeof(nodes)}`)

local Network = {}

function Network.setup()
	if game.RunService:IsServer() then
		--## Set up ReplicatedStorage ##--
		-- customise as needed
		
		local eventIntsancesFolder: Folder = Instance.new("Folder")
		eventIntsancesFolder.Name = "eventInstances"
		eventIntsancesFolder.Parent = game.ReplicatedStorage
		
		for name: string, nodeData: string in nodes do
			local args: { string } = table.pack(nodeData)
			
			local nodeName: string = args[1]
			expect("string", nodeName)
			
			local nodeType: string = args[2]
			expect("string", nodeType)
			
			local instance: string
		end
	elseif game.RunService:IsClient() then
		
	end
end

return Network