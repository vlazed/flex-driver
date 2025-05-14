TOOL.Category = "Poser"
TOOL.Name = "#tool.flexdriver.name"
TOOL.Command = nil
TOOL.ConfigName = ""

TOOL.ClientConVar["updateinterval"] = "10"

local lastFlexable = NULL
local lastValidFlexable = false
function TOOL:Think()
	local currentFlexable = self:GetFlexable()
	local validFlexable = IsValid(currentFlexable)

	if currentFlexable == lastFlexable and validFlexable == lastValidFlexable then
		return
	end

	if CLIENT then
		self:RebuildControlPanel(currentFlexable)
	end
	lastFlexable = currentFlexable
	lastValidFlexable = validFlexable
end

---@param newFlexable Entity
function TOOL:SetFlexable(newFlexable)
	self:GetWeapon():SetNW2Entity("flexdriver_entity", IsValid(newFlexable) and newFlexable or NULL)
end

---@return Entity flexable
function TOOL:GetFlexable()
	return self:GetWeapon():GetNW2Entity("flexdriver_entity")
end

---Select an entity to add flex drivers
---@param tr table|TraceResult
---@return boolean
function TOOL:RightClick(tr)
	if CLIENT then
		return true
	end

	if IsValid(tr.Entity) and tr.Entity:GetClass() == "prop_effect" then
		---@diagnostic disable-next-line: undefined-field
		tr.Entity = tr.Entity.AttachedEntity
	end

	self:SetFlexable(tr.Entity)

	return true
end

if SERVER then
	return
end

TOOL:BuildConVarList()

---@module "flexdriver.client.ui"
local ui = include("flexdriver/client/ui.lua")
---@module "flexdriver.shared.helpers"
local helpers = include("flexdriver/shared/helpers.lua")

---@type PanelState
local panelState = {
	flexable = NULL,
	selectedBone = -1,
}

---@param cPanel ControlPanel|DForm
---@param flexable Entity
function TOOL.BuildCPanel(cPanel, flexable)
	local panelProps = {
		flexable = flexable,
	}
	panelState.flexable = flexable
	local panelChildren = ui.ConstructPanel(cPanel, panelProps, panelState)
	ui.HookPanel(panelChildren, panelProps, panelState)
end

TOOL.Information = {
	{ name = "info" },
	{ name = "right" },
}
