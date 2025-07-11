// Human caches have been moved to SSicon_cache.

	///////////////////////
	//UPDATE_ICONS SYSTEM//
	///////////////////////
/*
Calling this a system is perhaps a bit trumped up. It is essentially update_clothing dismantled into its
core parts. The key difference is that when we generate overlays we do not generate either lying or standing
versions. Instead, we generate one set of "raw" (non-overlay-list friendly) overlays which are further processed
by SSoverlays when update_icon() runs. A single entry may be an /icon, an /image, or a /list of the former two.

	var/overlays_raw[26]

This system involves a bit more list churn than the old (bay) system, but should involve significantly less appearance
churn, plus has the benefit of reducing the number of overlays-with-overlays (compound overlays).
We also can put raw /icon instances directly in the list this way and SSoverlays will automatically convert them into
a more client-friendly format.

In the old system, we updated all our overlays every life() call, even if we were standing still inside a crate!
or dead!. 25ish overlays, all generated from scratch every second for every xeno/human/monkey and then applied.
More often than not update_clothing was being called a few times in addition to that! CPU was not the only issue,
all those icons had to be sent to every client. So really the cost was extremely cumulative. To the point where
update_clothing would frequently appear in the top 10 most CPU intensive procs during profiling.

Like the bay system, our list is indexed. This means we can update specific overlays!
So we only regenerate icons when we need them to be updated!
Also like bay, we use transforms to handle lying states instead of a separate set of icons.

There are several things that need to be remembered:

>	Whenever we do something that should cause an overlay to update (which doesn't use standard procs)
	( i.e. you do something like l_hand = /obj/item/something new(src) )
	You will need to call the relevant update_inv_* proc:
		update_inv_head()
		update_inv_wear_suit()
		update_inv_gloves()
		update_inv_shoes()
		update_inv_w_uniform()
		update_inv_glasses()
		update_inv_l_hand()
		update_inv_r_hand()
		update_inv_belt()
		update_inv_wear_id()
		update_inv_l_ear()
		update_inv_r_ear()
		update_inv_s_store()
		update_inv_pockets()
		update_inv_back()
		update_inv_handcuffed()
		update_inv_wear_mask()

	All of these are named after the variable they update from. They are defined at the mob/ level like
	update_clothing was, so you won't cause undefined proc runtimes with usr.update_inv_wear_id() if the usr is a
	slime etc. Instead, it'll just return without doing any work. So no harm in calling it for slimes and such.


>	There are also these special cases:
		update_mutations()	//handles updating your appearance for certain mutations.  e.g TK head-glows
		UpdateDamageIcon()	//handles damage overlays for brute/burn damage //(will rename this when I geta round to it)
		update_body()	//Handles updating your mob's icon to reflect their gender/race/complexion etc
		update_hair()	//Handles updating your hair overlay (used to be update_face, but mouth and
																			...eyes were merged into update_body)
		update_targeted() // Updates the target overlay when someone points a gun at you

>	All of these procs update overlays_raw, and then call update_icon() by default.
	If you wish to update several overlays at once, you can set the argument to 0 to disable the update and call
	it manually:
		e.g.
		update_inv_head(0)
		update_inv_l_hand(0)
		update_inv_r_hand()		//<---calls update_icon()

	or equivalently:
		update_inv_head(0)
		update_inv_l_hand(0)
		update_inv_r_hand(0)
		update_icon()

>	If you need to update all overlays you can use regenerate_icons(). it works exactly like update_clothing used to.

>	I reimplemented an old unused variable which was in the code called (coincidentally) var/update_icon
	It can be used as another method of triggering regenerate_icons(). It's basically a flag that when set to non-zero
	will call regenerate_icons() at the next life() call and then reset itself to 0.
	The idea behind it is icons are regenerated only once, even if multiple events requested it.
*/



#define GET_BODY_TYPE (cached_bodytype || (cached_bodytype = species.get_bodytype()))
#define GET_TAIL_LAYER (dir == NORTH ? TAIL_NORTH_LAYER : TAIL_SOUTH_LAYER)
#define GET_TAIL_ACC_LAYER (dir == NORTH ? TAIL_NORTH_ACC_LAYER : TAIL_SOUTH_ACC_LAYER)

/proc/overlay_image(icon, icon_state,color, flags, plane, layer)
	var/image/ret = image(icon,icon_state)
	ret.color = color
	ret.appearance_flags = PIXEL_SCALE | flags
	if(plane)
		ret.plane = plane
	if(layer)
		ret.layer = layer
	return ret

/mob/living/carbon/human
	var/list/overlays_raw[TOTAL_LAYERS] // Our set of "raw" overlays that can be modified, but cannot be directly applied to the mob without preprocessing.
	var/previous_damage_appearance // store what the body last looked like, so we only have to update it if something changed

#define UPDATE_ICON_IGNORE_DIRECTION_UPDATE -1

// Updates overlays from overlays_raw.
/mob/living/carbon/human/update_icon(var/forceDirUpdate = FALSE)
	if (QDELETED(src))
		return	// No point.

	update_hud()		//TODO: remove the need for this
	ClearOverlays()

	if(cloaked)
		icon = 'icons/mob/human.dmi'
		icon_state = "body_cloaked"
		AddOverlays(list(overlays_raw[L_HAND_LAYER], overlays_raw[R_HAND_LAYER]))

	else if (icon_update)
		if (icon != stand_icon)
			icon = stand_icon

		var/list/ovr = list()
		// We manually add each element instead of just using Copy() so that lists are appended instead of inserted.
		for (var/item in overlays_raw)
			if (item)
				ovr += item

		if(species.has_floating_eyes)
			ovr += species.get_eyes(src)

		for(var/aura in auras)
			var/obj/aura/A = aura
			var/icon/aura_overlay = icon(A.icon, icon_state = A.icon_state)
			ovr += aura_overlay

		AddOverlays(ovr)

	if (((lying_prev != lying) || forceDirUpdate || size_multiplier != 1) && forceDirUpdate != UPDATE_ICON_IGNORE_DIRECTION_UPDATE)
		if(lying && !species.prone_icon) //Only rotate them if we're not drawing a specific icon for being prone.
			var/matrix/M = matrix()

			switch(src.dir)
				if(SOUTH,EAST)
					M.Turn(90)
				else
					M.Turn(-90)
			M.Scale(size_multiplier)
			M.Translate(1,-6)
			animate(src, transform = M, time = (forceDirUpdate ? 0 : ANIM_LYING_TIME))

			if(istype(src.l_hand, /obj/item/gun) && lying)
				HeldObjectDirTransform(slot_l_hand, src.dir)
			if(istype(src.r_hand, /obj/item/gun) && lying)
				HeldObjectDirTransform(slot_r_hand, src.dir)

		else
			update_inv_l_hand(FALSE)
			update_inv_r_hand(FALSE)
			update_icon(UPDATE_ICON_IGNORE_DIRECTION_UPDATE)
			var/matrix/M = matrix()
			M.Scale(size_multiplier)
			M.Translate(0, 16*(size_multiplier-1))
			animate(src, transform = M, time = ANIM_LYING_TIME)

	UpdateOverlays()
	lying_prev = lying

/mob/living/carbon/human/proc/HeldObjectDirTransform(var/hand = slot_l_hand, var/direction)
	var/layer = null
	if(hand == slot_r_hand)
		update_inv_r_hand(FALSE)
		layer = R_HAND_LAYER
	else
		update_inv_l_hand(FALSE)
		layer = L_HAND_LAYER

	switch(direction)
		if(EAST)
			TransformLayerIcon(layer, -90)
		if(WEST)
			TransformLayerIcon(layer, 90)
		if(NORTH)
			TransformLayerIcon(layer, 0)
		if(SOUTH)
			TransformLayerIcon(layer, 180)


/mob/living/carbon/human/proc/TransformLayerIcon(var/layer, var/rotation = 0)
	var/image/item_image = overlays_raw[layer]
	var/matrix/item_transform = matrix()
	item_transform.Turn(rotation)

	animate(item_image, transform = item_transform)
	overlays_raw[layer] = item_image
	update_icon(UPDATE_ICON_IGNORE_DIRECTION_UPDATE)

#undef UPDATE_ICON_IGNORE_DIRECTION_UPDATE

//DAMAGE OVERLAYS
//constructs damage icon for each organ from mask * damage field and saves it in our overlays_raw list (as a list of icons).
/mob/living/carbon/human/UpdateDamageIcon(var/update_icons = 1)
	// first check whether something actually changed about damage appearance
	var/damage_appearance = ""

	for(var/obj/item/organ/external/O in organs)
		if(QDELETED(O) || O.is_stump())
			continue
		//if(O.status & ORGAN_DESTROYED) damage_appearance += "d" //what is this?
		//else
		//	damage_appearance += O.damage_state
		damage_appearance += O.damage_state

	if(damage_appearance == previous_damage_appearance)
		// nothing to do here
		return

	previous_damage_appearance = damage_appearance

	// The overlays we're going to add to the mob.
	var/list/ovr

	// blend the individual damage states with our icons
	for(var/obj/item/organ/external/O in organs)
		if(QDELETED(O) || O.is_stump())
			continue

		O.update_icon()
		if(O.damage_state == "00") continue
		var/cache_index = "[O.damage_state]/[O.icon_name]/[get_blood_color()]/[GET_BODY_TYPE]"
		var/list/damage_icon_parts = SSicon_cache.damage_icon_parts
		var/icon/DI = damage_icon_parts[cache_index]
		if(!DI)
			DI = new /icon(species.damage_overlays, O.damage_state)			// the damage icon for whole human
			DI.Blend(new /icon(species.damage_mask, O.icon_name), ICON_MULTIPLY)	// mask with this organ's pixels
			DI.Blend(get_blood_color(), ICON_MULTIPLY)
			damage_icon_parts[cache_index] = DI

		LAZYADD(ovr, DI)

	overlays_raw[MOB_DAMAGE_LAYER] = ovr
	update_bandages(update_icons)
	if(update_icons)
		update_icon()

/// Handles displaying bandages on the mob icon, and whether the mob should have the add/remove bandages verb attached to it
/mob/living/carbon/human/proc/update_bandages(var/update_icons = TRUE)
	var/bandage_icon = species.bandages_icon
	if(!bandage_icon)
		return

	var/list/ovr
	for(var/obj/item/organ/external/O in organs)
		if(O.is_stump())
			continue
		var/bandage_level = O.bandage_level
		if(bandage_level)
			LAZYADD(ovr, image(bandage_icon, "[O.icon_name][bandage_level]"))

	// this next part handles whether the mob should have the Remove Bandages verb available
	// obviously this is a little hacky, since this is the icon update function, but it's also the best place we loop through
	// the various organs and calculate their bandage level
	var/had_bandages = LAZYLEN(overlays_raw[BANDAGE_LAYER])
	var/has_bandages = LAZYLEN(ovr)

	// gained bandages
	if(!had_bandages && has_bandages)
		add_verb(src, /mob/living/carbon/human/proc/remove_bandages)
	// lost bandages
	else if(had_bandages && !has_bandages)
		remove_verb(src, /mob/living/carbon/human/proc/remove_bandages)

	overlays_raw[BANDAGE_LAYER] = ovr
	if(update_icons)
		update_icon()

//Overlays for the worn overlay so you can overlay while you overlay
//eg: ammo counters, primed grenade flashing, etc.
//"icon_file" is used automatically for inhands etc. to make sure it gets the correct inhand file
/obj/item/proc/worn_overlays(icon_file)
	. = list()
	var/mutable_appearance/M = null
	if(build_from_parts)
		M = mutable_appearance(icon_file, "[item_state]_[worn_overlay]")
		M.appearance_flags = RESET_COLOR|RESET_ALPHA
		if(worn_overlay_color)
			M.color = worn_overlay_color
		. += M

/proc/slot_str_to_contained_flag(var/slot_str)
	switch(slot_str)
		if(slot_back_str)
			return WORN_BACK
		if(slot_l_hand_str)
			return WORN_LHAND
		if(slot_r_hand_str)
			return WORN_RHAND
		if(slot_wear_id_str)
			return WORN_ID
		if(slot_w_uniform_str)
			return WORN_UNDER
		if(slot_head_str)
			return WORN_HEAD
		if(slot_glasses_str)
			return WORN_EYES
		if(slot_wear_mask_str)
			return WORN_MASK
		if(slot_belt_str)
			return WORN_BELT
		if(slot_wear_suit_str)
			return WORN_SUIT
		if(slot_l_ear_str)
			return WORN_LEAR
		if(slot_r_ear_str)
			return WORN_REAR
		if(slot_shoes_str)
			return WORN_SHOES
		if(slot_wrists_str)
			return WORN_WRISTS
		if(slot_gloves_str)
			return WORN_GLOVES
	return ""

//BASE MOB SPRITE
/mob/living/carbon/human/proc/update_body(var/update_icons=1, var/force_base_icon = FALSE)
	if (QDELETED(src))
		return

	var/husk_color_mod = rgb(96,88,80)

	var/husk = (mutations & HUSK)
	var/fat = (mutations & FAT)
	var/skeleton = (mutations & SKELETON)
	var/g = (gender == FEMALE ? "f" : "m")

	pixel_x = species.icon_x_offset
	pixel_y = species.icon_y_offset

	//CACHING: Generate an index key from visible bodyparts.
	//0 = destroyed, 1 = normal, 2 = robotic, 3 = necrotic.

	//Create a new, blank icon for our mob to use.
	if(stand_icon)
		qdel(stand_icon)
	stand_icon = new(species.icon_template ? species.icon_template : 'icons/mob/human.dmi',"blank")

	var/is_frenzied = "nofrenzy"
	if(mind)
		var/datum/vampire/vampire = mind.antag_datums[MODE_VAMPIRE]
		if(vampire && (vampire.status & VAMP_FRENZIED))
			is_frenzied = "frenzy"
	var/icon_key = "[species.race_key][g][s_tone][r_skin][g_skin][b_skin][lipstick_color || "nolips"][!!husk][!!fat][!!skeleton][is_frenzied]"
	var/obj/item/organ/internal/eyes/eyes = get_eyes()
	if(eyes)
		icon_key += "[rgb(eyes.eye_colour[1], eyes.eye_colour[2], eyes.eye_colour[3])]"
	else
		icon_key += "#000000"

	for(var/organ_tag in species.has_limbs)
		var/obj/item/organ/external/part = organs_by_name[organ_tag]
		if (!part)
			continue

		icon_key += SSicon_cache.get_organ_shortcode(part)

	var/icon/base_icon = SSicon_cache.human_icon_cache[icon_key]
	if (!base_icon || force_base_icon)	// Icon ain't in the cache, so generate it.
		//BEGIN CACHED ICON GENERATION.
		var/obj/item/organ/external/chest = get_organ(BP_CHEST)
		base_icon = chest.get_icon(skeleton)

		for(var/obj/item/organ/external/part in organs)
			if(isnull(part) || part.is_stump())
				continue
			var/icon/temp = part.get_icon(skeleton)//The color comes from this function
			//That part makes left and right legs drawn topmost and lowermost when human looks WEST or EAST
			//And no change in rendering for other parts (they icon_position is 0, so goes to 'else' part)
			if(part.icon_position&(LEFT|RIGHT))
				var/icon/temp2 = new('icons/mob/human.dmi',"blank")
				temp2.Insert(new /icon(temp ,dir = NORTH), dir = NORTH)
				temp2.Insert(new /icon(temp, dir = SOUTH), dir = SOUTH)
				if(!(part.icon_position & LEFT))
					temp2.Insert(new /icon(temp, dir = EAST), dir = EAST)
				if(!(part.icon_position & RIGHT))
					temp2.Insert(new /icon(temp, dir = WEST), dir = WEST)
				base_icon.Blend(temp2, ICON_OVERLAY)
				if(part.icon_position & LEFT)
					temp2.Insert(new /icon(temp, dir = EAST), dir = EAST)
				if(part.icon_position & RIGHT)
					temp2.Insert(new /icon(temp, dir = WEST), dir = WEST)
				base_icon.Blend(temp2, ICON_UNDERLAY)
			else
				base_icon.Blend(temp, ICON_OVERLAY)

		if(!(species.flags & NO_SCAN))
			if(husk)
				base_icon.ColorTone(husk_color_mod)

		//Handle husk overlay.
		if(husk && ("overlay_husk" in icon_states(species.icobase)))
			var/icon/mask = new(base_icon)
			var/icon/husk_over = new(species.icobase,"overlay_husk")
			mask.MapColors(0,0,0,1, 0,0,0,1, 0,0,0,1, 0,0,0,1, 0,0,0,0)
			husk_over.Blend(mask, ICON_ADD)
			base_icon.Blend(husk_over, ICON_OVERLAY)

		SSicon_cache.human_icon_cache[icon_key] = base_icon

	for(var/obj/item/organ/external/part in organs)
		part.cut_additional_images(src)
		var/list/add_images = part.get_additional_images(src)
		if(add_images)
			AddOverlays(add_images, ATOM_ICON_CACHE_PROTECTED)
	UpdateOverlays()

	//END CACHED ICON GENERATION.
	stand_icon.Blend(base_icon,ICON_OVERLAY)

	//tail
	update_tail_showing(0)

	if(update_icons)
		update_icon()

/mob/living/carbon/human/proc/update_underwear(update_icons = TRUE)
	overlays_raw[UNDERWEAR_LAYER] = list()

	if(species.appearance_flags & HAS_UNDERWEAR)
		for(var/category in all_underwear)
			if(hide_underwear[category])
				continue
			if(category == "Underwear, top" && hide_underwear["Undershirt"] == FALSE && !istype(all_underwear["Undershirt"], /datum/category_item/underwear/undershirt/none))
				continue //This piece of "code" is here to prevent tops from showing up over undershirts.
			var/datum/category_item/underwear/UWI = all_underwear[category]
			overlays_raw[UNDERWEAR_LAYER] += UWI.generate_image(all_underwear_metadata[category])

	if(update_icons)
		update_icon()

// This proc generates & returns an icon representing a human's hair, using a cached icon from SSicon_cache if possible.
// If `hair_is_visible` is FALSE, only facial hair will be drawn.
/mob/living/carbon/human/proc/generate_hair_icon(hair_is_visible = TRUE)
	var/cache_key = "[f_style ? "[f_style][r_facial][g_facial][b_facial]" : "nofacial"]_[(h_style && hair_is_visible) ? "[h_style][r_hair][g_hair][b_hair]" : "nohair"]_[(g_style && g_style != "None" && hair_is_visible) ? "[g_style][r_grad][g_grad][b_grad]" : "nograd"]"

	var/icon/face_standing = SSicon_cache.human_hair_cache[cache_key]
	if (!face_standing)	// Not cached, generate it from scratch.
		face_standing = new /icon(species.canvas_icon, "blank")

		// Beard.
		if(f_style)
			var/datum/sprite_accessory/facial_hair_style = GLOB.facial_hair_styles_list[f_style]
			if(facial_hair_style && facial_hair_style.species_allowed && (species.type in facial_hair_style.species_allowed))
				var/icon/facial_s = new/icon("icon" = facial_hair_style.icon, "icon_state" = facial_hair_style.icon_state)
				if(facial_hair_style.do_colouration)
					facial_s.Blend(rgb(r_facial, g_facial, b_facial), facial_hair_style.icon_blend_mode)

				face_standing.Blend(facial_s, ICON_OVERLAY)

		// Hair.
		if(hair_is_visible)
			var/icon/grad_s = null
			var/datum/sprite_accessory/hair_style = GLOB.hair_styles_list[h_style]
			if(hair_style && (species.type in hair_style.species_allowed))
				var/icon/hair_s = new/icon("icon" = hair_style.icon, "icon_state" = hair_style.icon_state)
				if(hair_style.do_colouration)
					if(g_style)
						var/datum/sprite_accessory/gradient_style = GLOB.hair_gradient_styles_list[g_style]
						if(gradient_style && gradient_style.species_allowed && (species.type in gradient_style.species_allowed))
							grad_s = new/icon("icon" = gradient_style.icon, "icon_state" = gradient_style.icon_state)
							grad_s.Blend(hair_s, ICON_AND)
							grad_s.Blend(rgb(r_grad, g_grad, b_grad), ICON_MULTIPLY)
					hair_s.Blend(rgb(r_hair, g_hair, b_hair), hair_style.icon_blend_mode)
					if(!isnull(grad_s))
						var/icon/grad_s_final = new/icon("icon" = hair_style.icon, "icon_state" = hair_style.icon_state)
						grad_s_final.Blend(grad_s, hair_style.icon_blend_mode)
						hair_s.Blend(grad_s_final, ICON_OVERLAY)

				face_standing.Blend(hair_s, ICON_OVERLAY)

		// Add it to the cache.
		SSicon_cache.human_hair_cache[cache_key] = face_standing

	return face_standing

//HAIR OVERLAY
/mob/living/carbon/human/proc/update_hair(var/update_icons=1)
	if (QDELETED(src))
		return

	//Reset our hair
	overlays_raw[HAIR_LAYER] = null
	overlays_raw[HAIR_LAYER_ALT] = null
	overlays_raw[HAIR_LAYER_EMISSIVE] = null
	overlays_raw[HAIR_LAYER_ALT_EMISSIVE] = null

	var/obj/item/organ/external/head/head_organ = get_organ(BP_HEAD)
	if(!head_organ || head_organ.is_stump() )
		if(update_icons)   update_icon()
		return

	//masks and helmets can obscure our hair.
	if( (head && (head.flags_inv & BLOCKHAIR)) || (wear_mask && (wear_mask.flags_inv & BLOCKHAIR)) || (l_ear && (l_ear.flags_inv & BLOCKHAIR)) || (r_ear && (r_ear.flags_inv & BLOCKHAIR)))
		if(update_icons)   update_icon()
		return

	var/has_visible_hair = h_style && !(head && (head.flags_inv & BLOCKHEADHAIR)) && !(l_ear && (l_ear.flags_inv & BLOCKHEADHAIR)) && !(r_ear && (r_ear.flags_inv & BLOCKHEADHAIR)) && !(wear_suit && (wear_suit.flags_inv & BLOCKHEADHAIR))

	var/icon/hair_icon = generate_hair_icon(has_visible_hair)

	// Handle light emission.
	if (species.light_range)
		if (has_visible_hair)
			var/datum/sprite_accessory/hair_style = GLOB.hair_styles_list[h_style]
			if (hair_style)
				var/col = species.get_light_color(src) || "#FFFFFF"
				set_light(species.light_range, species.light_power, col, uv = 0, angle = LIGHT_WIDE)
		else
			set_light(0)

	var/hair_layer = species.use_alt_hair_layer ? HAIR_LAYER_ALT : HAIR_LAYER
	overlays_raw[hair_layer] = hair_icon

	if(has_visible_hair)
		var/datum/sprite_accessory/hair_style = GLOB.hair_styles_list[h_style]
		if(hair_style)
			var/hair_emissive_layer = species.use_alt_hair_layer ? HAIR_LAYER_ALT_EMISSIVE : HAIR_LAYER_EMISSIVE
			overlays_raw[hair_emissive_layer] = emissive_blocker(hair_icon, hair_style.icon_state, MOB_SHADOW_UPPER_LAYER)

	if(update_icons)
		update_icon()

/mob/living/carbon/human/update_mutations(var/update_icons=1)
	if (QDELETED(src))
		return

	var/fat
	if((mutations & FAT))
		fat = "fat"

	var/image/standing	= image("icon" = 'icons/effects/genetics.dmi')
	var/add_image = 0
	var/g = "m"
	if(gender == FEMALE)	g = "f"
	// DNA2 - Drawing underlays.
	for(var/datum/dna/gene/gene in dna_genes)
		if(!gene.block)
			continue
		if(gene.is_active(src))
			var/underlay=gene.OnDrawUnderlays(src,g,fat)
			if(underlay)
				standing.underlays += underlay
				add_image = 1
	if((mutations & LASER_EYES))
		standing.overlays += "lasereyes_s"
		add_image = 1
	if(add_image)
		overlays_raw[MUTATIONS_LAYER] = standing
	else
		overlays_raw[MUTATIONS_LAYER] = null
	if(update_icons)
		update_icon()

/* --------------------------------------- */
//For legacy support.
/mob/living/carbon/human/regenerate_icons()
	..()

	if(QDELETED(src))
		return


	if(transforming)
		return

	update_mutations(FALSE)
	update_body(FALSE)
	update_hair(FALSE)
	update_inv_w_uniform(FALSE)
	update_inv_wear_id(FALSE)
	update_inv_gloves(FALSE)
	update_inv_glasses(FALSE)
	update_inv_l_ear(FALSE)
	update_inv_r_ear(FALSE)
	update_inv_shoes(FALSE)
	update_inv_s_store(FALSE)
	update_inv_wear_mask(FALSE)
	update_inv_head(FALSE)
	update_inv_belt(FALSE)
	update_inv_back(FALSE)
	update_inv_wear_suit(FALSE)
	update_inv_r_hand(FALSE)
	update_inv_l_hand(FALSE)
	update_inv_handcuffed(FALSE)
	update_inv_legcuffed(FALSE)
	update_inv_pockets(FALSE)
	update_fire(FALSE)
	update_surgery(FALSE)
	update_underwear(FALSE)
	update_inv_wrists(FALSE)
	UpdateDamageIcon()
	update_icon()
	//Hud Stuff
	update_hud()

/* --------------------------------------- */
//vvvvvv UPDATE_INV PROCS vvvvvv

/mob/living/carbon/human/update_inv_w_uniform(var/update_icons=1)
	if (QDELETED(src))
		return

	if(check_draw_underclothing())
		var/mob_icon
		var/mob_state = ""

		if(w_uniform.contained_sprite)//Do all the containedsprite stuff in one place
			w_uniform.auto_adapt_species(src)
			if(w_uniform.icon_override)
				mob_icon = w_uniform.icon_override
			else if(w_uniform.sprite_sheets && w_uniform.sprite_sheets[GET_BODY_TYPE])
				mob_icon = w_uniform.sprite_sheets[GET_BODY_TYPE]
			else
				mob_icon = w_uniform.icon

			if (w_uniform.icon_species_tag)
				mob_state += "[w_uniform.icon_species_tag]_"
			mob_state += w_uniform.item_state + WORN_UNDER

		else if(w_uniform.icon_override)
			mob_icon = w_uniform.icon_override
		else if(w_uniform.sprite_sheets && w_uniform.sprite_sheets[GET_BODY_TYPE])
			mob_icon = w_uniform.sprite_sheets[GET_BODY_TYPE]
		else if(w_uniform.item_icons && w_uniform.item_icons[slot_w_uniform_str])
			mob_icon = w_uniform.item_icons[slot_w_uniform_str]
		else
			mob_icon = INV_W_UNIFORM_DEF_ICON

		//determine state to use
		if (!mob_state)
			if(w_uniform.item_state_slots && w_uniform.item_state_slots[slot_w_uniform_str])
				mob_state = w_uniform.item_state_slots[slot_w_uniform_str] + "_s"
			else if(w_uniform.item_state)
				mob_state = w_uniform.item_state + "_s"
			else
				mob_state = w_uniform.icon_state + "_s"

		overlays_raw[UNIFORM_LAYER] = w_uniform.get_mob_overlay(src, mob_icon, mob_state, slot_w_uniform_str)
	else
		overlays_raw[UNIFORM_LAYER] = null

	if(update_icons)
		update_icon()

/mob/living/carbon/human/update_inv_wear_id(var/update_icons=1)
	if (QDELETED(src))
		return

	overlays_raw[ID_LAYER] = null
	overlays_raw[ID_LAYER_ALT] = null
	if(wear_id)
		if(istype(w_uniform, /obj/item/clothing/under))
			var/obj/item/clothing/under/uniform = w_uniform
			if(!uniform.displays_id)
				return

		var/mob_icon
		var/mob_state
		if(wear_id.contained_sprite)
			wear_id.auto_adapt_species(src)
			if(!(wear_id.overlay_state)) //legacy check
				wear_id.overlay_state = wear_id.item_state
			mob_icon = (wear_id.icon_override || wear_id.icon)
			mob_state = "[wear_id.overlay_state][WORN_ID]"
		else
			mob_icon = 'icons/mob/card.dmi'
			mob_state = wear_id.overlay_state

		//Layering under/over suit
		var/id_layer = ID_LAYER
		if(istype(wear_id, /obj/item/storage/wallet/lanyard))
			var/obj/item/storage/wallet/lanyard/lanyard = wear_id
			if(lanyard.wear_over_suit)
				id_layer = ID_LAYER_ALT
		else if(istype(wear_id, /obj/item/card/id))
			var/obj/item/card/id/id_card = wear_id
			if(id_card.wear_over_suit)
				id_layer = ID_LAYER_ALT

		overlays_raw[id_layer] = wear_id.get_mob_overlay(src, mob_icon, mob_state, slot_wear_id_str)

	BITSET(hud_updateflag, ID_HUD)
	BITSET(hud_updateflag, WANTED_HUD)

	if(update_icons)
		update_icon()

/mob/living/carbon/human/update_inv_gloves(var/update_icons=1)
	if (QDELETED(src))
		return


	if(check_draw_gloves())
		var/mob_icon
		var/mob_state = gloves.item_state || gloves.icon_state

		if(gloves.contained_sprite)
			if(gloves.icon_override)
				mob_icon = gloves.icon_override
			else if(gloves.sprite_sheets && gloves.sprite_sheets[GET_BODY_TYPE])
				mob_icon = gloves.sprite_sheets[GET_BODY_TYPE]
			else
				mob_icon = gloves.icon
			gloves.auto_adapt_species(src)
			mob_state = "[UNDERSCORE_OR_NULL(gloves.icon_species_tag)][gloves.item_state][WORN_GLOVES]"
		else if(gloves.icon_override)
			mob_icon = gloves.icon_override
		else if(gloves.sprite_sheets && gloves.sprite_sheets[GET_BODY_TYPE])
			mob_icon = gloves.sprite_sheets[GET_BODY_TYPE]
		else
			mob_icon = 'icons/mob/hands.dmi'

		overlays_raw[GLOVES_LAYER] = gloves.get_mob_overlay(src, mob_icon, mob_state, slot_gloves_str)
	else if(blood_DNA)
		var/image/bloodsies = image(species.blood_mask, "bloodyhands")
		bloodsies.color = hand_blood_color
		bloodsies.appearance_flags = RESET_ALPHA
		overlays_raw[GLOVES_LAYER] = bloodsies
	else
		overlays_raw[GLOVES_LAYER] = null

	if(update_icons)
		update_icon()

/mob/living/carbon/human/update_inv_glasses(var/update_icons=1)
	if (QDELETED(src))
		return

	if(check_draw_glasses())
		var/mob_icon
		var/mob_state = glasses.icon_state
		if(glasses.contained_sprite)
			if(glasses.icon_override)
				mob_icon = glasses.icon_override
			else if(glasses.sprite_sheets && glasses.sprite_sheets[GET_BODY_TYPE])
				mob_icon = glasses.sprite_sheets[GET_BODY_TYPE]
			else
				mob_icon = glasses.icon
			glasses.auto_adapt_species(src)
			mob_state = "[UNDERSCORE_OR_NULL(glasses.icon_species_tag)][glasses.item_state][WORN_EYES]"
		else if(glasses.icon_override)
			mob_icon = glasses.icon_override
		else if(glasses.sprite_sheets && glasses.sprite_sheets[GET_BODY_TYPE])
			mob_icon = glasses.sprite_sheets[GET_BODY_TYPE]
		else
			mob_icon = 'icons/mob/eyes.dmi'

		var/image/glasses_overlay = glasses.get_mob_overlay(src, mob_icon, mob_state, slot_glasses_str)

		var/normal_layer = GLASSES_LAYER
		if(istype(glasses, /obj/item/clothing/glasses))
			var/obj/item/clothing/glasses/G = glasses
			normal_layer = G.normal_layer

		overlays_raw[GLASSES_LAYER] = null
		overlays_raw[GLASSES_LAYER_ALT] = null
		overlays_raw[GLASSES_LAYER_OVER] = null
		overlays_raw[normal_layer] = glasses_overlay
	else
		overlays_raw[GLASSES_LAYER] = null
		overlays_raw[GLASSES_LAYER_ALT] = null
		overlays_raw[GLASSES_LAYER_OVER] = null

	if(update_icons)
		update_icon()

/mob/living/carbon/human/update_inv_l_ear(var/update_icons=1)
	if(QDELETED(src))
		return

	if(check_draw_left_ear())
		if(l_ear)
			var/mob_icon = INV_L_EAR_DEF_ICON
			var/mob_state = l_ear.icon_state

			if(l_ear.contained_sprite)
				if(l_ear.icon_override)
					mob_icon = l_ear.icon_override
				else if(l_ear.sprite_sheets && l_ear.sprite_sheets[GET_BODY_TYPE])
					mob_icon = l_ear.sprite_sheets[GET_BODY_TYPE]
				else
					mob_icon = l_ear.icon
				l_ear.auto_adapt_species(src)
				mob_state = "[UNDERSCORE_OR_NULL(l_ear.icon_species_tag)][l_ear.item_state][WORN_LEAR]"
			else if(l_ear.icon_override)
				mob_icon = l_ear.icon_override
			else if(l_ear.sprite_sheets && l_ear.sprite_sheets[GET_BODY_TYPE])
				mob_icon = l_ear.sprite_sheets[GET_BODY_TYPE]
			else if(l_ear.item_icons && (slot_l_ear_str in l_ear.item_icons))
				mob_icon = l_ear.item_icons[slot_l_ear_str]

			var/layer = L_EAR_LAYER
			var/layer_alt = L_EAR_LAYER_ALT
			var/obj/item/device/radio/headset/wrist/W = l_ear
			if(istype(W) && W.mob_wear_layer == ABOVE_SUIT_LAYER_WR)
				layer = L_EAR_LAYER_ALT
				layer_alt = L_EAR_LAYER

			overlays_raw[layer] = l_ear.get_mob_overlay(src, mob_icon, mob_state, slot_l_ear_str)
			overlays_raw[layer_alt] = null
	else
		overlays_raw[L_EAR_LAYER] = null
		overlays_raw[L_EAR_LAYER_ALT] = null

	if(update_icons)
		update_icon()

/mob/living/carbon/human/update_inv_r_ear(var/update_icons=1)
	if(QDELETED(src))
		return

	if(check_draw_right_ear())
		if(r_ear)
			var/mob_icon = INV_R_EAR_DEF_ICON
			var/mob_state = r_ear.icon_state

			if(r_ear.contained_sprite)
				if(r_ear.icon_override)
					mob_icon = r_ear.icon_override
				else if(r_ear.sprite_sheets && r_ear.sprite_sheets[GET_BODY_TYPE])
					mob_icon = r_ear.sprite_sheets[GET_BODY_TYPE]
				else
					mob_icon = r_ear.icon
				r_ear.auto_adapt_species(src)
				mob_state = "[UNDERSCORE_OR_NULL(r_ear.icon_species_tag)][r_ear.item_state][WORN_REAR]"
			else if(r_ear.icon_override)
				mob_icon = r_ear.icon_override
			else if(r_ear.sprite_sheets && r_ear.sprite_sheets[GET_BODY_TYPE])
				mob_icon = r_ear.sprite_sheets[GET_BODY_TYPE]
			else if(r_ear.item_icons && (slot_r_ear_str in r_ear.item_icons))
				mob_icon = r_ear.item_icons[slot_r_ear_str]

			var/layer = R_EAR_LAYER
			var/layer_alt = R_EAR_LAYER_ALT
			var/obj/item/device/radio/headset/wrist/W = r_ear
			if(istype(W) && W.mob_wear_layer == ABOVE_SUIT_LAYER_WR)
				layer = R_EAR_LAYER_ALT
				layer_alt = R_EAR_LAYER

			overlays_raw[layer] = r_ear.get_mob_overlay(src, mob_icon, mob_state, slot_r_ear_str)
			overlays_raw[layer_alt] = null
	else
		overlays_raw[R_EAR_LAYER] = null
		overlays_raw[R_EAR_LAYER_ALT] = null
	if(update_icons)
		update_icon()

/mob/living/carbon/human/update_inv_shoes(var/update_icons=1)
	if (QDELETED(src))
		return

	if(check_draw_shoes())
		var/mob_icon = INV_SHOES_DEF_ICON
		var/mob_state = shoes.icon_state

		if(shoes.contained_sprite)
			if(shoes.icon_override)
				mob_icon = shoes.icon_override
			if(shoes.sprite_sheets && shoes.sprite_sheets[GET_BODY_TYPE])
				mob_icon = shoes.sprite_sheets[GET_BODY_TYPE]
			else
				mob_icon = shoes.icon
			shoes.auto_adapt_species(src)
			mob_state = "[UNDERSCORE_OR_NULL(shoes.icon_species_tag)][shoes.item_state][WORN_SHOES]"
		else if(shoes.icon_override)
			mob_icon = shoes.icon_override
		else if(shoes.sprite_sheets && shoes.sprite_sheets[GET_BODY_TYPE])
			mob_icon = shoes.sprite_sheets[GET_BODY_TYPE]
		else if(shoes.item_icons && (slot_shoes_str in shoes.item_icons))
			mob_icon = shoes.item_icons[slot_shoes_str]
		else
			mob_icon = INV_SHOES_DEF_ICON

		//Shoe layer stuff from Polaris v1.0333a
		var/shoe_layer = SHOES_LAYER
		var/null_layer = SHOES_LAYER_ALT
		if(istype(shoes, /obj/item/clothing/shoes))
			var/obj/item/clothing/shoes/S = shoes
			if(S.shoes_under_pants == TRUE)
				shoe_layer = SHOES_LAYER_ALT
				null_layer = SHOES_LAYER

		overlays_raw[shoe_layer] = shoes.get_mob_overlay(src, mob_icon, mob_state, slot_shoes_str)
		overlays_raw[null_layer] = null
	else
		if(footprint_color)		// Handles bloody feet.
			var/image/result_layer
			for(var/limb_tag in list(BP_L_FOOT, BP_R_FOOT))
				var/obj/item/organ/external/E = get_organ(limb_tag)
				if(E && !E.is_stump())
					var/image/bloodsies = image(species.blood_mask, "shoeblood_[E.limb_name]")
					bloodsies.color = footprint_color
					bloodsies.appearance_flags = RESET_ALPHA
					if(!result_layer)
						result_layer = bloodsies
					else
						result_layer.overlays.Add(bloodsies)
			overlays_raw[SHOES_LAYER] = result_layer
			overlays_raw[SHOES_LAYER_ALT] = null
		else
			overlays_raw[SHOES_LAYER] = null
			overlays_raw[SHOES_LAYER_ALT] = null

	if(update_icons)
		update_icon()

/mob/living/carbon/human/update_inv_s_store(var/update_icons=1)
	if (QDELETED(src))
		return

	if(s_store)
		var/mob_icon = 'icons/mob/belt_mirror.dmi'
		var/mob_state = (s_store.item_state || s_store.icon_state)
		if(s_store.contained_sprite)
			if(s_store.icon_override)
				mob_icon = s_store.icon_override
			else if(s_store.sprite_sheets && s_store.sprite_sheets[GET_BODY_TYPE])
				mob_icon = s_store.sprite_sheets[GET_BODY_TYPE]
			else
				mob_icon = s_store.icon
			s_store.auto_adapt_species(src)
			mob_state = "[UNDERSCORE_OR_NULL(s_store.icon_species_tag)][s_store.item_state][WORN_SSTORE]"
		overlays_raw[SUIT_STORE_LAYER] = s_store.get_mob_overlay(src, mob_icon, mob_state, slot_s_store_str)
	else
		overlays_raw[SUIT_STORE_LAYER] = null

	if(update_icons)
		update_icon()

/mob/living/carbon/human/update_inv_head(update_icons = TRUE, recurse = TRUE)
	if (QDELETED(src))
		return

	overlays_raw[HEAD_LAYER] = null
	if(head)
		var/mob_icon = INV_HEAD_DEF_ICON
		var/mob_state = head.icon_state

		if(head.contained_sprite)
			if(head.icon_override)
				mob_icon = head.icon_override
			else if(head.sprite_sheets && head.sprite_sheets[GET_BODY_TYPE])
				mob_icon = head.sprite_sheets[GET_BODY_TYPE]
			else
				mob_icon = head.icon
			head.auto_adapt_species(src)
			mob_state = "[UNDERSCORE_OR_NULL(head.icon_species_tag)][head.item_state][WORN_HEAD]"
		else if(head.icon_override)
			mob_icon = head.icon_override
		else if(head.sprite_sheets && head.sprite_sheets[GET_BODY_TYPE])
			mob_icon = head.sprite_sheets[GET_BODY_TYPE]

		else if(head.item_icons && (slot_head_str in head.item_icons))
			mob_icon = head.item_icons[slot_head_str]
		else
			mob_icon = INV_HEAD_DEF_ICON

		overlays_raw[HEAD_LAYER] = head.get_mob_overlay(src, mob_icon, mob_state, slot_head_str)

	if (recurse)
		update_hair(FALSE)
		update_inv_wear_mask(FALSE, FALSE)

	if(update_icons)
		update_icon()

/mob/living/carbon/human/update_inv_belt(var/update_icons=1)
	if (QDELETED(src))
		return

	if(belt)
		var/mob_icon = INV_BELT_DEF_ICON
		var/mob_state = belt.item_state

		if(belt.contained_sprite)
			if(belt.icon_override)
				mob_icon = belt.icon_override
			else if(belt.sprite_sheets && belt.sprite_sheets[GET_BODY_TYPE])
				mob_icon = belt.sprite_sheets[GET_BODY_TYPE]
			else
				mob_icon = belt.icon
			belt.auto_adapt_species(src)
			mob_state = "[UNDERSCORE_OR_NULL(belt.icon_species_tag)][belt.item_state][WORN_BELT]"
		else if(belt.icon_override)
			mob_icon = belt.icon_override
		else if(belt.sprite_sheets && belt.sprite_sheets[GET_BODY_TYPE])
			mob_icon = belt.sprite_sheets[GET_BODY_TYPE]
		else if(belt.item_icons && (slot_belt_str in belt.item_icons))
			mob_icon = belt.item_icons[slot_belt_str]

		var/belt_layer = BELT_LAYER
		var/null_layer = BELT_LAYER_ALT
		if(istype(belt, /obj/item/storage/belt))
			var/obj/item/storage/belt/B = belt
			if(B.show_above_suit)
				belt_layer = BELT_LAYER_ALT
				null_layer = BELT_LAYER

		overlays_raw[belt_layer] = belt.get_mob_overlay(src, mob_icon, mob_state, slot_belt_str)
		overlays_raw[null_layer] = null
	else
		overlays_raw[BELT_LAYER] = null
		overlays_raw[BELT_LAYER_ALT] = null

	if(update_icons)
		update_icon()

/mob/living/carbon/human/update_inv_wear_suit(var/update_icons=1)
	if (QDELETED(src))
		return

	if(wear_suit)
		var/mob_icon = INV_SUIT_DEF_ICON
		var/mob_state = wear_suit.icon_state
		if(wear_suit.contained_sprite)
			if(wear_suit.icon_override)
				mob_icon = wear_suit.icon_override
			else if(wear_suit.sprite_sheets && wear_suit.sprite_sheets[GET_BODY_TYPE])
				mob_icon = wear_suit.sprite_sheets[GET_BODY_TYPE]
			else
				mob_icon = wear_suit.icon
			wear_suit.auto_adapt_species(src)
			mob_state = "[UNDERSCORE_OR_NULL(wear_suit.icon_species_tag)][wear_suit.item_state][WORN_SUIT]"
		else if(wear_suit.icon_override)
			mob_icon = wear_suit.icon_override
		else if(wear_suit.sprite_sheets && wear_suit.sprite_sheets[GET_BODY_TYPE])
			mob_icon = wear_suit.sprite_sheets[GET_BODY_TYPE]
		else if(wear_suit.item_icons && (slot_wear_suit_str in wear_suit.item_icons))
			mob_icon = wear_suit.item_icons[slot_wear_suit_str]

		overlays_raw[SUIT_LAYER] = wear_suit.get_mob_overlay(src, mob_icon, mob_state, slot_wear_suit_str)
		update_tail_showing(0)
	else
		overlays_raw[SUIT_LAYER] = null
		update_tail_showing(0)
		update_inv_shoes(0)

	update_collar(0)
	update_inv_w_uniform(0)

	if(update_icons)
		update_icon()


/mob/living/carbon/human/update_inv_pockets(var/update_icons=1)
	if (QDELETED(src))
		return

	if(update_icons)
		update_icon()


/mob/living/carbon/human/update_inv_wear_mask(update_icons = TRUE, recurse = TRUE)
	if (QDELETED(src))
		return

	overlays_raw[FACEMASK_LAYER] = null
	if(check_draw_mask())
		var/mob_icon
		var/mob_state

		if(wear_mask.contained_sprite)
			wear_mask.auto_adapt_species(src)
			var/state = "[UNDERSCORE_OR_NULL(wear_mask.icon_species_tag)][wear_mask.item_state][WORN_MASK]"
			if(wear_mask.icon_override)
				mob_icon = wear_mask.icon_override
			else if(wear_mask.sprite_sheets && wear_mask.sprite_sheets[GET_BODY_TYPE])
				mob_icon = wear_mask.sprite_sheets[GET_BODY_TYPE]
			else
				mob_icon = wear_mask.icon
			mob_state = state
		else if(wear_mask.icon_override)
			mob_icon = wear_mask.icon_override
			mob_state = wear_mask.icon_state
		else if(wear_mask.sprite_sheets && wear_mask.sprite_sheets[GET_BODY_TYPE])
			mob_icon = wear_mask.sprite_sheets[GET_BODY_TYPE]
			mob_state = wear_mask.icon_state
		else
			mob_icon = 'icons/mob/mask.dmi'
			mob_state = wear_mask.icon_state

		overlays_raw[FACEMASK_LAYER] = wear_mask.get_mob_overlay(src, mob_icon, mob_state, slot_wear_mask_str)

	if (recurse)
		update_inv_head(FALSE, FALSE)
		update_hair(FALSE)

	if(update_icons)
		update_icon()


/mob/living/carbon/human/update_inv_back(var/update_icons=1)
	if (QDELETED(src))
		return

	if(back)
		var/mob_icon = INV_BACK_DEF_ICON
		var/mob_state = back.icon_state

		if(back.contained_sprite)
			if(back.icon_override)
				mob_icon = back.icon_override
			else if(back.sprite_sheets && back.sprite_sheets[GET_BODY_TYPE])
				mob_icon = back.sprite_sheets[GET_BODY_TYPE]
			else
				mob_icon = back.icon
			back.auto_adapt_species(src)
			mob_state = "[UNDERSCORE_OR_NULL(back.icon_species_tag)][back.item_state][WORN_BACK]"
		else if(back.icon_override)
			mob_icon = back.icon_override
		else if(istype(back, /obj/item/rig))
			//If this is a rig and a mob_icon is set, it will take species into account in the rig update_icon() proc.
			var/obj/item/rig/rig = back
			mob_icon = rig.mob_icon
		else if(back.sprite_sheets && back.sprite_sheets[GET_BODY_TYPE])
			mob_icon = back.sprite_sheets[GET_BODY_TYPE]
		else if(back.item_icons && (slot_back_str in back.item_icons))
			mob_icon = back.item_icons[slot_back_str]

		if(!mob_state && back.item_state_slots && back.item_state_slots[slot_back_str])
			mob_state = back.item_state_slots[slot_back_str]

		overlays_raw[BACK_LAYER] = back.get_mob_overlay(src, mob_icon, mob_state, slot_back_str)
	else
		overlays_raw[BACK_LAYER] = null

	if(update_icons)
		update_icon()


/mob/living/carbon/human/update_hud()	//TODO: do away with this if possible
	if(client)
		client.screen |= contents
		if(hud_used)
			update_hud_hands()
			hud_used.hidden_inventory_update() 	//Updates the screenloc of the items on the 'other' inventory bar

//update whether handcuffs appears on our hud.
/mob/living/carbon/proc/update_hud_hands()
	if(hud_used?.l_hand_hud_object)
		hud_used.l_hand_hud_object.update_icon()
	if(hud_used?.r_hand_hud_object)
		hud_used.r_hand_hud_object.update_icon()

/mob/living/carbon/human/update_inv_handcuffed(var/update_icons=1)
	if (QDELETED(src))
		return

	if(handcuffed)
		drop_r_hand()
		drop_l_hand()
		stop_pulling()	//TODO: should be handled elsewhere

		var/image/standing
		if(handcuffed.icon_override)
			standing = image(handcuffed.icon_override, "handcuff1")
		else if(handcuffed.sprite_sheets && handcuffed.sprite_sheets[GET_BODY_TYPE])
			standing = image(handcuffed.sprite_sheets[GET_BODY_TYPE], "handcuff1")
		else
			standing = image('icons/mob/mob.dmi', "handcuff1")
		standing.appearance_flags = RESET_ALPHA
		overlays_raw[HANDCUFF_LAYER] = standing
	else
		overlays_raw[HANDCUFF_LAYER] = null

	update_hud_hands()
	if(update_icons)
		update_icon()

/mob/living/carbon/human/update_inv_legcuffed(var/update_icons=1)
	if (QDELETED(src))
		return

	if(legcuffed)
		var/image/standing
		if(legcuffed.icon_override)
			standing = image(legcuffed.icon_override, "legcuff1")
		else if(legcuffed.sprite_sheets && legcuffed.sprite_sheets[GET_BODY_TYPE])
			standing = image(legcuffed.sprite_sheets[GET_BODY_TYPE], "legcuff1")
		else
			standing = image('icons/mob/mob.dmi', "legcuff1")
		standing.appearance_flags = RESET_ALPHA
		overlays_raw[LEGCUFF_LAYER] = standing

		if(m_intent != M_WALK)
			m_intent = M_WALK
			if(hud_used && hud_used.move_intent)
				hud_used.move_intent.icon_state = "walking"

	else
		overlays_raw[LEGCUFF_LAYER] = null

	if(update_icons)
		update_icon()

/mob/living/carbon/human/update_inv_l_hand(update_icons = TRUE)
	if (QDELETED(src))
		return


	if(l_hand)
		var/mob_icon
		var/mob_state = l_hand.item_state || l_hand.icon_state

		if(l_hand.contained_sprite)
			if(l_hand.icon_override)
				mob_icon = l_hand.icon_override
			else if(l_hand.sprite_sheets && l_hand.sprite_sheets[GET_BODY_TYPE])
				mob_icon = l_hand.sprite_sheets[GET_BODY_TYPE]
			else
				mob_icon = l_hand.icon
			l_hand.auto_adapt_species(src)
			if(l_hand.item_state_slots && l_hand.item_state_slots[slot_l_hand_str])
				mob_state = "[l_hand.item_state_slots[slot_l_hand_str]][WORN_LHAND]"
			else
				mob_state = "[UNDERSCORE_OR_NULL(l_hand.icon_species_in_hand ? l_hand.icon_species_tag : null)][l_hand.item_state][WORN_LHAND]"
		else
			if(l_hand.item_state_slots && l_hand.item_state_slots[slot_l_hand_str])
				mob_state = l_hand.item_state_slots[slot_l_hand_str]

			if(l_hand.item_icons && (slot_l_hand_str in l_hand.item_icons))
				mob_icon = l_hand.item_icons[slot_l_hand_str]
			else if(l_hand.icon_override)
				mob_icon = l_hand.icon_override
				mob_state += WORN_LHAND
			else
				mob_icon = INV_L_HAND_DEF_ICON

		overlays_raw[L_HAND_LAYER] = l_hand.get_mob_overlay(src, mob_icon, mob_state, slot_l_hand_str)
	else
		overlays_raw[L_HAND_LAYER] = null

	if(update_icons)
		update_icon(forceDirUpdate = TRUE)

/mob/living/carbon/human/update_inv_r_hand(update_icons = TRUE)
	if (QDELETED(src))
		return

	if(r_hand)
		var/mob_icon
		var/mob_state = r_hand.item_state || r_hand.icon_state

		if(r_hand.contained_sprite)
			if(r_hand.icon_override)
				mob_icon = r_hand.icon_override
			else if(r_hand.sprite_sheets && r_hand.sprite_sheets[GET_BODY_TYPE])
				mob_icon = r_hand.sprite_sheets[GET_BODY_TYPE]
			else
				mob_icon = r_hand.icon
			r_hand.auto_adapt_species(src)
			if(r_hand.item_state_slots && r_hand.item_state_slots[slot_r_hand_str])
				mob_state = "[r_hand.item_state_slots[slot_r_hand_str]][WORN_RHAND]"
			else
				mob_state = "[UNDERSCORE_OR_NULL(r_hand.icon_species_in_hand ? r_hand.icon_species_tag : null)][r_hand.item_state][WORN_RHAND]"
		else
			if(r_hand.item_state_slots && r_hand.item_state_slots[slot_r_hand_str])
				mob_state = r_hand.item_state_slots[slot_r_hand_str]

			if(r_hand.item_icons && (slot_r_hand_str in r_hand.item_icons))
				mob_icon = r_hand.item_icons[slot_r_hand_str]
			else if(r_hand.icon_override)
				mob_icon = r_hand.icon_override
				mob_state += WORN_RHAND
			else
				mob_icon = INV_R_HAND_DEF_ICON

		overlays_raw[R_HAND_LAYER] = r_hand.get_mob_overlay(src, mob_icon, mob_state, slot_r_hand_str)
	else
		overlays_raw[R_HAND_LAYER] = null

	if(update_icons)
		update_icon(forceDirUpdate = TRUE)

/mob/living/carbon/human/update_inv_wrists(var/update_icons=1)
	if (QDELETED(src))
		return

	overlays_raw[UNDER_UNIFORM_LAYER_WR] = null
	overlays_raw[ABOVE_UNIFORM_LAYER_WR] = null
	overlays_raw[ABOVE_SUIT_LAYER_WR] = null

	if(check_draw_wrists())
		var/mob_icon
		var/mob_state = wrists.item_state || wrists.icon_state
		if(wrists.contained_sprite)
			if(wrists.icon_override)
				mob_icon = wrists.icon_override
			else if(wrists.sprite_sheets && wrists.sprite_sheets[GET_BODY_TYPE])
				mob_icon = wrists.sprite_sheets[GET_BODY_TYPE]
			else
				mob_icon = wrists.icon
			wrists.auto_adapt_species(src)
			mob_state = "[UNDERSCORE_OR_NULL(wrists.icon_species_tag)][wrists.item_state][WORN_WRISTS]"
		else
			if(wrists.item_state_slots && wrists.item_state_slots[slot_wrists_str])
				mob_state = wrists.item_state_slots[slot_wrists_str]

			//determine icon to use
			if(wrists.item_icons && (slot_wrists_str in wrists.item_icons))
				mob_icon = wrists.item_icons[slot_wrists_str]
			else if(wrists.icon_override)
				mob_icon = wrists.icon_override
				mob_state += WORN_WRISTS
			else
				mob_icon = INV_WRISTS_DEF_ICON

		var/image/wrists_overlay = wrists.get_mob_overlay(src, mob_icon, mob_state, slot_wrists_str)

		var/wrist_layer = ABOVE_SUIT_LAYER_WR
		if(istype(wrists, /obj/item/clothing/wrists) || istype(wrists, /obj/item/device/radio/headset/wrist))
			var/obj/item/clothing/wrists/W = wrists
			wrist_layer = W.mob_wear_layer

		overlays_raw[wrist_layer] = wrists_overlay

	if(update_icons)
		update_icon()

/mob/living/carbon/human/update_inv_pants(var/update_icons=1)
	if (QDELETED(src))
		return

	overlays_raw[UNDER_UNIFORM_LAYER_PA] = null
	overlays_raw[ABOVE_UNIFORM_LAYER_PA] = null
	overlays_raw[ABOVE_SUIT_LAYER_PA] = null

	if(check_draw_pants())
		var/mob_icon
		var/mob_state = pants.item_state || pants.icon_state
		if(pants.contained_sprite)
			if(pants.icon_override)
				mob_icon = pants.icon_override
			else if(pants.sprite_sheets && pants.sprite_sheets[GET_BODY_TYPE])
				mob_icon = pants.sprite_sheets[GET_BODY_TYPE]
			else
				mob_icon = pants.icon
			pants.auto_adapt_species(src)
			mob_state = "[UNDERSCORE_OR_NULL(pants.icon_species_tag)][pants.item_state][WORN_PANTS]"
		else
			if(pants.item_state_slots && pants.item_state_slots[slot_pants_str])
				mob_state = pants.item_state_slots[slot_pants_str]

			//determine icon to use
			if(pants.item_icons && (slot_pants_str in pants.item_icons))
				mob_icon = pants.item_icons[slot_pants_str]
			else if(pants.icon_override)
				mob_icon = pants.icon_override
				mob_state += WORN_PANTS
			else
				mob_icon = INV_PANTS_DEF_ICON

		var/image/pants_overlay = pants.get_mob_overlay(src, mob_icon, mob_state, slot_pants_str)

		var/pants_layer = ABOVE_SUIT_LAYER_PA
		if(istype(pants, /obj/item/clothing/pants))
			var/obj/item/clothing/pants/P = pants
			pants_layer = P.mob_wear_layer

		overlays_raw[pants_layer] = pants_overlay

	if(update_icons)
		update_icon()

/mob/living/carbon/human/proc/update_tail_showing(var/update_icons=1)

	if (QDELETED(src))
		return

	overlays_raw[TAIL_NORTH_LAYER] = null
	overlays_raw[TAIL_SOUTH_LAYER] = null

	var/tail_layer = GET_TAIL_LAYER

	if(species.tail && !(mutations & HUSK) && !(mutations & SKELETON) && !(wear_suit && wear_suit.flags_inv & HIDETAIL))
		var/icon/tail_s = get_tail_icon()
		overlays_raw[tail_layer] = image(tail_s, icon_state = "[tail_style]_s")
		animate_tail_reset()
		update_tail_accessory(FALSE)

	if(update_icons)
		update_icon()

/mob/living/carbon/human/proc/get_tail_icon()
	if (QDELETED(src))
		return

	var/icon_key = "[species.race_key][r_skin][g_skin][b_skin][r_hair][g_hair][b_hair]"
	var/icon/tail_icon = SSicon_cache.tail_icon_cache[icon_key]
	if(!tail_icon)
		//generate a new one
		tail_icon = new/icon(icon = (species.tail_animation? species.tail_animation : 'icons/effects/species.dmi'))
		tail_icon.Blend(rgb(r_skin, g_skin, b_skin), ICON_ADD)
		// The following will not work with animated tails.
		if(species.tail_hair)
			var/icon/hair_icon = icon('icons/effects/species.dmi', "[tail_style]_[species.tail_hair]")
			hair_icon.Blend(rgb(r_hair, g_hair, b_hair), ICON_ADD)
			tail_icon.Blend(hair_icon, ICON_OVERLAY)
		SSicon_cache.tail_icon_cache[icon_key] = tail_icon

	return tail_icon

/mob/living/carbon/human/proc/set_tail_state(var/mob_state)
	if(!tail_style)
		return

	var/tail_layer = GET_TAIL_LAYER
	var/image/tail_overlay = overlays_raw[tail_layer]

	var/obj/item/clothing/tail_accessory/TA = get_tail_accessory()
	if(TA && !(tail_style in TA.compatible_animated_tail))
		mob_state = "[tail_style]_static"

	if(tail_overlay && species.tail_animation)
		if(tail_overlay.icon_state != mob_state)
			tail_overlay.icon_state = mob_state
			update_tail_accessory()
			update_icon()
		return tail_overlay
	return null

//Not really once, since BYOND can't do that.
//Update this if the ability to flick() images or make looping animation start at the first frame is ever added.
/mob/living/carbon/human/proc/animate_tail_once()
	var/mob_state = "[tail_style]_once"

	var/tail_layer = GET_TAIL_LAYER

	var/image/tail_overlay = overlays_raw[tail_layer]
	if(tail_overlay && tail_overlay.icon_state == mob_state)
		return //let the existing animation finish

	tail_overlay = set_tail_state(mob_state)
	if(tail_overlay)
		addtimer(CALLBACK(src, PROC_REF(end_animate_tail_once), tail_overlay), 20, TIMER_CLIENT_TIME)

/mob/living/carbon/human/proc/end_animate_tail_once(image/tail_overlay)
	//check that the animation hasn't changed in the meantime
	var/tail_layer = GET_TAIL_LAYER
	if(overlays_raw[tail_layer] == tail_overlay && tail_overlay.icon_state == "[tail_style]_once")
		animate_tail_stop()
		update_tail_accessory()

/mob/living/carbon/human/proc/animate_tail_start()
	set_tail_state("[tail_style]_slow")

/mob/living/carbon/human/proc/animate_tail_fast()
	set_tail_state("[tail_style]_loop")

/mob/living/carbon/human/proc/animate_tail_reset()
	if(stat != DEAD && !lying)
		set_tail_state("[tail_style]_idle")
	else
		set_tail_state("[tail_style]_static")

/mob/living/carbon/human/proc/animate_tail_stop(var/update_icons=1)
	set_tail_state("[tail_style]_static")

/mob/living/carbon/human/proc/update_tail_accessory(var/update_icons=1)
	overlays_raw[TAIL_NORTH_ACC_LAYER] = null
	overlays_raw[TAIL_SOUTH_ACC_LAYER] = null

	var/obj/item/clothing/tail_accessory/TA = get_tail_accessory()
	if(!TA)
		return

	var/image/tail_overlay = overlays_raw[GET_TAIL_LAYER]
	if(!tail_overlay)
		return

	overlays_raw[GET_TAIL_ACC_LAYER] = TA.get_mob_overlay(src, TA.icon, "[tail_overlay.icon_state]_to", slot_tail_str)

	if(update_icons)
		update_icon()


//Adds a collar overlay above the helmet layer if the suit has one
//	Suit needs an identically named sprite in icons/mob/collar.dmi
/mob/living/carbon/human/proc/update_collar(var/update_icons=1)
	if (QDELETED(src))
		return

	var/list/collar_mapping	= SSicon_cache.collar_states
	if (!collar_mapping)
		SSicon_cache.setup_collar_mappings()

	if(wear_suit && collar_mapping[wear_suit.icon_state])
		overlays_raw[COLLAR_LAYER] = image('icons/mob/collar.dmi', wear_suit.icon_state)
	else
		overlays_raw[COLLAR_LAYER] = null

	if(update_icons)
		update_icon()

// update_fire()
/mob/living/carbon/human/update_fire(var/update_icons = TRUE)
	if(QDELETED(src))
		return

	var/image/fire_image_lower = on_fire ? image(species.onfire_overlay, "lower", layer = FIRE_LAYER_LOWER) : null
	var/image/fire_image_upper = on_fire ? image(species.onfire_overlay, "upper", layer = FIRE_LAYER_UPPER) : null

	overlays_raw[FIRE_LAYER_LOWER] = fire_image_lower
	overlays_raw[FIRE_LAYER_UPPER] = fire_image_upper

	if(update_icons)
		update_icon()

/mob/living/carbon/human/proc/update_surgery(var/update_icons=1)
	overlays_raw[SURGERY_LAYER] = null

	var/image/total = new
	for(var/obj/item/organ/external/E in organs)
		if(E.status & ORGAN_ROBOT || E.is_stump())
			continue
		if(!E.open)
			continue

		var/surgery_icon = E.owner.species.get_surgery_overlay_icon(src)
		if(!surgery_icon)
			continue

		var/list/surgery_states = icon_states(surgery_icon)
		var/base_state = "[E.icon_name][E.open]"
		var/overlay_state = "[base_state]-flesh"
		var/list/overlays_to_add

		if(overlay_state in surgery_states)
			var/image/flesh = image(icon = surgery_icon, icon_state = overlay_state, layer = -SURGERY_LAYER)
			flesh.color = E.owner.species.flesh_color
			flesh.appearance_flags = RESET_ALPHA
			LAZYADD(overlays_to_add, flesh)
		overlay_state = "[base_state]-blood"
		if(overlay_state in surgery_states)
			var/image/blood = image(icon = surgery_icon, icon_state = overlay_state, layer = -SURGERY_LAYER)
			blood.color = E.owner.get_blood_color()
			blood.appearance_flags = RESET_ALPHA
			LAZYADD(overlays_to_add, blood)
		overlay_state = "[base_state]-bones"
		if(overlay_state in surgery_states)
			LAZYADD(overlays_to_add, image(icon = surgery_icon, icon_state = overlay_state, layer = -SURGERY_LAYER))
		total.overlays |= overlays_to_add

	overlays_raw[SURGERY_LAYER] = total

	if(update_icons)
		update_icon()

//Drawcheck functions
//These functions check if an item should be drawn, or if its covered up by something else
/mob/living/carbon/human/proc/check_draw_gloves()
	SHOULD_NOT_SLEEP(TRUE)
	SHOULD_BE_PURE(TRUE)
	if (!gloves)
		return FALSE
	else if (gloves.flags_inv & ALWAYSDRAW)
		return TRUE
	else if (wear_suit && (wear_suit.flags_inv & HIDEGLOVES))
		return FALSE
	else
		return TRUE

/mob/living/carbon/human/proc/check_draw_right_ear()
	SHOULD_NOT_SLEEP(TRUE)
	SHOULD_BE_PURE(TRUE)
	if (!r_ear)
		return FALSE
	else if (r_ear.flags_inv & ALWAYSDRAW)
		return TRUE
	else if ((head && (head.flags_inv & (HIDEEARS))) || (wear_mask && (wear_mask.flags_inv & (HIDEEARS))))
		return FALSE
	return TRUE


/mob/living/carbon/human/proc/check_draw_left_ear()
	SHOULD_NOT_SLEEP(TRUE)
	SHOULD_BE_PURE(TRUE)
	if (!l_ear)
		return FALSE
	else if (l_ear.flags_inv & ALWAYSDRAW)
		return TRUE
	else if ((head && (head.flags_inv & (HIDEEARS))) || (wear_mask && (wear_mask.flags_inv & (HIDEEARS))))
		return FALSE
	return TRUE

/mob/living/carbon/human/proc/check_draw_glasses()
	SHOULD_NOT_SLEEP(TRUE)
	SHOULD_BE_PURE(TRUE)
	if (!glasses)
		return FALSE
	else if (glasses.flags_inv & ALWAYSDRAW)
		return TRUE
	else if( (head && (head.flags_inv & (HIDEEYES))) || (wear_mask && (wear_mask.flags_inv & (HIDEEYES))))
		return FALSE
	else
		return TRUE


/mob/living/carbon/human/proc/check_draw_mask()
	SHOULD_NOT_SLEEP(TRUE)
	SHOULD_BE_PURE(TRUE)
	if (!wear_mask)
		return FALSE
	else if (wear_mask.flags_inv & ALWAYSDRAW)
		return TRUE
	else if( head && (head.flags_inv & HIDEEYES))
		return FALSE
	else
		return TRUE

/mob/living/carbon/human/proc/check_draw_shoes()
	SHOULD_NOT_SLEEP(TRUE)
	SHOULD_BE_PURE(TRUE)
	if (!shoes)
		return FALSE
	else if (shoes.flags_inv & ALWAYSDRAW)
		return TRUE
	else if(wear_suit && (wear_suit.flags_inv & HIDESHOES))
		return FALSE
	else
		return TRUE

/mob/living/carbon/human/proc/check_draw_underclothing()
	SHOULD_NOT_SLEEP(TRUE)
	SHOULD_BE_PURE(TRUE)
	if (!w_uniform)
		return FALSE
	else if (w_uniform.flags_inv & ALWAYSDRAW)
		return TRUE
	else if(wear_suit && (wear_suit.flags_inv & HIDEJUMPSUIT))
		return FALSE
	else
		return TRUE

/mob/living/carbon/human/proc/check_draw_wrists()
	SHOULD_NOT_SLEEP(TRUE)
	SHOULD_BE_PURE(TRUE)
	if (!wrists)
		return FALSE
	else if (wrists.flags_inv & ALWAYSDRAW)
		return TRUE
	else if (wear_suit?.flags_inv & HIDEWRISTS)
		return FALSE
	else
		return TRUE

/mob/living/carbon/human/proc/check_draw_pants()
	SHOULD_NOT_SLEEP(TRUE)
	SHOULD_BE_PURE(TRUE)
	if (!pants)
		return FALSE
	else if (pants.flags_inv & ALWAYSDRAW)
		return TRUE
	else if (pants.flags_inv & HIDEPANTS)
		return FALSE
	else
		return TRUE

#undef UNDERSCORE_OR_NULL
#undef GET_BODY_TYPE
#undef GET_TAIL_LAYER
