---@module "flexdriver.shared.mathparser"
local mathparser = include("flexdriver/shared/mathparser.lua")

---@class BoneInfo
---@field pos Vector
---@field ang Angle
local BoneInfo = {}
BoneInfo.__index = BoneInfo

---@param pos Vector?
---@param ang Angle?
---@return BoneInfo
local function boneInfo(pos, ang)
	return setmetatable({
		pos = pos or vector_origin * 1,
		ang = ang or angle_zero * 1,
	}, BoneInfo)
end

---@param other BoneInfo|Vector|Angle
---@return BoneInfo
function BoneInfo:__add(other)
	if isvector(other) then
		return boneInfo(self.pos + other, self.ang)
	elseif isangle(other) then
		return boneInfo(self.pos, self.ang + other)
	elseif getmetatable(other) == BoneInfo then
		return boneInfo(self.pos + other.pos, self.ang + other.ang)
	end

	return self
end

---@param self BoneInfo
---@param other BoneInfo|Vector|Angle
---@return BoneInfo
function BoneInfo:__sub(other)
	return self:__add(-other)
end

---@param self BoneInfo
---@return BoneInfo
function BoneInfo:__unm()
	return boneInfo(-self.pos, -self.ang)
end

---@type {[string]: {[1]: string, [2]: integer}}
local axisIndexer = {
	["POS_X"] = { "pos", 1 },
	["POS_Y"] = { "pos", 2 },
	["POS_Z"] = { "pos", 3 },
	["SCALE_X"] = { "scale", 1 },
	["SCALE_Y"] = { "scale", 2 },
	["SCALE_Z"] = { "scale", 3 },
	["PITCH"] = { "ang", 1 },
	["YAW"] = { "ang", 2 },
	["ROLL"] = { "ang", 3 },
}

---@class Driver
---@field expression string A mathematical expression which, when parsed, will set a value for the `bone`'s `axis` for its `axisType`
---@field operation 'ADD'|'REPLACE' How the expression is applied, relative to other drivers on the same bone axis and axis type. 'ADD' sums the results of other drivers, while 'REPLACE' has precedence over other drivers,
---@field bone integer Bone index
---@field axisType 'POS_X'|'POS_Y'|'POS_Z'|'PITCH'|'YAW'|'ROLL'|'SCALE_X'|'SCALE_Y'|'SCALE_Z'
---@field type string An entity property (networked property, flex)
---@field typeId string The name of the entity property (flex name, entity property name)
local Driver = {}
Driver.__index = Driver

---@param driverInfo DriverInfo
local function driver(driverInfo)
	return setmetatable({
		expression = driverInfo.expression,
		operation = driverInfo.operation or "ADD",
		bone = driverInfo.bone or -1,
		axisType = driverInfo.axisType or "POS_X",
		type = driverInfo.type or "FLEX",
		typeId = driverInfo.typeId,
	}, Driver)
end

---@param driverInfo  DriverInfo
function Driver:setInfo(driverInfo)
	self.expression = driverInfo.expression or self.expression
	self.operation = driverInfo.operation or self.operation
	self.bone = driverInfo.bone or self.bone
	self.axisType = driverInfo.axisType or self.axisType
	self.type = driverInfo.type or self.type
	self.typeId = driverInfo.typeId or self.typeId
end

---@param parser Parser
---@param entity Entity
function Driver:setParserType(parser, entity)
	local result = 0
	if self.type == "FLEX" then
		local flexId = entity:GetFlexIDByName(self.typeId)
		if flexId then
			result = entity:GetFlexWeight(flexId)
		end
	elseif
		self.type == "PROP"
		and isfunction(entity["Get" .. self.typeId])
		and type(entity["Get" .. self.typeId](entity)) == "number"
	then
		result = entity["Get" .. self.typeId](entity)
	end

	parser:addVariable("x", result)
end

---Parse the expression and return the result
---@param parser Parser
---@return BoneInfo
function Driver:evaluate(parser)
	local result = boneInfo()
	local indexInfo = axisIndexer[self.axisType]

	if indexInfo then
		result[indexInfo[1]][indexInfo[2]] = parser:solve(self.expression)
	end

	return result
end

function Driver:serialize()
	return {
		expression = self.expression,
		operation = self.operation,
		bone = self.bone,
		axisType = self.axisType,
		type = self.type,
		typeId = self.typeId,
	}
end

---@class DriverArray
---@field drivers Driver[] An array of drivers
---@field entity Entity The entity that the drivers operate
local DriverArray = {}
DriverArray.__index = DriverArray

---@param drivers Driver[]
---@param entity Entity
---@return DriverArray
local function driverArray(drivers, entity)
	return setmetatable({
		drivers = drivers,
		entity = entity,
	}, DriverArray)
end

function DriverArray:getDriver(i)
	return self.drivers[i]
end

---@param d Driver
function DriverArray:insert(d)
	return table.insert(self.drivers, d)
end

---@param i integer
function DriverArray:remove(i)
	table.remove(self.drivers, i)
end

function DriverArray.__len(self)
	return #self.drivers
end

---Switch the driver order
---@param from integer
---@param to integer
function DriverArray:switch(from, to)
	local temp = self.drivers[from]
	self.drivers[from] = self.drivers[to]
	self.drivers[to] = temp
end

---@return table<integer, BoneInfo>, integer
function DriverArray:evaluate()
	---@type table<integer, BoneInfo>
	local result = {}

	local entity = self.entity
	local drivers = self.drivers

	---@type Parser
	local parser = mathparser:new()

	local count = 0

	-- Evaluate starting from the bottom
	for i = #drivers, 1, -1 do
		local d = drivers[i]

		if not result[d.bone] then
			count = count + 1
			result[d.bone] = boneInfo()
		end

		d:setParserType(parser, entity)
		if d.operation == "ADD" then
			result[d.bone] = result[d.bone] + d:evaluate(parser)
		elseif d.operation == "REPLACE" then
			result[d.bone] = d:evaluate(parser)
		end
	end

	return result, count
end

function DriverArray:serialize()
	local result = {}
	for _, d in ipairs(self.drivers) do
		table.insert(result, d:serialize())
	end

	return util.TableToJSON(result, true)
end

return {
	array = driverArray,
	driver = driver,
}
