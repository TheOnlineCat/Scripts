-- Decompiler will be improved soon!
-- Decompiled with Konstant V2.1, a fast Luau decompiler made in Luau by plusgiant5 (https://discord.gg/wyButjTMhM)
-- Decompiled on 2025-02-11 09:55:56
-- Luau version 6, Types version 3
-- Time taken: 0.023194 seconds

-- KONSTANTWARNING: Variable analysis failed. Output will have some incorrect variable assignments
local Money_upvr_2 = require(game.ReplicatedStorage.Modules.Money)
local UI_upvr_2 = require(game.ReplicatedStorage.Modules.UI)
local Util_upvr = require(game.ReplicatedStorage.Modules.Util)
local Gamepad_upvr = require(game.ReplicatedStorage.Modules.Gamepad)
local Map_upvr_2 = require(game.ReplicatedStorage.Assets.Data.Map)
local Character_upvr_2 = game.Players.LocalPlayer.Character
local HumanoidRootPart_upvr_2 = Character_upvr_2:WaitForChild("HumanoidRootPart")
local HiddenNPCs_upvr_2 = game.ReplicatedStorage.HiddenNPCs
local CurrentCamera_upvr_2 = workspace.CurrentCamera
local Parent_upvr_2 = script.Parent
local Header_upvr_2 = Parent_upvr_2.Header
local List_upvr = Parent_upvr_2.List
local MapArrow_upvr_2 = Parent_upvr_2.MapArrow
local MapMarker_upvr = Parent_upvr_2.MapMarker
local BestQuest_upvr_2 = Header_upvr_2.BestQuest
local var191_upvw
local var192_upvw
local ActiveMapTracking_upvr = Parent_upvr_2.Parent.Parent.ActiveMapTracking
local _ = {"You're getting stronger!", "You made another step forward!", "You feel a little different..."}
local MapAttachment_upvr_2 = workspace.Terrain:FindFirstChild("MapAttachment")
if not MapAttachment_upvr_2 then
	MapAttachment_upvr_2 = Instance.new("Attachment", workspace.Terrain)
end
MapAttachment_upvr_2.Name = "MapAttachment"
MapMarker_upvr.Adornee = MapAttachment_upvr_2
MapArrow_upvr_2.Adornee = HumanoidRootPart_upvr_2
Gamepad_upvr:CreateGroup(Parent_upvr_2)
local function getClosestNPC_upvr(arg1) -- Line 44, Named "getClosestNPC"
	--[[ Upvalues[2]:
		[1]: CurrentCamera_upvr_2 (readonly)
		[2]: HiddenNPCs_upvr_2 (readonly)
	]]
	-- KONSTANTWARNING: Variable analysis failed. Output will have some incorrect variable assignments
	local var214
	for _, v in next, workspace.NPCs:GetChildren() do
		if v.PrimaryPart and v.Name == arg1 and (not var214 or (CurrentCamera_upvr_2.CFrame.Position - v.PrimaryPart.Position).Magnitude < math.huge) then
			var214 = v
			-- KONSTANTERROR: Expression was reused, decompilation is incorrect
		end
	end
	for _, v_2 in next, HiddenNPCs_upvr_2:GetChildren() do
		local function INLINED_2() -- Internal function, doesn't exist in bytecode
			-- KONSTANTERROR: Expression was reused, decompilation is incorrect
			return (CurrentCamera_upvr_2.CFrame.Position - v_2.PrimaryPart.Position).Magnitude < (CurrentCamera_upvr_2.CFrame.Position - v.PrimaryPart.Position).Magnitude
		end
		if v_2.PrimaryPart and v_2.Name == arg1 and (not var214 or INLINED_2()) then
			var214 = v_2
			-- KONSTANTERROR: Expression was reused, decompilation is incorrect
		end
	end
	return var214
end
local function getAvailableArea_upvr() -- Line 66, Named "getAvailableArea"
	--[[ Upvalues[2]:
		[1]: Util_upvr (readonly)
		[2]: Map_upvr_2 (readonly)
	]]
	local var221
	for _, v_3 in next, Map_upvr_2.Grinding.Locations do
		if v_3.Level <= Util_upvr:GetActiveBeybladeData().Level and (not var221 or var221.Level < v_3.Level) then
			var221 = v_3
		end
	end
	return var221
end
local function getLowestOrderCategory_upvr() -- Line 81, Named "getLowestOrderCategory"
	--[[ Upvalues[1]:
		[1]: List_upvr (readonly)
	]]
	local var228
	for _, v_4 in next, List_upvr:GetChildren() do
		if v_4:IsA("Frame") and (not var228 or v_4.LayoutOrder < var228.LayoutOrder) then
			var228 = v_4
		end
	end
	return var228
end
local function setActiveLocation_upvr(arg1) -- Line 93, Named "setActiveLocation"
	--[[ Upvalues[4]:
		[1]: var191_upvw (read and write)
		[2]: var192_upvw (read and write)
		[3]: getClosestNPC_upvr (readonly)
		[4]: Character_upvr_2 (readonly)
	]]
	var191_upvw = arg1
	if arg1.NPC then
		var192_upvw = getClosestNPC_upvr(arg1.NPC).PrimaryPart.Position
	end
	if arg1.Position then
		var192_upvw = arg1.Position
	end
	_G.DisplayText(`You are now tracking <{arg1.Name}>!`, 5)
	Character_upvr_2:SetAttribute("MapTracking", true)
end
local function removeActiveLocation_upvr() -- Line 109, Named "removeActiveLocation"
	--[[ Upvalues[2]:
		[1]: var191_upvw (read and write)
		[2]: Character_upvr_2 (readonly)
	]]
	var191_upvw = nil
	Character_upvr_2:SetAttribute("MapTracking", false)
end
local function _(arg1) -- Line 115, Named "getNumberOfAvailableLocations"
	--[[ Upvalues[1]:
		[1]: List_upvr (readonly)
	]]
	local var235
	for _, v_5 in next, List_upvr[arg1].Items:GetChildren() do
		if v_5:IsA("Frame") and not v_5.Unavailable.Visible then
			var235 += 1
		end
	end
	return var235
end
local function isLocationAllowed_upvr(arg1) -- Line 127, Named "isLocationAllowed"
	--[[ Upvalues[1]:
		[1]: HiddenNPCs_upvr_2 (readonly)
	]]
	if arg1.NPC and not workspace.NPCs:FindFirstChild(arg1.NPC) and not HiddenNPCs_upvr_2:FindFirstChild(arg1.NPC) then
		return false
	end
	if arg1.World and workspace:GetAttribute("World") ~= arg1.World then
		return false
	end
	return true
end
local Jump_upvr = Header_upvr_2.Jump
local function _() -- Line 234, Named "isNextBestQuestEnabled"
	--[[ Upvalues[3]:
		[1]: getAvailableArea_upvr (readonly)
		[2]: Header_upvr_2 (readonly)
		[3]: isLocationAllowed_upvr (readonly)
	]]
	local getAvailableArea_upvr_result1_3 = getAvailableArea_upvr()
	if not getAvailableArea_upvr_result1_3 or not getAvailableArea_upvr_result1_3.NextLevel then
		return false
	end
	if Header_upvr_2.Cancel.Visible then
		return false
	end
	if not isLocationAllowed_upvr(getAvailableArea_upvr_result1_3) then
		return false
	end
	return true
end
local function updateBestQuestStatus() -- Line 252
	--[[ Upvalues[3]:
		[1]: getAvailableArea_upvr (readonly)
		[2]: BestQuest_upvr_2 (readonly)
		[3]: Header_upvr_2 (readonly)
	]]
	local getAvailableArea_upvr_result1_2 = getAvailableArea_upvr()
	if getAvailableArea_upvr_result1_2 then
		getAvailableArea_upvr_result1_2 = not Header_upvr_2.Cancel.Visible
		if getAvailableArea_upvr_result1_2 then
			getAvailableArea_upvr_result1_2 = not workspace:GetAttribute("AutomaticGoals")
		end
	end
	BestQuest_upvr_2.Visible = getAvailableArea_upvr_result1_2
end
local function updateLockedStatus(arg1) -- Line 258
	--[[ Upvalues[6]:
		[1]: Util_upvr (readonly)
		[2]: List_upvr (readonly)
		[3]: HiddenNPCs_upvr_2 (readonly)
		[4]: getAvailableArea_upvr (readonly)
		[5]: BestQuest_upvr_2 (readonly)
		[6]: Header_upvr_2 (readonly)
	]]
	local children_3, NONE_5 = List_upvr:GetChildren()
	for i_7, v_7 in next, children_3, NONE_5 do
		if v_7:IsA("Frame") then
			for _, v_8 in next, v_7.Items:GetChildren() do
				if v_8:IsA("Frame") then
					local var261
					if v_8:GetAttribute("Level") then
						if Util_upvr:GetBeybladeLevel() >= v_8:GetAttribute("Level") then
							var261 = false
						else
							var261 = true
						end
						v_8.Locked.Visible = var261
						var261 = not v_8.Locked.Visible
						v_8.Title.Visible = var261
					end
					var261 = v_8.Locked
					if not var261.Visible and v_8:GetAttribute("NPC") then
						var261 = workspace
						if not var261.NPCs:FindFirstChild(v_8:GetAttribute("NPC")) and not HiddenNPCs_upvr_2:FindFirstChild(v_8:GetAttribute("NPC")) then
							var261 = true
							v_8.Unavailable.Visible = var261
							-- KONSTANTWARNING: GOTO [97] #68
						end
					end
					var261 = false
					v_8.Unavailable.Visible = var261
					if v_8:GetAttribute("World") then
						var261 = workspace:GetAttribute("World")
						if v_8:GetAttribute("World") ~= var261 then
							var261 = true
							v_8.Unavailable.Visible = var261
						end
					end
				end
			end
		end
	end
	NONE_5 = getAvailableArea_upvr()
	local var262 = NONE_5
	if var262 then
		v_7 = Header_upvr_2.Cancel
		i_7 = v_7.Visible
		var262 = not i_7
		if var262 then
			i_7 = workspace:GetAttribute("AutomaticGoals")
			var262 = not i_7
		end
	end
	BestQuest_upvr_2.Visible = var262
end
UI_upvr_2:Bind(ActiveMapTracking_upvr.Cancel)
UI_upvr_2:Bind(Header_upvr_2.Cancel.Button)
UI_upvr_2:Bind(BestQuest_upvr_2.Button)
UI_upvr_2:AddShadowOnHover(Header_upvr_2.Cancel)
UI_upvr_2:AddShadowOnHover(BestQuest_upvr_2)
ActiveMapTracking_upvr.Cancel.MouseButton1Click:Connect(function() -- Line 295
	--[[ Upvalues[1]:
		[1]: removeActiveLocation_upvr (readonly)
	]]
	return removeActiveLocation_upvr()
end)
BestQuest_upvr_2.Button.MouseButton1Click:Connect(function() -- Line 299
	--[[ Upvalues[4]:
		[1]: getAvailableArea_upvr (readonly)
		[2]: isLocationAllowed_upvr (readonly)
		[3]: setActiveLocation_upvr (readonly)
		[4]: Parent_upvr_2 (readonly)
	]]
	local getAvailableArea_result1 = getAvailableArea_upvr()
	if getAvailableArea_result1 then
		if not isLocationAllowed_upvr(getAvailableArea_result1) then
			return _G.DisplayError("The next best quest is not located in this world! Go to the next world.", 5)
		end
		setActiveLocation_upvr(getAvailableArea_result1)
		Parent_upvr_2.Visible = false
	end
end)
Header_upvr_2.Cancel.Button.MouseButton1Click:Connect(function() -- Line 313
	--[[ Upvalues[1]:
		[1]: removeActiveLocation_upvr (readonly)
	]]
	return removeActiveLocation_upvr()
end)
game:GetService("UserInputService").InputBegan:Connect(function(arg1, arg2) -- Line 317
	--[[ Upvalues[2]:
		[1]: var191_upvw (read and write)
		[2]: removeActiveLocation_upvr (readonly)
	]]
	if not arg2 and arg1.KeyCode == Enum.KeyCode.ButtonY and var191_upvw then
		return removeActiveLocation_upvr()
	end
end)
while not (not game:IsLoaded() or Util_upvr.Ready) do
	task.wait()
end
task.wait(3)
for i_9, v_9 in next, Map_upvr_2 do
	local buildCategory_result1_2 = (function(arg1, arg2) -- Line 139, Named "buildCategory"
		--[[ Upvalues[5]:
			[1]: isLocationAllowed_upvr (readonly)
			[2]: Jump_upvr (readonly)
			[3]: UI_upvr_2 (readonly)
			[4]: getLowestOrderCategory_upvr (readonly)
			[5]: List_upvr (readonly)
		]]
		local var241
		for _, v_6 in next, arg2.Locations do
			if isLocationAllowed_upvr(v_6) then
				var241 += 1
			end
		end
		local clone_2_upvr = script.Category:Clone()
		clone_2_upvr.Name = arg1
		clone_2_upvr.Title.Text = `{arg1} ({var241})`
		clone_2_upvr.LayoutOrder = arg2.Order
		if arg2.Type == "Square" then
			clone_2_upvr.Items.UIGridLayout.CellSize = UDim2.new(0, 97, 0, 97)
		end
		local clone_4 = script.JumpSlot:Clone()
		clone_4.Name = arg1
		clone_4.Button.Text = `{arg1}`
		clone_4.LayoutOrder = arg2.Order
		clone_4.Parent = Jump_upvr
		UI_upvr_2:AddShadowOnHover(clone_4)
		UI_upvr_2:Bind(clone_4.Button)
		clone_4.Button.MouseButton1Click:Connect(function() -- Line 171
			--[[ Upvalues[3]:
				[1]: getLowestOrderCategory_upvr (copied, readonly)
				[2]: List_upvr (copied, readonly)
				[3]: clone_2_upvr (readonly)
			]]
			List_upvr.CanvasPosition = Vector2.new(0, clone_2_upvr.AbsolutePosition.Y - getLowestOrderCategory_upvr().AbsolutePosition.Y)
		end)
		clone_2_upvr:SetAttribute("Type", arg2.Type)
		return clone_2_upvr
	end)(i_9, v_9)
	for i_10, v_10 in next, v_9.Locations do
		(function(arg1, arg2) -- Line 183, Named "buildLocationSlot"
			--[[ Upvalues[5]:
				[1]: Money_upvr_2 (readonly)
				[2]: HiddenNPCs_upvr_2 (readonly)
				[3]: setActiveLocation_upvr (readonly)
				[4]: Parent_upvr_2 (readonly)
				[5]: UI_upvr_2 (readonly)
			]]
			local clone_upvr = script.Slot:Clone()
			clone_upvr.Name = arg1
			clone_upvr.Title.Text = arg1
			if arg2.Icon then
				clone_upvr.Background.Image = `rbxassetid://{arg2.Icon}`
			end
			if arg2.Level then
				clone_upvr.Title.Text = `{arg1} (Lv. {Money_upvr_2(arg2.Level, true)}+)`
				clone_upvr.Locked.Label.Text = `(Level {Money_upvr_2(arg2.Level, true)}+)`
				clone_upvr.LayoutOrder = arg2.Level
				clone_upvr:SetAttribute("Level", arg2.Level)
			end
			if arg2.World then
				clone_upvr:SetAttribute("World", arg2.World)
			end
			if arg2.Universe then
				clone_upvr:SetAttribute("Universe", arg2.Universe)
			end
			clone_upvr.Button.MouseButton1Click:Connect(function() -- Line 208
				--[[ Upvalues[5]:
					[1]: clone_upvr (readonly)
					[2]: arg2 (readonly)
					[3]: HiddenNPCs_upvr_2 (copied, readonly)
					[4]: setActiveLocation_upvr (copied, readonly)
					[5]: Parent_upvr_2 (copied, readonly)
				]]
				if clone_upvr.Locked.Visible then
					return _G.DisplayError("You haven't unlocked this area yet!", 5)
				end
				if arg2.NPC and not workspace.NPCs:FindFirstChild(arg2.NPC) and not HiddenNPCs_upvr_2:FindFirstChild(arg2.NPC) then
					return _G.DisplayError("Failed to find location in world!", 5)
				end
				if arg2.Universe and arg2.Universe ~= workspace:GetAttribute("World") then
					return _G.DisplayError("Failed to find location in world!", 5)
				end
				setActiveLocation_upvr(arg2)
				Parent_upvr_2.Visible = false
			end)
			clone_upvr:SetAttribute("NPC", arg2.NPC)
			clone_upvr:SetAttribute("LayoutOrder", clone_upvr.LayoutOrder)
			UI_upvr_2:Bind(clone_upvr.Button)
			UI_upvr_2:AddShadowOnHover(clone_upvr)
			return clone_upvr
		end)(i_10, v_10).Parent = buildCategory_result1_2.Items
		local _
	end
	buildCategory_result1_2.Parent = List_upvr
end
Util_upvr.ActiveBeybladeLevelChanged:Connect(updateLockedStatus)
Util_upvr.ActiveBeybladeChanged:Connect(updateLockedStatus)
Character_upvr_2:GetAttributeChangedSignal("MapTracking"):Connect(updateBestQuestStatus)
Header_upvr_2.Cancel:GetPropertyChangedSignal("Visible"):Connect(updateBestQuestStatus)
workspace:GetAttributeChangedSignal("AutomaticGoals"):Connect(updateBestQuestStatus)
updateLockedStatus()
local getAvailableArea_upvr_result1 = getAvailableArea_upvr()
if getAvailableArea_upvr_result1 then
	i_9 = Header_upvr_2.Cancel
	getAvailableArea_upvr_result1 = not i_9.Visible
	if getAvailableArea_upvr_result1 then
		v_9 = "AutomaticGoals"
		getAvailableArea_upvr_result1 = not workspace:GetAttribute(v_9)
	end
end
BestQuest_upvr_2.Visible = getAvailableArea_upvr_result1
Gamepad_upvr:EnabledCallback(Parent_upvr_2, function() -- Line 351
	--[[ Upvalues[2]:
		[1]: Gamepad_upvr (readonly)
		[2]: List_upvr (readonly)
	]]
	Gamepad_upvr:Select(List_upvr)
end)
game:GetService("RunService").RenderStepped:Connect(function(arg1) -- Line 355
	--[[ Upvalues[11]:
		[1]: var191_upvw (read and write)
		[2]: var192_upvw (read and write)
		[3]: Character_upvr_2 (readonly)
		[4]: HumanoidRootPart_upvr_2 (readonly)
		[5]: CurrentCamera_upvr_2 (readonly)
		[6]: MapArrow_upvr_2 (readonly)
		[7]: Money_upvr_2 (readonly)
		[8]: MapMarker_upvr (readonly)
		[9]: MapAttachment_upvr_2 (readonly)
		[10]: ActiveMapTracking_upvr (readonly)
		[11]: Header_upvr_2 (readonly)
	]]
	-- KONSTANTWARNING: Variable analysis failed. Output will have some incorrect variable assignments
	if var191_upvw and var192_upvw then
		local var282
		if not Character_upvr_2:GetAttribute("InBattle") then
			if 4000 < (var192_upvw - HumanoidRootPart_upvr_2.Position).Magnitude then
				for _, _ in next, workspace.Map.PortalNPCs:GetChildren() do
					local SOME = workspace.Map.PortalNPCs:FindFirstChild(workspace:GetAttribute("World").."PortalNPC"..1)
					if SOME and (SOME.PrimaryPart.Position - HumanoidRootPart_upvr_2.Position).Magnitude < math.huge then
						local var286 = SOME
					end
				end
				if var286 then
					var282 = var286.PrimaryPart.Position
				end
			end
			if not var282 then
				local var287 = var192_upvw
			end
			local Unit_2 = (var287 - HumanoidRootPart_upvr_2.Position).Unit
			local LookVector_2 = CurrentCamera_upvr_2.CFrame.LookVector
			local var290 = math.atan2(Unit_2.Z, Unit_2.X) - math.atan2(LookVector_2.Z, LookVector_2.X)
			MapArrow_upvr_2.Enabled = true
			MapArrow_upvr_2.Icon.Rotation = math.deg(var290)
			MapArrow_upvr_2.StudsOffset = Vector3.new(math.cos(var290 - (math.pi/2)), 0, math.sin(var290 - (math.pi/2))) * 5
			MapArrow_upvr_2.Distance.Text = Money_upvr_2(math.round((var287 - HumanoidRootPart_upvr_2.Position).Magnitude / 3), true)
			MapMarker_upvr.Label.Text = var191_upvw.Name
			MapMarker_upvr.Enabled = true
			MapAttachment_upvr_2.WorldPosition = var287 + Vector3.new(0, 20, 0)
			ActiveMapTracking_upvr.Top.Title.Text = `{var191_upvw.Name} ({MapArrow_upvr_2.Distance.Text})`
			ActiveMapTracking_upvr.Visible = true
			if (var287 - HumanoidRootPart_upvr_2.Position).Magnitude < 30 and var282 ~= var287 then
				var191_upvw = nil
				Character_upvr_2:SetAttribute("MapTracking", false)
				_G.DisplayText("You've arrived to your destination!", 5)
			end
			Header_upvr_2.Cancel.Visible = true
			return
		end
	end
	MapArrow_upvr_2.Enabled = false
	MapMarker_upvr.Enabled = false
	ActiveMapTracking_upvr.Visible = false
	Header_upvr_2.Cancel.Visible = false
end)
