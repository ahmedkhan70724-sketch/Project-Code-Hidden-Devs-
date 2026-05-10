--# Project-Code-Hidden-Devs-
-- Scripter : 590BILL

-- Services/
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")



--Modules

local InventoryModule = require(game.ReplicatedStorage.Modules:WaitForChild("Inventory"))
local TreeRewards  = require(ReplicatedStorage.Modules:WaitForChild("Rewards"))
local CollisionService = require(ReplicatedStorage.Modules:WaitForChild("CollisionService"))
local PlrDataManager = require(ReplicatedStorage.Modules:WaitForChild("PlrDataManager"))



--Remotes/
local treeChopRemote = ReplicatedStorage.Remotes:WaitForChild("ChopEvent")

local rewardsData , resourcesData = TreeRewards.SetUp()
local Plots = workspace:FindFirstChild("Plots")
local treemodelContainer = ReplicatedStorage:FindFirstChild("TreesModels") 
local TreeFolder = workspace:FindFirstChild("Trees")
local folderTrees = TreeFolder:GetChildren()


local _Axesdata = {
	"Wooden Axe",
	
	"Stone Axe",
	
	"Iron Axe",
	
	"Chainsaw"
}

local function IndicatetreeDamage(tree:Model) 
   
   for _No , ModelParts in ipairs(tree:GetChildren()) do -- Play Chop Effect// 
			if ModelParts:IsA("BasePart") then		
				local HitEffect = TweenService:Create(ModelParts ,  TweenInfo.new(0.1 , Enum.EasingStyle.Linear , Enum.EasingDirection.Out , 0 , true  ) , {CFrame = ModelParts.CFrame * CFrame.new(0 ,-2.5 , 0)})
				HitEffect:Play()

			end

	end 
end


local function SetAttributes(plr:Player)
	for _ , data in PlrDataManager[plr.UserId] do
		if type(data.Value) ~= "number"  then continue end
		
		plr:SetAttribute(data.Name , data.Value)
		
		plr:GetAttributeChangedSignal(data.Name):Connect(function()
			data.Value = plr:GetAttribute(data.Name)
			print(data)
		end)
		
	end
	
end


-- Set Up The Inventory And Add The Tools 
local function SetupPlayer(plr:Player , NoOfSlots)
	
	 
	local plrInventory = InventoryModule.SetUp(plr , NoOfSlots )
	plrInventory  = InventoryModule.AddSlots(NoOfSlots , plrInventory , plr)	
	--//
	SetAttributes(plr)


end



Players.PlayerRemoving:Connect(function(plr)
	PlrDataManager:Save(plr) -- Save The Data
    PlrDataManager[plr.UserId] = nil
end)

local InventorySlots = 15

Players.PlayerAdded:Connect(function(plr)  -- Set Up The Inventory and The Data Frame	
	-- Load The Data
	PlrDataManager:Load(plr , {

		Money = {Name = "Money", Value = 1000},

		Exp   = {Name = "Exp", Value = 0} ,

		ToolsBought = {}  
	}  
) 
	SetupPlayer(plr , InventorySlots)

	-- Give The Saved Tools
	PlrDataManager:GiveTools(plr)
	
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

treeChopRemote.OnServerEvent:Connect(function(plr , treeModel:Model , AxeData)-- The Result Of The Raycast (Tree) And The Axe That It Was Chopped Down With  
	
	if not  treeModel 
		or not treeModel:IsDescendantOf(TreeFolder) 
		or not CollectionService:HasTag(treeModel , "Tree") 
		or type(AxeData) ~= "table" 
		or not table.find(_Axesdata , AxeData.Name) then return end

	-- Check The Player's Inventory To See If There Is Space
	if not InventoryModule:HasSpace(plr) then
	    return
	end
	if  not DistanceCheck(treeModel , plr , 15) then return end
	
	local Health =  treeModel:GetAttribute("Health") -- Get The Attribute
	treeModel:SetAttribute("Health" , Health-AxeData.Damage)
	
	if Health <= 10   then  
		DestroyTree(treeModel , plr)
       return
	end	
 
    IndicatetreeDamage(treeModel)

end)




-- Spawn The Trees On The  Plots
local function SetupTrees() 
	local x = 5 
	local z = 5					
	local PlotIndex = 1 -- Current index Of Tree Zone  That Is Being Set
	local treeTemplate  
	
	
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
				CollectionService:AddTag(treeTemplateClone , "Tree")               
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
