local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local hazards = Workspace.World.Hazards:GetChildren()

local function onHazardTouched(otherPart)
	local character = otherPart.Parent
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		local humanoid = character:FindFirstChildWhichIsA("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end
end

for _, hazard in hazards do 
	hazard.Touched:Connect(onHazardTouched)
end