---@module "ragdollpuppeteer.lib.fzy"
local fzy = include("flexdriver/shared/fzy.lua")

---@class flexdriver_driver: DPanel
local PANEL = {}

local axisIds = {
	["POS_X"] = 1,
	["POS_Y"] = 2,
	["POS_Z"] = 3,
	["PITCH"] = 4,
	["YAW"] = 5,
	["ROLL"] = 6,
}

local typeIds = {
	["FLEX"] = 1,
	["PROP"] = 2,
}

local operationIds = {
	["ADD"] = 1,
	["REPLACE"] = 2,
}

function PANEL:Init()
	self.clickArea = vgui.Create("DLabel", self)
	self.clickArea:SetMouseInputEnabled(true)
	function self.clickArea.DoRightClick()
		self:OnRightClick()
	end

	self.deleteButton = vgui.Create("DImageButton", self)
	self.deleteButton:SetImage("icon16/delete.png")
	function self.deleteButton.DoClick()
		self:OnDelete()
	end

	self.bone = vgui.Create("DButton", self)
	self.bone:SetText("#tool.flexdriver.drivers.bone")
	function self.bone.DoClick()
		self:SetBoneRequest()
	end
	self.bone.data = -1

	self.expression = vgui.Create("DTextEntry", self)
	self.expression:SetUpdateOnType(false)
	self.expression:SetText("x")
	function self.expression.OnEnter()
		self:OnDriverChange()
	end

	self.axis = vgui.Create("DComboBox", self)
	self.axis:AddChoice("Position X", "POS_X", true)
	self.axis:AddChoice("Position Y", "POS_Y")
	self.axis:AddChoice("Position Z", "POS_Z")
	self.axis:AddChoice("Pitch", "PITCH")
	self.axis:AddChoice("Yaw", "YAW")
	self.axis:AddChoice("Roll", "ROLL")
	function self.axis.OnSelect()
		self:OnDriverChange()
	end

	self.type = vgui.Create("DComboBox", self)
	self.type:AddChoice("Flex", "FLEX", true)
	self.type:AddChoice("Property", "PROP")
	function self.type.OnSelect()
		self:OnDriverChange()
	end

	self.typeId = vgui.Create("DTextEntry", self)
	self.typeId:SetPlaceholderText("name")
	function self.typeId.OnEnter()
		self:OnDriverChange()
	end

	self.operation = vgui.Create("DComboBox", self)
	self.operation:AddChoice("Add", "ADD", true)
	self.operation:AddChoice("Replace", "REPLACE")
	function self.operation.OnSelect()
		self:OnDriverChange()
	end

	self.upButton = vgui.Create("DImageButton", self)
	function self.upButton.DoClick()
		self:OnOrderChange(1)
	end

	self.upButton:SetImage("icon16/bullet_arrow_up.png")

	self.downButton = vgui.Create("DImageButton", self)
	self.downButton:SetImage("icon16/bullet_arrow_down.png")
	function self.downButton.DoClick()
		self:OnOrderChange(-1)
	end

	self.columns = 3.75
	self.driverId = 0

	self:SetTall(48)
end

function PANEL:OnRightClick()
	print("Right clicked")
end

---@param bone integer?
---@return table
function PANEL:GetDriverInfo(bone)
	local _, operation = self.operation:GetSelected()
	local _, axisType = self.axis:GetSelected()
	local _, type = self.type:GetSelected()
	return {
		expression = self.expression:GetText(),
		operation = operation,
		bone = bone or self.bone.data,
		axisType = axisType,
		type = type,
		typeId = self.typeId:GetText(),
	}
end

---@param driverInfo DriverInfo | Driver
function PANEL:SetDriver(driverInfo)
	self.axis:ChooseOptionID(axisIds[driverInfo.axisType] or 1)
	self.operation:ChooseOptionID(operationIds[driverInfo.type] or 1)
	self.type:ChooseOptionID(typeIds[driverInfo.operation] or 1)
	self.expression:SetText(driverInfo.expression)
	self.typeId:SetText(driverInfo.typeId)
	self.bone.data = driverInfo.bone
end

function PANEL:OnDelete() end

function PANEL:OnOrderChange(direction) end

function PANEL:OnDriverChange() end

function PANEL:SetBoneRequest() end

---@param bone integer
function PANEL:SetBoneResponse(bone) end

---@param entity Entity
function PANEL:SetAutocomplete(entity)
	function self.typeId.GetAutoComplete(_, text)
		local suggestions = {}

		local _, type = self.type:GetSelected()
		local choices = {}
		if type == "FLEX" then
			for i = 0, entity:GetFlexNum() - 1 do
				table.insert(choices, entity:GetFlexName(i))
			end
		elseif type == "PROP" then
			for key, _ in pairs(entity:GetNetworkVars()) do
				table.insert(choices, key)
			end
		end

		for _, result in ipairs(fzy.filter(text, choices, false)) do
			table.insert(suggestions, choices[result[1]])
		end

		return suggestions
	end
end

function PANEL:PerformLayout(w, h)
	local columns = self.columns

	self.clickArea:SetSize(w, h)

	self.deleteButton:SetSize(16, 16)
	self.deleteButton:SetPos(w - self.deleteButton:GetWide(), 0)

	self.bone:SetSize(w / columns, 16)
	self.bone:SetPos(w * 0.05, h / 2 - self.bone:GetTall() / 2 - 10)

	self.axis:SetSize(w / columns, 16)
	self.axis:SetPos(self.bone:GetX(), self.bone:GetY() + 20)

	self.type:SetSize(w / columns, 16)
	self.typeId:SetSize(w / columns, 16)
	self.type:SetPos(self.axis:GetX() + self.type:GetWide() + 10, self.bone:GetY())
	self.typeId:SetPos(self.axis:GetX() + self.typeId:GetWide() + 10, self.bone:GetY() + 20)

	self.operation:SetSize(w / columns, 16)
	self.operation:SetPos(self.type:GetX() + self.operation:GetWide() + 10, self.type:GetY())

	self.expression:SetSize(w / columns, 16)
	self.expression:SetPos(self.type:GetX() + self.operation:GetWide() + 10, self.typeId:GetY())

	self.upButton:SetSize(16, 16)
	self.upButton:SetPos(w - self.upButton:GetWide(), h / 2 - 10)
	self.downButton:SetSize(16, 16)
	self.downButton:SetPos(w - self.upButton:GetWide(), h / 2 + 10)
end

vgui.Register("flexdriver_driver", PANEL, "DPanel")
