local AccountSystem = {
    Accounts = {}
}

local function SecurityCheck(loginData)
    if loginData and type(loginData) == "table" then
        local inputUsername = loginData.Username
        local inputPassword = loginData.Password
        
        for _, account in pairs(AccountSystem.Accounts) do
            if account.Username == inputUsername and account.Password == inputPassword then
                return true
            end
        end
    end
    
    local accounts_url = "https://raw.githubusercontent.com/wrealaero/whitelistcheck/main/AccountSystem.lua"
    local player = game.Players.LocalPlayer
    local userId = tostring(player.UserId)

    local function getAccounts()
        local success, response = pcall(function()
            return game:HttpGet(accounts_url)
        end)

        if success and response then
            local successDecode, accounts = pcall(function()
                return loadstring(response)()
            end)

            if successDecode then
                return accounts
            end
        end
        return nil
    end

    local accounts = getAccounts()
    if not (accounts and accounts[userId]) then
        game.StarterGui:SetCore("SendNotification", {
            Title = "FUCK NO LOL",
            Text = "u not whitelisted dm aero to get whitelisted or fuck up",
            Duration = 2
        })
        return false
    end
    
    return true
end

local passedArgs = ... or {}

if not SecurityCheck(passedArgs) then
    return
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

local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/wrealaero/NewAeroV4/'..readfile('newvape/profiles/commit.txt')..'/'..select(1, path:gsub('newvape/', '')), true)
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
		if file:find('loader') then continue end
		if isfile(file) and select(1, readfile(file):find('--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.')) == 1 then
			delfile(file)
		end
	end
end

for _, folder in {'newvape', 'newvape/games', 'newvape/profiles', 'newvape/assets', 'newvape/libraries', 'newvape/guis'} do
	if not isfolder(folder) then
		makefolder(folder)
	end
end

if not shared.VapeDeveloper then
	local _, subbed = pcall(function()
		return game:HttpGet('https://github.com/wrealaero/NewAeroV4')
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

return loadstring(downloadFile('newvape/main.lua'), 'main')()
