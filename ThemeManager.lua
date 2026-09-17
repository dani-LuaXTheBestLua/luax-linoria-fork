--[[
    Lua X ThemeManager — works with Linoria-style Library
    Saves/loads themes as .json under LuaXThemes/
]]

local HttpService = game:GetService("HttpService")

local ThemeManager = {
    Folder = "LuaXThemes",
    Library = nil,
    Themes = {},
}

local BuiltIn = {
    Primordial = {
        FontColor = {255, 255, 255},
        MainColor = {24, 24, 24},
        BackgroundColor = {18, 18, 18},
        AccentColor = {220, 150, 180},
        OutlineColor = {40, 40, 40},
        RiskColor = {255, 50, 50},
    },
    BlackWhite = {
        FontColor = {255, 255, 255},
        MainColor = {25, 25, 25},
        BackgroundColor = {15, 15, 15},
        AccentColor = {255, 255, 255},
        OutlineColor = {55, 55, 55},
        RiskColor = {255, 60, 60},
    },
    DarkBlue = {
        FontColor = {230, 235, 255},
        MainColor = {18, 22, 32},
        BackgroundColor = {12, 14, 20},
        AccentColor = {70, 140, 255},
        OutlineColor = {40, 50, 70},
        RiskColor = {255, 50, 50},
    },
    Red = {
        FontColor = {255, 240, 240},
        MainColor = {28, 20, 20},
        BackgroundColor = {18, 12, 12},
        AccentColor = {220, 60, 60},
        OutlineColor = {60, 40, 40},
        RiskColor = {255, 80, 80},
    },
    Green = {
        FontColor = {235, 255, 240},
        MainColor = {20, 28, 22},
        BackgroundColor = {12, 18, 14},
        AccentColor = {80, 200, 120},
        OutlineColor = {40, 55, 45},
        RiskColor = {255, 50, 50},
    },
}

local function toColor(t)
    if typeof(t) == "Color3" then return t end
    if type(t) == "table" then
        return Color3.fromRGB(t[1] or 255, t[2] or 255, t[3] or 255)
    end
    return Color3.fromRGB(255, 255, 255)
end

local function fromColor(c)
    return {
        math.floor(c.R * 255 + 0.5),
        math.floor(c.G * 255 + 0.5),
        math.floor(c.B * 255 + 0.5),
    }
end

function ThemeManager:SetLibrary(Library)
    self.Library = Library
end

function ThemeManager:EnsureFolder()
    if makefolder and not isfolder(self.Folder) then
        pcall(makefolder, self.Folder)
    end
end

function ThemeManager:GetThemeList()
    local list = {}
    for name in pairs(BuiltIn) do
        table.insert(list, name)
    end
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

function ThemeManager:ApplyTable(data)
    local L = self.Library
    if not L or type(data) ~= "table" then return end
    if data.FontColor then L.FontColor = toColor(data.FontColor) end
    if data.MainColor then L.MainColor = toColor(data.MainColor) end
    if data.BackgroundColor then L.BackgroundColor = toColor(data.BackgroundColor) end
    if data.AccentColor then
        L.AccentColor = toColor(data.AccentColor)
        L.AccentColorDark = L:GetDarkerColor(L.AccentColor)
    end
    if data.OutlineColor then L.OutlineColor = toColor(data.OutlineColor) end
    if data.RiskColor then L.RiskColor = toColor(data.RiskColor) end
    pcall(function() L:UpdateColorsUsingRegistry() end)
    pcall(function()
        if L.SetGlass and L.GlassEnabled then
            L:SetGlass(true, L.GlassTransparency or 0.28)
        end
    end)
end

function ThemeManager:Apply(name)
    if BuiltIn[name] then
        self:ApplyTable(BuiltIn[name])
        if self.Library and self.Library.Notify then
            self.Library:Notify('Theme "' .. name .. '" applied')
        end
        return true
    end
    self:EnsureFolder()
    local path = self.Folder .. "/" .. name .. ".json"
    if isfile and isfile(path) then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(path))
        end)
        if ok and type(data) == "table" then
            self:ApplyTable(data)
            if self.Library and self.Library.Notify then
                self.Library:Notify('Theme "' .. name .. '" loaded')
            end
            return true
        end
    end
    if self.Library and self.Library.Notify then
        self.Library:Notify("Theme not found", 2)
    end
    return false
end

function ThemeManager:Save(name)
    local L = self.Library
    if not L or not name or name == "" then return false end
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
        if L.Notify then L:Notify('Theme "' .. name .. '" saved') end
        return true
    end
    if L.Notify then L:Notify("writefile unavailable", 2) end
    return false
end

function ThemeManager:Delete(name)
    if BuiltIn[name] then
        if self.Library and self.Library.Notify then
            self.Library:Notify("Cannot delete built-in theme", 2)
        end
        return false
    end
    local path = self.Folder .. "/" .. name .. ".json"
    if delfile and isfile and isfile(path) then
        delfile(path)
        if self.Library and self.Library.Notify then
            self.Library:Notify('Theme "' .. name .. '" deleted')
        end
        return true
    end
    return false
end

function ThemeManager:GetCurrentTable()
    local L = self.Library
    if not L then return {} end
    return {
        FontColor = fromColor(L.FontColor),
        MainColor = fromColor(L.MainColor),
        BackgroundColor = fromColor(L.BackgroundColor),
        AccentColor = fromColor(L.AccentColor),
        OutlineColor = fromColor(L.OutlineColor),
        RiskColor = fromColor(L.RiskColor or Color3.fromRGB(255, 50, 50)),
    }
end

function ThemeManager:ApplyToGroupbox(Groupbox)
    local L = self.Library
    if not Groupbox or not L then return end

    Groupbox:AddDropdown("LuaXThemeList", {
        Values = self:GetThemeList(),
        Default = 1,
        Text = "Theme list",
        Callback = function() end,
    })
    Groupbox:AddButton("Refresh Theme List", function()
        if Options.LuaXThemeList and Options.LuaXThemeList.SetValues then
            Options.LuaXThemeList:SetValues(self:GetThemeList())
        end
        L:Notify("Theme list refreshed")
    end)
    Groupbox:AddButton("Load Theme", function()
        local n = Options.LuaXThemeList and Options.LuaXThemeList.Value
        if type(n) == "table" then n = n[1] end
        self:Apply(tostring(n or ""))
    end)
    Groupbox:AddInput("LuaXThemeName", { Text = "Theme name", Default = "MyTheme" })
    Groupbox:AddButton("Save Theme", function()
        local n = Options.LuaXThemeName and Options.LuaXThemeName.Value or "MyTheme"
        self:Save(n)
        if Options.LuaXThemeList and Options.LuaXThemeList.SetValues then
            Options.LuaXThemeList:SetValues(self:GetThemeList())
        end
    end)
    Groupbox:AddButton("Delete Theme", function()
        local n = Options.LuaXThemeList and Options.LuaXThemeList.Value
        if type(n) == "table" then n = n[1] end
        self:Delete(tostring(n or ""))
        if Options.LuaXThemeList and Options.LuaXThemeList.SetValues then
            Options.LuaXThemeList:SetValues(self:GetThemeList())
        end
    end)
    Groupbox:AddButton("Apply Primordial", function()
        self:Apply("Primordial")
    end)
end

function ThemeManager:ApplyToTab(Tab)
    if not Tab then return end
    local box = Tab:AddLeftGroupbox("Theme Manager")
    self:ApplyToGroupbox(box)
end

return ThemeManager
