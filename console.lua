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
connection = game:GetService("ReplicatedStorage").Events.BattleTransition.OnClientEvent:Connect(function(...)
    local args = {...} -- Capture all parameters
    warn("BattleTransition event fired with parameters:")

    for i, v in ipairs(args) do
        warn(("\nArgument %d:"):format(i))
        warnTable(v, 4) -- warn recursively
    end
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
