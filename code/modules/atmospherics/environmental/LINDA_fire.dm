/// Returns reactions which will contribute to a hotspot's size.
/proc/init_hotspot_reactions()
	var/list/fire_reactions = list()
	for (var/datum/gas_reaction/reaction as anything in subtypesof(/datum/gas_reaction))
		if(initial(reaction.expands_hotspot))
			fire_reactions += reaction

	return fire_reactions

/atom/proc/temperature_expose(datum/gas_mixture/air, exposed_temperature, exposed_volume)
	return null



/turf/proc/hotspot_expose(exposed_temperature, exposed_volume, soh = 0)
	return

/turf/open/proc/set_active_hotspot(obj/effect/hotspot/new_lad)
	if(active_hotspot == new_lad)
		return
	var/hotspot_around = NONE
	if(active_hotspot)
		if(new_lad)
			hotspot_around = active_hotspot.smoothing_junction
		if(!QDELETED(active_hotspot))
			QDEL_NULL(active_hotspot)
	else
		for(var/direction in GLOB.cardinals)
			var/turf/potentially_open = get_step(src, direction)
			if(!isopenturf(potentially_open))
				continue
			var/turf/open/potentially_hotboxed = potentially_open
			if(!potentially_hotboxed.active_hotspot)
				continue
			var/existing_directions = potentially_hotboxed.active_hotspot.smoothing_junction
			potentially_hotboxed.active_hotspot.set_smoothed_icon_state(existing_directions | REVERSE_DIR(direction))
			hotspot_around |= direction

	active_hotspot = new_lad
	if(active_hotspot)
		active_hotspot.set_smoothed_icon_state(hotspot_around)

/**
 * Handles the creation of hotspots and initial activation of turfs.
 * Setting the conditions for the reaction to actually happen for gasmixtures
 * is handled by the hotspot itself, specifically perform_exposure().
 */
/turf/open/hotspot_expose(exposed_temperature, exposed_volume, soh)
	//NOVA EDIT ADDITION
	if(liquids && !liquids.fire_state && liquids.check_fire(TRUE))
		SSliquids.processing_fire[src] = TRUE
	//NOVA EDIT END

	//If the air doesn't exist we just return false
	var/list/air_gases = air?.gases
	if(!air_gases)
		return

	. = air_gases[/datum/gas/oxygen]
	var/oxy = . ? .[MOLES] : 0
	if (oxy < 0.5)
		return
	. = air_gases[/datum/gas/plasma]
	var/plas = . ? .[MOLES] : 0
	. = air_gases[/datum/gas/tritium]
	var/trit = . ? .[MOLES] : 0
	. = air_gases[/datum/gas/hydrogen]
	var/h2 = . ? .[MOLES] : 0
	. = air_gases[/datum/gas/freon]
	var/freon = . ? .[MOLES] : 0
	if(active_hotspot)
		if(soh)
			if(plas > 0.5 || trit > 0.5 || h2 > 0.5)
				if(active_hotspot.temperature < exposed_temperature)
					active_hotspot.temperature = exposed_temperature
				if(active_hotspot.volume < exposed_volume)
					active_hotspot.volume = exposed_volume
			else if(freon > 0.5)
				if(active_hotspot.temperature > exposed_temperature)
					active_hotspot.temperature = exposed_temperature
				if(active_hotspot.volume < exposed_volume)
					active_hotspot.volume = exposed_volume
		return

	if(((exposed_temperature > PLASMA_MINIMUM_BURN_TEMPERATURE) && (plas > 0.5 || trit > 0.5 || h2 > 0.5)) || \
		((exposed_temperature < FREON_MAXIMUM_BURN_TEMPERATURE) && (freon > 0.5)))

		set_active_hotspot(new /obj/effect/hotspot(src, exposed_volume*25, exposed_temperature))

		active_hotspot.just_spawned = (current_cycle < SSair.times_fired)
		//remove just_spawned protection if no longer processing this cell
		SSair.add_to_active(src)

/**
 * Hotspot objects interfaces with the temperature of turf gasmixtures while also providing visual effects.
 * One important thing to note about hotspots are that they can roughly be divided into two categories based on the bypassing variable.
 */
/obj/effect/hotspot
	anchored = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	icon = 'icons/effects/atmos/fire.dmi'
	icon_state = "light"
	layer = GASFIRE_LAYER
	blend_mode = BLEND_ADD
	light_system = OVERLAY_LIGHT
	light_range = LIGHT_RANGE_FIRE
	light_power = 1
	light_color = LIGHT_COLOR_FIRE

	/// base sprite used for our icon states when smoothing
	/// BAAAASICALY the same as icon_state but is helpful to avoid duplicated work
	var/fire_stage = ""
	/**
	 * Volume is the representation of how big and healthy a fire is.
	 * Hotspot volume will be divided by turf volume to get the ratio for temperature setting on non bypassing mode.
	 * Also some visual stuffs for fainter fires.
	 */
	var/volume = 125
	/// Temperature handles the initial ignition and the colouring.
	var/temperature = FIRE_MINIMUM_TEMPERATURE_TO_EXIST
	/// Whether the hotspot is new or not. Used for bypass logic.
	var/just_spawned = TRUE
	/// Whether the hotspot becomes passive and follows the gasmix temp instead of changing it.
	var/bypassing = FALSE
	var/visual_update_tick = 0
	///Are we burning freon?
	var/cold_fire = FALSE

/obj/effect/hotspot/Initialize(mapload, starting_volume, starting_temperature)
	. = ..()
	SSair.hotspots += src
	if(!isnull(starting_volume))
		volume = starting_volume
	if(!isnull(starting_temperature))
		temperature = starting_temperature
	perform_exposure()
	setDir(pick(GLOB.cardinals))
	air_update_turf(FALSE, FALSE)
	var/static/list/loc_connections = list(
		COMSIG_ATOM_ENTERED = PROC_REF(on_entered),
		COMSIG_ATOM_ABSTRACT_ENTERED = PROC_REF(on_entered),
	)
	AddElement(/datum/element/connect_loc, loc_connections)

/obj/effect/hotspot/set_smoothed_icon_state(new_junction)
	smoothing_junction = new_junction
	// If we have a connection down offset physically down so we render correctly
	if(new_junction & SOUTH)
		// this ensures things physically below us but visually overlapping us render how we would want
		pixel_y = -16
		pixel_z = 16
	// Otherwise render normally, to avoid weird layering
	else
		pixel_y = 0
		pixel_z = 0

	update_color()

/**
 * Perform interactions between the hotspot and the gasmixture.
 *
 * For the first tick, hotspots will take a sample of the air in the turf,
 * set the temperature equal to a certain amount, and then reacts it.
 * In some implementations the ratio comes out to around 1, so all of the air in the turf.
 *
 * Afterwards if the reaction is big enough it mostly just tags along the fire,
 * copying the temperature and handling the colouring.
 * If the reaction is too small it will perform like the first tick.
 *
 * Also calls fire_act() which handles burning.
 */
/obj/effect/hotspot/proc/perform_exposure()
	var/turf/open/location = loc
	var/datum/gas_mixture/reference
	if(!istype(location) || !(location.air))
		return

	location.set_active_hotspot(src)

	bypassing = !just_spawned && (volume > CELL_VOLUME*0.95)

	//Passive mode
	if(bypassing || cold_fire)
		reference = location.air // Our color and volume will depend on the turf's gasmix
	//Active mode
	else
		var/datum/gas_mixture/affected = location.air.remove_ratio(volume/location.air.volume)
		if(affected) //in case volume is 0
			reference = affected // Our color and volume will depend on this small sparked gasmix
			affected.temperature = temperature
			affected.react(src)
			location.assume_air(affected)

	if(reference)
		volume = 0
		var/list/cached_results = reference.reaction_results
		for (var/reaction in SSair.hotspot_reactions)
			volume += cached_results[reaction] * FIRE_GROWTH_RATE
		temperature = reference.temperature

	// Handles the burning of atoms.
	if(cold_fire)
		return
	for(var/A in location)
		var/atom/AT = A
		if(!QDELETED(AT) && AT != src)
			AT.fire_act(temperature, volume)
	return

/// Mathematics to be used for color calculation.
/obj/effect/hotspot/proc/gauss_lerp(x, x1, x2)
	var/b = (x1 + x2) * 0.5
	var/c = (x2 - x1) / 6
	return NUM_E ** -((x - b) ** 2 / (2 * c) ** 2)

/obj/effect/hotspot/proc/update_color()
	cut_overlays()

	if(!(smoothing_junction & NORTH))
		var/mutable_appearance/frill = mutable_appearance('icons/effects/atmos/fire.dmi', "[fire_stage]_frill")
		frill.pixel_z = 32
		add_overlay(frill)
	var/heat_r = heat2colour_r(temperature)
	var/heat_g = heat2colour_g(temperature)
	var/heat_b = heat2colour_b(temperature)
	var/heat_a = 255
	var/greyscale_fire = 1 //This determines how greyscaled the fire is.
	// Note:
	// Some of the overlays applied to hotspots are not 3/4th'd. They COULD be but we have not gotten to that point yet.
	// Wallening todo?

	if(cold_fire)
		heat_r = 0
		heat_g = LERP(255, temperature, 1.2)
		heat_b = LERP(255, temperature, 0.9)
		heat_a = 100
	else if(temperature < 5000) //This is where fire is very orange, we turn it into the normal fire texture here.
		var/normal_amt = gauss_lerp(temperature, 1000, 3000)
		heat_r = LERP(heat_r,255,normal_amt)
		heat_g = LERP(heat_g,255,normal_amt)
		heat_b = LERP(heat_b,255,normal_amt)
		heat_a -= gauss_lerp(temperature, -5000, 5000) * 128
		greyscale_fire -= normal_amt
	if(temperature > 40000) //Past this temperature the fire will gradually turn a bright purple
		var/purple_amt = temperature < LERP(40000,200000,0.5) ? gauss_lerp(temperature, 40000, 200000) : 1
		heat_r = LERP(heat_r,255,purple_amt)
	if(temperature > 200000 && temperature < 500000) //Somewhere at this temperature nitryl happens.
		var/sparkle_amt = gauss_lerp(temperature, 200000, 500000)
		var/mutable_appearance/sparkle_overlay = mutable_appearance('icons/effects/effects.dmi', "shieldsparkles")
		sparkle_overlay.blend_mode = BLEND_ADD
		sparkle_overlay.alpha = sparkle_amt * 255
		add_overlay(sparkle_overlay)
	if(temperature > 400000 && temperature < 1500000) //Lightning because very anime.
		var/mutable_appearance/lightning_overlay = mutable_appearance('icons/effects/atmos/fire.dmi', "overcharged")
		if(!(smoothing_junction & NORTH))
			var/mutable_appearance/frill = mutable_appearance('icons/effects/atmos/fire.dmi', "overcharged_frill")
			frill.pixel_z = 32
			lightning_overlay.add_overlay(frill)
		lightning_overlay.blend_mode = BLEND_ADD
		add_overlay(lightning_overlay)
	if(temperature > 4500000) //This is where noblium happens. Some fusion-y effects.
		var/fusion_amt = temperature < LERP(4500000,12000000,0.5) ? gauss_lerp(temperature, 4500000, 12000000) : 1
		var/mutable_appearance/fusion_overlay = mutable_appearance('icons/effects/atmos/atmospherics.dmi', "fusion_gas")
		fusion_overlay.blend_mode = BLEND_ADD
		fusion_overlay.alpha = fusion_amt * 255
		var/mutable_appearance/rainbow_overlay = mutable_appearance('icons/hud/screen_gen.dmi', "druggy")
		rainbow_overlay.blend_mode = BLEND_ADD
		rainbow_overlay.alpha = fusion_amt * 255
		rainbow_overlay.appearance_flags = RESET_COLOR
		heat_r = LERP(heat_r,150,fusion_amt)
		heat_g = LERP(heat_g,150,fusion_amt)
		heat_b = LERP(heat_b,150,fusion_amt)
		add_overlay(fusion_overlay)
		add_overlay(rainbow_overlay)

	set_light_color(rgb(LERP(250, heat_r, greyscale_fire), LERP(160, heat_g, greyscale_fire), LERP(25, heat_b, greyscale_fire)))

	heat_r /= 255
	heat_g /= 255
	heat_b /= 255

	color = list(LERP(0.3, 1, 1-greyscale_fire) * heat_r,0.3 * heat_g * greyscale_fire,0.3 * heat_b * greyscale_fire, 0.59 * heat_r * greyscale_fire,LERP(0.59, 1, 1-greyscale_fire) * heat_g,0.59 * heat_b * greyscale_fire, 0.11 * heat_r * greyscale_fire,0.11 * heat_g * greyscale_fire,LERP(0.11, 1, 1-greyscale_fire) * heat_b, 0,0,0)
	alpha = heat_a

#define INSUFFICIENT(path) (!location.air.gases[path] || location.air.gases[path][MOLES] < 0.5)

/**
 * Regular process proc for hotspots governed by the controller.
 * Handles the calling of perform_exposure() which handles the bulk of temperature processing.
 * Burning or fire_act() are also called by perform_exposure().
 * Also handles the dying and qdeletion of the hotspot and hotspot creations on adjacent cardinal turfs.
 * And some visual stuffs too! Colors and fainter icons for specific conditions.
 */
/obj/effect/hotspot/process()
	if(just_spawned)
		just_spawned = FALSE
		return

	var/turf/open/location = loc
	if(!istype(location))
		qdel(src)
		return

	if(location.excited_group)
		location.excited_group.reset_cooldowns()

	cold_fire = FALSE
	if(temperature <= FREON_MAXIMUM_BURN_TEMPERATURE)
		cold_fire = TRUE

	if((temperature < FIRE_MINIMUM_TEMPERATURE_TO_EXIST && !cold_fire) || (volume <= 1))
		qdel(src)
		return

	//Not enough / nothing to burn
	if(!location.air || (INSUFFICIENT(/datum/gas/plasma) && INSUFFICIENT(/datum/gas/tritium) && INSUFFICIENT(/datum/gas/hydrogen) && INSUFFICIENT(/datum/gas/freon)) || INSUFFICIENT(/datum/gas/oxygen))
		qdel(src)
		return

	perform_exposure()

	if(bypassing)
		set_fire_stage("heavy")
		if(!cold_fire)
			location.burn_tile()

		//Possible spread due to radiated heat.
		if(location.air.temperature > FIRE_MINIMUM_TEMPERATURE_TO_SPREAD || cold_fire)
			var/radiated_temperature = location.air.temperature*FIRE_SPREAD_RADIOSITY_SCALE
			if(cold_fire)
				radiated_temperature = location.air.temperature * COLD_FIRE_SPREAD_RADIOSITY_SCALE
			for(var/t in location.atmos_adjacent_turfs)
				var/turf/open/T = t
				if(!T.active_hotspot)
					T.hotspot_expose(radiated_temperature, CELL_VOLUME/4)

	else
		if(volume > CELL_VOLUME*0.4)
			set_fire_stage("medium")
		else
			set_fire_stage("light")

	if((visual_update_tick++ % 7) == 0)
		update_color()

	return TRUE

/obj/effect/hotspot/proc/set_fire_stage(stage)
	if(fire_stage == stage)
		return
	fire_stage = stage
	icon_state = stage
	dir = pick(GLOB.cardinals)
	update_color()

/obj/effect/hotspot/Destroy()
	SSair.hotspots -= src
	var/turf/open/T = loc
	if(istype(T) && T.active_hotspot == src)
		T.set_active_hotspot(null)
	return ..()

/obj/effect/hotspot/proc/on_entered(datum/source, atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	SIGNAL_HANDLER
	if(isliving(arrived) && !cold_fire)
		var/mob/living/immolated = arrived
		immolated.fire_act(temperature, volume)

/obj/effect/hotspot/singularity_pull()
	return

#undef INSUFFICIENT
