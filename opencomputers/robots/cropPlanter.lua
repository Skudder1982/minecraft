--[[

Remarks
=======

  a) The robot recognizes only water blocks (assumes irrigation instead of using them to progress to next crop)
  b) The robot "harvests" all blocks in a crop row, so don't place any blocks on crop level (e.g. sprinkler, etc.)

TODOs
=====

  -) drop-off location for excess items
  b) detect if hoe is missing or broken
  c) handle durability of hoe
  d) support level changes (e.g. underground storage)
  e) handle empty inventories (use inventory_controller.getInventorySize() instead of robot.suck to detect inventories)
  f) implement excessInventory.firstInventory (requires e)
  g) implement excessInventory.lastInventory (requires e)
  h) Seaweed cannot be planted (or a robot cannot place blocks on water - neither place(), placeDown(), use() or useDown())
  
--]]

local excessInventory = {
  [0] = "belowInventories",--[[
  [1] = "firstInventory",
  [2] = "lastInventory",--]]
  
  belowInventories = 0--[[,
  firstInventory = 1,
  lastInventory = 2--]]
}

local robot = require("robot");
local sides = require("sides");

local maxHeight = 3;
local maxCropGap = 5;
local maxRowGap = 3;
local direction = sides.right;
local handleExcess = excessInventory.belowInventories;



--- Moves the robot down until it hits the floor.
function moveToFloor()
  while robot.down() do end
end



--- Moves the robot count blocks upwards
-- @return true if the robot moved count blocks upwards; otherwise false
function moveUp(count)
  if (count > 0) then
    for i = 1, count do
      if not robot.up() then return false;
      end
    end
  end
  
  return true;
end


--- Causes the robot to suck items from the inventories in front.
-- It tries to move upwards until it can't find any more inventories. Once
-- finished it moves back to the original position.
-- @return The number of inventories sucked from
function suckCrops()
  robot.select(1);
  local level = 1;
  while robot.suck() do
    print(string.format("Inventory found at level %d - sucked %d items", level, robot.count()));
    
    if (robot.up()) then
      level = level + 1;
    end
    
    robot.select(robot.select() + 1);
  end
  
  for i = 1, level do
    robot.down();
  end
  
  return robot.select() - 1;
end



--- Causes the robot to try to find the first adjacent inventory.
-- First it tries to find an inventory in any adjacent horizontal block. If
-- it can't find one, it moves upwards and repeats to search. If it finds one
-- in front of it, it stays in that position. Once it hits
-- maxHeight without finding an inventory, it stops to search and moves 
-- to the original position.
-- @see maxHeight
-- @return A pair of <found, level>. Returns true for found if it could
-- find an inventory; otherwise false. Returns the number of blocks
-- upwards from the original position if it could find an inventory;
-- otherwise nil
function findFirstInventory()
  robot.select(1);
  moveToFloor();
  
  local found = robot.suck();
  local level = 0;
  
  if not found then
    repeat
      local turns = 0;
      
      repeat
        robot.turnLeft();
        found = robot.suck();
        turns = turns + 1;
      until found or turns > 3
      
      if not found then
        robot.up();
        level = level + 1;
      end
     until found or level > maxHeight;
  end
  
  if found then
    robot.drop();
  else
    moveToFloor();
    level = nil;
  end
  
  return found, level;
end



function runCropRow()
  robot.select(1);
  print("Scanning for first inventory");
  local inventoryFound, inventoryLevel = findFirstInventory();

  if (inventoryFound) then
    print("Found inventory");
    local inventories = suckCrops();
    print(string.format("Found %d inventories (starting from level %d)", inventories, inventoryLevel));
    
    robot.up();
    robot.turnAround();

    print("Beginning plant loop");
    robot.select(1);
    local moved = plantCrops(inventories);
    
    print("Moving back to inventories");
    moveBackToInventory(moved);
    
    moveToFloor();
    moveUp(inventoryLevel);
    print("Storing items");
    storeItems(inventories);
    storeExcessItems();
  else
    print("No inventories found!");
  end
  
  return inventoryFound;
end


--- Causes the robot to try to find whether a solid or a liquid block is 
--- underneath.
-- The robot moves down until it can detect a solid or liquid block directly
-- underneath, and moves back to its original position once it found one.
-- @return True if a liquid block was found underneath; otherwise false
function detectWater()
  local moved = 0;
  local blocked = false;
  local liquidFound = false;
  
  while not blocked and not liquidFound do
    blocked, blockType = robot.detectDown()

    liquidFound = blockType == "liquid";
    
    if blocked or liquidFound then
      for i = 1, moved do
        robot.up();
        end
      return liquidFound;
    end
    
    robot.down();
    moved = moved + 1;
  end
end



function plantCrops(inventories)
  local cropsPlanted = 0;
  local planting = false;
  local stop = false;
  local moved = 0;
  local gap = 0;
  
  repeat
    -- harvest
    robot.swingDown();
    
    -- plant or till & plant
    if robot.placeDown() or (robot.useDown() and robot.placeDown()) then
      cropsPlanted = cropsPlanted + 1;
      
      -- enter planting state
      if not planting then
        planting = true;
        gap = 0;
        print(string.format("Entering planting mode (slot %d)", robot.select()))
      end
    else
      if planting then
        if detectWater() then
          print("Water detected - skipping block");
        else
          planting = false;
          print(string.format("Planted %d crops from slot %d", cropsPlanted, robot.select()));
          
          -- reset crop counter
          cropsPlanted = 0;
        
          -- select next slot (if applicable)
          if robot.select() < inventories then
            robot.select(robot.select() + 1);
          else
            stop = true;
          end
        end
      end
      
      gap = gap + 1;
      if gap >= maxCropGap then
        stop = true;
      end
    end

    if not stop then
      robot.forward();
      moved = moved + 1;
    end
  until stop;
  
  return moved;
end


--- Causes the robot to turn around and move blocksMoved blocks back (to its
--- inventory).
-- @param blocksMoved Distances to the inventory
function moveBackToInventory(blocksMoved)
  robot.turnAround();
  
  while blocksMoved > 0 do
    robot.forward();
    blocksMoved = blocksMoved - 1;
  end
end



function storeItems(inventories)
  robot.select(1);
  
  for i = 1, inventories do
    robot.drop();
    if i < inventories then
      robot.up();
      robot.select(robot.select() + 1);
    end
  end
  
  moveToFloor();
end



function storeExcessItems()
  local items = 0;
  
  -- strategy excessInventory.belowInventories
  if handleExcess == excessInventory.belowInventories then
    for i = 3,16 do
      robot.select(i);
      items = items + robot.count();
      robot.dropDown();
    end
  end
  
  print(string.format("Dropped %d excess items", items));
end



function runCropRows()
  local found = false;
  local moved = 0;
  local gap = 0;
  local rows = 0;
  
  print("Planting crop rows");
  repeat
    found = runCropRow();
    
    if found then
      gap = 0;
      rows = rows + 1;
      if direction == sides.right then
        robot.turnRight();
      else
        robot.turnLeft();
      end
    else
      gap = gap + 1;
    end
    
    robot.forward();
    moved = moved + 1;
  until gap >= maxRowGap;

  print(string.format("Planted %d crop rows", rows));
  
  -- return to start
  robot.turnAround();
  for i = 1,moved do
    robot.forward();
  end
  
end

runCropRows();