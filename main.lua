repeat task.wait() until game:IsLoaded()
if shared.vape then shared.vape:Uninject() end

if identifyexecutor then
	local executor = ({identifyexecutor()})[1]
	if executor == 'Argon' or executor == 'Wave' then
		getgenv().setthreadidentity = nil
	end
end

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

local ACCOUNT_SYSTEM_URL = decodeBase64("aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL3dyZWFsYWVyby93aGl0ZWxpc3RjaGVjay9tYWluL0FjY291bnRTeXN0ZW0ubHVh")

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

local function showGlobalAnnouncement()
    local announcementEnabled = true
    local announcementText = "Happy Thanksgiving! Go outside and spend time with family instead of cheating."
    local announcementDuration = 10
    
    if not announcementEnabled then
        return false
    end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "GlobalAnnouncement"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = game:GetService("CoreGui")
    
    local messageFrame = Instance.new("Frame")
    messageFrame.Size = UDim2.new(0.6, 0, 0.3, 0)
    messageFrame.Position = UDim2.new(0.2, 0, 0.35, 0)
    messageFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
    messageFrame.BorderSizePixel = 0
    messageFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = messageFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.new(1, 0.5, 0)
    stroke.Thickness = 3
    stroke.Parent = messageFrame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0.3, 0)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "ANNOUNCEMENT FROM AERO"
    title.TextColor3 = Color3.new(1, 0.5, 0)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.Parent = messageFrame
    
    local message = Instance.new("TextLabel")
    message.Size = UDim2.new(0.9, 0, 0.5, 0)
    message.Position = UDim2.new(0.05, 0, 0.3, 0)
    message.BackgroundTransparency = 1
    message.Text = announcementText
    message.TextColor3 = Color3.new(1, 1, 1)
    message.TextScaled = true
    message.Font = Enum.Font.Gotham
    message.TextWrapped = true
    message.Parent = messageFrame
    
    local countdown = Instance.new("TextLabel")
    countdown.Size = UDim2.new(1, 0, 0.2, 0)
    countdown.Position = UDim2.new(0, 0, 0.8, 0)
    countdown.BackgroundTransparency = 1
    countdown.Text = "Script will not load - Closing in " .. announcementDuration .. " seconds"
    countdown.TextColor3 = Color3.new(0.7, 0.7, 0.7)
    countdown.TextScaled = true
    countdown.Font = Enum.Font.Gotham
    countdown.Parent = messageFrame
    
    task.spawn(function()
        local timeLeft = announcementDuration
        while timeLeft > 0 do
            countdown.Text = "Script will not load - Closing in " .. timeLeft .. " seconds"
            task.wait(1)
            timeLeft = timeLeft - 1
        end
        screenGui:Destroy()
    end)
    
    return true
end

local function setupSuspensionCheck(username)
    local checkInterval = 30
    
    while task.wait(checkInterval) do
        if not vape or not vape.Loaded then break end
        
        local accounts = fetchAccounts()
        if accounts then
            local userAccount = nil
            for _, account in pairs(accounts) do
                if account.Username == username then
                    userAccount = account
                    break
                end
            end
            
            if not userAccount or userAccount.IsActive == false then
                game.StarterGui:SetCore("SendNotification", {
                    Title = "Account Suspended",
                    Text = "Your access has been revoked by admin",
                    Duration = 5
                })
                
                if shared.vape then
                    shared.vape:Uninject()
                end
                break
            end
        end
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
    
    if not (validationData.username and validationData.repo_owner and validationData.repo_name and validationData.validated and validationData.hardware_id) then
        game.StarterGui:SetCore("SendNotification", {
            Title = "Security Error",
            Text = "wrong validation file data.",
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
    
    local currentHardwareId = getHardwareId()
    if validationData.hardware_id ~= currentHardwareId then
        game.StarterGui:SetCore("SendNotification", {
            Title = "Security Error",
            Text = "device mismatch. use your own loadstring.",
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

local announcementShown = showGlobalAnnouncement()
if announcementShown then
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
		setupSuspensionCheck(validatedUsername)
	end)
	
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
