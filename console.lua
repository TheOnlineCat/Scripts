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
connection = game:GetService("ReplicatedStorage").Events.DialogueEnded.OnClientEvent:Connect(function(...)
    local args = {...} -- Capture all parameters
    warn("DialogueEnded event fired with parameters:")

    for i, v in ipairs(args) do
        warn(("\nArgument %d:"):format(i))
        warnTable(v, 4) -- warn recursively
    end

    -- Disconnect after first execution
    if connection then
        connection:Disconnect()
    end
end)
