
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Excavation pickaxes - sorted in order of delicacy. Players will have to choose the right one for each part of excavation.

/obj/item/pickaxe/brush
	name = "brush"
	icon = 'icons/obj/xenoarchaeology.dmi'
	icon_state = "pick_brush"
	item_state = "xenoarch_pick"
	contained_sprite = TRUE
	digspeed = 20
	digspeed_unwielded = 20
	digspeed_wielded = 20
	force = 2
	desc = "Thick metallic wires for clearing away dust and loose scree (1 centimetre excavation depth)."
	excavation_amount = 0.5
	drill_sound = 'sound/weapons/thudswoosh.ogg'
	drill_verb = "brushing"
	w_class = WEIGHT_CLASS_SMALL
	can_wield = 0

	action_button_name = null

/obj/item/pickaxe/one_pick
	name = "1/6 pick"
	icon = 'icons/obj/xenoarchaeology.dmi'
	icon_state = "pick1"
	item_state = "xenoarch_pick"
	contained_sprite = TRUE
	digspeed = 20
	digspeed_unwielded = 20
	digspeed_wielded = 20
	force = 2
	desc = "A miniature excavation tool for precise digging (2 centimetre excavation depth)."
	excavation_amount = 1
	drill_sound = 'sound/items/Screwdriver.ogg'
	drill_verb = "delicately picking"
	w_class = WEIGHT_CLASS_SMALL
	can_wield = 0

	action_button_name = null

/obj/item/pickaxe/two_pick
	name = "1/3 pick"
	icon = 'icons/obj/xenoarchaeology.dmi'
	icon_state = "pick2"
	item_state = "xenoarch_pick"
	contained_sprite = TRUE
	digspeed = 20
	digspeed_unwielded = 20
	digspeed_wielded = 20
	force = 2
	desc = "A miniature excavation tool for precise digging (4 centimetre excavation depth)."
	excavation_amount = 2
	drill_sound = 'sound/items/Screwdriver.ogg'
	drill_verb = "delicately picking"
	w_class = WEIGHT_CLASS_SMALL
	can_wield = 0

	action_button_name = null

/obj/item/pickaxe/three_pick
	name = "1/2 pick"
	icon = 'icons/obj/xenoarchaeology.dmi'
	icon_state = "pick3"
	item_state = "xenoarch_pick"
	contained_sprite = TRUE
	digspeed = 20
	digspeed_unwielded = 20
	digspeed_wielded = 20
	force = 2
	desc = "A miniature excavation tool for precise digging (6 centimetre excavation depth)."
	excavation_amount = 3
	drill_sound = 'sound/items/Screwdriver.ogg'
	drill_verb = "delicately picking"
	w_class = WEIGHT_CLASS_SMALL
	can_wield = 0

	action_button_name = null

/obj/item/pickaxe/four_pick
	name = "2/3 pick"
	icon = 'icons/obj/xenoarchaeology.dmi'
	icon_state = "pick4"
	item_state = "xenoarch_pick"
	contained_sprite = TRUE
	digspeed = 20
	digspeed_unwielded = 20
	digspeed_wielded = 20
	force = 2
	desc = "A miniature excavation tool for precise digging (8 centimetre excavation depth)."
	excavation_amount = 4
	drill_sound = 'sound/items/Screwdriver.ogg'
	drill_verb = "delicately picking"
	w_class = WEIGHT_CLASS_SMALL
	can_wield = 0

	action_button_name = null

/obj/item/pickaxe/five_pick
	name = "5/6 pick"
	icon = 'icons/obj/xenoarchaeology.dmi'
	icon_state = "pick5"
	item_state = "xenoarch_pick"
	contained_sprite = TRUE
	digspeed = 20
	digspeed_unwielded = 20
	digspeed_wielded = 20
	force = 2
	desc = "A miniature excavation tool for precise digging (10 centimetre excavation depth)."
	excavation_amount = 5
	drill_sound = 'sound/items/Screwdriver.ogg'
	drill_verb = "delicately picking"
	w_class = WEIGHT_CLASS_SMALL
	can_wield = 0

	action_button_name = null

/obj/item/pickaxe/six_pick
	name = "1/1 pick"
	icon = 'icons/obj/xenoarchaeology.dmi'
	icon_state = "pick6"
	item_state = "xenoarch_pick"
	contained_sprite = TRUE
	digspeed = 20
	digspeed_unwielded = 20
	digspeed_wielded = 20
	force = 2
	desc = "A miniature excavation tool for precise digging (12 centimetre excavation depth)."
	excavation_amount = 6
	drill_sound = 'sound/items/Screwdriver.ogg'
	drill_verb = "delicately picking"
	w_class = WEIGHT_CLASS_SMALL
	can_wield = 0

	action_button_name = null

/obj/item/pickaxe/hand
	name = "hand pickaxe"
	icon = 'icons/obj/xenoarchaeology.dmi'
	icon_state = "pick_hand"
	item_state = "pickaxe"
	digspeed = 20
	digspeed_unwielded = 20
	digspeed_wielded = 20
	force = 15
	desc = "A smaller, more precise version of the pickaxe (30 centimetre excavation depth)."
	excavation_amount = 15
	drill_sound = /singleton/sound_category/pickaxe_sound
	drill_verb = "clearing"
	w_class = WEIGHT_CLASS_NORMAL
	can_wield = 0

	action_button_name = null

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Pack for holding pickaxes

/obj/item/storage/box/excavation
	name = "excavation pick set"
	icon = 'icons/obj/storage/boxes.dmi'
	icon_state = "excavation"
	desc = "A rugged metal case containing a set of standardized picks used in archaeological digs."
	item_state = "box"
	foldable = /obj/item/stack/material/cardboard //BubbleWrap
	storage_slots = 7
	w_class = WEIGHT_CLASS_SMALL
	can_hold = list(/obj/item/pickaxe/brush,\
	/obj/item/pickaxe/one_pick,\
	/obj/item/pickaxe/two_pick,\
	/obj/item/pickaxe/three_pick,\
	/obj/item/pickaxe/four_pick,\
	/obj/item/pickaxe/five_pick,\
	/obj/item/pickaxe/six_pick)
	make_exact_fit = TRUE
	max_w_class = WEIGHT_CLASS_NORMAL
	use_to_pickup = TRUE // for picking up broken bulbs, not that most people will try

/obj/item/storage/box/excavation/fill()
	..()
	new /obj/item/pickaxe/brush(src)
	new /obj/item/pickaxe/one_pick(src)
	new /obj/item/pickaxe/two_pick(src)
	new /obj/item/pickaxe/three_pick(src)
	new /obj/item/pickaxe/four_pick(src)
	new /obj/item/pickaxe/five_pick(src)
	new /obj/item/pickaxe/six_pick(src)
