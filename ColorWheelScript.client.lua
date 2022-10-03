------------------------------------------------------------------------
local COLOR_WHEEL_VERSION = 1.2
string.format([[ 
	(ɔ◔‿◔)ɔ ♥ (ɔ◔‿◔)ɔ ♥ (ɔ◔‿◔)ɔ ♥ (ɔ◔‿◔)ɔ ♥
	Voxel's Magic Color Wheel v%.1f
	(ɔ◔‿◔)ɔ ♥ (ɔ◔‿◔)ɔ ♥ (ɔ◔‿◔)ɔ ♥ (ɔ◔‿◔)ɔ ♥
]], COLOR_WHEEL_VERSION)
------------------------------------------------------------------------
local UserInputService = game:GetService('UserInputService')
local GuiService = game:GetService('GuiService')

local colorFrame = script.Parent
local root = colorFrame.Parent
local frame = colorFrame.HueSaturationSlider
local wheel = frame.Wheel
local ring = wheel.Ring
local valueSlider = frame.Parent.ValueSlider
local bar = valueSlider.Bar
local textBoxFrame = colorFrame.TextBoxFrame
local textBox = textBoxFrame.TextBox
local adornee = root.Adornee
local property = root.ColorProperty
local serverSided = root.ServerSided.Value

local serverRoot = workspace:FindFirstChild('ColorWheelWorkspace')
local serverEvent : RemoteEvent | nil
local serverCooldownTime : number | nil
local serverDebounce = os.clock()
local serverTicket = -1
local CoreColorModule = require(serverRoot:WaitForChild('CoreColorModule'))

local mouseDown = false
local mouseIn = {}
local dragInterest = {
	{container = frame, ui = ring, x = true, y = true}, 
	{container = valueSlider, ui = bar, x = false, y = true}
}
local lastHueCoords = Vector2.zero
local lastValue = 1.

local adorneeWarn = false
local propertyWarn = false
local ADORNEE_WARN_MESSAGE = [[
Color wheel could not find attached object. Did you set the Adornee?
]]
local PROPERTY_WARN_MESSAGE = [[
Color wheel found object, but failed to set property. Consider changing the ColorProperty.
]]
local SERVER_WARN_MESSAGE = [[
Color wheel did not immediately find ColorWheelWorkspace in the current Workspace. Waiting...
]]
local INVALID_NUM_SPLITS = 'r, g, b'
local NOT_A_NUMBER = 'not a number'

local GLOBAL_OFFSET = GuiService:GetGuiInset() -- mouse coords are offset by this much
------------------------------------------------------------------------
if not serverRoot then
	warn(SERVER_WARN_MESSAGE)
	serverRoot = workspace:WaitForChild('ColorWheelWorkspace')
end
if serverSided then
	serverEvent = serverRoot:WaitForChild('RemoteEvent')
	serverCooldownTime = serverRoot:WaitForChild('Cooldown').Value
end
------------------------------------------------------------------------
local function getHSVFromCoordsAndValue(coords : Vector2, val : number) : Color3
	-- convert mouse coordinates and value to a Color3
	local hue = (math.deg(math.atan2(coords.Y, -coords.X)) / 360.) % 1.
	local sat = 2. * coords.Magnitude

	return Color3.fromHSV(hue, sat, val)
end

local function getCoordsFromHueSat(hue : number, sat : number) : Vector2
	-- convert hue and saturation to local color wheel coordinates
	local r = sat / 2.
	local phi = hue * 2 * math.pi
	local x, y = r * math.sin(phi), r * math.cos(phi)

	return Vector2.new(x, y)
end

local function localMouseCoords(object : GuiObject) : Vector2
	-- get current mouse coords of the LocalPlayer, relative to some other GUI
	local absPosition = object.AbsolutePosition
	local absSize = object.AbsoluteSize
	local mouseXY = UserInputService:GetMouseLocation() - GLOBAL_OFFSET

	return (mouseXY - absPosition) / absSize
end

local function roundColor(color : Color3) : Color3
	--[[
		return a Color3 with rounded values.
		
		The purpose of this is for strings only.
		This is because the string representation
		of a BrickColor is its name, e.g. "Really red".
		Furthermore, BrickColor doesn't internally
		store a value in the range [0, 255]; instead,
		it stores a Color3 in the range [0, 1].
		Though this is technically an invalid use case
		for Color3s because they're supposed to be 
		in the range [0, 1], I use this here because
		it seems to be the most semantically meaningful
		class for this purpose.
	]]
	return Color3.new(
		math.clamp(math.round(255 * color.R), 0, 255), 
		math.clamp(math.round(255 * color.G), 0, 255), 
		math.clamp(math.round(255 * color.B), 0, 255)
	)
end
------------------------------------------------------------------------
local function ticketHandler(ticket : number, color : Color3)
	if ticket == serverTicket then
		serverEvent:FireServer(adornee, property, color)
		serverDebounce = os.clock()
	end
end

local function updateObjectColor(color : Color3)
	-- update object color based on the relevant ObjectValue
	-- update text
	textBox.Text = tostring(roundColor(color))

	-- update object
	local adorneeValue = adornee.Value

	if not (adorneeValue or adorneeWarn) then
		warn(ADORNEE_WARN_MESSAGE)
		adorneeWarn = true
		return
	end

	local success = CoreColorModule:AssignColor(adornee, property, color)

	if not (success or propertyWarn) then
		warn(PROPERTY_WARN_MESSAGE)
		propertyWarn = true
	end
	
	-- server side
	if serverSided and success then
		serverTicket += 1
		local thisTicket = serverTicket
		local delta = serverCooldownTime - (os.clock() - serverDebounce)
		
		task.delay(math.max(0, delta), ticketHandler, thisTicket, color)
	end
end
------------------------------------------------------------------------
local function onInputBegan(input : InputObject)
	local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1
	local isTouch = input.UserInputType == Enum.UserInputType.Touch

	if isMouse or isTouch then
		for _, interestObj in pairs(dragInterest) do
			local mouseGood = mouseIn[interestObj.container.Name]

			if not mouseGood or mouseDown then continue end
			mouseDown = true

			while mouseDown and task.wait() do
				-- localize mouse coords x, y to GUI and convert to scale
				local coords = localMouseCoords(interestObj.container)
				local transCoords = coords - .5 * Vector2.one
				transCoords *= interestObj.p

				-- check if within circle
				local radius = transCoords.Magnitude
				if radius <= .5 then
					-- change position
					local old = interestObj.ui.Position
					local x = (interestObj.x and coords.X) or old.X.Scale
					local y = (interestObj.y and coords.Y) or old.Y.Scale
					local new = UDim2.fromScale(x, y)
					interestObj.ui.Position = new

					-- change color
					if interestObj.container == frame then
						-- hue
						lastHueCoords = transCoords
					else
						-- value
						if radius > .48 then y = math.round(y) end
						lastValue = 1. - y
					end

					local color = getHSVFromCoordsAndValue(lastHueCoords, lastValue)
					updateObjectColor(color)
				end
			end
		end
	end
end

local function onInputEnded(input : InputObject)
	local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1
	local isTouch = input.UserInputType == Enum.UserInputType.Touch

	if isMouse or isTouch then
		mouseDown = false
	end
end

local function onTextEntered()
	local text = textBox.Text

	-- try to split string
	local textSplit = text:split(',')

	-- check num splits
	if #textSplit ~= 3 then
		textBox.Text = INVALID_NUM_SPLITS
		return
	end

	-- check numbers
	for i, v in pairs(textSplit) do
		textSplit[i] = tonumber(v)
		if textSplit[i] == nil then
			textBox.Text = NOT_A_NUMBER
			return
		end
	end

	-- change object color
	local color = Color3.fromRGB(unpack(textSplit))
	local hue, sat, val = color:ToHSV()
	local coords = getCoordsFromHueSat(hue, sat)
	lastHueCoords = coords
	lastValue = val
	coords += .5 * Vector2.one
	ring.Position = UDim2.fromScale(coords.X, coords.Y)
	bar.Position = UDim2.fromScale(.5, math.clamp(1. - lastValue, 0., 1.))

	updateObjectColor(color)
end
------------------------------------------------------------------------
-- initialize default property
if adornee.Value == colorFrame and property.Value == '' then
	property.Value = 'BackgroundColor3'
end

-- initialize dragInterest
for _, interestObj in pairs(dragInterest) do
	local x, y = interestObj.x and 1 or 0, interestObj.y and 1 or 0
	interestObj.p = Vector2.new(x, y)

	local interest = interestObj.container
	mouseIn[interest.Name] = false

	interest.MouseEnter:Connect(function() mouseIn[interest.Name] = true end)
	interest.MouseLeave:Connect(function() mouseIn[interest.Name] = false end)
end

-- connect events
textBox.FocusLost:Connect(onTextEntered)

UserInputService.InputBegan:Connect(onInputBegan)
UserInputService.InputEnded:Connect(onInputEnded)
------------------------------------------------------------------------