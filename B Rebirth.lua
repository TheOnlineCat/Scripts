--[[
loadstring(game:HttpGet("https://raw.githubusercontent.com/TheOnlineCat/Scripts/refs/heads/refactor/B%20Rebirth.lua?t=" .. os.time()))()
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
local TaskRunner = {}

local BaseFarmStrategy = {}
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
    TaskRunner.__index = TaskRunner
    
    function TaskRunner.new()
        local self = setmetatable({}, TaskRunner)
        self._isRunning = false -- Lock to prevent multiple executions
        self._Maid = Maid.new() 
        return self
    end
    
    function TaskRunner:Run(taskFunction, ...)
        if self._isRunning then
            print("Already Running")
            return
        end
    
        self._isRunning = true
        local args = {...}
    
        self._Maid:GiveTask(task.spawn(function()
            taskFunction(table.unpack(args)) 
            self._isRunning = false 
        end))
    end
    
    function TaskRunner:Destroy()
        self._Maid:DoCleaning() 
        self._Maid = nil
        self._isRunning = false
    end
end

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

        -- self._Maid:GiveTask(function()
        --     self._CurrentNPC = nil
        --     self._NPCBeyblade = nil
        -- end)

        return self
    end

    function BaseNPCBattleStrategy:HandleDialogue(Responses: { DialogueChoice }, npc: Model)
        if not Responses or not npc then return end

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

    function BaseNPCBattleStrategy:BossAccept()
    end

    function BaseNPCBattleStrategy:IsNpcOnCooldown(npc)
        local CooldownEndTime = npc:GetAttribute("CooldownEnd")                    
        return CooldownEndTime and os.time() < CooldownEndTime
    end

    function BaseNPCBattleStrategy:Update()
        if not self._CurrentNPC or self:IsNpcOnCooldown(self._CurrentNPC) then
            AutofarmController:RunTask(function()
                self:InitiateFight()
            end)
        end

        if not self._NPCBeyblade then return end

        local ClientBeyblade: Model = AutofarmController:GetClientBeyblade()
        if not ClientBeyblade then return end

        -- Attack logic
        if os.clock() - self._LastAttack >= GENERAL_POLL_DELAY then
            self._LastAttack = os.clock()
            AutofarmController:Attack(self._NPCBeyblade)
            AutofarmController:FireSkills(self._NPCBeyblade)
        end

        -- Teleport logic
        ClientBeyblade.HumanoidRootPart.CFrame = self._NPCBeyblade.HumanoidRootPart.CFrame * CFrame.new(0, UIController:GetFarmDistance(), 0)
    end

    function BaseNPCBattleStrategy:Start()
        self._Maid:GiveTask(EventsFolder.UpdateDialogue.OnClientEvent:Connect(function(DialogueResponses, npc)
            warn("hi")
            self:HandleDialogue(DialogueResponses, npc)
        end))

        self._Maid:GiveTask(EventsFolder.ShowBossInfo.OnClientEvent:Connect(function(...)
            task.wait(0.3)
            AutofarmController:FireServer("StartBossBattle", "Easy")
        end))
        
        self._Maid:GiveTask(BeybladesFolder.ChildAdded:Connect(function(Beyblade)
            task.wait(0.3)
            if Beyblade:GetAttribute("TargetPlayer") == Client.Name then
                self._NPCBeyblade = Beyblade
            end
        end))

        self._Maid:GiveTask(BeybladesFolder.ChildRemoved:Connect(function(Beyblade)
            if Beyblade == self._NPCBeyblade then
                self._NPCBeyblade = nil
                self._CurrentNPC = nil
            end
        end))
        
        AutofarmController:RunTask(function()
            self:InitiateFight()
        end)
    end

    function BaseNPCBattleStrategy:InitiateFight()
        warn("initiating fight. should only see this once")
        AutofarmController:UnlaunchBeyblade()
    
        local Character = Client.Character
        if not Character then return end
    
        self._CurrentNPC = self:FindAvailableNPC()
        self._NPCBeyblade = nil
    
        if not self._CurrentNPC then
            warn("No Target")
            -- AutofarmController:QueueNextStrategy()
            return
        end
    
        task.wait(4 + UIController:GetFarmDelay())
        local success, err = pcall(function()
            Character.HumanoidRootPart.CFrame = self._CurrentNPC.HumanoidRootPart.CFrame
        end)
        if not success then
            print("Function failed with error:", err)
            print(self._CurrentNPC)
        else
            print("Function succeeded!")
        end
        task.wait(1)
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
        local Character = Client.Character
        if not Character then return end
        
        local Quest = UIController:GetSelectedQuest()
        local QuestGiver = NPCsFolder:FindFirstChild(Quest) or HiddenNPCsFolder:FindFirstChild(Quest)

        if not QuestGiver or not QuestGiver.PrimaryPart then 
            return 
        end

        task.wait(4 + UIController:GetFarmDelay())
        Character.HumanoidRootPart.CFrame = QuestGiver.PrimaryPart.CFrame
        NPCsFolder:WaitForChild(QuestGiver.Name)
        task.wait(0.5)
        fireproximityprompt(QuestGiver.HumanoidRootPart.Dialogue)
        EventsFolder.UpdateAllQuests.OnClientEvent:Wait()
        print("retrieved quest")
    end

    function QuestFarmStrategy:FindAvailableNPC()
        local QuestData = nil
        while not QuestData do
            for name, quest_data in pairs(Stats.Quest.Data) do
                if string.find(name, "Trainer") and quest_data.Type == nil then
                    QuestData = {}
                    for i = 1, #quest_data.Objectives do
                        table.insert(QuestData, {
                            Level = tonumber(quest_data.Objectives[i].Name), 
                            Amount = quest_data.Objectives[i].Amount,
                            Progress = quest_data.Progress[i]
                        })
                    end
                    break
                end
            end

            if QuestData == nil then
                self:GetQuest()
            end 
        end

                   
        for _, npc in NPCsFolder:GetChildren() do
            if not string.find(npc.Name, "Trainer") then continue end
            local NPCLevel = npc:GetAttribute("Level")
            for _, questTrainer in QuestData do
                if questTrainer.Progress >= questTrainer.Amount then continue end
                if NPCLevel == questTrainer.Level and not self:IsNpcOnCooldown(npc)then
                    warn(npc.Name, "can be fought")
                    return npc
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
        for _, folder in {NPCsFolder, HiddenNPCsFolder} do
            for _, boss in folder:GetChildren() do
                if not table.find(UIController:GetTargetBossNames(), boss:GetAttribute("Name")) then
                    continue
                end
                if not self:IsNpcOnCooldown(boss) then
                    warn(boss:GetAttribute("Name"), "can be fought")
                    return boss
                end
            end
        end

        return nil
    end
end

-- Controller Definitions
do
    local FarmStrategyClasses = {
        QuestFarm = QuestFarmStrategy,
        BossFarm = BossFarmStrategy
    }
    
    function AutofarmController:Init()
        self.CurrentFarmStrategy = nil
        self.CurrentFarm = nil
        self.TaskRunner = TaskRunner.new()
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
            
            -- Handle Strategy changes
            CharacterMaid:GiveTask(UIController.OnCurrentFarmChanged:Connect(function(NewFarmType: string?)
                self:SwitchStrategy(NewFarmType)
            end))

            CharacterMaid:GiveTask(UIController.OnBeybladeAutofarmToggled:Connect(function(IsEnabled: boolean)
                local CurrentStrategy = self.CurrentFarmStrategy

                if not IsEnabled then
                    self:SwitchStrategy(nil) --destroy all strategies
                    return
                end
                
                if CurrentStrategy then
                    CurrentStrategy:Start()
                else
                    self:SwitchStrategy(self:QueueNextStrategy())
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

    function AutofarmController:RunTask(task)
        self.TaskRunner:Run(task)
    end

    function AutofarmController:FireServer(RemoteName, ...)
        RemotesFolder[RemoteName]:FireServer(...)
    end

    function AutofarmController:Attack(Target: Model)
        local ClientBeyblade = self:GetClientBeyblade()
        if not ClientBeyblade then return end

        local TargetPosition = Target.PrimaryPart.Position
        local RandomValue = RNG:NextNumber(0.85, 0.9)

        AutofarmController:FireServer("Attack", "Attack", ClientBeyblade, Target, RandomValue, TargetPosition)
    end

    function AutofarmController:FireSkills(Target: Model)
        local EquippedBeyblade = nil
        for _, Item in Stats.Inventory.Items do
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
            self.CurrentFarm = nil
        end

        if NewStrategyType and FarmStrategyClasses[NewStrategyType] then
            -- Create a new instance of the strategy class
            self.CurrentFarmStrategy = FarmStrategyClasses[NewStrategyType].new()
            self.CurrentFarm = NewStrategyType

            if UIController:IsBeybladeAutofarmToggled() then
                warn(self.CurrentFarm)
                self.CurrentFarmStrategy:Start()
            end
        end
    end

    function AutofarmController:QueueNextStrategy()
        warn("Switching off from", self.CurrentFarm, "and going to", UIController:GetNextFarm(self.CurrentFarm))
        self:SwitchStrategy(UIController:GetNextFarm(self.CurrentFarm))
    end
end

do 
    local CONFIG_FOLDER_NAME: string = "TEST-CONFIG1"

    UIController.OnBeybladeAutofarmToggled = Signal.new()

    UIController.OnQuestFarmToggled = Signal.new() 
    UIController.OnBossFarmToggled = Signal.new()

    UIController.OnCurrentFarmChanged = Signal.new()
    UIController.OnQuestChanged = Signal.new()
    UIController.OnTrainerLevelChanged = Signal.new()

    UIController.OnStaffAutoKickChanged = Signal.new()

    -- State management
    UIController.State = {
        IsAutofarmEnabled = false,
        FarmConfig = {
            Distance = 1,
            Delay = 0
        },
        Farms = {
            QuestFarm = {
                Enabled = false,
                Priority = 2,
                SelectedQuest = "None"
            },

            BossFarm = {
                Enabled = false,
                Priority = 3
            }
        }
    }

    -- Helpers
    function UIController:_UpdateFarmHierarchy()
        local FarmStrategy = self:GetNextFarm()

        
    end

    -- State getters
    function UIController:IsBeybladeAutofarmToggled(): boolean
        return self.State.IsAutofarmEnabled
    end


    function UIController:GetSelectedQuest(): string
        return self.State.Farms.QuestFarm.SelectedQuest
    end
    
    function UIController:GetTargetBossNames()
        return Rayfield.Flags.SelectedBossToFarm.CurrentOption
    end

    function UIController:GetFarmDistance(): string
        return self.State.FarmConfig.Distance
    end

    function UIController:GetFarmDelay(): string
        return self.State.FarmConfig.Delay
    end

    function UIController:GetNextFarm(currentFarm): nil | string
        local Farms = self.State.Farms

        local HighestPriority: number = -1
        local HighestFarm = nil
        local SelectedFarm: (nil | string) = nil
        local CurrentPriority: number = (Farms[currentFarm] and Farms[currentFarm].Priority) or math.huge
        
        for FarmType: string, FarmData in Farms do
            if FarmData.Enabled then
                if not HighestFarm or Farms[HighestFarm].Priority < FarmData.Priority then
                    HighestFarm = FarmType
                end
                if FarmData.Priority > HighestPriority and FarmData.Priority < CurrentPriority then
                    HighestPriority = FarmData.Priority
                    SelectedFarm = FarmType
                end
            end
        end
        
        if SelectedFarm then
            return SelectedFarm
        else
            return HighestFarm
        end
    end

    function UIController:CanStaffAutoKick()
        return Rayfield.Flags.CanStaffAutoKick.CurrentValue
    end

    -- State setters
    function UIController:SetAutofarmEnabled(IsEnabled: boolean)
        self.State.IsAutofarmEnabled = IsEnabled
        self.OnBeybladeAutofarmToggled:Fire(IsEnabled)
    end

    function UIController:SetSelectedQuest(QuestName: string)
        self.State.Farms.QuestFarm.SelectedQuest = QuestName
        self.OnQuestChanged:Fire()
    end

    function UIController:SetFarmState(FarmType: string, IsEnabled: boolean)
        if IsEnabled ~= nil then
            self.State.Farms[FarmType].Enabled = IsEnabled
        end
        self.OnCurrentFarmChanged:Fire(self:GetNextFarm())
    end

    function UIController:Start()
    end
    
    function UIController:Init()
        local Window = Rayfield:CreateWindow({
            Name = "Blader's Rebirth v4.95",
            LoadingTitle = "Loading User Interface",
            LoadingSubtitle = "Script Credits: OnlineCat",
    
            ConfigurationSaving = {
                Enabled = true,
                FolderName = CONFIG_FOLDER_NAME
            },
            
            KeySystem = false
        })

        UIController:_CreateFarmTab(Window)
        UIController:_CreateConfigTab(Window)
        UIController:_CreateMiscTab(Window)
        Rayfield:LoadConfiguration()
    end

    function UIController:_CreateConfigTab(Window)
        local Tab = Window:CreateTab("Config", 4483362458)
        
        Tab:CreateSection("Farm Settings")
        Tab:CreateSlider({
            Name = "Distance to Target",
            Range = {1, 10},
            Increment = 1,
            CurrentValue = self.State.FarmConfig.Distance,
            Flag = "FarmDistance",
            Callback = function(Value)
                self.State.FarmConfig.Distance = tonumber(Value)
            end,
        })
        Tab:CreateSlider({
            Name = "Delay After Battle",
            Range = {0, 10},
            Increment = 1,
            CurrentValue = self.State.FarmConfig.Delay,
            Flag = "FarmDelay",
            Callback = function(Value)
                self.State.FarmConfig.Delay = tonumber(Value)
                self.OnTrainerLevelChanged:Fire()
            end,
        })
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
        Tab:CreateButton({
            Name = "Button Example",
            Callback = function()
                game:GetService("StarterGui"):SetCore("DevConsoleVisible", true)
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

        -- Trainer NPC Autofarm Section
        Tab:CreateSection("Auto Trainer Farm")

        -- Get the highest level trainer in the game
        local MaxTrainerLevel = -math.huge
        for _, npc in NPCsFolder:GetChildren() do
            if not string.find(npc.Name, "Trainer") then continue end
            local NPCLevel = npc:GetAttribute("Level")
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
            CurrentOption = {self.State.Farms.QuestFarm.SelectedQuest},
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
        Tab:CreateSection("Auto Boss Farm")
	
        local BossList = {"Volt", "Shin", "Ryuke", "Jinka"}
        for _, folder in ipairs({NPCsFolder, HiddenNPCsFolder}) do
            for _, npc in ipairs(folder:GetChildren()) do
                if npc.Name:find("^Boss") then
                    table.insert(BossList, npc:GetAttribute("Name"))
                end
            end
        end
        table.sort(BossList)
        
        Tab:CreateDropdown({
            Name = "Select Bosses to Farm",
            Options = BossList,
            CurrentOption = {BossList[1]},
            Flag = "SelectedBossToFarm",
            MultipleOptions = true,
            Callback = function() end
        })
        
        Tab:CreateToggle({
            Name = "Boss Autofarm",
            CurrentValue = false,
            Flag = "BossAutofarmToggle",
            Callback = function(State)
                self:SetFarmState("BossFarm", State)
                self.OnBossFarmToggled:Fire(State)
            end,
        })
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