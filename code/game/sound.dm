/proc/playsound(atom/source, soundin, vol as num, vary, extrarange as num, falloff, frequency = null, channel = 0, pressure_affected = TRUE, ignore_walls = TRUE)
	if(isarea(source))
		CRASH("playsound(): source is an area")

	var/turf/turf_source = get_turf(source)

	if (!turf_source)
		return

	//allocate a channel if necessary now so its the same for everyone
	channel = channel || open_sound_channel()

 	// Looping through the player list has the added bonus of working for mobs inside containers
	var/sound/S = sound(get_sfx(soundin))
	var/maxdistance = (world.view * 2 + extrarange)
	var/z = turf_source.z
	var/list/listeners = SSmobs.clients_by_zlevel[z].Copy()
	if(!ignore_walls) //these sounds don't carry through walls
		listeners = listeners & hearers(maxdistance,turf_source)
	for(var/P in listeners)
		var/mob/M = P
		if(get_dist(M, turf_source) <= maxdistance)
			M.playsound_local(turf_source, soundin, vol, vary, frequency, falloff, channel, pressure_affected, S)
	for(var/P in SSmobs.dead_players_by_zlevel[z])
		var/mob/M = P
		if(get_dist(M, turf_source) <= maxdistance)
			M.playsound_local(turf_source, soundin, vol, vary, frequency, falloff, channel, pressure_affected, S)

/mob/proc/playsound_local(turf/turf_source, soundin, vol as num, vary, frequency, falloff, channel = 0, pressure_affected = TRUE, sound/S)
	if(!client || !can_hear())
		return

	if(!S)
		S = sound(get_sfx(soundin))

	S.wait = 0 //No queue
	S.channel = channel || open_sound_channel()
	S.volume = vol
	S.falloff = (falloff ? falloff : FALLOFF_SOUNDS)
	S.frequency = frequency

	if(vary && !frequency)
		S.frequency = get_rand_frequency()

	var/direct = 0
	var/room   = -10000
	if(isturf(turf_source))
		var/turf/T = get_turf(src)

		//sound volume falloff with distance
		var/distance = get_dist(T, turf_source)

		S.volume -= max(distance - falloff, 0) * 2 //multiplicative falloff to add on top of natural audio falloff.

		if(get_area(T) == get_area(turf_source))
			direct = 0
			room   = -250
		else
			direct = -distance * 100
			room   = 0
		if(pressure_affected)
			//Atmosphere affects sound
			var/pressure_factor = 1
			var/datum/gas_mixture/hearer_env = T.return_air()
			var/datum/gas_mixture/source_env = turf_source.return_air()

			if(hearer_env && source_env)
				var/pressure = min(hearer_env.return_pressure(), source_env.return_pressure())
				if(pressure < ONE_ATMOSPHERE)
					pressure_factor = max((pressure - SOUND_MINIMUM_PRESSURE)/(ONE_ATMOSPHERE - SOUND_MINIMUM_PRESSURE), 0)
			else //space
				pressure_factor = 0

			if(distance <= 1)
				pressure_factor = max(pressure_factor, 0.15) //touching the source of the sound

			S.volume *= pressure_factor
			//End Atmosphere affecting sound

		var/dx = turf_source.x - T.x // Hearing from the right/left
		S.x = dx
		var/dz = turf_source.y - T.y // Hearing from infront/behind
		S.z = dz
		// The y value is for above your head, but there is no ceiling in 2d spessmens.
		S.y = 1

	//SOUND_MUTE signalizes the sound should play despite volume == 0
	if(S.volume == 0 && !(S.status & SOUND_UPDATE) && !(S.status & SOUND_MUTE))
		return
	S.environment = 7
	S.echo = list(direct, null, room, null, null, null, null, null, null, null, null, null, null, 1, 1, 1, null, null)
	SEND_SOUND(src, S)

/proc/sound_to_playing_players(soundin, volume = 100, vary = FALSE, frequency = 0, falloff = FALSE, channel = 0, pressure_affected = FALSE, sound/S)
	if(!S)
		S = sound(get_sfx(soundin))
	for(var/m in GLOB.player_list)
		if(ismob(m) && !isnewplayer(m))
			var/mob/M = m
			M.playsound_local(M, null, volume, vary, frequency, falloff, channel, pressure_affected, S)

/proc/open_sound_channel()
	var/static/next_channel = 1	//loop through the available 1024 - (the ones we reserve) channels and pray that its not still being used
	. = ++next_channel
	if(next_channel > CHANNEL_HIGHEST_AVAILABLE)
		next_channel = 1

/mob/proc/stop_sound_channel(chan)
	SEND_SOUND(src, sound(null, repeat = 0, wait = 0, channel = chan))

/client/proc/playtitlemusic(vol = MUSIC_VOLUME)
	set waitfor = FALSE
	UNTIL(SSticker.login_music) //wait for SSticker init to set the login music

	if(prefs && (prefs.toggles & SOUND_LOBBY))
		SEND_SOUND(src, sound(SSticker.login_music, repeat = 0, wait = 0, volume = vol, channel = CHANNEL_LOBBYMUSIC)) // MAD JAMS

/proc/get_rand_frequency()
	return rand(32000, 55000) //Frequency stuff only works with 45kbps oggs.

/proc/get_sfx(soundin)
	if(istext(soundin))
		switch(soundin)
			if ("shatter")
				soundin = pick('sound/effects/glassbr1.ogg','sound/effects/glassbr2.ogg','sound/effects/glassbr3.ogg')
			if ("explosion")
				soundin = pick('sound/effects/explosion1.ogg','sound/effects/explosion2.ogg')
			if ("sparks")
				soundin = pick('sound/effects/sparks1.ogg','sound/effects/sparks2.ogg','sound/effects/sparks3.ogg','sound/effects/sparks4.ogg')
			if ("rustle")
				soundin = pick('sound/effects/rustle1.ogg','sound/effects/rustle2.ogg','sound/effects/rustle3.ogg','sound/effects/rustle4.ogg','sound/effects/rustle5.ogg')
			if ("bodyfall")
				soundin = pick('sound/effects/bodyfall1.ogg','sound/effects/bodyfall2.ogg','sound/effects/bodyfall3.ogg','sound/effects/bodyfall4.ogg')
			if ("punch")
				soundin = pick('sound/weapons/punch1.ogg','sound/weapons/punch2.ogg','sound/weapons/punch3.ogg','sound/weapons/punch4.ogg')
			if ("clownstep")
				soundin = pick('sound/effects/clownstep1.ogg','sound/effects/clownstep2.ogg')
			if ("suitstep")
				soundin = pick('sound/effects/suitstep1.ogg','sound/effects/suitstep2.ogg')
			if ("swing_hit")
				soundin = pick('sound/weapons/genhit1.ogg', 'sound/weapons/genhit2.ogg', 'sound/weapons/genhit3.ogg')
			if ("hiss")
				soundin = pick('sound/voice/hiss1.ogg','sound/voice/hiss2.ogg','sound/voice/hiss3.ogg','sound/voice/hiss4.ogg')
			if ("pageturn")
				soundin = pick('sound/effects/pageturn1.ogg', 'sound/effects/pageturn2.ogg','sound/effects/pageturn3.ogg')
			if ("ricochet")
				soundin = pick(	'sound/weapons/effects/ric1.ogg', 'sound/weapons/effects/ric2.ogg','sound/weapons/effects/ric3.ogg','sound/weapons/effects/ric4.ogg','sound/weapons/effects/ric5.ogg')
			if ("terminal_type")
				soundin = pick('sound/machines/terminal_button01.ogg', 'sound/machines/terminal_button02.ogg', 'sound/machines/terminal_button03.ogg', \
								'sound/machines/terminal_button04.ogg', 'sound/machines/terminal_button05.ogg', 'sound/machines/terminal_button06.ogg', \
								'sound/machines/terminal_button07.ogg', 'sound/machines/terminal_button08.ogg')
			if ("desceration")
				soundin = pick('sound/misc/desceration-01.ogg', 'sound/misc/desceration-02.ogg', 'sound/misc/desceration-03.ogg')
			if ("im_here")
				soundin = pick('sound/hallucinations/im_here1.ogg', 'sound/hallucinations/im_here2.ogg')
			if ("can_open")
				soundin = pick('sound/effects/can_open1.ogg', 'sound/effects/can_open2.ogg', 'sound/effects/can_open3.ogg')
			if("bullet_miss")
				soundin = pick('sound/weapons/bulletflyby.ogg', 'sound/weapons/bulletflyby2.ogg', 'sound/weapons/bulletflyby3.ogg')
			if("gun_insert_empty_magazine")
				soundin = pick('sound/weapons/gun_magazine_insert_empty_1.ogg', 'sound/weapons/gun_magazine_insert_empty_2.ogg', 'sound/weapons/gun_magazine_insert_empty_3.ogg', 'sound/weapons/gun_magazine_insert_empty_4.ogg')
			if("gun_insert_full_magazine")
				soundin = pick('sound/weapons/gun_magazine_insert_full_1.ogg', 'sound/weapons/gun_magazine_insert_full_2.ogg', 'sound/weapons/gun_magazine_insert_full_3.ogg', 'sound/weapons/gun_magazine_insert_full_4.ogg', 'sound/weapons/gun_magazine_insert_full_5.ogg')
			if("gun_remove_empty_magazine")
				soundin = pick('sound/weapons/gun_magazine_remove_empty_1.ogg', 'sound/weapons/gun_magazine_remove_empty_2.ogg', 'sound/weapons/gun_magazine_remove_empty_3.ogg', 'sound/weapons/gun_magazine_remove_empty_4.ogg')
			if("gun_slide_lock")
				soundin = pick('sound/weapons/gun_slide_lock_1.ogg', 'sound/weapons/gun_slide_lock_2.ogg', 'sound/weapons/gun_slide_lock_3.ogg', 'sound/weapons/gun_slide_lock_4.ogg', 'sound/weapons/gun_slide_lock_5.ogg')
			if("revolver_spin")
				soundin = pick('sound/weapons/revolverspin1.ogg', 'sound/weapons/revolverspin2.ogg', 'sound/weapons/revolverspin3.ogg')
			if("law")
				soundin = pick('sound/voice/beepsky/god.ogg', 'sound/voice/beepsky/iamthelaw.ogg', 'sound/voice/beepsky/secureday.ogg', 'sound/voice/beepsky/radio.ogg', 'sound/voice/beepsky/insult.ogg', 'sound/voice/beepsky/creep.ogg')
			if("honkbot_e")
				soundin = pick('sound/items/bikehorn.ogg', 'sound/items/AirHorn2.ogg', 'sound/misc/sadtrombone.ogg', 'sound/items/AirHorn.ogg', 'sound/effects/reee.ogg',  'sound/items/WEEOO1.ogg', 'sound/voice/beepsky/iamthelaw.ogg', 'sound/voice/beepsky/creep.ogg','sound/magic/Fireball.ogg' ,'sound/effects/pray.ogg', 'sound/voice/hiss1.ogg','sound/machines/buzz-sigh.ogg', 'sound/machines/ping.ogg', 'sound/weapons/flashbang.ogg', 'sound/weapons/bladeslice.ogg')
			if("allah")
				soundin = pick('sound/items/Alah.ogg', 'sound/items/alah_grib.ogg')
			if("goose")
				soundin = pick('sound/creatures/goose1.ogg', 'sound/creatures/goose2.ogg', 'sound/creatures/goose3.ogg', 'sound/creatures/goose4.ogg')
			if("smcalm")
				soundin = pick('sound/machines/sm/accent/normal/1.ogg', 'sound/machines/sm/accent/normal/2.ogg', 'sound/machines/sm/accent/normal/3.ogg', 'sound/machines/sm/accent/normal/4.ogg', 'sound/machines/sm/accent/normal/5.ogg', 'sound/machines/sm/accent/normal/6.ogg', 'sound/machines/sm/accent/normal/7.ogg', 'sound/machines/sm/accent/normal/8.ogg', 'sound/machines/sm/accent/normal/9.ogg', 'sound/machines/sm/accent/normal/10.ogg', 'sound/machines/sm/accent/normal/11.ogg', 'sound/machines/sm/accent/normal/12.ogg', 'sound/machines/sm/accent/normal/13.ogg', 'sound/machines/sm/accent/normal/14.ogg', 'sound/machines/sm/accent/normal/15.ogg', 'sound/machines/sm/accent/normal/16.ogg', 'sound/machines/sm/accent/normal/17.ogg', 'sound/machines/sm/accent/normal/18.ogg', 'sound/machines/sm/accent/normal/19.ogg', 'sound/machines/sm/accent/normal/20.ogg', 'sound/machines/sm/accent/normal/21.ogg', 'sound/machines/sm/accent/normal/22.ogg', 'sound/machines/sm/accent/normal/23.ogg', 'sound/machines/sm/accent/normal/24.ogg', 'sound/machines/sm/accent/normal/25.ogg', 'sound/machines/sm/accent/normal/26.ogg', 'sound/machines/sm/accent/normal/27.ogg', 'sound/machines/sm/accent/normal/28.ogg', 'sound/machines/sm/accent/normal/29.ogg', 'sound/machines/sm/accent/normal/30.ogg', 'sound/machines/sm/accent/normal/31.ogg', 'sound/machines/sm/accent/normal/32.ogg', 'sound/machines/sm/accent/normal/33.ogg')
			if("smdelam")
				soundin = pick('sound/machines/sm/accent/delam/1.ogg', 'sound/machines/sm/accent/normal/2.ogg', 'sound/machines/sm/accent/normal/3.ogg', 'sound/machines/sm/accent/normal/4.ogg', 'sound/machines/sm/accent/normal/5.ogg', 'sound/machines/sm/accent/normal/6.ogg', 'sound/machines/sm/accent/normal/7.ogg', 'sound/machines/sm/accent/normal/8.ogg', 'sound/machines/sm/accent/normal/9.ogg', 'sound/machines/sm/accent/normal/10.ogg', 'sound/machines/sm/accent/normal/11.ogg', 'sound/machines/sm/accent/normal/12.ogg', 'sound/machines/sm/accent/normal/13.ogg', 'sound/machines/sm/accent/normal/14.ogg', 'sound/machines/sm/accent/normal/15.ogg', 'sound/machines/sm/accent/normal/16.ogg', 'sound/machines/sm/accent/normal/17.ogg', 'sound/machines/sm/accent/normal/18.ogg', 'sound/machines/sm/accent/normal/19.ogg', 'sound/machines/sm/accent/normal/20.ogg', 'sound/machines/sm/accent/normal/21.ogg', 'sound/machines/sm/accent/normal/22.ogg', 'sound/machines/sm/accent/normal/23.ogg', 'sound/machines/sm/accent/normal/24.ogg', 'sound/machines/sm/accent/normal/25.ogg', 'sound/machines/sm/accent/normal/26.ogg', 'sound/machines/sm/accent/normal/27.ogg', 'sound/machines/sm/accent/normal/28.ogg', 'sound/machines/sm/accent/normal/29.ogg', 'sound/machines/sm/accent/normal/30.ogg', 'sound/machines/sm/accent/normal/31.ogg', 'sound/machines/sm/accent/normal/32.ogg', 'sound/machines/sm/accent/normal/33.ogg')
			if("dog")
				soundin = pickweight(list('sound/voice/speech/dog1.ogg' = 49, 'sound/voice/speech/dogarf.ogg' = 1))
			if("cat")
				soundin = pick('sound/voice/speech/cat1.ogg')
			if("monkey")
				soundin = pick('sound/voice/speech/monkey1.ogg', 'sound/voice/speech/monkey2.ogg')
			if("parrot")
				soundin = pick('sound/voice/speech/parrot1.ogg', 'sound/voice/speech/parrot2.ogg', 'sound/voice/speech/parrot3.ogg')
			if("slime")
				soundin = pick('sound/voice/speech/slime1.ogg')
			if("humanmale")
				soundin = pick('sound/voice/speech/humanmale1.ogg', 'sound/voice/speech/humanmale2.ogg', 'sound/voice/speech/humanmale3.ogg', 'sound/voice/speech/humanmale4.ogg', 'sound/voice/speech/humanmale5.ogg')
			if("humanfemale")
				soundin = pick('sound/voice/speech/humanfemale1.ogg', 'sound/voice/speech/humanfemale2.ogg', 'sound/voice/speech/humanfemale3.ogg', 'sound/voice/speech/humanfemale4.ogg')
			if("humanplural")
				soundin = pick('sound/voice/speech/humanplural.ogg')
			if("lizard")
				soundin = pick('sound/voice/speech/lizard1.ogg', 'sound/voice/speech/lizard2.ogg', 'sound/voice/speech/lizard3.ogg')
			if("moth")
				soundin = pick('sound/voice/speech/moth1.ogg', 'sound/voice/speech/moth2.ogg', 'sound/voice/speech/moth3.ogg')
			if("chatter")
				soundin = pick('sound/voice/speech/chatter1.ogg', 'sound/voice/speech/chatter2.ogg')
			if("synthetic")
				soundin = pick('sound/voice/speech/synthetic1.ogg', 'sound/voice/speech/synthetic2.ogg', 'sound/voice/speech/synthetic3.ogg')
			if("insect")
				soundin = pick('sound/voice/speech/insect1.ogg', 'sound/voice/speech/insect2.ogg', 'sound/voice/speech/insect3.ogg')
			if("drone")
				soundin = pick('sound/voice/speech/drone1.ogg', 'sound/voice/speech/drone2.ogg', 'sound/voice/speech/drone3.ogg')
			if("plasma")
				soundin = pick('sound/voice/speech/plasma1.ogg', 'sound/voice/speech/plasma2.ogg', 'sound/voice/speech/plasma3.ogg')
			if("pod")
				soundin = pick('sound/voice/speech/pod1.ogg')
			if("shadow")
				soundin = pick('sound/voice/speech/shadow1.ogg', 'sound/voice/speech/shadow2.ogg', 'sound/voice/speech/shadow3.ogg')
			if("squid")
				soundin = pick('sound/voice/speech/squid1.ogg', 'sound/voice/speech/squid2.ogg', 'sound/voice/speech/squid3.ogg')
			if("zombie")
				soundin = pick('sound/voice/speech/zombie1.ogg', 'sound/voice/speech/zombie2.ogg', 'sound/voice/speech/zombie3.ogg')
			if("egg")
				soundin = pick('sound/voice/eggperson/egg_scream.ogg')
			if("skeleton")
				soundin = pick('sound/voice/speech/skeleton1.ogg', 'sound/voice/speech/skeleton2.ogg', 'sound/voice/speech/skeleton3.ogg')
			if("golem")
				soundin = pick('sound/voice/speech/golem1.ogg')
			if("felinid")	// Why awe we stiww hewe?!! Just t-to suffew?!?1 *sees buldge*
				soundin = pick('sound/voice/speech/felinid1.ogg', 'sound/voice/speech/felinid2.ogg', 'sound/voice/speech/felinid3.ogg', 'sound/voice/speech/felinid4.ogg')
	return soundin
