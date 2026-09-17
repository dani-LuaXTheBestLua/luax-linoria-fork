--[[ Lua X ThemeManager — create / save / load / delete / autoload | .json ]]
local HttpService = game:GetService("HttpService")

local ThemeManager = {
    Folder = "LuaXThemes",
    Library = nil,
    AutoLoadName = nil,
}

local BuiltIn = {
    Primordial = {
        FontColor = {255,255,255}, MainColor = {24,24,24}, BackgroundColor = {18,18,18},
        AccentColor = {220,150,180}, OutlineColor = {40,40,40}, RiskColor = {255,50,50},
    },
    BlackWhite = {
        FontColor = {255,255,255}, MainColor = {25,25,25}, BackgroundColor = {15,15,15},
        AccentColor = {255,255,255}, OutlineColor = {55,55,55}, RiskColor = {255,60,60},
    },
    DarkBlue = {
        FontColor = {230,235,255}, MainColor = {18,22,32}, BackgroundColor = {12,14,20},
        AccentColor = {70,140,255}, OutlineColor = {40,50,70}, RiskColor = {255,50,50},
    },
}

local function toColor(t)
    if typeof(t) == "Color3" then return t end
    if type(t) == "table" then return Color3.fromRGB(t[1] or 255, t[2] or 255, t[3] or 255) end
    return Color3.fromRGB(255, 255, 255)
end

local function fromColor(c)
    return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
end

local function notify(self, msg, t)
    pcall(function()
        if self.Library and self.Library.Notify then self.Library:Notify(msg, t) end
    end)
end

function ThemeManager:SetLibrary(Library) self.Library = Library end

function ThemeManager:EnsureFolder()
    if makefolder and not isfolder(self.Folder) then pcall(makefolder, self.Folder) end
end

function ThemeManager:GetThemeList()
    local list = {}
    for n in pairs(BuiltIn) do table.insert(list, n) end
    self:EnsureFolder()
    if listfiles then
        pcall(function()
            for _, f in ipairs(listfiles(self.Folder)) do
                local n = f:match("([^/\\]+)%.json$")
                if n and n ~= "_autoload" then table.insert(list, n) end
            end
        end)
    end
    table.sort(list)
    if #list == 0 then list = { "Primordial" } end
    return list
end

function ThemeManager:ApplyTable(data)
    local L = self.Library
    if not L or type(data) ~= "table" then return end
    if data.FontColor then L.FontColor = toColor(data.FontColor) end
    if data.MainColor then L.MainColor = toColor(data.MainColor) end
    if data.BackgroundColor then L.BackgroundColor = toColor(data.BackgroundColor) end
    if data.AccentColor then
        L.AccentColor = toColor(data.AccentColor)
        if L.GetDarkerColor then L.AccentColorDark = L:GetDarkerColor(L.AccentColor) end
    end
    if data.OutlineColor then L.OutlineColor = toColor(data.OutlineColor) end
    if data.RiskColor then L.RiskColor = toColor(data.RiskColor) end
    pcall(function() L:UpdateColorsUsingRegistry() end)
    pcall(function() if L.SetGlass and L.GlassEnabled then L:SetGlass(true, L.GlassTransparency or 0.28) end end)
end

function ThemeManager:Load(name)
    name = tostring(name or "")
    if BuiltIn[name] then
        self:ApplyTable(BuiltIn[name])
        notify(self, 'Theme "' .. name .. '" loaded')
        return true
    end
    self:EnsureFolder()
    local path = self.Folder .. "/" .. name .. ".json"
    if isfile and isfile(path) then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
        if ok and type(data) == "table" then
            self:ApplyTable(data)
            notify(self, 'Theme "' .. name .. '" loaded')
            return true
        end
    end
    notify(self, "Theme not found", 2)
    return false
end

function ThemeManager:Create(name)
    return self:Save(name)
end

function ThemeManager:Save(name)
    local L = self.Library
    name = tostring(name or ""):gsub("[%c%z/\\]", "")
    if name == "" or not L then
        notify(self, "Invalid theme name", 2)
        return false
    end
    if BuiltIn[name] then
        notify(self, "Cannot overwrite built-in theme", 2)
        return false
    end
    self:EnsureFolder()
    local data = {
        FontColor = fromColor(L.FontColor),
        MainColor = fromColor(L.MainColor),
        BackgroundColor = fromColor(L.BackgroundColor),
        AccentColor = fromColor(L.AccentColor),
        OutlineColor = fromColor(L.OutlineColor),
        RiskColor = fromColor(L.RiskColor or Color3.fromRGB(255, 50, 50)),
    }
    if writefile then
        writefile(self.Folder .. "/" .. name .. ".json", HttpService:JSONEncode(data))
        notify(self, 'Theme "' .. name .. '" created/saved')
        return true
    end
    notify(self, "writefile unavailable", 2)
    return false
end

function ThemeManager:Delete(name)
    name = tostring(name or "")
    if BuiltIn[name] then
        notify(self, "Cannot delete built-in theme", 2)
        return false
    end
    local path = self.Folder .. "/" .. name .. ".json"
    if delfile and isfile and isfile(path) then
        delfile(path)
        notify(self, 'Theme "' .. name .. '" deleted')
        return true
    end
    notify(self, "Delete failed", 2)
    return false
end

function ThemeManager:SetAutoLoad(name, enabled)
    self:EnsureFolder()
    if enabled and name and name ~= "" then
        self.AutoLoadName = name
        if writefile then writefile(self.Folder .. "/_autoload.txt", name) end
        notify(self, 'Theme auto-load: "' .. name .. '"')
    else
        self.AutoLoadName = nil
        if writefile then writefile(self.Folder .. "/_autoload.txt", "") end
        notify(self, "Theme auto-load off")
    end
end

function ThemeManager:TryAutoLoad()
    if not (readfile and isfile) then return end
    local meta = self.Folder .. "/_autoload.txt"
    if isfile(meta) then
        local name = readfile(meta)
        if name and name ~= "" then self:Load(name) end
    end
end

function ThemeManager:RefreshDropdown()
    pcall(function()
        if Options and Options.LuaXThemeList and Options.LuaXThemeList.SetValues then
            Options.LuaXThemeList:SetValues(self:GetThemeList())
        end
    end)
end

function ThemeManager:ApplyToGroupbox(Groupbox)
    local L = self.Library
    if not Groupbox or not L then return end

    Groupbox:AddDropdown("LuaXThemeList", {
        Values = self:GetThemeList(),
        Default = 1,
        Text = "Theme list",
    })
    Groupbox:AddInput("LuaXThemeName", { Text = "Theme name", Default = "MyTheme" })
    Groupbox:AddButton("Create Theme", function()
        local n = Options.LuaXThemeName and Options.LuaXThemeName.Value or "MyTheme"
        self:Create(n)
        self:RefreshDropdown()
    end)
    Groupbox:AddButton("Save Theme", function()
        local n = Options.LuaXThemeName and Options.LuaXThemeName.Value or "MyTheme"
        self:Save(n)
        self:RefreshDropdown()
    end)
    Groupbox:AddButton("Load Theme", function()
        local n = Options.LuaXThemeList and Options.LuaXThemeList.Value
        if type(n) == "table" then n = n[1] end
        self:Load(tostring(n or ""))
    end)
    Groupbox:AddButton("Delete Theme", function()
        local n = Options.LuaXThemeList and Options.LuaXThemeList.Value
        if type(n) == "table" then n = n[1] end
        self:Delete(tostring(n or ""))
        self:RefreshDropdown()
    end)
    Groupbox:AddToggle("LuaXThemeAutoLoad", {
        Text = "Auto Load Selected Theme",
        Default = false,
        Callback = function(V)
            local n = Options.LuaXThemeList and Options.LuaXThemeList.Value
            if type(n) == "table" then n = n[1] end
            self:SetAutoLoad(tostring(n or ""), V)
        end,
    })
    Groupbox:AddButton("Refresh List", function()
        self:RefreshDropdown()
        notify(self, "Theme list refreshed")
    end)
end

function ThemeManager:ApplyToTab(Tab)
    if Tab then self:ApplyToGroupbox(Tab:AddLeftGroupbox("Theme Manager")) end
end

return ThemeManager
