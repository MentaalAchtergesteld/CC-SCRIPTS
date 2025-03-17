local tui = require("/lib/tui")
local yoink = require("/lib/yoink");


local BASE_URL = "https://raw.githubusercontent.com/MentaalAchtergesteld/CC-SCRIPTS/refs/heads/main/";
local STORE_URL = BASE_URL .. "store.json";
local SCRIPTS_URL = BASE_URL .. "scripts/";
local LIB_URL = BASE_URL .. "lib/";

local SCRIPTS_DIR = "/";
local LIB_DIR = "lib/";

local STORE_PATH = "store/";
local APP_STATUS_PATH = STORE_PATH .. "scriptStatus.json";

local termWidth, termHeight = term.getSize();

local APPS = {};
local AppStatus = {
    Installed = 1,
    Installing = 2,
}
local APP_STATUS = {};

local function loadApps()
    local response, error = yoink.get(STORE_URL).json();
    if not response then
        return nil, error;
    end

    return response, nil;
end

local function loadAppStatusses()
    if not fs.exists(APP_STATUS_PATH) then
        APP_STATUS = {};
        return;
    end

    local file = fs.open(APP_STATUS_PATH, "r");
    local content = file.readAll();
    file.close();

    APP_STATUS = textutils.unserializeJSON(content) or {};
end

local function getAppWithId(id)
    for _, app in ipairs(APPS) do
        if app.id == id then
            return app;
        end
    end

    return nil, "Could not find app with supplied ID";
end

local function updateAppStatus(appId, newStatus)
    APP_STATUS[appId] = newStatus;
    
    local file = fs.open(APP_STATUS_PATH, "w");
    file.write(textutils.serializeJSON(APP_STATUS));
    file.close();
end

local function installApp(app)
    local installQueue = {app};
    local installedIds = {app.id};

    while #installQueue > 0 do
        local currentApp = table.remove(installQueue, 1);
        
        if installedIds[currentApp.id] then
            goto continue
        end

        updateAppStatus(currentApp.id, AppStatus.Installing);

        local url =
            (currentApp.type == "script" and SCRIPTS_URL) or
            (currentApp.type == "lib"    and LIB_URL);
        
        if url == nil then
            goto continue;
        end

        local res, error = yoink.get(url .. currentApp.file);

        if not res or error then
            local file = fs.open("error", "w");
            file.write(error);
            file.close();
            goto continue;
        end

        local directory =
            (currentApp.type == "script" and SCRIPTS_DIR) or
            (currentApp.type == "lib"    and LIB_DIR);
        
        local file = fs.open(directory .. currentApp.file, "w");
        file.write(res.content);
        file.close();

        updateAppStatus(currentApp.id, AppStatus.Installed);
        installedIds[currentApp.id] = true;

        if currentApp.deps then
            for _, dependencyId in ipairs(currentApp.deps) do
                local app, error = getAppWithId(dependencyId);
                if not error and not installedIds[dependencyId] then
                    table.insert(installQueue, app);
                end
            end
        end

        ::continue::
    end
end

local function removeApp(app)
    if not APP_STATUS[app.id] == "installed" then
        return false, "Script is not installed.";
    end

    local directory = 
        (app.type == "script" and SCRIPTS_DIR) or 
        (app.type == "lib" and LIB_DIR);

    fs.delete(directory .. app.file);
    updateAppStatus(app.id, nil);
end

local function createHomeView()
    local homeView = tui.createView("Home");

    local titleBar = tui.createTitleBar("Script Store");
    local appList = tui.createList(1, 3, APPS,
        function(index, item, isSelected)
            local itemIndex = "[" .. index .. "]";

            local itemStatusIndicator =
                (APP_STATUS[item.id] == AppStatus.Installed  and "*") or
                (APP_STATUS[item.id] == AppStatus.Installing and "~") or
                "+"

            local itemEntry = itemStatusIndicator .. " " .. item.name;

            local itemType = "";
            if item.type == "script" then
                itemType = "(Script)";
            elseif item.type == "lib" then
                itemType = "(Lib)";
            end

            local listItem = itemIndex .. " " .. itemEntry .. " " .. itemType;

            if isSelected then
                return "> " .. listItem;
            else
                return " " .. listItem;
            end 
        end
    );
    appList.focused = true;

    local labels = {
        tui.createLabel(1, termHeight - 2, "[Q] Quit | [Enter] See script details"),
        tui.createLabel(1, termHeight - 1, "[I] Install | [U] Update | [R] Remove"),
        tui.createLabel(1, termHeight - 0, "[^] Up | [v] Down"),
    };

    local errorLabel = tui.createLabel(1, 3, "");

    homeView:addElement(titleBar);
    homeView:addElement(appList);
    homeView:addElements(labels);

    homeView:addEventListener("key_up", function(event)
        local key = event[2];

        if appList.focused then
            local selectedApp = appList.items[appList.selected];
            if key == keys.enter then
                tui.switchView("AppDetails", { appName = selectedApp.name, appDescription = selectedApp.description });
            elseif key == keys.i then
                installApp(selectedApp);
            elseif key == keys.r then
                removeApp(selectedApp);
            end
        end
    end);

    homeView.onEnter = function (self)
        local res, error = loadApps();
        if error then
            errorLabel.text = error;
        else
            APPS = res;
            errorLabel.text = "";
            
            loadAppStatusses();
            appList.items = APPS;
        end
    end

    return homeView;
end

local function createAppDetailsview()
    local appDetailsView = tui.createView("AppDetails");

    local appTitle = tui.createLabel(1, 1, "AppTitle");
    local divider = tui.createDivider(2);
    local appDescription = tui.createParagraph(1, 3, "App Description", termWidth);

    local instructions = tui.createLabel(1, termHeight, "[B] Back | [I] Install");

    appDetailsView:addElement(appTitle);
    appDetailsView:addElement(divider);
    appDetailsView:addElement(appDescription);
    appDetailsView:addElement(instructions);

    appDetailsView.onEnter = function(self)
        local context = self.context;
        if context.appName then
            appTitle.text = context.appName;
        end

        if context.appDescription then
            appDescription.text = context.appDescription;
        end
    end

    appDetailsView:addEventListener("key_up", function(event)
        local key = event[2];

        if key == keys.b then
            tui.goBack();
        end
    end);

    return appDetailsView;
end

local function main()
    local homeView = createHomeView();
    local appDetailsView = createAppDetailsview();
    
    tui.addView(homeView);
    tui.addView(appDetailsView);
    
    tui.switchView("Home");
    
    tui.addEventListener("key_up", function(event)
        local key = event[2];
        if key == keys.q then
            tui.stop();
        end
    end);
    
    tui.start();
end

main();