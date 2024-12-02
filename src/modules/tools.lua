require "modules/IonCannonStorage"

---@param sound string
---@param player LuaPlayer
--TODO add debounce to prevent overlapping sounds
function playSoundForPlayer(sound, player)
	if not settings.get_player_settings(player)["ion-cannon-play-voices"].value then return end
	local voice = settings.get_player_settings(player)["ion-cannon-voice-style"].value
	player.play_sound({path = sound .. "-" .. voice, volume_modifier = settings.get_player_settings(player)["ion-cannon-voice-volume"].value / 100})
end