--===--===--===--===--===--===--===--===--===--===--===--===--===--

--> Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--> Dependencies
local Maid = require(ReplicatedStorage.Packages.maid)

local Inventory = { Inventories = {} }

--> Types
type Maid = typeof(Maid.new())
export type Inventory = typeof(setmetatable(
	{} :: {
		--> instance variables
		player: Player,
		profile: any,
		inventory: {},
		_onChangeCallbacks: {},
		maid: Maid,

		--> Public Functions
		new: (player: Player, profile: any) -> Inventory,
		Get: (self: Inventory) -> { string },
		OnChanged: (self: Inventory, callback: (tools: { string }) -> ()) -> (),
		NotifyChange: (self: Inventory) -> (),
		Insert: (self: Inventory, toolName: string) -> (boolean, string),
		Remove: (self: Inventory, toolName: string) -> (boolean, string),
		GetInstance: (player: Player) -> Inventory?,
		Destroy: (self: Inventory) -> (),
	},
	Inventory
))

--> Utility Functions

--- Gives a tool to a player by cloning it from storage.
-- @param player Player instance
-- @param toolName Name of the tool to give
local function GiveToolToPlayer(player: Player, toolName: string): ()
	local tool = "path.to.tool"
	if not tool then
		return
	end

	local clonedTool = tool:Clone()
	clonedTool.Parent = player:WaitForChild("Backpack")
end

--- Checks if the player already has a given tool in their character or backpack.
-- @param player Player instance
-- @param toolName Tool name
-- @return boolean True if player has tool
local function PlayerHasTool(player: Player, toolName: string): boolean
	return player:FindFirstChild(toolName) ~= nil
end

--- Loads all tools from the inventory into the player's backpack if missing.
-- @param self Inventory instance
local function LoadPlayerTools(self: Inventory)
	if not self or not self.player then
		return
	end

	for _, toolName in self.inventory do
		if not PlayerHasTool(self.player, toolName) then
			GiveToolToPlayer(self.player, toolName)
		end
	end
end

--> Public Functions

-- Constructor for a player inventory instance

--@param player: The Player instance the inventory is related to
--@param profile: The players profile for data persistance
--@return nil
function Inventory.new(player: Player, profile: any): Inventory?
	local self = setmetatable({
		player = player,
		profile = profile,
		inventory = "path.to.tools",
		_onChangeCallbacks = {},
		maid = Maid.new(),
	}, { __index = Inventory })

	--> Function Calls

	--> Connections
	self.maid:GiveTask(Players.PlayerRemoving:Connect(function(player: Player)
		if Inventory.Inventories[player.UserId] then
			Inventory.Inventories[player.UserId] = nil
		end
		setmetatable(self, nil)
		table.clear(self)
	end))

	self.maid:GiveTask(player.CharacterAdded:Connect(function()
		LoadPlayerTools(self)
	end))

	--> Cache
	Inventory.Inventories[player.UserId] = self

	return self
end

--- Gets a copy of the current inventory list.
-- @return {string} List of tool names
function Inventory.Get(self: Inventory)
	return { table.unpack(self.inventory) }
end

--- Registers a callback for when the inventory changes.
-- @param callback Function called with updated inventory
function Inventory.OnChanged(self: Inventory, callback: () -> ())
	table.insert(self._onChangeCallbacks, callback)
end

--- Notifies all listeners that the inventory has changed.
function Inventory.NotifyChange(self: Inventory)
	if self and self.profile then
		-- Update Data for Persistance Here
	end

	for _, cb in self._onChangeCallbacks do
		task.spawn(function()
			local ok, err = pcall(cb, self:Get())
			if not ok then
				warn("[Inventory] OnChanged callback failed:", err)
			end
		end)
	end
end

--- Inserts a tool into the inventory.
-- @param toolName Tool name
-- @return boolean success, string message
function Inventory.Insert(self: Inventory, toolName: string): (boolean, string)
	if table.find(self.inventory, toolName) then
		return false, "No Duplicates" -- Assuming no duplicates
	end
	table.insert(self.inventory, toolName)

	--> Function Calls
	GiveToolToPlayer(self.player, toolName)
	self:NotifyChange()

	return true, "Success"
end

--- Removes a tool from the inventory.
-- @param toolName Tool name
-- @return boolean success, string message
function Inventory.Remove(self: Inventory, toolName: string): (boolean, string)
	local index = table.find(self.inventory, toolName)
	if not index then
		return false, "Tool not found"
	end

	table.remove(self.inventory, index)

	if self.player.Backpack:FindFirstChild(toolName) then
		local tool = self.player.Backpack:FindFirstChild(toolName)
		if tool and tool:IsA("Tool") then
			tool:Destroy()
		end
	end

	if self.player.Character and self.player.Character:FindFirstChild(toolName) then
		local tool = self.player.Character:FindFirstChild(toolName)
		if tool and tool:IsA("Tool") then
			tool:Destroy()
		end
	end

	self:NotifyChange()
	return true, "Removed"
end

--- Retrieves an inventory instance by player.
-- @param player Player instance
-- @return Inventory? The player's inventory or nil
function Inventory.GetInstance(player: Player): Inventory?
	return Inventory.Inventories[player.UserId]
end

--- Destroys the inventory, cleaning up connections.
function Inventory.Destroy(self)
	self.maid:DoCleaning()
end

return Inventory

--===--===--===--===--===--===--===--===--===--===--===--===--===--
