local function warnTable(tbl, indent)
    indent = indent or 0
    if type(tbl) ~= "table" then
        warn(("[INDENT] %s%s"):format((" "):rep(indent), tostring(tbl)))
        return
    end

    for k, v in pairs(tbl) do
        if type(v) == "table" then
            warn(("%s[%s] = {"):format((" "):rep(indent), tostring(k)))
            warnTable(v, indent + 4)
            warn(("%s}"):format((" "):rep(indent)))
        else
            warn(("%s[%s] = %s"):format((" "):rep(indent), tostring(k), tostring(v)))
        end
    end
end
local connection
connection = game:GetService("ReplicatedStorage").Events.ShowBossInfo.OnClientEvent:Connect(function(...)
    local args = {...} -- Capture all parameters
    warn("ShowBossInfo event fired with parameters:")

    for i, v in ipairs(args) do
        warn(("\nArgument %d:"):format(i))
        warnTable(v, 4) -- warn recursively
    end

    -- Disconnect after first execution
    if connection then
        connection:Disconnect()
    end
end)

local connection
connection = game:GetService("ReplicatedStorage").Events.ShowBossInfo.OnClientEvent:Connect(function(test)
    if test["Badge"] then
        warn("this is a quest Boss")
    else
        warn("this is a WB")
    end
    -- Disconnect after first execution
    if connection then
        connection:Disconnect()
    end
end)

local connection
connection = game:GetService("ReplicatedStorage").Events.TakeBack.OnClientEvent:Connect(function(...)
    local args = {...} -- Capture all parameters
    warn("TakeBack event fired with parameters:")

    for i, v in ipairs(args) do
        warn(("\nArgument %d:"):format(i))
        warnTable(v, 4) -- warn recursively
    end

    -- Disconnect after first execution
    if connection then
        connection:Disconnect()
    end
end)

for _, conn in pairs(getconnections(game:GetService("ReplicatedStorage").Events.UpdateBlackmarket.OnClientEvent)) do
    conn.Function({}) -- Simulate event trigger with empty data
end
local mt = getrawmetatable(game)
setreadonly(mt, false)

local oldIndex = mt.__index
mt.__index = newcclosure(function(self, key)
    if self == EventsFolder.RunCaseAnimation and key == "FireClient" then
        return nil -- Prevent it from running
    end
    return oldIndex(self, key)
end)

-- local connection2
-- connection2 = game:GetService("ReplicatedStorage").Events.Teleport.OnClientEvent:Connect(function(...)
--     local args = {...} -- Capture all parameters
--     warn("Teleport event fired with parameters:")

--     for i, v in ipairs(args) do
--         warn(("\nArgument %d:"):format(i))
--         warnTable(v, 4) -- warn recursively
--     end

--     -- Disconnect after first execution
--     if connection2 then
--         connection2:Disconnect()
--     end
-- end)

local connection3
connection3 = game:GetService("ReplicatedStorage").Events.UpdateAllQuests.OnClientEvent:Connect(function(...)
    local args = {...} -- Capture all parameters
    warn("UpdateAllQuests event fired with parameters:")

    for i, v in ipairs(args) do
        warn(("\nArgument %d:"):format(i))
        warnTable(v, 4) -- warn recursively
    end

    -- Disconnect after first execution
    if connection3 then
        connection3:Disconnect()
    end
end)

local model = Instance.new("Model")
model.Name = "zCRYMSTA"


local root = Instance.new("Part")
root.Name = "Root"
root.Parent = model

local proximityPrompt = Instance.new("ProximityPrompt")
proximityPrompt.Name = "Crystal"
proximityPrompt.Parent = root

root.CFrame = CFrame.new(-16422.5078125, 6.468752861022949, -882.2816772460938)

model.Parent = workspace