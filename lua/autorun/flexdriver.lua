---@diagnostic disable-next-line: undefined-global
FlexDriver = FlexDriver or {}

if SERVER then
	print("Initializing Flex Driver on the server")

	AddCSLuaFile("flexdriver/shared/helpers.lua")
	AddCSLuaFile("flexdriver/shared/mathparser.lua")
	AddCSLuaFile("flexdriver/shared/setarray.lua")
	AddCSLuaFile("flexdriver/client/system.lua")
	AddCSLuaFile("flexdriver/client/ui.lua")

	include("flexdriver/server/net.lua")
	include("flexdriver/server/system.lua")
else
	print("Initializing Flex Driver on the client")

	include("flexdriver/client/system.lua")
end
