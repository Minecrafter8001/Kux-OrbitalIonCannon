require("mod")
if script.active_mods["gvv"] then require("__gvv__.gvv")() end
local Version = KuxCoreLib.Version.asGlobal()
local Events = KuxCoreLib.Events
-- require("__Kux-CoreLib__/stdlib/core")
local Area = require("__Kux-CoreLib__/stdlib/area/area") -- preload required by Position
local Chunk = require("__Kux-CoreLib__/stdlib/area/chunk")
local Position = require("__Kux-CoreLib__/stdlib/area/position")
require "modules/autotargeter"
require "modules/gui"
require "modules/Permissions"
require "modules/ion-cannon-table"
---------------------------------------------------------------------------------------------------

local fLog = function (functionName)
	print("control."..functionName)
end

local this = {}

_G.when_ion_cannon_targeted = nil

remote.add_interface("orbital_ion_cannon",
	{
		on_ion_cannon_targeted = function() return getIonCannonTargetedEventID() end,
		on_ion_cannon_fired = function() return getIonCannonFiredEventID() end,
		target_ion_cannon = function(force, position, surface, player) return targetIonCannon(force, position, surface, player) end -- Player is optional
	}
)

function generateEvents()
	getIonCannonTargetedEventID()
	getIonCannonFiredEventID()
end

function getIonCannonTargetedEventID()
	if not _G.when_ion_cannon_targeted then
		_G.when_ion_cannon_targeted = script.generate_event_name()
	end
	return _G.when_ion_cannon_targeted
end

function getIonCannonFiredEventID()
	if not _G.when_ion_cannon_fired then
		_G.when_ion_cannon_fired = script.generate_event_name()
	end
	return when_ion_cannon_fired
end

this.initialize = function()
	fLog("initialize")
	-- on_init, on_configuration_changed, on_force_created
	generateEvents()
	if not storage.forces_ion_cannon_table then
		storage.forces_ion_cannon_table = {}
		storage.forces_ion_cannon_table["player"] = {}
	else
		--print("OrbitalIonCannon:OnInit")
		-- MIGRATION: add 3rd columnr "surface"
		for fn,f in pairs(storage.forces_ion_cannon_table) do
			if fn == "Queue" then goto next_force end
			--print("Update cannon force ''"..fn.."'' "..serpent.line(f))
			for i,c in ipairs(f) do
				if #c==2 then
					--"Update cannon #"..tostring(i).." surface to 'nauvis'")
					table.insert(c, "nauvis")
				end
			end
			::next_force::
		end
	end

	storage.goToFull = storage.goToFull or {}
	storage.markers = storage.markers or {}
	--global.holding_targeter = global.holding_targeter or {} --MAV This doesn't do anything that makes sense, getting rid of it. If necessary can be replaced with isHolding()
	storage.klaxonTick = storage.klaxonTick or 0
	storage.auto_tick = storage.auto_tick or 0
	storage.readyTick = {}
--	if remote.interfaces["silo_script"] then
--		local tracked_items = remote.call("silo_script", "get_tracked_items") --COMPATIBILITY 1.1 get_tracked_items removed
--		if not tracked_items["orbital-ion-cannon"] then
--			remote.call("silo_script", "add_tracked_item", "orbital-ion-cannon") --COMPATIBILITY 1.1 add_tracked_item removed
--		end
--	end
	if not storage.permissions then Permissions.initialize() end
	for _, player in pairs(game.players) do
		storage.readyTick[player.index] = 0
		storage.forces_ion_cannon_table[player.force.name] = GetCannonTableFromForce(player.force) or {}
		if storage.goToFull[player.index] == nil then
			storage.goToFull[player.index] = true
		end
		if player.gui.top["ion-cannon-button"] then
			player.gui.top["ion-cannon-button"].destroy()
		end
		if player.gui.top["ion-cannon-stats"] then
			player.gui.top["ion-cannon-stats"].destroy()
		end
	end
	for i, force in pairs(game.forces) do
		force.reset_recipes()
		if GetCannonTableFromForce(force) and #GetCannonTableFromForce(force) > 0 then
			storage.IonCannonLaunched = true
			Events.on_nth_tick(60, process_60_ticks)
		end
	end
	storage.forces_ion_cannon_table["Queue"] = storage.forces_ion_cannon_table["Queue"] or {}
end

this.onLoad = function()
	fLog("onLoad")
	generateEvents()
	if storage.IonCannonLaunched then
		Events.on_nth_tick(60, process_60_ticks)
	end
end

Events.on_event(defines.events.on_force_created, function(event)
	if not storage.forces_ion_cannon_table then
		this.initialize()
	end
	NewCannonTableForForce(event.force)
end)

Events.on_event(defines.events.on_forces_merging, function(event)
	fLog("on_forces_merging")
	storage.forces_ion_cannon_table[event.source.name] = nil
	-- for i, player in pairs(game.players) do
		-- init_GUI(player)
	-- end
end)

--why we should open the GUI always? KUX MODIFICATION
--[[Events.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
	if event.player_index then
		local player = game.players[event.player_index]
		if global.IonCannonLaunched or player.cheat_mode or player.admin then
			open_GUI(player)
		end
	end
end)]]

Events.on_event("ion-cannon-hotkey", function(event)
	local player = game.players[event.player_index]
	if storage.IonCannonLaunched or player.admin then
		open_GUI(player)
	end
end)

Events.on_event(defines.events.on_player_created, function(event)
	fLog("on_player_created")
	init_GUI(game.players[event.player_index])
	storage.readyTick[event.player_index] = 0
end)

Events.on_event(defines.events.on_player_cursor_stack_changed, function(event)
	local player = game.players[event.player_index]
	if isHolding({name = "ion-cannon-targeter", count = 1}, player) then
		if player.character and not Permissions.hasPermission(player.index) then
			player.print({"ion-permission-denied"})
			playSoundForPlayer("unable-to-comply", player)
			if Version.baseVersionGreaterOrEqual1d1() then
				player.clear_cursor() --COMPATIBILITY 1.1
			else
				player["clean_cursor"]() --Factorio < 1.1
			end
			--global.holding_targeter[player.index] = false
		elseif ((#GetCannonTableFromForce(player.force) > 0 and not isAllIonCannonOnCooldown(player))) --and not global.holding_targeter[player.index]
		then
			playSoundForPlayer("select-target", player)
		end
	--else
		--holding_targeter[player.index] = false
	end
end)

function process_60_ticks(NthTickEvent)
	local current_tick = NthTickEvent.tick
	for i = #storage.markers, 1, -1 do -- Loop over table backwards because some entries get removed within the loop
		local marker = storage.markers[i]
		if marker[2] <= current_tick then
			if marker[1] and marker[1].valid then
				marker[1].destroy()
			end
			table.remove(storage.markers, i)
		end
	end
	ReduceIonCannonCooldowns()
	for i, force in pairs(game.forces) do
		if GetCannonTableFromForce(force) and isIonCannonReady(force) then
			for i, player in pairs(force.connected_players) do
				if storage.readyTick[player.index] < current_tick then
					storage.readyTick[player.index] = current_tick + settings.get_player_settings(player)["ion-cannon-ready-ticks"].value
					playSoundForPlayer("ion-cannon-ready", player)
				end
			end
		end
	end
	for i, player in pairs(game.connected_players) do
		update_GUI(player)
	end
end

--Reduce cannon cooldowns. Time parameter is optional, defaults to 1
function ReduceIonCannonCooldowns(time)
	time = time or 1;
	for _, force in pairs(game.forces) do
		if GetCannonTableFromForce(force) then
			for k, cooldown in pairs(GetCannonTableFromForce(force)) do
				if cooldown[1] > 0 then
					GetCannonTableFromForce(force)[k][1] = GetCannonTableFromForce(force)[k][1] - time
					if cooldown[1] < 0 then cooldown[1] = 0 end --Have to do this because the clowns that wrote this code check for if it equals 0 instead of if it's less than 0
				end
			end
		end
	end
end

function isAllIonCannonOnCooldown(player)
	for i, cooldown in pairs(GetCannonTableFromForce(player.force)) do
		if cooldown[2] == 1 then
			return false
		end
	end
	return true
end

function isIonCannonReady(force)
	local found = false
	for i, cooldown in pairs(GetCannonTableFromForce(force)) do
		if cooldown[1] == 0 and cooldown[2] == 0 then
			cooldown[2] = 1
			found = true
		end
	end
	return found
end

function countTotalIonCannons(force)
	return #GetCannonTableFromForce(force)
end

--Given a surface, counts the number of orbiting ion cannons. If the surface is an orbit, it counts the number of cannons attached to the associated planet instead
function countOrbitingIonCannons(force, surface)
	local surfaceName = surface.name
	local suffix=" Orbit"
	if surfaceName == "Nauvis Orbit" then
		surfaceName = "nauvis"
	elseif #surfaceName > #suffix and string.sub(surfaceName, -#suffix) == suffix then
		local sn = string.sub(surfaceName, 1, #surfaceName-#suffix)
		--if game.surfaces[surfaceName] then surfaceName = sn end
		surfaceName = sn
	end
	local total = 0
	for i = 1, #GetCannonTableFromForce(force) do
		if surfaceName == GetCannonTableFromForce(force)[i][3] then
			total = total + 1
		end
	end
	return total
end

--TODO add debounce to prevent overlapping sounds
function playSoundForPlayer(sound, player)
	if settings.get_player_settings(player)["ion-cannon-play-voices"].value then
		local voice = settings.get_player_settings(player)["ion-cannon-voice-style"].value
		player.play_sound({path = sound .. "-" .. voice, volume_modifier = settings.get_player_settings(player)["ion-cannon-voice-volume"].value / 100})
	end
end

--Returns true if the payer is holding the specified stack or a ghost of it
function isHolding(stack, player)
	local holding = player.cursor_stack
	if holding and holding.valid_for_read and holding.name == stack.name and holding.count >= stack.count then
		return true
	--"crafting" an item in SE remote view doesn't craft the item but instead puts a ghost of it into the cursor
	--Checking for cheat mode is a simple alternative to calling an SE remote function to check if the remote view is active
	elseif --[[player.cheat_mode and]] player.cursor_ghost and player.cursor_ghost.name == stack.name then
		return true
	end
	return false
end

--Adds an ion cannon. Ensures Ion cannons aren't added in orbit.
--Returns the name of the surface the cannon was added to.
function addIonCannon(force, surface)
	local surfaceName = surface.name
	local suffix=" Orbit"
	if surfaceName == "Nauvis Orbit" then
		surfaceName = "nauvis"
	elseif #surfaceName > #suffix and string.sub(surfaceName, -#suffix) == suffix then
		local sn = string.sub(surfaceName, 1, #surfaceName-#suffix)
		--if game.surfaces[surfaceName] then surfaceName = sn end
		surfaceName = sn
	end
	table.insert(GetCannonTableFromForce(force), {settings.global["ion-cannon-cooldown-seconds"].value, 0, surfaceName})
	storage.IonCannonLaunched = true
	return surfaceName
end

--Removes an ion cannon.
--Returns the name of the surface the cannon was removed from.
-- function removeIonCannon(force, surface)
-- 	local surfaceName = surface.name
-- 	if GetCannonTableFromForce(force).size()
-- end


---@param force LuaForce
---@param position MapPosition
---@param surface LuaSurface
---@param player LuaPlayer
---@return boolean
function targetIonCannon(force, position, surface, player)
	local cannonNum = 0
	local targeterName = "Auto"

	for i, cooldown in pairs(GetCannonTableFromForce(force)) do
		if cooldown[2] == 1 and cooldown[3] == surface.name then
			cannonNum = i
			break
		end
	end

	if player then
		targeterName = player.name
		--TODO: Add alternate cheat cannon firing, and/or add a cooldown reset button to the cheat menu
		--[[if player.cheat_mode == true then
			cannonNum = "Cheat"
			Events.on_nth_tick(60, process_60_ticks)
		end]]
	end
	if cannonNum == 0 then
		if player then
			player.print({"unable-to-fire"})
			playSoundForPlayer("unable-to-comply", player)
		end
		return false
	else
		local current_tick = game.tick
		local TargetPosition = position
		TargetPosition.y = TargetPosition.y + 1
		local IonTarget = surface.create_entity({name = "ion-cannon-target", position = TargetPosition, force = game.forces.neutral})
		local marker = force.add_chart_tag(surface, {icon = {type = "item", name = "ion-cannon-targeter"}, text = "Ion cannon #" .. cannonNum .. " target location (" .. targeterName .. ")", position = TargetPosition})
		table.insert(storage.markers, {marker, current_tick + settings.global["ion-cannon-chart-tag-duration"].value})
		local CrosshairsPosition = position
		CrosshairsPosition.y = CrosshairsPosition.y - 20
		local projectile = force.technologies[mod.tech.cannon_mk2].researched and "crosshairs-mk2" or "crosshairs"
		surface.create_entity({name = projectile, target = IonTarget, force = force, position = CrosshairsPosition, speed = 0})
		for i, player in pairs(game.connected_players) do
			if settings.get_player_settings(player)["ion-cannon-play-klaxon"].value and storage.klaxonTick < current_tick then
				storage.klaxonTick = current_tick + 60
				player.play_sound({path = "ion-cannon-klaxon", volume_modifier = settings.get_player_settings(player)["ion-cannon-klaxon-volume"].value / 100})
			end
		end
		--if not player or not player.cheat_mode then
			GetCannonTableFromForce(force)[cannonNum][1] = settings.global["ion-cannon-cooldown-seconds"].value
			GetCannonTableFromForce(force)[cannonNum][2] = 0
		--end
		if player then
			player.print({"targeting-ion-cannon" , cannonNum})
			for i, p in pairs(player.force.connected_players) do
				if settings.get_player_settings(p)["ion-cannon-custom-alerts"].value then
					p.add_custom_alert(IonTarget, {type = "item", name = "orbital-ion-cannon"}, {"ion-cannon-target-location", cannonNum, TargetPosition.x, TargetPosition.y, targeterName}, true)
				end
			end
			script.raise_event(_G.when_ion_cannon_targeted, {surfce = surface, force = force, position = position, radius = settings.startup["ion-cannon-radius"].value, player_index = player.index,})		-- Passes event.surface, event.force, event.position, event.radius, and event.player_index
		else
			script.raise_event(_G.when_ion_cannon_targeted, {surface = surface, force = force, position = position, radius = settings.startup["ion-cannon-radius"].value})		-- Passes event.surface, event.force, event.position, and event.radius
		end
		return cannonNum
	end
end

local function install_ion_cannon(force, surface)
	local surfaceName = addIonCannon(force, surface)

	Events.on_nth_tick(60, process_60_ticks)
	for i, player in pairs(force.connected_players) do
		init_GUI(player)
		playSoundForPlayer("ion-cannon-charging", player)
	end
	if #GetCannonTableFromForce(force) == 1 then
		force.print({"congratulations-first"})
		force.print({"first-help"})
		force.print({"second-help"})
		force.print({"third-help"})
	else
		force.print({"congratulations-additional"})
		force.print({"ion-cannons-in-orbit", surfaceName, countOrbitingIonCannons(force, surface)})
	end
end

--- Called when the rocket is launched.
-- rocket :: LuaEntity
-- rocket_silo :: LuaEntity (optional)
-- player_index :: uint (optional): The player that is riding the rocket, if any.
Events.on_event(defines.events.on_rocket_launched, function(event)
	print("on_rocket_launched")
	local force = event.rocket.force

	print("item_count: " .. tostring(event.rocket.get_item_count()))
	print("item_count: " .. tostring(event.rocket.get_item_count()))
	local inv=event.rocket.get_main_inventory()
	if inv then
		for i=1,inv.get_item_count() do
			print("item["..tostring(i).."] = "..tostring(inv[i]))
		end
	end

	if event.rocket.get_item_count("orbital-ion-cannon") > 0 then
		print("orbital-ion-cannon found in rocket")
		install_ion_cannon(force, event.rocket_silo.surface)
	end
end)

local c_on_pre_build = defines.events.on_pre_build --COMPATIBILITY 1.1 'on_put_item' renamed to 'on_pre_build'
if not c_on_pre_build then c_on_pre_build = (defines.events--[[@as any]]).on_put_item end

Events.on_event(c_on_pre_build, function(event)
	local current_tick = event.tick
	if storage.tick and storage.tick > current_tick then
		return
	end
	storage.tick = current_tick + 10
	local player = game.players[event.player_index]
	if isHolding({name = "ion-cannon-targeter", count = 1}, player) and player.force.is_chunk_charted(player.surface, Chunk.from_position(event.position)) then
		targetIonCannon(player.force, event.position, player.surface, player)
		--player.cursor_stack.clear()
		--global.holding_targeter[event.player_index] = true
		--player.cursor_stack.set_stack({name = "ion-cannon-targeter", count = 1})
		--clearing and then setting the stack seems to destroy the item as you put it away, not sure why this is here
	end
end)

Events.on_event(defines.events.on_built_entity, function(event)
	local entity = event.entity
	if entity.name == "ion-cannon-targeter" then
		local player = game.players[event.player_index]
		player.cursor_stack.set_stack({name = "ion-cannon-targeter", count = 1})
		entity.destroy()
		return
	end
	if entity.name == "entity-ghost" then
		if entity.ghost_name == "ion-cannon-targeter" then
			entity.destroy()
			return
		end
	end
end)

Events.on_event(defines.events.on_trigger_created_entity, function(event)
	local created_entity = event.entity
	if created_entity.name == "ion-cannon-explosion" then
		script.raise_event(when_ion_cannon_fired, {surface = created_entity.surface, position = created_entity.position, radius = settings.startup["ion-cannon-radius"].value})		-- Passes event.surface, event.position, and event.radius
		--TODO: Is this charting the chunk for every force in the game? wtf?
		for i, force in pairs(game.forces) do
			force.chart(created_entity.surface, Position.expand_to_area(created_entity.position, 1))
		end
	end
end)


ModGui.initEvents()

local allowed_items = {"ion-cannon-targeter", "orbital-ion-cannon-area-targeter"}

local function give_shortcut_item(player, prototype_name)
	if prototypes.item[prototype_name] then
		local cc = false
		if Version.baseVersionGreaterOrEqual1d1() then
			cc = player.clear_cursor() --COMPATIBILITY 1.1
		else
			cc = player.clean_cursor() --Factorio < 1.1
		end
		--if remote.interfaces["space-exploration"] and remote.call("space-exploration", "remote_view_is_active", {player=player}) then
			player.cursor_ghost = prototypes.item[prototype_name]
		--else
		--	player.cursor_stack.set_stack({name = prototype_name}) --Warining: this will allow the player to obtain infinite remotes
		--	player.get_main_inventory().remove({name = prototype_name, count = 1})
		--end
	end
end

Events.on_event(defines.events.on_lua_shortcut, function(event)
	local prototype_name = event.prototype_name
	local player = game.players[event.player_index]
	if prototypes.shortcut[prototype_name] then
		for _, item_name in pairs(allowed_items) do
			if item_name == prototype_name then
				give_shortcut_item(player, prototype_name)
			end
		end
	end
end)


---@param e {entity: LuaEntity?, platform: LuaSpacePlatform?}
function on_built(e)
	if not e.entity or not e.entity.valid then return end
	--print("on_space_platform_built_entity "..e.entity.name)

	--[[ temorary solutuion: place a radar
	local inv = e.platform.hub.get_inventory(defines.inventory.hub_main)
	if not inv then return end
	if inv.get_item_count("orbital-ion-cannon") == 0 then return end
	local surface = game.surfaces[e.platform.space_location.name] --TODO.validate
	if not surface then return end
	inv.remove({name="orbital-ion-cannon", count=1})
	]]

	if e.entity.name ~= "orbital-ion-cannon" and e.entity.name ~= "orbital-ion-cannon-mk2" then return end
	if not e.platform then e.platform = e.entity.surface.platform end
	if not e.platform then return end
	local force = e.platform.force
	local isMk2Editity = e.entity.name == "orbital-ion-cannon-mk2"
	local isMk2Tech = force.technologies[mod.tech.cannon_mk2].researched
	local result = (isMk2Editity and isMk2Tech) or (not isMk2Editity and not isMk2Tech)
	if result then install_ion_cannon(e.platform.force, e.platform.space_location) else
		e.entity.surface.create_entity({
			name = "big-explosion",
			position = e.entity.position,
		})
		e.entity.destroy()
		force.print({"explosion-because-obsolete-technology"})
	end
end

Events.on_built(on_built)

Events.on_event(defines.events.on_player_selected_area, function(event)
	if event.item ~= "orbital-ion-cannon-area-targeter" then return end
	local player = game.players[event.player_index]
	local radius = settings.startup["ion-cannon-radius"].value --[[@as number]] -- Radius eines Kreises
	local surface = player.surface
	local force = player.force
	local positions = {}

	-- Bereichsgrenzen
	local area = event.area
	--local x_start, x_end = area.left_top.x, area.right_bottom.x
	--local y_start, y_end = area.left_top.y, area.right_bottom.y
	--allow 30% border overlap
	local x_start, x_end = area.left_top.x - radius/3, area.right_bottom.x + radius/3
	local y_start, y_end = area.left_top.y - radius/3, area.right_bottom.y + radius/3

	-- Abstand für hexagonales Muster
	local radius = radius / 1.1 -- 10% Overlap
	local x_step = 2 * radius
	local y_step = math.sqrt(3) * radius

	-- Berechne effektive Anzahl der Kreise
	local x_count = math.floor((x_end - x_start) / x_step)
	local y_count = math.floor((y_end - y_start) / y_step)

	-- Berechne tatsächliche Abdeckung durch die Kreise
	local effective_width = (x_count - 1) * x_step + 2 * radius
	local effective_height = (y_count - 1) * y_step + 2 * radius

	-- Zentrierung: Versatz berechnen
	local x_offset = x_start + ((x_end - x_start) - effective_width) / 2
	local y_offset = y_start + ((y_end - y_start) - effective_height) / 2

	-- Versuche, hexagonales Gitter zu platzieren
	for y = y_offset + radius, y_offset + effective_height - radius, y_step do
		local row_offset = ((math.floor((y - y_offset) / y_step) % 2) == 0) and 0 or radius

		for x = x_offset + radius + row_offset, x_offset + effective_width - radius, x_step do
			-- Setze Dummy-Entität als "Kreis"
			table.insert(positions, {x, y})
			circles_placed = true -- Mindestens ein Kreis wurde gesetzt
		end
	end

	-- Fallback: Eine horizontale oder vertikale Reihe, falls kein Gitter passt
	if #positions == 0 then
		local x_range = x_end - x_start
		local y_range = y_end - y_start

		if x_range >= y_range then
			-- Horizontale Reihe platzieren
			for x = x_start + radius, x_end - radius, x_step do
				table.insert(positions,  {x, (y_start + y_end) / 2})
			end
		else
			-- Vertikale Reihe platzieren
			for y = y_start + radius, y_end - radius, y_step do
				table.insert(positions, {(x_start + x_end) / 2, y})
			end
		end
	end

	-- Letzter Fallback: Ein Kreis in die Mitte setzen
	if #positions == 0 then
		local center_x = (x_start + x_end) / 2
		local center_y = (y_start + y_end) / 2
		table.insert(positions, {center_x, center_y})
	end

	for _, position in ipairs(positions) do
		--game.forces[player.force.name].add_chart_tag(surface, {position = position, text = "O"})
		targetIonCannon(force, {x=position[1],y=position[2]}, surface, player)
	end
end)



Events.on_init(this.initialize)
Events.on_load(this.onLoad)
Events.on_configuration_changed(this.initialize)
