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
    
    for _, account in pairs(accounts) do
        if account.Username == inputUsername and account.Password == inputPassword then
            return true
        end
    end
    
    StarterGui:SetCore("SendNotification", {
        Title = "Access Denied",
        Text = "wrong info dm 5qvx for access",
        Duration = 3
    })
    return false
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