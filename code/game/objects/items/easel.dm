/obj/structure/easel
	name = "easel"
	desc = "Only for the finest of art!"
	icon = 'icons/obj/canvas.dmi'
	icon_state = "easel"
	density = TRUE
	build_amt = 5
	var/obj/item/canvas/painting = null

/obj/structure/easel/Initialize(ml, _mat, _reinf_mat)
	. = ..()
	RegisterSignal(src, COMSIG_MOVABLE_MOVED, PROC_REF(move_painting))
	material = SSmaterials.get_material_by_name(MATERIAL_WOOD)

/obj/structure/easel/Destroy()
	painting = null
	UnregisterSignal(src, COMSIG_MOVABLE_MOVED)
	return ..()

/*
 * Adding canvases.
 */
/obj/structure/easel/attackby(obj/item/attacking_item, mob/user, params)
	if(istype(attacking_item, /obj/item/canvas))
		var/obj/item/canvas/C = attacking_item
		if(user.unEquip(C))
			painting = C
			C.forceMove(get_turf(src))
			C.layer = layer + 0.1
			C.pixel_x = 0
			C.pixel_y = 0
			C.pixel_z = 0
			user.visible_message("<b>[user]</b> puts \the [C] on \the [src].", SPAN_NOTICE("You place \the [C] on \the [src]."))
		return TRUE
	if(attacking_item.iswrench())
		to_chat(user, SPAN_NOTICE("You dismantle \the [src]."))
		dismantle()
		return TRUE
	return ..()

/*
 * Stick to the easel like glue.
 */
/obj/structure/easel/proc/move_painting()
	if(painting && Adjacent(painting)) // Only move if it's near us.
		painting.forceMove(get_turf(src))
	else
		painting = null
