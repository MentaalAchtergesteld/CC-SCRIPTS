local DIRECTIONS = {
    north = 0,
    east = 1,
    south = 2,
    west = 3
};

local DIRECTION_DELTAS = {
    [DIRECTIONS.north] = { x = 0, y = 0, z = -1 },
    [DIRECTIONS.east] = { x = 1, y = 0, z = 0 },
    [DIRECTIONS.south] = { x = 0, y = 0, z = 1 },
    [DIRECTIONS.west] = { x = -1, y = 0, z = 0 },
    up = { x = 0, y = 1, z = 0 },
    down = { x = 0, y = -1, z = 0 }
};

local RELATIVE_DELTAS = {
    forward = { x = 0, y = 0, z = -1 },
    back = { x = 0, y = 0, z = 1 },
    left = { x = -1, y = 0, z = 0 },
    right = { x = 1, y = 0, z = 0 },
    up = { x = 0, y = 1, z = 0 },
    down = { x = 0, y = -1, z = 0 },
}

local MOVE_DIRECTIONS = {
    forward = 0,
    back = 1,
    up = 2,
    down = 3
}

local TURN_DIRECTIONS = {
    right = 0,
    left = 1,
}

local DIRECTION = DIRECTIONS.north;
local POSITION = {
    x = 0,
    y = 0,
    z = 0,
};

local function getPosition()
    return POSITION;
end

local function getDirection()
    return DIRECTION;
end

local function applyDirectionDelta(delta)
    if delta == nil or delta == RELATIVE_DELTAS.up or delta == RELATIVE_DELTAS.down then
        return delta
    end

    -- Copy the delta to avoid mutation
    local rotatedDelta = { x = delta.x, y = delta.y, z = delta.z }

    -- Apply 90° rotations based on DIRECTION
    for _ = 1, DIRECTION do
        rotatedDelta = {
            x = -rotatedDelta.z, -- Rotating clockwise
            y = rotatedDelta.y,
            z = rotatedDelta.x,
        }
    end

    return rotatedDelta
end

local function applyPositionDelta(delta)
    return {
        x = POSITION.x + delta.x,
        y = POSITION.y + delta.y,
        z = POSITION.z + delta.z
    }
end

local function isPositionAdjacent(position)
    local dx = math.abs(position.x - POSITION.x);
    local dy = math.abs(position.y - POSITION.y);
    local dz = math.abs(position.z - POSITION.z);

    return (dx + dy + dz) == 1
end

local function syncWithGPS()
    local x, y, z = gps.locate();

    if not x then
        return false, false;
    end

    POSITION.x = x;
    POSITION.y = y;
    POSITION.z = z;

    if turtle.getFuelLevel() < 2 then
        return true, false;
    end

    local turnCount = 0;
    local couldMove = false;
    
    for i=1, 4 do
        couldMove = turtle.forward();
        if couldMove then
            break;
        end
        turtle.turnRight();
        turnCount = turnCount + 1;
    end

    if not couldMove then
        return true, false;
    end

    local new_x, new_y, new_z = gps.locate();

    if new_x and new_z then
        local dx = new_x - x;
        local dz = new_z - z;

        if dx == 1 then
            DIRECTION = DIRECTIONS.east;
        elseif dx == -1 then
            DIRECTION = DIRECTIONS.west;
        elseif dz == 1 then
            DIRECTION = DIRECTIONS.south;
        elseif dz == -1 then
            DIRECTION = DIRECTIONS.north;
        end
    else
        return true, false;
    end

    turtle.back();

    for i=1, turnCount do
        turtle.turnLeft();
    end

    return true, true;
end

local function move(direction)
    if direction == MOVE_DIRECTIONS.forward then
        local couldMove, error = turtle.forward();
        if not couldMove then
            return false, error
        end
        
        POSITION = applyPositionDelta(DIRECTION_DELTAS[DIRECTION]);
    elseif direction == MOVE_DIRECTIONS.back then
        local couldMove, error = turtle.back();
        if not couldMove then
            return false, error
        end
        
        POSITION = applyPositionDelta(DIRECTION_DELTAS[(DIRECTION + 2)%4]);
    elseif direction == MOVE_DIRECTIONS.up then
        local couldMove, error = turtle.up();
        if not couldMove then
            return false, error
        end

        POSITION = applyPositionDelta(DIRECTION_DELTAS.up);
    elseif direction == MOVE_DIRECTIONS.down then
        local couldMove, error = turtle.down();
        if not couldMove then
            return false, error
        end
        
        POSITION = applyPositionDelta(DIRECTION_DELTAS.down);
    else
        return false, "Invalid direction.";
    end

    return true;
end

local function forceMove(direction)
    if turtle.getFuelLevel() == 0 then
        return false, "Not enough fuel.";
    end

    if direction == nil then
        return false, "Invalid direction."
    end

    while not move(direction) do
        if direction == MOVE_DIRECTIONS.forward then
            turtle.dig();
        elseif direction == MOVE_DIRECTIONS.up then
            turtle.digUp();
        elseif direction == MOVE_DIRECTIONS.down then
            turtle.digDown();
        end
    end
end

local function forward() move(MOVE_DIRECTIONS.forward) end
local function back() move(MOVE_DIRECTIONS.back) end
local function up() move(MOVE_DIRECTIONS.forward) end
local function down() move(MOVE_DIRECTIONS.down) end

local function forceForward() forceMove(MOVE_DIRECTIONS.forward) end
local function forceUp() forceMove(MOVE_DIRECTIONS.up) end
local function forceDown() forceMove(MOVE_DIRECTIONS.down) end

local function turn(amount, direction)
    for _ = 1, amount do
        if direction == TURN_DIRECTIONS.left then
            turtle.turnLeft();
            DIRECTION = (DIRECTION - 1 + 4) % 4;
        elseif direction == TURN_DIRECTIONS.right then
            turtle.turnRight();
            DIRECTION = (DIRECTION + 1) % 4;
        end

    end
end

local function turnTo(direction)
    local clockwiseTurns = (direction - DIRECTION + 4) % 4;
    local counterClockwiseTurns = (DIRECTION - direction + 4) % 4;

    if clockwiseTurns <= counterClockwiseTurns then
        turn(math.abs(clockwiseTurns), TURN_DIRECTIONS.right);
    else
        turn(counterClockwiseTurns, TURN_DIRECTIONS.left);
    end
end

local function turnLeft() turn(1, TURN_DIRECTIONS.left) end
local function turnRight() turn(1, TURN_DIRECTIONS.right) end

local function hasEnoughFuel(minimumFuelLevel)
    return turtle.getFuelLevel() >= minimumFuelLevel;
end

local function moveTo(target)
    local dx = target.x - POSITION.x;
    local dy = target.y - POSITION.y;
    local dz = target.z - POSITION.z;

    if not hasEnoughFuel(math.abs(dx) + math.abs(dy) + math.abs(dz)) then
        return false, "Not enough fuel.";
    end

    if dx > 0 then
        turnTo(DIRECTIONS.east);
    elseif dx < 0 then
        turnTo(DIRECTIONS.west);
    end

    for i=1, math.abs(dx) do
        forceForward();
    end

    if dz > 0 then
        turnTo(DIRECTIONS.south);
    elseif dz < 0 then
        turnTo(DIRECTIONS.north)
    end

    for i=1, math.abs(dz) do
        forceForward();
    end

    for i=1, math.abs(dy) do
        if dy > 0 then
            forceUp();
        else
            forceDown();
        end
    end

    return true;
end

local function inspectSurroundings()
    local surroundings = {};
    
    local hasBlock, data = turtle.inspect();
    surroundings["forward"] = {
        hasBlock = hasBlock,
        data = data
    };

    local hasBlock, data = turtle.inspectUp();
    surroundings["up"] = {
        hasBlock = hasBlock,
        data = data
    };

    local hasBlock, data = turtle.inspectDown();
    surroundings["down"] = {
        hasBlock = hasBlock,
        data = data
    };

    turtle.turnLeft();
    local hasBlock, data = turtle.inspect();
    surroundings["left"] = {
        hasBlock = hasBlock,
        data = data
    };
    turtle.turnRight();


    turtle.turnRight();
    local hasBlock, data = turtle.inspect();
    surroundings["right"] = {
        hasBlock = hasBlock,
        data = data
    };
    turtle.turnLeft();

    return surroundings;
end

local function hasItem(itemName)
    for i=1, 16 do
        local itemDetail = turtle.getItemDetail(i);

        if itemDetail and itemDetail.name == itemName then
            return true;
        end
    end

    return false;
end

local function getItemCount(itemName)
    local count = 0;
    for i=1, 16 do
        local itemDetail = turtle.getItemDetail(i);

        if itemDetail and itemDetail.name == itemName then
            count = count + turtle.getItemCount(i);            
        end
    end

    return count;
end

local function findItem(itemName)
    for i=1, 16 do
        local itemDetail = turtle.getItemDetail(i);

        if itemDetail and itemDetail.name == itemName then
            return i;
        end
    end

    return -1;
end

local function getPositionKey(position)
    return string.format("%d,%d,%d", position.x, position.y, position.z);
end

local function findTravelPath(startPosition, endPosition, allowedPositions)
    if allowedPositions ~= nil and not allowedPositions[getPositionKey(endPosition)] then
        return false, nil;
    end

    local function isPositionEqual(pos1, pos2)
        return pos1.x == pos2.x and pos1.y == pos2.y and pos1.z == pos2.z;
    end

    local function isPositionAllowed(position)
        return allowedPositions == nil or allowedPositions[getPositionKey(position)];
    end

    local function getNeighbours(position)
        local checkDirections = {
            { x =  1, y =  0, z =  0 },
            { x = -1, y =  0, z =  0 },
            { x =  0, y =  1, z =  0 },
            { x =  0, y = -1, z =  0 },
            { x =  0, y =  0, z =  1 },
            { x =  0, y =  0, z = -1 },
        }

        local neighbours = {};

        for _, direction in ipairs(checkDirections) do
            local neighbourPosition = {
                x = position.x + direction.x,
                y = position.y + direction.y,
                z = position.z + direction.z
            }
            if isPositionAllowed(neighbourPosition) then
                table.insert(neighbours, neighbourPosition);
            end
        end

        return neighbours;
    end

    local queue = { { position = startPosition, path = { startPosition } } };
    local visited = {};

    while #queue > 0 do
        local current = table.remove(queue, 1);
        local currentPosition = current.position;
        local currentPath = current.path;

        local key = getPositionKey(currentPosition);

        if isPositionEqual(currentPosition, endPosition) then
            return true, currentPath;
        end

        if visited[key] then
            goto continue
        end

        visited[key] = true;

        for _, neighbour in ipairs(getNeighbours(currentPosition)) do
            if not visited[getPositionKey(neighbour)] then
                local newPath = { table.unpack(currentPath) };
                table.insert(newPath, neighbour);
                table.insert(queue, { position = neighbour, path = newPath });
            end
        end

        ::continue::
    end

    return false, nil;
end

local function pathfindToPosition(startPosition, endPosition, allowedPositions)
    local couldFindPath, path = findTravelPath(startPosition, endPosition, allowedPositions);

    if not couldFindPath or path == nil then
        print("COULD NOT FIND PATH");
        return false;
    end

    for _, position in pairs(path) do
        if not moveTo(position) then
            return false;
        end
    end

    return true;
end

return {
    getPosition = getPosition,
    getDirection = getDirection,
    directions = DIRECTIONS,
    directionDeltas = DIRECTION_DELTAS,
    relativeDeltas = RELATIVE_DELTAS,
    turnDirections = TURN_DIRECTIONS,
    syncWithGPS = syncWithGPS,
    forward = forward,
    back = back,
    up = up,
    down = down,
    forceForward = forceForward,
    forceUp = forceUp,
    forceDown = forceDown,
    turn = turn,
    turnTo = turnTo,
    turnLeft = turnLeft,
    turnRight = turnRight,
    applyPositionDelta = applyPositionDelta,
    applyDirectionDelta = applyDirectionDelta,
    isPositionAdjacent = isPositionAdjacent,
    hasEnoughFuel = hasEnoughFuel,
    moveTo = moveTo,
    inspectSurroundings = inspectSurroundings,
    hasItem = hasItem,
    getItemCount = getItemCount,
    findItem = findItem,
    getPositionKey = getPositionKey,
    findTravelPath = findTravelPath,
    pathfindToPosition = pathfindToPosition,
}