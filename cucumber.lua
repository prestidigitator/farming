
--= Cucumber (Original textures from DocFarming mod)
-- https://forum.minetest.net/viewtopic.php?id=3948

minetest.register_craftitem("farming:cucumber", {
	description = "Cucumber",
	inventory_image = "farming_cucumber.png",
	on_place = function(itemstack, placer, pointed_thing)
		return farming.place_seed(itemstack, placer, pointed_thing, "farming:cucumber_1")
	end,
	on_use = minetest.item_eat(4),
})

-- Define Cucumber growth stages

minetest.register_node("farming:cucumber_1", {
	drawtype = "plantlike",
	tiles = {"farming_cucumber_1.png"},
	paramtype = "light",
	waving = 1,
	walkable = false,
	buildable_to = true,
	drop = "",
	selection_box = {type = "fixed",fixed = {-0.5, -0.5, -0.5, 0.5, -5/16, 0.5},},
	groups = {snappy=3,flammable=2,plant=1,not_in_creative_inventory=1,attached_node=1,growing=1},
	sounds = default.node_sound_leaves_defaults(),
})

minetest.register_node("farming:cucumber_2", {
	drawtype = "plantlike",
	tiles = {"farming_cucumber_2.png"},
	paramtype = "light",
	waving = 1,
	walkable = false,
	buildable_to = true,
	drop = "",
	selection_box = {type = "fixed",fixed = {-0.5, -0.5, -0.5, 0.5, -5/16, 0.5},},
	groups = {snappy=3,flammable=2,plant=1,not_in_creative_inventory=1,attached_node=1,growing=1},
	sounds = default.node_sound_leaves_defaults(),
})

minetest.register_node("farming:cucumber_3", {
	drawtype = "plantlike",
	tiles = {"farming_cucumber_3.png"},
	paramtype = "light",
	waving = 1,
	walkable = false,
	buildable_to = true,
	drop = "",
	selection_box = {type = "fixed",fixed = {-0.5, -0.5, -0.5, 0.5, -5/16, 0.5},},
	groups = {snappy=3,flammable=2,plant=1,not_in_creative_inventory=1,attached_node=1,growing=1},
	sounds = default.node_sound_leaves_defaults(),
})

-- Last stage of Cucumber growth doesnnot have growing=1 so abm never has to check these

minetest.register_node("farming:cucumber_4", {
	drawtype = "plantlike",
	tiles = {"farming_cucumber_4.png"},
	paramtype = "light",
	waving = 1,
	walkable = false,
	buildable_to = true,
	is_ground_content = true,
	drop = {
		items = {
			{items = {'farming:cucumber'},rarity=1},
			{items = {'farming:cucumber 2'},rarity=2},
		}
	},
	selection_box = {type = "fixed",fixed = {-0.5, -0.5, -0.5, 0.5, -5/16, 0.5},},
	groups = {snappy=3,flammable=2,plant=1,not_in_creative_inventory=1,attached_node=1},
	sounds = default.node_sound_leaves_defaults(),
})
