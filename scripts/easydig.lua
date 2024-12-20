local args = {...};

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

local StartPosition = {
    top = "top",
    bottom = "bottom"
}

local fluids = {
    "minecraft:water",
    "minecraft:lava"
}

function table:contains(value, recursive)
    recursive = recursive or false
    for key, table_value in pairs(self) do
        if recursive and type(table_value) == "table" then
            local contains = table.contains(table_value, value);
            if contains then return true end
        end

        if table_value == value then
            return true;
        end
    end

    return false;
end

local function printHelp()
    print("USAGE: dig <width> <height> <depth> [startPosition (top | bottom)]");

    print("DESCRIPTION:");
    print(" - <width> The width of the area to dig.");
    print(" - <height> The height of the area to dig.");
    print(" - <depth> The depth of the area to dig.");
    print(" - [startPosition] Optional. Specificy wether this turtle is at the top or bottom of the defined area, defaults to top.");
end

local function calculateFuelUsage(width, height, depth)
    local totalFuelUsage = 0;
    
    local area = width * depth;
    local volume = area * height;
    totalFuelUsage = totalFuelUsage + volume;

    if area%2 ~= 0 then
        totalFuelUsage = totalFuelUsage + height;
        totalFuelUsage = totalFuelUsage + width;
    end

    totalFuelUsage = totalFuelUsage + depth;

    return totalFuelUsage;
end

local function tryRefuelling(requiredFuelAmount)
    local oldSelectedSlot = turtle.getSelectedSlot();

    for i=1, 16 do
        turtle.select(i);
        turtle.refuel();
        if turtle.getFuelLevel() >= requiredFuelAmount then
            turtle.select(oldSelectedSlot);
            return;
        end
    end

    turtle.select(oldSelectedSlot);
end

local function forceDig(direction)
    if not Direction[direction] then return false end

    local hasBlock, data = inspectDirection[direction]();

    while hasBlock do
        digDirection[direction]();

        hasBlock, data = inspectDirection[direction]();

        if hasBlock and table.contains(fluids, data.name) then
            return true;
        end
    end

    return true;
end

local function dig(width, height, depth, startPosition)
    local positionString = "bottom";
    if startPosition == StartPosition.top then
        positionString = "top";
    end
    print("Alright, digging an area of size " .. width .. ", " .. height .. ", " .. depth .. " starting at the " .. positionString .. ".");

    local totalColumnCounter = 0;

    if startPosition == StartPosition.top then
        totalColumnCounter = totalColumnCounter + 1;
    end

    for z=0, depth-1 do
        forceDig(Direction.front)
        turtle.forward();

        if z%2 == 0 then
            turtle.turnRight();
        else
            turtle.turnLeft();
        end

        for x=0, width-1 do            
            for y=0, height-2 do
                if totalColumnCounter%2 == 0 then
                    forceDig(Direction.up)
                    turtle.up();
                else
                    forceDig(Direction.down)
                    turtle.down();
                end
            end

            if x < width-1 then
                forceDig(Direction.front)
                turtle.forward();
            end

            totalColumnCounter = totalColumnCounter + 1;
        end

        if z%2 == 0 then
            turtle.turnLeft();
        else
            turtle.turnRight();
        end
    end
    
    print("Finished digging!");
end

local function returnHome(width, height, depth, startPosition)
    print("Returning home.");
    local area = width * depth;

    if area%2 ~= 0 then
        for i=0, height-1 do
            if startPosition == StartPosition.bottom then
                turtle.down();
            else
                turtle.up();
            end
        end

        turtle.turnLeft();
        for i = 0, width-1 do
            turtle.forward();
        end
    else
        turtle.turnLeft();
    end

    turtle.turnLeft();
    for i = 0, depth-1 do
        turtle.forward();
    end

    turtle.turnRight();
    turtle.turnRight();

    print("Returned home!");
end

local function main()
    if args[1] == "help" then
        printHelp();
        return;
    end

    if #args < 3 then
        printHelp();
        return;
    end

    local width = tonumber(args[1]);
    local height = tonumber(args[2]);
    local depth = tonumber(args[3]);

    if not (width and height and depth) then
        printHelp();
        return;
    end

    local startPosition = StartPosition.bottom;

    if #args >= 4 then
        local startPositionArg = args[4];

        if startPositionArg == "top" then
            startPosition = StartPosition.top;
        elseif startPositionArg == "bottom" then
            startPosition = StartPosition.bottom
        else
            printHelp();
            return;
        end
    end

    local requiredFuelAmount = calculateFuelUsage(width, height, depth);
    if requiredFuelAmount > turtle.getFuelLimit() then
        print("More fuel required than limit allows, quitting program.");
        return;
    end

    while turtle.getFuelLevel() < requiredFuelAmount do
        print("Not enough fuel, i need " .. requiredFuelAmount .. " but only have " .. turtle.getFuelLevel());
        print("Try refuelling? (y/n)");
        local doRefuel = read();

        if doRefuel == "n" then
            print("Not refuelling, quitting program.");
            return;
        elseif doRefuel == "y" then
            tryRefuelling(requiredFuelAmount);
        end
    end

    dig(width, height, depth, startPosition);
    returnHome(width, height, depth, startPosition);
end

main();