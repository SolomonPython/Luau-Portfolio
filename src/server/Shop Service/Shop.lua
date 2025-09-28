--[[
    Shop Module
    -----------
    Manages shop inventory and restocking.
    Utilizes a Scheduler for timed restocks.
    By SolomonPython
]]

--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--
local Shop = {}
Shop.__index = Shop

--@ Services
local ServerScriptService = game:GetService("ServerScriptService")

--@ Modules
local Scheduler = require(ServerScriptService["Shop Service"].Dependencies.Scheduler)

--@ Objects
local RestockTimer = Scheduler.new()

--@ Constants
local RESTOCK_INTERVAL = 300
local MAX_RESTOCK_PER_TICK = 100

--@ Types
export type Item = {

	--@ Properties
	name: string,
	max_stock: number,
	current_stock: number,
	weight: number,
	cost: number,
	rarity: string,
	robux: number,

	--@ Signals
	OnStockChanged: any,
	OnPurchase: any,
	OnRestock: any,
}

export type Schema = { [string]: Item }
export type Shop = typeof(setmetatable({} :: {}, Shop))

--@ Utility Functions
local function Signal()
	local listeners = {}
	return {
		Connect = function(_, fn)
			table.insert(listeners, fn)
			return {
				Disconnect = function()
					for i, f in ipairs(listeners) do
						if f == fn then
							table.remove(listeners, i)
							break
						end
					end
				end,
			}
		end,
		Fire = function(_, ...)
			for _, fn in ipairs(listeners) do
				fn(...)
			end
		end,
	}
end

--@ Private Methods
function Shop:_AddSignals(schema: Schema)
	for key, item in pairs(schema) do
		local copy: Item = table.clone(item) :: Item

		copy.OnStockChanged = Signal()
		copy.OnPurchase = Signal()
		copy.OnRestock = Signal()

		self._items[key] = copy
	end
end

--@ Constructor
function Shop.new(schema: Schema)
	local self = setmetatable({}, Shop)

	self._items = {}

	self.OnAnyPurchase = Signal()
	self.OnAnyRestock = Signal()

	self:_AddSignals(schema)

	return self
end

--@ Public Methods
function Shop:GetItem(key: string): Item?
	return self._items[key]
end

function Shop:Purchase(key: string, quantity: number): boolean
	local item = self._items[key]

	if not item then
		warn("Item not found:", key)
		return false
	end

	if item.current_stock < quantity then
		warn("Insufficient stock for item:", key)
		return false
	end

	item.current_stock -= quantity

	--@ Fire Signals
	item.OnStockChanged:Fire(item.current_stock)
	item.OnPurchase:Fire(quantity, key)
	self.OnAnyPurchase:Fire(key, quantity)

	return true
end

function Shop:Restock(key: string, quantity: number): boolean
	local item = self._items[key]

	if not item then
		warn("Item not found:", key)
		return false
	end

	if item.current_stock + quantity > item.max_stock then
		warn("Exceeds max stock for item:", key)
		return false
	end

	item.current_stock = math.min(item.max_stock, item.current_stock + quantity)

	--@ Fire Signals
	item.OnStockChanged:Fire(item.current_stock)
	item.OnRestock:Fire(quantity, key)
	self.OnAnyRestock:Fire(key, quantity)

	return true
end

function Shop:RestockAll()
	--@ Create a weighted pool of items based on how much they can be restocked
	local weightedPool = {}

	for key, item in pairs(self._items) do
		if item.current_stock < item.max_stock then
			local deficit = item.max_stock - item.current_stock
			local score = deficit * item.weight -- weight scales restock probability

			for _ = 1, math.floor(score) do
				table.insert(weightedPool, key)
			end
		end
	end

	if #weightedPool == 0 then
		return
	end

	--@ Decide how many items to restock per tick
	local restockCount = MAX_RESTOCK_PER_TICK
	for _ = 1, restockCount do
		local key = weightedPool[math.random(1, #weightedPool)]
		local item = self._items[key]

		if item.current_stock < item.max_stock then
			item.current_stock += 1

			-- Fire signals
			item.OnStockChanged:Fire(item.current_stock)
			item.OnRestock:Fire(1)
			self.OnAnyRestock:Fire(key, 1)
		end
	end
end

function Shop:GetData()
	local data = {}
	for key, item in pairs(self._items) do
		data[key] = {
			name = item.name,
			stock = item.current_stock,
			max = item.max_stock,
			weight = item.weight,
			cost = item.cost,
			rarity = item.rarity,
			robux = item.robux,
		}
	end
	return data
end

--@ Start the restock loop
RestockTimer:Start(
	"ShopRestock",
	RESTOCK_INTERVAL,
	function()
		Shop:RestockAll()
	end,
	true,
	function(elapsed: number, remaining: number)
		warn(string.format("Next restock in %.2f seconds", remaining))
	end,
	1
)

return Shop
--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--
