--===--===--===--===--===--===--===--===--===--===--===--===--===--

--> Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

--> Dependencies
local Maid = require(ReplicatedStorage.Packages.maid)

local Cutscene = {}

--> Types
export type ICutscene = typeof(setmetatable(
	{} :: {
		-- Instance Properties
		camera: Camera,
		targetCFrames: { CFrame },
		duration: number,
		easingStyle: Enum.EasingStyle,
		easingDirection: Enum.EasingDirection,
		tweens: { Tween },
		isComplete: boolean,
		shouldLoop: boolean,
		loopCount: number?,
		maid: any,

		-- Instance Methods
		Start: (self: ICutscene, onComplete: (() -> ())?) -> (),
		End: (self: ICutscene) -> (),
		Add: (self: ICutscene, targets: { CFrame }) -> (),
		Destroy: (self: ICutscene) -> (),
	},
	Cutscene
))

--[=[
	Creates a new cutscene instance.

	@param camera Camera -- The camera used for the cutscene
	@param targetCFrames {CFrame} -- The sequence of CFrames for the camera to tween through
	@param duration number? -- Time (in seconds) per tween step (default: 5)
	@param easingStyle Enum.EasingStyle? -- Tween easing style (default: Sine)
	@param easingDirection Enum.EasingDirection? -- Tween easing direction (default: InOut)
	@param shouldLoop boolean? -- Whether to loop the cutscene (default: false)
	@param loopCount number? -- Number of loops before ending (nil = infinite if shouldLoop is true)

	@return ICutscene
]=]
function Cutscene.new(
	camera: Camera,
	targetCFrames: { CFrame },
	duration: number?,
	easingStyle: Enum.EasingStyle?,
	easingDirection: Enum.EasingDirection,
	shouldLoop: boolean?,
	loopCount: number?
)
	local self = setmetatable({
		camera = camera,
		targetCFrames = targetCFrames,
		duration = duration or 5,
		easingStyle = easingStyle or Enum.EasingStyle.Sine,
		easingDirection = easingDirection or Enum.EasingDirection.InOut,
		tweens = {},
		isComplete = false,
		shouldLoop = shouldLoop or false,
		loopCount = loopCount,

		maid = Maid.new(),
	}, { __index = Cutscene })

	return self
end

--[=[
	Starts the cutscene sequence.
	Handles looping and invokes the optional `onComplete` callback
	when the cutscene finishes.

	@param onComplete (() -> ())? -- Optional callback fired after cutscene ends
]=]
function Cutscene.Start(self: ICutscene, onComplete: () -> ()?): ()
	local loopCounter = 0

	self.maid:GiveTask(task.spawn(function()
		while not self.isComplete do
			for _, target in ipairs(self.targetCFrames) do
				if self.isComplete then
					return
				end

				local info = TweenInfo.new(self.duration, self.easingStyle, self.easingDirection)
				local tween = TweenService:Create(self.camera, info, { CFrame = target })
				table.insert(self.tweens, tween)

				self.camera.CameraType = Enum.CameraType.Scriptable
				tween:Play()
				tween.Completed:Wait()

				-- Force exact CFrame to prevent floating-point drift
				self.camera.CFrame = target
			end

			loopCounter += 1
			if not self.shouldLoop then
				break
			end
			if self.loopCount and loopCounter >= self.loopCount then
				break
			end
		end

		if onComplete then
			onComplete()
		end
	end))
end

--[=[
	Ends the cutscene immediately.
	Cancels all tweens, clears tasks, and resets camera.
]=]
function Cutscene.End(self: ICutscene): ()
	self.isComplete = true

	for _, tween in ipairs(self.tweens) do
		tween:Cancel()
	end
	table.clear(self.tweens)

	self.camera.CameraType = Enum.CameraType.Custom
end

--[=[
	Adds one or more new CFrames to the cutscene’s sequence.
    
	@param targets {CFrame} -- List of new CFrames to append
]=]
function Cutscene.Add(self: ICutscene, targets: { CFrame })
	if self.isComplete then
		return
	end
	for _, target in ipairs(targets) do
		table.insert(self.targetCFrames, target)
	end
end

--[=[
	Cleans up the cutscene completely.
	Ends the cutscene and clears all Maid connections.
]=]
function Cutscene:Destroy()
	self:End()
	self.maid:DoCleaning()
end

return Cutscene
--===--===--===--===--===--===--===--===--===--===--===--===--===--
