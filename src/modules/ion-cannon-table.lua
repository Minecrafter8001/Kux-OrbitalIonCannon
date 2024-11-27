function GetCannonTable(name)
    return storage.forces_ion_cannon_table[name]
end

function GetCannonTableFromForce(force)
    return storage.forces_ion_cannon_table[force.name]
end

function NewCannonTableForForce(force)
    storage.forces_ion_cannon_table[force.name] = {}
end

function CountEntriesBySurface(entries)
	local surfaceCounts = {}

	for _, entry in ipairs(entries) do
		local surfaceName = entry[3]
		if not surfaceCounts[surfaceName] then
			surfaceCounts[surfaceName] = 0
		end
		surfaceCounts[surfaceName] = surfaceCounts[surfaceName] + 1
	end

	return surfaceCounts
end