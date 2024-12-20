local args = { ... };

local function help()
    print("How to use:");
    print("Place the turtle in front of a cobble generator. It will dig 64 cobble, before trying to deposit them downwards.");
end

local function getItemCount(item)
    local totalItemCount = 0;

    for i=1, 16 do
        local details = turtle.getItemDetail(i);

        if details then
            for key, value in pairs(item) do
                if not details[key] or details[key] ~= value then
                    break;
                end
            end

            totalItemCount = totalItemCount + turtle.getItemCount(i);
        end
    end

    return totalItemCount;
end

local function mineCobble(amountToMine)
    while getItemCount({ name = "minecraft:cobblestone" }) < amountToMine do
        turtle.dig();
    end
end

local function depositCobble()
    while getItemCount({ name = "minecraft:cobblestone" }) > 0 do
        for i=1, 16 do
            turtle.select(i);
            turtle.dropDown();
            if getItemCount({name = "minecraft:cobblestone" }) == 0 then
                break;
            end
        end
    end

    turtle.select(1);
end

local function main()
    print("Cobbler V2.0");

    if #args > 0 and args[1] == "help" then
        help();
        return;
    end

    print("Mining cobble...");

    while true do
        mineCobble(64);
        depositCobble();
    end
end

main();