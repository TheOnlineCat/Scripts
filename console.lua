local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui"):SetCore("DevConsoleVisible", true)

local function toggleDevConsole(input, gameProcessed)
    if gameProcessed then return end -- Ignore inputs processed by the game

    if input.KeyCode == Enum.KeyCode.Semicolon then
        StarterGui:SetCore("DevConsoleVisible", true)
    end
end

UserInputService.InputBegan:Connect(toggleDevConsole)
