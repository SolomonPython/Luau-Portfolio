--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--

--[[
    Scheduler Module
    ----------------
    Provides a lightweight timer system built on top of RunService.
    Allows you to start, cancel, pause, and resume timers with callbacks
    and optional tick updates.

    Features:
    - Start timers with unique IDs.
    - Supports looping timers (repeat).
    - onTick callbacks for progress updates.
    - Pause and resume functionality.
    - Cleanup via Destroy().
]]

local Scheduler = {}
Scheduler.__index = Scheduler

--@ Services
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

--@ Modules
local T = require(script.Parent.T)
local Bin = require(StarterPlayer.StarterPlayerScripts.Bin.Bin)

--@ Types
export type Timer = {
	id: string, -- Unique identifier for the timer
	callback: () -> ()?, -- Called when timer completes
	duration: number, -- Length of timer in seconds
	elapsed: number, -- Current elapsed time
	looped: boolean, -- Whether timer should repeat
	paused: boolean, -- Whether timer is currently paused
	onTick: ((elapsed: number, remaining: number) -> ())?, -- Called every tickInterval seconds
	_tickAccumulator: number, -- Internal counter for tick intervals
	tickInterval: number, -- Interval for calling onTick
}

export type Scheduler = typeof(setmetatable(
	{} :: {
		_timers: { [string]: Timer },
		Update: (self: Scheduler, dt: number) -> (),
		Start: (self: Scheduler, id: string, duration: number, callback: () -> (), repeatTimer: boolean?) -> (),
		Cancel: (self: Scheduler, id: string) -> (),
		Pause: (self: Scheduler, id: string) -> (),
		Resume: (self: Scheduler, id: string) -> (),
		Destroy: (self: Scheduler) -> (),
	},
	Scheduler
))

--[[
    Creates a new Scheduler instance.
    Automatically hooks into RunService.PostSimulation to update timers.

    @Returns:
        Scheduler
]]
function Scheduler.new()
	local self = setmetatable({}, Scheduler)

	self._timers = {}

	self._bin = Bin.new()
	self._bin:Add(RunService.PostSimulation:Connect(function(deltaTime: number)
		self:Update(deltaTime)
	end))

	return self
end

--[[
    Updates all active timers.
    Called internally every frame via RunService.

    @Params:
        deltaTime (number) - Time since last frame in seconds
]]
function Scheduler:Update(deltaTime: number)
	for id, timer in pairs(self._timers) do
		if timer.paused then
			continue
		end

		timer.elapsed += deltaTime
		timer._tickAccumulator += deltaTime

		-- Fire onTick callback at intervals
		if timer.onTick and timer._tickAccumulator >= timer.tickInterval then
			local remaining = math.max(0, timer.duration - timer.elapsed)
			task.spawn(timer.onTick, timer.elapsed, remaining)
			timer._tickAccumulator -= timer.tickInterval
		end

		-- Timer finished
		if timer.elapsed >= timer.duration then
			if timer.callback and T.callback(timer.callback) then
				task.spawn(timer.callback)
			end

			if timer.looped then
				timer.elapsed -= timer.duration
			else
				self._timers[id] = nil
			end
		end
	end
end

--[[
    Starts or restarts a timer.

    @Params:
        id (string) - Unique identifier for the timer
        duration (number) - Duration in seconds
        callback (function?) - Called when timer finishes
        repeatTimer (boolean?) - If true, timer loops (default: false)
        onTick (function?) - Called every tickInterval (elapsed, remaining)
        tickInterval (number?) - Interval in seconds for onTick (default: 1)

    Example:
        scheduler:Start("MyTimer", 10, function()
            print("Timer finished!")
        end, false, function(elapsed, remaining)
            print("Elapsed:", elapsed, "Remaining:", remaining)
        end, 1)
]]
function Scheduler:Start(
	id: string,
	duration: number,
	callback: () -> ()?,
	repeatTimer: boolean?,
	onTick: ((elapsed: number, remaining: number) -> ())?,
	tickInterval: number?
): ()
	if self._timers[id] then
		warn("Timer with id " .. id .. " already exists. Overwriting.")
	end

	self._timers[id] = {
		id = id,
		callback = callback,
		duration = duration,
		elapsed = 0,
		looped = repeatTimer or false,
		paused = false,
		onTick = onTick,
		_tickAccumulator = 0,
		tickInterval = tickInterval or 1,
	}
end

--[[
    Cancels a timer by ID.
    @Params:
        id (string) - Timer identifier
]]
function Scheduler:Cancel(id: string)
	self._timers[id] = nil
end

--[[
    Pauses a timer by ID.
    @Params:
        id (string) - Timer identifier
]]
function Scheduler:Pause(id: string)
	local timer = self._timers[id]
	if timer then
		timer.paused = true
	end
end

--[[
    Resumes a paused timer by ID.
    @Params:
        id (string) - Timer identifier
]]
function Scheduler:Resume(id: string)
	local timer = self._timers[id]
	if timer then
		timer.paused = false
	end
end

--[[
    Destroys the Scheduler and clears all timers.
    Disconnects from RunService and cleans up memory.
]]
function Scheduler:Destroy()
	self._bin:Destroy()
	self._timers = nil

	setmetatable(self, nil)
	table.clear(self)
end

return Scheduler
--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--
