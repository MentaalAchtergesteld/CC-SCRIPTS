local yoink = require("/lib/yoink");

local BASE_URL = "https://raw.githubusercontent.com/MentaalAchtergesteld/CC-SCRIPTS/refs/heads/main/";
local STORE_URL = BASE_URL .. "store.json";
local SCRIPTS_URL = BASE_URL .. "scripts/";
local LIB_URL = BASE_URL .. "lib/";

local STORE_PATH = "store/";
local SCRIPT_STATUS_PATH = STORE_PATH .. "scriptStatus.json";

local SCRIPTS_DIR = "/";
local LIB_DIR = "lib/";

local SCRIPTS = {};
local SCRIPT_STATUS = {};
local LOG = {};

local screenWidth, screenHeight = term.getSize();

local RUNNING = true;
local SCREENS = {};
local currentScreen = nil;

local function switchScreen(screenName, switchData)
    currentScreen = SCREENS[screenName];
    if currentScreen == nil then return end

    currentScreen.enter(switchData);
end

local function drawLoop()
    while RUNNING do
        if currentScreen == nil then goto continue end

        currentScreen.draw();

        os.sleep(0.1);
        
        ::continue::
    end
end

local function inputLoop()
    while RUNNING do
        if currentScreen == nil then goto continue end

        local event = {os.pullEvent()};

        currentScreen.input(event);

        ::continue::
    end
end

local function loadStore()
    local response = yoink.get(STORE_URL).json();
    if not response then
        table.insert(LOG, "Couldn't load script list.");
    end;

    SCRIPTS = response;
end

local function findScriptIndexById(id)
    for i, script in ipairs(SCRIPTS) do
        if script.id == id then
            return i;
        end
    end

    return nil;
end

local function loadScriptStatus()
    if not fs.exists(SCRIPT_STATUS_PATH) then
        SCRIPT_STATUS = {};
        return;
    end

    local file = fs.open(SCRIPT_STATUS_PATH, "r");
    local content = file.readAll();
    file.close();

    SCRIPT_STATUS = textutils.unserializeJSON(content) or {};
end

local function updateScriptStatus(scriptName, status)
    SCRIPT_STATUS[scriptName] = status;
    
    local file = fs.open(SCRIPT_STATUS_PATH, "w");
    file.write(textutils.serializeJSON(SCRIPT_STATUS));
    file.close();
end

local function installScript(script)
    if script == nil or script.id == nil then
        return false, "No script provided"
    end


    local installQueue = {script};
    local installed = {};

    while #installQueue > 0 do
        local currentScript = table.remove(installQueue, 1);

        if installed[currentScript.id] then
            goto continue;
        end

        updateScriptStatus(currentScript.id, "installing");
        local url = 
            (currentScript.type == "script" and SCRIPTS_URL) or
            (currentScript.type == "lib" and LIB_URL);
    
        if url == nil then
            updateScriptStatus(currentScript.id, nil);
            goto continue;
        end

        local response = yoink.get(url .. currentScript.file);
        if not response then
            updateScriptStatus(currentScript.id, nil);
            goto continue;
        end

        local directory = 
            (currentScript.type == "script" and SCRIPTS_DIR) or 
            (currentScript.type == "lib" and LIB_DIR);

        local file = fs.open(directory .. currentScript.file, "w");
        file.write(response.content);
        file.close();

        updateScriptStatus(currentScript.id, "installed");
        installed[currentScript.id] = true;

        if currentScript.deps then
            for _, dep in ipairs(currentScript.deps) do
                local scriptIndex = findScriptIndexById(dep);
                local dependency = SCRIPTS[scriptIndex];

                if dependency and not installed[dependency.id] then
                    table.insert(installQueue, SCRIPTS[scriptIndex]);                   
                end
            end
        end

        ::continue::
    end

    return true;
end

local function updateScript(script)
    if not SCRIPT_STATUS[script.id] == "installed" then
        return false, "Script is not installed.";
    end

    updateScriptStatus(script.id, "updating");

    installScript(script);
end

local function removeScript(script)
    if not SCRIPT_STATUS[script.id] == "installed" then
        return false, "Script is not installed.";
    end

    local directory = 
        (script.type == "script" and SCRIPTS_DIR) or 
        (script.type == "lib" and LIB_DIR);

    updateScriptStatus(script.id, "removing");
    fs.delete(directory .. script.file);
    updateScriptStatus(script.id, nil);
end

local function installAllInstallingScripts()
    for scriptName, status in ipairs(SCRIPT_STATUS) do
        if status == "installing" and SCRIPTS[scriptName] then
            installScript(SCRIPTS[scriptName]);
        end
    end
end

local function updateAllUpdatingScripts()
    for scriptName, status in ipairs(SCRIPT_STATUS) do
        if status == "updating" and SCRIPTS[scriptName] then
            updateScript(SCRIPTS[scriptName]);
        end
    end
end

local function removeAllRemovingScripts()
    for scriptName, status in ipairs(SCRIPT_STATUS) do
        if status == "removing" and SCRIPTS[scriptName] then
            removeScript(SCRIPTS[scriptName]);
        end
    end
end

local function createHomeScreen()
    local selectedIndex = 1;

    local title = " Script Store ";
    local borderWidth = screenWidth - #title;
    local fullTitle = string.rep("=", borderWidth/2) .. title .. string.rep("=", borderWidth/2);

    local function enter(switchData)
        loadStore();
    end

    local function draw()
        term.clear();

        term.setCursorPos(1, 1);
        term.write(fullTitle);

        local listY = 2;
        local listHeight = 7;
        local listCenter = math.floor(listHeight/2);

        local listStart = math.max(1, selectedIndex - listCenter + 1);
        listStart = math.min(listStart, math.max(1, #SCRIPTS - listHeight + 1));

        for i=1, math.min(listHeight, #SCRIPTS) do
            term.setCursorPos(1, i + listY);

            local scriptIndex = i + (listStart - 1);
            if scriptIndex > #SCRIPTS then break end;

            local script = SCRIPTS[scriptIndex];

            local isSelected = "";

            if scriptIndex == selectedIndex then
                term.setTextColor(colors.lightGray);
                isSelected = ">";
            else
                term.setTextColor(colors.white);
                isSelected = "";
            end

            local isInstalled =
                (SCRIPT_STATUS[script.id] == "installed" and "*") or
                (SCRIPT_STATUS[script.id] ~= nil and "~") or
                "+"

            local type = (script.type == "script" and "Script") or (script.type == "lib" and "Library");

            term.write(string.format("%s [%d] %s %s (%s)", isSelected, scriptIndex, isInstalled, script.name, type));
        end

        term.setTextColor(colors.white);

        term.setCursorPos(1, screenHeight-2);
        term.write("[Q] Quit | [Enter] See script details");
        term.setCursorPos(1, screenHeight-1)
        term.write("[I] Install | [U] Update | [R] Remove");
        term.setCursorPos(1, screenHeight)
        term.write("[^] Up | [v] Down");
    end

    local function input(event)
        local eventName = event[1];
        if eventName == "key" then
            local key = event[2];

            if key == keys.up then
                selectedIndex = math.max(selectedIndex - 1, 1);
            elseif key == keys.down then
                selectedIndex = math.min(selectedIndex + 1, #SCRIPTS);
            elseif key == keys.enter then
                switchScreen("scriptDetails", { scriptIndex = selectedIndex });
            elseif key == keys.q then
                switchScreen("quit");
            elseif key == keys.i then
                    installScript(SCRIPTS[selectedIndex]);
            elseif key == keys.u then
                updateScript(SCRIPTS[selectedIndex]);
            elseif key == keys.r then
                removeScript(SCRIPTS[selectedIndex]);
            elseif key == keys.b then
                switchScreen("home");
            end
        end
    end

    return {
        enter = enter,
        draw = draw,
        input = input;
    }
end

local function createScriptDetailsScreen()
    local script = nil;

    local function enter(switchData)
        local scriptIndex = switchData.scriptIndex;
        
        script = SCRIPTS[scriptIndex];
    end

    local function draw()
        term.clear();
        
        local scriptName = script and script.name or "NO NAME";
        local scriptDescription = script and script.description or "NO DESCRIPTION";

        term.setTextColor(colors.white);

        term.setCursorPos(1, 1);
        term.write(scriptName);

        term.setCursorPos(1, 2);
        term.write(string.rep("-", screenWidth));

        term.setCursorPos(1, 3);
        print(scriptDescription);

        local scriptInstructions = "";

        if script and script.id then
            local scriptStatus = SCRIPT_STATUS[script.id];
            if scriptStatus == "installed" then
                scriptInstructions = "[U] Update | [R] Remove";
            elseif scriptStatus == "installing" then
                scriptInstructions = "Installing...";
            elseif scriptStatus == "updating" then
                scriptInstructions = "Updating...";
            elseif scriptStatus == "removing" then
                scriptInstructions = "Removing...";
            else
                scriptInstructions = "[I] Install";
            end
        end

        term.setCursorPos(1, screenHeight);
        term.write("[B] Back | " .. scriptInstructions);
    end

    local function input(event)
        local eventName = event[1];
        if eventName == "key" then
            local key = event[2];

            if key == keys.i then
                installScript(script);
            elseif key == keys.u then
                updateScript(script);
            elseif key == keys.r then
                removeScript(script);
            elseif key == keys.b then
                switchScreen("home");
            end
        end
    end

    return {
        enter = enter,
        draw = draw,
        input = input,
    }
end

local function createQuitScreen()
    local function enter(switchData)
        term.clear();
        term.setCursorPos(1, 1);
        RUNNING = false;
    end

    local function draw()
        term.clear();
        term.setCursorPos(1, 1);
        term.write("Goodbye.");
    end

    local function input(event)

    end

    return {
        enter = enter,
        draw = draw,
        input = input,
    }
end


local function main()
    if not fs.exists("store") then
        fs.makeDir("store");
    end

    loadStore();
    loadScriptStatus();
    installAllInstallingScripts();
    updateAllUpdatingScripts();
    removeAllRemovingScripts();

    SCREENS["home"] = createHomeScreen();
    SCREENS["scriptDetails"] = createScriptDetailsScreen();
    SCREENS["quit"] = createQuitScreen();

    switchScreen("home");

    parallel.waitForAll(drawLoop, inputLoop);
end

main();