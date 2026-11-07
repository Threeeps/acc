if not game:IsLoaded() then game.Loaded:Wait() end
local RS, HttpService = game:GetService("ReplicatedStorage"), game:GetService("HttpService")
local function popup(text)
    warn("[Kaitun Config] " .. tostring(text))
    pcall(function() game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Kaitun Config", Text = tostring(text):sub(1, 180), Duration = 10 }) end)
end
if game.GameId ~= 3183403065 then popup("Run this in Anime Adventures.") return end
local ok, err = pcall(function()

local ASTRAL = "https://raw.githubusercontent.com/inCythe/Astral/f9f469b94b714332df86f43013de5e9b7c8354c3/"
local Library
for i = 1, 3 do
    local ok, src = pcall(game.HttpGet, game, ASTRAL .. "Astral.lua")
    local fn = ok and type(src) == "string" and loadstring(src)
    local ok2, lib = false, nil
    if fn then ok2, lib = pcall(fn) end
    if ok2 and lib then Library = lib break end
    task.wait(i)
end
if not Library then popup("UI download failed, run it again.") return end
do
    local orig = Library.GetTextBounds
    Library.GetTextBounds = function(self, Text, Font, Size, Width)
        local ok, x, y = pcall(orig, self, Text, Font, Size, Width)
        if ok then return x, y end
        local w = Width or workspace.CurrentCamera.ViewportSize.X - 32
        local v = game:GetService("TextService"):GetTextSize(tostring(Text):gsub("<[^>]->", ""), Size, Enum.Font.Gotham, Vector2.new(w, 1e5))
        return v.X, v.Y
    end
end
local Options = Library.Options
if getgenv().KT_CONFIG_LIB then pcall(function() getgenv().KT_CONFIG_LIB:Unload() end) end
getgenv().KT_CONFIG_LIB = Library

local function data(name)
    local ok, t = pcall(function() return require(RS:WaitForChild("src", 30):WaitForChild("Data", 30):WaitForChild(name, 30)) end)
    return ok and type(t) == "table" and t or {}
end
local Units, Levels, Worlds = data("Units"), data("Levels"), data("Worlds")
local count, byName = {}, {}
for id, d in pairs(Units) do
    if type(d) == "table" and d.name and d.rarity and tonumber(d.cost) and not tostring(id):find("_evolved$") then
        count[d.name] = (count[d.name] or 0) + 1
    end
end
local ALL, MYTHIC, VALUE, LABEL = {}, {}, {}, {}
for id, d in pairs(Units) do
    if type(d) == "table" and d.name and count[d.name] then
        local label = count[d.name] == 1 and d.name or ("%s [%s]"):format(d.name, id)
        VALUE[label] = count[d.name] == 1 and d.name or id
        LABEL[id] = label
        ALL[#ALL + 1] = label
        if d.rarity == "Mythic" then MYTHIC[#MYTHIC + 1] = label end
    end
end
table.sort(ALL) table.sort(MYTHIC)
if #ALL == 0 then warn("[Kaitun Config] unit list not loaded: run it in Anime Adventures") end
local acts = {}
for id, d in pairs(Levels) do
    if type(d) == "table" and tostring(id):match("_level_%d+$") and tonumber(d.story_world_rank) then
        acts[d.world] = math.min(acts[d.world] or math.huge, tonumber(d.story_world_rank))
    end
end
local order = {}
for w in pairs(acts) do order[#order + 1] = w end
table.sort(order, function(a, b) return acts[a] < acts[b] end)
local STORY = { "All" }
for _, w in ipairs(order) do STORY[#STORY + 1] = tostring(type(Worlds[w]) == "table" and Worlds[w].name or w) end
local function pick(id, fallback) return LABEL[id] or fallback end

local Window = Library:CreateWindow({ Title = "Hina Kaitun", Footer = "Kaitun Config | discord.gg/hinahub", NotifySide = "Right", Resizable = true, ShowCustomCursor = false })
local Tab = Window:AddTab("Kaitun", "settings")

local L = (Tab.AddLeftGroupbox or Tab.AddLeftSection)(Tab, "Goal", "target")
local R = (Tab.AddRightGroupbox or Tab.AddRightSection)(Tab, "Units", "users")
local function bigDropdown(box, idx, info)
    local full, def = info.Values, info.Default
    info.Values, info.Default = {}, nil
    local d = box:AddDropdown(idx, info)
    if not (info.Multi and type(d.Menu) == "table" and type(d.BuildDropdownList) == "function") then
        d:SetValues(full) d:SetValue(def or (info.Multi and {} or nil)) return d
    end
    d.Values = full
    local v = {}
    for _, n in ipairs(type(def) == "table" and def or {}) do if table.find(full, n) then v[n] = true end end
    d.Value = v
    d:Display()
    local built = false
    for _, m in ipairs({ "Toggle", "Open" }) do
        local f = d.Menu[m]
        d.Menu[m] = function(...) if not built then built = true d:BuildDropdownList() end return f(...) end
    end
    return d
end

L:AddInput("KTLevel", { Text = "Account Level Goal", Default = "40", Numeric = true, Finished = false, Placeholder = "40" })
L:AddDropdown("KTStory", { Text = "Story: Clear Up To", Values = STORY, Default = "All", Searchable = true })
L:AddDropdown("KTMode", { Text = "Story Mode", Values = { "Normal", "Hard" }, Default = "Normal" })
L:AddLabel("Hard = clears Normal first, then Hard once your compass unit is evolved.", true)
L:AddInput("KTRollAt", { Text = "Gems Before Rolling (0 = roll anytime)", Default = "0", Numeric = true, Finished = false })
L:AddInput("KTSave", { Text = "Gems To Save At The End", Default = "0", Numeric = true, Finished = false })
L:AddLabel("Saved after every Wanted and Support unit is owned.", true)
L:AddInput("KTHook", { Text = "Discord Webhook (optional)", Default = "", Placeholder = "https://discord.com/api/webhooks/..." })
L:AddLabel("Pings you when the goal is done. Then it farms gems in Inf 6.", true)

R:AddDropdown("KTCompass", { Text = "Wanted (Compass Use)", Values = MYTHIC, Default = pick("elyssia", MYTHIC[1]), Searchable = true })
R:AddLabel("ONLY 1 compass per account. Pick 1 unit.", true)
local wantOrder = {}
bigDropdown(R, "KTWanted", { Text = "Wanted (No Compass)", Values = ALL, Multi = true, Default = {}, Searchable = true,
    Callback = function(v)
        for i = #wantOrder, 1, -1 do if not v[wantOrder[i]] then table.remove(wantOrder, i) end end
        for k, on in pairs(v) do if on and not table.find(wantOrder, k) then wantOrder[#wantOrder + 1] = k end end
    end })
local sDef = {}
for _, id in ipairs({ "wendy", "erwin", "bulma", "speedwagon", "nobara" }) do if LABEL[id] then sDef[#sDef + 1] = LABEL[id] end end
bigDropdown(R, "KTSupports", { Text = "Support Units", Values = ALL, Multi = true, Default = sDef, Searchable = true })
R:AddLabel("Mythic supports (Zombie, Griffin...) are rolled only after every Wanted unit. Keep 2 farm units (Bulma, Speedwagon).", true)

local Info = (Tab.AddRightGroupbox or Tab.AddRightSection)(Tab, "Read Me", "info")
Info:AddLabel("If you wish to also farm for Griffin and Zombie, select them in Support Units, not in Wanted.", true)
Info:AddLabel("Compass unit: once owned, Kaitun focuses on evolving it. It plays normally until Walled City Infinite is unlocked, farms takedowns there (resets at wave 50), then plays normally until challenges give the star fruits, then evolves.", true)
Info:AddLabel("Wanted (No Compass) = random pulls, same priority as the compass unit, forced into the team.", true)
Info:AddLabel("Kaitun joins the game's group by itself (the compass code needs it). Trait rerolls are never used.", true)
Info:AddLabel("Paste the copied config ABOVE the Kaitun loadstring and keep it there.", true)

local function num(idx, def) return math.max(0, math.floor(tonumber(Options[idx].Value) or def)) end
local function list(labels)
    local out = {}
    for _, l in ipairs(labels) do out[#out + 1] = ("%q"):format(VALUE[l] or l) end
    return "{ " .. table.concat(out, ", ") .. " }"
end
local function build()
    local sup = {}
    for l, on in pairs(Options.KTSupports.Value) do if on then sup[#sup + 1] = l end end
    table.sort(sup)
    local wanted = {}
    for _, l in ipairs(wantOrder) do if l ~= Options.KTCompass.Value then wanted[#wanted + 1] = l end end
    local compass = Options.KTCompass.Value
    return table.concat({
        "getgenv().Kaitun = {",
        ("    TargetLevel = %d,"):format(math.max(1, num("KTLevel", 40))),
        ("    WantedCompass = %q,"):format(compass and (VALUE[compass] or compass) or ""),
        ("    Wanted = %s,"):format(list(wanted)),
        ("    Supports = %s,"):format(list(sup)),
        ("    StoryTo = %q,"):format(Options.KTStory.Value or "All"),
        ("    StoryHard = %s,"):format(tostring(Options.KTMode.Value == "Hard")),
        ("    RollAtGems = %d,"):format(num("KTRollAt", 0)),
        ("    SaveGems = %d,"):format(num("KTSave", 0)),
        ("    Webhook = %q,"):format(tostring(Options.KTHook.Value or "")),
        "}",
    }, "\n")
end
getgenv().KT_CONFIG_BUILD = build
R:AddButton({ Text = "Create Config", Func = function()
    local text = build()
    local copy = setclipboard or toclipboard or (Clipboard and Clipboard.set)
    if copy then pcall(copy, text) end
    print(text)
    Library:Notify({ Title = "Hina Kaitun", Description = copy and "Copied! Paste it ABOVE the Kaitun loadstring." or "No clipboard: copy it from the console (F9).", Time = 8 })
end })
Library:Notify({ Title = "Hina Kaitun", Description = "Fill it in, then press Create Config.", Time = 5 })
end)
if not ok then popup("Error: " .. tostring(err)) end
