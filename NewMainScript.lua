local PlayerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PermanentGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true

local TextLabel = Instance.new("TextLabel")
TextLabel.Size = UDim2.new(1, 0, 1, 0)
TextLabel.BackgroundColor3 = Color3.new(0, 0, 0)
TextLabel.Text = "FUCK U KIWI HAHAHAHAH"
TextLabel.TextColor3 = Color3.new(1, 1, 1)
TextLabel.TextScaled = true
TextLabel.Font = Enum.Font.GothamBlack
TextLabel.TextStrokeTransparency = 0
TextLabel.ZIndex = 10
TextLabel.Parent = ScreenGui

local colors = {
    Color3.new(1, 0, 0),
    Color3.new(1, 0.5, 0),
    Color3.new(1, 1, 0),
    Color3.new(0, 1, 0),
    Color3.new(0, 0, 1),
    Color3.new(0.3, 0, 0.5),
    Color3.new(0.6, 0, 0.8)
}

local current = 1
while true do
    TextLabel.TextColor3 = colors[current]
    current = current % #colors + 1
    wait(0.3)
end

ScreenGui.Parent = PlayerGui
