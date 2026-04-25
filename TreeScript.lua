--# Project-Code-Hidden-Devs-
-- Scripter : 590BILL

-- Services/
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

--Modules
local Inventory = require(game.ReplicatedStorage.Modules.Inventory)
local TreeRewards  = require(ReplicatedStorage.Modules.Rewards)

--Remotes/
local ChopEvent = ReplicatedStorage.Remotes.ChopEvent
local InventoryEvent = ReplicatedStorage.Remotes.InventoryEvent
local CashEvent = ReplicatedStorage.Remotes.CashEvent
local InfoEvent = ReplicatedStorage.Remotes.InfoEvent

local Rewards , Resources = TreeRewards.SetUp()

local Plots = workspace:FindFirstChild("Plots")
local TreeModels = ReplicatedStorage.TreesModels
local TreeFile:Folder = workspace.Trees	
local TreeModelsChildren = TreeModels:GetChildren()
local CurrInventory
local FileChildren = TreeFile:GetChildren()

--Data Sets/
local TreesData = {	
	TreeStats = {}
}

local PlrData = {}

-- Check If The Player Can Hit The Tree 
local CanHit = {} 

-- Check If The Player Can Store Items In Their Respective Inventory
local CanStoreItem = {}

-- Store The Tree Model's Pivot For Correct Position Of The Respawned Tree
local Pivots ={} 

local function SetUpPlayer(plr:Player , NoOfSlots)
	local plrinventory = Inventory.SetUp(plr) -- Players's Inventory
	PlrData[plr.UserId] = {
		Money = {Name = "Money", Value = 1000},
		Exp   = {Name = "Exp", Value = 0}
	} 
	
	--//
	local MoneyValue = Instance.new("IntValue",  plr)
	MoneyValue.Name = "MoneyValue"
    MoneyValue.Value = PlrData[plr.UserId].Money.Value
	--//
	
	plrinventory = Inventory.AddSlots( NoOfSlots , plrinventory , plr)  -- Set Up The Inventory
	
	InventoryEvent:FireClient(plr , plrinventory) -- Tell Client To Update The Inventory
	
	CashEvent:FireClient(plr , PlrData[plr.UserId] , MoneyValue) -- Set The Cash Display
	
	MoneyValue:GetPropertyChangedSignal("Value"):Connect(function()
		CashEvent:FireClient(plr , PlrData[plr.UserId] , MoneyValue) -- Update The Cash Display
	end)

end


local function SetupCharacter(char)
	for i , v in ipairs(char:GetChildren()) do -- Set The Collison Group Of The Player's BodyParts So It Doesnt Collide With The Tree
			if v:IsA("BasePart") then
				v.CollisionGroup = "Player"
			end
	 end  
end

local InventorySlots = 20 -- No of Slots
Players.PlayerAdded:Connect(function(plr)  -- Set Up The Inventory and The Data Frame	
	SetUpPlayer(plr , InventorySlots)
   
   plr.CharacterAdded:Connect(function(char)
	   CashEvent:FireClient(plr , PlrData[plr.UserId])
	  
	  SetupCharacter(char , plr)
		
   end)
	
end)
-- Set Up The Reward And The Wood It Will Drop By Getting The Tree's Name
local function SetupTreeRewards( TemplateClone )	
			
				local RandomizeRewards = {}
				
				RandomizeRewards[TemplateClone.Name] = {} -- Make A Table For The Rewards Of The Trees  i.e RandomizeRewards["BirchTree"] = {Spirit Seed = {} , Golden Leaf = {}} , RandomizeRewards["BasicTree"] = {Speical Resin = { }}
				
				
			if Rewards[TemplateClone.Name] then  
				
				-- Loop Through Table To Find The Tree Reward Table Using Model's Name
				for _ , rewards in ipairs(Rewards[TemplateClone.Name]) do 
					
					table.insert(RandomizeRewards[TemplateClone.Name] , rewards)	
				end
					 
                local __Random = math.random(1 , #RandomizeRewards[TemplateClone.Name]) -- Get A Random Number Within The Number Of Tables
				local selectionChance = math.random(1 , 100)
				
				local selected = RandomizeRewards[TemplateClone.Name][__Random] -- Select The Reward
					
					if selectionChance <= selected.Chance  then -- See if It Gets Selected
						table.insert(TreesData[TemplateClone].PerTreeReward , selected)-- Insert In The Trees Rewards Table
					end
			end
				
			
	table.insert(TreesData[TemplateClone].PerTreeReward, Resources[TreesData[TemplateClone].TreeStats.Wood])-- Insert The Wood 
end	

  -- Collision Groups 
 PhysicsService:RegisterCollisionGroup("Tree")
 PhysicsService:RegisterCollisionGroup("OtherStuff")
 PhysicsService:RegisterCollisionGroup("Player")

-- Set The Collisions
PhysicsService:CollisionGroupSetCollidable("Tree" , "OtherStuff", true)
PhysicsService:CollisionGroupSetCollidable("Tree",  "Player" , false)


local function SetUpTreeStats(Tree) -- Set Up The Trees Stats And Store The Tree Model's Stats With Its Instance And Store The Items In A Different Table
			TreesData[Tree] = {
				
		TreeStats = {	
			Name = TreesData[Tree.Name].Name ;
			Health = TreesData[Tree.Name].Health      ;
			Wood = TreesData[Tree.Name].Wood
		} , 
		PerTreeReward = {}		
	}
end
--//
--    //Get The Tree Models In The Folder And Sets It Collision Group  And Its Stats
for _ , Tree in ipairs(ReplicatedStorage.TreesModels:GetChildren()) do 
	for i , v in ipairs(Tree:GetChildren()) do
		
		if v:IsA("Part") then
			
			v.CollisionGroup = "Tree"
			
		end
	end
	
	TreesData[Tree.Name] = {
		Name = Tree.Name ;
		Health = Tree.Health.Value;
		Wood = Tree.WoodName.Value;
	}
end

-- Store The Values Of The Tree
local function Store_Inventory_Values(Tree , Inventory , plr) 
	
	-- Loop Through The Rewards That Tree Is Assigned With
	for key , val in ipairs(TreesData[Tree].PerTreeReward) do 
	   -- Loop Through The Inventory And Making Sure That Data Isn't OverWritten
	   for Index = 1 , #Inventory   do 
					
			if  Inventory[Index] and Inventory[Index].Item == "" then
			 
			 CanStoreItem[plr] = true
             Inventory[Index].Item = val
			 break
			end			
        end
	end	
	print(Inventory)
 InventoryEvent:FireClient(plr , Inventory)	-- Fire To The Client to Update The Inventory UI	
	
end

local function PlayTransparencyEffect(TreeArg:Model) -- Play  The Tree Hit Animation
	local Cooldown = 1
	for _ , treeparts in ipairs(TreeArg:GetDescendants())  do
			
			if treeparts:IsA("IntValue") or treeparts:IsA("StringValue") then continue end
			local Effect = TweenService:Create(treeparts , TweenInfo.new(Cooldown , Enum.EasingStyle.Sine , Enum.EasingDirection.Out , 0 , false) , {Transparency = 1})
			Effect:Play()
		
	end
	
end
-- Respawn The Tree  And Set It To The Pivot in Pivots
local function RespawnTree(Old:Model) 
	local RespawnTime = 5
	
	  task.wait(RespawnTime)

	   local Clone:Model =  TreeModels:FindFirstChild(Old.Name):Clone()
	   Clone.Parent = workspace.Trees
	   local pivot = Pivots[Old]
	   Clone:PivotTo(pivot)
	  Pivots[Clone] = Clone:GetPivot()
	 CanHit[Clone] = true
	SetUpTreeStats(Clone)
	   SetupTreeRewards(Clone)
	
	 Pivots[Old]= nil
	 CanHit[Old] = nil
	TreesData[Old] = nil
	Old:Destroy()
	
	 
end


ChopEvent.OnServerEvent:Connect(function(plr , Result_Model:Model , Curraxe)-- The Result Of The Raycast (Tree) And The Axe That It Was Chopped Down With  
   if not  Result_Model or not CanHit[Result_Model]  then return end	 
   local PlrInventory  = Inventory.ReturnPlrInventory(plr) 	

 CanStoreItem[plr] = false
 
 -- Check The Player's Inventory To See If There Is Space
   for p , Slots in ipairs(PlrInventory) do 
	    if Slots.Item == "" then
	     CanStoreItem[plr] = true
	     break
	    end 
    end

if not CanStoreItem[plr] then 
		InfoEvent:FireClient(plr , "Inventory Is Full !") 
	return
end


TreesData[Result_Model].TreeStats.Health-= Curraxe.Damage 
	
	local Health =  TreesData[Result_Model].TreeStats.Health -- Store The Health After Subtracting It  

if Health < 0   then  

CanHit[Result_Model] = false  -- Cant Hit The Tree To Stop The Duplication Of Rewards

Store_Inventory_Values(Result_Model , PlrInventory , plr) 

   for _ , parts in ipairs(Result_Model:GetChildren()) do
		if parts:IsA("BasePart") then
			parts.Anchored = false
			parts.CanCollide = true
		elseif parts:IsA("WeldConstraint") or parts:IsA("IntValue") or parts.Name == "Decor"  then
			parts:Destroy()
			
		end
		
		
   end
       PlayTransparencyEffect(Result_Model) -- Play Fading Effect //
      RespawnTree(Result_Model) -- Respawn Tree//..
	 
    
end	

for _No , ModelParts in ipairs(Result_Model:GetChildren()) do -- Play Tree Hit Effect// 
   if Health >= 0 then
		if ModelParts:IsA("BasePart") then		
	
		local HitEffect = TweenService:Create(ModelParts ,  TweenInfo.new(0.1 , Enum.EasingStyle.Linear , Enum.EasingDirection.Out , 0 , true  ) , {CFrame = ModelParts.CFrame * CFrame.new(0 ,-2.5 , 0)})
		HitEffect:Play()
			
			
		end
	
	end
 end 
	print(PlrInventory)
end)

-- Spawn The Trees On The  Plots
local function SetUpTrees() 
 local x = 5 
 local z = 5					
 local no = 1 -- Current No Of Tree Zone  That Is Being Set
	local TreeTemplate  
   -- Loop To Select The Current Tree Model Of The Trees Folder
   for _ , TreeModel in ipairs(TreeModels:GetChildren()) do 
		local Plot = Plots:WaitForChild("Plot"..no)-- The Currrent Plot/Zone (Plot1 , Plot2 .etc)
	   
	    FileChildren[no] = TreeModel
		TreeTemplate = FileChildren[no]
		
		no += 1	  -- Increment The no
	 
	 for Xside = -x , x  do -- Spawn trees in a  Square formation
	     task.wait(0.2)
	
	        for Zside = -z , z  do
		     local Template:Model = TreeTemplate:Clone()
	
		     Template.Parent = workspace.Trees 
		     local space_between_trees = 10 
		     Template:PivotTo(Plot.CFrame * CFrame.new(Xside * space_between_trees , Plot.Size.Y + Template.PrimaryPart.Size.Y/2 , Zside * space_between_trees) )  
				
				Pivots[Template] = Template:GetPivot()
				CanHit[Template] = true
				
			  SetUpTreeStats(Template)
		      SetupTreeRewards(Template) 
              
	        end
	    end	
    end
end

SetUpTrees()


-- Concept Map 
-- Player Spawns In And Is Given A Inventory And Data Frame 
-- Spawn Trees In Each Zone 
-- Player Gets Listed Items  By Chopping Down Trees
  -- . Tree Wood
  -- . A Random Reward By Chance
-- Tree is Reseted After A Little Time

--//-
