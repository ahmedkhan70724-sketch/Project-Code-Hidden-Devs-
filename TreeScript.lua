--# Project-Code-Hidden-Devs-
-- Scripter : 590BILL

-- Services/
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local DataStoreService = game:GetService("DataStoreService")

--Data Store For The Player's Data
local PlayerData = DataStoreService:GetDataStore("PlayerData")

--Modules
local InventoryModule = require(game.ReplicatedStorage.Modules.Inventory)
local TreeRewards  = require(ReplicatedStorage.Modules.Rewards)

--Remotes/
local treeChopRemote = ReplicatedStorage.Remotes:WaitForChild("ChopEvent")
local inventoryRemote = ReplicatedStorage.Remotes:WaitForChild("InventoryEvent")
local cashRemote = ReplicatedStorage.Remotes:WaitForChild("CashEvent")
local infoRemote = ReplicatedStorage.Remotes:WaitForChild("InfoEvent")

local rewardsData , resourcesData = TreeRewards.SetUp()
local Plots = workspace:FindFirstChild("Plots")
local treemodelContainer = ReplicatedStorage:FindFirstChild("TreesModels") 
local TreeFolder = workspace:FindFirstChild("Trees")
local folderTrees = TreeFolder:GetChildren()

--Data Sets/
-- The Rewards Of Tree
local rewardsPerTree = {}

local PlrDataManager = {} 

-- Check If The Player Can Store Items In Their Respective Inventory
local InventoryHasSpace = {}

-- Collision Groups 

PhysicsService:RegisterCollisionGroup("Tree")
PhysicsService:RegisterCollisionGroup("OtherStuff")
PhysicsService:RegisterCollisionGroup("Player")

-- Set The Collisions
PhysicsService:CollisionGroupSetCollidable("Tree" , "OtherStuff", true)
PhysicsService:CollisionGroupSetCollidable("Tree",  "Player" , false)

-- Load The Saved Data And Init A New If No Saved Data
function PlrDataManager:Load(plr:Player)
	local InventorySlots = 20
	local sucess , data = pcall(function()
		return PlayerData:GetAsync(plr.UserId)
	end)

	if sucess and data then
		print("Successfully Loaded Data For "..":"..plr.Name)
		self[plr.UserId] = data		

	else
		print("Failed To Load Data For:.."..":"..plr.Name)	
		--/
		self[plr.UserId] = {
			Money = {Name = "Money", Value = 1000},

			Exp   = {Name = "Exp", Value = 0} ,

			ToolsBought = {} -- Store The Bought Tools 
		} 
	end 

end


-- Give The Saved/Bought Tools To The Player
function PlrDataManager:GiveTools(plr:Player)
	if not self[plr.UserId].ToolsBought then return end
	print("Init")

	for i , v  in ipairs(self[plr.UserId].ToolsBought) do
		
		if not v then continue end
		local Tool  = ReplicatedStorage.AxesFolder:FindFirstChild(v)
		if not Tool then continue end
		local StarterGear_Clone = Tool:Clone()
		local Backpack_Clone =  Tool:Clone()
       
		Backpack_Clone.Parent = plr.Backpack
		StarterGear_Clone.Parent = plr.StarterGear
	end
end


-- Save data 
function PlrDataManager:Save(plr:Player)

	local tries = 0
	
	
	
		
	while tries < 3  do
		local  success , data = pcall(function()
			PlayerData:UpdateAsync(plr.UserId , function(oldData)  -- Merge The Player's Saved Data
              tries += 1
			  oldData = oldData or {}

			  oldData.Money = self[plr.UserId].Money
			  oldData.Exp   = self[plr.UserId].Exp
			  oldData.ToolsBought = self[plr.UserId].ToolsBought

			 return oldData
		end)
		    end)
		
	
		if success then
	    	print(plr.Name.."'s".."Data Has Been Succesfully Saved")
		  
	    else
		 print("Failed To Load Data For".." : "..plr.Name)
	    end	
	 	
		
	end
	
tries = 0

end


local function SetUpCharacter(Char:Model) 
	for i , v in ipairs(Char:GetChildren()) do
		if v:IsA("BasePart") then
			v.CollisionGroup = "Player"
		end
	end
end

-- Set Up The Inventory And Add The Tools 
local function SetupPlayer(plr:Player , NoOfSlots)

	local plrInventory = InventoryModule.SetUp(plr , NoOfSlots )
	plrInventory  = InventoryModule.AddSlots(NoOfSlots , plrInventory , plr)	
	--//
	local MoneyValue = Instance.new("IntValue",  plr)
	MoneyValue.Name = "MoneyValue"
	MoneyValue.Value = PlrDataManager[plr.UserId].Money.Value
	--//

	plr.Backpack.ChildAdded:Connect(function(tool:Tool)

		if tool.Name == "Wooden Axe" then return end
		if table.find(PlrDataManager[plr.UserId].ToolsBought , tool.Name) then return end

		table.insert(PlrDataManager[plr.UserId].ToolsBought , tool.Name)
	end)


	cashRemote:FireClient(plr , PlrDataManager[plr.UserId] , MoneyValue) -- Set The Cash Display

	MoneyValue:GetPropertyChangedSignal("Value"):Connect(function()

		PlrDataManager[plr.UserId].Money.Value = MoneyValue.Value -- Update To It For Data Saving Purposes
		cashRemote:FireClient(plr , PlrDataManager[plr.UserId] , MoneyValue) -- Update The Cash Display

	end)

end



Players.PlayerRemoving:Connect(function(plr)
	PlrDataManager:Save(plr) -- Save The Data
    PlrDataManager[plr.UserId] = nil
end)

local InventorySlots = 20

Players.PlayerAdded:Connect(function(plr)  -- Set Up The Inventory and The Data Frame	
	local plrInventory = InventoryModule.ReturnPlrInventory(plr)
	-- Load The Data
	PlrDataManager:Load(plr) 

	SetupPlayer(plr , InventorySlots)

	-- Give The Saved Tools
	PlrDataManager:GiveTools(plr)

	local Character = plr.Character or plr.CharacterAdded:Wait()
	if Character  then
		SetUpCharacter(Character)
		cashRemote:FireClient(plr , PlrDataManager[plr.UserId])
		inventoryRemote:FireClient(plr , plrInventory)  
	end





end)
-- Set Up The Reward And The Wood It Will Drop By Getting The Tree's Name
local function SetuptreeRewards( treeModel:Model )	

	local RandomizeRewards = {}

	RandomizeRewards[treeModel.Name] = {} -- Make A Table For The Rewards Of The Trees  i.e RandomizeRewards["BirchTree"] = {Spirit Seed = {} , Golden Leaf = {}} , RandomizeRewards["BasicTree"] = {Speical Resin = { }}
	rewardsPerTree[treeModel] = {}

	if rewardsData[treeModel.Name] then  

		-- Loop Through Table To Find The Tree Reward Table Using Model's Name
		for _ , rewards in ipairs(rewardsData[treeModel.Name]) do 

			table.insert(RandomizeRewards[treeModel.Name] , rewards)	
		end

		local __Random = math.random(1 , #RandomizeRewards[treeModel.Name]) -- Get A Random Number Within The Number Of Tables
		local selectionChance = math.random(1 , 100)

		local selected = RandomizeRewards[treeModel.Name][__Random] -- Select The Reward

		if selectionChance <= selected.Chance  then -- See if It Gets Selected
			table.insert(rewardsPerTree[treeModel] , selected)-- Insert In The Trees Rewards Table
		end
	end


	table.insert(rewardsPerTree[treeModel], resourcesData[treeModel:GetAttribute("Wood")])-- Insert The Wood 
end	


--//
--    //Get The Tree Models In The Folder And Sets It Collision Group  And Its Attributes
for _ , Tree in ipairs(ReplicatedStorage.TreesModels:GetChildren()) do 
	for i , v in ipairs(Tree:GetDescendants()) do

		if v:IsA("BasePart") then

			v.CollisionGroup = "Tree"
			v.CanQuery = true
		end
	end

	Tree:SetAttribute("Health", Tree.Health.Value)
	Tree:SetAttribute("Wood" , Tree.WoodName.Value)


end

-- Store The Values Of The Tree
local function Store_Inventory_Values(Tree , Inventory , plr) 

	-- Loop Through The Rewards That Tree Is Assigned With
	for key , value in ipairs(rewardsPerTree[Tree]) do 

		-- Loop Through The Inventory And Making Sure That Data Isn't OverWritten

		for slots = 1 , #Inventory   do 

			if   Inventory[slots].Item == "" then

				InventoryHasSpace[plr] = true
				Inventory[slots].Item = value
				break
			end			
		end
	end	
	print()
	inventoryRemote:FireClient(plr , Inventory)	-- Fire To The Client to Update The Inventory UI	

end

local function PlayTransparencyEffect(Tree:Model) -- Play  The Tree Disappearance Animation
	local Cooldown = 1
	for _ , treeparts in ipairs(Tree:GetDescendants())  do

		if treeparts:IsA("IntValue") or treeparts:IsA("StringValue") then continue end
		local Effect = TweenService:Create(treeparts , TweenInfo.new(Cooldown , Enum.EasingStyle.Sine , Enum.EasingDirection.Out , 0 , false) , {Transparency = 1})
		Effect:Play()

	end

end
-- Respawn The Tree  And Set It Up
local function RespawnTree(oldTree:Model) 
    task.wait(05)
	local treeClone:Model =  treemodelContainer:FindFirstChild(oldTree.Name):Clone()
	treeClone.Parent = workspace.Trees
	CollectionService:AddTag(treeClone , "CanHit")
	SetuptreeRewards(treeClone)

	local pivot = oldTree:GetAttribute("LastPivot")
	treeClone:PivotTo(pivot)
	treeClone:SetAttribute("LastPivot" , treeClone:GetPivot())   

	Debris:AddItem(oldTree , 5)
end


treeChopRemote.OnServerEvent:Connect(function(plr , treeModel:Model , AxeData)-- The Result Of The Raycast (Tree) And The Axe That It Was Chopped Down With  
	if not  treeModel 
		or not treeModel:IsDescendantOf(TreeFolder) 
		or not CollectionService:HasTag(treeModel , "CanHit") 
		or type(AxeData) ~= "table" then return end


	local PlrInventory  = InventoryModule.ReturnPlrInventory(plr) 	
	InventoryHasSpace[plr] = false

	-- Check The Player's Inventory To See If There Is Space
	for _ , inventorySlots in ipairs(PlrInventory) do 

		if inventorySlots.Item == "" then

			InventoryHasSpace[plr] = true

			break

		end 
	end

	if not InventoryHasSpace[plr] then 
		infoRemote:FireClient(plr , "Inventory Is Full !") 
		return
	end


	local Health =  treeModel:GetAttribute("Health") -- Get The Attribute
	treeModel:SetAttribute("Health" , Health-AxeData.Damage)
	if Health <= 0   then  

		CollectionService:RemoveTag(treeModel , "CanHit") -- Cant Hit The Tree To Stop The Duplication Of Rewards

		Store_Inventory_Values(treeModel , PlrInventory , plr) 

		for _ , parts in ipairs(treeModel:GetChildren()) do
			if parts:IsA("BasePart") then
				parts.Anchored = false
				parts.CanCollide = true
			elseif  parts:IsA("IntValue") or parts.Name == "Decor"  then
				parts:Destroy()	
			end


		end
		PlayTransparencyEffect(treeModel) -- Play Fading Effect //
		RespawnTree(treeModel) -- Respawn Tree//..


	end	

	for _No , ModelParts in ipairs(treeModel:GetChildren()) do -- Play Chop Effect// 
		if Health > 0 then
			if ModelParts:IsA("BasePart") then		
				local HitEffect = TweenService:Create(ModelParts ,  TweenInfo.new(0.1 , Enum.EasingStyle.Linear , Enum.EasingDirection.Out , 0 , true  ) , {CFrame = ModelParts.CFrame * CFrame.new(0 ,-2.5 , 0)})
				HitEffect:Play()

			end

		end
	end 
	print(PlrInventory)

end)

-- Spawn The Trees On The  Plots
local function SetupTrees() 
	local x = 5 
	local z = 5					
	local PlotIndex = 1 -- Current index Of Tree Zone  That Is Being Set
	local treeTemplate  
	
	folderTrees = TreeFolder:GetChildren()
	-- Loop To Select The Current Tree Model Of The Trees Folder
	for _ , TreeModel in ipairs(treemodelContainer:GetChildren()) do 
		local Plot = Plots:WaitForChild("Plot"..PlotIndex)-- The Currrent Plot/Zone (Plot1 , Plot2 .etc)

		folderTrees[PlotIndex] = TreeModel
		treeTemplate = folderTrees[PlotIndex]

		PlotIndex += 1	  -- Increment The no

		for Xside = -x , x  do -- Spawn trees in a  Square formation
			task.wait(0.2)

			for Zside = -z , z  do
				local treeTemplateClone:Model = treeTemplate:Clone()

				treeTemplateClone.Parent = workspace.Trees 
				local space_between_trees = 10 
				treeTemplateClone:PivotTo(Plot.CFrame * CFrame.new(Xside * space_between_trees , Plot.Size.Y + treeTemplateClone.PrimaryPart.Size.Y/2 , Zside * space_between_trees) )  

				treeTemplateClone:SetAttribute("LastPivot" , treeTemplateClone:GetPivot()) -- Store The Pivot For The Next Respawned Tree's Positioning
				SetuptreeRewards(treeTemplateClone) 
				CollectionService:AddTag(treeTemplateClone , "CanHit")               
			end
		end	
	end





end




SetupTrees()

-- AutoSave Player's Data
task.spawn(function()
	
	while true do 
		task.wait(35)
			for _ , player in ipairs(Players:GetPlayers()) do
				PlrDataManager:Save(player)
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
--//--- Set Up The Inventory And Add The Tools
