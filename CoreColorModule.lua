local module = {}

function module:AssignColor(adornee : ObjectValue, property : StringValue, color : Color3)
	-- given an adornee, property, and value, assign a color
	local adorneeValue = adornee.Value

	if adorneeValue:IsA('Model') or adorneeValue:IsA('Folder') then
		adornee = adorneeValue:GetChildren()
	else
		adornee = {adorneeValue}
	end

	local success, _ = pcall(function()
		for _, obj in pairs(adornee) do
			local key = property.Value
			local value = color

			if key == '' then
				-- try to infer property type
				if obj:IsA('BasePart') then
					value = BrickColor.new(value)
					key = 'BrickColor'
				else
					key = 'Color'
				end
			elseif key == 'BrickColor' then
				value = BrickColor.new(value)
			end

			obj[key] = value
		end
	end)

	return success
end

return module