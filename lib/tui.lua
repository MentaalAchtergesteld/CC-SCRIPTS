local tui = {};

tui.views = {};
tui.currentView = nil;
tui.viewStack = {};

tui.eventListeners = {};
tui.running = false;

tui.Direction = {
    UP = 1,
    DOWN = 2,
    LEFT = 3,
    RIGHT = 4
};

local termWidth, termHeight = term.getSize();

local View = {
    name = "EmptyView",
    elements = {},
    eventListeners = {},
    context = {},
    onEnter = function(self) end,
    onExit = function(self) end,
    addEventListener = function(self, eventName, callback)
        table.insert(self.eventListeners, {
            eventName = eventName,
            callback = callback,
        });
    end,
    addElement = function(self, element)
        table.insert(self.elements, element)
    end,
    addElements = function(self, elements)
        for _, element in ipairs(elements) do
            self:addElement(element);
        end
    end
}

function tui.createView(name)
    local view = {
        name = name,
        elements = {},
        context = {},
        onEnter = function(self) end,
        onExit = function(self) end,
    };

    setmetatable(view, {__index = View});
    return view;
end

function tui.addView(view)
    tui.views[view.name] = view;
end

function tui.switchView(name, context)
    if tui.currentView then
        tui.currentView:onExit();
        table.insert(tui.viewStack, tui.currentView);
    end

    tui.currentView = tui.views[name];
    tui.currentView.context = context or {};
    tui.currentView:onEnter();
end

function tui.goBack()
    if #tui.viewStack > 0 then
        tui.currentView:onExit();
        tui.currentView = table.remove(tui.viewStack);
        tui.currentView:onEnter();
    end
end

local Element = {
    x = 1,
    y = 1,
    width = 1,
    height = 1,
    neighbours = {
        [tui.Direction.UP]    = nil,
        [tui.Direction.DOWN]  = nil,
        [tui.Direction.LEFT]  = nil,
        [tui.Direction.RIGHT] = nil,
    },
    hasNeighbour = function(self, direction)
        return self.neighbours[direction] ~= nil
    end,
    getNeighbour = function(self, direction)
        return self.neighbours[direction];
    end,
    switchFocus = function(self, other)
        self.focused = false;
        other.focused = true;
    end,
    focused = false,
    draw = function(self) end,
    handleEvent = function(self, event) end,
}

function tui.createLabel(x, y, text)
    local label = {
        x = x,
        y = y,
        width = #text,
        height = 1,
        text = text,
        draw = function (self)
            term.setCursorPos(self.x, self.y);
            term.write(self.text);
        end
    }

    setmetatable(label, {__index = Element});
    return label;
end

function tui.createButton(x, y, text, callback)
    local button = {
        x = x,
        y = y,
        width = #text + 2,
        height = 1,
        text = text,
        callback = callback,
        draw = function(self)
            term.setCursorPos(self.x, self.y);
            if self.focused then
                term.write("[".. self.text .."]");
            else
                term.write("<".. self.text ..">");
            end
        end,
        handleEvent = function(self, event)
            if not self.focused then return end;
            if event[1] ~= "key_up" then return end;

            local key = event[2];

            if key == keys.enter then
                self.callback(self);
            elseif key == keys.up and self:hasNeighbour(tui.Direction.UP) then
                self:switchFocus(self:getNeighbour(tui.Direction.UP));
            elseif key == keys.down and self:hasNeighbour(tui.Direction.DOWN) then
                self:switchFocus(self:getNeighbour(tui.Direction.DOWN));
            elseif key == keys.left and self:hasNeighbour(tui.Direction.LEFT) then
                self:switchFocus(self:getNeighbour(tui.Direction.LEFT));
            elseif key == keys.right and self:hasNeighbour(tui.Direction.RIGHT) then
                self:switchFocus(self:getNeighbour(tui.Direction.RIGHT));
            end
        end
    };

    setmetatable(button, {__index = Element});
    return button;
end

function tui.createTitleBar(text)
    local titleBar = {
        x = 1,
        y = 1,
        width = termWidth,
        height = 1,
        text = text,
        draw = function(self)
            local termWidth, termHeight = term.getSize();
            local borderWidth = termWidth - #self.text;
            local fullTitle = string.rep("=", borderWidth/2) .. self.text .. string.rep("=", borderWidth/2);
            term.setCursorPos(self.x, self.y);
            term.write(fullTitle);
        end
    };

    setmetatable(titleBar, {__index = Element});
    return titleBar;
end

function tui.createList(x, y, items, itemGenerator)
    local list = {
        x = x,
        y = y,
        width = 0,
        height = #items,
        selected = 1,
        items = items,
        itemGenerator = itemGenerator or function(index, item, isSelected)
            if isSelected then
                return "> " .. item;
            else
                return " " .. item;
            end
        end,
        draw = function(self)
            for i, item in ipairs(self.items) do
                term.setCursorPos(self.x, self.y + i - 1);
                if i == self.selected then
                    term.setTextColor(colors.lightGray);
                else
                    term.setTextColor(colors.white);
                end

                local itemText = self.itemGenerator(i, item, i == self.selected);
                term.write(itemText);
            end

            term.setTextColor(colors.white);
        end,
        handleEvent = function(self, event)
            if not self.focused then return end;
            if event[1] ~= "key_up" then return end;

            local key = event[2];

            if key == keys.down then
                if self.selected < #self.items then
                    self.selected = self.selected + 1;
                end
            elseif key == keys.up then
                if self.selected > 1 then
                    self.selected = self.selected - 1;
                end
            end
        end
    }

    for _, item in ipairs(items) do
        list.width = math.max(list.width, #item + 2);
    end

    setmetatable(list, {__index = Element});
    return list;
end

function tui.createDivider(y, pattern)
    local divider = {
        x = 1,
        y = y,
        height = 1,
        width = termWidth,
        pattern = pattern or '-',
        draw = function(self)
            term.setCursorPos(self.x, self.y);

            local dividerString = string.rep(self.pattern, math.ceil(termWidth / #self.pattern + 1)):sub(1, termWidth);
            term.write(dividerString);
        end
    }

    setmetatable(divider, {__index = Element});
    return divider;
end

function tui.createParagraph(x, y, text, width)
    local function calculateWrap(text, width)
        local lines = {};
        local currentLine = "";
        local words = {};

        for word in text:gmatch("%S+") do
            while #word > width do
                table.insert(words, word:sub(1, width - 1) .. "-");
                word = word:sub(width);
            end

            table.insert(words, word);
        end

        for _, word in ipairs(words) do
            if #currentLine + #word + 1 > width then
                table.insert(lines, currentLine);
                currentLine = word;
            else
                if currentLine == "" then
                    currentLine = word;
                else
                    currentLine = currentLine .. " " .. word;
                end
            end
        end
        table.insert(lines, currentLine);

        return lines, #lines;
    end

    local lines, height = calculateWrap(text, width);

    local paragraph = {
        x = x,
        y = y,
        width = width or (termWidth - x + 1),
        height = height,
        text = text,
        oldText = text,
        lines = lines,
        draw = function(self)
            if self.oldText ~= self.text then
                self.lines, self.height = calculateWrap(self.text, self.width);
                self.oldText = self.text;
            end

            for i, line in ipairs(self.lines) do
                term.setCursorPos(self.x, self.y + i - 1);
                term.write(line);
            end
        end
    }

    setmetatable(paragraph, {__index = Element});
    return paragraph;
end

function tui.addEventListener(eventName, callback)
    table.insert(tui.eventListeners, {
        eventName = eventName,
        callback = callback;
    });
end

function tui.linkNeighbours(e1, e2, direction)
    e1.neighbours[direction] = e2;
    local opposite = {
        [tui.Direction.UP] = tui.Direction.DOWN,
        [tui.Direction.DOWN] = tui.Direction.UP,
        [tui.Direction.LEFT] = tui.Direction.RIGHT,
        [tui.Direction.RIGHT] = tui.Direction.LEFT,
    }
    e2.neighbours[opposite[direction]] = e1;
end

function tui.redraw()
    while tui.running do
        term.clear();

        for _, element in ipairs(tui.currentView.elements) do
            element:draw();
        end

        os.sleep(0.1);
    end
end

function tui.handleEvents()
    -- Wait so enter button isnt detected immediatly when starting.
    os.sleep(0.5);

    while tui.running do
        local event = { os.pullEvent() };

        for _, listener in ipairs(tui.eventListeners) do
            if event[1] == listener.eventName then
                listener.callback(event);
            end
        end

        if tui.currentView then
            for _, listener in ipairs(tui.currentView.eventListeners) do
                if event[1] == listener.eventName then
                    listener.callback(event);
                end
            end

            for _, element in ipairs(tui.currentView.elements) do
                element:handleEvent(event);
            end
        end

    end
end

function tui.stop()
    if tui.running then
        term.clear();
        term.setCursorPos(1, 1);
        tui.running = false; 
    end
end

function tui.start()
    tui.running = true;
    parallel.waitForAll(tui.redraw, tui.handleEvents);
    tui.stop();
end

return tui;