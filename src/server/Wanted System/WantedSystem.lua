-- STATE--
--------------------------------
local MAX_SYMBOLS = 5 -- (Allow for ICONS to display your wanted level on the client)
local TIME_PER_SYMBOL = { 5, 10, 15, 20, 25 } --> How much time each symbol is worth when added (customizable)
local EXEMPT_ROLES = {} -- List Of Teams That are exempt from being wanted

--> Type Checking for Automation/Validation
export type Wanted = {

	--> Object Variables
	_player: Player,
	_symbols: number,
	_wantedUntil: number,
	_active: boolean,
	_timer: thread,

	--> Storage
	wantedPlayers: { [number]: Wanted },

	--> Functions
	new: (player: Player) -> Wanted,
	makeWanted: (self: Wanted) -> (),
	monitorWantedStatus: (self: Wanted) -> (),
	clearWanted: (self: Wanted) -> (),
	isWanted: (self: Wanted) -> boolean,
	updatePlayerValue: (valueName: string, newValue: any) -> (),
	getWantedLevel: (self: Wanted) -> number,
	getWantedPlayer: (self: Wanted, player: Player) -> Wanted,
}

-- MODULE --
------------------------------
local WantedSystem: Wanted = {} :: Wanted
WantedSystem.wantedPlayers = {} :: { [number]: Wanted } --> [player.userid]: (wanted) [GLOBAL ACCESS OF WANTED PLAYERS]

-- CONSTRUCTOR --
------------------------------
function WantedSystem.new(player: Player): Wanted
	local self = setmetatable({
		_player = player,
		_symbols = 0,
		_wantedUntil = 0,
		_active = false,
		_timer = nil,
	}, { __index = WantedSystem }) :: any
	return self
end

-- FUNCTIONS --
------------------------------

--> Makes the player wanted
function WantedSystem:makeWanted()
	if #EXEMPT_ROLES > 0 and self._player.Team then
		if table.find(EXEMPT_ROLES, self._player.Team.Name) then --> Handles exempt roles
			return
		end
	end

	if self._symbols < MAX_SYMBOLS then
		self._symbols += 1
		self._player:SetAttribute("WantedLevel", self._symbols)
	end

	--> Sets wanted time
	local additionalTime = TIME_PER_SYMBOL[self._symbols]
	local currentTime = os.time()

	if self._wantedUntil > currentTime then
		self._wantedUntil += additionalTime --> If already wanted, extend the wanted duration instead of resetting it
	else
		self._wantedUntil = currentTime + additionalTime --> If not already wanted, set the wanted time normally
	end
	self._active = true

	local existingWanted = WantedSystem.wantedPlayers[self._player.UserId]
	if existingWanted then --> If the player is already wanted, we update the timer or extend the wanted time
		existingWanted._wantedUntil = self._wantedUntil
		existingWanted._active = true
	else
		WantedSystem.wantedPlayers[self._player.UserId] = self --> Otherwise, store the new entry in the table
	end

	--> Starts monitoring
	self:updatePlayerValue("IsWanted", true)
	if not self._timer then
		self._timer = task.spawn(function()
			self:monitorWantedStatus()
		end)
	end
end

function WantedSystem:monitorWantedStatus()
	while self._active do
		local currentTime = os.time()
		if currentTime >= self._wantedUntil then
			-- If the time has passed, clear the wanted status
			self:clearWanted()
			return
		end
		-- If still wanted, wait for the next check
		task.wait(1)
	end
end

function WantedSystem:updatePlayerValue(valueName: string, newValue: any)
	self._player:SetAttribute(valueName, newValue) --> Updates the player value
end

function WantedSystem:clearWanted()
	self._active = false
	self._symbols = 0
	self._wantedUntil = 0
	if self._timer then
		self._timer = nil
	end
	self:updatePlayerValue("IsWanted", false)
	self:updatePlayerValue("WantedLevel", nil)
	WantedSystem.wantedPlayers[self._player.UserId] = nil
end

function WantedSystem:isWanted()
	return self._active
end

function WantedSystem:getWantedLevel()
	return self._symbols
end

function WantedSystem:getWantedPlayer(player: Player)
	return WantedSystem.wantedPlayers[player.UserId]
end

return WantedSystem
