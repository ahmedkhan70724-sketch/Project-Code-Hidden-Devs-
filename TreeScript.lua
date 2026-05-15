--# Project-Code-Hidden-Devs-
-- Scripter : 590BILL

-- Services/
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local DataStoreService = game:GetService("DataStoreService")

--Data Store For The Player's Data
local PlayerData = DataStoreService:GetDataStore("PlayerData")

--Modules
local InventoryModule = require(game.ReplicatedStorage.Modules:WaitForChild("Inventory"))
local TreeRewards  = require(ReplicatedStorage.Modules:WaitForChild("Rewards"))
local CollisionService = require(ReplicatedStorage.Modules:WaitForChild("CollisionService")) --  Collision Groups
local ToolsService = require(ReplicatedStorage.Modules:WaitForChild("ToolsService"))

--Remotes/
local treeChopRemote = ReplicatedStorage.Remotes:FindFirstChild("ChopEvent")
--//
local rewardsData , resourcesData = TreeRewards.SetUp()
local Plots = workspace:FindFirstChild("Plots")
local treemodelContainer = ReplicatedStorage:FindFirstChild("TreesModels") 
local TreeFolder = workspace:FindFirstChild("Trees")
local folderTrees = TreeFolder:GetChildren()
-- Security Layer
local _Axesdata = {
	["Wooden Axe"] = {
		Name = "Wooden Axe",
		Price = "Free" ,
		Damage = 10
	} ,["Stone Axe"] = {
		Name = "Stone Axe",
		Price = 200 ,
		Damage = 20
	} ,["Iron Axe"] = {
		Name = "Iron Axe",
		Price = 500 ,
		Damage = 30
	} ,["Chainsaw"] = {
		Name = "Chainsaw",
		Price = 1000 ,
		Damage = 50
	} 
	
	
}
-- Data Table
local PlrDataManager = {}
local AttributeConnections = {}

function PlrDataManager:Load(plr:Player , dataTemplate)
	local success , data = pcall(function()
		return PlayerData:GetAsync(plr.UserId)
	end)

	if success and data then
		print("Successfully Loaded Data For "..":"..plr.Name)
		self[plr.UserId] = data
		ToolsService:Setuptools(plr , data.ToolsBought)
	    InventoryModule:LoadPlrInventory(plr , data.Inventory)
		
	else
		print("Failed To Load Data For:.."..":"..plr.Name)	
		--/
		self[plr.UserId] = dataTemplate

	end 
		self[plr.UserId].SessionLock = game.JobId
		self[plr.UserId].SessionLockTime = os.time()
end

-- Save data 
function PlrDataManager:Update(plr:Player)

	local tries = 0
	while tries < 3  do
		tries += 1
		if self[plr.UserId].SessionLock and self[plr.UserId].SessionLock ~= game.JobId and os.time() - (self[plr.UserId].SessionLockTime or 0 )  < 120  then
			return 
		end
		local  success , data = pcall(function()
			PlayerData:UpdateAsync(plr.UserId , function(oldData)  -- Merge The Player's Saved Data
				
				oldData = oldData or {}

				oldData.Money = self[plr.UserId].Money
				oldData.Exp   = self[plr.UserId].Exp
				oldData.ToolsBought = ToolsService:FindPlrData(plr)
				oldData.Inventory = InventoryModule:ReturnPlrInventory(plr)
				
				return oldData
			end)
		end)


		if success then
			print(plr.Name.."'s".."Data Has Been Succesfully Saved")
            break
		else
			print("Failed To Load Data For".." : "..plr.Name)
			task.wait(1)
		end	
	end
end

function PlrDataManager:Save(plr:Player)

	pcall(function()

		PlayerData:UpdateAsync(plr.UserId , function(oldData)
             oldData = oldData or {}
			
			oldData.Money = self[plr.UserId].Money
			oldData.Exp = self[plr.UserId].Exp
			oldData.ToolsBought = ToolsService:FindPlrData(plr)
			oldData.Inventory = InventoryModule:ReturnPlrInventory(plr)
			oldData.SessionLock = nil
			oldData.SessionLockTime = nil

			return oldData
		end)

	end)


end


local function Tweentree(tree:Model) 

   for _No , ModelParts in ipairs(tree:GetChildren()) do -- Play Chop Effect// 
			if ModelParts:IsA("BasePart") then		
				local HitEffect = TweenService:Create(ModelParts ,  TweenInfo.new(0.1 , Enum.EasingStyle.Linear , Enum.EasingDirection.Out , 0 , true  ) , {CFrame = ModelParts.CFrame * CFrame.new(0 ,-2.5 , 0)})
				HitEffect:Play()

			end

	end 
end

local function SetAttributes(plr:Player)
	
	AttributeConnections[plr.UserId] = {}
	for _ , data in pairs(PlrDataManager[plr.UserId]) do
		if type(data) ~= "table" then
			continue 
		end
		
		if not data.Value or type(data.Value) ~= "number" then
			continue
		end
		
		plr:SetAttribute(data.Name , data.Value)
		
		table.insert(AttributeConnections[plr.UserId] , plr:GetAttributeChangedSignal(data.Name):Connect(function()
			data.Value = plr:GetAttribute(data.Name)
		end))
	end
	
end


-- Set Up The Inventory And Add The Tools 
local function SetupPlayer(plr:Player , NoOfSlots)
	--//
	SetAttributes(plr)

end



Players.PlayerRemoving:Connect(function(plr)
	PlrDataManager:Save(plr) -- Save The Data
   
	for _ , connections in ipairs(AttributeConnections[plr.UserId]) do
		connections:Disconnect()
	end 
	
	AttributeConnections[plr.UserId] = nil
	PlrDataManager[plr.UserId] = nil
end)



Players.PlayerAdded:Connect(function(plr)  -- Set Up The Inventory and The Data Frame	
	-- Load The Data
	PlrDataManager:Load(plr , {

		Money = {Name = "Money", Value = 1000},

		Exp   = {Name = "Exp", Value = 0} ,

		ToolsBought = ToolsService:CreateTemplate(plr) ,

        Inventory = InventoryModule:SetUp(plr)
	}  
) 
	SetupPlayer(plr)

	-- Give The Saved Tools
	ToolsService:GiveTools(plr)
	
	local Character = plr.Character or plr.CharacterAdded:Wait()
	if Character  then
		CollisionService:SetModelGroup(Character , "Player")
		InventoryModule:Refresh(plr)
	end


end)
-- Set Up The Reward And The Wood It Will Drop By Getting The Tree's Name
local function GiveResources( treeModel:Model, plr:Player )	
	
	if rewardsData[treeModel.Name] then  
       local selectionChance = math.random(1 , 50)

		-- Loop Through Table To Find The Tree Reward Table Using Model's Name
		for _ , rewards in ipairs(rewardsData[treeModel.Name]) do 
		
		if selectionChance <= rewards.Chance  then -- See if It Gets Selected
			
			InventoryModule:AddItem(plr , rewards)
		
			break
		end
			
		end
	end

	InventoryModule:AddItem(plr, resourcesData[treeModel:GetAttribute("Wood")])-- Insert The Wood 
end	
 
 -- Play  The Tree Disappearance Animation
local function PlayTransparencyEffect(Tree:Model)
	local Cooldown = 1
	for _ , treeparts in ipairs(Tree:GetDescendants())  do

		if treeparts:IsA("IntValue") or treeparts:IsA("StringValue") or treeparts:IsA("WeldConstraint")  then continue end
		local Effect = TweenService:Create(treeparts , TweenInfo.new(Cooldown , Enum.EasingStyle.Sine , Enum.EasingDirection.Out , 0 , false) , {Transparency = 1})
		Effect:Play()

	end

end

-- Respawn The Tree  And Set It Up
local function RespawnTree(oldTree:Model) 
    task.wait(05)
	local treeClone:Model =  treemodelContainer:FindFirstChild(oldTree.Name):Clone()
	treeClone.Parent = workspace.Trees
	CollectionService:AddTag(treeClone , "Tree")

	local pivot = oldTree:GetAttribute("LastPivot")
	treeClone:PivotTo(pivot)
	treeClone:SetAttribute("LastPivot" , treeClone:GetPivot())   

	Debris:AddItem(oldTree , 5)
end

local function DistanceCheck(tree:Model , plr:Player , distance)
	if not plr.Character then 
		return false
	end
	if (tree.PrimaryPart.Position - plr.Character.PrimaryPart.Position).Magnitude <= distance then
		return true
	else 
		return false
	end
 
end

local function DestroyTree(tree, plr)
	
	CollectionService:RemoveTag(tree , "Tree") -- Cant Hit The Tree To Stop The Duplication Of Rewards

	GiveResources(tree , plr)

	for _ , parts in ipairs(tree:GetChildren()) do
		if parts:IsA("BasePart") then
			parts.Anchored = false
			parts.CanCollide = true
		elseif  parts:IsA("IntValue") or parts.Name == "Decor"  then
			parts:Destroy()	
		end

	end
	
	PlayTransparencyEffect(tree) -- Play Fading Effect //
	RespawnTree(tree) -- Respawn Tree//..

end

treeChopRemote.OnServerEvent:Connect(function(plr , treeModel:Model , AxeName:string)-- The Result Of The Raycast (Tree) And The Axe That It Was Chopped Down With  

	 local ServeraxeData = _Axesdata[AxeName]
	 
	 if not ServeraxeData
	
	or ServeraxeData.Name ~= "Wooden Axe" and not table.find(PlrDataManager[plr.UserId].ToolsBought , AxeName)   
	
	or not  treeModel 
		or not treeModel:IsDescendantOf(TreeFolder) 
		or not CollectionService:HasTag(treeModel , "Tree") 
		or type(AxeName) ~= "string"  then return end

       
	-- Check The Player's Inventory To See If There Is Space
	if not InventoryModule:HasSpace(plr) then
	    return
	end
	if  not DistanceCheck(treeModel , plr , 15) then return end
	
	local Health =  treeModel:GetAttribute("Health")-ServeraxeData.Damage -- Get The Attribute
	treeModel:SetAttribute("Health" , Health)
	
	if Health <= 0   then  
		DestroyTree(treeModel , plr)
       return
	end	
 
    Tweentree(treeModel)

end)


-- Spawn The Trees On The  Plots
local function SetupTrees() 
	local x = 5 
	local z = 5					
	local PlotIndex = 1 -- Current index Of Tree Zone  That Is Being Set
	local Count = 0
	local treeTemplate  
	
	
	-- Loop To Select The Current Tree Model Of The Trees Folder
	for _ , TreeModel in ipairs(treemodelContainer:GetChildren()) do 
		local Plot = Plots:WaitForChild("Plot"..PlotIndex)-- The Currrent Plot/Zone (Plot1 , Plot2 .etc)

		folderTrees[PlotIndex] = TreeModel
		treeTemplate = folderTrees[PlotIndex]

		PlotIndex += 1	  -- Increment The no
        
		for Xside = -x , x  do -- Spawn trees in a  Square formation
			if Count % 25 then
				task.wait()
				Count = 0
			end

			for Zside = -z , z  do
				local treeTemplateClone:Model = treeTemplate:Clone()

				treeTemplateClone.Parent = workspace.Trees 
				local space_between_trees = 10 
				treeTemplateClone:PivotTo(Plot.CFrame * CFrame.new(Xside * space_between_trees , Plot.Size.Y + treeTemplateClone.PrimaryPart.Size.Y/2 , Zside * space_between_trees) )  

				treeTemplateClone:SetAttribute("LastPivot" , treeTemplateClone:GetPivot()) -- Store The Pivot For The Next Respawned Tree's Positioning
				CollectionService:AddTag(treeTemplateClone , "Tree")               
			end
		end	
		Count += 1
	end




end

SetupTrees()

game:BindToClose(function()
	for  _ , plr in ipairs(Players:GetPlayers()) do
		PlrDataManager:Save(plr)
	end
end)


-- AutoSave Player's Data
task.spawn(function()
	
	while true do 
		task.wait(35)
			for _ , player in ipairs(Players:GetPlayers()) do
				PlrDataManager:Update(player)
			end
		
	end
end)

-- Concept Map 
-- Player Spawns In And Is Given A Inventory And Data Frame //  Data Loaded If They Have Played It Before
-- Spawn Trees In Each Zone 
-- Player Gets Rewards
-- . Tree Wood
-- . A Random Reward By Chance
-- Tree is Reseted After A Little Time
-- AutoSave Every 35 Seconds
-- Save Data When Leaving
--//-
