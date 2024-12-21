local baseURL = "https://raw.githubusercontent.com/MentaalAchtergesteld/CC-SCRIPTS/refs/heads/main/";
local storeURL = baseURL .. "store.json";
local scriptsURL = baseURL .. "scripts/";
local libURL = baseURL .. "lib/";

local screenWidth, screenHeight = term.getSize();

local function fetchScripts()
    print("Fetching list of available scripts...")
    local response = http.get(storeURL);
    if not response then
        error("Failed to fetch script list.");
    end

    local content = response.readAll();
    response.close();

    local decoded = textutils.unserializeJSON(content);
    if not decoded then
        error("Failed to decode JSON data.");
    end

    return decoded;
end

local function isInstalled(scriptName)
    return fs.exists("/" .. scriptName .. ".lua");
end

local function installScript(script)
    print(string.format("[INFO] Installing %s...", script.name));
    local response = http.get(scriptsURL .. script.file);
    if not response then
        error("Failed to download %s", script.name);
    end

    local content = response.readAll();
    response.close();

    local file = fs.open("/" .. script.name .. ".lua", "w");
    file.write(content);
    file.close();

    print(string.format("Installed %s!", script.name));
end

local function updateScript(script)
    if not isInstalled(script.name) then
        print("Script is not installed.");
        return;
    end

    print(string.format("Updating %s...", script.name));
    installScript(script);
end

local function removeScript(script)
    print(string.format("Removing %s...", script.name));

    if isInstalled(script.name) then
        fs.delete("/" .. script.name .. ".lua");
        print(string.format("Removed %s.", script.name));
    else
        print("Script is not installed.");
    end
end

local function drawScriptsList(scripts, selectedIndex)
    term.clear();
    term.setCursorPos(1,1);
    print("=== Script Store ===");

    for i=1, math.min(screenHeight - 2, #scripts) do
        local scriptIndex = i + (selectedIndex - 1);
        if scriptIndex > #scripts then break end

        local script = scripts[scriptIndex];
        if scriptIndex == selectedIndex then
            term.setTextColor(colors.gray);
        else
            term.setTextColor(colors.white);
        end

        print(string.format("[%d] %s", scriptIndex, script.name));
    end

    term.setTextColor(colors.white);
end

local function drawScriptDetails(script)
    term.clear();
    term.setCursorPos(1, 1);
    print("=== Script Details ===");
    print("Name: " .. script.name);
    print("Description: " .. script.description);
    print();
    print("[I] Install | [U] Update | [R] Remove | [B] Back");
end

local function main()
    local scripts = fetchScripts();
    local selectedIndex = 1;

    local running = true;

    local UIStates = {
        ScriptList = 1,
        ScriptDetail = 2
    }

    local state = UIStates.ScriptList;

    while running do
        if state == UIStates.ScriptList then
            drawScriptsList(scripts, selectedIndex);
            local event, key = os.pullEvent("key");
    
            if key == keys.up then
                selectedIndex = math.max(selectedIndex - 1, 1);
            elseif key == keys.down then
                selectedIndex = math.min(selectedIndex + 1, #scripts);
            elseif key == keys.enter then
                state = UIStates.ScriptDetail;
            end
        elseif state == UIStates.ScriptDetail then
            local script = scripts[selectedIndex];
            drawScriptDetails(script);

            local event, char = os.pullEvent("char");
            if char == "i" then
                installScript(script);
            elseif char == "u" then
                updateScript(script);
            elseif char == "r" then
                removeScript(script);
            elseif char == "b" then
                state = UIStates.ScriptList;
            end
        end

        sleep(0.1);
    end
end

main();