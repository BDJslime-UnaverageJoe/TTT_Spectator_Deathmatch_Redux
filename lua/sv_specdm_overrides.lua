hook.Add("PlayerSpawn", "PlayerSpawn_SpecDM", function(ply)
	if ply:IsGhost() then
		ply.has_spawned = true

		ply:UnSpectate()
		ply:GiveGhostWeapons()

		hook.Call("PlayerSetModel", GAMEMODE, ply)
    end
end)

local function SpecDM_Respawn(ply)
	ply.allowrespawn = false

	if IsValid(ply) and ply:IsGhost() and not ply:Alive() then
		ply:UnSpectate()
		ply:Spawn()
		ply:GiveGhostWeapons()

		SpecDM:RelationShip(ply)
    end
end

hook.Add("PlayerSilentDeath", "PlayerDeath_SpecDM", function(victim)
	if victim:IsGhost() then
		if SpecDM.RespawnTime < 1 then
			timer.Simple(0, function()
                if not IsValid(victim) then return end

				SpecDM_Respawn(victim)
			end)
		else
			net.Start("SpecDM_RespawnTimer")
			net.Send(victim)

			timer.Simple(SpecDM.RespawnTime, function()
                if not IsValid(victim) then return end

				victim.allowrespawn = true
			end)

			if SpecDM.AutomaticRespawnTime > -1 then
				timer.Simple(SpecDM.AutomaticRespawnTime + SpecDM.RespawnTime, function()
                    if not IsValid(victim) then return end

					SpecDM_Respawn(victim)
				end)
			end
		end
	elseif GetRoundState() == ROUND_ACTIVE and victim:IsActive() then
		timer.Simple(2, function()
			if IsValid(victim) then
				net.Start("SpecDM_Autoswitch")
				net.Send(victim)
			end
		end)
	end
end)


hook.Add("Initialize", "Initialize_SpecDM", function()

	local meta = FindMetaTable("Player")

	local old_ResetRoundFlags = meta.ResetRoundFlags
	function meta:ResetRoundFlags()
		if self:IsGhost() then return end

		old_ResetRoundFlags(self)
	end

	local old_ShouldSpawn = meta.ShouldSpawn
	function meta:ShouldSpawn()
		if self:IsGhost() then return true end

		return old_ShouldSpawn(self)
	end

	local old_GiveLoadout = GAMEMODE.PlayerLoadout
	function GAMEMODE:PlayerLoadout(ply)
		if ply:IsGhost() then return end

		old_GiveLoadout(self, ply)
	end
	
	local function force_spectate(ply, cmd, arg)
		if IsValid(ply) then
			if #arg == 1 and tonumber(arg[1]) == 0 then
				ply:SetForceSpec(false)
			else
				if ply:IsGhost() then
					ply:SetForceSpec(true)

					return
				end

				if not ply:IsSpec() then
					ply:Kill()
				end

				GAMEMODE:PlayerSpawnAsSpectator(ply)

				ply:SetTeam(TEAM_SPEC)
				ply:SetForceSpec(true)
				ply:Spawn()
				ply:SetRagdollSpec(false)
			end
		end
	end

	concommand.Remove("ttt_spectate") -- local function without a hook.call

	concommand.Add("ttt_spectate", force_spectate)
end)

hook.Add("PlayerButtonDown", "SpecDM_Respawn", function(ply, key)
	if ply:IsGhost() and ply.allowrespawn then
		SpecDM_Respawn(ply)
	end
end)

hook.Add("PlayerCanPickupWeapon", "SpecDM_Loadout", function(ply, weapon)
	if ply:IsGhost() and ply.EquippedDM then return false end
end)

hook.Add("TTTCanPickupAmmo", "SpecDM_Pickup", function(ply, ammo)
	if ply:IsGhost() and ply.EquippedDM then return false end
end)

hook.Add("AcceptInput", "AcceptInput_Ghost", function(ent, name, activator, caller, data)
	if IsValid(caller) and caller:GetClass() == "ttt_logic_role" then
		if IsValid(activator) and activator:IsPlayer() and activator:IsGhost() then
			return true
		end
	end
end)

hook.Add("EntityEmitSound", "EntityEmitSound_SpecDM", function(t)
	if t.Entity and t.Entity:IsPlayer() and t.Entity:IsGhost() and t.OriginalSoundName == "HL2Player.BurnPain" then
		return false
	end
end)

local function GhostTakeDamage(ply, dmginfo)
	--hook.Call("GhostTakeDamage")
	local ghostforce = DamageInfo()
	ghostforce:SetDamage(0)
	ghostforce:SetAttacker(game.GetWorld())
	ghostforce:SetDamageType(DMG_GENERIC)
	ghostforce:SetDamageForce(dmginfo:GetDamageForce())
	ply:TakeDamageInfo(ghostforce)

	if dmginfo:GetDamage() >= ply:Health() then
		ply:CreateRagdoll()
		ply:KillSilent()
	else
		ply:SetHealth(ply:Health() - dmginfo:GetDamage())
	end
end

/*
	Ghosts can not take damage from:
	Terrorists (Active players)
	Indirect Ghost damage (C4 and explosives)
	NPCs (Shouldn't be targetable)

	Ghosts can not deal direct damage (from a gun) to Terrorists and other entites
	Indirect damage are assumed to be used during round while active
*/
hook.Add("EntityTakeDamage","GhostDamageEntity_SpecDM", function(ent, dmginfo)
	if dmginfo:GetDamage() == 0 then return end --0 damage wont be processed or is already modified
	local atk = dmginfo:GetAttacker()
	local wep = util.WeaponFromDamage(dmginfo)

	if ent:IsPlayer() and ent:IsGhost() then
		if IsValid(atk) then
			if atk:IsNPC() and not atk:IsWorld()
			or (atk:IsPlayer() and (not atk:IsGhost() or atk == ent))
			or wep and ((isValid(wep) and atk:GetActiveWeapon()) != wep)
			then return true end
		end
		GhostTakeDamage(ent, dmginfo)
		return true
	elseif IsValid(atk) and atk:IsPlayer() and atk:IsGhost() and IsValid(wep) and atk:GetActiveWeapon() == wep then
		return true
	end
end)
