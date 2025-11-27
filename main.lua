repeat task.wait() until game:IsLoaded()
if shared.vape then shared.vape:Uninject() end

if identifyexecutor then
	local executor = ({identifyexecutor()})[1]
	if executor == 'Argon' or executor == 'Wave' then
		getgenv().setthreadidentity = nil
	end
end

local function validateSecurity()
    local HttpService = game:GetService("HttpService")
    
    if not isfile('newvape/security/validated') then
        game.StarterGui:SetCore("SendNotification", {
            Title = "Security Error",
            Text = "can't find yo validation file.",
            Duration = 5
        })
        return false, nil
    end
    
    local validationContent = readfile('newvape/security/validated')
    local success, validationData = pcall(HttpService.JSONDecode, HttpService, validationContent)
    
    if not success or not validationData then
        game.StarterGui:SetCore("SendNotification", {
            Title = "Security Error",
            Text = "validation file corrupted.",
            Duration = 5
        })
        return false, nil
    end
    
    if not (validationData.username and validationData.repo_owner and validationData.repo_name and validationData.validated) then
        game.StarterGui:SetCore("SendNotification", {
            Title = "Security Error",
            Text = "wronmg validation file data.",
            Duration = 5
        })
        return false, nil
    end
    
    if not isfile('newvape/security/'..validationData.username) then
        game.StarterGui:SetCore("SendNotification", {
            Title = "Security Error",
            Text = "user validation data missing.",
            Duration = 5
        })
        return false, nil
    end
    
    if validationData.repo_owner ~= "wrealaero" or validationData.repo_name ~= "NewAeroV4" then
        game.StarterGui:SetCore("SendNotification", {
            Title = "Security Error",
            Text = "wrong loadstring bud.",
            Duration = 5
        })
        return false, nil
    end
    
    return true, validationData.username
end

local securityPassed, validatedUsername = validateSecurity()
if not securityPassed then
    return
end

shared.ValidatedUsername = validatedUsername

local vape
local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then
		vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end
local queue_on_teleport = queue_on_teleport or function() end
local isfile = isfile or function(file)
	local suc, res = pcall(readfile, file)
	return suc and res ~= nil and res ~= ''
end
local cloneref = cloneref or function(obj)
	return obj
end
local playersService = cloneref(game:GetService('Players'))

local commitText = readfile('newvape/profiles/commit.txt')

local function downloadFile(path, func)
	if not isfile(path) then
		local cleanPath = select(1, path:gsub('newvape/', ''))
		local suc, res = pcall(game.HttpGet, game, 'https://raw.githubusercontent.com/wrealaero/NewAeroV4/'..commitText..'/'..cleanPath, true)
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

	local teleportedServers
	vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
		if teleportedServers or shared.VapeIndependent then return end
		teleportedServers = true
		local teleportScript = 'shared.vapereload = true\n'
		if shared.VapeDeveloper then
			teleportScript = teleportScript..'shared.VapeDeveloper = true\n'
		end
		if shared.VapeCustomProfile then
			teleportScript = teleportScript..'shared.VapeCustomProfile = "'..shared.VapeCustomProfile..'"\n'
		end
		if shared.VapeDeveloper then
			teleportScript = teleportScript..'loadstring(readfile(\'newvape/loader.lua\'), \'loader\')()'
		else
			teleportScript = teleportScript..'loadstring(game:HttpGet(\'https://raw.githubusercontent.com/wrealaero/NewAeroV4/\'..readfile(\'newvape/profiles/commit.txt\')..\'//loader.lua\', true), \'loader\')()'
		end
		vape:Save()
		queue_on_teleport(teleportScript)
	end))

	if not shared.vapereload then
		if not vape.Categories then return end
		if vape.Categories.Main.Options['GUI bind indicator'].Enabled then
			vape:CreateNotification('Finished Loading', 'Welcome, '..shared.ValidatedUsername..'! '..(vape.VapeButton and 'Press the button in the top right to open GUI' or 'Press '..table.concat(vape.Keybind, ' + '):upper()..' to open GUI'), 5)
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
		loadstring(readfile('newvape/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))(...)
	elseif not shared.VapeDeveloper then
		local suc, res = pcall(game.HttpGet, game, 'https://raw.githubusercontent.com/wrealaero/NewAeroV4/'..commitText..'/games/'..game.PlaceId..'.lua', true)
		if suc and res ~= '404: Not Found' then
			loadstring(downloadFile('newvape/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))(...)
		end
	end
	finishLoading()
else
	vape.Init = finishLoading
	return vape
end