--===--===--===--===--===--===--===--===--===--===--===--===--===--
local Yield = {}

--@ Types
export type WaitOptions = {
	method: "poll" | "event",
	timeout: number?,
}

--@ Utility Functions
local function NormalizeOptions(options: WaitOptions?): WaitOptions
	return {
		method = options and options.method or "event",
		timeout = options and options.timeout or 2,
	}
end

local function SafeDisconnect(conn: RBXScriptConnection?)
	if conn and conn.Connected then
		conn:Disconnect()
	end
end

--@ Main Functions

--[[
	Wait for a single attribute
	@param instance Instance -- The instance to wait on
	@param attributeName string -- Attribute name
	@param options WaitOptions? -- Options (method, timeout)
	@return T?, boolean -- Value, didTimeout
]]
function Yield.WaitForAttribute<T>(instance: Instance?, attributeName: string, options: WaitOptions?): (T?, boolean)
	assert(instance, "Instance is nil")
	assert(typeof(attributeName) == "string", "Attribute name must be a string")

	local opts = NormalizeOptions(options)
	local deadline = os.clock() + opts.timeout

	-- Polling Method
	if opts.method == "poll" then
		while os.clock() < deadline do
			local value = instance:GetAttribute(attributeName)
			if value ~= nil then
				return value :: T, false
			end
			task.wait()
		end
		return nil, true
	end

	-- Event Method
	local current = instance:GetAttribute(attributeName)
	if current ~= nil then
		return current :: T, false
	end

	local result: T? = nil
	local finished = false
	local conn = instance:GetAttributeChangedSignal(attributeName):Connect(function()
		local value = instance:GetAttribute(attributeName)
		if value ~= nil then
			result = value :: T
			finished = true
		end
	end)

	while not finished and os.clock() < deadline do
		task.wait()
	end

	SafeDisconnect(conn)
	return result, not finished
end

--[[
	Wait for multiple attributes
	@param instance Instance
	@param attributeNames {string}
	@param options WaitOptions?
	@return {[string]: T?}, boolean -- Results, didTimeout
]]
function Yield.WaitForAttributes<T>(
	instance: Instance?,
	attributeNames: { string },
	options: WaitOptions?
): ({ [string]: T? }, boolean)
	assert(instance, "Instance is nil")
	for _, name in attributeNames do
		assert(typeof(name) == "string", "Attribute name must be a string")
	end

	local opts = NormalizeOptions(options)
	local deadline = os.clock() + opts.timeout

	-- Polling Method
	if opts.method == "poll" then
		local results: { [string]: T? } = {}
		while os.clock() < deadline do
			local allFound = true
			for _, attr in ipairs(attributeNames) do
				local value = instance:GetAttribute(attr)
				results[attr] = value :: T?
				if value == nil then
					allFound = false
				end
			end
			if allFound then
				return results, false
			end
			task.wait()
		end
		return results, true
	end

	-- Event Method
	local results: { [string]: T? } = {}
	local missing = {}

	for _, attr in ipairs(attributeNames) do
		local value = instance:GetAttribute(attr)
		if value ~= nil then
			results[attr] = value :: T
		else
			table.insert(missing, attr)
		end
	end

	if #missing == 0 then
		return results, false
	end

	local conn
	conn = instance.AttributeChanged:Connect(function(attr)
		local idx = table.find(missing, attr)
		if idx then
			local value = instance:GetAttribute(attr)
			if value ~= nil then
				results[attr] = value :: T
				table.remove(missing, idx)
				if #missing == 0 then
					SafeDisconnect(conn)
				end
			end
		end
	end)

	while #missing > 0 and os.clock() < deadline do
		task.wait()
	end

	SafeDisconnect(conn)
	return results, #missing > 0
end

--[[
	Wait for a child of a given class
	@param parent Instance
	@param className string
	@param options WaitOptions?
	@return T?, boolean -- Child instance, didTimeout
]]
function Yield.ForChildOfClass<T>(parent: Instance?, className: string, options: WaitOptions?): (T?, boolean)
	assert(parent, "Parent is nil")
	assert(typeof(className) == "string", "ClassName must be a string")

	local opts = NormalizeOptions(options)
	local deadline = os.clock() + opts.timeout

	-- Polling Method
	if opts.method == "poll" then
		while os.clock() < deadline do
			local obj = parent:FindFirstChildOfClass(className)
			if obj then
				return obj :: T, false
			end
			task.wait()
		end
		return nil, true
	end

	-- Event Method
	local obj = parent:FindFirstChildOfClass(className)
	if obj then
		return obj :: T, false
	end

	local result: T? = nil
	local finished = false
	local conn = parent.ChildAdded:Connect(function(child)
		if child.ClassName == className then
			result = child :: T
			finished = true
		end
	end)

	while not finished and os.clock() < deadline do
		task.wait()
	end

	SafeDisconnect(conn)
	return result, not finished
end

--[[
	Wait for a descendant of a given class
	@param parent Instance
	@param className string
	@param options WaitOptions?
	@return T?, boolean -- Descendant instance, didTimeout
]]
function Yield.ForDescendantOfClass<T>(parent: Instance?, className: string, options: WaitOptions?): (T?, boolean)
	assert(parent, "Parent is nil")
	assert(typeof(className) == "string", "ClassName must be a string")

	local opts = NormalizeOptions(options)
	local deadline = os.clock() + opts.timeout

	-- Polling Method
	if opts.method == "poll" then
		while os.clock() < deadline do
			local obj = parent:FindFirstChildWhichIsA(className, true) -- deep search
			if obj then
				return obj :: T, false
			end
			task.wait()
		end
		return nil, true
	end

	-- Event Method
	local obj = parent:FindFirstChildWhichIsA(className, true)
	if obj then
		return obj :: T, false
	end

	local result: T? = nil
	local finished = false
	local conn = parent.DescendantAdded:Connect(function(child)
		if child:IsA(className) then
			result = child :: T
			finished = true
		end
	end)

	while not finished and os.clock() < deadline do
		task.wait()
	end

	SafeDisconnect(conn)
	return result, not finished
end

--[[
	Wait for a descendant with a given name
	@param parent Instance
	@param childName string
	@param options WaitOptions?
	@return T?, boolean -- Descendant instance, didTimeout
]]
function Yield.ForDescendantNamed<T>(parent: Instance?, childName: string, options: WaitOptions?): (T?, boolean)
	assert(parent, "Parent is nil")
	assert(typeof(childName) == "string", "Child name must be a string")

	local opts = NormalizeOptions(options)
	local deadline = os.clock() + opts.timeout

	-- Polling Method
	if opts.method == "poll" then
		while os.clock() < deadline do
			local obj = parent:FindFirstChild(childName, true) -- deep search
			if obj then
				return obj :: T, false
			end
			task.wait()
		end
		return nil, true
	end

	-- Event Method
	local obj = parent:FindFirstChild(childName, true)
	if obj then
		return obj :: T, false
	end

	local result: T? = nil
	local finished = false
	local conn = parent.DescendantAdded:Connect(function(child)
		if child.Name == childName then
			result = child :: T
			finished = true
		end
	end)

	while not finished and os.clock() < deadline do
		task.wait()
	end

	SafeDisconnect(conn)
	return result, not finished
end

return Yield
--===--===--===--===--===--===--===--===--===--===--===--===--===--
