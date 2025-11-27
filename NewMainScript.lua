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
    
    if matchedAccount.IsActive