local SecurityModule = {}

local function decodeBase64(data)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if x == '=' then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if #x ~= 8 then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

local EXPECTED_REPO_OWNER = decodeBase64("d3JlYWxhZXJv")
local EXPECTED_REPO_NAME = decodeBase64("TmV3QWVyb1Y0")
local ACCOUNT_SYSTEM_URL = decodeBase64("aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL3dyZWFsYWVyby93aGl0ZWxpc3RjaGVjay9tYWluL0FjY291bnRTeXN0ZW0ubHVh")

local HttpService = game:GetService("HttpService")
local StarterGui = game.StarterGui

local function getHardwareId()
    local hardwareInfo = ""
    
    if syn and syn.crypt then
        hardwareInfo = syn.crypt.hash(syn.crypt.random(16))
    elseif getexecutorname then
        hardwareInfo = getexecutorname() .. tostring(os.clock())
    else
        hardwareInfo = game:GetService("RbxAnalyticsService"):GetClientId() .. tostring(tick())
    end
    
    local hash = ""
    for i = 1, 32 do
        local byte = string.byte(hardwareInfo, (i % #hardwareInfo) + 1)
        hash = hash .. string.format("%02x", byte)
    end
    
    return hash:sub(1, 16)
end

local function createValidationFile(username, repoInfo, hardwareId)
    if not isfolder('newvape/security') then
        makefolder('newvape/security')
    end
    
    local validationData = {
        username = username,
        timestamp = os.time(),
        repo_owner = repoInfo.owner,
        repo_name = repoInfo.name,
        validated = true,
        hardware_id = hardwareId,
        checksum = HttpService:GenerateGUID(false)
    }
    
    local encoded = HttpService:JSONEncode(validationData)
    writefile('newvape/security/validated', encoded)
    writefile('newvape/security/'..username, tostring(os.time()))
end

local function fetchAccounts()
    local success, response = pcall(game.HttpGet, game, ACCOUNT_SYSTEM_URL)
    if success and response then
        local accountsTable = loadstring(response)()
        if accountsTable and accountsTable.Accounts then
            return accountsTable.Accounts
        end
    end
    return nil
end

local function getRepoInfo()
    return {
        owner = EXPECTED_REPO_OWNER,
        name = EXPECTED_REPO_NAME,
        url = 'https://github.com/'..EXPECTED_REPO_OWNER..'/'..EXPECTED_REPO_NAME
    }
end

local function SecurityCheck(loginData)
    if not loginData or type(loginData) ~= "table" then
        StarterGui:SetCore("SendNotification", {
            Title = "Security Error",
            Text = "wrong loadstring bitch. dm aero",
            Duration = 3
        })
        return false
    end
    
    local inputUsername = loginData.Username
    local inputPassword = loginData.Password
    
    if not (inputUsername and inputPassword) then
        StarterGui:SetCore("SendNotification", {
            Title = "Security Error", 
            Text = "missing yo credentials fuck u doing? dm aero",
            Duration = 3
        })
        return false
    end
    
    local accounts = fetchAccounts()
    if not accounts then
        StarterGui:SetCore("SendNotification", {
            Title = "Connection Error",
            Text = "failed to check if its yo account check your wifi it might be shitty. dm aero",
            Duration = 3
        })
        return false
    end
    
    local currentHardwareId = getHardwareId()
    local matchedAccount = nil
    
    for _, account in pairs(accounts) do
        if account.Username == inputUsername and account.Password == inputPassword then
            matchedAccount = account
            break
        end
    end
    
    if not matchedAccount then
        StarterGui:SetCore("SendNotification", {
            Title = "Access Denied",
            Text = "wrong info dm 5qvx for access",
            Duration = 3
        })
        return false
    end
    
    if matchedAccount.IsActive == false then
        StarterGui:SetCore("SendNotification", {
            Title = "Account Suspended",
            Text = "your account has been suspended. dm aero",
            Duration = 3
        })
        return false
    end
    
    if matchedAccount.HardwareId == "" or matchedAccount.HardwareId == nil then
        matchedAccount.HardwareId = currentHardwareId
    elseif matchedAccount.HardwareId ~= currentHardwareId then
        StarterGui:SetCore("SendNotification", {
            Title = "Security Alert", 
            Text = "account is being used on different device. dm aero",
            Duration = 3
        })
        return false
    end
    
    createValidationFile(inputUsername, getRepoInfo(), currentHardwareId)
    return true
end

local passedArgs = ... or {}
if not SecurityCheck(passedArgs) then
    return
end

local isfile = isfile or function(file)
    local suc, res = pcall(readfile, file)
    return suc and res ~= nil and res ~= ''
end

local delfile = delfile or function(file)
    writefile(file, '')
end

local commitText = readfile('newvape/profiles/commit.txt')

local function downloadFile(path, func)
    if not isfile(path) then
        local cleanPath = select(1, path:gsub('newvape/', ''))
        local suc, res = pcall(game.HttpGet, game, 'https://raw.githubusercontent.com/'..EXPECTED_REPO_OWNER..'/'..EXPECTED_REPO_NAME..'/'..commitText..'/'..cleanPath, true)
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
        if not file:find('loader') then
            if isfile(file) then
                local content = readfile(file)
                if content:sub(1, 103) == '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.' then
                    delfile(file)
                end
            end
        end
    end
end

local folders = {'newvape', 'newvape/games', 'newvape/profiles', 'newvape/assets', 'newvape/libraries', 'newvape/guis', 'newvape/security'}
for i = 1, #folders do
    if not isfolder(folders[i]) then
        makefolder(folders[i])
    end
end

if not shared.VapeDeveloper then
    local _, subbed = pcall(game.HttpGet, game, 'https://github.com/'..EXPECTED_REPO_OWNER..'/'..EXPECTED_REPO_NAME)
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

return loadstring(downloadFile('newvape/main.lua'), 'main')()