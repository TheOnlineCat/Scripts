--[[
loadstring(game:HttpGet("https://raw.githubusercontent.com/TheOnlineCat/Scripts/refs/heads/main/B%20Rebirth.lua"))()
--]]

if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")

-- Packages
local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua"))()
local Maid = loadstring(game:HttpGet("https://raw.githubusercontent.com/Quenty/NevermoreEngine/refs/heads/main/src/maid/src/Shared/Maid.lua"))()
local Signal = loadstring(game:HttpGet("https://raw.githubusercontent.com/Sleitnick/RbxUtil/refs/heads/main/modules/signal/init.luau"))()

-- Constants
local GENERAL_POLL_DELAY = 0.1

-- Controllers
local AutofarmController = {}
local MiscController = {}
local UIController = {}

-- Classes
local BaseFarmStrategy = {}
local RockFarmStrategy = {}

local BaseNPCBattleStrategy = {}
local QuestFarmStrategy = {}
local BossFarmStrategy = {}

-- Variables
local Client = Players.LocalPlayer

local EventsFolder = ReplicatedStorage.Events
local BeybladesFolder = workspace.Beyblades
local TrainingFolder = workspace.Training
local NPCsFolder = workspace.NPCs
local HiddenNPCsFolder = ReplicatedStorage.HiddenNPCs
local RemotesFolder = ReplicatedStorage.Events
local Stats = require(ReplicatedStorage.Modules.Stats)

local RNG = Random.new()

-- Class Definitions
do
    BaseFarmStrategy.__index = BaseFarmStrategy

    function BaseFarmStrategy.new()
        local self = setmetatable({}, BaseFarmStrategy)
        self._LastAttack = 0
        self._Maid = Maid.new()
        return self
    end

    function BaseFarmStrategy:Start()
        -- Override in child classes
    end

    function BaseFarmStrategy:Update()
        -- Override in child classes
    end

    function BaseFarmStrategy:Destroy()
        self._Maid:DoCleaning()
        self._Maid = nil
    end
end

do
    setmetatable(RockFarmStrategy, BaseFarmStrategy)
    RockFarmStrategy.__index = RockFarmStrategy
    
    function RockFarmStrategy.new()
        local self = setmetatable(BaseFarmStrategy.new(), RockFarmStrategy)
        self._CurrentTarget = nil

        self._Maid:GiveTask(function()
            self._CurrentTarget = nil
            AutofarmController:UnlaunchBeyblade() 
        end)
        
        return self
    end
    
    function RockFarmStrategy:ScanForTarget()
        local TargetRockName: string = UIController:GetSelectedRockName()
        for _, Rock: Model in TrainingFolder:GetChildren() do
            if Rock.PrimaryPart and Rock.PrimaryPart.Position.Y > 1000 then continue end
            if Rock.Name ~= TargetRockName then continue end
            if Rock:GetAttribute("Health") <= 0 then continue end
            self._CurrentTarget = Rock
            break
        end
    end
    
    function RockFarmStrategy:Update()
        local ClientBeyblade: Model = AutofarmController:GetClientBeyblade()
        if not ClientBeyblade or not self._CurrentTarget then return end
        
        -- Attack logic
        if os.clock() - self._LastAttack >= GENERAL_POLL_DELAY then
            self._LastAttack = os.clock()
            AutofarmController:Attack(self._CurrentTarget)
            AutofarmController:FireSkills(self._CurrentTarget)
        end
        
        -- Teleport logic
        ClientBeyblade.HumanoidRootPart.CFrame = self._CurrentTarget.PrimaryPart.CFrame * CFrame.new(0, 1, 0)
    end
    
    function RockFarmStrategy:Start()
        -- Initial Beyblade launch
        AutofarmController:LaunchBeyblade()

        -- Initial scan for valid target
        self:ScanForTarget()

        -- Handle beyblade tracking
        self._Maid:GiveTask(BeybladesFolder.ChildRemoved:Connect(function(Beyblade: Model)
            if Beyblade.Name == Client.Name then
                task.wait(self.GENERAL_POLL_DELAY)
                AutofarmController:LaunchBeyblade()
            end
        end))

        -- Handle rock tracking
        self._Maid:GiveTask(TrainingFolder.ChildAdded:Connect(function(Rock: Model)
            task.wait()
            local TargetRockName = UIController:GetSelectedRockName()
            if Rock.Name ~= TargetRockName then return end
            
            if Rock.PrimaryPart and Rock.PrimaryPart.Position.Y < 1000 then
                if not self._CurrentTarget then
                    self._CurrentTarget = Rock
                end
            end
        end))
        
        self._Maid:GiveTask(TrainingFolder.ChildRemoved:Connect(function(Rock: Model)
            if Rock == self._CurrentTarget then
                self._CurrentTarget = nil
                self:ScanForTarget()
            end
        end))

        self._Maid:GiveTask(UIController.OnRockTargetTypeChanged:Connect(function()
            -- Scan for a new target after changing the type of rock we want to target
            self:ScanForTarget()
        end))
    end
end

do
    setmetatable(BaseNPCBattleStrategy, BaseFarmStrategy)
    BaseNPCBattleStrategy.__index = BaseNPCBattleStrategy

    type DialogueChoice = {
        Id: number,
        Text: string,
        Type: string?,
    }    

    function BaseNPCBattleStrategy.new()
        local self = setmetatable(BaseFarmStrategy.new(), BaseNPCBattleStrategy)
        self._CurrentNPC = nil
        self._NPCBeyblade = nil

        self._Maid:GiveTask(function()
            self._CurrentNPC = nil
            self._NPCBeyblade = nil
        end)

        return self
    end

    function BaseNPCBattleStrategy:HandleDialogue(Responses: { DialogueChoice }, NPC: Model)
        if not Responses or not NPC then return end

        local FirstResponseId, FirstReplyId
        
        for _, Choice in ipairs(Responses) do
            if Choice.Type == "Response" and not FirstResponseId then 
                FirstResponseId = Choice.Id
            elseif Choice.Type == "Reply" and not FirstReplyId then
                FirstReplyId = Choice.Id
            end
        end
        
        local DelayTime = FirstReplyId and 2 or 0.5
        local ChoiceId = FirstReplyId or FirstResponseId
        
        task.wait(DelayTime)
        AutofarmController:FireServer("DialogueChoice", ChoiceId)
    end

    function BaseNPCBattleStrategy:Update()
        local ClientBeyblade: Model = AutofarmController:GetClientBeyblade()
        
        if not ClientBeyblade or not self._NPCBeyblade then return end
        
        -- Attack logic
        if os.clock() - self._LastAttack >= GENERAL_POLL_DELAY then
            self._LastAttack = os.clock()
            AutofarmController:Attack(self._NPCBeyblade)
            AutofarmController:FireSkills(self._NPCBeyblade)
        end

        -- Teleport logic
        ClientBeyblade.HumanoidRootPart.CFrame = self._NPCBeyblade.HumanoidRootPart.CFrame * CFrame.new(0, 1, 0)
    end

    function BaseNPCBattleStrategy:Start()
        self._Maid:GiveTask(task.spawn(function()
            while true do
                task.wait(1)
                if self._CurrentNPC then
                    local CooldownEndTime = self._CurrentNPC:GetAttribute("CooldownEnd")                    
                    if CooldownEndTime and os.time() < CooldownEndTime then
                        self:BeginFarming()
                    end
                else
                    self:BeginFarming()
                end
            end
        end))

        self._Maid:GiveTask(EventsFolder.UpdateDialogue.OnClientEvent:Connect(function(DialogueResponses, NPC)
            self:HandleDialogue(DialogueResponses, NPC)
        end))
        
        self._Maid:GiveTask(BeybladesFolder.ChildAdded:Connect(function(Beyblade)
            task.wait(0.5)
            if Beyblade:GetAttribute("TargetPlayer") == Client.Name then
                self._NPCBeyblade = Beyblade
            end
        end))

        self._Maid:GiveTask(BeybladesFolder.ChildRemoved:Connect(function(Beyblade)
            if Beyblade == self._NPCBeyblade then
                self._NPCBeyblade = nil
                task.wait(1)
                self:BeginFarming()
            end
        end))
        
        self:BeginFarming()
    end

    function BaseNPCBattleStrategy:BeginFarming()
        AutofarmController:UnlaunchBeyblade()

        local Character = Client.Character
        if not Character then return end
                
        self._CurrentNPC = self:FindAvailableNPC()
        self._NPCBeyblade = nil

        if not self._CurrentNPC then return end

        task.wait(4)
        Character.HumanoidRootPart.CFrame = self._CurrentNPC.HumanoidRootPart.CFrame
        task.wait(0.5)
        fireproximityprompt(self._CurrentNPC.HumanoidRootPart.Dialogue)
    end

    function BaseNPCBattleStrategy:FindAvailableNPC()
    end
end

do
    setmetatable(QuestFarmStrategy, BaseNPCBattleStrategy)
    QuestFarmStrategy.__index = QuestFarmStrategy

    function QuestFarmStrategy.new()
        return setmetatable(BaseNPCBattleStrategy.new(), QuestFarmStrategy)
    end

    function QuestFarmStrategy:GetQuest() 
        AutofarmController:UnlaunchBeyblade()
        local Character = Client.Character
        if not Character then return end
        
        local Quest = UIController:GetSelectedQuest()
        local QuestGiver = NPCsFolder:FindFirstChild(Quest) or HiddenNPCsFolder:FindFirstChild(Quest)

        if not QuestGiver or not QuestGiver.PrimaryPart then 
            return 
        end
        Character.HumanoidRootPart.CFrame = QuestGiver.PrimaryPart.CFrame

        NPCsFolder:WaitForChild(QuestGiver.Name)
        
        local oldQuestCount = #Stats.Quest.Data

        fireproximityprompt(QuestGiver.HumanoidRootPart.Dialogue)

        repeat 
            task.wait(1)
            print("hi")
        until #Stats.Quest.Data > oldQuestCount
    end

    function QuestFarmStrategy:FindAvailableNPC()
        local SelectedQuest = UIController:GetSelectedQuest()
        local QuestData = nil
        for _, quest_data in pairs(Stats.Quest.Data) do
            if string.find(quest_data.Name, SelectedQuest:match("%d+")) then
                QuestData = {}
                for i = 1, #quest_data.Objectives do
                    table.insert(QuestData, {
                        Level = quest_data.Objectives[i].Name, 
                        Amount = quest_data.Objectives[i].Amount,
                        Progress = quest_data.Progress[i]
                    })
                    warn(quest_data.Objectives[i].Name, quest_data.Progress[i])
                end
                break
            end
        end

        if QuestData == nil then
            self:GetQuest()
            return
        end        

        for _, NPC in NPCsFolder:GetChildren() do
            if not string.find(NPC.Name, "Trainer") then continue end

            local NPCLevel = NPC:GetAttribute("Level")

            for _, trainer in QuestData do
                if trainer.Progress < trainer.Amount and NPCLevel == trainer.Level then
                    local CooldownEndTime = NPC:GetAttribute("CooldownEnd")            
                    if CooldownEndTime and os.time() < CooldownEndTime then continue end
                    return NPC
                end
            end
        end

        return nil
    end


end

do
    setmetatable(BossFarmStrategy, BaseNPCBattleStrategy)
    BossFarmStrategy.__index = BossFarmStrategy

    function BossFarmStrategy.new()
        return setmetatable(BaseNPCBattleStrategy.new(), BossFarmStrategy)
    end

    function BossFarmStrategy:FindAvailableNPC()
        for _, NPC in NPCsFolder:GetChildren() do
            if not string.find(NPC.Name, "Boss") then continue end
            if not table.find(UIController:GetTargetBossNames(), NPC:GetAttribute("Name")) then
                continue
            end

            local CooldownEndTime = NPC:GetAttribute("CooldownEnd")            
            if CooldownEndTime and os.time() < CooldownEndTime then continue end
                        
            return NPC
        end

        return nil
    end
end

-- Controller Definitions
do
    local FarmStrategyClasses = {
        RockFarm = RockFarmStrategy,
        QuestFarm = QuestFarmStrategy,
        BossFarm = BossFarmStrategy
    }
    
    local StatsModule = require(ReplicatedStorage.Modules.Stats)

    function AutofarmController:FireServer(RemoteName, ...)
        RemotesFolder[RemoteName]:FireServer(...)
    end

    function AutofarmController:Attack(Target: Model)
        local AttackRemote = RemotesFolder:FindFirstChild("Attack")
        if not AttackRemote then return end
        
        local ClientBeyblade = self:GetClientBeyblade()
        if not ClientBeyblade then return end

        local TargetPosition = Target.PrimaryPart.Position
        local RandomValue = RNG:NextNumber(0.85, 0.9)

        AttackRemote:FireServer("Attack", ClientBeyblade, Target, RandomValue, TargetPosition)
    end

    function AutofarmController:FireSkills(Target: Model)
        local EquippedBeyblade = nil
        for _, Item in StatsModule.Inventory.Items do
            if Item.Name == "Beyblade" and Item.Equipped then
                EquippedBeyblade = Item
                break
            end
        end

        if not EquippedBeyblade then return end

        local TargetPrimaryPart = Target.PrimaryPart
        local TargetPosition = TargetPrimaryPart.Position

        for SkillIndex, _ in pairs(EquippedBeyblade.Skills) do
            -- RunSkill, returns debounce data which we could utilise
            -- FinishSkill, for 2nd arg I could've put any instance, since
            --  it doesn't affect the skill's performance
            RemotesFolder.SetPoint:FireServer(TargetPosition)

            -- May yield, so process in a thread
            task.spawn(function()
                RemotesFolder.RunSkill:InvokeServer("Skill" .. SkillIndex)
            end)
            RemotesFolder.FinishSkill:FireServer(TargetPosition, TargetPrimaryPart)
        end
    end

    function AutofarmController:GetClientBeyblade() : Model
        return BeybladesFolder:FindFirstChild(Client.Name)
    end
    
    function AutofarmController:LaunchBeyblade()
        local ClientBeyblade: Model = self:GetClientBeyblade()
        if not ClientBeyblade then
            repeat
                AutofarmController:FireServer("Launch")
                task.wait(GENERAL_POLL_DELAY)
            until self:GetClientBeyblade()
        end
    end

    function AutofarmController:UnlaunchBeyblade()
        local Character = Client.Character
        if Character and Character:GetAttribute("Launching") then
            Character:GetAttributeChangedSignal("Launching"):Wait()
        end
        local ClientBeyblade: Model = self:GetClientBeyblade()
        if ClientBeyblade then
            repeat
                AutofarmController:FireServer("Launch")
                task.wait(GENERAL_POLL_DELAY)
            until not self:GetClientBeyblade()
        end
    end

    function AutofarmController:SwitchStrategy(NewStrategyType: string?)
        if self.CurrentFarmStrategy then
            self.CurrentFarmStrategy:Destroy()
            self.CurrentFarmStrategy = nil
        end

        if NewStrategyType and FarmStrategyClasses[NewStrategyType] then
            -- Create a new instance of the strategy class
            self.CurrentFarmStrategy = FarmStrategyClasses[NewStrategyType].new()

            if UIController:IsBeybladeAutofarmToggled() then
                self.CurrentFarmStrategy:Start()
            end
        end
    end

    function AutofarmController:Init()
        self.CurrentFarmStrategy = nil
    end
    
    function AutofarmController:Start()
        local CharacterMaid = Maid.new()
        
        local function OnCharacterAdded(Character)
            CharacterMaid:DoCleaning()

            Character:WaitForChild("HumanoidRootPart")
            Character:WaitForChild("Humanoid")

            -- Handle Beyblade autofarm updates
            CharacterMaid:GiveTask(RunService.Heartbeat:Connect(function()
                if not UIController:IsBeybladeAutofarmToggled() then return end
                if self.CurrentFarmStrategy then
                    self.CurrentFarmStrategy:Update()
                end
            end))
            
            -- Handle priority changes
            CharacterMaid:GiveTask(UIController.OnCurrentFarmChanged:Connect(function(NewFarmType: string?)
                self:SwitchStrategy(NewFarmType)
            end))

            CharacterMaid:GiveTask(UIController.OnBeybladeAutofarmToggled:Connect(function(IsEnabled: boolean)
                local CurrentStrategy = self.CurrentFarmStrategy
                
                if CurrentStrategy then
                    if IsEnabled then
                        CurrentStrategy:Start()
                    else
                        self:SwitchStrategy(nil)
                    end
                elseif IsEnabled then
                    self:SwitchStrategy(UIController:GetCurrentValidFarm())
                end
            end))

            -- Cleanup
            CharacterMaid:GiveTask(function()
                self:SwitchStrategy(nil) -- Clean up current strategy
            end)
        end

        Client.CharacterAdded:Connect(OnCharacterAdded)
        if Client.Character then
            task.spawn(OnCharacterAdded, Client.Character)
        end
    end
end

do 
    local CONFIG_FOLDER_NAME: string = "TEST-CONFIG1"

    UIController.OnBeybladeAutofarmToggled = Signal.new()

    UIController.OnQuestFarmToggled = Signal.new() 
    UIController.OnBossFarmToggled = Signal.new()
    UIController.OnRockFarmToggled = Signal.new() 

    UIController.OnCurrentFarmChanged = Signal.new()
    UIController.OnRockTargetTypeChanged = Signal.new()
    UIController.OnQuestChanged = Signal.new()
    UIController.OnTrainerLevelChanged = Signal.new()

    UIController.OnStaffAutoKickChanged = Signal.new()

    -- State management
    UIController.State = {
        IsAutofarmEnabled = false,
        ActiveFarms = {
            RockFarm = {
                Enabled = false,
                Priority = 10,
                SelectedRock = "Rock"
            },

            QuestFarm = {
                Enabled = false,
                Priority = 10,
                SelectedQuest = "None"
            },

            BossFarm = {
                Enabled = false,
                Priority = 10
            }
        }
    }

    -- Helpers
    function UIController:_UpdateFarmHierarchy()
        local NewHighestPriorityFarm = self:GetCurrentValidFarm()

        -- Store the last highest priority farm if we haven't yet
        if not self._LastHighestPriorityFarm then
            self._LastHighestPriorityFarm = NewHighestPriorityFarm
            self.OnCurrentFarmChanged:Fire(NewHighestPriorityFarm, nil)
            return
        end
        
        -- If the highest priority farm has changed, fire the signal
        if self._LastHighestPriorityFarm ~= NewHighestPriorityFarm then
            self.OnCurrentFarmChanged:Fire(NewHighestPriorityFarm, self._LastHighestPriorityFarm)
            self._LastHighestPriorityFarm = NewHighestPriorityFarm
        end
    end

    -- State getters
    function UIController:IsBeybladeAutofarmToggled(): boolean
        return self.State.IsAutofarmEnabled
    end

    function UIController:GetSelectedRockName(): string
        return self.State.ActiveFarms.RockFarm.SelectedRock
    end

    function UIController:GetSelectedQuest(): string
        return self.State.ActiveFarms.QuestFarm.SelectedQuest
    end
    
    function UIController:GetTargetBossNames()
        return Rayfield.Flags.SelectedBossToFarm.CurrentOption
    end

    function UIController:GetCurrentValidFarm(): nil | string
        local HighestPriority: number = -1
        local SelectedFarm: (nil | string) = nil
        
        for FarmType: string, FarmData in self.State.ActiveFarms do
            if FarmData.Enabled and FarmData.Priority > HighestPriority then
                HighestPriority = FarmData.Priority
                SelectedFarm = FarmType
            end
        end
        
        return SelectedFarm
    end

    function UIController:CanStaffAutoKick()
        return Rayfield.Flags.CanStaffAutoKick.CurrentValue
    end

    -- State setters
    function UIController:SetAutofarmEnabled(IsEnabled: boolean)
        self.State.IsAutofarmEnabled = IsEnabled
        self.OnBeybladeAutofarmToggled:Fire(IsEnabled)
    end

    function UIController:SetSelectedRock(RockName: string)
        self.State.ActiveFarms.RockFarm.SelectedRock = RockName
        self.OnRockTargetTypeChanged:Fire()
    end

    function UIController:SetSelectedQuest(QuestName: string)
        self.State.ActiveFarms.QuestFarm.SelectedQuest = QuestName
        self.OnQuestChanged:Fire()
    end

    function UIController:SetFarmState(FarmType: string, IsEnabled: boolean)
        if IsEnabled ~= nil then
            self.State.ActiveFarms[FarmType].Enabled = IsEnabled
        end
        self:_UpdateFarmHierarchy()
    end

    function UIController:Start()
    end
    
    function UIController:Init()
        local Window = Rayfield:CreateWindow({
            Name = "Blader's Rebirth",
            LoadingTitle = "Loading User Interface",
            LoadingSubtitle = "Script Credits: OnlineCat v1.85",
    
            ConfigurationSaving = {
                Enabled = true,
                FolderName = CONFIG_FOLDER_NAME
            },
            
            KeySystem = false
        })

        UIController:_CreateFarmTab(Window)
        UIController:_CreateMiscTab(Window)
        Rayfield:LoadConfiguration()
    end

    function UIController:_CreateMiscTab(Window)
        local Tab = Window:CreateTab("Misc", 4483362458)
        
        -- Staff Management Section
        Tab:CreateSection("Staff Manangement")
        Tab:CreateToggle({
            Name = "Staff Auto-Kick",
            CurrentValue = false,
            Flag = "CanStaffAutoKick",
            Callback = function(State)
                self.OnStaffAutoKickChanged:Fire(State)
            end,
        })
    end
    
    function UIController:_CreateFarmTab(Window)
        local Tab = Window:CreateTab("Farming", 4483362458)
        
        -- Main Autofarm Toggle Section
        Tab:CreateSection("Main Controls")
        
        Tab:CreateToggle({
            Name = "Enable Beyblade Autofarm",
            CurrentValue = self.State.IsAutofarmEnabled,
            Flag = "MainAutofarmToggle",
            Callback = function(State)
                self:SetAutofarmEnabled(State)
            end,
        })
        --[[
        -- Rock Farm Section
        Tab:CreateSection("Auto Rock Farm")

        local RockList = {
            "Rock", "Large Rock", "Cobblestone", "Metal", "Large Metal Rock", 
            "Blood Rock", "Bluesteel Rock", "Large Bluesteel Rock",
            "Sandstone", "Sandcastle", "Cactus", "Glacier", "Ice Crystal", 
            "Water Rock", "Giant Water Rock", "Ghost Tear", "Darkstone", 
            "Molten Rock", "Large Darkstone", "Portable Crystal", "Boulder"
        }

        -- Add anything extra we missed out
        for _, Rock in TrainingFolder:GetChildren() do
            if not table.find(RockList, Rock.Name) then continue end
            table.insert(RockList, Rock.Name)        
        end
        
        Tab:CreateDropdown({
            Name = "Select Rock to Farm",
            Options = RockList,
            CurrentOption = {self.State.ActiveFarms.RockFarm.SelectedRock},
            Flag = "SelectedRockToFarm",
            Callback = function(Option)
                self:SetSelectedRock(Option[1])
            end
        })
        
        Tab:CreateToggle({
            Name = "Rock Autofarm",
            CurrentValue = self.State.ActiveFarms.RockFarm.Enabled,
            Flag = "RockAutofarmToggle",
            Callback = function(State)
                self:SetFarmState("RockFarm", State)
                UIController.OnRockFarmToggled:Fire(State)
            end,
        })
        --]]

        -- Trainer NPC Autofarm Section
        Tab:CreateSection("Auto Trainer Farm")

        -- Get the highest level trainer in the game
        local MaxTrainerLevel = -math.huge
        for _, NPC in NPCsFolder:GetChildren() do
            if not string.find(NPC.Name, "Trainer") then continue end
            local NPCLevel = NPC:GetAttribute("Level")
            if NPCLevel < MaxTrainerLevel then continue end
            MaxTrainerLevel = NPCLevel
        end

        local QuestList = {}
        for _, folder in ipairs({NPCsFolder, HiddenNPCsFolder}) do
            for _, npc in ipairs(folder:GetChildren()) do
                if npc.Name:find("Quest") and not npc.Name:find("Boss") then
                    table.insert(QuestList, npc.Name)
                end
            end
        end
        
        table.sort(QuestList, function(a, b)
            return tonumber(a:match("%d+")) < tonumber(b:match("%d+"))
        end)
        
        Tab:CreateDropdown({
            Name = "Select Quest",
            Options = QuestList,
            CurrentOption = {self.State.ActiveFarms.QuestFarm.SelectedQuest},
            Flag = "SelectedQuest",
            Callback = function(Option)
                self:SetSelectedQuest(Option[1])
            end
        })

        Tab:CreateToggle({
            Name = "Quest Autofarm",
            CurrentValue = false,
            Flag = "QuestAutofarmToggle",
            Callback = function(State)
                self:SetFarmState("QuestFarm", State)
                self.OnQuestFarmToggled:Fire(State)
            end,
        })

        -- Boss NPC Autofarm Section
        -- Tab:CreateSection("Auto Boss Farm")
	
        -- local BossList = {}
        -- for _, NPC in ipairs(NPCsFolder:GetChildren()) do
        --     if not string.find(NPC.Name, "Boss") then continue end
        --     table.insert(BossList, NPC:GetAttribute("Name"))
        -- end
        
        -- Tab:CreateDropdown({
        --     Name = "Select Bosses to Farm",
        --     Options = BossList,
        --     CurrentOption = {BossList[1]},
        --     Flag = "SelectedBossToFarm",
        --     MultipleOptions = true,
        --     Callback = function() end
        -- })
        
        -- Tab:CreateToggle({
        --     Name = "Boss Autofarm",
        --     CurrentValue = false,
        --     Flag = "BossAutofarmToggle",
        --     Callback = function(State)
        --         self:SetFarmState("BossFarm", State)
        --         self.OnBossFarmToggled:Fire(State)
        --     end,
        -- })
    end

    function UIController:Notify(MessageData)
        Rayfield:Notify({
            Title = MessageData.Title,
            Content = MessageData.Content,
            Duration = MessageData.Duration,
            Image = 4483362458,
         })
    end
end

do
    local GAME_GROUP_ID = 33103002
    local MINIMUM_GROUP_FLAG_RANK = 95 -- Minimum: Contributor rank

    function MiscController:OnPlayerAdded(Player)
        if Player:GetRankInGroup(GAME_GROUP_ID) < MINIMUM_GROUP_FLAG_RANK then return end

        local StaffName = Player.Name
        local StaffRole = Player:GetRoleInGroup(GAME_GROUP_ID)

        local MessageContent = "Staff Name: " .. StaffName  .. ", Staff Role/Rank: " .. StaffRole
        UIController:Notify({
            Title = "[WARNING] Staff In Game!",
            Content = MessageContent
        })

        if UIController:CanStaffAutoKick() then
            Client:Kick("Kicked from game due to staff being in the same server! " .. MessageContent)
        end
    end

    function MiscController:Init()
        --immediate check
        UIController.OnStaffAutoKickChanged:Connect(function(IsEnabled)
            if not IsEnabled then return end
            for _, Player in Players:GetPlayers() do
                task.spawn(function()
                    self:OnPlayerAdded(Player)
                end)
            end    
        end)

        --Recurring check on new joins
        Players.PlayerAdded:Connect(function(Player)
            self:OnPlayerAdded(Player)
        end)


        --initial startup check
        for _, Player in Players:GetPlayers() do
            task.spawn(function()
                self:OnPlayerAdded(Player)
            end)
        end 
    end

    function MiscController:Start()
    end
end

local function LoadControllers()
    -- Functions check
    for _, FunctionName in pairs({
        "getfenv",
        "getgc",
        "islclosure",
        "fireproximityprompt",
        "getupvalues"
    }) do
        assert(loadstring("return " .. FunctionName)(), "Function: " .. FunctionName .. " couldn't be found!")
        
    end

    -- Grab network functions
    local NetworkModule = ReplicatedStorage.Modules.Network
    local NetworkFireMethod = nil

    for _, Function in getgc() do
        if type(Function) == "function" and islclosure(Function) then
            if getfenv(Function).script == NetworkModule and getinfo(Function).name == "fire" then
                NetworkFireMethod = Function
                break
            end
        end 
    end

    -- Reverse Remote name randomisations
    for _, Upvalue in getupvalues(NetworkFireMethod) do
        if type(Upvalue) == "table" and Upvalue["Attack"] then            
            for RemoteName, RemoteObject in Upvalue do
                RemoteObject.Name = RemoteName
            end
            break
        end
    end

    -- Anti-idle/afk
    Client.Idled:Connect(function()
        VirtualUser:ClickButton2(Vector2.new())
    end)

    -- Initialize controllers
    UIController:Init()
    AutofarmController:Init()
    MiscController:Init()

    UIController:Start()
    AutofarmController:Start()
    MiscController:Start()
end

LoadControllers()