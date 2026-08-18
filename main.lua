local ContentProvider = game:GetService("ContentProvider")
local env = getgenv and getgenv() or _G
local req = env.request or env.http_request or (env.syn and env.syn.request) or (env.http and env.http.request)
local custom = env.getcustomasset or env.getsynasset
local write = env.writefile
local read = env.readfile
local isfile = env.isfile
local makefolder = env.makefolder
local isfolder = env.isfolder
local listfiles = env.listfiles
local delfile = env.delfile
local assets = {}
local folder = "AssetLibrary/cache"
local exts = {png=true, jpg=true, jpeg=true, webp=true, gif=true, bmp=true}

local function mkdir(path)
    if not makefolder then return end
    local current = ""
    for part in tostring(path):gmatch("[^/\\]+") do
        current = current == "" and part or current .. "/" .. part
        if not isfolder or not isfolder(current) then pcall(makefolder, current) end
    end
end

local function folders()
    mkdir("AssetLibrary")
    mkdir(folder)
end

local function hash(str)
    local h = 2166136261
    for i = 1, #str do
        h = bit32.bxor(h, str:byte(i))
        h = (h * 16777619) % 4294967296
    end
    return string.format("%08x", h)
end

local function safe(str)
    return tostring(str):gsub("[^%w%-%._]", "_")
end

local function extname(str)
    local ext = tostring(str):match("%.([%w]+)$")
    ext = ext and ext:lower()
    return ext and exts[ext] and ext or nil
end

local function urlext(url)
    local clean = tostring(url):match("^[^?#]+") or tostring(url)
    return extname(clean)
end

local function header(headers, name)
    if type(headers) ~= "table" then return nil end
    name = name:lower()
    for k, v in pairs(headers) do
        if tostring(k):lower() == name then return tostring(v) end
    end
end

local function mimetype(headers)
    local contentType = header(headers, "content-type")
    if not contentType then return nil end
    return contentType:lower():match("^%s*([^;%s]+)")
end

local function mimeext(headers)
    local contentType = mimetype(headers)
    if not contentType then return nil end
    if contentType == "image/png" then return "png" end
    if contentType == "image/jpeg" or contentType == "image/jpg" then return "jpg" end
    if contentType == "image/webp" then return "webp" end
    if contentType == "image/gif" then return "gif" end
    if contentType == "image/bmp" or contentType == "image/x-ms-bmp" then return "bmp" end
end

local function bodyext(body)
    local a, b, c, d = body:byte(1,4)
    if a == 137 and b == 80 and c == 78 and d == 71 then return "png" end
    if a == 255 and b == 216 and c == 255 then return "jpg" end
    if body:sub(1,4) == "RIFF" and body:sub(9,12) == "WEBP" then return "webp" end
    if body:sub(1,6) == "GIF87a" or body:sub(1,6) == "GIF89a" then return "gif" end
    if body:sub(1,2) == "BM" then return "bmp" end
end

local function fetch(url, headers)
    if req then
        local ok, res = pcall(req, {Url=url, Method="GET", Headers=headers or {}})
        if not ok then error("failed to request asset: " .. tostring(res), 3) end
        if type(res) == "string" then return res, {} end
        if type(res) ~= "table" then error("returned an invalid request response", 3) end
        local status = tonumber(res.StatusCode or res.Status or res.status_code or res.status)
        local body = res.Body or res.body
        local responseHeaders = res.Headers or res.headers or {}
        if status and (status < 200 or status >= 300) then error("asset request failed with HTTP " .. tostring(status), 3) end
        if type(body) ~= "string" then error("asset request returned no body", 3) end
        return body, responseHeaders
    end
    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok then error("failed to download asset: " .. tostring(body), 3) end
    return body, {}
end

local function robloxid(source)
    if type(source) == "number" then
        if source <= 0 then return nil end
        return tostring(math.floor(source))
    end
    if type(source) ~= "string" then return nil end
    return source:match("^%s*(%d+)%s*$")
        or source:match("^%s*rbxassetid://(%d+)%s*$")
        or source:match("[?&]id=(%d+)")
        or source:match("/library/(%d+)")
        or source:match("/catalog/(%d+)")
        or source:match("/store/asset/(%d+)")
        or source:match("/asset/(%d+)")
end

local function native(source)
    if type(source) ~= "string" then return false end
    return source:match("^rbxasset://") ~= nil
        or source:match("^rbxgameasset://") ~= nil
        or source:match("^rbxthumb://") ~= nil
end

local function cached(meta)
    if not read or not isfile or not isfile(meta) then return nil end
    local ok, path = pcall(read, meta)
    if not ok or type(path) ~= "string" or path == "" then return nil end
    if isfile(path) then return path end
end

local function localasset(path)
    if not custom then error("enviorment does not provide getcustomasset/getsynasset", 3) end
    local ok, id = pcall(custom, path)
    if not ok then error("failed to register local asset: " .. tostring(id), 3) end
    return id
end

function assets.download(url, opts)
    opts = opts or {}
    if type(url) ~= "string" or not url:match("^https?://") then error("download expects an http(s) URL", 2) end
    if not write then error("enviroment does not provide writefile", 2) end
    folders()
    local name = opts.name and safe(opts.name) or nil
    local forcedExt = opts.ext and tostring(opts.ext):lower() or nil
    if forcedExt and not exts[forcedExt] then error("unsupported image extension: " .. forcedExt, 2) end
    local key = name or hash(url)
    local meta = folder .. "/" .. key .. ".meta"
    if not opts.force then
        if name and extname(name) and isfile then
            local direct = folder .. "/" .. name
            if isfile(direct) then return direct, true end
        end
        local path = cached(meta)
        if path then return path, true end
    end
    local body, responseHeaders = fetch(url, opts.headers)
    if #body == 0 then error("downloaded asset was empty", 2) end
    local contentType = mimetype(responseHeaders)
    if contentType and (contentType == "text/html" or contentType == "text/plain" or contentType == "application/json") then
        error("URL did not return an image: " .. contentType, 2)
    end
    local ext = forcedExt or mimeext(responseHeaders) or bodyext(body) or urlext(url)
    if name and extname(name) then ext = forcedExt or mimeext(responseHeaders) or bodyext(body) or extname(name) end
    if not ext or not exts[ext] then error("could not determine a supported image format", 2) end
    local path
    if name then
        path = folder .. "/" .. (extname(name) and name or name .. "." .. ext)
    else
        path = folder .. "/" .. key .. "." .. ext
    end
    write(path, body)
    pcall(write, meta, path)
    return path, false
end

function assets.load(source, opts)
    opts = opts or {}
    if native(source) then return source, nil end
    local id = robloxid(source)
    if id then return "rbxassetid://" .. id, nil end
    if type(source) ~= "string" then error("unsupported asset source", 2) end
    if source:match("^https?://") then
        local path = assets.download(source, opts)
        return localasset(path), path
    end
    if isfile and isfile(source) then return localasset(source), source end
    if custom then
        local ok, result = pcall(custom, source)
        if ok and result then return result, source end
    end
    error("unknown asset source: " .. source, 2)
end

function assets.preload(source, opts)
    local id, path = assets.load(source, opts)
    local ok, err = pcall(ContentProvider.PreloadAsync, ContentProvider, {id})
    return id, path, ok, err
end

function assets.set(i, property, source, opts)
    if not i then error("instance is required", 2) end
    local id, path = assets.load(source, opts)
    i[property or "Image"] = id
    return id, path
end

function assets.file(path)
    if type(path) ~= "string" or path == "" then error("invalid file path", 2) end
    if isfile and not isfile(path) then error("file does not exist: " .. path, 2) end
    return localasset(path)
end

function assets.clear()
    if not listfiles or not delfile then return false, "executor does not provide listfiles/delfile" end
    folders()
    local ok, files = pcall(listfiles, folder)
    if not ok then return false, files end
    for _, path in ipairs(files) do pcall(delfile, path) end
    return true
end

function assets.setfolder(path)
    if type(path) ~= "string" or path == "" then error("invalid folder", 2) end
    folder = path:gsub("[/\\]+$", "")
    mkdir(folder)
    return folder
end

function assets.getfolder()
    return folder
end

function assets.supported()
    return {
        request=req ~= nil,
        customasset=custom ~= nil,
        writefile=write ~= nil,
        readfile=read ~= nil,
        isfile=isfile ~= nil,
        makefolder=makefolder ~= nil,
        listfiles=listfiles ~= nil,
        delfile=delfile ~= nil
    }
end

folders()
env.AssetLibrary = assets
return assets
