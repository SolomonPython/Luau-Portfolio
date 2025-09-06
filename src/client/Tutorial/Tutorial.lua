--===--===--===--===--===--===--===--===--===--===--===--===--===--

--> Servicess
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

--> Dependencies
local Types = require(StarterPlayer.StarterPlayerScripts.Tutorial.Dependencies.Types)
local Maid = require(ReplicatedStorage.Packages.maid)

--> Settings
local TWEEN_SETTINGS = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local FRAME_SIZE = UDim2.fromScale(0.4, 0.5)
local TIME_BETWEEN_SOUND = 0.05

local Tutorial = { ActiveTutorial = nil :: Types.ITutorial? }

--> Types
export type Tutorial = typeof(setmetatable({} :: Types.ITutorial, Tutorial))

--> Utility Functions
local function UpdateCurrentPage(self)
	if self.pageLabel and self.currentPage and self.pages then
		self.pageLabel.Text = `{self.currentPage}/{#self.pages}`
	end
end

--> Public Functions
function Tutorial.new(title: string, pages: {})
	if not title or not pages then
		return nil
	end

	local function CreateSelf()
		local self = setmetatable({
			title = title,
			pages = pages,
			currentPage = 1,
			_animating = false,
			maid = Maid.new(),
		}, { __index = Tutorial })

		self:open()
		Tutorial.ActiveTutorial = self
		return self
	end

	if Tutorial.ActiveTutorial then
		local old = Tutorial.ActiveTutorial
		Tutorial.ActiveTutorial = nil
		old:close(function()
			CreateSelf()
		end)
		return
	end

	return CreateSelf()
end

function Tutorial.next(self)
	if not self.pages or self._animating then
		return
	end
	if self.currentPage + 1 > #self.pages then
		self:animate(self.pages[self.currentPage])
		return
	end
	self.currentPage += 1
	UpdateCurrentPage(self)
	self:animate(self.pages[self.currentPage])
end

function Tutorial.prev(self)
	if not self.pages or self._animating then
		return
	end

	if self.currentPage - 1 < 1 then
		self:animate(self.pages[self.currentPage])
		return
	end

	self.currentPage -= 1

	UpdateCurrentPage(self)
	self:animate(self.pages[self.currentPage])
end

function Tutorial.animate(self, text: string)
	if self._animating then
		return
	end
	self._animating = true

	self.bodyLabel = "path.to.label"
	if not self.bodyLabel then
		self._animating = false
		return
	end

	self.bodyLabel.Text = ""
	local lastPlayTime = 0

	for i = 1, #text do
		if not self._animating then
			break
		end

		self.bodyLabel.Text = string.sub(text, 1, i)

		local now = tick()
		if now - lastPlayTime >= TIME_BETWEEN_SOUND then
			if self.sound then
				self.sound:Destroy()
			end

			--> External audio module

			--[[
			self.sound = PlaySound(SoundSchema.SFX.Text, nil, {
				Volume = 0.25,
				Loop = false,
				PlayOnRemove = true,
			})
			self.sound:Destroy()
            ]]

			lastPlayTime = now
		end
		task.wait(TIME_BETWEEN_SOUND)
	end

	self._animating = false
end

function Tutorial.open(self)
	if not self.pages or not self.tutorialContainer then
		return
	end
	self.bodyLabel.Text = ""
	self.tutorialContainer.Visible = true

	local tween = TweenService:Create(self.tutorialContainer, TWEEN_SETTINGS, {
		Size = FRAME_SIZE,
	})
	tween:Play()

	self.maid:GiveTask(tween.Completed:Connect(function()
		self:animate(self.pages[self.currentPage])
	end))
end

function Tutorial.close(self, onComplete: () -> ()?)
	if not self.tutorialContainer then
		return
	end

	if self.sound then
		self.sound:Destroy()
		self.sound = nil
	end
	self._animating = false

	local tween = TweenService:Create(self.tutorialContainer, TWEEN_SETTINGS, {
		Size = UDim2.fromScale(0, 0),
	})
	tween:Play()

	self.maid:GiveTask(tween.Completed:Connect(function()
		self.tutorialContainer.Visible = false
		if onComplete then
			task.spawn(onComplete)
		end
		self:destroy()
	end))
end

function Tutorial.destroy(self)
	self._animating = false
	if self.sound then
		self.sound:Destroy()
		self.sound = nil
	end
	self.maid:DoCleaning()
	if self == Tutorial.ActiveTutorial then
		Tutorial.ActiveTutorial = nil
	end
end

return Tutorial

--===--===--===--===--===--===--===--===--===--===--===--===--===--
