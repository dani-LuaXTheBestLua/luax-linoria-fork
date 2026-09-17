--[[ Lua X SaveManager — create / save / load / delete / autoload | .json ]]
local HttpService = game:GetService("HttpService")

local SaveManager = {
    Folder = "LuaXConfigs",
    Library = nil,
    AutoLoadName = nil,
}

local function notify(self, msg, t)
    pcall(function()
        if self.Library and self.Library.Notify then self.Library:Notify(msg, t) end
    end)
end

function SaveManager:SetLibrary(Library) self.Library = Library end

function SaveManager:EnsureFolder()
    if makefolder and not isfolder(self.Folder) then pcall(makefolder, self.Folder) end
end

function SaveManager:GetConfigList()
    local list = {}
    self:EnsureFolder()
    if listfiles then
        pcall(function()
            for _, f in ipairs(listfiles(self.Folder)) do
                local n = f:match("([^/\\]+)%.json$")
                if n then table.insert(list, n) end
            end
        end)
    end
    table.sort(list)
    if #list == 0 then list = { "default" } end
    return list
end

function SaveManager:BuildData()
    local data = { Toggles = {}, Options = {} }
    local Toggles = getgenv().Toggles or {}
    local Options = getgenv().Options or {}
    for idx, tog in pairs(Toggles) do
        if type(tog) == "table" and tog.Value ~= nil then
            data.Toggles[idx] = tog.Value
        end
    end
    for idx, opt in pairs(Options) do
        if type(opt) == "table" and opt.Type then
            if opt.Type == "ColorPicker" and opt.Value then
                data.Options[idx] = { Type = "ColorPicker", R = opt.Value.R, G = opt.Value.G, B = opt.Value.B }
            elseif opt.Type == "KeyPicker" then
                data.Options[idx] = { Type = "KeyPicker", Value = opt.Value, Mode = opt.Mode }
            elseif opt.Value ~= nil then
                data.Options[idx] = { Type = opt.Type, Value = opt.Value }
            end
        end
    end
    return data
end

function SaveManager:ApplyData(data)
    if type(data) ~= "table" then return end
    local Toggles = getgenv().Toggles or {}
    local Options = getgenv().Options or {}
    if type(data.Toggles) == "table" then
        for idx, val in pairs(data.Toggles) do
            local tog = Toggles[idx]
            if tog and tog.SetValue then pcall(function() tog:SetValue(val) end) end
        end
    end
    if type(data.Options) == "table" then
        for idx, info in pairs(data.Options) do
            local opt = Options[idx]
            if opt then
                pcall(function()
                    if info.Type == "ColorPicker" then
                        local c = Color3.new(info.R or 1, info.G or 1, info.B or 1)
                        if opt.SetValueRGB then opt:SetValueRGB(c)
                        elseif opt.SetValue then opt:SetValue(c) end
                    elseif info.Type == "KeyPicker" then
                        if opt.SetValue then opt:SetValue(info.Value) end
                    elseif opt.SetValue then
                        opt:SetValue(info.Value)
                    end
                end)
            end
        end
    end
end

function SaveManager:Create(name) return self:Save(name) end

function SaveManager:Save(name)
    name = tostring(name or ""):gsub("[%c%z/\\]", "")
    if name == "" then
        notify(self, "Empty config name", 2)
        return false
    end
    self:EnsureFolder()
    if writefile then
        writefile(self.Folder .. "/" .. name .. ".json", HttpService:JSONEncode(self:BuildData()))
        notify(self, 'Config "' .. name .. '" created/saved')
        return true
    end
    notify(self, "writefile unavailable", 2)
    return false
end

function SaveManager:Load(name)
    name = tostring(name or "")
    local path = self.Folder .. "/" .. name .. ".json"
    if not (readfile and isfile and isfile(path)) then
        notify(self, "Config not found", 2)
        return false
    end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok or type(data) ~= "table" then
        notify(self, "Load failed", 2)
        return false
    end
    self:ApplyData(data)
    notify(self, 'Config "' .. name .. '" loaded')
    return true
end

function SaveManager:Delete(name)
    name = tostring(name or "")
    local path = self.Folder .. "/" .. name .. ".json"
    if delfile and isfile and isfile(path) then
        delfile(path)
        notify(self, 'Config "' .. name .. '" deleted')
        return true
    end
    notify(self, "Delete failed", 2)
    return false
end

function SaveManager:SetAutoLoad(name, enabled)
    self:EnsureFolder()
    if enabled and name and name ~= "" then
        self.AutoLoadName = name
        if writefile then writefile(self.Folder .. "/_autoload.txt", name) end
        notify(self, 'Config auto-load: "' .. name .. '"')
    else
        self.AutoLoadName = nil
        if writefile then writefile(self.Folder .. "/_autoload.txt", "") end
        notify(self, "Config auto-load off")
    end
end

function SaveManager:TryAutoLoad()
    if not (readfile and isfile) then return end
    local meta = self.Folder .. "/_autoload.txt"
    if isfile(meta) then
        local name = readfile(meta)
        if name and name ~= "" then self:Load(name) end
    end
end

function SaveManager:RefreshDropdown()
    pcall(function()
        if Options and Options.LuaXConfigList and Options.LuaXConfigList.SetValues then
            Options.LuaXConfigList:SetValues(self:GetConfigList())
        end
    end)
end

function SaveManager:ApplyToGroupbox(Groupbox)
    local L = self.Library
    if not Groupbox or not L then return end

    Groupbox:AddDropdown("LuaXConfigList", {
        Values = self:GetConfigList(),
        Default = 1,
        Text = "Config list",
    })
    Groupbox:AddInput("LuaXConfigName", { Text = "Config name", Default = "default" })
    Groupbox:AddButton("Create Config", function()
        local n = Options.LuaXConfigName and Options.LuaXConfigName.Value or "default"
        self:Create(n)
        self:RefreshDropdown()
    end)
    Groupbox:AddButton("Save Config", function()
        local n = Options.LuaXConfigName and Options.LuaXConfigName.Value or "default"
        self:Save(n)
        self:RefreshDropdown()
    end)
    Groupbox:AddButton("Load Config", function()
        local n = Options.LuaXConfigList and Options.LuaXConfigList.Value
        if type(n) == "table" then n = n[1] end
        if (not n or n == "") and Options.LuaXConfigName then n = Options.LuaXConfigName.Value end
        self:Load(tostring(n or ""))
    end)
    Groupbox:AddButton("Delete Config", function()
        local n = Options.LuaXConfigList and Options.LuaXConfigList.Value
        if type(n) == "table" then n = n[1] end
        self:Delete(tostring(n or ""))
        self:RefreshDropdown()
    end)
    Groupbox:AddToggle("LuaXConfigAutoLoad", {
        Text = "Auto Load Selected Config",
        Default = false,
        Callback = function(V)
            local n = Options.LuaXConfigList and Options.LuaXConfigList.Value
            if type(n) == "table" then n = n[1] end
            self:SetAutoLoad(tostring(n or "default"), V)
        end,
    })
    Groupbox:AddButton("Refresh List", function()
        self:RefreshDropdown()
        notify(self, "Config list refreshed")
    end)
end

function SaveManager:ApplyToTab(Tab)
    if Tab then self:ApplyToGroupbox(Tab:AddLeftGroupbox("Config Manager")) end
end

return SaveManager
