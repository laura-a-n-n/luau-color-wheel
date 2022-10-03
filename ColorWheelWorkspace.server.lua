local CoreColorModule = require(script:WaitForChild('CoreColorModule'))

local event = script.RemoteEvent
local debounce = {}
local cooldown = script.Cooldown.Value

game.Players.PlayerAdded:Connect(function(player : Player)
	debounce[player.Name] = 0
end)
game.Players.PlayerRemoving:Connect(function(player : Player)
	debounce[player.Name] = nil
end)

event.OnServerEvent:Connect(function(player : Player,
	adornee : ObjectValue,
	property : StringValue,
	value : BrickColor | Color3)

	if not adornee then return end
	if typeof(value) ~= 'Color3'
		or (os.clock() - debounce[player.Name] < cooldown) then
		-- player is probably exploiting.
		player:Kick()
	end
	CoreColorModule:AssignColor(adornee, property, value)
end)