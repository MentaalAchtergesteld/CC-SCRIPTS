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
    local appListY = 3;
    local appListMaxY = 13;
    local appList = tui.createList(1, appListY, appListMaxY,  APPS,
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
                tui.switchView("AppDetails", { app = selectedApp });
            elseif key == keys.i then
                installApp(selectedApp);
            elseif key == keys.r then
                removeApp(selectedApp);
            end
        end
    end);

    homeView.onEnter = function (self)
        -- local res, error = loadApps();
        -- if error then
        --     errorLabel.text = error;
        -- else
        --     APPS = res;
        --     errorLabel.text = "";
            
        --     loadAppStatusses();
        --     appList.items = APPS;
        -- end
    end

    return homeView;
end

local function createAppDetailsview()
    local appDetailsView = tui.createView("AppDetails");

    local appTitle = tui.createLabel(1, 1, "AppTitle");
    local appStatusLabel = tui.createLabel(termWidth, 1, "");
    local divider = tui.createDivider(2);
    local appType = {
        tui.createLabel(1, 3, "Type: ");
        tui.createLabel(7, 3, "None");
    };
    local appDescription = tui.createParagraph(1, 5, "App Description", math.floor(termWidth*0.75));

    local instructions = tui.createLabel(1, termHeight, "[I] Install | [B] Back");

    appDetailsView:addElement(appTitle);
    appDetailsView:addElement(appStatusLabel);
    appDetailsView:addElement(divider);
    appDetailsView:addElements(appType);
    appDetailsView:addElement(appDescription);
    appDetailsView:addElement(instructions);

    local function updateInstructions(appId)
        local appStatus = APP_STATUS[appId];

        if appStatus == AppStatus.Installed or appStatus == AppStatus.Installing then
            instructions.text = "[U] Update | [R] Remove | [B] Back";
        else
            instructions.text = "[I] Install | [B] Back";
        end
    end

    local function updateAppStatus(appId)
        local appStatus = APP_STATUS[appId];

        appStatusLabel.text =
            (appStatus == AppStatus.Installed and "Installed") or
            (appStatus == AppStatus.Installing and "Installing...") or
            "Not Installed";
        
        appStatusLabel.x = termWidth - #appStatusLabel.text;
    end

    appDetailsView.onEnter = function(self)
        local app = self.context.app;
        if not app then return end;

        appTitle.text = app.name;
        appDescription.text = app.description;

        appType[2].text =
            (app.type == "script" and "Script") or
            (app.type == "lib" and "Library");
        
        updateInstructions(app.id);
        updateAppStatus(app.id);
    end

    appDetailsView:addEventListener("key_up", function(event)
        local key = event[2];

        local currentApp = appDetailsView.context.app;

        if currentApp then
            local status = APP_STATUS[currentApp.id];

            if status == AppStatus.Installed then
                if key == keys.r then
                    removeApp(currentApp);
                    updateAppStatus(currentApp.id);
                    updateInstructions(currentApp.id);
                elseif key == keys.u then
                    installApp(currentApp);
                    updateAppStatus(currentApp.id);
                    updateInstructions(currentApp.id);
                end
            elseif status ~= AppStatus.Installing then
                if key == keys.i then
                    installApp(currentApp);
                    updateAppStatus(currentApp.id);
                    updateInstructions(currentApp.id);
                end
            end
        end

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