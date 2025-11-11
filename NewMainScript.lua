local function SecurityCheck(bypassData)
    local function DecodeHidden(str)
        local result = ""
        for i = 1, #str do
            result = result .. string.char(string.byte(str, i) + 1)
        end
        return result
    end
    
    local encodedBypass = "zft"
    local encodedKey = "Nbgj`Dbk`Lm`No"   
    local encodedPass = "Bdsn`Ht`LzC`bccz" 
    
    if bypassData and type(bypassData) == "table" then
        local userBypass = bypassData["Bypass"]
        local userKey = bypassData["Key"] 
        local userPass = bypassData["Pass"]
        
        local realBypass = "yes"
        local realKey = "MafiaClanOnTop"
        local realPass = "AeroIsMyDaddy"
        
        if userBypass == realBypass and userKey == realKey and userPass == realPass then
            return true
        end
    end
    
    local whitelist_url = "https://raw.githubusercontent.com/wrealaero/whitelistcheck/main/whitelist.json"
    local player = game.Players.LocalPlayer
    local userId = tostring(player.UserId)

    local function getWhitelist()
        local success, response = pcall(function()
            return game:HttpGet(whitelist_url)
        end)

        if success and response then
            local successDecode, whitelist = pcall(function()
                return game:GetService("HttpService"):JSONDecode(response)
            end)

            if successDecode then
                return whitelist
            end
        end
        return nil
    end

    local whitelist = getWhitelist()
    if not (whitelist and whitelist[userId]) then
        game.StarterGui:SetCore("SendNotification", {
            Title = "Access Denied",
            Text = "Not whitelisted",
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
