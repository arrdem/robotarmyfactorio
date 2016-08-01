require("util")
require("config.config") -- config for squad control mechanics - important for anyone using 
require("robolib.util") -- some utility functions not necessarily related to robot army mod
require("robolib.robotarmyhelpers") -- random helper functions related to the robot army mod
require("robolib.Squad") -- allows us to control squads, add entities to squads, etc.
require("prototypes.DroidUnitList") -- so we know what is spawnable
require("stdlib/log/logger")
LOGGER = Logger.new("robotarmy", "robot_army_logs", true, {log_ticks = true})


script.on_init(function() 

	LOGGER.log("Robot Army mod Init script running...")
	if not global.Squads then
		global.Squads = {}
	end

	if not global.uniqueSquadId then
		global.uniqueSquadId = {}
	end

	if not global.DroidAssemblers then 
		global.DroidAssemblers = {}
	end

	if not global.droidCounters then
		global.droidCounters = {}
	end

	if not global.lootChests then
		global.lootChests = {}
	end
	
	if not global.droidGuardStations then
		global.droidGuardStations = {}
	end		
	LOGGER.log("Robot Army mod Init script finished...")
end)

script.on_event(defines.events.on_force_created, function(event)
	handleForceCreated(event)
 end)
function handleForceCreated(event)

    local force = event.force
    LOGGER.log(string.format("New force detected... %s",force.name) )
    global.DroidAssemblers = global.DroidAssemblers or {}
    global.DroidAssemblers[force.name] = global.DroidAssemblers[force.name] or {}

    global.Squads = global.Squads or {}
    global.Squads[force.name] = global.Squads[force.name] or {}

    global.uniqueSquadId = global.uniqueSquadId or {}
    global.uniqueSquadId[force.name] = global.uniqueSquadId[force.name] or 1

    global.lootChests = global.lootChests or {}
    global.lootChests[force.name] = global.lootChests[force.name] or {}

    global.droidCounters = global.droidCounters or {}
    global.droidCounters[force.name] = global.droidCounters[force.name] or {}

    global.droidGuardStations = global.droidGuardStations or {}
    global.droidGuardStations[force.name] = global.droidGuardStations[force.name] or {} 


	--not needed as of factorio 0.13.10 which removes friendly fire issue.
	force.set_cease_fire(force, true) --set ceasefire on your own force. maybe this will prevent friendlyfire stuff?
    LOGGER.log("New force handler finished...")

end


script.on_configuration_changed(function(data) 
 
	 if data.mod_changes ~= nil and data.mod_changes["robotarmy"] ~= nil and data.mod_changes["robotarmy"].old_version == nil then  -- Mod was added
		LOGGER.log("Robot Army mod added - setting up research and recipe unlocks...")
		for _,force in pairs(game.forces) do

			--Tech Additions for droids and droid counter combinator
			if force.technologies["military"].researched then
				force.recipes["droid-rifle"].enabled=true
				force.recipes["droid-rifle-deploy"].enabled=true
				force.recipes["loot-chest"].enabled=true
			end

			if force.technologies["electronics"].researched then
				force.recipes["droid-counter"].enabled=true
			end

			if force.technologies["military-2"].researched then
				force.recipes["droid-smg"].enabled=true
				force.recipes["droid-smg-deploy"].enabled=true
				force.recipes["droid-rocket"].enabled=true
				force.recipes["droid-rocket-deploy"].enabled=true
			end
		  
			if force.technologies["military-3"].researched then
				force.recipes["terminator"].enabled=true
				force.recipes["terminator-deploy"].enabled=true
			end
		end     
	 end
	if data.mod_changes ~= nil and data.mod_changes["robotarmy"] ~= nil and data.mod_changes["robotarmy"].old_version ~= nil then  -- Mod was changed
		LOGGER.log("Robot Army mod changed version - checking research and recipe unlocks...")
		for _,force in pairs(game.forces) do
			
			--Tech Additions for droids and droid counter combinator
			if force.technologies["military"].researched then
				force.recipes["droid-rifle"].enabled=true
				force.recipes["droid-rifle-deploy"].enabled=true
				force.recipes["loot-chest"].enabled=true
			end

			if force.technologies["electronics"].researched then
				force.recipes["droid-counter"].enabled=true
			end

			if force.technologies["military-2"].researched then
				force.recipes["droid-smg"].enabled=true
				force.recipes["droid-smg-deploy"].enabled=true
				force.recipes["droid-rocket"].enabled=true
				force.recipes["droid-rocket-deploy"].enabled=true
			end
		  
			if force.technologies["military-3"].researched then
				force.recipes["terminator"].enabled=true
				force.recipes["terminator-deploy"].enabled=true
			end
		end 
		
	end
	
end)


function handleDroidSpawned(event)

	local entity = event.created_entity
	local player = game.players[event.player_index]
	
	--player.print(string.format("Processing new entity %s spawned by player %s", entity.name, player.name) )
	local position = entity.position
	
	--if this is the first time we are using the player's tables, make it
	if not global.Squads[player.force.name] then 
		global.Squads[player.force.name] = {}
	end

	--trimSquads(game.players) -- maintain squad tables before checking for distance to nearest squad
	
	local squadref = getClosestSquadToPos(global.Squads[player.force.name], entity.position, SQUAD_CHECK_RANGE)
	
	if  not squadref then
		--if we didnt find a squad nearby, create one	
		squadref = createNewSquad(global.Squads[player.force.name], player, entity)

	end
	 

	addMember(global.Squads[player.force.name][squadref],entity)		
	--checkMembersAreInGroup(global.Squads[player.force.name][squadref])
	global.Squads[player.force.name][squadref].unitGroup.add_member(entity)
	
	local squadOfInterest = global.Squads[player.force.name][squadref]
	
	if event.guard == true then
		if squadOfInterest.command ~= commands.guard then
			squadOfInterest.command = commands.guard
			squadOfInterest.home = event.guardPos
			--game.players[1].print(string.format("Setting guard squad to wander around %s", event.guardPos))
			
			--check if the squad it just joined is patrolling, if it is, don't force any more move commands because it will be disruptive!
			
			if not squadOfInterest.patrolState or (squadOfInterest.patrolState and squadOfInterest.patrolState.currentWaypoint == -1) then
				--Game.print_force(entity.force, "Setting move command to squad home..." )
				squadOfInterest.unitGroup.set_command({type=defines.command.wander, destination = squadOfInterest.home, distraction=defines.distraction.by_enemy})
				squadOfInterest.unitGroup.start_moving()
			end
		end
	end
	
	--global.Squads[player.force.name][squadref].unitGroup.start_moving()	

end

function handleGuardStationPlaced(event)

	local entity = event.created_entity
	local force = entity.force
	LOGGER.log( string.format("Adding guard station to force %s", force.name) )
	
	--check for droid guard station global tables first.
	if not global.droidGuardStations then
		global.droidGuardStations = {}
	end
	if not global.droidGuardStations[force.name] then
		global.droidGuardStations[force.name] = {}
	end
	
	table.insert(global.droidGuardStations[force.name], entity)
	maintainTable(global.droidGuardStations[force.name]) -- helps remove old invalid/nil entries.

end

function handleDroidAssemblerPlaced(event)
	local entity = event.created_entity
	local force = entity.force
	
	--check for droid guard station global tables first.
	if not global.DroidAssemblers then
		global.DroidAssemblers = {}
	end
	if not global.DroidAssemblers[force.name] then
		global.DroidAssemblers[force.name] = {}
	end
	LOGGER.log( string.format("Adding assembler to force %s", force.name) )	
	if global.DroidAssemblers and global.DroidAssemblers[force.name] then
		table.insert(global.DroidAssemblers[force.name], entity)
	else
		
		LOGGER.log("WARNING: no global table for droid assemblers and/or the force is missing one for it")
	end


end

script.on_event(defines.events.on_built_entity, function(event)
    
   local entity = event.created_entity
  
	if(entity.name == "droid-assembling-machine") then 
		handleDroidAssemblerPlaced(event)
	elseif(entity.name == "droid-guard-station") then
		handleGuardStationPlaced(event)
	elseif(entity.name == "droid-counter") then
		handleBuiltDroidCounter(event)
	elseif entity.name == "loot-chest" then
		handleBuiltLootChest(event)
	elseif entity.name == "rally-beacon" then
		handleBuiltRallyBeacon(event)	
	elseif table.contains(squadCapable, entity.name) then --squadCapable is defined in DroidUnitList.
		handleDroidSpawned(event) --this deals with droids spawning
	end
	
  
end)

function handleBuiltRallyBeacon(event)

	
	local entity = event.created_entity
	if global.Squads and global.Squads[entity.force.name] then
		trimSquads(game.forces)
		
		--game.players[1].print(string.format("Rally point built, for force %s...", entity.force.name))
		--loop through all squads on the force, checking for those who are hunting or 'assembling' and make them move to the rally point and then continue what they were doing.
		for _, squad in pairs(global.Squads[entity.force.name]) do
			--game.players[1].print("checking squad..")
			if squad and squad.unitGroup and squad.unitGroup.valid then
				--game.players[1].print("checking squad command...")
				if squad.command ~= commands.guard and squad.command ~= commands.patrol then
			
					--game.players[1].print(string.format("Sending squad %d to rally point...", squad.squadID))
					local pos = entity.position
					pos.x = pos.x+2
					pos.y = pos.y+2
					--give them command to move. distraction by damage means if they are shot at/bit, they will at least try and defend themselves while running away.
					squad.unitGroup.set_command({type=defines.command.go_to_location, destination=pos, distraction=defines.distraction.none})
					--squad.unitGroup.start_moving()
				
				end
			end	
		end
	end
end


script.on_event(defines.events.on_robot_built_entity, function(event)
	local entity = event.created_entity
	if(entity.name == "droid-assembling-machine") then 
		handleDroidAssemblerPlaced(event)
	elseif(entity.name == "droid-guard-station") then
		handleGuardStationPlaced(event)
	elseif(entity.name == "droid-counter") then
		handleBuiltDroidCounter(event)
	elseif entity.name == "rally-beacon" then
		handleBuiltRallyBeacon(event)
	elseif entity.name == "loot-chest" then
		handleBuiltLootChest(event)
	end

end)

--logic for handling loot chest spawning, cannot have more than one per force.
function handleBuiltLootChest(event)

	--check if there is a global table entry for loot chests yet, make one if not.
	if not global.lootChests then
		global.lootChests = {}
	end
	
	local chest = event.created_entity
	local force = chest.force
	LOGGER.log( string.format("Adding loot chest to force %s", force.name) )
	if not global.lootChests[force.name] or not global.lootChests[force.name].valid  then
		global.lootChests[force.name] = chest   --this is now the force's chest. 
	else
	
		force.players[1].print("Error: Can only place one loot chest!")	
		chest.surface.spill_item_stack(chest.position, {name="loot-chest", count = 1})
		chest.destroy()
		LOGGER.log("WARNING: Can only place one loot chest!")
	
	end



end

function handleBuiltDroidCounter(event)
	
	local entity = event.created_entity 
	local entityForce = entity.force.name
	LOGGER.log( string.format("Adding droid counter to force %s", entityForce) )
	if not global.droidCounters then			
		global.droidCounters = {}		
		global.droidCounters[entityForce] = {}
		table.insert(global.droidCounters[entityForce], entity )
	elseif not global.droidCounters[entityForce] then 
		global.droidCounters[entityForce] = {}
		table.insert(global.droidCounters[entityForce], entity)
	else
		table.insert(global.droidCounters[entityForce], entity)
	end
end


-- during the on-tick event, lets check if we need to update squad AI, spawn droids from assemblers, or update bot counters, etc
function onTickHandler(event)

	if not global.lastTick then
		global.lastTick = 0
	end
  -- has enough time elapsed to go through and set squad orders yet?
  if event.tick > (global.lastTick + TICK_UPDATE_SQUAD_AI) then
	
	local forces = game.forces
	local players = game.players -- list of players 
	trimSquads(forces) -- does some quick maintenance of the squad tables. 
	
	sendSquadsToBattle(forces, SQUAD_SIZE_MIN_BEFORE_HUNT) -- finds all squads for all players and checks for squad size and sends to attack nearest targets
	guardAIUpdate()
	revealSquadChunks()
	grabArtifacts(forces)
	global.lastTick = event.tick
	
  end
  
  if (event.tick % ASSEMBLER_UPDATE_TICKRATE == 0) then

	local players = game.players
	
	for _, player in pairs(players) do
	
		if global.DroidAssemblers and global.DroidAssemblers[player.force.name] then
	--for each building in their list using name as key\
			for index, assembler in pairs(global.DroidAssemblers[player.force.name]) do
				
				if assembler and assembler.valid and assembler.force == player.force then

					local inv = assembler.get_output_inventory() --gets us a luainventory
					local spawnableDroidName = containsSpawnableDroid(inv) -- assembler.get_item_count("droid-smg-dummy") --replace with "contains any spawnable droid"

					if (spawnableDroidName ~= nil and type(spawnableDroidName) == "string") then
					
						
						local droidPos =  getDroidSpawnLocation(assembler) -- uses assmbler pos, direction, and spawns droid at an offset +- random amount
						
						local assForce = assembler.force -- haha, ass force!
						local returnedEntity = assembler.surface.create_entity({name = spawnableDroidName , position = droidPos, direction = defines.direction.east, force = assForce })

						if returnedEntity then
													
							local eventStub = {player_index = player.index, created_entity = returnedEntity}
							handleDroidSpawned(eventStub)
						
						end
						
						inv.clear() --clear output slot
					
					end

				end
				
			end

		end --end if they have a list of droid assemblers
		
		--handle guard station spawning here
		
		if global.droidGuardStations and global.droidGuardStations[player.force.name] then
		
			for _, station in pairs(global.droidGuardStations[player.force.name]) do
			
				if station and station.valid and station.force == player.force then
					
					local inv = station.get_output_inventory() --gets us a luainventory
					local spawnableDroidName = containsSpawnableDroid(inv) 

					local nearby = countNearbyDroids(station.position, station.force, 30) --inputs are position, force, and radius
										
					--if we have a spawnable droid ready, and there is not too many droids nearby, lets spawn one!
					if (spawnableDroidName ~= nil and type(spawnableDroidName) == "string") and nearby < GUARD_STATION_GARRISON_SIZE then
							
						local droidPos =  getGuardSpawnLocation(station) -- uses station pos			
		
						local returnedEntity = station.surface.create_entity({name = spawnableDroidName , position = droidPos, direction = defines.direction.east, force = station.force })

						if returnedEntity then
													
							local eventStub = {player_index = player.index, created_entity = returnedEntity, guard = true, guardPos = station.position}
							handleDroidSpawned(eventStub)
						
						end
						
						inv.clear() --clear output slot
					
					end
					
					
				end
			
			end
		
		end
		
		
		
	end -- end for each player in players list

  end
  
  
  if( event.tick % BOT_COUNTERS_UPDATE_TICKRATE == 0) then
  
	doCounterUpdate(event)
	
  
  end
 


  if(event.tick % LONE_WOLF_CLEANUP_SCRIPT_PERIOD == 0) then
  
	--begin lone-wolf cleanup process. finds and removes units who are not in a unitGroup
	--this is unfinished, will be in next release
  
  end
 
end


script.on_event(defines.events.on_tick, function( event) 
	onTickHandler(event)
 end)

 


 
