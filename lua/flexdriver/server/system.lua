local enableSystem = CreateConVar("sv_flexdriver_enablesystem", "1", FCVAR_NOTIFY + FCVAR_LUA_SERVER)
local enabled = enableSystem:GetBool()
cvars.AddChangeCallback("sv_flexdriver_enablesystem", function(convar, oldValue, newValue)
	enabled = tobool(Either(tonumber(newValue) ~= nil, tonumber(newValue) > 0, false))
end)

net.Receive("flexdriver_replicate", function(len)
	if not enabled then
		return
	end

	local entIndex = net.ReadUInt(14)
	local entity = Entity(entIndex)
	if not IsValid(entity) then
		return
	end

	local boneCount = net.ReadUInt(8)
	for _ = 1, boneCount do
		local bone = net.ReadUInt(8)
		local pos = net.ReadVector()
		local ang = net.ReadAngle()

		entity:ManipulateBonePosition(bone, pos)
		entity:ManipulateBoneAngles(bone, ang)
	end
end)
