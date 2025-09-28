--@ Personal Cleanup Module By SolomonPython

local Bin = {}
Bin.__index = Bin

--@Types
export type Task = () -> () | RBXScriptConnection | Instance | Bin

export type Bin = typeof(setmetatable(
	{} :: {
		_tasks: { [number | string]: Task },
		_taskId: number,
		_tags: { [string]: { number | string } },
		_onDestroy: { () -> () },
		_destroyed: boolean,

		new: () -> Bin,

		Add: (self: Bin, task: Task, tag: string?) -> number | string,
		AddNamed: (self: Bin, name: string, task: Task, tag: string?) -> string,
		Remove: (self: Bin, id: number | string) -> (),
		RemoveTagged: (self: Bin, tag: string) -> (),
		LinkInstance: (self: Bin, instance: Instance, tag: string?) -> (),
		LinkPlayer: (self: Bin, player: Player, tag: string?) -> (),
		Extend: (self: Bin, other: Bin) -> (),
		OnDestroy: (self: Bin, fn: () -> ()) -> (),
		Destroy: (self: Bin) -> (),
		DestroyAfter: (self: Bin, delayTime: number) -> (),

		HasTag: (self: Bin, tag: string) -> boolean,
		FindByTag: (self: Bin, tag: string) -> { Task },
		GetTags: (self: Bin) -> { string },
		IsDestroyed: (self: Bin) -> boolean,
		DestroyWhen: (self: Bin, signal: RBXScriptSignal) -> (),
	},
	Bin
))

--@Constructor
function Bin.new()
	return setmetatable({
		_tasks = {} :: { [number]: Task },
		_taskId = 0,
		_tags = {} :: { [string]: number },
		_onDestroy = {},
		_destroyed = false,
	}, Bin)
end

--@Public Functions

--[[ 
	Adds a cleanup task to the bin.
	@param task: Task
	-- Optionally assigns a tag to group tasks.
	@return id: number (used to remove task later if needed)
]]
function Bin:Add(task: Task, tag: string?): number
	assert(task ~= nil, "Task must not be nil")

	self._taskId += 1
	local id = self._taskId
	self._tasks[id] = task

	if tag then
		self._tags[tag] = self._tags[tag] or {}
		table.insert(self._tags[tag], id)
	end

	return id
end

--[[ 
	Adds (or overwrites) a named cleanup task.
	Useful for long-lived connections where only one should exist at a time.
	@param name: string
	@param task: Task
]]
function Bin:AddNamed(name: string, task: Task, tag: string?): string
	if self._tasks[name] then
		self:Remove(name)
	end
	self._tasks[name] = task

	if tag then
		self._tags[tag] = self._tags[tag] or {}
		table.insert(self._tags[tag], name)
	end

	return name
end

--[[ 
	Removes and cleans up a task by ID or name.
	@param id: number | string
]]
function Bin:Remove(id: number | string)
	local task = self._tasks[id]
	if not task then
		return
	end
	self._tasks[id] = nil

	if type(task) == "function" then
		task()
	elseif typeof(task) == "RBXScriptConnection" then
		if task.Connected then
			task:Disconnect()
		end
	elseif typeof(task) == "Instance" then
		if task.Parent then
			task:Destroy()
		end
	elseif getmetatable(task) == Bin then
		task:Destroy()
	end
end

--[[ 
	Removes all tasks with the given tag.
	@param tag: string
]]
function Bin:RemoveTagged(tag: string)
	local tagged = self._tags[tag]
	if not tagged then
		return
	end

	for _, id in ipairs(tagged) do
		self:Remove(id)
	end
	self._tags[tag] = nil
end

--[[ 
	Registers a callback to run when an instance is destroyed.
	The callback will only fire once.
	@param instance: Instance
	@param callback: () -> ()
	@return id: number (the cleanup id for the connection)
]]
function Bin:OnInstanceRemoved(instance: Instance, callback: () -> ()): number
	assert(typeof(instance) == "Instance", "Expected Instance")
	assert(type(callback) == "function", "Expected function")

	local conn
	conn = instance.Destroying:Connect(function()
		callback()
		if conn.Connected then
			conn:Disconnect()
		end
	end)
	return self:Add(conn)
end

-- Creates a child bin tied to the player's lifetime
function Bin:WithPlayer(player: Player): Bin
	assert(player and player:IsA("Player"), "Expected valid Player")

	local child = Bin.new()
	self:Add(child) -- ensures child is cleaned if parent is destroyed

	local conn
	conn = player.AncestryChanged:Connect(function(_, parent)
		if not parent then
			child:Destroy()
			if conn.Connected then
				conn:Disconnect()
			end
		end
	end)
	self:Add(conn)

	return child
end

--[[ 
	Links the bin's lifetime to an instance.
	If the instance is destroyed, this bin is also destroyed.
]]
function Bin:LinkInstance(instance: Instance, tag: string?)
	local conn
	conn = instance.Destroying:Connect(function()
		self:Destroy()
		if conn.Connected then
			conn:Disconnect()
		end
	end)
	self:Add(conn, tag)
end

--[[ 
	Links the bin's lifetime to a player's lifetime.
	If the player leaves, this bin is destroyed.
]]
function Bin:LinkPlayer(player: Player, tag: string?)
	assert(player and player:IsDescendantOf(game), "Player must be valid")

	local conn
	conn = player.AncestryChanged:Connect(function(_, parent)
		if not parent then
			self:Destroy()
			if conn.Connected then
				conn:Disconnect()
			end
		end
	end)
	self:Add(conn, tag)
end

--[[ 
	Merges another bin into this one, adopting its tasks.
	@param other: Bin
]]
function Bin:Extend(other: Bin)
	for id, task in pairs(other._tasks) do
		self:Add(task)
	end
	other:Destroy()
end

--[[ 
	Registers a callback that runs after cleanup.
	@param fn: () -> ()
]]
function Bin:OnDestroy(fn: () -> ())
	table.insert(self._onDestroy, fn)
end

--[[ 
	Schedules the bin to destroy itself after a delay.
	@param delayTime: number
]]
function Bin:DestroyAfter(delayTime: number)
	task.delay(delayTime, function()
		if self:HasTasks() then
			self:Destroy()
		end
	end)
end

--[[ 
	Counts all tasks in the bin.
	Note: includes both numeric and named tasks.
	@return boolean
]]
function Bin:HasTasks(): boolean
	return next(self._tasks) ~= nil
end

--[[ 
	Checks whether the bin has been destroyed.
	@return boolean
]]
function Bin:IsDestroyed(): boolean
	return self._destroyed
end

--[[ 
	Returns all tasks associated with a given tag.
	@param tag: string
	@return {Task}
]]
function Bin:FindByTag(tag: string): { Task }
	local tagged = self._tags[tag]
	if not tagged then
		return {}
	end

	local results = {}
	for _, id in ipairs(tagged) do
		local task = self._tasks[id]
		if task then
			table.insert(results, task)
		end
	end
	return results
end

--[[ 
	Checks if any task exists under a given tag.
	@param tag: string
	@return boolean
]]
function Bin:HasTag(tag: string): boolean
	return self._tags[tag] ~= nil
end

--[[ 
	Returns all active tags in the bin.
	@return {string}
]]
function Bin:GetTags(): { string }
	local tags = {}
	for tag in pairs(self._tags) do
		table.insert(tags, tag)
	end
	return tags
end

--[[ 
	Automatically destroys the bin when a given signal fires.
	@param signal: RBXScriptSignal
]]
function Bin:DestroyWhen(signal: RBXScriptSignal)
	local conn
	conn = signal:Connect(function()
		self:Destroy()
		if conn.Connected then
			conn:Disconnect()
		end
	end)
	self:Add(conn)
end

--[[ 
	Counts all tasks in the bin.
	Note: includes both numeric and named tasks.
	@return number
]]
function Bin:GetTaskCount(): number
	local count = 0
	for _ in pairs(self._tasks) do
		count += 1
	end
	return count
end

--[[ 
	Cleans up all tasks in the bin.
	Recursive if tasks are also bins.
]]
function Bin:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true

	for id in pairs(self._tasks) do
		self:Remove(id)
	end

	self._tasks = {}
	self._tags = {}

	for _, fn in ipairs(self._onDestroy) do
		local ok, err = pcall(fn)
		if not ok then
			warn("[Bin]: OnDestroy callback error -", err)
		end
	end
	self._onDestroy = {}
end

--@ Utility Functions

--[[ 
	Adds a task that runs once after a delay.
	@param delayTime: number
	@param fn: () -> ()
	@param tag: string?
	@return id: number
]]
function Bin:Timeout(delayTime: number, fn: () -> (), tag: string?): number
	return self:Add(task.delay(delayTime, fn), tag)
end

--[[ 
	Wraps a connection so that the callback auto-disconnects after firing once.
	@param signal: RBXScriptSignal
	@param fn: (...any) -> ()
	@param tag: string?
	@return id: number
]]
function Bin:Once(signal: RBXScriptSignal, fn: (...any) -> (), tag: string?): number
	local conn
	conn = signal:Connect(function(...)
		fn(...)
		if conn.Connected then
			conn:Disconnect()
		end
	end)
	return self:Add(conn, tag)
end

--[[ 
	Attempts to clean up a task immediately without erroring.
	@param task: Task
	@return void
]]
function Bin.SafeCleanup(task: Task)
	if not task then
		return
	end

	if type(task) == "function" then
		pcall(task)
	elseif typeof(task) == "RBXScriptConnection" then
		if task.Connected then
			pcall(function()
				task:Disconnect()
			end)
		end
	elseif typeof(task) == "Instance" then
		if task.Parent then
			pcall(function()
				task:Destroy()
			end)
		end
	elseif getmetatable(task) == Bin then
		task:Destroy()
	end
end

--@Aliases
Bin.Cleanup = Bin.Destroy

return Bin
