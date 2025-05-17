---@module "flexdriver.shared.helpers"
local helpers = include("flexdriver/shared/helpers.lua")

---@module "flexdriver.client.driver"
local driver = include("flexdriver/client/driver.lua")

local ipairs_sparse = helpers.ipairs_sparse

---@type ClientFlexableInfo
local flexableInfo = {
	flexables = {},
	previousCount = 0,
	count = 0,
}

local system = {}

---Make a table to store the entity, its bones, and other fields,
---rather than storing it in the entity itself to avoid Entity.__index calls
---@param entity Entity
---@param d Driver
---@return ClientFlexable
local function constructFlexable(entity, d)
	return {
		entity = entity,
		drivers = driver.array({ d }, entity),
		resetters = {},
	}
end

---@param entIndex integer
local function removeFlexable(entIndex)
	flexableInfo.flexables[entIndex] = nil
	flexableInfo.count = flexableInfo.count - 1
end

---@param entIndex number
---@return ClientFlexable
local function addFlexable(entIndex, driver)
	local flexable = constructFlexable(Entity(entIndex), driver)
	flexableInfo.flexables[entIndex] = flexable
	flexableInfo.count = flexableInfo.count + 1
	return flexable
end

---Set driver parameters with `driverInfo` for the specified `driverId` of an `entity`
---@param entity Entity
---@param driverId integer
---@param driverInfo DriverInfo
function system.setDriver(entity, driverId, driverInfo)
	local entIndex = entity:EntIndex()
	local flexable = flexableInfo.flexables[entIndex]
	if flexable then
		local d = flexable.drivers:getDriver(driverId)
		if d then
			flexable.resetters[d.bone] = driver.boneInfo()
			d:setInfo(driverInfo)
		end
	end
end

---Add a driver to an entity. If an entity doesn't have any drivers, add the entity to the system
---@param entity Entity
---@param driverInfo DriverInfo
function system.addDriver(entity, driverInfo)
	local entIndex = entity:EntIndex()
	local flexable = flexableInfo.flexables[entIndex]
	local driverId
	if not flexable then
		addFlexable(entIndex, driver.driver(driverInfo))
		driverId = 1
		print("New flexable. Driver at ", driverId)
	else
		driverId = flexable.drivers:insert(driver.driver(driverInfo))
		print("Inserted driver at ", driverId)
	end

	return driverId
end

---Get a driver if it exists
---@param entity Entity
---@return Driver?
function system.getDriver(entity, driverId)
	local entIndex = entity:EntIndex()
	local flexable = flexableInfo.flexables[entIndex]
	return flexable and flexable.drivers:getDriver(driverId)
end

---Switch the order of `driverId` to the `newDriverId`
---@param entity Entity
---@return boolean
function system.switchDriver(entity, driverId, newDriverId)
	local entIndex = entity:EntIndex()
	local flexable = flexableInfo.flexables[entIndex]
	if flexable then
		flexable.drivers:switch(driverId, newDriverId)
		return true
	end

	return false
end

---Remove a driver from a specified `driverId` for an `entity`. If there are no more drivers, remove the `entity` from the system
---@param entity Entity
---@param driverId integer
function system.removeDriver(entity, driverId)
	local entIndex = entity:EntIndex()
	local flexable = flexableInfo.flexables[entIndex]
	if flexable then
		print("Removing driver at ", driverId)
		local d = flexable.drivers:getDriver(driverId)
		if d then
			flexable.resetters[d.bone] = driver.boneInfo()
		end
		flexable.drivers:remove(driverId)
	end

	if #flexable.drivers.drivers == 0 then
		print("Remove flexable")
		removeFlexable(entIndex)
	end
end

---Remove drivers from entity, but don't remove the entity from the system
---Mostly used for switching presets
---@param entity Entity
function system.clearDrivers(entity)
	local entIndex = entity:EntIndex()
	local flexable = flexableInfo.flexables[entIndex]
	if flexable then
		for _, d in ipairs(flexable.drivers.drivers) do
			flexable.resetters[d.bone] = driver.boneInfo()
		end
		flexable.drivers.drivers = {}
	end
end

---@param entIndex integer
---@return ClientFlexable
function system.getEntity(entIndex)
	return flexableInfo.flexables[entIndex]
end

---@param entIndex integer
---@param boneDict table<integer, BoneInfo>
---@param boneCount integer
local function replicate(entIndex, boneDict, boneCount)
	net.Start("flexdriver_replicate")
	net.WriteUInt(entIndex, 14)
	net.WriteUInt(boneCount, 8)
	for index, boneInfo in pairs(boneDict) do
		net.WriteUInt(index, 8)
		net.WriteVector(boneInfo.pos)
		net.WriteAngle(boneInfo.ang)
	end
	net.SendToServer()
end

---Check if the entity passes rules on the client
---Useful to ensure the client doesn't send what it can't see
---@param entity Entity
local function checkReplication(entity)
	-- TODO: Implement replication rules
	return true
end

do
	local checkReplicationConVar = GetConVar("flexdriver_checkreplication")
	local shouldCheckReplication = checkReplicationConVar and checkReplicationConVar:GetBool()
	cvars.AddChangeCallback("flexdriver_checkreplication", function(_, _, newValue)
		shouldCheckReplication = tobool(newValue) or shouldCheckReplication
	end)
	local updateIntervalConVar = GetConVar("flexdriver_updateinterval")
	local updateInterval = updateIntervalConVar and updateIntervalConVar:GetFloat()
	cvars.AddChangeCallback("flexdriver_updateinterval", function(_, _, newValue)
		updateInterval = tonumber(newValue) or updateInterval
	end)

	local lastThink = 0

	-- The client is responsible for parsing the expressions
	hook.Remove("Think", "flexdriver_system")
	hook.Add("Think", "flexdriver_system", function()
		checkReplicationConVar = checkReplicationConVar or GetConVar("flexdriver_checkreplication")
		updateIntervalConVar = updateIntervalConVar or GetConVar("flexdriver_updateinterval")
		if not shouldCheckReplication and checkReplicationConVar then
			shouldCheckReplication = checkReplicationConVar:GetBool()
		end
		if not updateInterval and updateIntervalConVar then
			updateInterval = updateIntervalConVar:GetFloat()
		end

		local now = CurTime()
		if (now - lastThink) < updateInterval / 1000 then
			return
		end
		lastThink = now

		local flexables = flexableInfo.flexables
		for entIndex, flexable in
			ipairs_sparse(flexables, "flexdriver_system", flexableInfo.count ~= flexableInfo.previousCount)
		do
			-- Cleanup invalid entities
			if not flexable or not IsValid(flexable.entity) then
				removeFlexable(entIndex)
				continue
			end

			if not shouldCheckReplication or (shouldCheckReplication and checkReplication(flexable.entity)) then
				local boneDict, boneCount = flexable.drivers:evaluate()
				replicate(entIndex, boneDict, boneCount)

				replicate(entIndex, flexable.resetters, table.Count(flexable.resetters))
				flexable.resetters = {}
			end
		end
		flexableInfo.previousCount = flexableInfo.count
	end)
end

FlexDriver.System = system
