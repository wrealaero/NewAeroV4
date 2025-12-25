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

local function validateSecurity()
    if not isfile or not isfile('newvape/security/validated') then
        if not closetMode then
            game.StarterGui:SetCore("SendNotification", {
                Title = "error within security",
                Text = "no validation file found",
                Duration = 3
            })
        end
        return false, nil, nil
    end
    
    local validationContent = readfile('newvape/security/validated')
    local success, validationData = pcall(function()
        return game:GetService("HttpService"):JSONDecode(validationContent)
    end)
    
    if not success or not validationData or not validationData.username then
        if not closetMode then
            game.StarterGui:SetCore("SendNotification", {
                Title = "error within security",
                Text = "wrong validation data",
                Duration = 5
            })
        end
        return false, nil, nil
    end
    
    return true, validationData.username, validationData.guest or false
end

local securityPassed, validatedUsername, isGuest = validateSecurity()
if not securityPassed then
    return
end

shared.ValidatedUsername = validatedUsername
shared.IsGuestAccount = isGuest
shared.DeviceHWID = "HWID_CHECK_DISABLED"

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

local function checkAccountActive()
    if isGuest then return true end
    
    local function fetchAccounts()
        local success, response = pcall(function()
            return game:HttpGet(ACCOUNT_SYSTEM_URL)
        end)
        if success and response then
            local accountsTable = loadstring(response)()
            if accountsTable and accountsTable.Accounts then
                return accountsTable.Accounts
            end
        end
        return nil
    end
    
    local accounts = fetchAccounts()
    if not accounts then 
        return true 
    end
    
    for _, account in pairs(accounts) do
        if account.Username == shared.ValidatedUsername then
            return account.IsActive == true
        end
    end
    return false
end

local activeCheckRunning = false
local function startActiveCheck()
    if activeCheckRunning or isGuest then return end
    activeCheckRunning = true
    
    task.spawn(function()
        while task.wait(30) do
            if shared.vape then
                local isActive = checkAccountActive()
                
                if not isActive then
                    if not closetMode then
                        game.StarterGui:SetCore("SendNotification", {
                            Title = "access revoked",
                            Text = "account deactivated",
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
            else
                break
            end
        end
        activeCheckRunning = false
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

local function finishLoading()
    vape.Init = nil
    vape:Load()
    task.spawn(function()
        repeat
            vape:Save()
            task.wait(10)
        until not vape.Loaded
    end)

    if not isGuest then
        startActiveCheck()
    end

    local teleportedServers
    vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
		if (not teleportedServers) and (not shared.VapeIndependent) then
			teleportedServers = true
			local teleportScript = [[
				shared.vapereload = true
				if shared.VapeDeveloper then
					loadstring(readfile('newvape/loader.lua'), 'loader')()
				else
					loadstring(game:HttpGet('https://raw.githubusercontent.com/wrealaero/NewAeroV4/'..readfile('newvape/profiles/commit.txt')..'/loader.lua', true), 'loader')()
				end
			]]
			if shared.VapeDeveloper then
				teleportScript = 'shared.VapeDeveloper = true\n'..teleportScript
			end
			if shared.VapeCustomProfile then
				teleportScript = 'shared.VapeCustomProfile = "'..shared.VapeCustomProfile..'"\n'..teleportScript
			end
			vape:Save()
			queue_on_teleport(teleportScript)
		end
	end))

    if not shared.vapereload and not closetMode then 
        if not vape.Categories then return end
        if vape.Categories.Main.Options['GUI bind indicator'].Enabled then
            local welcomeMsg = isGuest and 'Running as Guest' or 'Welcome, '..shared.ValidatedUsername..''
            vape:CreateNotification('Finished Loading', welcomeMsg..' '..(vape.VapeButton and 'Press the button in the top right to open GUI' or 'Press '..table.concat(vape.Keybind, ' + '):upper()..' to open GUI'), 5)
        end
    end
end

if not isfile('newvape/profiles/gui.txt') then
	writefile('newvape/profiles/gui.txt', 'new')
end
local gui = readfile('newvape/profiles/gui.txt')

if not isfolder('newvape/assets/'..gui) then
	makefolder('newvape/assets/'..gui)
end
vape = loadstring(downloadFile('newvape/guis/'..gui..'.lua'), 'gui')()
shared.vape = vape

if not shared.VapeIndependent then
	loadstring(downloadFile('newvape/games/universal.lua'), 'universal')()
	if isfile('newvape/games/'..game.PlaceId..'.lua') then
		loadstring(readfile('newvape/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))(options)
	else
		if not shared.VapeDeveloper then
			local suc, res = pcall(function()
				return game:HttpGet('https://raw.githubusercontent.com/wrealaero/NewAeroV4/'..readfile('newvape/profiles/commit.txt')..'/games/'..game.PlaceId..'.lua', true)
			end)
			if suc and res ~= '404: Not Found' then
				loadstring(downloadFile('newvape/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))(options)
			end
		end
	end
	finishLoading()
else
	vape.Init = finishLoading
	return vape
end
