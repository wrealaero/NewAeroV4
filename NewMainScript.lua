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

local _1 = {}
for i = 65, 90 do table.insert(_1, i) end
for i = 97, 122 do table.insert(_1, i) end
for i = 48, 57 do table.insert(_1, i) end
table.insert(_1, 43) table.insert(_1, 47)

local function _2(a)
    local b = ""
    for i = 1, #a do
        local c = a[i]
        if c == 61 then break end
        local d = table.find(_1, c)
        if d then
            local e = d - 1
            b = b .. string.format("%06d", tonumber(string.format("%d", e)))
        end
    end
    local f = ""
    for i = 1, #b, 8 do
        local g = b:sub(i, i + 7)
        if #g == 8 then
            local h = 0
            for j = 1, 8 do
                if g:sub(j, j) == "1" then
                    h = h + 2^(8-j)
                end
            end
            f = f .. string.char(h)
        end
    end
    return f
end

local function _3()
    local i = "aHR0cHM6Ly9wYXN0ZWJpbi5jb20vcmF3L0N2MmZNeDg5"
    return _2(i)
end

local ACCOUNT_SYSTEM_URL = _3()

local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end

local delfile = delfile or function(file)
	writefile(file, '')
end

local function _4()
    local j = {}
    if gethwid then return gethwid() end
    if identifyexecutor then table.insert(j, ({identifyexecutor()})[1] or "U") end
    table.insert(j, game.JobId)
    if game:GetService("HttpService") then
        table.insert(j, game:GetService("HttpService"):GenerateGUID(false))
    end
    return table.concat(j, "-")
end

local DEVICE_HWID = _4()

local function _5()
    if setclipboard then
        pcall(function() setclipboard(DEVICE_HWID) end)
        return true
    end
    return false
end

local function _6()
    if not isfolder('newvape/security') then makefolder('newvape/security') end
    writefile('newvape/security/hwid.txt', DEVICE_HWID)
end

local function _7(k, l)
    if not isfolder('newvape/security') then makefolder('newvape/security') end
    local m = {
        username = k,
        timestamp = os.time(),
        validated = true,
        guest = l,
        hwid = DEVICE_HWID,
        checksum = game:GetService("HttpService"):GenerateGUID(false)
    }
    local n = game:GetService("HttpService"):JSONEncode(m)
    writefile('newvape/security/validated', n)
    writefile('newvape/security/'..k, tostring(os.time()))
    _6()
end

local function _8(o)
    if not isfolder('newvape/security') then return end
    if isfile('newvape/security/validated') then
        local p, q = pcall(function()
            return game:GetService("HttpService"):JSONDecode(readfile('newvape/security/validated'))
        end)
        if p and q and q.username ~= o then
            for _, r in listfiles('newvape/security') do
                if not r:find('hwid.txt') then delfile(r) end
            end
        end
    end
end

local function _9(s)
    _6()
    local t = s.Username
    local u = s.Password
    _8(t)
    local v, w = pcall(function()
        local x = game:HttpGet(ACCOUNT_SYSTEM_URL)
        local y = loadstring(x)()
        return y and y.Accounts
    end)
    if not v or not w then
        _7(t, false)
        return true, t, false
    end
    local z = false
    local A = nil
    for _, B in pairs(w) do
        if B.Username == t and B.Password == u then
            z = true
            A = B
            break
        end
    end
    if not z then
        _5()
        if not closetMode then
            game.StarterGui:SetCore("SendNotification", {
                Title = "wrong info",
                Text = "wrong username or password",
                Duration = 5
            })
        end
        _7("guest_"..tostring(os.time()), true)
        return true, "guest_"..tostring(os.time()), true
    end
    if not A.IsActive then
        if not closetMode then
            game.StarterGui:SetCore("SendNotification", {
                Title = "Account Disabled",
                Text = "your account has been deactivated(dm aero - 5qvx)",
                Duration = 3
            })
        end
        _7("guest_"..tostring(os.time()), true)
        return true, "guest_"..tostring(os.time()), true
    end
    _7(t, false)
    return true, t, false
end

local C, D, E = _9(options)
if not C then return end
shared.ValidatedUsername = D
shared.IsGuestAccount = E
shared.DeviceHWID = DEVICE_HWID

local F = {100,51,74,101,89,87,119,98,71,56,121,97,87,90,51}
local G = {84,109,90,48,99,109,56,121,89,87,52,52}
local function _H(I)
    local J = ""
    for K = 1, #I do J = J .. string.char(I[K]) end
    return J
end
local EXPECTED_REPO_OWNER = _H(F)
local EXPECTED_REPO_NAME = _H(G)

local function downloadFile(L, M)
	if not isfile(L) then
		local N, O = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/'..EXPECTED_REPO_OWNER..'/'..EXPECTED_REPO_NAME..'/'..readfile('newvape/profiles/commit.txt')..'/'..select(1, L:gsub('newvape/', '')), true)
		end)
		if not N or O == '404: Not Found' then error(O) end
		if L:find('.lua') then
			O = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..O
		end
		writefile(L, O)
	end
	return (M or readfile)(L)
end

local function wipeFolder(P)
	if not isfolder(P) then return end
	for _, Q in listfiles(P) do
		if Q:find('loader') or Q:find('hwid.txt') then continue end
		if isfile(Q) and select(1, readfile(Q):find('--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.')) == 1 then
			delfile(Q)
		end
	end
end

for _, R in {'newvape', 'newvape/games', 'newvape/profiles', 'newvape/assets', 'newvape/libraries', 'newvape/guis', 'newvape/security'} do
	if not isfolder(R) then makefolder(R) end
end

if not shared.VapeDeveloper then
	local S, T = pcall(function()
		return game:HttpGet('https://github.com/'..EXPECTED_REPO_OWNER..'/'..EXPECTED_REPO_NAME)
	end)
	local U = T:find('currentOid')
	U = U and T:sub(U + 13, U + 52) or nil
	U = U and #U == 40 and U or 'main'
	if U == 'main' or (isfile('newvape/profiles/commit.txt') and readfile('newvape/profiles/commit.txt') or '') ~= U then
		wipeFolder('newvape')
		wipeFolder('newvape/games')
		wipeFolder('newvape/guis')
		wipeFolder('newvape/libraries')
	end
	writefile('newvape/profiles/commit.txt', U)
end

return loadstring(downloadFile('newvape/main.lua'), 'main')(options)
