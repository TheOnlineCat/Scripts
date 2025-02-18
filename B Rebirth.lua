--[[
loadstring(game:HttpGet("https://raw.githubusercontent.com/TheOnlineCat/Scripts/refs/heads/refactor/B%20Rebirth.lua?t=" .. os.time(), true))()
--]]

if game.GameId ~= 5321619756 then
    return -- Stops script execution in unintended games
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

-- Packages
local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua"))()
local Maid = loadstring(game:HttpGet("https://raw.githubusercontent.com/Quenty/NevermoreEngine/refs/heads/main/src/maid/src/Shared/Maid.lua"))()
local Signal = loadstring(game:HttpGet("https://raw.githubusercontent.com/Sleitnick/RbxUtil/refs/heads/main/modules/signal/init.luau"))()

-- Constants
local GENERAL_POLL_DELAY = 0.1

-- Controllers
local AutofarmController = {}
local AutoTaskController = {}
local MiscController = {}
local UIController = {}

-- Classes
local TaskRunner = {}

local BaseFarmStrategy = {}

local CrystalFarmStrategy = {}

local BaseNPCBattleStrategy = {}
local QuestFarmStrategy = {}
local BossFarmStrategy = {}



-- Variables
local PLACE_ID = game.PlaceId 
local Client = Players.LocalPlayer
local EventsFolder = ReplicatedStorage.Events
local VendingMachinesFolder = workspace.World.VendingMachines
local BeybladesFolder = workspace.Beyblades
local TrainingFolder = workspace.Training
local NPCsFolder = workspace.NPCs
local HiddenNPCsFolder = ReplicatedStorage.HiddenNPCs
local RemotesFolder = ReplicatedStorage.Events
local Stats = require(ReplicatedStorage.Modules.Stats)
local ItemIndex = Client.PlayerGui.UI.Menu.ItemIndex:FindFirstChild("ItemIndex/Inventory")

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
    setmetatable(CrystalFarmStrategy, BaseFarmStrategy)
    CrystalFarmStrategy.__index = CrystalFarmStrategy

    function CrystalFarmStrategy.new()
        local self = setmetatable(BaseFarmStrategy.new(), CrystalFarmStrategy)

        self.RandomSearchTime = RNG:NextInteger(2, 4)

        return self
    end

    function CrystalFarmStrategy:Update()
        if AutofarmController.Crystal then
            if os.clock() >= AutofarmController.TimeOfCrystalSpawn + 600 then
                AutofarmController.Crystal = nil
                AutofarmController.TimeOfCrystalSpawn = nil
                AutofarmController:QueueNextStrategy(false)
            end

            warn("crystal prep")

            AutofarmController:UnlaunchBeyblade()

            if os.clock() - self.RandomSearchTime < AutofarmController.TimeOfCrystalSpawn then return end
            
            warn("crystal start pick")

            AutofarmController:RunTask(function()
                local success, error = pcall(function()
                    local Character = Client.Character
                    if not Character then return end
                    local previousCFrame = Character.HumanoidRootPart.CFrame
                    AutofarmController:TeleportToCFrame(AutofarmController.Crystal.PrimaryPart.CFrame)
                    task.wait(0.1)
                    fireproximityprompt(AutofarmController.Crystal.PrimaryPart.Crystal)
                    task.wait(0.1)
                    AutofarmController:TeleportToCFrame(previousCFrame)
                    AutofarmController.Crystal = nil
                    AutofarmController:QueueNextStrategy(true)
                    return
                end)

                if not success then
                    warn(error)
                end
            end)
                
        end
    end

    function CrystalFarmStrategy:Start()
        if not AutofarmController.Crystal then
            AutofarmController:QueueNextStrategy(false)
        end
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
        self._PreviousNPC = nil
        self._CurrentNPC = nil
        self._NPCBeyblade = nil
        self._IsBattling = false

        self._LastAttack = 0
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
        
        local ChoiceId = FirstReplyId or FirstResponseId
        
        task.wait(0.5)
        AutofarmController:FireServer("DialogueChoice", ChoiceId)
    end

    function BaseNPCBattleStrategy:BossAccept()
    end

    function BaseNPCBattleStrategy:IsNpcOnCooldown(npc)
        local CooldownEndTime = npc:GetAttribute("CooldownEnd")                    
        return CooldownEndTime and os.time() < CooldownEndTime
    end

    function BaseNPCBattleStrategy:Update()
        if not self._IsBattling then
            if not self._CurrentNPC or self:IsNpcOnCooldown(self._CurrentNPC) then
                AutofarmController:RunTask(function()
                    self:InitiateFight()
                end)
            end
        end

        if not self._NPCBeyblade then return end

        self._IsBattling = true

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
            self:HandleDialogue(DialogueResponses, npc)
        end))

        self._Maid:GiveTask(BeybladesFolder.ChildAdded:Connect(function(Beyblade)
            task.wait(0.3)
            if Beyblade:GetAttribute("TargetPlayer") == Client.Name then
                self._NPCBeyblade = Beyblade
            end
        end))

        self._Maid:GiveTask(BeybladesFolder.ChildRemoved:Connect(function(Beyblade)
            if Beyblade == self._NPCBeyblade or (Beyblade.Name == Client.Name and self._NPCBeyblade) then
                self._NPCBeyblade = nil
                self._CurrentNPC = nil
                self._NPCBeyblade = nil

                --wait until back
                EventsFolder.BattleTransition.OnClientEvent:Wait() 
                task.wait(2 + UIController:GetFarmDelay())
                self._IsBattling = false
                AutofarmController:QueueNextStrategy(true)
            end
        end))

        self._Maid:GiveTask(EventsFolder.ShowBossInfo.OnClientEvent:Connect(function(bossInfo)
            task.wait(0.5)
            if bossInfo["Badge"] then
                AutofarmController:FireServer("StartBossBattle", UIController:GetBossDifficulty())
            else
                AutofarmController:FireServer("StartBossBattle", UIController:GetWorldBossDifficulty())
            end
            
        end))
        
        AutofarmController:RunTask(function()
            self:InitiateFight()
        end)
    end

    function BaseNPCBattleStrategy:InitiateFight()
        AutofarmController:UnlaunchBeyblade()
    

    
        local NpcTarget = self:FindAvailableNPC()
        self._NPCBeyblade = nil
    
        if not NpcTarget then
            AutofarmController:QueueNextStrategy(false)
            return
        end
    
        local NpcCFrame = NpcTarget.PrimaryPart.CFrame
        if not AutofarmController:TeleportToCFrame(NpcCFrame * CFrame.new(0, 2, -6)) then return end

        self._CurrentNPC = NPCsFolder:WaitForChild(NpcTarget.Name, 5)
        if not self._CurrentNPC  then return end
        local CurrentTarget = self._CurrentNPC 
        pcall(function()
            self._Maid:GiveTask(task.delay(15, function()
                -- Only reset if `_CurrentNPC` is still the same NPC and not in Battle
                if self._CurrentNPC == CurrentTarget and not self._IsBattling then
                    self._PreviousNPC = self._CurrentNPC
                    self._CurrentNPC = nil
                end
            end))
        end)

        task.wait(0.5)

        local success, err = pcall(function()
            fireproximityprompt(self._CurrentNPC.PrimaryPart.Dialogue)
        end)
        if not success then
            self._CurrentNPC = nil
        end
    end

    function BaseNPCBattleStrategy:GetQuest(QuestGiver)
        if not QuestGiver or not QuestGiver.PrimaryPart then 
            return 
        end

        local QuestGiverCFrame = QuestGiver.PrimaryPart.CFrame
        if not AutofarmController:TeleportToCFrame(QuestGiverCFrame * CFrame.new(0, 2, -6)) then return end
        local VisibleTarget = NPCsFolder:WaitForChild(QuestGiver.Name, 5)
        VisibleTarget.PrimaryPart:WaitForChild("Dialogue", 5)
        fireproximityprompt(VisibleTarget.PrimaryPart.Dialogue)

        --timeout for dialogue stuck
        local connection
        local eventTriggered = false
        local timeout = 5
        connection = EventsFolder.UpdateAllQuests.OnClientEvent:Connect(function(...)
            eventTriggered = true
            connection:Disconnect() 
        end)

        pcall(function()
            self._Maid:GiveTask(connection)
        end)

        local startTime = os.clock()
        while os.clock() - startTime < timeout and not eventTriggered do
            task.wait() 
        end
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

    

    function QuestFarmStrategy:FindAvailableNPC()
        local QuestData = nil
        for name, quest_data in pairs(Stats.Quest.Data) do
            if quest_data.Type == "Daily" then continue end
            if not quest_data.Objectives then continue end
            if not quest_data.Objectives[1].Type:find("Trainer") then continue end
            
            QuestData = {}
            for i = 1, #quest_data.Objectives do
                table.insert(QuestData, {
                    Identifier = quest_data.Objectives[i].Name, 
                    Amount = quest_data.Objectives[i].Amount,
                    Progress = quest_data.Progress[i]
                })
            end
            break
        end

        if QuestData == nil then
            local quest = UIController:GetSelectedQuest()
            local questGiver = NPCsFolder:FindFirstChild(quest) or HiddenNPCsFolder:FindFirstChild(quest)
            self:GetQuest(questGiver)
            return
        end 

                   
        for _, folder in {NPCsFolder, HiddenNPCsFolder} do
            for _, npc in folder:GetChildren() do
                if not npc:GetAttribute("Cooldown") then continue end
                if self:IsNpcOnCooldown(npc) then continue end
                if npc.Name:find("^Boss") then continue end 
                if self._PreviousNPC == npc then continue end --find different target, helpful for timeed out npcs
                for _, questTrainer in QuestData do
                    if questTrainer.Progress >= questTrainer.Amount then continue end
                    local NPCLevel = npc:GetAttribute("Level")
                    if npc.Name == questTrainer.Identifier then
                        return npc
                    end
                    if NPCLevel and NPCLevel == tonumber(questTrainer.Identifier) then
                        return npc
                    end
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
                if not boss:GetAttribute("Cooldown") then continue end
                if self:IsNpcOnCooldown(boss) then continue end
                if self._PreviousNPC == boss then continue end --find different target, helpful for timeed out npcs
                if not table.find(UIController:GetTargetBossNames(), boss:GetAttribute("Name")) then continue end

                local QuestGiver = nil
                for _, folder in ipairs({NPCsFolder, HiddenNPCsFolder}) do
                    for _, npc in ipairs(folder:GetChildren()) do
                        if npc.Name:find("Boss") and npc.Name:find("Quest") then
                            QuestGiver = npc
                        end
                    end
                end
                if not QuestGiver then
                    return boss
                end

                local IsQuestExist = false
                local timeoutCount = 0
                repeat
                    for quest_name, quest_data in pairs(Stats.Quest.Data) do
                        if quest_data.Type == "Daily" then continue end
                        if not quest_data.Objectives then continue end
                        if quest_data.Objectives[1].Name == boss.Name then 
                            IsQuestExist = true
                            break
                        end
                    end

                    if not IsQuestExist then
                        if timeoutCount >= 2 then
                            break
                        end
                        timeoutCount += 1
                        self:GetQuest(QuestGiver)
                    end 
                until IsQuestExist


                return boss
            end
        end

        return nil
    end
end

-- Controller Definitions
do
    export type Item = {
        Type: string,
        Description: string,
        Id: string,
        Trait: string,
        Price: number,
        Skill: string,
        Name: string,
        Tier: string?,
        Equipped: boolean,
        Stackable: boolean,
        Favorite: boolean,
        Category: string
    }

    local ItemsToStore = {}

    function AutoTaskController:Init()
        self.TaskRunner = TaskRunner.new()
    end

    function AutoTaskController:Start()
        local CharacterMaid = Maid.new()
        
        local function OnCharacterAdded(Character)
            CharacterMaid:DoCleaning()

            Character:WaitForChild("HumanoidRootPart")
            Character:WaitForChild("Humanoid")

            CharacterMaid:GiveTask(EventsFolder.UpdateSpecificItem.OnClientEvent:Connect(function(item: Item)
                if UIController:IsAutoBankToggled() then
                    pcall(function()
                        if item.Category == "Parts" then return end
                        warn(item.Category, item.Type, item.Name)
                    end)
                    if item.Type == "Skill" then
                        if not UIController:GetAllBankState().AllFragment then return end
                    elseif item.Type == "Auras" then
                        if not UIController:GetAllBankState().AllAura then return end
                    elseif item.Type == "Crystals" then
                        if not UIController:GetAllBankState().AllCrystal then return end
                    elseif item.Type == "Enchants" then
                        if not UIController:GetAllBankState().AllEnchants then return end
                    else
                        return
                    end
                    table.insert(ItemsToStore, item.Id)
                    self:RunTask(function()
                        task.wait(1)
                        EventsFolder.DepositItems:FireServer("Bank1", ItemsToStore)
                        ItemsToStore = {}
                    end)
                end
            end))

        end

        Client.CharacterAdded:Connect(OnCharacterAdded)
        if Client.Character then
            task.spawn(OnCharacterAdded, Client.Character)
        end
    end

    function AutoTaskController:RunTask(task)
        self.TaskRunner:Run(task)
    end

    function AutoTaskController:FireServer(RemoteName, ...)
        RemotesFolder[RemoteName]:FireServer(...)
    end
end

do
    local FarmStrategyClasses = {
        CrystalFarm = CrystalFarmStrategy,
        QuestFarm = QuestFarmStrategy,
        BossFarm = BossFarmStrategy
    }
    
    function AutofarmController:Init()
        self.CurrentFarmStrategy = nil
        self.CurrentFarm = nil
        self.Crystal = nil
        self.TimeOfCrystalSpawn = nil
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

            --Noclip when farming (to avoid getting pushed away from dialogue)
            CharacterMaid:GiveTask(RunService.Stepped:Connect(function()
                for _, part in pairs(Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        if (UIController:IsBeybladeAutofarmToggled()) then
                            part.CanCollide = false
                        else
                            part.CanCollide = true
                        end
                    end
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
                    self:SwitchStrategy(UIController:GetNextFarm())
                end
            end))

            CharacterMaid:GiveTask(workspace.ChildAdded:Connect(function(child)
                --workspace["572b341d-e0d9-4c75-8ad3-1258b5fdfd53"].Root.Crystal
                local Root = child:FindFirstChild("Root")
                if Root then
                    local Crystal = Root:FindFirstChild("Crystal")
                    if Crystal then
                        print("Crystal Found!")
                        self:SwitchStrategy(UIController:GetNextFarm())
                        self.Crystal = child
                        self.TimeOfCrystalSpawn = os.clock()
                        local connection
                        connection = workspace.ChildRemoved:Connect(function(removedChild)
                            if removedChild == child then
                                self.Crystal = nil
                                self.TimeOfCrystalSpawn = nil
                                connection:Disconnect()
                            end
                        end)

                        if connection then
                            CharacterMaid:GiveTask(connection)
                        end
                    end
                end
            end))
            

            CharacterMaid:GiveTask(task.spawn(function()
                if Client:GetAttribute("InMenu") then
                    Client.PlayerGui.Menu.Enabled = not Client.PlayerGui.Menu.Enabled
                    task.wait(3)
                end

                if not UIController:IsBeybladeAutofarmToggled() then
                    self:SwitchStrategy(nil) --destroy all strategies
                    return
                end
                
                if self.CurrentFarmStrategy then
                    warn("Starting...")
                    self.CurrentFarmStrategy:Start()
                else
                    self:SwitchStrategy(UIController:GetNextFarm())
                end
            end))

            --cleanup
            CharacterMaid:GiveTask(function()
                self:SwitchStrategy(nil)
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
            -- FinishSkill, for 2nd arg I could've put any instance
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
                self.CurrentFarmStrategy:Start()
            end
        end
    end

    function AutofarmController:TeleportToCFrame(cframe)
        local Character = Client.Character
        if Character then
            local root = Character:FindFirstChild("HumanoidRootPart")
            if root then
                root.Velocity = Vector3.zero -- Stop movement instantly
                root.RotVelocity = Vector3.zero -- Stop rotation to avoid spinning
                root.CFrame = cframe
                root.Anchored = true
                task.delay(10, function()
                    root.Anchored = false
                end)
                return true
            end
        end
        return false
    end

    function AutofarmController:QueueNextStrategy(restart)
        if restart then
            self:SwitchStrategy(UIController:GetNextFarm())
        else
            self:SwitchStrategy(UIController:GetNextFarm(self.CurrentFarm))
        end
        
    end
end

do 
    local CONFIG_FOLDER_NAME: string = "TEST-CONFIG1"

    UIController.OnBeybladeAutofarmToggled = Signal.new()

    UIController.OnQuestFarmToggled = Signal.new() 
    UIController.OnBossFarmToggled = Signal.new()
    UIController.OnCrystalFarmToggled = Signal.new()

    UIController.OnCurrentFarmChanged = Signal.new()
    UIController.OnQuestChanged = Signal.new()
    UIController.OnTrainerLevelChanged = Signal.new()

    UIController.OnStaffAutoKickChanged = Signal.new()

    -- State management
    UIController.State = {
        IsAutofarmEnabled = false,
        FarmConfig = {
            Distance = 1,
            Delay = 0,
            BossDifficulty = "Easy",
            WorldBossDifficulty = "Easy"
        },
        Farms = {
            CrystalFarm = {
                Enabled = false,
                Priority = 4,
            },

            QuestFarm = {
                Enabled = false,
                Priority = 2,
                SelectedQuest = "None"
            },

            BossFarm = {
                Enabled = false,
                Priority = 3
            }
        },
        IsAutoBankEnabled = false,
        Bank = {
            AllAura = false,
            AllFragment = false,
            AllCrystal = false,
            AllEnchants = false,
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


    function UIController:IsAutoBankToggled(): boolean
        return self.State.IsAutoBankEnabled
    end

    function UIController:GetAllBankState(): boolean
        return self.State.Bank
    end
    

    function UIController:GetBossDifficulty()
        return self.State.FarmConfig.BossDifficulty
    end 

    function UIController:GetWorldBossDifficulty()
        return self.State.FarmConfig.WorldBossDifficulty
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
            Name = "Blader's Rebirth v6",
            LoadingTitle = "Loading User Interface",
            LoadingSubtitle = "Script Credits: OnlineCat",
    
            ConfigurationSaving = {
                Enabled = true,
                FolderName = CONFIG_FOLDER_NAME
            },
            
            KeySystem = false
        })

        UIController:_CreateFarmTab(Window)
        UIController:_CreateRollTab(Window)
        UIController:_CreateAutoTab(Window)
        UIController:_CreateConfigTab(Window)
        UIController:_CreateMiscTab(Window)
        Rayfield:LoadConfiguration()
    end

    function UIController:_CreateConfigTab(Window)
        local Tab = Window:CreateTab("Config", 4483362458)
        
        Tab:CreateSection("Farm Settings")
        Tab:CreateSlider({
            Name = "Distance to Target",
            Range = {1, 80},
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

        local BossDifficultyList = {"Easy", "Normal", "Hard", "Impossible"} 

        Tab:CreateDropdown({
            Name = "Select Boss Difficulty",
            Options = BossDifficultyList,
            CurrentOption = {"Easy"},
            Flag = "BossDifficulty",
            Callback = function(selected)
                self.State.FarmConfig.BossDifficulty = selected[1]
            end
        })

        Tab:CreateDropdown({
            Name = "Select World Boss Difficulty",
            Options = BossDifficultyList,
            CurrentOption = {"Easy"},
            Flag = "WorldBossDifficulty",
            Callback = function(selected)
                self.State.FarmConfig.WorldBossDifficulty = selected[1]
            end
        })
    end

    function UIController:_CreateAutoTab(Window)
        if not ItemIndex then return end

        local AuraFolder = ItemIndex.Auras.Items

        local Tab = Window:CreateTab("Auto", 4483362458)

        Tab:CreateSection("Banking")
        Tab:CreateToggle({
            Name = "Auto Bank Items",
            CurrentValue = false,
            Flag = "AutoBankToggle",
            Callback = function(Value)
                UIController.State.IsAutoBankEnabled = Value
            end
        })

        Tab:CreateToggle({
            Name = "Bank ALL Auras",
            CurrentValue = false,
            Flag = "AllBankAuraToggle",
            Callback = function(Value) 
                UIController.State.Bank.AllAura = Value
            end
        })

        Tab:CreateToggle({
            Name = "Bank ALL Fragments",
            CurrentValue = false,
            Flag = "AllBankFragmentsToggle",
            Callback = function(Value) 
                UIController.State.Bank.AllFragment = Value
            end
        })

        Tab:CreateToggle({
            Name = "Bank ALL Crystals",
            CurrentValue = false,
            Flag = "AllBankCrystalToggle",
            Callback = function(Value) 
                UIController.State.Bank.AllCrystal = Value
            end
        })

        Tab:CreateToggle({
            Name = "Bank ALL Enchants",
            CurrentValue = false,
            Flag = "AllBankEnchantsToggle",
            Callback = function(Value) 
                UIController.State.Bank.AllEnchants = Value
            end
        })

        local AuraList = {}
        for _, aura in pairs(AuraFolder:GetChildren()) do
            if aura:IsA("Frame") then
                table.insert(AuraList, aura.Name)
            end
        end
        Tab:CreateDropdown({
            Name = "Auras",
            Options = AuraList,
            CurrentOption = {},
            Flag = "AurasToBank",
            MultipleOptions = true,
            Callback = function() end
        })
    end

    function UIController:_CreateRollTab(Window)
        local Tab = Window:CreateTab("Roll", 4483362458)

        local traitWhiteList = {
            Rare = true,
            Uncommon = true,
            Common = true,
            Traitless = true,
            Legendary = true
        }
        local autoVendingEnabled = false
        local autoBlackmarketEnabled = false
        local rollDelay = 500

        -- Store and disable connections
        local oldConnections = {}
        for _, conn in pairs(getconnections(EventsFolder.RunCaseAnimation.OnClientEvent)) do
            table.insert(oldConnections, conn.Function) -- Save the function
        end


        Tab:CreateSection("Roll")

        -- Get vending machine names
        local vendingOptions = {"Cygnus and Dransword"}
        for _, machine in pairs(VendingMachinesFolder:GetChildren()) do
            if machine.Name:find("and") and not table.find(vendingOptions, machine.Name) then
                table.insert(vendingOptions, machine.Name)
            end
        end
        local SelectedMachine = vendingOptions[1] or "None"

        -- Dropdown for selecting vending machine
        Tab:CreateDropdown({
            Name = "Select Vending Machine",
            Options = vendingOptions,
            Flag = "SelectedVendingMachine",
            Callback = function(selected)
                SelectedMachine = selected[1]
            end
        })

        Tab:CreateToggle({
            Name = "Skip Gacha Animation",
            CurrentValue = false,
            Flag = "SkipGacha",
            Callback = function(Value)
                if Value then
                    for _, conn in pairs(getconnections(EventsFolder.RunCaseAnimation.OnClientEvent)) do
                        conn:Disable()
                    end
                else
                    for _, func in pairs(oldConnections) do
                        EventsFolder.RunCaseAnimation.OnClientEvent:Connect(func) 
                    end
                end
            end
        })

        Tab:CreateSlider({
            Name = "Roll Delay",
            Range = {0.02, 2.0},
            Increment = 0.02,
            CurrentValue = 0.5,
            Flag = "RollDelay",
            Callback = function(Value)
                rollDelay = Value
            end
        })

        Tab:CreateToggle({
            Name = "Auto Vending Machine",
            CurrentValue = false,
            Flag = "AutoVending",
            Callback = function(Value)
                autoVendingEnabled = Value
                
                task.spawn(function()
                    while autoVendingEnabled do
                        local TraitWhiteList = {}
                        -- Add selected traits to whitelist
                        for trait, enabled in pairs(traitWhiteList) do
                            if enabled then
                                table.insert(TraitWhiteList, trait)
                            end
                        end

                        EventsFolder.PurchaseItem:InvokeServer(SelectedMachine, {TraitWhiteList = TraitWhiteList})
                        task.wait(rollDelay)
                    end
                end)
            end
        })

        Tab:CreateToggle({
            Name = "Auto Blackmarket",
            CurrentValue = false,
            Flag = "AutoBlackmarket",
            Callback = function(Value)
                autoBlackmarketEnabled = Value
                task.spawn(function()
                    while autoBlackmarketEnabled do
                        EventsFolder.BuyBlackmarket:InvokeServer()
                        task.wait(rollDelay)
                    end
                end)
            end
        })

        Tab:CreateButton({
            Name = "Spin BlackMarket",
            Callback = function()
                EventsFolder.BuyBlackmarket:InvokeServer()
            end
        })

        Tab:CreateButton({
            Name = "Show BlackMarket",
            Callback = function()
                Client.PlayerGui.UI.Menu.Blackmarket.Visible = not Client.PlayerGui.UI.Menu.Blackmarket.Visible 
            end
        })

        Tab:CreateSection("Filter")
        for trait, _ in pairs(traitWhiteList) do
            Tab:CreateToggle({
                Name = "Destroy " .. trait,
                CurrentValue = true,
                Flag = trait .. "Filter",
                Callback = function(Value)
                    traitWhiteList[trait] = Value
                end
            })
        end

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
            Name = "Teleport to other world",
            Callback = function()
                if (workspace.World.Portals:FindFirstChild("DellancyTown")) then
                    AutofarmController:TeleportToCFrame(workspace.World.Portals.Volcano.PrimaryPart.CFrame)
                else
                    AutofarmController:TeleportToCFrame(workspace.World.Portals.Adventure.PrimaryPart.CFrame)
                end
                task.wait(0.2)
                EventsFolder.SendPortalRequest:FireServer(true)
            end,
        })

        Tab:CreateButton({
            Name = "Show Bank",
            Callback = function()
                local remote = EventsFolder.ShowBank
                if remote then
                    for _, connection in ipairs(getconnections(remote.OnClientEvent)) do
                        connection.Function("Bank1", "BankPart")
                    end
                end
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
        
        pcall(function()
            table.sort(QuestList, function(a, b)
                return tonumber(a:match("%d+")) < tonumber(b:match("%d+"))
            end)
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
	
        local BossList = {"Volt", "Shin", "Ryuke", "Jinka", "Cupid"}
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


        -- Crystal Autofarm Section
        Tab:CreateSection("Auto Crystal Collect")
        Tab:CreateToggle({
            Name = "Collect Crystals",
            CurrentValue = false,
            Flag = "CrystalAutofarmToggle",
            Callback = function(State)
                self:SetFarmState("CrystalFarm", State)
                self.OnCrystalFarmToggled:Fire(State)
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
            local SERVER_LIST_URL = "https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=100"
            local success, result = pcall(function()
                return HttpService:GetAsync(SERVER_LIST_URL)
            end)

            local isTeleporting = false 
        
            if success then
                local serverData = HttpService:JSONDecode(result)
                for _, server in ipairs(serverData.data) do
                    if server.id ~= game.JobId and server.playing < server.maxPlayers then
                        isTeleporting = true
                        TeleportService.TeleportInitFailed:Connect(function(...)
                            Client:Kick("Failed attempt to teleport due to staff!" .. MessageContent)
                        end)
                        TeleportService:TeleportToPlaceInstance(PLACE_ID, server.id, Players.LocalPlayer)
                        return
                    end
                end
            end

            if not isTeleporting then
                Client:Kick("Kicked from game due to staff being in the same server! " .. MessageContent)
            end
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
    AutoTaskController:Init()
    MiscController:Init()

    UIController:Start()
    AutofarmController:Start()
    AutoTaskController:Start()
    MiscController:Start()
end

LoadControllers()