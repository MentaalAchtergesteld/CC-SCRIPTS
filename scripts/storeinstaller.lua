local BASE_URL = "https://raw.githubusercontent.com/MentaalAchtergesteld/CC-SCRIPTS/refs/heads/main/";

local SCRIPT_STATUS_PATH = "/store/scriptStatus.json";

local function json(content)
    return textutils.unserialiseJSON(content)
end

local function get(url, headers)
    local response = http.get(url, headers);
    if not response then
        return nil, "Get request to " .. url .. " failed.";
    end

    local content = response.readAll();
    response.close();

    return {
        content = content;
        json = function ()
            return json(content);
        end
    }
end

local function installScript(url, filename, directory)
    print("Installing " .. filename .. "...");
    local response = get(url);

    if not response then
        print("Couldn't install " .. filename .. "!");
        return false;
    end

    local file = fs.open(directory .. filename, "w");
    file.write(response.content);
    file.close();
    print("Installed " .. filename .. "!");

    return true;
end

local function cleanup(files)
    for _, file in ipairs(files) do
        fs.delete(file);
    end
end

local function main()
    local storeUrl = BASE_URL .. "/scripts/store.lua";
    local yoinkUrl = BASE_URL .. "/lib/yoink.lua";

    if fs.exists("store.lua") then
        print("Store already installed!");
        return;
    end

    if not installScript(storeUrl, "store.lua", "/") then
        cleanup({"store.lua"});
        return;
    end


    if not fs.exists("/lib/yoink.lua") then
        if not installScript(yoinkUrl, "yoink.lua", "/lib/") then
            cleanup({"store.lua", "/lib/yoink.lua"});
            return;
        end 
    end

    local file = fs.open(SCRIPT_STATUS_PATH, "w");
    file.write(textutils.serializeJSON({ scriptstore = "installed" }));
    file.close();

    print("Succesfully installed script store.");
end

main();