data:extend({
	{
		type = "item",
		name = "orbital-ion-cannon",
		icon = ModPath.."graphics/icon64.png",
		icon_size = 64,
		subgroup = "defensive-structure",
		order = "e[orbital-ion-cannon]",
		stack_size = 1
	},
})

data:extend({
	{
		type = "recipe",
		name = "orbital-ion-cannon",
		energy_required = 60,
		ingredients = {
			{ type = "item", name = "low-density-structure", amount = 100 },
			{ type = "item", name = "solar-panel", amount = 100 },
			{ type = "item", name = "accumulator", amount = 200 },
			{ type = "item", name = "radar", amount = 10 },
			{ type = "item", name = "processing-unit", amount = 200 },
			{ type = "item", name = "electric-engine-unit", amount = 25 },
			{ type = "item", name = "laser-turret", amount = 50 },
			{ type = "item", name = "rocket-fuel", amount = 50 }
		},
		results = {
			{ type = "item", name = "orbital-ion-cannon", amount = 1 }
		}

	},
})

--TODO update to not use array indices
if data.raw["item"]["advanced-processing-unit"] and settings.startup["ion-cannon-bob-updates"].value then
	data.raw["recipe"]["orbital-ion-cannon"].ingredients[5] = {type = "item", name = "advanced-processing-unit", amount=200}
end

if data.raw["item"]["bob-laser-turret-5"] and settings.startup["ion-cannon-bob-updates"].value then
	data.raw["recipe"]["orbital-ion-cannon"].ingredients[7] = {type = "item", name = "bob-laser-turret-5", amount=50}
end

if data.raw["item"]["fast-accumulator-3"] and data.raw["item"]["solar-panel-large-3"] and settings.startup["ion-cannon-bob-updates"].value then
	data.raw["recipe"]["orbital-ion-cannon"].ingredients[2] = {type = "item", name = "solar-panel-large-3", amount=100}
	data.raw["recipe"]["orbital-ion-cannon"].ingredients[3] = {type = "item", name = "fast-accumulator-3", amount=200}
end
