local Player = game.Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FuckYouKiwi"
ScreenGui.IgnoreGuiInset = true
ScreenGui.ResetOnSpawn = false

local TextLabel = Instance.new("TextLabel")
TextLabel.Size = UDim2.new(1, 0, 1, 0)
TextLabel.BackgroundColor3 = Color3.new(0, 0, 0)
TextLabel.Text = "fuck u kiwi hahahahah"
TextLabel.TextColor3 = Color3.new(1, 1, 1)
TextLabel.TextScaled = true
TextLabel.Font = Enum.Font.SourceSansBold
TextLabel.Parent = ScreenGui

ScreenGui.Parent = PlayerGui
