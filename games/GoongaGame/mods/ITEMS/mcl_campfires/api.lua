local S = minetest.get_translator(minetest.get_current_modname())
mcl_campfires = {}

local drop_items = mcl_util.drop_items_from_meta_container("main")

local function on_blast(pos)
	local meta = minetest.get_meta(pos)
	local node = minetest.get_node(pos)
	local entites = minetest.get_objects_inside_radius(pos, 0.5)
	if entites then
		for _, food_entity in ipairs(entites) do
			if food_entity then
				if food_entity:get_luaentity().name == "mcl_campfires:food_entity" then
					food_entity:remove()
					for i = 1, 4 do
						meta:set_string("food_x_"..tostring(i), nil)
						meta:set_string("food_y_"..tostring(i), nil)
						meta:set_string("food_z_"..tostring(i), nil)
					end
				end
			end
		end
	end
	drop_items(pos, node)
	minetest.remove_node(pos)
end

-- on_rightclick function to take items that are cookable in a campfire, and put them in the campfire inventory
function mcl_campfires.take_item(pos, node, player, itemstack)
	local campfire_spots = {
		vector.new(-0.25, -0.04, -0.25),
		vector.new( 0.25, -0.04, -0.25),
		vector.new( 0.25, -0.04,  0.25),
		vector.new(-0.25, -0.04,  0.25),
	}
	local food_entity = {nil,nil,nil,nil}
	local is_creative = minetest.is_creative_enabled(player:get_player_name())
	local inv = player:get_inventory()
	local campfire_meta = minetest.get_meta(pos)
	local campfire_inv = campfire_meta:get_inventory()
	local timer = minetest.get_node_timer(pos)
	local stack = itemstack:peek_item(1)
	if minetest.get_item_group(itemstack:get_name(), "campfire_cookable") ~= 0 then
		local cookable = minetest.get_craft_result({method = "cooking", width = 1, items = {itemstack}})
		if cookable then
			for space = 1, 4 do -- Cycle through spots
				local spot = campfire_inv:get_stack("main", space)
				if not spot or spot == (ItemStack("") or ItemStack("nil")) then -- Check if the spot is empty or not
					if not is_creative then itemstack:take_item(1) end -- Take the item if in creative
					campfire_inv:set_stack("main", space, stack) -- Set the inventory itemstack at the empty spot
					campfire_meta:set_int("cooktime_"..tostring(space), 30) -- Set the cook time meta
					food_entity[space] = minetest.add_entity(pos + campfire_spots[space], "mcl_campfires:food_entity") -- Spawn food item on the campfire
					local food_luaentity = food_entity[space]:get_luaentity()
					food_luaentity.wield_item = campfire_inv:get_stack("main", space):get_name() -- Set the wielditem of the food item to the food on the campfire
					food_luaentity.wield_image = "mcl_mobitems_"..string.sub(campfire_inv:get_stack("main", space):get_name(), 14).."_raw.png" -- Set the wield_image to the food item on the campfire
					food_entity[space]:set_properties(food_luaentity) -- Apply changes to the food entity
					campfire_meta:set_string("food_x_"..tostring(space), tostring(food_entity[space]:getpos().x))
					campfire_meta:set_string("food_y_"..tostring(space), tostring(food_entity[space]:getpos().y))
					campfire_meta:set_string("food_z_"..tostring(space), tostring(food_entity[space]:getpos().z))
					break
				end
			end
		end
		timer:start(1) -- Start cook timer
	end
end

-- on_timer function to run the cook timer and cook items.
function mcl_campfires.cook_item(pos, elapsed)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local continue = 0
	-- Cycle through slots to cook them.
	for i = 1, 4 do
		local time_r = meta:get_int("cooktime_"..tostring(i))
		local item = inv:get_stack("main", i)
		local food_entity = nil
		local food_x = tonumber(meta:get_string("food_x_"..tostring(i)))
		local food_y = tonumber(meta:get_string("food_y_"..tostring(i)))
		local food_z = tonumber(meta:get_string("food_z_"..tostring(i)))
		if food_x and food_y and food_z then
			local entites = minetest.get_objects_inside_radius(vector.new(food_x, food_y, food_z), 0)
			if entites then
				for _, entity in ipairs(entites) do
					if entity then
						luaentity = entity:get_luaentity()
						if luaentity then
							name = luaentity.name
							if name == "mcl_campfires:food_entity" then
								food_entity = entity
								food_entity:set_properties({wield_item = inv:get_stack("main", i):get_name()})
							end
						end
					end
				end
			end
		end
		if item ~= (ItemStack("") or ItemStack("nil")) then
			-- Item hasn't been cooked completely, continue cook timer countdown.
			if time_r and time_r ~= 0 and time_r > 0 then
				meta:set_int("cooktime_"..tostring(i), time_r - 1)
			-- Item cook timer is up, finish cooking process and drop cooked item.
			elseif time_r <= 0 then
				local cooked = minetest.get_craft_result({method = "cooking", width = 1, items = {item}})
				if cooked then
					if food_entity then
						food_entity:remove() -- Remove visual food entity
						meta:set_string("food_x_"..tostring(i), nil)
						meta:set_string("food_y_"..tostring(i), nil)
						meta:set_string("food_z_"..tostring(i), nil)
					end
					minetest.add_item(pos, cooked.item) -- Drop Cooked Item
					inv:set_stack("main", i, "") -- Clear Inventory
					continue  = continue + 1 -- Indicate that the slot is clear.
				end
			end
		end
	end
	-- Not all slots are empty, continue timer.
	if continue ~= 4 then
		return true
	-- Slots are empty, stop node timer.
	else
		return false
	end
end

function mcl_campfires.register_campfire(name, def)
	-- Define Campfire
	minetest.register_node(name, {
		description = def.description,
		_tt_help = S("Cooks food and keeps bees happy."),
		_doc_items_longdesc = S("Campfires have multiple uses, including keeping bees happy, cooking raw meat and fish, and as a trap."),
		inventory_image = def.inv_texture,
		wield_image = def.inv_texture,
		drawtype = "mesh",
		mesh = "mcl_campfires_campfire.obj",
		tiles = {{name="mcl_campfires_log.png"},},
		use_texture_alpha = "clip",
		groups = { handy=1, axey=1, material_wood=1, not_in_creative_inventory=1, campfire=1, },
		paramtype = "light",
		paramtype2 = "facedir",
		on_rightclick = function (pos, node, player, itemstack, pointed_thing)
			if player:get_wielded_item():get_name() == "mcl_fire:flint_and_steel" then
				node.name = name.."_lit"
				minetest.set_node(pos, node)
			end
		end,
		drop = def.drops,
		_mcl_silk_touch_drop = {name},
		mcl_sounds.node_sound_wood_defaults(),
		selection_box = {
			type = 'fixed',
			fixed = {-.5, -.5, -.5, .5, -.05, .5}, --left, bottom, front, right, top
		},
		collision_box = {
			type = 'fixed',
			fixed = {-.5, -.5, -.5, .5, -.05, .5},
		},
		_mcl_blast_resistance = 2,
		_mcl_hardness = 2,
	})

	--Define Lit Campfire
	minetest.register_node(name.."_lit", {
		description = def.description,
		_tt_help = S("Cooks food and keeps bees happy."),
		_doc_items_longdesc = S("Campfires have multiple uses, including keeping bees happy, cooking raw meat and fish, and as a trap."),
		inventory_image = def.inv_texture,
		wield_image = def.inv_texture,
		drawtype = "mesh",
		mesh = "mcl_campfires_campfire_lit.obj",
		tiles = {{
			name=def.fire_texture,
			animation={
				type="vertical_frames",
				aspect_w=16,
				aspect_h=16,
				length=2.0
			}},
			{name=def.lit_logs_texture,
			animation={
				type="vertical_frames",
				aspect_w=16,
				aspect_h=16,
				length=2.0
			}}
		},
		use_texture_alpha = "clip",
		groups = { handy=1, axey=1, material_wood=1, campfire=1, lit_campfire=1 },
		paramtype = "light",
		paramtype2 = "facedir",
		on_construct = function(pos)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			inv:set_size("main", 4)
		end,
		on_rightclick = function (pos, node, player, itemstack, pointed_thing)
			if player:get_wielded_item():get_name():find("shovel") then
				node.name = name
				minetest.set_node(pos, node)
				minetest.sound_play("fire_extinguish_flame", {pos = pos, gain = 0.25, max_hear_distance = 16}, true)
			end
			mcl_campfires.take_item(pos, node, player, itemstack)
		end,
		on_timer = mcl_campfires.cook_item,
		drop = def.drops,
		_mcl_silk_touch_drop = {name.."_lit"},
		light_source = def.lightlevel,
		mcl_sounds.node_sound_wood_defaults(),
		selection_box = {
			type = "fixed",
			fixed = {-.5, -.5, -.5, .5, -.05, .5}, --left, bottom, front, right, top
		},
		collision_box = {
			type = "fixed",
			fixed = {-.5, -.5, -.5, .5, -.05, .5},
		},
		_mcl_blast_resistance = 2,
		_mcl_hardness = 2,
		damage_per_second = def.damage,
		on_blast = on_blast,
		after_dig_node = on_blast,
	})
end

local function burn_in_campfire(obj)
	local p = obj:get_pos()
	if p then
		local n = minetest.find_node_near(p,0.4,{"group:lit_campfire"},true)
		if n then
			mcl_burning.set_on_fire(obj, 5)
		end
	end
end

local etime = 0
minetest.register_globalstep(function(dtime)
	etime = dtime + etime
	if etime < 0.5 then return end
	etime = 0
	for _,pl in pairs(minetest.get_connected_players()) do
		burn_in_campfire(pl)
	end
	for _,ent in pairs(minetest.luaentities) do
		if ent.is_mob then
			burn_in_campfire(ent.object)
		end
	end
end)
