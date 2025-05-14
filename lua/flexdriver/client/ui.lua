---@module "flexdriver.shared.helpers"
local helpers = include("flexdriver/shared/helpers.lua")

local getValidModelChildren = helpers.getValidModelChildren
local getModelName, getModelNameNice, getModelNodeIconPath =
	helpers.getModelName, helpers.getModelNameNice, helpers.getModelNodeIconPath
local vectorFromString = helpers.vectorFromString

local ui = {}

local BONE_PRESETS_DIR = "flexdriver/presets"

---Add hooks and model tree pointers
---@param parent TreePanel_Node
---@param entity Entity
---@param info EntityTree
---@param rootInfo EntityTree
---@return TreePanel_Node
local function addEntityNode(parent, entity, info, rootInfo)
	local node = parent:AddNode(getModelNameNice(entity))
	---@cast node TreePanel_Node

	node:SetExpanded(true, true)

	node.Icon:SetImage(getModelNodeIconPath(entity))
	node.info = info

	return node
end

---Construct the model tree
---@param parent Entity
---@return EntityTree
local function entityHierarchy(parent)
	local tree = {}
	if not IsValid(parent) then
		return tree
	end

	---@type Entity[]
	local children = getValidModelChildren(parent)

	for i, child in ipairs(children) do
		if child.GetModel and child:GetModel() ~= "models/error.mdl" then
			---@type EntityTree
			local node = {
				parent = parent:EntIndex(),
				entity = child:EntIndex(),
				children = entityHierarchy(child),
			}
			table.insert(tree, node)
		end
	end

	return tree
end

---Construct the DTree from the entity model tree
---@param tree EntityTree
---@param nodeParent TreePanel_Node
---@param root EntityTree
local function hierarchyPanel(tree, nodeParent, root)
	for _, child in ipairs(tree) do
		local childEntity = Entity(child.entity)
		if not IsValid(childEntity) or not childEntity.GetModel or not childEntity:GetModel() then
			continue
		end

		local node = addEntityNode(nodeParent, childEntity, child, root)

		if #child.children > 0 then
			hierarchyPanel(child.children, node, root)
		end
	end
end

---Construct the `entity`'s model tree
---@param treePanel TreePanel
---@param entity Entity
---@returns EntityTree
local function buildTree(treePanel, entity)
	if IsValid(treePanel.ancestor) then
		treePanel.ancestor:Remove()
	end

	---@type EntityTree
	local hierarchy = {
		entity = entity:EntIndex(),
		children = entityHierarchy(entity),
	}

	---@type TreePanel_Node
	---@diagnostic disable-next-line
	treePanel.ancestor = addEntityNode(treePanel, entity, hierarchy, hierarchy)
	treePanel.ancestor.Icon:SetImage(getModelNodeIconPath(entity))
	treePanel.ancestor.info = hierarchy
	hierarchyPanel(hierarchy.children, treePanel.ancestor, hierarchy)

	return hierarchy
end

---Helper for DForm
---@param cPanel ControlPanel|DForm
---@param name string
---@param type "ControlPanel"|"DForm"
---@return ControlPanel|DForm
local function makeCategory(cPanel, name, type)
	---@type DForm|ControlPanel
	local category = vgui.Create(type, cPanel)

	category:SetLabel(name)
	cPanel:AddItem(category)
	return category
end

local boneTypes = {
	"icon16/brick.png",
	"icon16/connect.png",
	"icon16/error.png",
}
---@param parentNode DTreeScroller|BoneTreeNode
---@param childName string
---@param boneType integer
---@return BoneTreeNode
local function addBoneNode(parentNode, childName, boneType)
	local child = parentNode:AddNode(childName)
	---@cast child BoneTreeNode
	child:SetIcon(boneTypes[boneType])
	child:SetExpanded(true, false)
	return child
end

---@param entity Entity
---@param boneIndex integer
---@return integer
local function getBoneType(entity, boneIndex)
	local boneType = 2
	local isPhysicalBone = entity:TranslatePhysBoneToBone(entity:TranslateBoneToPhysBone(boneIndex)) == boneIndex

	if entity:BoneHasFlag(boneIndex, 4) then
		boneType = 3
	elseif isPhysicalBone then
		boneType = 1
	end

	return boneType
end

---@param node DTreeScroller|BoneTreeNode
---@param entity Entity
---@returns nodeArray: BoneTreeNode[]
local function populateBoneTree(node, entity)
	---@type BoneTreeNode[], BoneTreeNode[]
	local parentSet, nodeArray = {}, {}
	for b = 0, entity:GetBoneCount() - 1 do
		if entity:GetBoneName(b) == "__INVALIDBONE__" then
			continue
		end

		local boneType = getBoneType(entity, b)

		local parent = entity:GetBoneParent(b)
		if parent > -1 and parentSet[parent] then
			parentSet[b] = addBoneNode(parentSet[parent], entity:GetBoneName(b), boneType)
			parentSet[b].bone = b
			table.insert(nodeArray, parentSet[b])
		else
			parentSet[b] = addBoneNode(node, entity:GetBoneName(b), boneType)
			parentSet[b].bone = b
			table.insert(nodeArray, parentSet[b])
		end
	end

	return nodeArray
end

---@param treeNodes BoneTreeNode[]
local function getBoneTreeDepth(treeNodes)
	local depth, maxDepth = 0, 0
	for _, n in ipairs(treeNodes) do
		local counter = 0
		local walk = n
		while walk:GetParentNode():GetName() == "DTree_Node" and counter < 100 do
			---@diagnostic disable-next-line: cast-local-type
			walk = walk:GetParentNode()
			counter = counter + 1
			depth = depth + 1
		end

		if depth > maxDepth then
			maxDepth = depth
		end
		depth = 0
	end

	return maxDepth
end

---@param boneTree DTreeScroller
---@param flexable Entity
local function refreshBoneTree(boneTree, flexable)
	boneTree:Clear()

	local nodeArray = populateBoneTree(boneTree, flexable)
	local depth = getBoneTreeDepth(nodeArray)
	local width = depth * 17
	boneTree:UpdateWidth(width + 64 + 32 + 128)
end

---@type DFrame?
local boneTreeModal

---@param cPanel DForm|ControlPanel
---@param panelProps PanelProps
---@param panelState PanelState
---@return PanelChildren
function ui.ConstructPanel(cPanel, panelProps, panelState)
	local flexable = panelProps.flexable

	cPanel:Help("#tool.flexdriver.general")

	local treeForm = makeCategory(cPanel, "Entity Hierarchy", "DForm")
	if IsValid(flexable) then
		treeForm:Help("#tool.flexdriver.tree")
	end
	treeForm:Help(IsValid(flexable) and "Entity hierarchy for " .. getModelName(flexable) or "No entity selected")
	local treePanel = vgui.Create("DTreeScroller", treeForm)
	---@cast treePanel TreePanel
	if IsValid(flexable) then
		panelState.tree = buildTree(treePanel, flexable)
	end
	treeForm:AddItem(treePanel)
	treePanel:Dock(TOP)
	treePanel:SetSize(treeForm:GetWide(), 125)

	local driverForm = makeCategory(cPanel, "Drivers", "DForm")

	local presets = vgui.Create("DPresetSaver", cPanel)
	presets:SetEntity(flexable)
	presets:SetDirectory(BONE_PRESETS_DIR)
	presets:RefreshDirectory()
	driverForm:AddItem(presets)

	local addDriver = driverForm:Button("#tool.flexdriver.drivers.add", "")

	local replicationSettings = makeCategory(cPanel, "Replication Settings", "DForm")
	replicationSettings:Help("#tool.flexdriver.replication.warning")
	local updateInterval =
		replicationSettings:NumSlider("#tool.flexdriver.replication.interval", "flexdriver_updateinterval", 0, 1000)
	updateInterval:SetTooltip("#tool.flexdriver.replication.interval.tooltip")

	if boneTreeModal then
		boneTreeModal:Remove()
	end
	boneTreeModal = vgui.Create("DFrame")
	boneTreeModal:SetTitle("#tool.flexdriver.bonetree")
	boneTreeModal:SizeTo(cPanel:GetWide(), cPanel:GetTall(), 0)

	-- Shows up in a modal frame
	local boneTree = vgui.Create("DTreeScroller", boneTreeModal)
	boneTreeModal:Add(boneTree)
	boneTree:Dock(FILL)

	local setBone = vgui.Create("DButton", boneTreeModal)
	setBone:Dock(BOTTOM)
	setBone:SetEnabled(false)
	setBone:SetText("#tool.flexdriver.bonetree.setbone")

	boneTreeModal:SetVisible(false)

	if IsValid(flexable) then
		refreshBoneTree(boneTree, flexable)
	end

	return {
		treePanel = treePanel,
		boneTree = boneTree,
		setBone = setBone,
		addDriver = addDriver,
		updateInterval = updateInterval,
		driverForm = driverForm,
		presets = presets,
	}
end

---@param panelChildren PanelChildren
---@param panelProps PanelProps
---@param panelState PanelState
function ui.HookPanel(panelChildren, panelProps, panelState)
	local treePanel = panelChildren.treePanel
	local boneTree = panelChildren.boneTree
	local presets = panelChildren.presets
	local setBone = panelChildren.setBone
	local addDriver = panelChildren.addDriver
	local driverForm = panelChildren.driverForm

	local flexable = panelState.flexable
	local player = LocalPlayer()

	---@param startingPosition integer driverId >= 1
	local function resetIds(startingPosition)
		---@diagnostic disable-next-line: undefined-field
		local items = driverForm.Items
		for i = 2 + startingPosition, #items do
			local driverPanel = items[i]
			if driverPanel.driverId then
				driverPanel.driverId = driverPanel.driverId - 1
			end
		end
	end

	---@param driverPanel flexdriver_driver
	local function hookDriver(driverPanel)
		function driverPanel:SetBoneRequest()
			if boneTreeModal then
				boneTreeModal:SetVisible(true)
			end
			panelState.selectedDriver = self
		end

		function driverPanel:SetBoneResponse()
			local bone = panelState.selectedBone
			local _, operation = self.operation:GetSelected()
			local _, axisType = self.axis:GetSelected()
			local _, type = self.type:GetSelected()
			if FlexDriver.System.getDriver(flexable, self.driverId) then
				FlexDriver.System.setDriver(flexable, self.driverId, {
					expression = self.expression:GetText(),
					operation = operation,
					bone = bone,
					axisType = axisType,
					type = type,
					typeId = self.typeId:GetText(),
				})
			else
				self.driverId = FlexDriver.System.addDriver(flexable, {
					expression = self.expression:GetText(),
					operation = operation,
					bone = bone,
					axisType = axisType,
					type = type,
					typeId = self.typeId:GetText(),
				})
			end
			self:SetAutocomplete(flexable)
			self.bone.data = bone
			self.bone:SetText(flexable:GetBoneName(bone) or "#tool.flexdriver.drivers.bone")
		end

		function driverPanel:OnDriverChange()
			local bone = panelState.selectedBone
			local _, operation = self.operation:GetSelected()
			local _, axisType = self.axis:GetSelected()
			local _, type = self.type:GetSelected()
			FlexDriver.System.setDriver(flexable, self.driverId, {
				expression = self.expression:GetText(),
				operation = operation,
				bone = bone,
				axisType = axisType,
				type = type,
				typeId = self.typeId:GetText(),
			})
			self:SetAutocomplete(flexable)
			self.bone.data = bone
		end

		function driverPanel:OnDelete()
			FlexDriver.System.removeDriver(flexable, self.driverId)
			resetIds(self.driverId + 1)
			self:Remove()
		end
	end

	---@param entity Entity
	local function refreshDrivers(entity)
		---@diagnostic disable-next-line: undefined-field
		local items = driverForm.Items
		for i = 3, #items do
			local panel = driverForm[i]
			if IsValid(panel) then
				panel:Remove()
			end
		end
		for i = #items, 3, -1 do
			items[i] = nil
		end

		local flexableInfo = FlexDriver.System.getEntity(entity:EntIndex())
		if flexableInfo then
			for _, driver in ipairs(flexableInfo.drivers.drivers) do
				local panel = vgui.Create("flexdriver_driver", driverForm)
				panel:SetDriver({
					expression = driver.expression,
					operation = driver.operation,
					bone = driver.bone,
					axisType = driver.axisType,
					type = driver.type,
					typeId = driver.typeId,
				})
				panel.bone:SetText(flexable:GetBoneName(driver.bone) or "#tool.flexdriver.drivers.bone")

				driverForm:AddItem(panel)
				hookDriver(panel)
			end
		end
	end

	function addDriver:DoClick()
		local panel = vgui.Create("flexdriver_driver", driverForm)
		driverForm:AddItem(panel)
		hookDriver(panel)
	end

	---@param node TreePanel_Node
	function treePanel:OnNodeSelected(node)
		local selectedEntity = Entity(node.info.entity)
		if flexable == selectedEntity then
			return
		end

		flexable = selectedEntity

		presets:SetEntity(flexable)
		presets:SetText(helpers.getModelNameNice(flexable))
		refreshDrivers(flexable)
		refreshBoneTree(boneTree, flexable)
	end

	function presets:OnSaveSuccess()
		notification.AddLegacy("Driver settings saved", NOTIFY_GENERIC, 5)
	end

	function presets:OnSaveFailure(msg)
		notification.AddLegacy("Failed to save driver settings: " .. msg, NOTIFY_ERROR, 5)
	end

	function presets:OnSavePreset()
		local data = {}

		return data
	end

	---@param preset any
	function presets:OnLoadPreset(preset)
		notification.AddLegacy("Drivers loaded", NOTIFY_GENERIC, 5)
	end

	---@param node BoneTreeNode
	function boneTree:OnNodeSelected(node)
		setBone:SetEnabled(true)
		panelState.selectedBone = node.bone
	end

	function setBone:DoClick()
		if boneTreeModal then
			boneTreeModal:SetVisible(false)
		end
		if panelState.selectedDriver then
			panelState.selectedDriver:SetBoneResponse()
		end
		self:SetEnabled(false)
	end

	if IsValid(flexable) then
		refreshDrivers(flexable)
		addDriver:SetEnabled(true)
		presets:SetEnabled(true)
	else
		addDriver:SetEnabled(false)
		presets:SetEnabled(false)
	end
end

return ui
