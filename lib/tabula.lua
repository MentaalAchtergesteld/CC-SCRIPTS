function table:contains(searchValue, recursive)
    recursive = recursive or false;

    local queue = {self};

    while #queue > 0 do
        local entry = table.remove(queue, 1);
        for _, value in pairs(entry) do

            if type(value) == "table" then
                if recursive then
                    table.insert(queue, value);                   
                end
            elseif value == searchValue then
                return true;
            end
        end
    end

    return false;
end

function table:print(indent)
    indent = indent or 0;

    local spaceBefore = string.rep(" ", indent);
    for key, value in pairs(self) do

        if type(value) == "table" then
            print(spaceBefore .. key .. ":");
            table.print(value, indent + 2);
        else
            print(spaceBefore .. key .. ": " .. tostring(value));
        end
    end
end

function table:filter(predicate)
    local result = {};

    for _, value in pairs(self) do
        if predicate(value) then
            table.insert(result, value);
        end
    end

    return result;
end

function table:equal(other, recursive)
    if self == other then return true end;
    recursive = recursive or false;

    local selfKeyCount = 0;
    for key, value in pairs(self) do
        selfKeyCount = selfKeyCount + 1;

        if other[key] == nil or not (value == other[key]) then
            return false;
        end

        if recursive and type(value) == "table" then
            if not table.equal(value, other[key]) then
                return false;
            end
        end
     end

    local otherKeyCount = 0;

    for _, _ in pairs(other) do
        otherKeyCount = otherKeyCount + 1;
    end

    return selfKeyCount == otherKeyCount;
end