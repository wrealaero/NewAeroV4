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

local _1 = {116, 104, 105, 115, 105, 115, 97, 116, 101, 115, 116}
local _2 = {112, 97, 115, 116, 101, 98, 105, 110, 46, 99, 111, 109}
local _3 = {114, 97, 119, 47, 67, 118, 50, 102, 77, 120, 56, 57}

local function _a(b)
    local c = ""
    for d = 1, #b do
        c = c .. string.char(b[d])
    end
    return c
end

local function _e(f)
    local g = ""
    for h = 1, #f do
        local i = f:byte(h)
        g = g .. string.char(255 - i)
    end
    return g
end

local function getWhitelistUrl()
    local j = _a(_1)
    local k = _a(_2)
    local l = _a(_3)
    return "https://" .. _e(k) .. "/" .. _e(l)
end

local ACCOUNT_SYSTEM_URL = getWhitelistUrl()

local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end

local delfile = delfile or function(file)
	writefile(file, '')
end

local function getHWID()
    local m = {}
    
    if gethwid then
        return gethwid()
    end
    
    if identifyexecutor then
        table.insert(m, ({identifyexecutor()})[1] or "U")
    end
    
    table.insert(m, game.JobId)
    
    if game:GetService("HttpService") then
        table.insert(m, game:GetService("HttpService"):GenerateGUID(false))
    end
    
    return table.concat(m, "-")
end

local DEVICE_HWID = getHWID()

local function copyHWID()
    if setclipboard then
        pcall(function() setclipboard(DEVICE_HWID) end)
        return true
    end
    return false
end

local function saveHWID()
    if not isfolder('newvape/security') then
        makefolder('newvape/security')
    end
    writefile('newvape/security/hwid.txt', DEVICE_HWID)
end

local function createValidation(n, o)
    if not isfolder('newvape/security') then
        makefolder('newvape/security')
    end
    
    local p = {
        username = n,
        timestamp = os.time(),
        validated = true,
        guest = o,
        hwid = DEVICE_HWID,
        checksum = game:GetService("HttpService"):GenerateGUID(false)
    }
    
    local q = game:GetService("HttpService"):JSONEncode(p)
    writefile('newvape/security/validated', q)
    writefile('newvape/security/'..n, tostring(os.time()))
    saveHWID()
end

local function clearValidation(r)
    if not isfolder('newvape/security') then
        return
    end
    
    if isfile('newvape/security/validated') then
        local s, t = pcall(function()
            return game:GetService("HttpService"):JSONDecode(readfile('newvape/security/validated'))
        end)
        
        if s and t and t.username ~= r then
            for _, u in listfiles('newvape/security') do
                if not u:find('hwid.txt') then
                    delfile(u)
                end
            end
        end
    end
end

local function SecurityCheck(v)
    saveHWID()
    
    if not v or type(v) ~= "table" or not v.Username or not v.Password then
        createValidation("guest_"..tostring(os.time()), true)
        if not closetMode then
            game.StarterGui:SetCore("SendNotification", {
                Title = "Guest Mode",
                Text = "Running as a guest account",
                Duration = 3
            })
        end
        return true, "guest_"..tostring(os.time()), true
    end
    
    local w = v.Username
    local x = v.Password
    
    clearValidation(w)
    
    local y, z = pcall(function()
        local A = game:HttpGet(ACCOUNT_SYSTEM_URL)
        local B = loadstring(A)()
        return B and B.Accounts
    end)
    
    if not y or not z then
        createValidation(w, false)
        if not closetMode then
            game.StarterGui:SetCore("SendNotification", {
                Title = "Login Successful",
                Text = "Logged in as " .. w,
                Duration = 5
            })
        end
        return true, w, false
    end
    
    local C = false
    local D = nil
    
    for _, E in pairs(z) do
        if E.Username == w and E.Password == x then
            C = true
            D = E
            break
        end
    end
    
    if not C then
        copyHWID()
        if not closetMode then
            game.StarterGui:SetCore("SendNotification", {
                Title = "Invalid Credentials",
                Text = "Wrong username or password",
                Duration = 10
            })
        end
        createValidation("guest_"..tostring(os.time()), true)
        return true, "guest_"..tostring(os.time()), true
    end
    
    if not D.IsActive then
        if not closetMode then
            game.StarterGui:SetCore("SendNotification", {
                Title = "Account Disabled",
                Text = "Your account has been deactivated",
                Duration = 5
            })
        end
        createValidation("guest_"..tostring(os.time()), true)
        return true, "guest_"..tostring(os.time()), true
    end
    
    createValidation(w, false)
    return true, w, false
end

local F, G, H = SecurityCheck(options)

if not F then
    return
end

shared.ValidatedUsername = G
shared.IsGuestAccount = H
shared.DeviceHWID = DEVICE_HWID

local I = {100, 51, 74, 101, 89, 87, 119, 98, 71, 56, 121, 97, 87, 90, 51}
local J = {84, 109, 90, 48, 99, 109, 56, 121, 89, 87, 52, 52}

local function _K(L)
    local M = ""
    for N = 1, #L do
        M = M .. string.char(L[N])
    end
    return M
end

local EXPECTED_REPO_OWNER = _K(I)
local EXPECTED_REPO_NAME = _K(J)

local function downloadFile(O, P)
	if not isfile(O) then
		local Q, R = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/'..EXPECTED_REPO_OWNER..'/'..EXPECTED_REPO_NAME..'/'..readfile('newvape/profiles/commit.txt')..'/'..select(1, O:gsub('newvape/', '')), true)
		end)
		if not Q or R == '404: Not Found' then
			error(R)
		end
		if O:find('.lua') then
			R = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..R
		end
		writefile(O, R)
	end
	return (P or readfile)(O)
end

local function wipeFolder(S)
	if not isfolder(S) then return end
	for _, T in listfiles(S) do
		if T:find('loader') or T:find('hwid.txt') then continue end
		if isfile(T) and select(1, readfile(T):find('--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.')) == 1 then
			delfile(T)
		end
	end
end

for _, U in {'newvape', 'newvape/games', 'newvape/profiles', 'newvape/assets', 'newvape/libraries', 'newvape/guis', 'newvape/security'} do
	if not isfolder(U) then
		makefolder(U)
	end
end

if not shared.VapeDeveloper then
	local V, W = pcall(function()
		return game:HttpGet('https://github.com/'..EXPECTED_REPO_OWNER..'/'..EXPECTED_REPO_NAME)
	end)
	local X = W:find('currentOid')
	X = X and W:sub(X + 13, X + 52) or nil
	X = X and #X == 40 and X or 'main'
	if X == 'main' or (isfile('newvape/profiles/commit.txt') and readfile('newvape/profiles/commit.txt') or '') ~= X then
		wipeFolder('newvape')
		wipeFolder('newvape/games')
		wipeFolder('newvape/guis')
		wipeFolder('newvape/libraries')
	end
	writefile('newvape/profiles/commit.txt', X)
end

return loadstring(downloadFile('newvape/main.lua'), 'main')(options)
