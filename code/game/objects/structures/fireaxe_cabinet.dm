/obj/structure/fireaxecabinet
	name = "fire axe cabinet"
	desc = "A fire axe cabinet. There is small label that reads \"FOR EMERGENCY USE ONLY\" along with details for safe use of the axe on the side of it. As if."
	icon = 'icons/obj/wallmounts.dmi'
	icon_state = "fireaxe"
	anchored = TRUE
	density = FALSE
	req_access = null
	obj_flags = OBJ_FLAG_MOVES_UNSUPPORTED

	var/damage_threshold = 10 // Damage needed to break the glass.
	var/open
	var/unlocked
	var/shattered
	var/obj/item/material/twohanded/fireaxe/fireaxe

/obj/structure/fireaxecabinet/north
	dir = NORTH
	pixel_y = 24

/obj/structure/fireaxecabinet/east
	dir = EAST
	pixel_x = 19

/obj/structure/fireaxecabinet/west
	dir = WEST
	pixel_x = -19

/obj/structure/fireaxecabinet/south
	dir = SOUTH
	pixel_y = -20

/obj/structure/fireaxecabinet/attack_generic(var/mob/user, var/damage, var/attack_verb, var/wallbreaker)
	user.do_attack_animation(src)
	playsound(user, 'sound/effects/glass_hit.ogg', 50, 1)
	visible_message(SPAN_WARNING("\The [user] [attack_verb] \the [src]!"))
	if(damage_threshold >= damage)
		to_chat(user, SPAN_WARNING("Your strike is deflected by the reinforced glass!"))
		return
	if(shattered)
		return
	shattered = TRUE
	unlocked = TRUE
	open = TRUE
	playsound(user, /singleton/sound_category/glass_break_sound, 100, 1)
	update_icon()

/obj/structure/fireaxecabinet/update_icon()
	ClearOverlays()
	if(fireaxe)
		AddOverlays("axe")
	if(shattered)
		AddOverlays("glass4")
	if(unlocked)
		AddOverlays("unlocked")
	else
		AddOverlays("locked")
	if(open)
		AddOverlays("glass_raised")
	else
		AddOverlays("glass")


/obj/structure/fireaxecabinet/New()
	..()
	fireaxe = new(src)
	update_icon()

/obj/structure/fireaxecabinet/Initialize(mapload)
	. = ..()

	if(!mapload)
		set_pixel_offsets()

/obj/structure/fireaxecabinet/set_pixel_offsets()
	pixel_x = ((src.dir & (NORTH|SOUTH)) ? 0 : (src.dir == EAST ? 19 : -(19)))
	pixel_y = ((src.dir & (NORTH|SOUTH)) ? (src.dir == NORTH ? 24 : -(20)) : 0)

/obj/structure/fireaxecabinet/attack_ai(var/mob/user)
	if(!ai_can_interact(user))
		return
	toggle_lock(user)

/obj/structure/fireaxecabinet/attack_hand(var/mob/user)
	if(!unlocked)
		to_chat(user, SPAN_NOTICE("\The [src] is locked."))
		return
	toggle_open(user)

/obj/structure/fireaxecabinet/mouse_drop_dragged(atom/over, mob/user, src_location, over_location, params)
	if(over == user)
		var/mob/mob_dropped_over = over
		if(!istype(mob_dropped_over))
			return

		if(!open)
			to_chat(mob_dropped_over, SPAN_NOTICE("\The [src] is closed."))
			return

		if(!fireaxe)
			to_chat(mob_dropped_over, SPAN_NOTICE("\The [src] is empty."))
			return

		fireaxe.forceMove(get_turf(mob_dropped_over))
		mob_dropped_over.put_in_hands(fireaxe)
		fireaxe = null
		update_icon()

	return

/obj/structure/fireaxecabinet/Destroy()
	if(fireaxe)
		fireaxe.forceMove(get_turf(src))
		fireaxe = null
	return ..()

/obj/structure/fireaxecabinet/attackby(obj/item/attacking_item, mob/user)
	if(attacking_item.ismultitool())
		toggle_lock(user)
		return

	if(istype(attacking_item, /obj/item/material/twohanded/fireaxe))
		if(open)
			if(fireaxe)
				to_chat(user, SPAN_ALERT("There is already \a [fireaxe] inside \the [src]."))
			else if(user.unEquip(attacking_item))
				attacking_item.forceMove(src)
				fireaxe = attacking_item
				to_chat(user, SPAN_NOTICE("You place \the [fireaxe] into \the [src]."))
				update_icon()
			return

	if(attacking_item.force)
		user.setClickCooldown(10)
		attack_generic(user, attacking_item.force, "bashes")
		return

	return ..()

/obj/structure/fireaxecabinet/proc/toggle_open(var/mob/user)
	if(shattered)
		open = TRUE
		unlocked = TRUE
	else
		user.setClickCooldown(10)
		open = !open
		to_chat(user, SPAN_NOTICE("You [open ? "open" : "close"] \the [src]."))
	update_icon()

/obj/structure/fireaxecabinet/proc/toggle_lock(var/mob/user)
	if(open)
		return

	if(shattered)
		open = TRUE
		unlocked = TRUE
	else
		user.setClickCooldown(10)
		to_chat(user, SPAN_NOTICE("You begin [unlocked ? "enabling" : "disabling"] \the [src]'s maglock."))

		if(!do_after(user, 20))
			return

		if(shattered)
			return

		unlocked = !unlocked
		to_chat(user, SPAN_NOTICE("You [unlocked ? "disable" : "enable"] the maglock."))

	update_icon()
