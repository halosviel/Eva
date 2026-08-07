--[=[
	[INFO]
	author: @halosviel
	created: 2026 July 15
	
	[DESCRIPTION]
	A rewrite and successor of Pip's `processTimer` module.
	
	Allows scripts to create a class, which as long as it is alive,
	will push warns across numbered milestones indicating that a process
	is still running and taking longer than expected.
	
	[USAGE]
	```
	local clock: processClock.ProcessClock
	clock = processClock.new({
		name = "myProcessClock",
		callback = function()
			clock = nil
		end,
		milestones = {5, 10, 15}, --# optional
		log = true				  --# optional, default true
	})
	
	clock:Destroy()
	clock = nil
	```
	
	[NOTES]
	- The class can be destroyed mid-execution :D
	- The callback must set the object to nil!!!
	- The callback is not pcalled! It assumes that the caller is just
	  setting the object to nil (what more are you to do when a time
	  finishes anyway?).
]=]

--## CONFIG ##--

local DEFAULT_MILESTONES = { 5, 15, 30, 60, 120, 300, 600, 1000 }

--## IMPORTS ##--

local class = require("@game/ReplicatedFirst/eva/sys/class")
local expect = require("@game/ReplicatedFirst/eva/sys/expect")
local signal = require("@game/ReplicatedFirst/eva/libs/cuteSignal")

--## TYPES ##--

export type Config = {
	name: string,
	callback: () -> nil,
	milestones: { number }?,
	log: boolean
}

type self = {
	config: Config,
	startTimestamp: number,
	thread: thread,
	destroyed: boolean,
	onUpdate: signal.Signal,
	onMilestone: signal.Signal,
	new: ( self: self ) -> nil,
	Destroy: ( self: self ) -> nil,
	ready: ( self: self ) -> nil
}
export type ProcessClock = self

--## PROCESS CLOCK ##--

return class {
	new = function(self: self, config: Config)
		expect("table", config)
		expect("string", config.name)
		expect("function", config.callback)
		
		if config.milestones then
			expect("table", config.milestones)
			for _, value: number in config.milestones do
				expect("number", value)
			end
		else
			config.milestones = DEFAULT_MILESTONES
		end
		
		if config.log ~= nil then
			expect("boolean", config.log)
		else
			config.log = true
		end
		
		self.config = config
		
		self.startTimestamp = os.clock()
		self.thread = nil
		self.destroyed = false
		self.onUpdate = signal.new()
		self.onMilestone = signal.new()
	end,
	
	Destroy = function(self: self)
		if self.destroyed == true then
			return
		end
		self.destroyed = true
		
		if self.onUpdate then
			self.onUpdate:Destroy()
			self.onUpdate = nil
		end
		
		if self.onMilestone then
			self.onMilestone:Destroy()
			self.onMilestone = nil
		end
		
		self.config.callback()
	end,
	
	ready = function(self: self)
		self.thread = task.spawn(function()
			local index: number = 1
			
			while true do
				task.wait(1)
				
				if self.destroyed == true then
					return
				end
				
				local elapsed: number = math.floor(os.clock() - self.startTimestamp)
				self.onUpdate:Fire(elapsed)
				
				--# clanker warns of drift, but i doubt it
				if elapsed == self.config.milestones[index] then
					if self.config.log == true then
						warn(`Process \`{self.config.name}\` taking longer than usual ({self.config.milestones[index]}s)`)
					end
					
					self.onMilestone:Fire(index)
					index += 1
					
					if self.config.milestones[index] == nil then
						if self.config.log == true then
							warn(`Process \`{self.config.name}\` timed out`)
						end
						
						self:Destroy()
						return
					end
				end
			end
		end)
	end,
}