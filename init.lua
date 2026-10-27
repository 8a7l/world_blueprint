-- world_blueprint/init.lua
local modpath = minetest.get_modpath("world_blueprint")
local map_data = {}
local SPAWN_POS = { x = 0, y = 5, z = 0 }

-- Зчитуємо JSON
local file = io.open(modpath .. "/map.json", "r")
if file then
    local content = file:read("*all")
    file:close()
    map_data = minetest.parse_json(content) or {}
end

local function check_and_build()
    local flag_file = minetest.get_worldpath() .. "/world_blueprint_built.flag"
    local f = io.open(flag_file, "r")
    if f then
        f:close()
        minetest.log("action", "[world_blueprint] Карта вже існує.")
    else
        architect_core.build(map_data)
        local out = io.open(flag_file, "w")
        if out then out:write("Built"); out:close() end
    end
end

check_and_build()

-- Безпечний спавн
minetest.register_on_joinplayer(function(player)
    local pos = player:get_pos()
    if pos.y > 100 or pos.y < -10 then
        player:set_pos(SPAWN_POS)
    end
end)

minetest.register_on_respawnplayer(function(player)
    player:set_pos(SPAWN_POS)
    return true
end)

-- ОНОВЛЕНА ЧАТ-КОМАНДА З ПІДТРИМКОЮ ПОВОРОТУ
minetest.register_chatcommand("place_schem", {
    params = "<назва_файлу> [поворот]",
    description = "Поставити схематик туди, куди дивиться гравець (поворот: 0, 90, 180, 270)",
    privs = {server = true},
    func = function(name, param)
        -- Розбиваємо параметри на назву файлу та кут повороту
        local file_name, rot = param:match("^(%S+)%s*(%S*)$")
        
        if not file_name or file_name == "" then
            return false, "Вкажіть назву файлу! Наприклад: /place_schem house.mts 90"
        end
        
        -- Якщо кут не вказано, ставимо 0
        if rot == "" then
            rot = "0" 
        end

        -- Перевіряємо, чи правильно вказано кут
        if rot ~= "0" and rot ~= "90" and rot ~= "180" and rot ~= "270" then
            return false, "Неправильний кут повороту! Дозволено лише 0, 90, 180 або 270."
        end

        local player = minetest.get_player_by_name(name)
        if not player then return end

        -- Визначаємо позицію за допомогою променя (Raycast)
        local p_pos = player:get_pos()
        local eye_h = player:get_properties().eye_height or 1.5
        local eye_pos = {x = p_pos.x, y = p_pos.y + eye_h, z = p_pos.z}
        local look_dir = player:get_look_dir()
        
        local target_pos = {
            x = eye_pos.x + look_dir.x * 20,
            y = eye_pos.y + look_dir.y * 20,
            z = eye_pos.z + look_dir.z * 20
        }
        local ray = minetest.raycast(eye_pos, target_pos, false, true)
        local pointed = ray:next()

        local pos
        if pointed and pointed.type == "node" then
            pos = pointed.under
            pos.y = pos.y + 1
        else
            pos = {x = p_pos.x, y = p_pos.y - 1, z = p_pos.z}
        end

        pos.x = math.floor(pos.x)
        pos.y = math.floor(pos.y)
        pos.z = math.floor(pos.z)

        -- Шлях до схематика
        local schematic_path = architect_core.schems_dir .. "/" .. file_name

        local file = io.open(schematic_path, "r")
        if not file then
            return false, "Файл " .. file_name .. " не знайдено в папці schems!"
        end
        file:close()

        -- Ставимо схематик із вказаним кутом
        minetest.place_schematic(pos, schematic_path, rot, true)
        
        minetest.chat_send_player(name, "[world_blueprint] Будівлю " .. file_name .. " встановлено з поворотом " .. rot .. "°!")
        return true
    end,
})