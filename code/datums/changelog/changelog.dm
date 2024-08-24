/datum/changelog
	var/static/list/changelog_items = list()
	//QUADRANT69 EDIT ADDITION BEGIN - Q69_MODULE_NOID - (We add separate list for Q69 changelog.)
	var/static/list/changelog_items_q69 = list()
	//QUADRANT69 EDIT ADDITION END

/datum/changelog/ui_state()
	return GLOB.always_state

/datum/changelog/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if (!ui)
		ui = new(user, src, "Changelog")
		ui.open()

/datum/changelog/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(action == "get_month")
		//QUADRANT69 EDIT REMOVAL BEGIN - Q69_MODULE_NOID
		/*
		var/datum/asset/changelog_item/changelog_item = changelog_items[params["date"]]
		if (!changelog_item)
			changelog_item = new /datum/asset/changelog_item(params["date"])
			changelog_items[params["date"]] = changelog_item
		return ui.send_asset(changelog_item)
		*/
		//QUADRANT69 EDIT REMOVAL END
		//QUADRANT69 EDIT ADDITION BEGIN - Q69_MODULE_NOID - (Return assets based if we want upstream changelog or not.)
		if (params["upstreamChangelog"])
			var/datum/asset/changelog_item/changelog_item = changelog_items_q69[params["date"]]
			if (!changelog_item)
				changelog_item = new /datum/asset/changelog_item(params["date"], params["upstreamChangelog"])
				changelog_items_q69[params["date"]] = changelog_item
			return ui.send_asset(changelog_item)
		else
			var/datum/asset/changelog_item/changelog_item = changelog_items[params["date"]]
			if (!changelog_item)
				changelog_item = new /datum/asset/changelog_item(params["date"], params["upstreamChangelog"])
				changelog_items[params["date"]] = changelog_item
			return ui.send_asset(changelog_item)
		//QUADRANT69 EDIT ADDITION END

/datum/changelog/ui_static_data()
	//QUADRANT69 EDIT CHANGE BEGIN - Q69_MODULE_NOID
	var/list/data = list( "dates" = list(), "dates_q69" = list() )
	//var/list/data = list( "dates" = list() ) - QUADRANT69 EDIT - ORIGINAL
	//QUADRANT69 EDIT CHANGE END
	var/regex/ymlRegex = regex(@"\.yml", "g")

	for(var/archive_file in sort_list(flist("html/changelogs/archive/")))
		var/archive_date = ymlRegex.Replace(archive_file, "")
		data["dates"] = list(archive_date) + data["dates"]
	//QUADRANT69 EDIT ADDITION BEGIN - Q69_MODULE_NOID
	for(var/archive_file_q69 in sort_list(flist("html/changelogs_q69/archive/")))
		var/archive_date_q69 = ymlRegex.Replace(archive_file_q69, "")
		data["dates_q69"] = list(archive_date_q69) + data["dates_q69"]
	//QUADRANT69 EDIT ADDITION END
	return data
