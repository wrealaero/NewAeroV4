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

local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end

local delfile = delfile or function(file)
	writefile(file, '')
end

local function decodeBase64(data)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

local function getWhitelistUrl()
    local p1 = "aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29t"
    local p2 = "L3dyZWFsYWVyby93aGl0ZWxpc3RjaGVjay9tYWluL0Fj"
    local p3 = "Y291bnRTeXN0ZW0ubHVh"
    return decodeBase64(p1 .. p2 .. p3)
end

local ACCOUNT_SYSTEM_URL = getWhitelistUrl()

local function saveHWID()
    if not isfolder('newvape/security') then
        makefolder('newvape/security')
    end
    writefile('newvape/security/hwid.txt', "HWID_CHECK_DISABLED")
end

local function createValidation(username, isGuest)
    if not isfolder('newvape/security') then
        makefolder('newvape/security')
    end
    
    local validationData = {
        username = username,
        timestamp = os.time(),
        validated = true,
        guest = isGuest,
        checksum = game:GetService("HttpService"):GenerateGUID(false)
    }
    
    local encoded = game:GetService("HttpService"):JSONEncode(validationData)
    writefile('newvape/security/validated', encoded)
    writefile('newvape/security/'..username, tostring(os.time()))
    saveHWID()
end

local function clearValidation(newUsername)
    if not isfolder('newvape/security') then
        return
    end
    
    if isfile('newvape/security/validated') then
        local success, data = pcall(function()
            return game:GetService("HttpService"):JSONDecode(readfile('newvape/security/validated'))
        end)
        
        if success and data and data.username ~= newUsername then
            for _, file in listfiles('newvape/security') do
                if not file:find('hwid.txt') then
                    delfile(file)
                end
            end
        end
    end
end

local function SecurityCheck(loginData)
    saveHWID()
    
    if not loginData or type(loginData) ~= "table" or not loginData.Username or not loginData.Password then
        createValidation("guest_"..tostring(os.time()), true)
        return true, "guest_"..tostring(os.time()), true
    end
    
    local username = loginData.Username
    local password = loginData.Password
    
    clearValidation(username)
    
    local accountsSuccess, accounts = pcall(function()
        local response = game:HttpGet(ACCOUNT_SYSTEM_URL)
        local accountsTable = loadstring(response)()
        return accountsTable and accountsTable.Accounts
    end)
    
    if not accountsSuccess or not accounts then
        createValidation(username, false)
        return true, username, false
    end
    
    local found = false
    local accountData = nil
    
    for _, account in pairs(accounts) do
        if account.Username == username and account.Password == password then
            found = true
            accountData = account
            break
        end
    end
    
    if not found then
        if not closetMode then
            game.StarterGui:SetCore("SendNotification", {
                Title = "Invalid Credentials",
                Text = "wrong username or password",
                Duration = 10
            })
        end
        createValidation("guest_"..tostring(os.time()), true)
        return true, "guest_"..tostring(os.time()), true
    end
    
    if not accountData.IsActive then
        if not closetMode then
            game.StarterGui:SetCore("SendNotification", {
                Title = "Account Disabled",
                Text = "your account has been deactivated",
                Duration = 5
            })
        end
        createValidation("guest_"..tostring(os.time()), true)
        return true, "guest_"..tostring(os.time()), true
    end
    
    createValidation(username, false)
    return true, username, false
end

local success, username, isGuest = SecurityCheck(options)

if not success then
    return
end

shared.ValidatedUsername = username
shared.IsGuestAccount = isGuest
shared.DeviceHWID = "HWID_CHECK_DISABLED"

local encryptedRepo = "d3JlYWxhZXJv"
local encryptedRepoName = "TmV3QWVyb1Y0"
local EXPECTED_REPO_OWNER = decodeBase64(encryptedRepo)
local EXPECTED_REPO_NAME = decodeBase64(encryptedRepoName)

local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/'..EXPECTED_REPO_OWNER..'/'..EXPECTED_REPO_NAME..'/'..readfile('newvape/profiles/commit.txt')..'/'..select(1, path:gsub('newvape/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function wipeFolder(path)
	if not isfolder(path) then return end
	for _, file in listfiles(path) do
		if file:find('loader') or file:find('hwid.txt') then continue end
		if isfile(file) and select(1, readfile(file):find('--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.')) == 1 then
			delfile(file)
		end
	end
end

for _, folder in {'newvape', 'newvape/games', 'newvape/profiles', 'newvape/assets', 'newvape/libraries', 'newvape/guis', 'newvape/security'} do
	if not isfolder(folder) then
		makefolder(folder)
	end
end

if not shared.VapeDeveloper then
	local _, subbed = pcall(function()
		return game:HttpGet('https://github.com/'..EXPECTED_REPO_OWNER..'/'..EXPECTED_REPO_NAME)
	end)
	local commit = subbed:find('currentOid')
	commit = commit and subbed:sub(commit + 13, commit + 52) or nil
	commit = commit and #commit == 40 and commit or 'main'
	if commit == 'main' or (isfile('newvape/profiles/commit.txt') and readfile('newvape/profiles/commit.txt') or '') ~= commit then
		wipeFolder('newvape')
		wipeFolder('newvape/games')
		wipeFolder('newvape/guis')
		wipeFolder('newvape/libraries')
	end
	writefile('newvape/profiles/commit.txt', commit)
end

return loadstring(downloadFile('newvape/main.lua'), 'main')(options)
