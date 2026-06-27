local ReplicatedStorage = game:GetService("ReplicatedStorage")

local padVisualEvent = Instance.new("RemoteEvent")
padVisualEvent.Name = "PadVisualEvent"
padVisualEvent.Parent = ReplicatedStorage

local getPadInitialText = Instance.new("RemoteFunction")
getPadInitialText.Name = "GetPadInitialTextFunction"
getPadInitialText.Parent = ReplicatedStorage