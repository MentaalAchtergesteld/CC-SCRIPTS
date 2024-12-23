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

local function post(url, data, headers)
    local payload = type(data) == "table" and textutils.serializeJSON(data) or data;

    local response = http.post(url, payload, headers);
    if not response then
        return nil, "Post request to " .. url .. " failed.";
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

return {
    get = get,
    post = post
}