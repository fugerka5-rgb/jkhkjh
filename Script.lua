-- ========= [ Fluent UI и менеджеры ] =========
local Library = loadstring(game:HttpGetAsync("https://github.com/1dontgiveaf/Fluent-Renewed/releases/download/v1.0/Fluent.luau"))()
local SaveManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/1dontgiveaf/Fluent-Renewed/refs/heads/main/Addons/SaveManager.luau"))()
local InterfaceManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/1dontgiveaf/Fluent-Renewed/refs/heads/main/Addons/InterfaceManager.luau"))()

-- ========= [ Services / utils ] =========
local HttpService       = game:GetService("HttpService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")

local plr  = Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local hum  = char:WaitForChild("Humanoid")
local root = char:WaitForChild("HumanoidRootPart")

local function ensureChar()
    char = plr.Character or plr.CharacterAdded:Wait()
    hum  = char:WaitForChild("Humanoid")
    root = char:WaitForChild("HumanoidRootPart")
end
plr.CharacterAdded:Connect(function() task.defer(ensureChar) end)

-- ========= [ Packets (без ошибок, если модуля нет) ] =========
local packets do
    local ok, mod = pcall(function() return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Packets")) end)
    packets = ok and mod or {}
end
local function swingtool(eids)
    if type(eids) ~= "table" then eids = { eids } end
    if packets and packets.SwingTool and packets.SwingTool.send then
        pcall(function() packets.SwingTool.send(eids) end)
    end
end
local function pickup(eid)
    if packets and packets.Pickup and packets.Pickup.send then
        pcall(function() packets.Pickup.send(eid) end)
    end
end

-- ========= [ Window / Tabs ] =========
local Window = Library:CreateWindow{
    Title = "Fuger Hub -- Booga Booga Reborn",
    SubTitle = "by Fuger XD",
    Size = UDim2.fromOffset(840, 560),
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
}
local Tabs = {}
Tabs.Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })

-- менеджеры
SaveManager:SetLibrary(Library)
InterfaceManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/specific-game")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

-- ========= [ Helpers ] =========
local function sanitize(name)
    name = tostring(name or ""):gsub("[%c\\/:*?\"<>|]+",""):gsub("^%s+",""):gsub("%s+$","")
    return name == "" and "default" or name
end

-- === [ RouteLock: общий замок для Route/Follow — убирает чужие силы ] ===
_G.__ROUTE_LOCK = _G.__ROUTE_LOCK or {count = 0, active = false}
local function RouteLock(on)
    local L = _G.__ROUTE_LOCK
    if on then L.count = L.count + 1 else L.count = math.max(0, L.count - 1) end
    L.active = (L.count > 0)

    local c = Players.LocalPlayer.Character
    local r = c and c:FindFirstChild("HumanoidRootPart")
    if r and L.active then
        for _,o in ipairs(r:GetChildren()) do
            if o:IsA("BodyVelocity") or o:IsA("LinearVelocity")
            or o:IsA("VectorForce")  or o:IsA("BodyForce")
            or o:IsA("BodyThrust") then
                o:Destroy()
            end
        end
        local a = r:FindFirstChild("_MV_BV");    if a then a:Destroy() end
        local b = r:FindFirstChild("_ROUTE_BV"); if b then b:Destroy() end
        local c1 = r:FindFirstChild("_FLW_BV");  if c1 then c1:Destroy() end
        r.Anchored = false
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then h.PlatformStand = false end
    end
    return L.active
end

-- ========= [ ROUTE persist (save/load) ] =========
local function routePath(cfg) return "FluentScriptHub/specific-game/"..sanitize(cfg)..".route.json" end
local ROUTE_AUTOSAVE = "FluentScriptHub/specific-game/_route_autosave.json"

local function encodeRoute(points)
    local t = {}
    for i,p in ipairs(points or {}) do
        t[i] = {
            x = p.pos.X, y = p.pos.Y, z = p.pos.Z,
            wait = p.wait or 0,
            js = p.jump_start and true or nil,
            je = p.jump_end   and true or nil,
        }
    end
    return t
end
local function decodeRoute(t)
    local out = {}
    for _,r in ipairs(t or {}) do
        table.insert(out, {
            pos = Vector3.new(r.x, r.y, r.z),
            wait = (r.wait and r.wait > 0) and r.wait or nil,
            jump_start = r.js or nil,
            jump_end   = r.je or nil
        })
    end
    return out
end
function Route_SaveToFile(path, points)
    if not writefile then return false end
    local ok, json = pcall(function() return HttpService:JSONEncode(encodeRoute(points)) end)
    if not ok then return false end
    local ok2 = pcall(writefile, path, json)
    return ok2 == true or ok2 == nil
end
function Route_LoadFromFile(path, Route, redraw)
    if not (isfile and readfile) or not isfile(path) then return false end
    local ok, json = pcall(readfile, path); if not ok then return false end
    local ok2, arr = pcall(function() return HttpService:JSONDecode(json) end); if not ok2 then return false end
    table.clear(Route.points)
    if redraw and redraw.clearDots then redraw.clearDots() end
    for _,p in ipairs(decodeRoute(arr)) do
        table.insert(Route.points, p)
        if redraw and redraw.dot then redraw.dot(Color3.fromRGB(255,230,80), p.pos, 0.7) end
    end
    return true
end

-- ========= [ Общие инвентарь/еды ] =========
function findInventoryList()
    local pg = plr:FindFirstChild("PlayerGui"); if not pg then return nil end
    local mg = pg:FindFirstChild("MainGui");    if not mg then return nil end
    local rp = mg:FindFirstChild("RightPanel"); if not rp then return nil end
    local inv = rp:FindFirstChild("Inventory"); if not inv then return nil end
    return inv:FindFirstChild("List")
end
function getSlotByName(itemName)
    local list = findInventoryList()
    if not list then return nil end
    for _,child in ipairs(list:GetChildren()) do
        if child:IsA("ImageLabel") and child.Name == itemName then
            return child.LayoutOrder
        end
    end
    return nil
end
function consumeBySlot(slot)
    if not slot then return false end
    if packets and packets.UseBagItem     and packets.UseBagItem.send     then pcall(function() packets.UseBagItem.send(slot) end);     return true end
    if packets and packets.ConsumeBagItem and packets.ConsumeBagItem.send then pcall(function() packets.ConsumeBagItem.send(slot) end); return true end
    if packets and packets.ConsumeItem    and packets.ConsumeItem.send    then pcall(function() packets.ConsumeItem.send(slot) end);    return true end
    if packets and packets.UseItem        and packets.UseItem.send        then pcall(function() packets.UseItem.send(slot) end);        return true end
    return false
end
_G.fruittoitemid = _G.fruittoitemid or {
    Bloodfruit = 94, Bluefruit = 377, Lemon = 99, Coconut = 1, Jelly = 604,
    Banana = 606, Orange = 602, Oddberry = 32, Berry = 35, Strangefruit = 302,
    Strawberry = 282, Sunfruit = 128, Pumpkin = 80, ["Prickly Pear"] = 378,
    Apple = 243, Barley = 247, Cloudberry = 101, Carrot = 147
}
function getItemIdByName(name) local t=_G.fruittoitemid return t and t[name] or nil end
function consumeById(id)
    if not id then return false end
    if packets and packets.ConsumeItem and packets.ConsumeItem.send then pcall(function() packets.ConsumeItem.send(id) end); return true end
    if packets and packets.UseItem     and packets.UseItem.send     then pcall(function() packets.UseItem.send({itemID = id}) end); return true end
    if packets and packets.Eat         and packets.Eat.send         then pcall(function() packets.Eat.send(id) end); return true end
    if packets and packets.EatFood     and packets.EatFood.send     then pcall(function() packets.EatFood.send(id) end); return true end
    return false
end

-- ========= [ TAB: Configs ] =========
Tabs.Configs = Window:AddTab({ Title = "Configs", Icon = "save" })

local cfgName = "default"
local cfgInput = Tabs.Configs:AddInput("cfg_name_input", { Title="Config name", Default=cfgName })
cfgInput:OnChanged(function(v) cfgName = sanitize(v) end)

Tabs.Configs:CreateButton({
    Title = "Quick Save",
    Callback = function()
        local n = sanitize(cfgName)
        pcall(function() SaveManager:Save(n) end)
        Route_SaveToFile(routePath(n), (_G.__ROUTE and _G.__ROUTE.points) or {})
        Route_SaveToFile(ROUTE_AUTOSAVE, (_G.__ROUTE and _G.__ROUTE.points) or {})
        Library:Notify{ Title="Configs", Content="Saved "..n.." (+route)", Duration=3 }
    end
})
Tabs.Configs:CreateButton({
    Title = "Quick Load",
    Callback = function()
        local n = sanitize(cfgName)
        pcall(function() SaveManager:Load(n) end)
        if _G.__ROUTE then
            local ok = Route_LoadFromFile(routePath(n), _G.__ROUTE, _G.__ROUTE._redraw)
            Library:Notify{
                Title="Configs",
                Content="Loaded "..n..(ok and " +route" or " (no route file)"),
                Duration=3
            }
        else
            Library:Notify{ Title="Configs", Content="Loaded "..n, Duration=3 }
        end
    end
})
local auto = Tabs.Configs:CreateToggle("autoload_cfg", { Title="Autoload this config", Default=true })
auto:OnChanged(function(v)
    local n = sanitize(cfgName)
    if v then pcall(function() SaveManager:SaveAutoloadConfig(n) end)
    else pcall(function() SaveManager:DeleteAutoloadConfig() end) end
end)

-- === [ переносимый экспорт/импорт ROUTE ] ===
do
    local function Route_ToString()
        local arr = encodeRoute((_G.__ROUTE and _G.__ROUTE.points) or {})
        local ok, json = pcall(function() return HttpService:JSONEncode(arr) end)
        return ok and json or "[]"
    end
    local function Route_FromString(str)
        if type(str) ~= "string" or str == "" then return false, "empty" end
        local ok, t = pcall(function() return HttpService:JSONDecode(str) end)
        if not ok or type(t) ~= "table" then return false, "bad json" end
        if not _G.__ROUTE then return false, "no route obj" end
        local points = decodeRoute(t)
        table.clear(_G.__ROUTE.points)
        if _G.__ROUTE._redraw and _G.__ROUTE._redraw.clearDots then _G.__ROUTE._redraw.clearDots() end
        for _,p in ipairs(points) do
            table.insert(_G.__ROUTE.points, p)
            if _G.__ROUTE._redraw and _G.__ROUTE._redraw.dot then
                _G.__ROUTE._redraw.dot(Color3.fromRGB(255,230,80), p.pos, 0.7)
            end
        end
        if _G.__ROUTE._redraw and _G.__ROUTE._redraw.redrawLines then
            _G.__ROUTE._redraw.redrawLines()
        end
        return true
    end

    local routeStr = ""
    local routeInput = Tabs.Configs:AddInput("cfg_route_string", {
        Title="Route JSON (paste here to import)",
        Default="",
        Placeholder="сюда вставь длинную строку JSON маршрута"
    })
    routeInput:OnChanged(function(v) routeStr = tostring(v or "") end)

    Tabs.Configs:CreateButton({
        Title="Fill input from CURRENT route",
        Callback=function()
            local s = Route_ToString()
            routeStr = s
            routeInput:SetValue(s)
            Library:Notify{ Title="Route", Content="Input filled from current route", Duration=2 }
        end
    })
    Tabs.Configs:CreateButton({
        Title="Copy CURRENT route (JSON) to Clipboard",
        Callback=function()
            local s = Route_ToString()
            if setclipboard then
                pcall(setclipboard, s)
                Library:Notify{ Title="Route", Content="Copied to clipboard!", Duration=2 }
            else
                print("[ROUTE JSON]\n"..s)
                Library:Notify{ Title="Route", Content="setclipboard недоступен — строка в F9", Duration=4 }
            end
        end
    })
    Tabs.Configs:CreateButton({
        Title="Load route from INPUT (replace current)",
        Callback=function()
            local ok, err = Route_FromString(routeStr)
            if ok then
                Library:Notify{ Title="Route", Content="Route loaded from input", Duration=3 }
                pcall(function() Route_SaveToFile(ROUTE_AUTOSAVE, _G.__ROUTE.points) end)
            else
                Library:Notify{ Title="Route", Content="Import failed: "..tostring(err), Duration=4 }
            end
        end
    })
end

-- ========= [ TAB: Survival (Auto-Eat) ] =========
Tabs.Survival = Window:AddTab({ Title="Survival", Icon="apple" })
local ae_toggle = Tabs.Survival:CreateToggle("ae_toggle", { Title="Auto Eat (Hunger)", Default=false })
local ae_food   = Tabs.Survival:CreateDropdown("ae_food", { Title="Food to eat",
    Values={"Bloodfruit","Berry","Bluefruit","Coconut","Strawberry","Pumpkin","Apple","Lemon","Orange","Banana"},
    Default="Bloodfruit" })
local ae_thresh = Tabs.Survival:CreateSlider("ae_thresh", { Title="Setpoint / Threshold (%)", Min=1, Max=100, Rounding=0, Default=70 })
local ae_mode   = Tabs.Survival:CreateDropdown("ae_mode", { Title="Scale mode", Values={"Fullness 100→0","Hunger 0→100"}, Default="Fullness 100→0" })
local ae_debug  = Tabs.Survival:CreateToggle("ae_debug", { Title="Debug logs (F9)", Default=false })

local function normPct(n) if type(n)~="number" then return nil end if n<=1.5 then n=n*100 end return math.clamp(n,0,100) end
local function readHungerFromValues() for _,v in ipairs(plr:GetDescendants()) do if v.Name=="Hunger" and (v:IsA("NumberValue") or v:IsA("IntValue")) then return normPct(v.Value) end end end
local function readHungerFromBar()
    local pg=plr:FindFirstChild("PlayerGui"); if not pg then return end
    local mg=pg:FindFirstChild("MainGui"); if not mg then return end
    local bars=mg:FindFirstChild("Bars"); if not bars then return end
    local hb=bars:FindFirstChild("Hunger")
    if hb and hb:IsA("Frame") and hb.Size and hb.Size.X and typeof(hb.Size.X.Scale)=="number" then
        return normPct(hb.Size.X.Scale)
    end
end
local function readHungerFromText()
    local pg=plr:FindFirstChild("PlayerGui"); if not pg then return end
    for _,inst in ipairs(pg:GetDescendants()) do
        if inst:IsA("TextLabel") then
            local txt=tostring(inst.Text or ""):lower()
            if txt:find("голод") or inst.Name:lower():find("hunger") or (inst.Parent and inst.Parent.Name:lower():find("hunger")) then
                local num=tonumber(txt:match("([-+]?%d+%.?%d*)"))
                if num and num>=0 and num<=100 then return num end
            end
        end
    end
end
local function readHungerFromAttr() local a=plr:GetAttribute("Hunger") if typeof(a)=="number" then return normPct(a) end end
local function readHungerPercent() return readHungerFromValues() or readHungerFromBar() or readHungerFromText() or readHungerFromAttr() or 100 end

local eatingLock=false
task.spawn(function()
    while true do
        task.wait(0.2)
        if not ae_toggle.Value then continue end
        local target=ae_thresh.Value
        local mode=ae_mode.Value
        local cur=readHungerPercent()
        local need = (mode=="Fullness 100→0" and cur<target) or (mode=="Hunger 0→100" and cur>target)
        if need and not eatingLock then
            eatingLock=true
            task.spawn(function()
                local tries, maxTries = 0, 25
                local minDelay, band = 0.15, 0.5
                while ae_toggle.Value and tries<maxTries do
                    cur=readHungerPercent()
                    local okNow=(mode=="Fullness 100→0" and cur>=target-band) or (mode=="Hunger 0→100" and cur<=target+band)
                    if okNow then if ae_debug.Value then print(("[AutoEat] reached: %.1f / %d (%s)"):format(cur,target,mode)) end; break end
                    local food=ae_food.Value or "Bloodfruit"
                    local ate=consumeBySlot(getSlotByName(food)) or consumeById(getItemIdByName(food))
                    if ae_debug.Value then print(("[AutoEat] try=%d -> %s"):format(tries + 1, ate and "EAT" or "MISS")) end
                    tries = tries + 1; task.wait(minDelay)
                end
                eatingLock=false
            end)
        end
    end
end)

-- ========= [ TAB: Break (Radius) — v2 (cached, low-lag, multi-swing) ] =========
do
    local BreakTab = Window:AddTab({ Title = "Break (Radius)", Icon = "hammer" })

    local br_auto     = BreakTab:CreateToggle("br_auto",     { Title = "Auto Break (cached)", Default = false })
    local br_range    = BreakTab:CreateSlider("br_range",    { Title = "Range (studs)", Min = 5, Max = 150, Rounding = 0, Default = 35 })
    local br_max      = BreakTab:CreateSlider("br_max",      { Title = "Max targets per swing", Min = 1, Max = 15, Rounding = 0, Default = 8 })
    local br_cd       = BreakTab:CreateSlider("br_cd",       { Title = "Swing cooldown (s)", Min = 0.05, Max = 1.00, Rounding = 2, Default = 0.15 })
    local br_tick     = BreakTab:CreateSlider("br_tick",     { Title = "Scan interval (s)", Min = 0.03, Max = 0.40, Rounding = 2, Default = 0.10 })
    local br_onlyRes  = BreakTab:CreateToggle("br_onlyres",  { Title = "Scan only workspace.Resources", Default = true })

    -- Новые — мульти-удар
    local br_swings   = BreakTab:CreateSlider("br_swings",   { Title = "Swings per tick", Min = 1, Max = 4, Rounding = 0, Default = 2 })
    local br_gap      = BreakTab:CreateSlider("br_gap",      { Title = "Gap between swings (s)", Min = 0.00, Max = 0.20, Rounding = 2, Default = 0.04 })
    local br_retarget = BreakTab:CreateToggle("br_retarget", { Title = "Retarget each swing", Default = false })

    local KNOWN_TARGETS = {
        "Gold Node","Iron Node","Stone Node","Ice Node","Crystal Node",
        "Adurite Node","Magnetite Node","Emerald Node","Pink Diamond Node","Void Stone",
        "Tree","Big Tree","Bush","Boulder","Totem","Chest","Ancient Chest",
        "Shelly","Rock","Log Pile","Leaf Pile","Coal Node"
    }
    local br_black   = BreakTab:CreateToggle("br_black",  { Title = "Use selection as Blacklist (else Whitelist/All)", Default = false })
    local br_list    = BreakTab:CreateDropdown("br_list", { Title = "Targets (multi, optional)", Values = KNOWN_TARGETS, Multi = true, Default = {} })

    -- быстрый вызов свинга
    local function sendSwing(ids)
        if type(ids) ~= "table" then ids = { ids } end
        local ok = false
        if typeof(swingtool) == "function" then ok = pcall(function() swingtool(ids) end) end
        if not ok and packets and packets.SwingTool and packets.SwingTool.send then
            pcall(function() packets.SwingTool.send(ids) end)
        end
    end

    ----------------------------------------------------------------
    -- КЕШ: следим за папками и держим лёгкий список
    ----------------------------------------------------------------
    local cache = {}  -- [instance] = {eid=<number>, getPos=<fn>, name=<string>}
    local watched, conns = {}, {}

    local function addModel(inst)
        if inst:IsA("Model") and inst:FindFirstChildOfClass("Humanoid") then return end
        local eid = inst.GetAttribute and inst:GetAttribute("EntityID"); if not eid then return end

        local getPos
        if inst:IsA("Model") then
            local pp = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")
            if not pp then return end
            getPos = function() return pp.Position end
        elseif inst:IsA("BasePart") or inst:IsA("MeshPart") then
            getPos = function() return inst.Position end
        else
            return
        end

        local nm = inst.Name
        if inst.GetAttribute then
            nm = inst:GetAttribute("DisplayName") or inst:GetAttribute("Name") or nm
        end

        cache[inst] = { eid = eid, getPos = getPos, name = nm, dist = math.huge }
    end

    local function removeModel(inst)
        cache[inst] = nil
    end

    local function hookFolder(folder)
        if not folder or watched[folder] then return end
        watched[folder] = true
        for _,ch in ipairs(folder:GetChildren()) do addModel(ch) end
        conns[#conns+1] = folder.ChildAdded:Connect(addModel)
        conns[#conns+1] = folder.ChildRemoved:Connect(removeModel)
    end

    local function refreshFolders()
        hookFolder(workspace:FindFirstChild("Resources"))
        if not br_onlyRes.Value then hookFolder(workspace) end
    end
    refreshFolders()
    br_onlyRes:OnChanged(function()
        for _,c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        table.clear(conns); table.clear(watched); table.clear(cache)
        refreshFolders()
    end)

    ----------------------------------------------------------------
    -- Селектор целей
    ----------------------------------------------------------------
    local selSet, useBlack = nil, false
    local function compileSelector()
        local val = br_list.Value
        local hasAny = (type(val)=="table") and next(val) ~= nil
        if not hasAny then selSet = nil; return end
        selSet = {}
        for k,v in pairs(val) do if v then selSet[string.lower(k)] = true end end
    end
    compileSelector()
    br_list:OnChanged(compileSelector)
    br_black:OnChanged(function(v) useBlack = v end)

    ----------------------------------------------------------------
    -- Раннер
    ----------------------------------------------------------------
    task.spawn(function()
        while true do
            if br_auto.Value and root and root.Parent then
                local range   = br_range.Value
                local maxHit  = br_max.Value

                -- Собираем и частично ограничиваем кандидатов
                local candidates = {}
                local myPos = root.Position
                for inst, info in pairs(cache) do
                    if inst.Parent then
                        local pos = info.getPos()
                        local d   = (pos - myPos).Magnitude
                        if d <= range then
                            local pass = true
                            if selSet then
                                local inSel = selSet[string.lower(info.name or "")]
                                pass = (useBlack and (not inSel)) or ((not useBlack) and inSel)
                            elseif useBlack then
                                pass = true -- пустой blacklist => ломаем всё
                            end
                            if pass then
                                info.dist = d
                                candidates[#candidates+1] = info
                                if #candidates >= (maxHit * 3) then break end
                            end
                        end
                    end
                end

                if #candidates > maxHit then
                    table.sort(candidates, function(a,b) return a.dist < b.dist end)
                end

                -- первичный пакет целей
                local ids = {}
                for i = 1, math.min(maxHit, #candidates) do
                    ids[#ids+1] = candidates[i].eid
                end

                -- мульти-удар за тик
                local swings = math.max(1, math.floor(br_swings.Value))
                if #ids > 0 then
                    for s = 1, swings do
                        if br_retarget.Value and s > 1 then
                            -- быстрый ретаргет: обновим дистанции и пересоберём ids
                            myPos = root.Position
                            for j = 1, #candidates do
                                local c = candidates[j]
                                c.dist = (c.getPos() - myPos).Magnitude
                            end
                            if #candidates > 1 then
                                table.sort(candidates, function(a,b) return a.dist < b.dist end)
                            end
                            table.clear(ids)
                            for i = 1, math.min(maxHit, #candidates) do
                                ids[#ids+1] = candidates[i].eid
                            end
                        end

                        sendSwing(ids)

                        local g = br_gap.Value
                        if g > 0 then task.wait(g) end
                    end
                end

                task.wait(br_cd.Value + br_tick.Value)
            else
                task.wait(0.15)
            end
        end
    end)
end


-- ========= [ TAB: Route (плавный подъём по Y как в Movement, без автопрыжка) ] =========
Tabs.Route = Window:AddTab({ Title = "Route", Icon = "route" })

local R_gap     = Tabs.Route:CreateSlider("r_gap",     { Title="Point gap (studs)", Min=0.5, Max=8, Rounding=2, Default=2 })
local R_spd     = Tabs.Route:CreateSlider("r_spd",     { Title="Follow speed",      Min=6, Max=40, Rounding=1, Default=20 })
local R_loop    = Tabs.Route:CreateToggle("r_loop",    { Title="Loop back & forth", Default=true })
local R_click   = Tabs.Route:CreateToggle("r_click",   { Title="Add points by mouse click", Default=false })
local R_light   = Tabs.Route:CreateToggle("r_light",   { Title="Lightweight visuals", Default=true })
local R_maxDots = Tabs.Route:CreateSlider("r_maxdots", { Title="Max dots on screen", Min=50, Max=800, Rounding=0, Default=300 })

-- НОВОЕ: параметры плавного подъёма
local R_liftY   = Tabs.Route:CreateSlider("r_lifty",   { Title="Base lift above path (studs)", Min=0, Max=12, Rounding=1, Default=1.5 })
local R_yGain   = Tabs.Route:CreateSlider("r_ygain",   { Title="Vertical gain (responsiveness)", Min=0.5, Max=8, Rounding=1, Default=2.6 })
local R_yMax    = Tabs.Route:CreateSlider("r_ymax",    { Title="Max vertical speed", Min=2, Max=25, Rounding=0, Default=10 })
local R_yDamp   = Tabs.Route:CreateSlider("r_ydamp",   { Title="Smoothing (0=no, 0.9=очень плавно)", Min=0, Max=0.95, Rounding=2, Default=0.55 })

local Route = { points = {}, recording=false, running=false, _hb=nil, _jump=nil, _click=nil, _lastPos=nil, _idleT0=nil, _vy=0 }
_G.__ROUTE = Route

local routeFolder = Workspace:FindFirstChild("_ROUTE_DOTS")  or Instance.new("Folder", Workspace); routeFolder.Name="_ROUTE_DOTS"
local linesFolder = Workspace:FindFirstChild("_ROUTE_LINES") or Instance.new("Folder", Workspace); linesFolder.Name="_ROUTE_LINES"
local COL_Y=Color3.fromRGB(255,230,80); local COL_R=Color3.fromRGB(230,75,75); local COL_B=Color3.fromRGB(90,155,255); local COL_L=Color3.fromRGB(255,200,70)

local DOT_POOL, DOT_USED, DOT_QUEUE = {}, {}, {}
local function allocDot()
    local p = table.remove(DOT_POOL) or Instance.new("Part")
    p.Name="_route_dot"; p.Anchored=true; p.CanCollide=false; p.CanQuery=false; p.CanTouch=false
    p.Shape=Enum.PartType.Ball
    p.Material = R_light.Value and Enum.Material.SmoothPlastic or Enum.Material.Neon
    p.CastShadow = not R_light.Value
    p.Transparency = R_light.Value and 0.35 or 0.1
    p.Parent = routeFolder
    DOT_USED[p]=true; table.insert(DOT_QUEUE,p)
    local cap = (R_maxDots and R_maxDots.Value) or 300
    while #DOT_QUEUE > cap do
        local old = table.remove(DOT_QUEUE,1)
        DOT_USED[old]=nil; old.Parent=nil; table.insert(DOT_POOL, old)
    end
    return p
end
local function dot(color,pos,size)
    local p=allocDot(); p.Color=color
    local s=size or (R_light.Value and 0.45 or 0.6)
    p.Size=Vector3.new(s,s,s); p.CFrame=CFrame.new(pos + Vector3.new(0,0.12,0))
end
local function clearDots() for p,_ in pairs(DOT_USED) do DOT_USED[p]=nil; p.Parent=nil; table.insert(DOT_POOL,p) end; table.clear(DOT_QUEUE) end
local function clearLines() for _,c in ipairs(linesFolder:GetChildren()) do c:Destroy() end end
local function makeSeg(a,b)
    local seg=Instance.new("Part")
    seg.Name="_route_line"; seg.Anchored=true; seg.CanCollide=false; seg.CanQuery=false; seg.CanTouch=false
    seg.Material = R_light.Value and Enum.Material.SmoothPlastic or Enum.Material.Neon
    seg.Color=COL_L; seg.Transparency= R_light.Value and 0.45 or 0.2; seg.CastShadow = not R_light.Value
    local mid=(a+b)/2; local dir=(b-a); local dist=dir.Magnitude
    seg.Size=Vector3.new(0.12,0.12, math.max(0.05, dist))
    seg.CFrame = CFrame.lookAt(mid, b); seg.Parent=linesFolder
end
local function redrawLines()
    clearLines()
    for i=1,#Route.points-1 do makeSeg(Route.points[i].pos, Route.points[i+1].pos) end
    if R_loop.Value and #Route.points>=2 then makeSeg(Route.points[#Route.points].pos, Route.points[1].pos) end
end
Route._redraw = { clearDots=clearDots, dot=dot, clearLines=clearLines, redrawLines=redrawLines }

local function ui(msg) pcall(function() Library:Notify{ Title="Route", Content=tostring(msg), Duration=2 } end) end
local function pushPoint(pos,flags)
    local r={pos=pos}; if flags then for k,v in pairs(flags) do r[k]=v end end
    table.insert(Route.points, r)
    local col = (r.jump_start or r.jump_end) and COL_B or (r.wait and COL_R or COL_Y)
    dot(col,pos, R_light.Value and 0.45 or 0.6)
    if not Route.recording then redrawLines() end
end

-- === BV для follow (с мягкой вертикалью) ===
local ROUTE_BV_NAME="_ROUTE_BV"
local function getRouteBV() return root and root:FindFirstChild(ROUTE_BV_NAME) or nil end
local function ensureRouteBV()
    ensureChar(); if not (root and root.Parent) then return end
    local bv=getRouteBV()
    if not bv then
        bv=Instance.new("BodyVelocity"); bv.Name=ROUTE_BV_NAME
        bv.MaxForce = Vector3.new(1e9, 1e5, 1e9) -- умеренная сила по Y
        bv.Velocity = Vector3.new()
        bv.Parent   = root
    end
    return bv
end
local function stopRouteBV() local bv=getRouteBV(); if bv then bv.Velocity=Vector3.new() end end
local function killRouteBV() local bv=getRouteBV(); if bv then bv:Destroy() end end

-- клик-точки
local UIS_click = game:GetService("UserInputService")
local mouse = plr:GetMouse()
local rayParams = RaycastParams.new(); rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = { plr.Character }
local function worldPointFromMouse()
    local cam = workspace.CurrentCamera; if not cam then return end
    local ur = cam:ViewportPointToRay(mouse.X, mouse.Y)
    local hit = workspace:Raycast(ur.Origin, ur.Direction*5000, rayParams)
    if hit then return hit.Position end
    if mouse.Hit then return mouse.Hit.Position end
end
local function startClickAdd()
    if Route._click then Route._click:Disconnect(); Route._click=nil end
    if not R_click.Value then return end
    Route._click = mouse.Button1Down:Connect(function()
        if Route.recording or Route.running then return end
        local p = worldPointFromMouse(); if not p then return end
        if #Route.points==0 then dot(COL_Y,p, R_light.Value and 0.55 or 0.75) end
        pushPoint(p); ui(("added point #%d"):format(#Route.points))
    end)
end

-- ===== Record =====
function _ROUTE_startRecord()
    ensureChar()
    if Route.recording or Route.running then return end
    if not (hum and root and hum.Parent and root.Parent) then return end

    RouteLock(true)
    Route.recording = true
    table.clear(Route.points); clearDots(); clearLines()
    Route._lastPos = root.Position
    Route._idleT0  = nil
    pushPoint(Route._lastPos)

    if Route._jump then Route._jump:Disconnect() end
    Route._jump = hum.StateChanged:Connect(function(_,new)
        if not Route.recording then return end
        if new==Enum.HumanoidStateType.Jumping then
            pushPoint(root.Position, {jump_start=true})
        elseif new==Enum.HumanoidStateType.Landed then
            pushPoint(root.Position, {jump_end=true})
        end
    end)

    if Route._hb then Route._hb:Disconnect() end
    Route._hb = RunService.Heartbeat:Connect(function()
        if not Route.recording then return end
        local cur = root.Position

        -- idle -> WAIT
        local vel    = root.AssemblyLinearVelocity or Vector3.zero
        local planar = Vector3.new(vel.X,0,vel.Z).Magnitude
        local moving = hum.MoveDirection.Magnitude > 0.10
        local onGround = hum.FloorMaterial ~= Enum.Material.Air
        local idle   = onGround and (planar <= 0.25) and (not moving)

        if idle then
            if not Route._idleT0 then
                Route._idleT0 = tick()
                pushPoint(cur, { _pendingWait = true })
                dot(COL_R, cur, R_light.Value and 0.5 or 0.7)
            end
        else
            if Route._idleT0 then
                local dt = tick() - Route._idleT0
                Route._idleT0 = nil
                if dt >= 0.35 then
                    for i = #Route.points, 1, -1 do
                        local p = Route.points[i]
                        if p._pendingWait then p._pendingWait = nil; p.wait = dt; break end
                    end
                else
                    if Route.points[#Route.points] and Route.points[#Route.points]._pendingWait then
                        table.remove(Route.points, #Route.points); redrawLines()
                    end
                end
            end
        end

        if (cur - Route._lastPos).Magnitude >= ((R_gap and R_gap.Value) or 2) then
            pushPoint(cur); Route._lastPos = cur
        end
    end)
    ui("recording…")
end

function _ROUTE_stopRecord()
    if not Route.recording then return end
    Route.recording=false
    if Route._hb   then Route._hb:Disconnect();   Route._hb=nil end
    if Route._jump then Route._jump:Disconnect(); Route._jump=nil end

    if Route._idleT0 then
        local dt = tick() - Route._idleT0
        Route._idleT0 = nil
        if dt >= 0.35 then
            for i = #Route.points, 1, -1 do local p = Route.points[i]
                if p._pendingWait then p._pendingWait=nil; p.wait=dt; break end
            end
        else
            if Route.points[#Route.points] and Route.points[#Route.points]._pendingWait then
                table.remove(Route.points, #Route.points); redrawLines()
            end
        end
    end

    redrawLines()
    RouteLock(false)
    ui(("rec done (%d pts)"):format(#Route.points))
    pcall(function() Route_SaveToFile(ROUTE_AUTOSAVE, Route.points) end)
end

-- ===== Follow (плавный подъём) =====
local function followSeg(p1, p2)
    local bv=ensureRouteBV(); if not bv then return false end
    local speed   = (R_spd and R_spd.Value) or 20
    local stopTol = 1.05
    local ySnap   = 1.2
    local t0      = tick()

    while Route.running do
        if not (root and root.Parent) then ensureChar(); if not (root and root.Parent) then break end end
        local cur = root.Position

        -- Планарное ведение по XZ
        local planar = Vector3.new(p2.X - cur.X, 0, p2.Z - cur.Z)
        local d = planar.Magnitude
        local vPlan = (d>0 and planar.Unit or Vector3.new())*speed

        -- Плавная вертикаль: цель = высота точки + базовый лифт
        local wantY   = p2.Y + ((R_liftY and R_liftY.Value) or 0)
        local err     = wantY - cur.Y
        local targetV = math.clamp(err * ((R_yGain and R_yGain.Value) or 2.6),
                                   -((R_yMax and R_yMax.Value) or 10),
                                   ((R_yMax and R_yMax.Value) or 10))

        -- сглаживаем (инерция), 0 — без сглаживания, ближе к 1 — плавнее
        local damp    = (R_yDamp and R_yDamp.Value) or 0.55
        Route._vy     = Route._vy or 0
        Route._vy     = Route._vy + (targetV - Route._vy) * (1 - damp)

        if d <= stopTol and math.abs(cur.Y - wantY) <= ySnap then
            stopRouteBV(); return true
        end

        bv.Velocity = Vector3.new(vPlan.X, Route._vy, vPlan.Z)

        if tick()-t0>8 then return false end
        RunService.Heartbeat:Wait()
    end
    stopRouteBV(); return false
end

function _ROUTE_startFollow()
    ensureChar()
    if Route.running or Route.recording then return end
    if #Route.points<2 then ui("no route"); return end
    if not (root and root.Parent) then ui("char not ready"); return end

    RouteLock(true)
    Route.running=true
    Route._vy = 0
    ensureRouteBV().Velocity=Vector3.new()

    task.spawn(function()
        while Route.running do
            ui(R_loop.Value and "following (loop from start)" or "following")
            for i=1,#Route.points-1 do
                if not Route.running then break end
                local pt=Route.points[i]
                if pt.wait and pt.wait>0 then stopRouteBV(); task.wait(pt.wait) end
                if not followSeg(pt.pos, Route.points[i+1].pos) then Route.running=false break end
            end
            if Route.running and R_loop.Value then
                followSeg(Route.points[#Route.points].pos, Route.points[1].pos)
            else break end
        end
        stopRouteBV(); killRouteBV(); Route.running=false
        RouteLock(false)
    end)
end

function _ROUTE_stopFollow()
    if not Route.running then return end
    Route.running=false; stopRouteBV(); killRouteBV()
    Route._vy = 0
    pcall(function() if hum then hum:ChangeState(Enum.HumanoidStateType.Running) end end)
    RouteLock(false); ui("stopped")
end

function _ROUTE_clear()
    table.clear(Route.points); clearDots(); clearLines(); stopRouteBV(); killRouteBV(); Route._vy=0; ui("cleared")
end

Tabs.Route:CreateButton({ Title="Start record", Callback=_ROUTE_startRecord })
Tabs.Route:CreateButton({ Title="Stop record",  Callback=_ROUTE_stopRecord  })
Tabs.Route:CreateButton({ Title="Start follow", Callback=_ROUTE_startFollow })
Tabs.Route:CreateButton({ Title="Stop follow",  Callback=_ROUTE_stopFollow  })
Tabs.Route:CreateButton({ Title="Clear route",  Callback=_ROUTE_clear       })
Tabs.Route:CreateButton({
    Title = "Undo last point",
    Callback = function() if #Route.points>0 then table.remove(Route.points,#Route.points); redrawLines(); ui("last point removed") end end
})
R_loop:OnChanged(redrawLines)
R_click:OnChanged(function() startClickAdd(); ui(R_click.Value and "Click-to-add: ON" or "Click-to-add: OFF") end)
startClickAdd()


-- ========= [ TAB: Auto Loot ] =========
Tabs.Loot = Window:AddTab({ Title = "Auto Loot", Icon = "package" })
local LOOT_ITEM_NAMES = {
    "Berry","Bloodfruit","Bluefruit","Lemon","Strawberry","Gold","Raw Gold","Crystal Chunk",
    "Coin","Coins","Coin Stack","Essence","Emerald","Raw Emerald","Pink Diamond",
    "Raw Pink Diamond","Void Shard","Jelly","Magnetite","Raw Magnetite","Adurite","Raw Adurite",
    "Ice Cube","Stone","Iron","Raw Iron","Steel","Hide","Leaves","Log","Wood","Pie"
}
local loot_on        = Tabs.Loot:CreateToggle("loot_on",      { Title="Auto Loot", Default=false })
local loot_range     = Tabs.Loot:CreateSlider("loot_range",   { Title="Range (studs)", Min=5, Max=150, Rounding=0, Default=40 })
local loot_batch     = Tabs.Loot:CreateSlider("loot_batch",   { Title="Max pickups / tick", Min=1, Max=50, Rounding=0, Default=12 })
local loot_cd        = Tabs.Loot:CreateSlider("loot_cd",      { Title="Tick cooldown (s)", Min=0.03, Max=0.4, Rounding=2, Default=0.08 })
local loot_chests    = Tabs.Loot:CreateToggle("loot_chests",  { Title="Also loot chests (Contents)", Default=true })
local loot_blacklist = Tabs.Loot:CreateToggle("loot_black",   { Title="Use selection as Blacklist (else Whitelist)", Default=false })
local loot_debug     = Tabs.Loot:CreateToggle("loot_debug",   { Title="Debug (F9)", Default=false })
local loot_dropdown  = Tabs.Loot:CreateDropdown("loot_items", { Title="Items (multi)", Values=LOOT_ITEM_NAMES, Multi=true, Default={ Leaves=true, Log=true } })

local function safePickup(eid) local ok = pcall(function() pickup(eid) end); if not ok and packets and packets.Pickup and packets.Pickup.send then pcall(function() packets.Pickup.send(eid) end) end end
local DROP_FOLDERS = { "Items","Drops","WorldDrops","Loot","Dropped","Resources" }
local watchedFolders, conns = {}, {}
local cache = {}
local function normalizedName(inst)
    local a; if inst.GetAttribute then a = inst:GetAttribute("ItemName") or inst:GetAttribute("Name") or inst:GetAttribute("DisplayName") end
    if typeof(a) == "string" and a ~= "" then return a end
    return inst.Name
end
local function addDrop(inst)
    if cache[inst] then return end
    local eid = inst.GetAttribute and inst:GetAttribute("EntityID"); if not eid then return end
    local name = normalizedName(inst)
    local getPos
    if inst:IsA("Model") then
        local pp = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart"); if not pp then return end
        getPos = function() return pp.Position end
    elseif inst:IsA("BasePart") or inst:IsA("MeshPart") then getPos = function() return inst.Position end
    else return end
    cache[inst] = { eid = eid, name = name, getPos = getPos }
end
local function removeDrop(inst) cache[inst] = nil end
local function hookFolder(folder)
    if not folder or watchedFolders[folder] then return end
    watchedFolders[folder] = true
    for _,ch in ipairs(folder:GetChildren()) do addDrop(ch) end
    conns[#conns+1] = folder.ChildAdded:Connect(addDrop)
    conns[#conns+1] = folder.ChildRemoved:Connect(removeDrop)
end
local function hookChests()
    local dep = workspace:FindFirstChild("Deployables"); if not dep then return end
    for _,mdl in ipairs(dep:GetChildren()) do
        if mdl:IsA("Model") then
            local contents = mdl:FindFirstChild("Contents")
            if contents and not watchedFolders[contents] then hookFolder(contents) end
        end
    end
    conns[#conns+1] = dep.ChildAdded:Connect(function(mdl)
        task.defer(function()
            if mdl:IsA("Model") then local contents = mdl:FindFirstChild("Contents"); if contents then hookFolder(contents) end end
        end)
    end)
end
for _,n in ipairs(DROP_FOLDERS) do hookFolder(workspace:FindFirstChild(n)) end
hookChests()
task.spawn(function()
    while true do
        for _,n in ipairs(DROP_FOLDERS) do local f = workspace:FindFirstChild(n); if f and not watchedFolders[f] then hookFolder(f) end end
        if loot_chests.Value then hookChests() end
        task.wait(1.0)
    end
end)
local function selectedSet()
    local sel, val = {}, loot_dropdown.Value
    if typeof(val) == "table" then for k,v in pairs(val) do if v then sel[string.lower(k)] = true end end end
    return sel
end
task.spawn(function()
    while true do
        if loot_on.Value and root then
            local set = selectedSet()
            local useBlack = loot_blacklist.Value
            local range = loot_range.Value
            local maxPer = math.max(1, math.floor(loot_batch.Value))
            local candidates = {}
            for inst,info in pairs(cache) do
                if inst.Parent then
                    local isContents = false
                    if not loot_chests.Value then
                        local p = inst.Parent
                        while p and p ~= workspace do
                            if p.Name == "Contents" then isContents = true; break end
                            p = p.Parent
                        end
                    end
                    if not isContents then
                        local pos = info.getPos()
                        local d   = (pos - root.Position).Magnitude
                        if d <= range then
                            local nm   = info.name or "Unknown"
                            local pass = true
                            if next(set) ~= nil then
                                local inSel = set[string.lower(nm)] == true
                                pass = (useBlack and (not inSel)) or ((not useBlack) and inSel)
                            end
                            if pass then candidates[#candidates+1] = { eid = info.eid, dist = d, name = nm } end
                        end
                    end
                end
            end
            if #candidates > 1 then table.sort(candidates, function(a,b) return a.dist < b.dist end) end
            if loot_debug.Value then print(("[AutoLoot] candidates=%d (mode=%s, chests=%s)"):format(#candidates, useBlack and "Blacklist" or "Whitelist", tostring(loot_chests.Value))) end
            for i = 1, math.min(maxPer, #candidates) do
                safePickup(candidates[i].eid)
                if loot_debug.Value then print(("[AutoLoot] pickup #%d: %s [%.1f]"):format(i, candidates[i].name, candidates[i].dist)) end
                task.wait(0.01)
            end
            task.wait(loot_cd.Value)
        else
            task.wait(0.15)
        end
    end
end)

-- ========= [ TAB: Player — Selective NoClip ] =========
local PlayerTab = Tabs.Player or Window:AddTab({ Title = "Player", Icon = "ghost" })
local snc_on    = PlayerTab:CreateToggle("snc_on",   { Title = "Selective NoClip", Default = false })
local snc_hold  = PlayerTab:CreateToggle("snc_hold", { Title = "Hold-to-clip (key B)", Default = true })
local snc_range = PlayerTab:CreateSlider("snc_range",{ Title = "Scan range (studs)", Min=8, Max=80, Rounding=0, Default=36 })
local snc_limit = PlayerTab:CreateSlider("snc_limit",{ Title = "Max parts / tick",  Min=30, Max=300, Rounding=0, Default=160 })
local snc_tick  = PlayerTab:CreateSlider("snc_tick", { Title = "Update rate (s)",   Min=0.05, Max=0.40, Rounding=2, Default=0.18 })

local UIS = game:GetService("UserInputService")
local _heldB = false
UIS.InputBegan:Connect(function(i,gp) if not gp and i.KeyCode==Enum.KeyCode.B then _heldB = true end end)
UIS.InputEnded:Connect(function(i) if i.KeyCode==Enum.KeyCode.B then _heldB = false end end)
local function isDown() return snc_on.Value or (snc_hold.Value and _heldB) end

local function getCharParts()
    local parts = {}
    local c = plr.Character
    if not c then return parts end
    for _,v in ipairs(c:GetDescendants()) do
        if v:IsA("BasePart") then parts[#parts+1] = v end
    end
    return parts
end

local MATERIAL_OK = {
    [Enum.Material.Wood] = true, [Enum.Material.WoodPlanks] = true,
    [Enum.Material.Rock] = true, [Enum.Material.Slate] = true, [Enum.Material.Basalt] = true,
    [Enum.Material.Granite] = true, [Enum.Material.Ground] = true, [Enum.Material.Grass] = true,
    [Enum.Material.Ice] = true, [Enum.Material.Cobblestone] = true, [Enum.Material.Sandstone] = true
}
local NAME_HINTS = {
    "tree","log","plank","wood","wall","fence","gate","bridge","totem","boulder","rock",
    "stone","node","ore","iron","gold","emerald","magnetite","adurite","crystal",
    "ice","cave","shelly","chest","hut","house","raft","boat"
}
local function isBoogaEnvPart(p: BasePart): boolean
    if not p or not p.Parent or not p.CanCollide then return false end
    if p:IsDescendantOf(plr.Character) then return false end
    if p.Parent:FindFirstChildOfClass("Humanoid") then return false end
    local okMat = MATERIAL_OK[p.Material] or p:IsA("MeshPart"); if not okMat then return false end
    local n = string.lower(p.Name)
    for _,kw in ipairs(NAME_HINTS) do if string.find(n, kw, 1, true) then return true end end
    if p.GetAttribute then
        local dn = tostring(p:GetAttribute("DisplayName") or p:GetAttribute("Name") or ""):lower()
        for _,kw in ipairs(NAME_HINTS) do if dn ~= "" and dn:find(kw, 1, true) then return true end end
    end
    return okMat
end

local activeNCC = {}  -- [envPart] = { [charPart] = NCC }
local function addNoCollide(envPart: BasePart)
    if not envPart or not envPart.Parent then return end
    local perChar = activeNCC[envPart]; if not perChar then perChar = {}; activeNCC[envPart] = perChar end
    for _,cp in ipairs(getCharParts()) do
        if cp and cp.Parent and not perChar[cp] then
            local ncc = Instance.new("NoCollisionConstraint")
            ncc.Part0, ncc.Part1 = cp, envPart
            ncc.Parent = cp
            perChar[cp] = ncc
        end
    end
end
local function removeNoCollideFor(envPart: BasePart)
    local perChar = activeNCC[envPart]
    if perChar then for _,ncc in pairs(perChar) do if ncc then ncc:Destroy() end end; activeNCC[envPart] = nil end
end
local function clearAllNCC() for part,_ in pairs(activeNCC) do removeNoCollideFor(part) end end
plr.CharacterAdded:Connect(function() task.defer(clearAllNCC) end)

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.FilterDescendantsInstances = { plr.Character }
local function getNearBoogaParts(origin: Vector3, radius: number, maxCount: number)
    local res = {}
    local hits = workspace:GetPartBoundsInRadius(origin, radius, overlap)
    if not hits then return res end
    for _,p in ipairs(hits) do
        if p:IsA("BasePart") and p.CanCollide and isBoogaEnvPart(p) then
            res[#res+1] = p
            if #res >= maxCount then break end
        end
    end
    return res
end

task.spawn(function()
    while true do
        if isDown() and root and root.Parent then
            local near = getNearBoogaParts(root.Position, snc_range.Value, snc_limit.Value)
            local keep = {}
            for _,part in ipairs(near) do keep[part] = true; addNoCollide(part) end
            for part,_ in pairs(activeNCC) do if (not part.Parent) or (not keep[part]) then removeNoCollideFor(part) end end
            task.wait(snc_tick.Value)
        else
            clearAllNCC(); task.wait(0.15)
        end
    end
end)



-- ========= [ TAB: Movement (Slope / Auto Climb + 360°) ] =========
local UIS2 = game:GetService("UserInputService")
local LRun = game:GetService("RunService")

local MoveTab = Window:AddTab({ Title = "Movement", Icon = "mountain" })

-- базовые настройки
local mv_on        = MoveTab:CreateToggle("mv_on",        { Title = "Slope / Auto Climb (BV)", Default = false })
local mv_speed     = MoveTab:CreateSlider("mv_speed",     { Title = "Speed", Min = 8, Max = 40, Rounding = 1, Default = 20 })
local mv_boost     = MoveTab:CreateToggle("mv_boost",     { Title = "Shift = Boost (+40%)", Default = true })
local mv_jumphelp  = MoveTab:CreateToggle("mv_jumphelp",  { Title = "Auto Jump on slopes", Default = true })
local mv_sidestep  = MoveTab:CreateToggle("mv_sidestep",  { Title = "Side step if blocked", Default = true })

-- зонды/анти-застревание
local mv_probeLen  = MoveTab:CreateSlider("mv_probel",    { Title = "Wall probe length", Min = 4, Max = 12, Rounding = 1, Default = 7 })
local mv_probeH    = MoveTab:CreateSlider("mv_probeh",    { Title = "Probe height", Min = 1.5, Max = 4, Rounding = 1, Default = 2.4 })
local mv_stuckT    = MoveTab:CreateSlider("mv_stuck",     { Title = "Anti-stuck time (s)", Min = 0.2, Max = 1.2, Rounding = 2, Default = 0.6 })
local mv_sideStep  = MoveTab:CreateSlider("mv_sidest",    { Title = "Side step power", Min = 2, Max = 7, Rounding = 1, Default = 4.2 })

-- новый режим: 360° подъём (можно спиной/боком)
local mv_360       = MoveTab:CreateToggle("mv_360",       { Title = "360° climb (спиной/боком тоже)", Default = true })
local mv_360_fov   = MoveTab:CreateSlider("mv_360_fov",   { Title = "Конус (°) вокруг движения", Min = 30, Max = 360, Rounding = 0, Default = 300 })
local mv_360_rays  = MoveTab:CreateSlider("mv_360_rays",  { Title = "Кол-во лучей", Min = 4, Max = 24, Rounding = 0, Default = 12 })

-- утилиты BV
local function getRoot()
    if not root or not root.Parent then
        local c = plr.Character
        root = c and c:FindFirstChild("HumanoidRootPart") or root
    end
    return root
end
local function mv_getBV()
    local rp = getRoot()
    return rp and rp:FindFirstChild("_MV_BV") or nil
end
local function mv_ensureBV()
    local rp = getRoot(); if not rp then return end
    local bv = mv_getBV()
    if not bv then
        bv = Instance.new("BodyVelocity")
        bv.Name = "_MV_BV"
        bv.MaxForce = Vector3.new(1e9, 0, 1e9) -- движемся по XZ, прыжку не мешаем
        bv.Velocity = Vector3.new()
        bv.Parent = rp
    end
    return bv
end
local function mv_killBV()
    local bv = mv_getBV(); if bv then bv:Destroy() end
end

-- рейкасты
local rayParams_mv = RaycastParams.new()
rayParams_mv.FilterType = Enum.RaycastFilterType.Exclude
rayParams_mv.FilterDescendantsInstances = { plr.Character }

local function wallAheadXZ(dir2d)
    local rp = getRoot(); if not rp then return false end
    if dir2d.Magnitude < 1e-3 then return false end
    local origin = rp.Position + Vector3.new(0, mv_probeH.Value, 0)
    local dir3 = Vector3.new(dir2d.X, 0, dir2d.Z).Unit * mv_probeLen.Value
    local hit = workspace:Raycast(origin, dir3, rayParams_mv)
    if not hit then return false end
    -- вертикальная/крутая поверхность
    return (hit.Normal.Y or 0) < 0.6
end

local function rotate2D(v, deg)
    local a = math.rad(deg)
    local ca, sa = math.cos(a), math.sin(a)
    return Vector3.new(v.X * ca - v.Z * sa, 0, v.X * sa + v.Z * ca)
end

local function blocked360(dir2d)
    local rays = math.max(4, math.floor(mv_360_rays.Value))
    local span = math.clamp(mv_360_fov.Value, 30, 360)
    if dir2d.Magnitude < 1e-3 then
        dir2d = Vector3.new(0,0,1) -- базовый вектор, если стоим
        span = 360
    end
    local start = -span/2
    local step  = span / (rays - 1)
    for i = 0, rays - 1 do
        local d = rotate2D(dir2d.Unit, start + i * step)
        if wallAheadXZ(d) then return true end
    end
    return false
end

local function autoJump()
    if not mv_jumphelp.Value then return end
    if hum and hum.Parent then
        pcall(function()
            hum.Jump = true
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end
end

local function trySideStep(dir2d)
    if not mv_sidestep.Value then return end
    local rp = getRoot(); local bv = mv_ensureBV(); if not (rp and bv) then return end
    local perp = Vector3.new(-dir2d.Z, 0, dir2d.X).Unit
    local power = mv_sideStep.Value * 2
    local t1 = tick()
    while mv_on.Value and tick() - t1 < 0.18 do
        bv.Velocity = perp * power
        LRun.Heartbeat:Wait()
    end
    bv.Velocity = Vector3.new()
    t1 = tick()
    while mv_on.Value and tick() - t1 < 0.18 do
        bv.Velocity = -perp * power
        LRun.Heartbeat:Wait()
    end
    bv.Velocity = Vector3.new()
end

-- основной цикл
task.spawn(function()
    local lastMoveT = tick()
    while true do
        if mv_on.Value and hum and root and hum.Parent then
            local dir = hum.MoveDirection
            local moving = dir.Magnitude > 0.05
            local speed = mv_speed.Value
            if mv_boost.Value and UIS2:IsKeyDown(Enum.KeyCode.LeftShift) then
                speed = speed * 1.4
            end

            -- 360-сканирование препятствий (подъём спиной/боком)
            if mv_360.Value then
                local scanDir = moving and dir or Vector3.new(0,0,1)
                if blocked360(scanDir) then
                    autoJump()
                    if moving then trySideStep(dir) end
                end
            else
                if moving and wallAheadXZ(dir) then
                    autoJump()
                    trySideStep(dir)
                end
            end

            -- движение
            local bv = mv_ensureBV()
            if moving then
                bv.Velocity = dir.Unit * speed
                lastMoveT = tick()
            else
                bv.Velocity = Vector3.new()
            end

            -- анти-застревание
            if tick() - lastMoveT > mv_stuckT.Value then
                local d2 = hum.MoveDirection
                if d2.Magnitude > 0.05 then trySideStep(d2.Unit) end
                lastMoveT = tick()
            end

            LRun.Heartbeat:Wait()
        else
            mv_killBV()
            task.wait(0.12)
        end
    end
end)

plr.CharacterAdded:Connect(function()
    task.defer(function()
        ensureChar()
        if not mv_on.Value then mv_killBV() end
    end)
end)
mv_on:OnChanged(function(v) if not v then mv_killBV() end end)


-- =========================
-- TAB: Follow (следовать за игроком)
-- =========================
Tabs.Follow = Window:AddTab({ Title = "Follow", Icon = "user" })
local flw_toggle = Tabs.Follow:CreateToggle("flw_on", { Title="Follow selected player", Default=false })
local flw_dist   = Tabs.Follow:CreateSlider("flw_dist", { Title="Keep distance (studs)", Min=2, Max=50, Rounding=1, Default=8 })
local flw_speed  = Tabs.Follow:CreateSlider("flw_speed",{ Title="Speed (BV)", Min=5, Max=60, Rounding=1, Default=21 })

local function getAllPlayerNames()
    local list = {} for _, p in ipairs(Players:GetPlayers()) do if p ~= plr then table.insert(list, p.Name) end end
    table.sort(list); return list
end
local flw_dd = Tabs.Follow:CreateDropdown("flw_target", { Title="Target player", Values=getAllPlayerNames(), Default="" })
Tabs.Follow:CreateButton({ Title="Refresh list", Callback=function()
    local names = getAllPlayerNames(); pcall(function() if flw_dd.SetValues then flw_dd:SetValues(names) end end)
    local cur = (flw_dd and flw_dd.Value) or ""; if #names>0 and (cur=="" or cur==nil) then pcall(function() if flw_dd.SetValue then flw_dd:SetValue(names[1]) end end) end
end })
Players.PlayerAdded:Connect(function() pcall(function() if flw_dd.SetValues then flw_dd:SetValues(getAllPlayerNames()) end end) end)
Players.PlayerRemoving:Connect(function(leaver)
    pcall(function() if flw_dd.SetValues then flw_dd:SetValues(getAllPlayerNames()) end end)
    if (flw_dd and flw_dd.Value) == leaver.Name then flw_toggle:SetValue(false) end
end)

local function FLW_getBV() return root and root:FindFirstChild("_FLW_BV") or nil end
local function FLW_ensureBV()
    if not root then return nil end
    local bv = FLW_getBV()
    if not bv then
        bv = Instance.new("BodyVelocity"); bv.Name="_FLW_BV"
        bv.MaxForce = Vector3.new(1e9, 0, 1e9) -- XZ only
        bv.Velocity = Vector3.new(); bv.Parent = root
    end
    return bv
end
local function FLW_killBV() local bv=FLW_getBV(); if bv then bv:Destroy() end end

local function getTargetRootByName(name)
    if not name or name=="" then return nil end
    local p = Players:FindFirstChild(name); if not p then return nil end
    local wf = workspace:FindFirstChild("Players")
    if wf then local wfplr = wf:FindFirstChild(name); if wfplr then local hrp = wfplr:FindFirstChild("HumanoidRootPart"); if hrp then return hrp end end end
    local ch = p.Character; return ch and ch:FindFirstChild("HumanoidRootPart") or nil
end
plr.CharacterAdded:Connect(function() task.defer(FLW_killBV) end)

task.spawn(function()
    while true do
        if flw_toggle.Value then
            local targetName = (flw_dd and flw_dd.Value) or ""
            local keepDist   = tonumber(flw_dist.Value)  or 8
            local speed      = tonumber(flw_speed.Value) or 21
            local trg = getTargetRootByName(targetName)
            if root and trg then
                local bv = FLW_ensureBV()
                local myPos  = root.Position
                local trgPos = trg.Position
                local v = Vector3.new(trgPos.X - myPos.X, 0, trgPos.Z - myPos.Z)
                local d = v.Magnitude
                local band = 0.8
                if d > keepDist + band then
                    bv.Velocity = v.Unit * speed
                elseif d < math.max(keepDist - band, 1) then
                    bv.Velocity = Vector3.new()
                else
                    bv.Velocity = v.Unit * (speed * 0.4)
                end
            else
                local bv = FLW_getBV(); if bv then bv.Velocity = Vector3.new() end
            end
            RunService.Heartbeat:Wait()
        else
            FLW_killBV(); task.wait(0.15)
        end
    end
end)

-- ========= [ TAB: ESP — Wandering Trader (event + resilient) ] =========
local TraderTab = Window:AddTab({ Title = "Trader ESP", Icon = "store" })

local tr_enable    = TraderTab:CreateToggle("tr_esp_enable", { Title = "Enable Trader ESP", Default = true })
local tr_showbb    = TraderTab:CreateToggle("tr_show_label", { Title = "Show overhead label", Default = true })
local tr_highlight = TraderTab:CreateToggle("tr_highlight",  { Title = "Highlight model", Default = true })
local tr_maxdist   = TraderTab:CreateSlider ("tr_maxdist",   { Title = "Max distance (studs)", Min=100, Max=5000, Rounding=0, Default=2000 })
local tr_notify    = TraderTab:CreateToggle("tr_notify",     { Title = "Notify on spawn/despawn", Default = true })

-- hints
local TRADER_NAME_HINTS = { "wandering trader","wanderingtrader","trader","wanderer" }
local function textMatch(s, arr)
    s = string.lower(tostring(s or ""))
    for i=1,#arr do if string.find(s, arr[i], 1, true) then return true end end
    return false
end
local function isTraderModel(m)
    if not (m and m:IsA("Model")) then return false end
    if textMatch(m.Name, TRADER_NAME_HINTS) then return true end
    if m.GetAttribute then
        if textMatch(m:GetAttribute("DisplayName"), TRADER_NAME_HINTS) then return true end
        if textMatch(m:GetAttribute("Name"),        TRADER_NAME_HINTS) then return true end
        if textMatch(m:GetAttribute("NPCType"),     TRADER_NAME_HINTS) then return true end
    end
    -- иногда имя на дочерних объектах
    for _,ch in ipairs(m:GetChildren()) do
        if textMatch(ch.Name, TRADER_NAME_HINTS) then return true end
    end
    return false
end

-- utils
local function modelRoot(m)
    return m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
end
local function prettyName(m)
    local dn
    if m.GetAttribute then dn = m:GetAttribute("DisplayName") or m:GetAttribute("Name") or m:GetAttribute("NPCType") end
    return (dn and dn~="") and tostring(dn) or "Wandering Trader"
end

-- visuals
local function makeBillboard(adornee)
    local bb = Instance.new("BillboardGui")
    bb.Name = "_ESP_TRADER_BB"; bb.AlwaysOnTop = true
    bb.Size = UDim2.fromOffset(180, 26)
    bb.StudsOffsetWorldSpace = Vector3.new(0,4,0)
    bb.Adornee = adornee; bb.Parent = adornee
    local tl = Instance.new("TextLabel")
    tl.BackgroundTransparency = 1; tl.Size = UDim2.fromScale(1,1)
    tl.Font = Enum.Font.GothamBold; tl.TextScaled = true
    tl.TextStrokeTransparency = 0.25; tl.TextColor3 = Color3.fromRGB(255,220,90)
    tl.Text = "Wandering Trader"; tl.Parent = bb
    return bb, tl
end
local function ensureHL(model)
    local hl = model:FindFirstChild("_ESP_TRADER_HL")
    if not hl then
        hl = Instance.new("Highlight")
        hl.Name = "_ESP_TRADER_HL"
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillTransparency = 1; hl.OutlineTransparency = 0
        hl.OutlineColor = Color3.fromRGB(255,220,90)
        hl.Adornee = model; hl.Parent = model
    end
    return hl
end

-- state
local TR = { map = {}, loop = nil, addConn=nil, remConn=nil }

local function attachTrader(m)
    if TR.map[m] then return end
    local r = modelRoot(m)
    local bb, tl, hl

    -- если пока нет корневой детали — дождёмся
    if not r then
        local tmpConn
        tmpConn = m.ChildAdded:Connect(function(ch)
            if ch:IsA("BasePart") or ch.Name == "HumanoidRootPart" then
                r = modelRoot(m)
                if r and TR.map[m] and TR.map[m].bb then
                    TR.map[m].bb.Adornee = r
                end
            end
        end)
        -- создадим запись, билборд появится как только найдётся корень
        TR.map[m] = { model=m, root=nil, bb=nil, tl=nil, hl=nil, label=prettyName(m), waitConn=tmpConn, lastTxt="" }
    end

    if r then
        bb, tl = makeBillboard(r)
        hl = ensureHL(m)
        TR.map[m] = { model=m, root=r, bb=bb, tl=tl, hl=hl, label=prettyName(m), waitConn=nil, lastTxt="" }
    end

    if tr_notify.Value and Library and Library.Notify then
        Library:Notify{ Title="Trader", Content="Wandering Trader FOUND", Duration=3 }
    end
end

local function detachTrader(m)
    local rec = TR.map[m]; if not rec then return end
    if rec.waitConn then pcall(function() rec.waitConn:Disconnect() end) end
    if rec.bb then pcall(function() rec.bb:Destroy() end) end
    if rec.hl then pcall(function() rec.hl:Destroy() end) end
    TR.map[m] = nil
    if tr_notify.Value and Library and Library.Notify then
        Library:Notify{ Title="Trader", Content="Wandering Trader lost", Duration=2 }
    end
end

local function startTraderESP()
    if TR.loop then return end

    -- первичный один-раз скан (легко, но полно)
    for _,inst in ipairs(workspace:GetDescendants()) do
        if inst:IsA("Model") and isTraderModel(inst) then attachTrader(inst) end
    end

    -- глобальные вотчеры: ничего не пропустим
    TR.addConn = workspace.DescendantAdded:Connect(function(inst)
        if inst:IsA("Model") and isTraderModel(inst) then attachTrader(inst) end
    end)
    TR.remConn = workspace.DescendantRemoving:Connect(function(inst)
        if TR.map[inst] then detachTrader(inst) end
    end)

    -- лёгкий апдейт раз в 0.2с
    local acc = 0
    TR.loop = RunService.Heartbeat:Connect(function(dt)
        acc = acc + (dt or 0)
        if acc < 0.20 then return end
        acc = 0

        local enabled = tr_enable.Value
        local showBB  = tr_showbb.Value
        local showHL  = tr_highlight.Value
        local maxD    = tr_maxdist.Value

        local myRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") or nil
        for m, rec in pairs(TR.map) do
            if not (rec.model and rec.model.Parent) then
                detachTrader(m)
            else
                -- если root появился позже — создадим визуал сейчас
                if not rec.root then
                    local nr = modelRoot(rec.model)
                    if nr then
                        local bb, tl = makeBillboard(nr)
                        local hl = ensureHL(rec.model)
                        rec.root, rec.bb, rec.tl, rec.hl = nr, bb, tl, hl
                    end
                end
                if rec.root then
                    -- дистанция/видимость
                    local inRange, txt = true, rec.label
                    if myRoot then
                        local d = (rec.root.Position - myRoot.Position).Magnitude
                        inRange = (d <= maxD)
                        txt = rec.label .. string.format(" (%.0f)", d)
                    end
                    if rec.tl and txt ~= rec.lastTxt then rec.tl.Text = txt; rec.lastTxt = txt end
                    if rec.bb then rec.bb.Enabled = enabled and showBB and inRange end
                    if rec.hl then rec.hl.Enabled = enabled and showHL and inRange end
                end
            end
        end
    end)
end

local function stopTraderESP()
    if TR.loop   then TR.loop:Disconnect(); TR.loop=nil end
    if TR.addConn then TR.addConn:Disconnect(); TR.addConn=nil end
    if TR.remConn then TR.remConn:Disconnect(); TR.remConn=nil end
    for m,_ in pairs(TR.map) do detachTrader(m) end
end

tr_enable:OnChanged(function(v) if v then startTraderESP() else stopTraderESP() end end)
if tr_enable.Value then startTraderESP() end


-- ========= [ TAB: Configs ] =========
Tabs.Configs = Window:AddTab({ Title = "Configs", Icon = "save" })

local cfgName = "default"
local cfgInput = Tabs.Configs:AddInput("cfg_name_input", { Title="Config name", Default=cfgName })
cfgInput:OnChanged(function(v) cfgName = sanitize(v) end)

Tabs.Configs:CreateButton({
    Title = "Quick Save",
    Callback = function()
        local n = sanitize(cfgName)
        pcall(function() SaveManager:Save(n) end)
        Route_SaveToFile(routePath(n), (_G.__ROUTE and _G.__ROUTE.points) or {})
        Route_SaveToFile(ROUTE_AUTOSAVE, (_G.__ROUTE and _G.__ROUTE.points) or {})
        Library:Notify{ Title="Configs", Content="Saved "..n.." (+route)", Duration=3 }
    end
})
Tabs.Configs:CreateButton({
    Title = "Quick Load",
    Callback = function()
        local n = sanitize(cfgName)
        pcall(function() SaveManager:Load(n) end)
        if _G.__ROUTE then
            local ok = Route_LoadFromFile(routePath(n), _G.__ROUTE, _G.__ROUTE._redraw)
            Library:Notify{
                Title="Configs",
                Content="Loaded "..n..(ok and " +route" or " (no route file)"),
                Duration=3
            }
        else
            Library:Notify{ Title="Configs", Content="Loaded "..n, Duration=3 }
        end
    end
})
local auto = Tabs.Configs:CreateToggle("autoload_cfg", { Title="Autoload this config", Default=true })
auto:OnChanged(function(v)
    local n = sanitize(cfgName)
    if v then pcall(function() SaveManager:SaveAutoloadConfig(n) end)
    else pcall(function() SaveManager:DeleteAutoloadConfig() end) end
end)

-- === [ переносимый экспорт/импорт ROUTE ] ===
do
    local function Route_ToString()
        local arr = encodeRoute((_G.__ROUTE and _G.__ROUTE.points) or {})
        local ok, json = pcall(function() return HttpService:JSONEncode(arr) end)
        return ok and json or "[]"
    end
    local function Route_FromString(str)
        if type(str) ~= "string" or str == "" then return false, "empty" end
        local ok, t = pcall(function() return HttpService:JSONDecode(str) end)
        if not ok or type(t) ~= "table" then return false, "bad json" end
        if not _G.__ROUTE then return false, "no route obj" end
        local points = decodeRoute(t)
        table.clear(_G.__ROUTE.points)
        if _G.__ROUTE._redraw and _G.__ROUTE._redraw.clearDots then _G.__ROUTE._redraw.clearDots() end
        for _,p in ipairs(points) do
            table.insert(_G.__ROUTE.points, p)
            if _G.__ROUTE._redraw and _G.__ROUTE._redraw.dot then
                _G.__ROUTE._redraw.dot(Color3.fromRGB(255,230,80), p.pos, 0.7)
            end
        end
        if _G.__ROUTE._redraw and _G.__ROUTE._redraw.redrawLines then
            _G.__ROUTE._redraw.redrawLines()
        end
        return true
    end

    local routeStr = ""
    local routeInput = Tabs.Configs:AddInput("cfg_route_string", {
        Title="Route JSON (paste here to import)",
        Default="",
        Placeholder="сюда вставь длинную строку JSON маршрута"
    })
    routeInput:OnChanged(function(v) routeStr = tostring(v or "") end)

    Tabs.Configs:CreateButton({
        Title="Fill input from CURRENT route",
        Callback=function()
            local s = Route_ToString()
            routeStr = s
            routeInput:SetValue(s)
            Library:Notify{ Title="Route", Content="Input filled from current route", Duration=2 }
        end
    })
    Tabs.Configs:CreateButton({
        Title="Copy CURRENT route (JSON) to Clipboard",
        Callback=function()
            local s = Route_ToString()
            if setclipboard then
                pcall(setclipboard, s)
                Library:Notify{ Title="Route", Content="Copied to clipboard!", Duration=2 }
            else
                print("[ROUTE JSON]\n"..s)
                Library:Notify{ Title="Route", Content="setclipboard недоступен — строка в F9", Duration=4 }
            end
        end
    })
    Tabs.Configs:CreateButton({
        Title="Load route from INPUT (replace current)",
        Callback=function()
            local ok, err = Route_FromString(routeStr)
            if ok then
                Library:Notify{ Title="Route", Content="Route loaded from input", Duration=3 }
                pcall(function() Route_SaveToFile(ROUTE_AUTOSAVE, _G.__ROUTE.points) end)
            else
                Library:Notify{ Title="Route", Content="Import failed: "..tostring(err), Duration=4 }
            end
        end
    })
end

-- ========= [ TAB: Survival (Auto-Eat) ] =========
Tabs.Survival = Window:AddTab({ Title="Survival", Icon="apple" })
local ae_toggle = Tabs.Survival:CreateToggle("ae_toggle", { Title="Auto Eat (Hunger)", Default=false })
local ae_food   = Tabs.Survival:CreateDropdown("ae_food", { Title="Food to eat",
    Values={"Bloodfruit","Berry","Bluefruit","Coconut","Strawberry","Pumpkin","Apple","Lemon","Orange","Banana"},
    Default="Bloodfruit" })
local ae_thresh = Tabs.Survival:CreateSlider("ae_thresh", { Title="Setpoint / Threshold (%)", Min=1, Max=100, Rounding=0, Default=70 })
local ae_mode   = Tabs.Survival:CreateDropdown("ae_mode", { Title="Scale mode", Values={"Fullness 100→0","Hunger 0→100"}, Default="Fullness 100→0" })
local ae_debug  = Tabs.Survival:CreateToggle("ae_debug", { Title="Debug logs (F9)", Default=false })

local function normPct(n) if type(n)~="number" then return nil end if n<=1.5 then n=n*100 end return math.clamp(n,0,100) end
local function readHungerFromValues() for _,v in ipairs(plr:GetDescendants()) do if v.Name=="Hunger" and (v:IsA("NumberValue") or v:IsA("IntValue")) then return normPct(v.Value) end end end
local function readHungerFromBar()
    local pg=plr:FindFirstChild("PlayerGui"); if not pg then return end
    local mg=pg:FindFirstChild("MainGui"); if not mg then return end
    local bars=mg:FindFirstChild("Bars"); if not bars then return end
    local hb=bars:FindFirstChild("Hunger")
    if hb and hb:IsA("Frame") and hb.Size and hb.Size.X and typeof(hb.Size.X.Scale)=="number" then
        return normPct(hb.Size.X.Scale)
    end
end
local function readHungerFromText()
    local pg=plr:FindFirstChild("PlayerGui"); if not pg then return end
    for _,inst in ipairs(pg:GetDescendants()) do
        if inst:IsA("TextLabel") then
            local txt=tostring(inst.Text or ""):lower()
            if txt:find("голод") or inst.Name:lower():find("hunger") or (inst.Parent and inst.Parent.Name:lower():find("hunger")) then
                local num=tonumber(txt:match("([-+]?%d+%.?%d*)"))
                if num and num>=0 and num<=100 then return num end
            end
        end
    end
end
local function readHungerFromAttr() local a=plr:GetAttribute("Hunger") if typeof(a)=="number" then return normPct(a) end end
local function readHungerPercent() return readHungerFromValues() or readHungerFromBar() or readHungerFromText() or readHungerFromAttr() or 100 end

local eatingLock=false
task.spawn(function()
    while true do
        task.wait(0.2)
        if not ae_toggle.Value then continue end
        local target=ae_thresh.Value
        local mode=ae_mode.Value
        local cur=readHungerPercent()
        local need = (mode=="Fullness 100→0" and cur<target) or (mode=="Hunger 0→100" and cur>target)
        if need and not eatingLock then
            eatingLock=true
            task.spawn(function()
                local tries, maxTries = 0, 25
                local minDelay, band = 0.15, 0.5
                while ae_toggle.Value and tries<maxTries do
                    cur=readHungerPercent()
                    local okNow=(mode=="Fullness 100→0" and cur>=target-band) or (mode=="Hunger 0→100" and cur<=target+band)
                    if okNow then if ae_debug.Value then print(("[AutoEat] reached: %.1f / %d (%s)"):format(cur,target,mode)) end; break end
                    local food=ae_food.Value or "Bloodfruit"
                    local ate=consumeBySlot(getSlotByName(food)) or consumeById(getItemIdByName(food))
                    if ae_debug.Value then print(("[AutoEat] try=%d -> %s"):format(tries + 1, ate and "EAT" or "MISS")) end
                    tries = tries + 1; task.wait(minDelay)
                end
                eatingLock=false
            end)
        end
    end
end)

-- ========= [ TAB: Configs ] =========
Tabs.Configs = Window:AddTab({ Title = "Configs", Icon = "save" })

local cfgName = "default"
local cfgInput = Tabs.Configs:AddInput("cfg_name_input", { Title="Config name", Default=cfgName })
cfgInput:OnChanged(function(v) cfgName = sanitize(v) end)

Tabs.Configs:CreateButton({
    Title = "Quick Save",
    Callback = function()
        local n = sanitize(cfgName)
        pcall(function() SaveManager:Save(n) end)
        Route_SaveToFile(routePath(n), (_G.__ROUTE and _G.__ROUTE.points) or {})
        Route_SaveToFile(ROUTE_AUTOSAVE, (_G.__ROUTE and _G.__ROUTE.points) or {})
        Library:Notify{ Title="Configs", Content="Saved "..n.." (+route)", Duration=3 }
    end
})
Tabs.Configs:CreateButton({
    Title = "Quick Load",
    Callback = function()
        local n = sanitize(cfgName)
        pcall(function() SaveManager:Load(n) end)
        if _G.__ROUTE then
            local ok = Route_LoadFromFile(routePath(n), _G.__ROUTE, _G.__ROUTE._redraw)
            Library:Notify{
                Title="Configs",
                Content="Loaded "..n..(ok and " +route" or " (no route file)"),
                Duration=3
            }
        else
            Library:Notify{ Title="Configs", Content="Loaded "..n, Duration=3 }
        end
    end
})
local auto = Tabs.Configs:CreateToggle("autoload_cfg", { Title="Autoload this config", Default=true })
auto:OnChanged(function(v)
    local n = sanitize(cfgName)
    if v then pcall(function() SaveManager:SaveAutoloadConfig(n) end)
    else pcall(function() SaveManager:DeleteAutoloadConfig() end) end
end)

-- === [ переносимый экспорт/импорт ROUTE ] ===
do
    local function Route_ToString()
        local arr = encodeRoute((_G.__ROUTE and _G.__ROUTE.points) or {})
        local ok, json = pcall(function() return HttpService:JSONEncode(arr) end)
        return ok and json or "[]"
    end
    local function Route_FromString(str)
        if type(str) ~= "string" or str == "" then return false, "empty" end
        local ok, t = pcall(function() return HttpService:JSONDecode(str) end)
        if not ok or type(t) ~= "table" then return false, "bad json" end
        if not _G.__ROUTE then return false, "no route obj" end
        local points = decodeRoute(t)
        table.clear(_G.__ROUTE.points)
        if _G.__ROUTE._redraw and _G.__ROUTE._redraw.clearDots then _G.__ROUTE._redraw.clearDots() end
        for _,p in ipairs(points) do
            table.insert(_G.__ROUTE.points, p)
            if _G.__ROUTE._redraw and _G.__ROUTE._redraw.dot then
                _G.__ROUTE._redraw.dot(Color3.fromRGB(255,230,80), p.pos, 0.7)
            end
        end
        if _G.__ROUTE._redraw and _G.__ROUTE._redraw.redrawLines then
            _G.__ROUTE._redraw.redrawLines()
        end
        return true
    end

    local routeStr = ""
    local routeInput = Tabs.Configs:AddInput("cfg_route_string", {
        Title="Route JSON (paste here to import)",
        Default="",
        Placeholder="сюда вставь длинную строку JSON маршрута"
    })
    routeInput:OnChanged(function(v) routeStr = tostring(v or "") end)

    Tabs.Configs:CreateButton({
        Title="Fill input from CURRENT route",
        Callback=function()
            local s = Route_ToString()
            routeStr = s
            routeInput:SetValue(s)
            Library:Notify{ Title="Route", Content="Input filled from current route", Duration=2 }
        end
    })
    Tabs.Configs:CreateButton({
        Title="Copy CURRENT route (JSON) to Clipboard",
        Callback=function()
            local s = Route_ToString()
            if setclipboard then
                pcall(setclipboard, s)
                Library:Notify{ Title="Route", Content="Copied to clipboard!", Duration=2 }
            else
                print("[ROUTE JSON]\n"..s)
                Library:Notify{ Title="Route", Content="setclipboard недоступен — строка в F9", Duration=4 }
            end
        end
    })
    Tabs.Configs:CreateButton({
        Title="Load route from INPUT (replace current)",
        Callback=function()
            local ok, err = Route_FromString(routeStr)
            if ok then
                Library:Notify{ Title="Route", Content="Route loaded from input", Duration=3 }
                pcall(function() Route_SaveToFile(ROUTE_AUTOSAVE, _G.__ROUTE.points) end)
            else
                Library:Notify{ Title="Route", Content="Import failed: "..tostring(err), Duration=4 }
            end
        end
    })
end

-- ========= [ TAB: Survival (Auto-Eat) ] =========
Tabs.Survival = Window:AddTab({ Title="Survival", Icon="apple" })
local ae_toggle = Tabs.Survival:CreateToggle("ae_toggle", { Title="Auto Eat (Hunger)", Default=false })
local ae_food   = Tabs.Survival:CreateDropdown("ae_food", { Title="Food to eat",
    Values={"Bloodfruit","Berry","Bluefruit","Coconut","Strawberry","Pumpkin","Apple","Lemon","Orange","Banana"},
    Default="Bloodfruit" })
local ae_thresh = Tabs.Survival:CreateSlider("ae_thresh", { Title="Setpoint / Threshold (%)", Min=1, Max=100, Rounding=0, Default=70 })
local ae_mode   = Tabs.Survival:CreateDropdown("ae_mode", { Title="Scale mode", Values={"Fullness 100→0","Hunger 0→100"}, Default="Fullness 100→0" })
local ae_debug  = Tabs.Survival:CreateToggle("ae_debug", { Title="Debug logs (F9)", Default=false })

local function normPct(n) if type(n)~="number" then return nil end if n<=1.5 then n=n*100 end return math.clamp(n,0,100) end
local function readHungerFromValues() for _,v in ipairs(plr:GetDescendants()) do if v.Name=="Hunger" and (v:IsA("NumberValue") or v:IsA("IntValue")) then return normPct(v.Value) end end end
local function readHungerFromBar()
    local pg=plr:FindFirstChild("PlayerGui"); if not pg then return end
    local mg=pg:FindFirstChild("MainGui"); if not mg then return end
    local bars=mg:FindFirstChild("Bars"); if not bars then return end
    local hb=bars:FindFirstChild("Hunger")
    if hb and hb:IsA("Frame") and hb.Size and hb.Size.X and typeof(hb.Size.X.Scale)=="number" then
        return normPct(hb.Size.X.Scale)
    end
end
local function readHungerFromText()
    local pg=plr:FindFirstChild("PlayerGui"); if not pg then return end
    for _,inst in ipairs(pg:GetDescendants()) do
        if inst:IsA("TextLabel") then
            local txt=tostring(inst.Text or ""):lower()
            if txt:find("голод") or inst.Name:lower():find("hunger") or (inst.Parent and inst.Parent.Name:lower():find("hunger")) then
                local num=tonumber(txt:match("([-+]?%d+%.?%d*)"))
                if num and num>=0 and num<=100 then return num end
            end
        end
    end
end
local function readHungerFromAttr() local a=plr:GetAttribute("Hunger") if typeof(a)=="number" then return normPct(a) end end
local function readHungerPercent() return readHungerFromValues() or readHungerFromBar() or readHungerFromText() or readHungerFromAttr() or 100 end

local eatingLock=false
task.spawn(function()
    while true do
        task.wait(0.2)
        if not ae_toggle.Value then continue end
        local target=ae_thresh.Value
        local mode=ae_mode.Value
        local cur=readHungerPercent()
        local need = (mode=="Fullness 100→0" and cur<target) or (mode=="Hunger 0→100" and cur>target)
        if need and not eatingLock then
            eatingLock=true
            task.spawn(function()
                local tries, maxTries = 0, 25
                local minDelay, band = 0.15, 0.5
                while ae_toggle.Value and tries<maxTries do
                    cur=readHungerPercent()
                    local okNow=(mode=="Fullness 100→0" and cur>=target-band) or (mode=="Hunger 0→100" and cur<=target+band)
                    if okNow then if ae_debug.Value then print(("[AutoEat] reached: %.1f / %d (%s)"):format(cur,target,mode)) end; break end
                    local food=ae_food.Value or "Bloodfruit"
                    local ate=consumeBySlot(getSlotByName(food)) or consumeById(getItemIdByName(food))
                    if ae_debug.Value then print(("[AutoEat] try=%d -> %s"):format(tries + 1, ate and "EAT" or "MISS")) end
                    tries = tries + 1; task.wait(minDelay)
                end
                eatingLock=false
            end)
        end
    end
end)

-- ========= [ TAB: Configs ] =========
Tabs.Configs = Window:AddTab({ Title = "Configs", Icon = "save" })

local cfgName = "default"
local cfgInput = Tabs.Configs:AddInput("cfg_name_input", { Title="Config name", Default=cfgName })
cfgInput:OnChanged(function(v) cfgName = sanitize(v) end)

Tabs.Configs:CreateButton({
    Title = "Quick Save",
    Callback = function()
        local n = sanitize(cfgName)
        pcall(function() SaveManager:Save(n) end)
        Route_SaveToFile(routePath(n), (_G.__ROUTE and _G.__ROUTE.points) or {})
        Route_SaveToFile(ROUTE_AUTOSAVE, (_G.__ROUTE and _G.__ROUTE.points) or {})
        Library:Notify{ Title="Configs", Content="Saved "..n.." (+route)", Duration=3 }
    end
})
Tabs.Configs:CreateButton({
    Title = "Quick Load",
    Callback = function()
        local n = sanitize(cfgName)
        pcall(function() SaveManager:Load(n) end)
        if _G.__ROUTE then
            local ok = Route_LoadFromFile(routePath(n), _G.__ROUTE, _G.__ROUTE._redraw)
            Library:Notify{
                Title="Configs",
                Content="Loaded "..n..(ok and " +route" or " (no route file)"),
                Duration=3
            }
        else
            Library:Notify{ Title="Configs", Content="Loaded "..n, Duration=3 }
        end
    end
})
local auto = Tabs.Configs:CreateToggle("autoload_cfg", { Title="Autoload this config", Default=true })
auto:OnChanged(function(v)
    local n = sanitize(cfgName)
    if v then pcall(function() SaveManager:SaveAutoloadConfig(n) end)
    else pcall(function() SaveManager:DeleteAutoloadConfig() end) end
end)

-- === [ переносимый экспорт/импорт ROUTE ] ===
do
    local function Route_ToString()
        local arr = encodeRoute((_G.__ROUTE and _G.__ROUTE.points) or {})
        local ok, json = pcall(function() return HttpService:JSONEncode(arr) end)
        return ok and json or "[]"
    end
    local function Route_FromString(str)
        if type(str) ~= "string" or str == "" then return false, "empty" end
        local ok, t = pcall(function() return HttpService:JSONDecode(str) end)
        if not ok or type(t) ~= "table" then return false, "bad json" end
        if not _G.__ROUTE then return false, "no route obj" end
        local points = decodeRoute(t)
        table.clear(_G.__ROUTE.points)
        if _G.__ROUTE._redraw and _G.__ROUTE._redraw.clearDots then _G.__ROUTE._redraw.clearDots() end
        for _,p in ipairs(points) do
            table.insert(_G.__ROUTE.points, p)
            if _G.__ROUTE._redraw and _G.__ROUTE._redraw.dot then
                _G.__ROUTE._redraw.dot(Color3.fromRGB(255,230,80), p.pos, 0.7)
            end
        end
        if _G.__ROUTE._redraw and _G.__ROUTE._redraw.redrawLines then
            _G.__ROUTE._redraw.redrawLines()
        end
        return true
    end

    local routeStr = ""
    local routeInput = Tabs.Configs:AddInput("cfg_route_string", {
        Title="Route JSON (paste here to import)",
        Default="",
        Placeholder="сюда вставь длинную строку JSON маршрута"
    })
    routeInput:OnChanged(function(v) routeStr = tostring(v or "") end)

    Tabs.Configs:CreateButton({
        Title="Fill input from CURRENT route",
        Callback=function()
            local s = Route_ToString()
            routeStr = s
            routeInput:SetValue(s)
            Library:Notify{ Title="Route", Content="Input filled from current route", Duration=2 }
        end
    })
    Tabs.Configs:CreateButton({
        Title="Copy CURRENT route (JSON) to Clipboard",
        Callback=function()
            local s = Route_ToString()
            if setclipboard then
                pcall(setclipboard, s)
                Library:Notify{ Title="Route", Content="Copied to clipboard!", Duration=2 }
            else
                print("[ROUTE JSON]\n"..s)
                Library:Notify{ Title="Route", Content="setclipboard недоступен — строка в F9", Duration=4 }
            end
        end
    })
    Tabs.Configs:CreateButton({
        Title="Load route from INPUT (replace current)",
        Callback=function()
            local ok, err = Route_FromString(routeStr)
            if ok then
                Library:Notify{ Title="Route", Content="Route loaded from input", Duration=3 }
                pcall(function() Route_SaveToFile(ROUTE_AUTOSAVE, _G.__ROUTE.points) end)
            else
                Library:Notify{ Title="Route", Content="Import failed: "..tostring(err), Duration=4 }
            end
        end
    })
end

-- ========= [ TAB: Survival (Auto-Eat) ] =========
Tabs.Survival = Window:AddTab({ Title="Survival", Icon="apple" })
local ae_toggle = Tabs.Survival:CreateToggle("ae_toggle", { Title="Auto Eat (Hunger)", Default=false })
local ae_food   = Tabs.Survival:CreateDropdown("ae_food", { Title="Food to eat",
    Values={"Bloodfruit","Berry","Bluefruit","Coconut","Strawberry","Pumpkin","Apple","Lemon","Orange","Banana"},
    Default="Bloodfruit" })
local ae_thresh = Tabs.Survival:CreateSlider("ae_thresh", { Title="Setpoint / Threshold (%)", Min=1, Max=100, Rounding=0, Default=70 })
local ae_mode   = Tabs.Survival:CreateDropdown("ae_mode", { Title="Scale mode", Values={"Fullness 100→0","Hunger 0→100"}, Default="Fullness 100→0" })
local ae_debug  = Tabs.Survival:CreateToggle("ae_debug", { Title="Debug logs (F9)", Default=false })

local function normPct(n) if type(n)~="number" then return nil end if n<=1.5 then n=n*100 end return math.clamp(n,0,100) end
local function readHungerFromValues() for _,v in ipairs(plr:GetDescendants()) do if v.Name=="Hunger" and (v:IsA("NumberValue") or v:IsA("IntValue")) then return normPct(v.Value) end end end
local function readHungerFromBar()
    local pg=plr:FindFirstChild("PlayerGui"); if not pg then return end
    local mg=pg:FindFirstChild("MainGui"); if not mg then return end
    local bars=mg:FindFirstChild("Bars"); if not bars then return end
    local hb=bars:FindFirstChild("Hunger")
    if hb and hb:IsA("Frame") and hb.Size and hb.Size.X and typeof(hb.Size.X.Scale)=="number" then
        return normPct(hb.Size.X.Scale)
    end
end
local function readHungerFromText()
    local pg=plr:FindFirstChild("PlayerGui"); if not pg then return end
    for _,inst in ipairs(pg:GetDescendants()) do
        if inst:IsA("TextLabel") then
            local txt=tostring(inst.Text or ""):lower()
            if txt:find("голод") or inst.Name:lower():find("hunger") or (inst.Parent and inst.Parent.Name:lower():find("hunger")) then
                local num=tonumber(txt:match("([-+]?%d+%.?%d*)"))
                if num and num>=0 and num<=100 then return num end
            end
        end
    end
end
local function readHungerFromAttr() local a=plr:GetAttribute("Hunger") if typeof(a)=="number" then return normPct(a) end end
local function readHungerPercent() return readHungerFromValues() or readHungerFromBar() or readHungerFromText() or readHungerFromAttr() or 100 end

local eatingLock=false
task.spawn(function()
    while true do
        task.wait(0.2)
        if not ae_toggle.Value then continue end
        local target=ae_thresh.Value
        local mode=ae_mode.Value
        local cur=readHungerPercent()
        local need = (mode=="Fullness 100→0" and cur<target) or (mode=="Hunger 0→100" and cur>target)
        if need and not eatingLock then
            eatingLock=true
            task.spawn(function()
                local tries, maxTries = 0, 25
                local minDelay, band = 0.15, 0.5
                while ae_toggle.Value and tries<maxTries do
                    cur=readHungerPercent()
                    local okNow=(mode=="Fullness 100→0" and cur>=target-band) or (mode=="Hunger 0→100" and cur<=target+band)
                    if okNow then if ae_debug.Value then print(("[AutoEat] reached: %.1f / %d (%s)"):format(cur,target,mode)) end; break end
                    local food=ae_food.Value or "Bloodfruit"
                    local ate=consumeBySlot(getSlotByName(food)) or consumeById(getItemIdByName(food))
                    if ae_debug.Value then print(("[AutoEat] try=%d -> %s"):format(tries + 1, ate and "EAT" or "MISS")) end
                    tries = tries + 1; task.wait(minDelay)
                end
                eatingLock=false
            end)
        end
    end
end)




-- ========= [ Finish / Autoload ] =========
Window:SelectTab(1)
Library:Notify{ Title="Fuger Hub", Content="Loaded: Configs + Survival + Gold + Route + Farming + Heal + Combat", Duration=6 }
pcall(function() SaveManager:LoadAutoloadConfig() end)
pcall(function()
    local ok = Route_LoadFromFile(ROUTE_AUTOSAVE, _G.__ROUTE, _G.__ROUTE._redraw)
    if ok then Library:Notify{ Title="Route", Content="Route autosave loaded", Duration=3 } end
end)
