/**
 * Records subtype for the shared functionality between medical/security/warrant consoles.
 */
/obj/machinery/computer/records
	/// The character preview view for the UI.
	var/atom/movable/screen/map_view/char_preview/character_preview_view

/obj/machinery/computer/records/ui_data(mob/user)
	var/list/data = list()

	var/has_access = (authenticated && isliving(user)) || isAdminGhostAI(user)
	data["authenticated"] = has_access
	if(!has_access)
		return data

	data["assigned_view"] = "preview_[user.ckey]_[REF(src)]_records"
	data["station_z"] = !!(z && is_station_level(z))

	return data

/obj/machinery/computer/records/ui_act(action, list/params, datum/tgui/ui)
	. = ..()
	if(.)
		return

	var/datum/record/crew/target
	if(params["crew_ref"])
		target = locate(params["crew_ref"]) in GLOB.manifest.general

	switch(action)
		if("edit_field")
			target = locate(params["ref"]) in GLOB.manifest.general
			var/field = params["field"]
			if(!field || !(field in target?.vars))
				return FALSE

			var/value = trim(params["value"], MAX_BROADCAST_LEN)
			investigate_log("[key_name(usr)] changed the field: \"[field]\" with value: \"[target.vars[field]]\" to new value: \"[value || "Unknown"]\"", INVESTIGATE_RECORDS)
			target.vars[field] = value || "Unknown"

			return TRUE

		if("expunge_record")
			if(!target)
				return FALSE
			// Don't let people off station futz with the station network.
			if(!is_station_level(z))
				balloon_alert(usr, "out of range!")
				return TRUE

			expunge_record_info(target)
			balloon_alert(usr, "record expunged")
			playsound(src, 'sound/machines/terminal_eject.ogg', 70, TRUE)
			investigate_log("[key_name(usr)] expunged the record of [target.name].", INVESTIGATE_RECORDS)

			return TRUE

		if("login")
			authenticated = secure_login(usr)
			investigate_log("[key_name(usr)] [authenticated ? "successfully logged" : "failed to log"] into the [src].", INVESTIGATE_RECORDS)
			return TRUE

		if("logout")
			balloon_alert(usr, "logged out")
			playsound(src, 'sound/machines/terminal_off.ogg', 70, TRUE)
			authenticated = FALSE

			return TRUE

		if("purge_records")
			// Don't let people off station futz with the station network.
			//NOVA EDIT BEGIN: disable record purging/expunging to stop people messing around with the AI effortlessly
			balloon_alert(usr, "access denied!")
			return TRUE
			/*
			if(!is_station_level(z))
				balloon_alert(usr, "out of range!")
				return TRUE

			ui.close()
			balloon_alert(usr, "purging records...")
			playsound(src, 'sound/machines/terminal_alert.ogg', 70, TRUE)

			if(do_after(usr, 5 SECONDS))
				for(var/datum/record/crew/entry in GLOB.manifest.general)
					expunge_record_info(entry)

				balloon_alert(usr, "records purged")
				playsound(src, 'sound/machines/terminal_off.ogg', 70, TRUE)
				investigate_log("[key_name(usr)] purged all records.", INVESTIGATE_RECORDS)
			else
				balloon_alert(usr, "interrupted!")

			return TRUE
			*/
			//NOVA EDIT END

		if("view_record")
			if(!target)
				return FALSE

			playsound(src, "sound/machines/terminal_button0[rand(1, 8)].ogg", 50, TRUE)
			update_preview(usr, params["assigned_view"], target)
			return TRUE

	return FALSE

/// Creates a character preview view for the UI.
/obj/machinery/computer/records/proc/create_character_preview_view(mob/user)
	var/assigned_view = "preview_[user.ckey]_[REF(src)]_records"
	if(user.client?.screen_maps[assigned_view])
		return

	var/atom/movable/screen/map_view/char_preview/new_view = new(null, src)
	new_view.generate_view(assigned_view)
	new_view.display_to(user)

/// Takes a record and updates the character preview view to match it.
/obj/machinery/computer/records/proc/update_preview(mob/user, assigned_view, datum/record/crew/target)
	var/mutable_appearance/preview = new(target.character_appearance)
	preview.underlays += mutable_appearance('icons/effects/effects.dmi', "static_base", alpha = 20)
	preview.add_overlay(mutable_appearance(generate_icon_alpha_mask('icons/effects/effects.dmi', "scanline"), alpha = 20))

	var/atom/movable/screen/map_view/char_preview/old_view = user.client?.screen_maps[assigned_view]?[1]
	if(!old_view)
		return

	old_view.appearance = preview.appearance

/// Expunges info from a record.
/obj/machinery/computer/records/proc/expunge_record_info(datum/record/crew/target)
	return

/// Inserts a new record into GLOB.manifest.general. Requires a photo to be taken.
/obj/machinery/computer/records/proc/insert_new_record(mob/user, obj/item/photo/mugshot)
	if(!mugshot || !is_operational || !user.can_perform_action(src, ALLOW_SILICON_REACH))
		return FALSE

	if(!authenticated && !allowed(user))
		balloon_alert(user, "access denied")
		playsound(src, 'sound/machines/terminal_error.ogg', 70, TRUE)
		return FALSE

	if(mugshot.picture.psize_x > world.icon_size || mugshot.picture.psize_y > world.icon_size)
		balloon_alert(user, "photo too large!")
		playsound(src, 'sound/machines/terminal_error.ogg', 70, TRUE)
		return FALSE

	var/trimmed = copytext(mugshot.name, 9, MAX_NAME_LEN) // Remove "photo - "
	var/name = tgui_input_text(user, "Enter the name of the new record.", "New Record", trimmed, MAX_NAME_LEN)
	if(!name || !is_operational || !user.can_perform_action(src, ALLOW_SILICON_REACH) || !mugshot || QDELETED(mugshot) || QDELETED(src))
		return FALSE

	new /datum/record/crew(name = name, character_appearance = mugshot.picture.picture_image)

	balloon_alert(user, "record created")
	playsound(src, 'sound/machines/terminal_insert_disc.ogg', 70, TRUE)

	qdel(mugshot)

	return TRUE

/// Secure login
/obj/machinery/computer/records/proc/secure_login(mob/user)
	if(!user.can_perform_action(src, ALLOW_SILICON_REACH) || !is_operational)
		return FALSE

	if(!allowed(user))
		balloon_alert(user, "access denied")
		playsound(src, 'sound/machines/terminal_error.ogg', 70, TRUE)
		return FALSE

	balloon_alert(user, "logged in")
	playsound(src, 'sound/machines/terminal_on.ogg', 70, TRUE)

	return TRUE
