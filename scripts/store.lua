local storeURL = "https://raw.githubusercontent.com/MentaalAchtergesteld/CC-SCRIPTS/refs/heads/main/store.json";
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

local function drawScriptsList(scripts, selectedIndex)
    term.clear();
    term.setCursorPos(1,1);
    print("=== Script Store ===");

    for i=1, math.min(screenHeight - 2, #scripts) do
        local scriptIndex = i + (selectedIndex - 1);
        if scriptIndex > #scripts then break end

        local script = scripts[scriptIndex];
        if scriptIndex == selectedIndex then
            term.setTextColor(colors.yellow);
        else
            term.setTextColor(colors.white);
        end

        print(string.format("[%d] %s", scriptIndex, script.name));
    end

    term.setTextColor(colors.white);
end

local function main()
    local scripts = fetchScripts();
    local selectedIndex = 1;

    local running = true;

    while running do
        drawScriptsList(scripts, selectedIndex);
    end
end

main();