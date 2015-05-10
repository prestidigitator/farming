--[[
	Minetest Farming Redo Mod 1.14 (19th April 2015)
	by TenPlus1
]]

farming = {}
farming.mod = "redo"
farming.hoe_on_use = default.hoe_on_use

local GrowthModel = dofile(minetest.get_modpath("farming").."/GrowthModel.lua")
dofile(minetest.get_modpath("farming").."/soil.lua")
dofile(minetest.get_modpath("farming").."/hoes.lua")
dofile(minetest.get_modpath("farming").."/grass.lua")
dofile(minetest.get_modpath("farming").."/wheat.lua")
dofile(minetest.get_modpath("farming").."/cotton.lua")
dofile(minetest.get_modpath("farming").."/carrot.lua")
dofile(minetest.get_modpath("farming").."/potato.lua")
dofile(minetest.get_modpath("farming").."/tomato.lua")
dofile(minetest.get_modpath("farming").."/cucumber.lua")
dofile(minetest.get_modpath("farming").."/corn.lua")
dofile(minetest.get_modpath("farming").."/coffee.lua")
dofile(minetest.get_modpath("farming").."/melon.lua")
dofile(minetest.get_modpath("farming").."/sugar.lua")
dofile(minetest.get_modpath("farming").."/pumpkin.lua")
dofile(minetest.get_modpath("farming").."/cocoa.lua")
dofile(minetest.get_modpath("farming").."/raspberry.lua")
dofile(minetest.get_modpath("farming").."/blueberry.lua")
dofile(minetest.get_modpath("farming").."/rhubarb.lua")
dofile(minetest.get_modpath("farming").."/beanpole.lua")
dofile(minetest.get_modpath("farming").."/donut.lua")
dofile(minetest.get_modpath("farming").."/mapgen.lua")
dofile(minetest.get_modpath("farming").."/compatibility.lua") -- Farming Plus compatibility

-- Used to grow plants with a model of time independent of when the ABM actually runs.
local growth_model = GrowthModel(13, 1000,  -- light range
                                 160);      -- average seconds per stage

-- Place Seeds on Soil

function farming.place_seed(itemstack, placer, pointed_thing, plantname)
	local pt = pointed_thing

	-- check if pointing at a node
	if not pt and pt.type ~= "node" then
		return
	end

	local under = minetest.get_node(pt.under)
	local above = minetest.get_node(pt.above)

	-- check if pointing at the top of the node
	if pt.above.y ~= pt.under.y+1 then
		return
	end

	-- return if any of the nodes is not registered
	if not minetest.registered_nodes[under.name]
	or not minetest.registered_nodes[above.name] then
		return
	end

	-- can I replace above node, and am I pointing at soil
	if not minetest.registered_nodes[above.name].buildable_to
	or minetest.get_item_group(under.name, "soil") < 2 
	or minetest.get_item_group(above.name, "plant") ~= 0 then -- ADDED this line for multiple seed placement bug
		return
	end

	-- add the node and remove 1 item from the itemstack
	if not minetest.is_protected(pt.above, placer:get_player_name()) then
		minetest.add_node(pt.above, {name=plantname})
		growth_model:mark_time(pt.above);  -- Marks initial planting time to avoid extra ABM period
		if not minetest.setting_getbool("creative_mode") then
			itemstack:take_item()
		end
		return itemstack
	end
end

-- Single ABM Handles Growing of All Plants

--- Returns (plant_name, stage, max_stage), or nil if pos isn't loaded
local function examine_plant(node)
	local name = node and node.name
	if not name or name == "ignore" then return end

	local sep_pos = name:find("_[^_]+$")

	local plant, stage
	if sep_pos and sep_pos > 1 then
		stage = tonumber(name:sub(sep_pos+1));
		if stage and stage >= 0 then
			plant = name:sub(1, sep_pos-1);
		else
			plant, stage = name, 0
		end
	else
		plant, stage = name, 0
	end

	local max_stage = stage
	while minetest.registered_nodes[plant.."_"..(max_stage+1)] do
		max_stage = max_stage+1
	end

	return plant, stage, max_stage
end

-- farming.DEBUG = farming.DEBUG or {};

local DEBUG_farming_start_time_us = 0;
local DEBUG_farming_end_time_us   = 0;
local DEBUG_farming_dt_us         = 0;
local DEBUG_farming_runs          = 0;
if farming.DEBUG then
	function farming.DEBUG.reportTimes()
		local us_per_run  = (DEBUG_farming_runs > 0 and
		                     DEBUG_farming_dt_us/DEBUG_farming_runs)
		                    or 0;
		local report_time = (DEBUG_farming_end_time_us -
		                     DEBUG_farming_start_time_us)/1000000.0;
		print("farming.DEBUG: ABM used "..DEBUG_farming_dt_us.."us over "..
		      DEBUG_farming_runs.." runs and "..report_time.."s, making "..
		      us_per_run.."us per run");
	end;
	function farming.DEBUG.resetTimes()
		local t = minetest.get_us_time();
		DEBUG_farming_start_time_us = t;
		DEBUG_farming_end_time_us   = t;
		DEBUG_farming_dt_us         = 0;
		DEBUG_farming_runs          = 0;
	end;
end;

minetest.register_abm({
	nodenames = {"group:growing"},
	neighbors = {"farming:soil_wet", "default:jungletree"},
	interval = 80,
	chance   = 3,

	action = function(pos, node)
		local t0_us;
		if farming.DEBUG then
			t0_us = minetest.get_us_time();
		end;

		-- get node type (e.g. farming:wheat_1)
		local plant, stage, max_stage = examine_plant(node);
		if not plant or stage >= max_stage then return end

		local grow = true
		
		-- Check for Cocoa Pod
		if plant == "farming:cocoa" then
			if not minetest.find_node_near(pos, 1, {"default:jungletree", "moretrees:jungletree_leaves_green"}) then
				grow = false
			end
		else
			-- check if on wet soil
			pos.y = pos.y-1
			if minetest.get_node(pos).name ~= "farming:soil_wet" then
				grow = false
			end
			pos.y = pos.y+1
		end

		if grow then
			local growth = growth_model:growth_stages(pos, stage, max_stage);
			if growth > 0 then
				minetest.set_node(pos, { name = plant.."_"..(stage+growth) });
			end
		end

		growth_model:mark_time(pos);

		if farming.DEBUG then
			local t1_us = minetest.get_us_time();
			DEBUG_farming_end_time_us = t1_us;
			DEBUG_farming_dt_us       = DEBUG_farming_dt_us + (t1_us - t0_us);
			DEBUG_farming_runs        = DEBUG_farming_runs + 1;
			local elapsed_us          = t1_us - DEBUG_farming_start_time_us;
			if DEBUG_farming_runs >= 400 or elapsed_us > 100000000.0 then
				farming.DEBUG.reportTimes();
				farming.DEBUG.resetTimes();
			end;
		end;
	end
})

-- Function to register plants (for compatibility)

farming.register_plant = function(name, def)
	local mname = name:split(":")[1]
	local pname = name:split(":")[2]

	-- Check def table
	if not def.description then
		def.description = "Seed"
	end
	if not def.inventory_image then
		def.inventory_image = "unknown_item.png"
	end
	if not def.steps then
		return nil
	end

	-- Register seed
	minetest.register_node(":" .. mname .. ":seed_" .. pname, {
		description = def.description,
		tiles = {def.inventory_image},
		inventory_image = def.inventory_image,
		wield_image = def.inventory_image,
		drawtype = "signlike",
		groups = {seed = 1, snappy = 3, attached_node = 1},
		paramtype = "light",
		paramtype2 = "wallmounted",
		walkable = false,
		sunlight_propagates = true,
		selection_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, -5/16, 0.5},},
		on_place = function(itemstack, placer, pointed_thing)
			return farming.place_seed(itemstack, placer, pointed_thing, mname .. ":"..pname.."_1")
		end
	})

	-- Register harvest
	minetest.register_craftitem(":" .. mname .. ":" .. pname, {
		description = pname:gsub("^%l", string.upper),
		inventory_image = mname .. "_" .. pname .. ".png",
	})

	-- Register growing steps
	for i=1,def.steps do
		local drop = {
			items = {
				{items = {mname .. ":" .. pname}, rarity = 9 - i},
				{items = {mname .. ":" .. pname}, rarity= 18 - i * 2},
				{items = {mname .. ":seed_" .. pname}, rarity = 9 - i},
				{items = {mname .. ":seed_" .. pname}, rarity = 18 - i * 2},
			}
		}
		
		local g = {snappy = 3, flammable = 2, plant = 1, not_in_creative_inventory = 1, attached_node = 1, growing = 1}
		-- Last step doesn't need growing=1 so Abm never has to check these
		if i == def.steps then
			g = {snappy = 3, flammable = 2, plant = 1, not_in_creative_inventory = 1, attached_node = 1}
		end

		minetest.register_node(mname .. ":" .. pname .. "_" .. i, {
			drawtype = "plantlike",
			waving = 1,
			tiles = {mname .. "_" .. pname .. "_" .. i .. ".png"},
			paramtype = "light",
			walkable = false,
			buildable_to = true,
			is_ground_content = true,
			drop = drop,
			selection_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, -5/16, 0.5},},
			groups = g,
			sounds = default.node_sound_leaves_defaults(),
		})
	end

	-- Return info
	local r = {seed = mname .. ":seed_" .. pname, harvest = mname .. ":" .. pname}
	return r
end

--[[ Cotton (example, is already registered in cotton.lua)
farming.register_plant("farming:cotton", {
	description = "Cotton seed",
	inventory_image = "farming_cotton_seed.png",
	steps = 8,
})
--]]
