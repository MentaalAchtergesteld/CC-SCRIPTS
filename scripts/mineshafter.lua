local args = {...}

local version = "0.0.1";

local function help()
    print(string.format("Welcome to MineShafter V%s!", version));
    print("Here's how to use this program:");
    print("");
    print("This program digs 5 high, 3 wide tunnels downwards.");
    print("After 15 blocks, it'll dig a 5 long 4 high platform");
    print("Make sure to place the turtle in the bottom center of the place where you want the shaft.");
    print("Usage:");
    print("mineshafter <amountOfLevels> | help");
end

local tunnelWidth = 3;
local tunnelHeight = 5;
local platformWidth = 3;
local platformHeight = 4;
local platformLength = 5;
local platformInterval = 15;

local digDirection = {
    front = turtle.dig,
    up = turtle.digUp,
    down = turtle.digDown
}

local inspectDirection = {
    front = turtle.inspect,
    up = turtle.inspectUp,
    down = turtle.inspectDown
}

local Direction = {
    front = "front",
    up = "up",
    down = "down"
}

local function forceDig(direction)
    if not Direction[direction] then return false end
    while inspectDirection[direction]() do
        digDirection[direction]();
    end

    return true;
end

local function refuel()
    local oldSelectedSlot = turtle.getSelectedSlot();
    for i = 1, 16, 1 do
        turtle.select(i);
        turtle.refuel();
    end
    turtle.select(oldSelectedSlot);
end

local function checkForFuel(amountOfLevels)
    local amountOfShaftSlices = platformInterval*amountOfLevels;
    local amountToMovePerLevel = tunnelHeight*2-1;
    local totalToMoveForShaft = amountToMovePerLevel * amountOfShaftSlices;

    local amountToMoveForPlatform = (platformHeight-1)*platformLength;
    local totalToMoveForPlatforms = amountToMoveForPlatform * amountOfLevels;

    local totalToMoveUpShaft = amountOfShaftSlices*2;
    local totalToMoveUpPlatforms = platformLength*amountOfLevels;

    local totalFuelUsage = 
        totalToMoveForShaft + 
        totalToMoveForPlatforms + 
        totalToMoveUpShaft + 
        totalToMoveUpPlatforms;

    if turtle.getFuelLevel() < totalFuelUsage then
        refuel();
    end

    if turtle.getFuelLevel() < totalFuelUsage then
        return false, totalFuelUsage;
    end

    return true;
end

local function mineShaftSlice()
    for i = 1, tunnelHeight-2, 1 do
        turtle.up();
    end

    forceDig(Direction.front);
    turtle.forward();

    turtle.turnLeft();
    forceDig(Direction.front);
    turtle.turnRight();
    turtle.turnRight();
    forceDig(Direction.front);
    turtle.turnLeft();

    for i = 1, tunnelHeight-1, 1 do
        forceDig(Direction.down);
        turtle.down();
        turtle.turnLeft();
        forceDig(Direction.front);
        turtle.turnRight();
        turtle.turnRight();
        forceDig(Direction.front);
        turtle.turnLeft();
    end
end

local function minePlatformSlice(i)
    forceDig(Direction.front);
    turtle.forward();
    for j = 1, platformHeight-1 do
        turtle.turnLeft();
        forceDig(Direction.front);
        turtle.turnRight();
        turtle.turnRight();
        forceDig(Direction.front);
        turtle.turnLeft();
        if i % 2 == 0 then
            forceDig(Direction.down);
            turtle.down();
        else
            forceDig(Direction.up);
            turtle.up();
        end
    end
    turtle.turnLeft();
    forceDig(Direction.front);
    turtle.turnRight();
    turtle.turnRight();
    forceDig(Direction.front);
    turtle.turnLeft();
end

local function minePlatform()
    local i = 0;

    for i = 1, platformLength, 1 do
        minePlatformSlice(i);
    end

    for i = 1, platformHeight-1, 1 do
        turtle.down();
    end
end


local function mineshafter(amountOfLevels)
    local hasEnoughFuel, requiredAmount = checkForFuel(amountOfLevels);
    if not hasEnoughFuel then
        print("Not enough fuel, please feed me UwU.")
        print("Required amount: "..requiredAmount);
        return false;
    end

    for i = 1, amountOfLevels, 1 do
        for i = 1, platformInterval, 1 do
            mineShaftSlice();
        end

        minePlatform();
    end

    print("Done!");
end

local function main()
    if #args ~= 1 or not (tonumber(args[1]) ~= nil or args[1] == "help") then
        print("Correct usage:")
        print("mineshafter <amountOfLevels> | help")
    end

    if args[1] == "help" then
        help()
    else
        mineshafter(args[1])
    end
end

main();