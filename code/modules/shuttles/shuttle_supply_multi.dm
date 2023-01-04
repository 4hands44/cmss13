/obj/effect/landmark/multi_fakezlevel_supply_elevator
	var/fake_zlevel
	var/is_primary_fake_zlevel = FALSE

/obj/effect/landmark/multi_fakezlevel_supply_elevator/Initialize(mapload, ...)
	. = ..()

	var/turf/dummy_variable
	for(var/i = 1; i != null; i++)
		if(length(GLOB.supply_elevator_turfs) < fake_zlevel)
			GLOB.supply_elevator_turfs += dummy_variable
		else
			break

	GLOB.supply_elevator_turfs[fake_zlevel] = get_turf(src)

	if(is_primary_fake_zlevel)
		supply_controller.primary_fake_zlevel = fake_zlevel

	return INITIALIZE_HINT_QDEL

/datum/shuttle/ferry/supply/multi
	iselevator = 1
	var/list/obj/effect/elevator/supply/multi/elevator_effects = list()
	var/list/shaft_projectors = list() //contains lists which each contain groups of projectors near each stop of the elevator
	var/fake_zlevel = 0
	var/target_zlevel = 1
	var/obj/structure/elevator_control_mount/in_elevator_controller
	replacement_turf_type = /turf/open/floor/almayer/empty/multi_elevator

/datum/shuttle/ferry/supply/multi/New()
	elevator_animation = new()
	elevator_animation.pixel_y = -192

	for(var/obj/effect/projector/P in projectors)
		for(var/turf/T in GLOB.supply_elevator_turfs)
			var/area/area_of_T = get_area(T)
			for(var/i = 0; i < area_of_T.fake_zlevel; i++)
				if(length(shaft_projectors) < area_of_T.fake_zlevel)
					shaft_projectors += list(list())
				else
					break
			var/maths_x = T.x - P.x
			var/maths_y = T.y - P.y
			if(T.z == P.z)
				if(maths_x > -5 && maths_x <= 0)
					if(maths_y > -5 && maths_y <= 0)
						shaft_projectors[area_of_T.fake_zlevel] |= P
					else if(maths_y < -5 && maths_y >= 0)
						shaft_projectors[area_of_T.fake_zlevel] |= P
				else if(maths_x < 5 && maths_x >= 0)
					if(maths_y > -5 && maths_y <= 0)
						shaft_projectors[area_of_T.fake_zlevel] |= P
					else if(maths_y < -5 && maths_y >= 0)
						shaft_projectors[area_of_T.fake_zlevel] |= P

	if(supply_controller)
		for(var/i=1; i <= length(GLOB.supply_elevator_turfs);i++)
			var/turf/T = GLOB.supply_elevator_turfs[i]

			elevator_effects["[i]SW"]  = new /obj/effect/elevator/supply/multi(locate(T.x-2,T.y-2,T.z))
			elevator_effects["[i]SW"].vis_contents += elevator_animation

			elevator_effects["[i]SE"] = new /obj/effect/elevator/supply/multi(locate(T.x+2,T.y-2,T.z))
			elevator_effects["[i]SE"].pixel_x = -128
			elevator_effects["[i]SE"].vis_contents += elevator_animation

			elevator_effects["[i]NW"] = new /obj/effect/elevator/supply/multi(locate(T.x-2,T.y+2,T.z))
			elevator_effects["[i]NW"].pixel_y = -128
			elevator_effects["[i]NW"].vis_contents += elevator_animation

			elevator_effects["[i]NE"] = new /obj/effect/elevator/supply/multi(locate(T.x+2,T.y+2,T.z))
			elevator_effects["[i]NE"].pixel_x = -128
			elevator_effects["[i]NE"].pixel_y = -128
			elevator_effects["[i]NE"].vis_contents += elevator_animation

	//playsound(locate(Elevator_x,Elevator_y,Elevator_z), 'sound/machines/cargo_alarm.ogg', 50, 0)  //<-- play this when sending offsite

/datum/shuttle/ferry/supply/multi/add_structures()
	for(var/turf/T in area_offsite)
		var/check1 = (get_step(T, NORTH).density ? TRUE : FALSE)
		var/check2 = (get_step(T, EAST).density ? TRUE : FALSE)
		if(check1 && check2)
			in_elevator_controller = new/obj/structure/elevator_control_mount(T)
			break

/datum/shuttle/ferry/supply/multi/pick_loc()
	RETURN_TYPE(/turf)
	if(!supply_controller.multi_fakezlevel_elevator)
		return GLOB.supply_elevator_turfs[target_zlevel]

/datum/shuttle/ferry/supply/multi/get_location_area(location_id)
	if (isnull(location_id))
		location_id = location

	if (!location_id)
		return get_area(GLOB.supply_elevator_turfs[target_zlevel])

	return area_offsite

/datum/shuttle/ferry/supply/multi/at_station()
	return fake_zlevel

/datum/shuttle/ferry/supply/multi/short_jump(var/area/origin,var/area/destination)
	if(moving_status != SHUTTLE_IDLE)
		return

	if(isnull(location))
		return

	recharging = 1

	if(!destination)
		if(!target_zlevel)
			destination = area_offsite
		else
			destination = get_area(GLOB.supply_elevator_turfs[target_zlevel])
	if(!origin)
		if(!fake_zlevel)
			origin = area_offsite
		else
			origin = get_area(GLOB.supply_elevator_turfs[fake_zlevel])

	moving_status = SHUTTLE_WARMUP
	spawn(warmup_time)
		if (moving_status == SHUTTLE_IDLE)
			return	//someone cancelled the launch

		if (target_zlevel != supply_controller.primary_fake_zlevel)
			if(fake_zlevel == supply_controller.primary_fake_zlevel)
				raise_railings()
			sleep(12)
			if(forbidden_atoms_check())
				//cancel the launch because of forbidden atoms. announce over supply channel?
				moving_status = SHUTTLE_IDLE
				playsound(GLOB.supply_elevator_turfs[fake_zlevel], 'sound/machines/buzz-two.ogg', 50, 0)
				if(fake_zlevel == supply_controller.primary_fake_zlevel)
					lower_railings()
				return
		else	//at centcom
			supply_controller.buy()

		//We pretend it's a long_jump by making the shuttle stay at centcom for the "in-transit" period.
		var/area/away_area = get_location_area(away_location)
		moving_status = SHUTTLE_INTRANSIT

		/*We attach the turfs in our starting area to the vis_contents overlay. The elevator effect procs will animate this. If we're going down, the stuff will instantly be
		teleported and then cosmetically animated as lowering; otherwise, it will be animated as raising, then teleported afterwards. Either way, it's all on the admin level.*/
		for(var/turf/T in away_area)
			elevator_animation.vis_contents += T

		for(var/turf/i in elevator_animation.vis_contents)
			i.layer = elevator_animation.layer + 0.01
			i.plane = elevator_animation.plane
			for(var/obj/o in i)
				o.layer = elevator_animation.layer + 0.01
				o.plane = elevator_animation.plane

		//If we are at the away_area then we are just pretending to move, otherwise actually do the move
		if (target_zlevel && fake_zlevel == null)
			move_elevator_up(origin, destination)
		else if(target_zlevel == null && fake_zlevel)
			move_elevator_down(origin, destination)
		else if(fake_zlevel < target_zlevel)
			move_elevator_up(origin, destination)
		else if(fake_zlevel > target_zlevel)
			move_elevator_down(origin, destination)

		var/area/target_area
		if(!target_zlevel)
			target_area = area_offsite
		else
			target_area = get_area(GLOB.supply_elevator_turfs[target_zlevel])
		fake_zlevel = target_area.fake_zlevel

		moving_status = SHUTTLE_IDLE
		stop_gears()
		elevator_animation.vis_contents.Cut()

		if (!at_station())	//at centcom
			handle_sell()
		else
			lower_railings()

		spawn(0)
			recharging = 0

/datum/shuttle/ferry/supply/multi/proc/move_elevator_down(origin, destination)
	playsound(locate(Elevator_x,Elevator_y,Elevator_z), 'sound/machines/asrs_lowering.ogg', 50, 0)
	move(origin, destination)
	animate(elevator_animation, pixel_y = -180, time = 2 SECONDS)
	start_gears(SOUTH)
	sleep(21)
	sleep(70)

/datum/shuttle/ferry/supply/multi/proc/move_elevator_up(origin, destination)
	playsound(locate(Elevator_x,Elevator_y,Elevator_z), 'sound/machines/asrs_raising.ogg', 50, 0)
	start_gears(NORTH)
	sleep(70)
	animate(elevator_animation, pixel_x = 0, pixel_y = 0, time = 2 SECONDS)
	sleep(2 SECONDS)
	move(origin, destination)

/datum/shuttle/ferry/supply/multi/move(area/origin, area/destination)
	update_shaft_projectors(1)
	update_shaft_effects(1)
	..()
	for(var/turf/T in get_area(GLOB.supply_elevator_turfs[target_zlevel]))
		T.layer = initial(T.layer)
		T.plane = initial(T.plane)
	for(var/obj/O in get_area(GLOB.supply_elevator_turfs[target_zlevel]))
		O.layer = initial(O.layer)
		O.plane = initial(O.plane)
	update_shaft_effects(2)
	update_shaft_projectors(2)

/datum/shuttle/ferry/supply/multi/proc/update_shaft_effects(mode)
	message_admins("update_shaft_effects()-->mode:[mode] \n target_zlevel:[target_zlevel] \n fake_zlevel:[fake_zlevel]")
	switch(mode)
		if(1)
			if(target_zlevel)
				elevator_effects["[target_zlevel]SW"].moveToNullspace()
				elevator_effects["[target_zlevel]SE"].moveToNullspace()
				elevator_effects["[target_zlevel]NW"].moveToNullspace()
				elevator_effects["[target_zlevel]NE"].moveToNullspace()
			if(fake_zlevel)
				elevator_effects["[fake_zlevel]SW"].moveToNullspace()
				elevator_effects["[fake_zlevel]SE"].moveToNullspace()
				elevator_effects["[fake_zlevel]NW"].moveToNullspace()
				elevator_effects["[fake_zlevel]NE"].moveToNullspace()
		if(2)
			if(target_zlevel)
				var/turf/turf_arrived_at = GLOB.supply_elevator_turfs[target_zlevel]
				elevator_effects["[target_zlevel]SW"].forceMove(locate(turf_arrived_at.x-2, turf_arrived_at.y-2, turf_arrived_at.z))
				elevator_effects["[target_zlevel]SE"].forceMove(locate(turf_arrived_at.x+2, turf_arrived_at.y-2, turf_arrived_at.z))
				elevator_effects["[target_zlevel]NW"].forceMove(locate(turf_arrived_at.x-2, turf_arrived_at.y+2, turf_arrived_at.z))
				elevator_effects["[target_zlevel]NE"].forceMove(locate(turf_arrived_at.x+2, turf_arrived_at.y+2, turf_arrived_at.z))
			if(fake_zlevel)
				var/turf/departing_from_turf = GLOB.supply_elevator_turfs[fake_zlevel]
				elevator_effects["[fake_zlevel]SW"].forceMove(locate(departing_from_turf.x-2, departing_from_turf.y-2, departing_from_turf.z))
				elevator_effects["[fake_zlevel]SE"].forceMove(locate(departing_from_turf.x+2, departing_from_turf.y-2, departing_from_turf.z))
				elevator_effects["[fake_zlevel]NW"].forceMove(locate(departing_from_turf.x-2, departing_from_turf.y+2, departing_from_turf.z))
				elevator_effects["[fake_zlevel]NE"].forceMove(locate(departing_from_turf.x+2, departing_from_turf.y+2, departing_from_turf.z))

/datum/shuttle/ferry/supply/multi/proc/update_shaft_projectors(mode)
	//this assumes the projectors are from lower zlevels [FROM INSIDE A SHAFT]
	//and that lower zlevels are ordered from 1 up moving downwards
	//all logic handled by /datum/controller/subsystem/fz_transitions/fire()
	message_admins("update_shaft_projectors()-->mode:[mode] \n target_zlevel:[target_zlevel] \n fake_zlevel:[fake_zlevel]")
	switch(mode)
		if(1)
			if(target_zlevel && target_zlevel + 1 <= length(GLOB.supply_elevator_turfs))
				for(var/obj/effect/projector/P in shaft_projectors[target_zlevel + 1])
					P.update_state(TRUE)

				for(var/obj/effect/projector/P in shaft_projectors[target_zlevel])
					P.update_state(TRUE)
			if(fake_zlevel && fake_zlevel != target_zlevel + 1)
				for(var/obj/effect/projector/P in shaft_projectors[fake_zlevel])
					P.update_state(TRUE)
		if(2)
			if(target_zlevel)
				for(var/obj/effect/projector/P in shaft_projectors[target_zlevel])
					P.update_state(FALSE)

			if(fake_zlevel && fake_zlevel + 1 <= length(GLOB.supply_elevator_turfs))
				for(var/obj/effect/projector/P in shaft_projectors[fake_zlevel + 1])
					P.update_state(FALSE)

				if(fake_zlevel != target_zlevel + 1)
					for(var/obj/effect/projector/P in shaft_projectors[fake_zlevel])
						P.update_state(FALSE)

/datum/shuttle/ferry/supply/multi/forbidden_atoms_check()
	if(target_zlevel != 0 || target_zlevel != null)
		return FALSE
	else
		return ..()

/obj/item/elevator_contoller
	name = "Freight Elevator Controller"
	icon = 'icons/obj/items/misc.dmi'
	icon_state = "elevator_control"

	w_class = SIZE_LARGE

	var/obj/structure/elevator_control_mount/attached_to
	var/datum/effects/tethering/tether_effect

	var/zlevel_transfer = FALSE
	var/zlevel_transfer_timer = TIMER_ID_NULL
	var/zlevel_transfer_timeout = 5 SECONDS

/obj/item/elevator_contoller/Initialize(mapload)
	. = ..()
	if(istype(loc, /obj/structure/elevator_control_mount))
		attach_to(loc)

/obj/item/elevator_contoller/Destroy()
	remove_attached()
	return ..()

/obj/item/elevator_contoller/proc/attach_to(var/obj/structure/elevator_control_mount/to_attach)
	if(!istype(to_attach))
		return

	remove_attached()

	attached_to = to_attach

/obj/item/elevator_contoller/proc/remove_attached()
	attached_to = null
	reset_tether()

/obj/item/elevator_contoller/proc/reset_tether()
	SIGNAL_HANDLER
	if (tether_effect)
		UnregisterSignal(tether_effect, COMSIG_PARENT_QDELETING)
		if(!QDESTROYING(tether_effect))
			qdel(tether_effect)
		tether_effect = null
	if(!do_zlevel_check())
		on_beam_removed()

/obj/item/elevator_contoller/attack_hand(mob/user)
	if(attached_to && get_dist(user, attached_to) > attached_to.range)
		return FALSE
	return ..()


/obj/item/elevator_contoller/proc/on_beam_removed()
	if(!attached_to)
		return

	if(loc == attached_to)
		return

	if(get_dist(attached_to, src) > attached_to.range)
		attached_to.recall_phone()

	var/atom/tether_to = src

	if(loc != get_turf(src))
		tether_to = loc
		if(tether_to.loc != get_turf(tether_to))
			attached_to.recall_phone()
			return

	var/atom/tether_from = attached_to

	if(attached_to.tether_holder)
		tether_from = attached_to.tether_holder

	if(tether_from == tether_to)
		return

	var/list/tether_effects = apply_tether(tether_from, tether_to, range = attached_to.range, icon = "wire", always_face = FALSE)
	tether_effect = tether_effects["tetherer_tether"]
	RegisterSignal(tether_effect, COMSIG_PARENT_QDELETING, .proc/reset_tether)

/obj/item/elevator_contoller/attack_self(mob/user)
	. = ..()

/obj/item/elevator_contoller/dropped(var/mob/user)
	. = ..()
	UnregisterSignal(user, COMSIG_LIVING_SPEAK)

/obj/item/elevator_contoller/on_enter_storage(obj/item/storage/S)
	. = ..()
	if(attached_to)
		attached_to.recall_phone()

/obj/item/elevator_contoller/forceMove(atom/dest)
	. = ..()
	if(.)
		reset_tether()

/obj/item/elevator_contoller/proc/do_zlevel_check()
	if(!attached_to || !loc.z || !attached_to.z)
		return FALSE

	if(zlevel_transfer)
		if(loc.z == attached_to.z)
			zlevel_transfer = FALSE
			if(zlevel_transfer_timer)
				deltimer(zlevel_transfer_timer)
			UnregisterSignal(attached_to, COMSIG_MOVABLE_MOVED)
			return FALSE
		return TRUE

	if(attached_to && loc.z != attached_to.z)
		zlevel_transfer = TRUE
		zlevel_transfer_timer = addtimer(CALLBACK(src, .proc/try_doing_tether), zlevel_transfer_timeout, TIMER_UNIQUE|TIMER_STOPPABLE)
		//RegisterSignal(attached_to, COMSIG_MOVABLE_MOVED, .proc/transmitter_move_handler)
		return TRUE
	return FALSE


/obj/item/elevator_contoller/proc/try_doing_tether()
	zlevel_transfer_timer = TIMER_ID_NULL
	zlevel_transfer = FALSE
	UnregisterSignal(attached_to, COMSIG_MOVABLE_MOVED)
	reset_tether()

// ------------- HERE BE YE OLDE INDUSTRIAL ELEVATOR CONTROLLER MOUNT STRUCTURE ------------

/obj/structure/elevator_control_mount
	name = "Elevator Control"
	icon = 'icons/obj/structures/structures.dmi'
	icon_state = "elevator_control"
	desc = "This holds the elevator controller. What a fine piece of technology."
	pixel_y = 28

	var/obj/item/elevator_contoller/attached_to
	var/atom/tether_holder

	var/range = 3

	var/enabled = TRUE

/obj/structure/elevator_control_mount/Initialize(mapload, ...)
	. = ..()

	attached_to = new /obj/item/elevator_contoller(src)
	RegisterSignal(attached_to, COMSIG_PARENT_PREQDELETED, .proc/override_delete)

/obj/structure/elevator_control_mount/update_icon()
	. = ..()

	if(attached_to in contents)
		icon_state = initial(icon_state)
	else
		icon_state = "[initial(icon_state)]_hand"

/obj/structure/elevator_control_mount/attack_hand(mob/user)
	. = ..()

	if(!attached_to || attached_to.loc != src)
		return

	if(!ishuman(user))
		return

	if(!enabled)
		return

	user.put_in_active_hand(attached_to)
	update_icon()

/obj/structure/elevator_control_mount/proc/recall_phone()
	if(ismob(attached_to.loc))
		var/mob/M = attached_to.loc
		M.drop_held_item(attached_to)
		playsound(get_turf(M), "rtb_handset", 100, FALSE, 7)

	attached_to.forceMove(src)

	update_icon()

/obj/structure/elevator_control_mount/proc/override_delete()
	SIGNAL_HANDLER
	recall_phone()
	return COMPONENT_ABORT_QDEL

/obj/structure/elevator_control_mount/proc/set_tether_holder(var/atom/A)
	tether_holder = A

	if(attached_to)
		attached_to.reset_tether()

/obj/structure/elevator_control_mount/attackby(obj/item/W, mob/user)
	if(W == attached_to)
		recall_phone()
	else
		. = ..()

/obj/structure/elevator_control_mount/Destroy()
	if(attached_to)
		if(attached_to.loc == src)
			UnregisterSignal(attached_to, COMSIG_PARENT_PREQDELETED)
			qdel(attached_to)
		else
			attached_to.attached_to = null
			attached_to = null

	return ..()
