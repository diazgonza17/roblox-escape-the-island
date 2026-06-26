local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local padVisualEvent = ReplicatedStorage:WaitForChild("PadVisualEvent")
local getPadInitialText = ReplicatedStorage:WaitForChild("GetPadInitialTextFunction")

local upgradesFolder = Workspace:WaitForChild("World"):WaitForChild("Upgrades")

local padStateByPad = {}

local HOLD_FILL_COLOR = Color3.fromRGB(144, 238, 144)
local SUCCESS_COLOR = Color3.fromRGB(50, 255, 50)
local FAIL_COLOR = Color3.fromRGB(255, 50, 50)

local FLASH_DURATION = 0.5
local HOLD_DURATION = 1

local activeTweenByPad = {}

local function getOrCreatePadState(pad)
	if not padStateByPad[pad] then
		local fill = pad:FindFirstChild("Fill")
		
		padStateByPad[pad] = {
			originalPadColor = pad.Color,
			fill = fill,
			originalFillSize = fill and fill.Size or nil,
			originalFillCFrame = fill and fill.CFrame or nil,
			originalFillTransparency = fill and fill.Transparency or 1
		}
	end
	
	return padStateByPad[pad]
end


local function cancelActiveTween(pad)
	local activeTween = activeTweenByPad[pad]
	if activeTween then
		activeTween:Cancel()
		activeTweenByPad[pad] = nil
	end
end

local function resetFillToIdle(pad)
	local state = getOrCreatePadState(pad)
	local fill = state.fill
	
	if not fill or not state.originalFillSize or not state.originalFillCFrame then
		return
	end
	
	fill.Size = state.originalFillSize
	fill.CFrame = state.originalFillCFrame
	fill.Transparency = state.originalFillTransparency
end

local function resetPadVisuals(pad)
	cancelActiveTween(pad)
	
	local state = getOrCreatePadState(pad)
	pad.Color = state.originalPadColor
	
	resetFillToIdle(pad)
end

local function animateFillHold(pad)
	local state = getOrCreatePadState(pad)
	local fill = state.fill
	
	if not fill or not state.originalFillSize or not state.originalFillCFrame then
		return
	end
	
	cancelActiveTween(pad)
	resetFillToIdle(pad)
	fill.Color = HOLD_FILL_COLOR
	fill.Transparency = 0.5
	
	local originalSize = state.originalFillSize
	local originalCFrame = state.originalFillCFrame
	
	local fullWidth = pad.Size.Z
	local idleWidth = originalSize.Z
	local widthDifference = fullWidth - idleWidth
	
	local centerShift = widthDifference / 2
	local goalSize = Vector3.new(originalSize.X, originalSize.Y, fullWidth)
	local goalCFrame = originalCFrame * CFrame.new(0,0,centerShift)
	
	local tweenInfo = TweenInfo.new(HOLD_DURATION, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	local tween = TweenService:Create(fill, tweenInfo, { Size = goalSize, CFrame = goalCFrame })
	
	activeTweenByPad[pad] = tween
	tween:Play()
	
	tween.Completed:Connect(function()
		if activeTweenByPad[pad] == tween then
			activeTweenByPad[pad] = nil
		end
	end)
end

local function flashPadColor(pad, color)
	cancelActiveTween(pad)
	
	local state = getOrCreatePadState(pad)
	pad.Color = color
	
	task.delay(FLASH_DURATION, function()
		pad.Color = state.originalPadColor
		resetFillToIdle(pad)
	end)
end

local function updateText(pad, extraData)
	local billboard = pad:FindFirstChildOfClass("BillboardGui")
	if billboard then 
		local textLabel = billboard:FindFirstChildOfClass("TextLabel")
		if textLabel and type(extraData) == "string" then
			textLabel.Text = extraData
		end
	end
end 

padVisualEvent.OnClientEvent:Connect(function(pad, action, extraData)
	if not pad or not pad:IsA("BasePart") then
		return
	end
	
	if action == "UpdateText" then
		updateText(pad, extraData)
	elseif action == "NotEnoughMoney" then
		flashPadColor(pad, FAIL_COLOR)
	elseif action == "HoldStart" then 
		animateFillHold(pad)
	elseif action == "HoldCancel" then
		resetPadVisuals(pad)
	elseif action == "PurchaseSuccess" then
		flashPadColor(pad, SUCCESS_COLOR)
	elseif action == "Revert" then
		resetPadVisuals(pad)
	end
end)

local function requestInitialText(pad)
	task.spawn(function()
		local initialText = getPadInitialText:InvokeServer(pad)
		
		if initialText and initialText ~= "Error" then
			updateText(pad, initialText)
		end
	end)
end

for _, pad in upgradesFolder:GetChildren() do
	requestInitialText(pad)
end
upgradesFolder.ChildAdded:Connect(function(pad)
	requestInitialText(pad)
end)