--[[
	Constipated Music Player
	Search songs · Play Roblox audio IDs · Queue · Volume · Visualizer bars
	Search powered by rblxdb.com (verified working SoundIds)
]]

repeat task.wait() until game:IsLoaded() and game:GetService("Players").LocalPlayer

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local GENV = (typeof(getgenv) == "function" and getgenv()) or _G
GENV.__ConstipatedMusic = (GENV.__ConstipatedMusic or 0) + 1
local GEN = GENV.__ConstipatedMusic
local function alive()
	return GENV.__ConstipatedMusic == GEN
end

-- http helpers (executor)
local function httpGet(url)
	local ok, res = pcall(function()
		if typeof(request) == "function" then
			local r = request({ Url = url, Method = "GET" })
			return r.Body or r.body
		elseif typeof(http_request) == "function" then
			local r = http_request({ Url = url, Method = "GET" })
			return r.Body or r.body
		elseif typeof(syn) == "table" and syn.request then
			local r = syn.request({ Url = url, Method = "GET" })
			return r.Body or r.body
		else
			return game:HttpGet(url)
		end
	end)
	if ok then return res end
	return nil
end

-- ===================== STATE =====================
local State = {
	playing = false,
	volume = 0.6,
	loop = false,
	current = nil, -- { name, id }
	queue = {},
	results = {},
	searchQuery = "",
}

-- Sound
local Sound = Instance.new("Sound")
Sound.Name = "CSW_Music"
Sound.Volume = State.volume
Sound.Looped = false
Sound.Parent = SoundService

Sound.Ended:Connect(function()
	if not alive() then return end
	if State.loop and State.current then
		Sound.TimePosition = 0
		Sound:Play()
		return
	end
	-- next in queue
	if #State.queue > 0 then
		local next = table.remove(State.queue, 1)
		playSong(next)
	else
		State.playing = false
		updatePlayBtn()
	end
end)

-- ===================== PLAY =====================
function playSong(song)
	if not song or not song.id then return end
	State.current = song
	State.playing = true
	Sound.SoundId = "rbxassetid://" .. tostring(song.id)
	Sound.Volume = State.volume
	Sound:Play()
	updateNowPlaying()
	updatePlayBtn()
end

local function pauseToggle()
	if not State.current then return end
	if Sound.IsPlaying then
		Sound:Pause()
		State.playing = false
	else
		Sound:Resume()
		State.playing = true
	end
	updatePlayBtn()
end

local function stopSong()
	Sound:Stop()
	State.playing = false
	updatePlayBtn()
end

-- ===================== SEARCH =====================
local function searchSongs(query)
	if not query or #query < 1 then return {} end
	local q = HttpService:UrlEncode(query)
	local url = "https://rblxdb.com/api/v1/songs?q=" .. q .. "&limit=25&working=true"
	local body = httpGet(url)
	if not body then
		-- fallback without working filter
		body = httpGet("https://rblxdb.com/api/v1/songs?q=" .. q .. "&limit=25")
	end
	if not body then return {} end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(body)
	end)
	if not ok or not data then return {} end
	local list = data.songs or data.results or data.data or data
	if typeof(list) ~= "table" then return {} end
	local out = {}
	for _, s in ipairs(list) do
		local id = s.id or s.assetId or s.soundId or s.audioId
		local name = s.name or s.title or s.Name or ("Song " .. tostring(id))
		if id then
			table.insert(out, {
				name = tostring(name),
				id = tonumber(id) or id,
				working = s.isWorking ~= false,
			})
		end
	end
	return out
end

-- also try Roblox catalog proxy style
local function searchCatalogFallback(query)
	local q = HttpService:UrlEncode(query)
	-- public proxies sometimes used by hubs
	local urls = {
		"https://search.roblox.com/catalog/json?Category=9&Keyword=" .. q,
	}
	for _, url in ipairs(urls) do
		local body = httpGet(url)
		if body then
			local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
			if ok and typeof(data) == "table" then
				local out = {}
				for _, s in ipairs(data) do
					local id = s.AssetId or s.assetId or s.Id
					local name = s.Name or s.name
					if id and name then
						table.insert(out, { name = name, id = id, working = true })
					end
				end
				if #out > 0 then return out end
			end
		end
	end
	return {}
end

-- ===================== UI =====================
local Gui = Instance.new("ScreenGui")
Gui.Name = "ConstipatedMusic"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.DisplayOrder = 200
Gui.Parent = PG

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 360, 0, 480)
Main.Position = UDim2.new(0.5, -180, 0.5, -240)
Main.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
Main.BorderSizePixel = 0
Main.Parent = Gui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 14)

local Stroke = Instance.new("UIStroke")
Stroke.Color = Color3.fromRGB(100, 70, 200)
Stroke.Thickness = 1.5
Stroke.Transparency = 0.3
Stroke.Parent = Main

-- Title bar
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -80, 0, 36)
Title.Position = UDim2.new(0, 14, 0, 6)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.TextColor3 = Color3.fromRGB(220, 200, 255)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Text = "Constipated Music"
Title.Parent = Main

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -36, 0, 8)
CloseBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 50)
CloseBtn.Text = "X"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
CloseBtn.Parent = Main
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 8)

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 28, 0, 28)
MinBtn.Position = UDim2.new(1, -68, 0, 8)
MinBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 50)
MinBtn.Text = "_"
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 14
MinBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
MinBtn.Parent = Main
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 8)

-- Now playing
local NowFrame = Instance.new("Frame")
NowFrame.Size = UDim2.new(1, -24, 0, 70)
NowFrame.Position = UDim2.new(0, 12, 0, 44)
NowFrame.BackgroundColor3 = Color3.fromRGB(28, 26, 40)
NowFrame.BorderSizePixel = 0
NowFrame.Parent = Main
Instance.new("UICorner", NowFrame).CornerRadius = UDim.new(0, 10)

local NowLabel = Instance.new("TextLabel")
NowLabel.Size = UDim2.new(1, -16, 0, 20)
NowLabel.Position = UDim2.new(0, 10, 0, 8)
NowLabel.BackgroundTransparency = 1
NowLabel.Font = Enum.Font.Gotham
NowLabel.TextSize = 11
NowLabel.TextColor3 = Color3.fromRGB(150, 140, 180)
NowLabel.TextXAlignment = Enum.TextXAlignment.Left
NowLabel.Text = "NOW PLAYING"
NowLabel.Parent = NowFrame

local SongTitle = Instance.new("TextLabel")
SongTitle.Size = UDim2.new(1, -16, 0, 22)
SongTitle.Position = UDim2.new(0, 10, 0, 28)
SongTitle.BackgroundTransparency = 1
SongTitle.Font = Enum.Font.GothamBold
SongTitle.TextSize = 14
SongTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
SongTitle.TextXAlignment = Enum.TextXAlignment.Left
SongTitle.TextTruncate = Enum.TextTruncate.AtEnd
SongTitle.Text = "Nothing playing"
SongTitle.Parent = NowFrame

local TimeLabel = Instance.new("TextLabel")
TimeLabel.Size = UDim2.new(1, -16, 0, 14)
TimeLabel.Position = UDim2.new(0, 10, 0, 50)
TimeLabel.BackgroundTransparency = 1
TimeLabel.Font = Enum.Font.Gotham
TimeLabel.TextSize = 11
TimeLabel.TextColor3 = Color3.fromRGB(140, 130, 160)
TimeLabel.TextXAlignment = Enum.TextXAlignment.Left
TimeLabel.Text = "0:00 / 0:00"
TimeLabel.Parent = NowFrame

-- Controls
local Ctrl = Instance.new("Frame")
Ctrl.Size = UDim2.new(1, -24, 0, 44)
Ctrl.Position = UDim2.new(0, 12, 0, 122)
Ctrl.BackgroundTransparency = 1
Ctrl.Parent = Main

local function makeCtrl(text, x, w)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, w or 56, 0, 36)
	b.Position = UDim2.new(0, x, 0, 4)
	b.BackgroundColor3 = Color3.fromRGB(45, 35, 70)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = Color3.fromRGB(230, 220, 255)
	b.Text = text
	b.Parent = Ctrl
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	return b
end

local PrevBtn = makeCtrl("Prev", 0, 70)
local PlayBtn = makeCtrl("Play", 80, 90)
local NextBtn = makeCtrl("Next", 180, 70)
local LoopBtn = makeCtrl("Loop", 260, 64)

-- Volume
local VolLabel = Instance.new("TextLabel")
VolLabel.Size = UDim2.new(0, 60, 0, 20)
VolLabel.Position = UDim2.new(0, 12, 0, 172)
VolLabel.BackgroundTransparency = 1
VolLabel.Font = Enum.Font.Gotham
VolLabel.TextSize = 12
VolLabel.TextColor3 = Color3.fromRGB(180, 170, 200)
VolLabel.TextXAlignment = Enum.TextXAlignment.Left
VolLabel.Text = "Vol 60%"
VolLabel.Parent = Main

local VolBar = Instance.new("Frame")
VolBar.Size = UDim2.new(1, -90, 0, 8)
VolBar.Position = UDim2.new(0, 74, 0, 178)
VolBar.BackgroundColor3 = Color3.fromRGB(40, 35, 55)
VolBar.BorderSizePixel = 0
VolBar.Parent = Main
Instance.new("UICorner", VolBar).CornerRadius = UDim.new(1, 0)

local VolFill = Instance.new("Frame")
VolFill.Size = UDim2.new(State.volume, 0, 1, 0)
VolFill.BackgroundColor3 = Color3.fromRGB(140, 100, 255)
VolFill.BorderSizePixel = 0
VolFill.Parent = VolBar
Instance.new("UICorner", VolFill).CornerRadius = UDim.new(1, 0)

-- Search
local SearchBox = Instance.new("TextBox")
SearchBox.Size = UDim2.new(1, -100, 0, 34)
SearchBox.Position = UDim2.new(0, 12, 0, 200)
SearchBox.BackgroundColor3 = Color3.fromRGB(30, 28, 42)
SearchBox.PlaceholderText = "Search songs (e.g. muga million)..."
SearchBox.PlaceholderColor3 = Color3.fromRGB(120, 110, 140)
SearchBox.Text = ""
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 13
SearchBox.TextColor3 = Color3.fromRGB(240, 240, 255)
SearchBox.ClearTextOnFocus = false
SearchBox.Parent = Main
Instance.new("UICorner", SearchBox).CornerRadius = UDim.new(0, 8)
local pad = Instance.new("UIPadding", SearchBox)
pad.PaddingLeft = UDim.new(0, 10)

local SearchBtn = Instance.new("TextButton")
SearchBtn.Size = UDim2.new(0, 76, 0, 34)
SearchBtn.Position = UDim2.new(1, -88, 0, 200)
SearchBtn.BackgroundColor3 = Color3.fromRGB(120, 80, 220)
SearchBtn.Font = Enum.Font.GothamBold
SearchBtn.TextSize = 13
SearchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SearchBtn.Text = "Search"
SearchBtn.Parent = Main
Instance.new("UICorner", SearchBtn).CornerRadius = UDim.new(0, 8)

-- Status
local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -24, 0, 18)
Status.Position = UDim2.new(0, 12, 0, 238)
Status.BackgroundTransparency = 1
Status.Font = Enum.Font.Gotham
Status.TextSize = 11
Status.TextColor3 = Color3.fromRGB(140, 130, 170)
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.Text = "Search for a song to begin"
Status.Parent = Main

-- Results list
local List = Instance.new("ScrollingFrame")
List.Size = UDim2.new(1, -24, 1, -270)
List.Position = UDim2.new(0, 12, 0, 258)
List.BackgroundColor3 = Color3.fromRGB(24, 22, 34)
List.BorderSizePixel = 0
List.ScrollBarThickness = 4
List.ScrollBarImageColor3 = Color3.fromRGB(120, 90, 200)
List.CanvasSize = UDim2.new(0, 0, 0, 0)
List.Parent = Main
Instance.new("UICorner", List).CornerRadius = UDim.new(0, 10)

local ListLayout = Instance.new("UIListLayout")
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding = UDim.new(0, 4)
ListLayout.Parent = List
local ListPad = Instance.new("UIPadding", List)
ListPad.PaddingTop = UDim.new(0, 6)
ListPad.PaddingLeft = UDim.new(0, 6)
ListPad.PaddingRight = UDim.new(0, 6)

-- Manual ID
local IdBox = Instance.new("TextBox")
IdBox.Size = UDim2.new(1, -100, 0, 0) -- hidden by default; we use search mainly
IdBox.Visible = false
IdBox.Parent = Main

-- ===================== UI HELPERS =====================
function updateNowPlaying()
	if State.current then
		SongTitle.Text = State.current.name or ("ID " .. tostring(State.current.id))
	else
		SongTitle.Text = "Nothing playing"
	end
end

function updatePlayBtn()
	PlayBtn.Text = State.playing and "Pause" or "Play"
end

local function fmtTime(t)
	t = math.floor(t or 0)
	local m = math.floor(t / 60)
	local s = t % 60
	return string.format("%d:%02d", m, s)
end

local function clearResults()
	for _, c in ipairs(List:GetChildren()) do
		if c:IsA("TextButton") or c:IsA("Frame") then c:Destroy() end
	end
end

local function addResultRow(song, order)
	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, -4, 0, 40)
	row.BackgroundColor3 = Color3.fromRGB(36, 32, 52)
	row.Font = Enum.Font.Gotham
	row.TextSize = 12
	row.TextColor3 = Color3.fromRGB(230, 225, 255)
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.Text = "  " .. (song.name or "Unknown")
	row.AutoButtonColor = true
	row.LayoutOrder = order
	row.Parent = List
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

	local playSmall = Instance.new("TextLabel")
	playSmall.Size = UDim2.new(0, 50, 1, 0)
	playSmall.Position = UDim2.new(1, -54, 0, 0)
	playSmall.BackgroundTransparency = 1
	playSmall.Font = Enum.Font.GothamBold
	playSmall.TextSize = 11
	playSmall.TextColor3 = Color3.fromRGB(160, 130, 255)
	playSmall.Text = "PLAY"
	playSmall.Parent = row

	row.MouseButton1Click:Connect(function()
		playSong(song)
		Status.Text = "Playing: " .. (song.name or song.id)
	end)
end

local function refreshList()
	clearResults()
	for i, song in ipairs(State.results) do
		addResultRow(song, i)
	end
	task.defer(function()
		List.CanvasSize = UDim2.new(0, 0, 0, ListLayout.AbsoluteContentSize.Y + 12)
	end)
end

local function doSearch()
	local q = SearchBox.Text
	if not q or #q < 1 then
		Status.Text = "Type a song name first"
		return
	end
	Status.Text = "Searching..."
	SearchBtn.Text = "..."
	task.spawn(function()
		local results = searchSongs(q)
		if #results == 0 then
			results = searchCatalogFallback(q)
		end
		State.results = results
		refreshList()
		Status.Text = #results > 0 and ("Found " .. #results .. " songs") or "No songs found — try another name"
		SearchBtn.Text = "Search"
	end)
end

-- ===================== EVENTS =====================
SearchBtn.MouseButton1Click:Connect(doSearch)
SearchBox.FocusLost:Connect(function(enter)
	if enter then doSearch() end
end)

PlayBtn.MouseButton1Click:Connect(function()
	if State.current then
		pauseToggle()
	elseif #State.results > 0 then
		playSong(State.results[1])
	end
end)

PrevBtn.MouseButton1Click:Connect(function()
	Sound.TimePosition = 0
end)

NextBtn.MouseButton1Click:Connect(function()
	if #State.queue > 0 then
		playSong(table.remove(State.queue, 1))
	elseif #State.results > 0 then
		local idx = 1
		if State.current then
			for i, s in ipairs(State.results) do
				if s.id == State.current.id then idx = i + 1 break end
			end
		end
		if State.results[idx] then
			playSong(State.results[idx])
		end
	end
end)

LoopBtn.MouseButton1Click:Connect(function()
	State.loop = not State.loop
	Sound.Looped = State.loop
	LoopBtn.BackgroundColor3 = State.loop and Color3.fromRGB(100, 70, 180) or Color3.fromRGB(45, 35, 70)
end)

-- volume drag
local volDragging = false
VolBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		volDragging = true
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		volDragging = false
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if not volDragging then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		local rel = math.clamp((input.Position.X - VolBar.AbsolutePosition.X) / VolBar.AbsoluteSize.X, 0, 1)
		State.volume = rel
		Sound.Volume = rel
		VolFill.Size = UDim2.new(rel, 0, 1, 0)
		VolLabel.Text = "Vol " .. math.floor(rel * 100) .. "%"
	end
end)

CloseBtn.MouseButton1Click:Connect(function()
	GENV.__ConstipatedMusic = GEN + 1
	Sound:Stop()
	Sound:Destroy()
	Gui:Destroy()
end)

local minimized = false
MinBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	if minimized then
		Main.Size = UDim2.new(0, 360, 0, 44)
		for _, c in ipairs(Main:GetChildren()) do
			if c ~= Title and c ~= CloseBtn and c ~= MinBtn and c:IsA("GuiObject") then
				c.Visible = false
			end
		end
	else
		Main.Size = UDim2.new(0, 360, 0, 480)
		for _, c in ipairs(Main:GetChildren()) do
			if c:IsA("GuiObject") then c.Visible = true end
		end
	end
end)

-- drag window
local dragging, dragStart, startPos
Title.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = Main.Position
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if not dragging then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		local d = input.Position - dragStart
		Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end)

-- time update
RunService.RenderStepped:Connect(function()
	if not alive() then return end
	if Sound.IsPlaying or State.current then
		TimeLabel.Text = fmtTime(Sound.TimePosition) .. " / " .. fmtTime(Sound.TimeLength)
	end
end)

-- play by raw ID helper: type "id:123456" in search
SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
	local t = SearchBox.Text
	if t and t:match("^id:%d+") then
		local id = t:match("id:(%d+)")
		if id then
			Status.Text = "Press Search to play ID " .. id
		end
	end
end)

-- if user searches id:NUMBER play directly
local oldDoSearch = doSearch
doSearch = function()
	local t = SearchBox.Text or ""
	local id = t:match("^id:(%d+)$") or t:match("^(%d+)$")
	if id and #t < 15 then
		playSong({ name = "Audio " .. id, id = tonumber(id) })
		Status.Text = "Playing ID " .. id
		return
	end
	oldDoSearch()
end
SearchBtn.MouseButton1Click:Connect(doSearch)

print("[Constipated Music] loaded — search a song name")
