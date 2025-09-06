# FEATURES

- Player can be marked as "Wanted" with escalating levels.
- Time-based mechanic that extends "Wanted" status.
- Exempt roles can avoid being marked as "Wanted".
- Monitors the "Wanted" status until expiration.
- Handles multiple players being "Wanted" simultaneously.
- Automatically clears "Wanted" status after time expires.
- Provides functions for checking and managing "Wanted" status.
- Works seamlessly with player attributes to reflect status visually.

# USAGE

1. Place the module script inside `ServerScriptService` or wherever it's appropriate in your project.
2. Make sure to set up the appropriate roles for exemption (e.g., `"Emperor"`) in the `EXEMPT_ROLES` table.

3. In a Script, you can initialize and use the `WantedSystem` like this:

```lua
local WantedSystem = require(path.to.WantedModule)

-- Create a new 'Wanted' instance for a player
local player = game.Players.LocalPlayer -- or any player object
local wantedInstance = WantedSystem.new(player)

-- Mark the player as 'Wanted' and start monitoring
wantedInstance:makeWanted()

-- You can check if a player is 'Wanted' at any time
if wantedInstance:isWanted() then
    print(player.Name .. " is wanted!")
end

-- You can also get the wanted level of a player
print(player.Name .. "'s wanted level: " .. wantedInstance:getWantedLevel())

-- Clear the 'Wanted' status when needed
wantedInstance:clearWanted()
