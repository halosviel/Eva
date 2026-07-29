--[[


### SERVER ###

local nodes = require("./nodes")

nodes.myEvent:unicast(player)
nodes.myEvent:broadcast()
nodes.myEvent:multicast({player1, player2})
nodes.myevent:anycast()


# REMOTE EVENT
nodes.myEvent.onCast:Connect(function()
	
end)

# REMOTE FUNCTION
nodes.myEvent.onRequest:Connect(function()
	
end)


### CLIENT ###

local nodes = require("./nodes")

# REMOTE EVENT
nodes.myEvent:cast()

# REMOTE FUNCTION
nodes.myEvent:request(response)

end)


]]