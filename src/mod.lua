KuxCoreLib = require("__Kux-CoreLib__/lib/init") --[[@as KuxCoreLib]]

---@class Mod : KuxCoreLib.ModInfo Mod Kux-OrbitalIonCannon
local mod = KuxCoreLib.ModInfo.new{separator="-"}

--mod.name = "Kux-OrbitalIonCannon"
--mod.path="__"..mod.name.."__/"
--mod.prefix=mod.name.."-"

---technology names
mod.tech = {
	cannon = "orbital-ion-cannon",
	area_fire = "orbital-ion-cannon-area-fire",
	auto_targeting = "auto-targeting",
	cannon_mk2 = "orbital-ion-cannon-mk2",
	cannon_mk2_upgrade = "orbital-ion-cannon-mk2-upgrade"
}

---technology recipe names
mod.recipe = {
	cannon = "orbital-ion-cannon",
	targeter = "ion-cannon-targeter",
	cannon_mk2 = "orbital-ion-cannon-mk2"
}

mod:protect()
_G.mod = mod
return mod