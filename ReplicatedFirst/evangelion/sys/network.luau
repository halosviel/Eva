--[=[
	[INFO]
	author: @halosviel
	created: 2026 July 19
	
	[DESCRIPTION]
	Evangelion's networking system. Inspired by the Internet Protocol.
	
	On runtime, the metadata in the `nodes` module are replaced with an object.
	
	[NOTES]
	- One downside to this system is that all nodes have access to all types.
]=]

local expect = require("./expect")
local log = require("./log")

local nodes = require("@game/ReplicatedFirst/client/nodes")
assert(typeof(nodes) == "table", `Table expected for \`nodes\`, got {typeof(nodes)}`)

type NodeMetadata = {
	reliable: boolean?,
	returns: boolean?,
	throttle: number?,
	paramCount: number?
}

local Network = {}

function Network.setup()
	if game.RunService:IsServer() then
		--## Set up Events Folder ##--
		
		local eventsFolder: Folder = Instance.new("Folder")
		eventsFolder.Name = "events"
		eventsFolder.Parent = game.ReplicatedStorage
		
		--## Create Event Instances ##--
		
		for nodeName: string, metadata: NodeMetadata in nodes do
			--## Validate ##--
			expect("string", nodeName, "Node must have a string key")
			expect("table", metadata, `Node must have a table value`)
			
			if metadata.reliable == nil and metadata.returns == nil then
				log(1, "Missing values", `Node \`{nodeName}\` could not be evaluated; must have \`reliable\` or \`returns\` attributes!`)
			end
			
			--# prep default data
			local instance: string?
			local throttle: number? = 0 --# no cooldown
			local paramCount: number? = math.huge --# inf params
			
			if metadata.reliable ~= nil then
				expect("boolean", metadata.reliable, "`metadata.reliable` must be a boolean")
			end
			if metadata.returns ~= nil then
				expect("boolean", metadata.returns, "`metadata.returns` must be a boolean")
			end
			if metadata.throttle ~= nil then
				expect("number", metadata.throttle, "`metadata.throttle` must be a number")
				throttle = metadata.throttle
			end
			if metadata.paramCount ~= nil then
				expect("number", metadata.paramCount, "`metadata.paramCount` must be a number")
				paramCount = metadata.paramCount
			end
			
			--## Create Instances ##--
			
			if metadata.reliable == false then
				instance = Instance.new("UnreliableRemoteEvent")
			elseif metadata.returns == true then
				instance = Instance.new("RemoteFunction")
			else
				instance = Instance.new("RemoteEvent")
			end
			
			instance.Name = nodeName
			instance.Parent = eventsFolder
			
			--## Overwrite Nodes Module ##--
			
			nodes[nodeName] = instance
		end
	elseif game.RunService:IsClient() then
		--## Find Events Folder ##--
		
		local eventsFolder: Folder = game.ReplicatedStorage:WaitForChild("events")
		
		--## Overwrite Nodes Module ##--
		
		local function overwriteNode(event: Instance)
			nodes[event.Name] = event
		end
		
		eventsFolder.ChildAdded:Connect(overwriteNode)
		for _, event: Instance in eventsFolder:GetChildren() do
			overwriteNode(event)
		end
	end
end

return Network