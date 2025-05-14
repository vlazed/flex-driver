---@meta

---@generic T, U
---@alias Set<T, U> {[T]: U}

---@alias Bone integer
---@alias BoneArray Bone[]
---@alias BoneSet Set<Bone, integer>

---@class ClientFlexable
---@field entity Entity
---@field drivers DriverArray

---@class ServerFlexable
---@field entity Entity

---@class FlexableInfo
---@field previousCount integer

---@class ServerFlexableInfo: FlexableInfo
---@field flexables SetArray

---@class ClientFlexableInfo: FlexableInfo
---@field flexables ClientFlexable[]
---@field count integer

---@alias AxisType 'POS_X'|'POS_Y'|'POS_Z'|'PITCH'|'YAW'|'ROLL'|'SCALE_X'|'SCALE_Y'|'SCALE_Z'

---@class DriverInfo
---@field expression string
---@field operation 'ADD'|'REPLACE'
---@field bone integer
---@field axisType AxisType
---@field type string
---@field typeId string

---@class PanelState
---@field flexable Entity
---@field selectedBone integer
---@field selectedDriver flexdriver_driver?
---@class PanelProps
---@field flexable Entity

---@class PanelChildren
---@field treePanel DTreeScroller
---@field boneTree DTreeScroller
---@field setBone DButton
---@field addDriver DButton
---@field driverForm DForm
---@field updateInterval DNumSlider
---@field presets flexdriver_presetsaver

---Wrapper for `DTree_Node`
---@class TreePanel_Node: DTree_Node
---@field Icon DImage
---@field info EntityTree
---@field GetChildNodes fun(self: TreePanel_Node): TreePanel_Node[]

---Wrapper for `DTree`
---@class TreePanel: DTreeScroller
---@field ancestor TreePanel_Node
---@field GetSelectedItem fun(self: TreePanel): TreePanel_Node

---Main structure representing an entity's model tree
---@class EntityTree
---@field parent integer?
---@field entity integer
---@field children EntityTree[]

---@class BoneTreeNode: DTree_Node
---@field GetChildNodes fun(self: BoneTreeNode): BoneTreeNode[]
---@field bone Bone

---@class Parser
---@field solve fun(self: Parser, expression: string): result: number
---@field addVariable fun(self: Parser, variableName: string, variableValue: number)
