repeat task.wait() until game:IsLoaded()
if shared.vape then shared.vape:Uninject() end

local options = ... or {}
local closetMode = options.Closet or false

if closetMode then
    getgenv().print = function() end
    getgenv().warn = function() end
    getgenv().error = function() end
    
    task.spawn(function()
        repeat
            for _, v in getconnections(game:GetService('LogService').MessageOut) do
                v:Disable()
            end
            for _, v in getconnections(game:GetService('ScriptContext').Error) do
                v:Disable()
            end
            task.wait(1)
        until not closetMode
    end)
end

if identifyexecutor then
	if table.find({'Argon', 'Wave'}, ({identifyexecutor()})[1]) then
		getgenv().setthreadidentity = nil
	end
end

local function _1()
    if not isfile or not isfile('newvape/security/validated') then
        if not closetMode then
            game.StarterGui:SetCore("SendNotification", {
                Title = "Security Error",
                Text = "validation file missing",
                Duration = 3
            })
        end
        return false, nil, nil
    end
    local a = readfile('newvape/security/validated')
    local b, c = pcall(function()
        return game:GetService("HttpService"):JSONDecode(a)
    end)
    if not b or not c or not c.username then
        if not closetMode then
            game.StarterGui:SetCore("SendNotification", {
                Title = "Security Error",
                Text = "wrong validation data",
                Duration = 5
            })
        end
        return false, nil, nil
    end
    return true, c.username, c.guest or false
end

local d, e, f = _1()
if not d then return end
shared.ValidatedUsername = e
shared.IsGuestAccount = f
shared.DeviceHWID = shared.DeviceHWID or (isfile('newvape/security/hwid.txt') and readfile('newvape/security/hwid.txt') or "Unknown")

local _2 = {}
for i = 65, 90 do table.insert(_2, i) end
for i = 97, 122 do table.insert(_2, i) end
for i = 48, 57 do table.insert(_2, i) end
table.insert(_2, 43) table.insert(_2, 47)

local function _3(g)
    local h = ""
    for i = 1, #g do
        local j = g[i]
        if j == 61 then break end
        local k = table.find(_2, j)
        if k then
            local l = k - 1
            h = h .. string.format("%06d", tonumber(string.format("%d", l)))
        end
    end
    local m = ""
    for i = 1, #h, 8 do
        local n = h:sub(i, i + 7)
        if #n == 8 then
            local o = 0
            for p = 1, 8 do
                if n:sub(p, p) == "1" then
                    o = o + 2^(8-p)
                end
            end
            m = m .. string.char(o)
        end
    end
    return m
end

local function _4()
    local q = "aHR0cHM6Ly9wYXN0ZWJpbi5jb20vcmF3L0N2MmZNeDg5"
    return _3(q)
end

local ACCOUNT_SYSTEM_URL = _4()

local function _5(r)
    local s = shared.DeviceHWID
    if r.HWID and r.HWID ~= "" and s == r.HWID then return true end
    if r.AllowedHWIDs and #r.AllowedHWIDs > 0 then
        for _, t in pairs(r.AllowedHWIDs) do
            if s == t then return true end
        end
    end
    return false
end

local function _6()
    if f then return true end
    local function u()
        local v, w = pcall(function()
            return game:HttpGet(ACCOUNT_SYSTEM_URL)
        end)
        if v and w then
            local x = loadstring(w)()
            if x and x.Accounts then return x.Accounts end
        end
        return nil
    end
    local y = u()
    if not y then return true end
    for _, z in pairs(y) do
        if z.Username == shared.ValidatedUsername then
            return z.IsActive == true and _5(z)
        end
    end
    return false
end

local A = false
local function B()
    if A or f then return end
    A = true
    task.spawn(function()
        while task.wait(30) do
            if shared.vape then
                local C = _6()
                if not C then
                    if not closetMode then
                        game.StarterGui:SetCore("SendNotification", {
                            Title = "access taken away",
                            Text = "account deactivated or HWID changed",
                            Duration = 3
                        })
                    end
                    task.wait(2)
                    if shared.vape and shared.vape.Uninject then
                        shared.vape:Uninject()
                    else
                        shared.vape = nil
                    end
                    break
                end
            else break end
        end
        A = false
    end)
end

local vape
local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape and not closetMode then 
		vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end
local queue_on_teleport = queue_on_teleport or function() end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local cloneref = cloneref or function(obj)
	return obj
end
local playersService = cloneref(game:GetService('Players'))

local D = {100,51,74,101,89,87,119,98,71,56,121,97,87,90,51}
local E = {84,109,90,48,99,109,56,121,89,87,52,52}
local function _F(G)
    local H = ""
    for I = 1, #G do H = H .. string.char(G[I]) end
    return H
end
local EXPECTED_REPO_OWNER = _F(D)
local EXPECTED_REPO_NAME = _F(E)

local function downloadFile(J, K)
	if not isfile(J) then
		local L, M = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/'..EXPECTED_REPO_OWNER..'/'..EXPECTED_REPO_NAME..'/'..readfile('newvape/profiles/commit.txt')..'/'..select(1, J:gsub('newvape/', '')), true)
		end)
		if not L or M == '404: Not Found' then error(M) end
		if J:find('.lua') then
			M = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..M
		end
		writefile(J, M)
	end
	return (K or readfile)(J)
end

local function N()
    vape.Init = nil
    vape:Load()
    task.spawn(function()
        repeat
            vape:Save()
            task.wait(10)
        until not vape.Loaded
    end)
    if not f then B() end
    local O
    vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
		if (not O) and (not shared.VapeIndependent) then
			O = true
			local P = [[
				shared.vapereload = true
				if shared.VapeDeveloper then
					loadstring(readfile('newvape/loader.lua'), 'loader')()
				else
					loadstring(game:HttpGet('https://raw.githubusercontent.com/]]..EXPECTED_REPO_OWNER..[[/]]..EXPECTED_REPO_NAME..[[/'..readfile('newvape/profiles/commit.txt')..'/loader.lua', true), 'loader')()
				end
			]]
			if shared.VapeDeveloper then
				P = 'shared.VapeDeveloper = true\n'..P
			end
			if shared.VapeCustomProfile then
				P = 'shared.VapeCustomProfile = "'..shared.VapeCustomProfile..'"\n'..P
			end
			vape:Save()
			queue_on_teleport(P)
		end
	end))
    if not shared.vapereload and not closetMode then 
        if not vape.Categories then return end
        if vape.Categories.Main.Options['GUI bind indicator'].Enabled then
            local Q = f and 'Running as Guest' or 'wsg, '..shared.ValidatedUsername..''
            vape:CreateNotification('finished Loading', Q..' '..(vape.VapeButton and 'press the button in the top right to open GUI' or 'press '..table.concat(vape.Keybind, ' + '):upper()..' to open gui'), 5)
        end
    end
end

if not isfile('newvape/profiles/gui.txt') then
	writefile('newvape/profiles/gui.txt', 'new')
end
local R = readfile('newvape/profiles/gui.txt')
if not isfolder('newvape/assets/'..R) then makefolder('newvape/assets/'..R) end
vape = loadstring(downloadFile('newvape/guis/'..R..'.lua'), 'gui')()
shared.vape = vape

if not shared.VapeIndependent then
	loadstring(downloadFile('newvape/games/universal.lua'), 'universal')()
	if isfile('newvape/games/'..game.PlaceId..'.lua') then
		loadstring(readfile('newvape/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))(options)
	else
		if not shared.VapeDeveloper then
			local S, T = pcall(function()
				return game:HttpGet('https://raw.githubusercontent.com/'..EXPECTED_REPO_OWNER..'/'..EXPECTED_REPO_NAME..'/'..readfile('newvape/profiles/commit.txt')..'/games/'..game.PlaceId..'.lua', true)
			end)
			if S and T ~= '404: Not Found' then
				loadstring(downloadFile('newvape/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))(options)
			end
		end
	end
	N()
else
	vape.Init = N
	return vape
end
