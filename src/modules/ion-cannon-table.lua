function GetCannonTable(name)
    return storage.forces_ion_cannon_table[name]
end

function GetCannonTableFromForce(force)
    return storage.forces_ion_cannon_table[force.name]
end

function NewCannonTableForForce(force)
    storage.forces_ion_cannon_table[force.name] = {}
end
