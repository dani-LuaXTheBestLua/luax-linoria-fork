--[[
    Lua X SaveManager / ConfigManager — Linoria-style
    Saves Toggles + Options as .json under LuaXConfigs/
]]

local HttpService = game:GetService("HttpService")

local SaveManager = {
    Folder = "LuaXConfigs",
    Library = nil,
    AutoLoad = false,
    AutoLoadName = "autoload",
}

function SaveManager:SetLibrary(Library)
    self.Library = Library
end

function SaveManager:EnsureFolder()
    if makefolder and not isfolder(self.Folder) then
        pcall(makefolder, self.Folder)
    end
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
            local t = opt.Type
            if t == "ColorPicker" and opt.Value then
                data.Options[idx] = {
                    Type = "ColorPicker",
                    R = opt.Value.R,
                    G = opt.Value.G,
                    B = opt.Value.B,
                    Transparency = opt.Transparency,
                }
            elseif t == "KeyPicker" then
                data.Options[idx] = {
                    Type = "KeyPicker",
                    Value = opt.Value,
                    Mode = opt.Mode,
                }
            elseif opt.Value ~= nil then
                data.Options[idx] = { Type = t, Value = opt.Value }
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
            if tog and tog.SetValue then
                pcall(function() tog:SetValue(val) end)
            end
        end
    end

    if type(data.Options) == "table" then
        for idx, info in pairs(data.Options) do
            local opt = Options[idx]
            if opt then
            pcall(function()
                if info.Type == "ColorPicker" and opt.SetValueRGB then
                    opt:SetValueRGB(Color3.new(info.R, info.G, info.B))
                elseif info.Type == "ColorPicker" and opt.SetValue then
                    opt:SetValue(Color3.new(info.R, info.G, info.B))
                elseif info.Type == "KeyPicker" then
                    if opt.SetValue then opt:SetValue(info.Value) end
                    if info.Mode and opt.SetMode then opt:SetMode(info.Mode) end
                elseif opt.SetValue then
                    opt:SetValue(info.Value)
                end
            end)
            end
        end
    end
end

function SaveManager:Save(name)
    name = tostring(name or "")
    if name == "" then
        if self.Library and self.Library.Notify then
            self.Library:Notify("Empty config name", 2)
        end
        return false
    end
    self:EnsureFolder()
    local data = self:BuildData()
    if writefile then
        writefile(self.Folder .. "/" .. name .. ".json", HttpService:JSONEncode(data))
        if self.Library and self.Library.Notify then
            self.Library:Notify('Config "' .. name .. '" saved')
        end
        return true
    end
    if self.Library and self.Library.Notify then
        self.Library:Notify("writefile unavailable", 2)
    end
    return false
end

function SaveManager:Load(name)
    name = tostring(name or "")
    local path = self.Folder .. "/" .. name .. ".json"
    if not (readfile and isfile and isfile(path)) then
        if self.Library and self.Library.Notify then
            self.Library:Notify("Config not found", 2)
        end
        return false
    end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)
    if not ok or type(data) ~= "table" then
        if self.Library and self.Library.Notify then
            self.Library:Notify("Load failed", 2)
        end
        return false
    end
    self:ApplyData(data)
    if self.Library and self.Library.Notify then
        self.Library:Notify('Config "' .. name .. '" loaded')
    end
    return true
end

function SaveManager:Delete(name)
    name = tostring(name or "")
    local path = self.Folder .. "/" .. name .. ".json"
    if delfile and isfile and isfile(path) then
        delfile(path)
        if self.Library and self.Library.Notify then
            self.Library:Notify('Config "' .. name .. '" deleted')
        end
        return true
    end
    if self.Library and self.Library.Notify then
        self.Library:Notify("Delete failed", 2)
    end
    return false
end

function SaveManager:SetAutoLoad(name, enabled)
    self.AutoLoadName = name or "autoload"
    self.AutoLoad = enabled and true or false
    self:EnsureFolder()
    if writefile then
        writefile(self.Folder .. "/_autoload.txt", self.AutoLoad and self.AutoLoadName or "")
    end
end

function SaveManager:TryAutoLoad()
    if not (readfile and isfile) then return end
    local meta = self.Folder .. "/_autoload.txt"
    if isfile(meta) then
        local name = readfile(meta)
        if name and name ~= "" then
            self:Load(name)
        end
    end
end

function SaveManager:ApplyToGroupbox(Groupbox)
    local L = self.Library
    if not Groupbox or not L then return end

    Groupbox:AddDropdown("LuaXConfigList", {
        Values = self:GetConfigList(),
        Default = 1,
        Text = "Config list",
        Callback = function() end,
    })
    Groupbox:AddButton("Refresh Config List", function()
        if Options.LuaXConfigList and Options.LuaXConfigList.SetValues then
            Options.LuaXConfigList:SetValues(self:GetConfigList())
        end
        L:Notify("Config list refreshed")
    end)
    Groupbox:AddInput("LuaXConfigName", { Text = "Config name", Default = "default" })
    Groupbox:AddButton("Create / Save Config", function()
        local n = Options.LuaXConfigName and Options.LuaXConfigName.Value or "default"
        self:Save(n)
        if Options.LuaXConfigList and Options.LuaXConfigList.SetValues then
            Options.LuaXConfigList:SetValues(self:GetConfigList())
        end
    end)
    Groupbox:AddButton("Load Config", function()
        local n = Options.LuaXConfigList and Options.LuaXConfigList.Value
        if type(n) == "table" then n = n[1] end
        if (not n or n == "") and Options.LuaXConfigName then
            n = Options.LuaXConfigName.Value
        end
        self:Load(tostring(n or ""))
    end)
    Groupbox:AddButton("Delete Config", function()
        local n = Options.LuaXConfigList and Options.LuaXConfigList.Value
        if type(n) == "table" then n = n[1] end
        self:Delete(tostring(n or ""))
        if Options.LuaXConfigList and Options.LuaXConfigList.SetValues then
            Options.LuaXConfigList:SetValues(self:GetConfigList())
        end
    end)
    Groupbox:AddToggle("LuaXAutoLoad", {
        Text = "Auto Load Selected",
        Default = false,
        Callback = function(V)
            local n = Options.LuaXConfigList and Options.LuaXConfigList.Value
            if type(n) == "table" then n = n[1] end
            self:SetAutoLoad(tostring(n or "default"), V)
        end,
    })
end

function SaveManager:ApplyToTab(Tab)
    if not Tab then return end
    local box = Tab:AddLeftGroupbox("Config Manager")
    self:ApplyToGroupbox(box)
end

return SaveManager
