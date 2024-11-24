KuxCoreLib = require("__Kux-CoreLib__/lib/init") --[[@as KuxCoreLib]]

---@class Mod : KuxCoreLib.ModInfo Mod Kux-OrbitalIonCannon
local mod = KuxCoreLib.ModInfo.new{separator="-"}

--mod.name = "Kux-OrbitalIonCannon"
--mod.path="__"..mod.name.."__/"
--mod.prefix=mod.name.."-"

mod.tech = {
	cannon = "orbital-ion-cannon",
	auto_targeting = "auto-targeting"
}
mod.recipe = {
	cannon = "orbital-ion-cannon",
	targeter = "ion-cannon-targeter"
}

mod:protect()
_G.mod = mod
return mod