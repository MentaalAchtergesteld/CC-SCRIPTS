local tabula = require("/lib/tabula");
local ecdysis = require("/lib/ecdysis");

local ORES = {
    "minecraft:coal_ore",
    "minecraft:deepslate_coal_ore",
    "minecraft:iron_ore",
    "minecraft:deepslate_iron_ore",
    "minecraft:copper_ore",
    "minecraft:deepslate_copper_ore",
    "minecraft:gold_ore",
    "minecraft:deepslate_gold_ore",
    "minecraft:redstone_ore",
    "minecraft:deepslate_redstone_ore",
    "minecraft:emerald_ore",
    "minecraft:deepslate_emerald_ore",
    "minecraft:lapis_ore",
    "minecraft:deepslate_lapis_ore",
    "minecraft:diamond_ore",
    "minecraft:deepslate_diamond_ore",
    "create:zinc_ore",
    "create:deepslate_zinc_ore",
};

local KEEP = {
    "minecraft:coal",
    "minecraft:raw_iron",
    "minecraft:raw_copper",
    "minecraft:raw_gold",
    "minecraft:redstone",
    "minecraft:emerald",
    "minecraft:lapis_lazuli",
    "minecraft:diamond",
    "create:raw_zinc"
}

local function isOre(block)
    if not block or not block.name then
        return false;
    end

    local blockName = block.name;

    return table.contains(ORES, blockName);
end

local function getOreNeighbours()
    local neighbours = ecdysis.inspectSurroundings();
    local neighbourPositions = {}

    for direction, neighbour in pairs(neighbours) do
        if isOre(neighbour.data) then
            local delta = ecdysis.applyDirectionDelta(ecdysis.relativeDeltas[direction]);
            local orePosition = ecdysis.applyPositionDelta(delta);

            table.insert(neighbourPositions, orePosition);
        end
    end

    return neighbourPositions;
end

local function mineOreVein(firstOrePosition, endPosition)
    local stack = {firstOrePosition};
    local visited = {};
    visited[ecdysis.getPositionKey(endPosition)] = true;

    while #stack > 0 do
        local currentPosition = table.remove(stack, #stack);
        local key = ecdysis.getPositionKey(currentPosition);

        if visited[key] then
            goto continue
        end

        visited[key] = true;

        local couldTravel = ecdysis.pathfindToPosition(ecdysis.getPosition(), currentPosition, visited);

        if not couldTravel then
            return false, "Could not travel to required position.";
        end
        
        for _, position in pairs(getOreNeighbours()) do
            table.insert(stack, position);
        end

        ::continue::
    end

    ecdysis.pathfindToPosition(ecdysis.getPosition(), endPosition, visited);
end

local function filterInventory()
    for i=1, 16 do
        local itemDetail = turtle.getItemDetail(i);

        if itemDetail and not table.contains(KEEP, itemDetail.name) then
            turtle.select(i);
            turtle.dropDown();
        end
    end
end

local function digForward()
    ecdysis.forceForward();

    local direction = ecdysis.getDirection();
    for _, position in pairs(getOreNeighbours()) do
        mineOreVein(position, ecdysis.getPosition());
    end
    ecdysis.turnTo(direction);
end

local function main()
    local startPosition = { x = ecdysis.getPosition().x, y = ecdysis.getPosition().y, z = ecdysis.getPosition().z };

    for i=0, 100 do
        local distanceToStart = math.sqrt(
            startPosition.x * startPosition.x +
            startPosition.y * startPosition.y +
            startPosition.z * startPosition.z
        );

        if turtle.getFuelLevel() < distanceToStart + 100 then
            break;
        end

        digForward();

        if i%5 then
            filterInventory();
        end
    end

    ecdysis.pathfindToPosition(ecdysis.getPosition(), startPosition);
end

main();