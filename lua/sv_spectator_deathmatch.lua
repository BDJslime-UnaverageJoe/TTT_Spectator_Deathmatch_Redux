AddCSLuaFile("cl_spectator_deathmatch.lua")
AddCSLuaFile("sh_spectator_deathmatch.lua")
AddCSLuaFile("specdm_config.lua")
AddCSLuaFile("cl_specdm_hud.lua")
AddCSLuaFile("vgui/spec_dm_loadout.lua")
AddCSLuaFile("cl_stats.lua")
AddCSLuaFile("specdm_von.lua")
AddCSLuaFile("cl_quakesounds.lua")

include("sh_spectator_deathmatch.lua")
include("sv_specdm_overrides.lua")
include("sv_stats.lua")
include("sv_quakesounds.lua")

util.AddNetworkString("SpecDM_Error")
util.AddNetworkString("SpecDM_Ghost")
util.AddNetworkString("SpecDM_ChangeState")
util.AddNetworkString("SpecDM_Autoswitch")
util.AddNetworkString("SpecDM_SendLoadout")
util.AddNetworkString("SpecDM_GhostJoin")
util.AddNetworkString("SpecDM_BulletGhost")
util.AddNetworkString("SpecDM_AskStats")
util.AddNetworkString("SpecDM_SendStats")
util.AddNetworkString("SpecDM_OpenStats")
util.AddNetworkString("SpecDM_AskOpenStats")
util.AddNetworkString("SpecDM_QuakeSound")
util.AddNetworkString("SpecDM_Hitmarker")
util.AddNetworkString("SpecDM_RespawnTimer")

if SpecDM.QuakeSoundsEnabled then
	resource.AddFile("sound/specdm/killingspree.mp3")
	resource.AddFile("sound/specdm/dominating.mp3")
	resource.AddFile("sound/specdm/megakill.mp3")
	resource.AddFile("sound/specdm/wickedsick.mp3")
	resource.AddFile("sound/specdm/monsterkill.mp3")
	resource.AddFile("sound/specdm/unstoppable.mp3")
	resource.AddFile("sound/specdm/godlike.mp3")
	resource.AddFile("sound/specdm/triplekill.mp3")
	resource.AddFile("sound/specdm/ultrakill.mp3")
	resource.AddFile("sound/specdm/doublekill.mp3")
	resource.AddFile("sound/specdm/rampage.mp3")
	resource.AddFile("sound/specdm/holyshit.mp3")
end

local commands_table = {}
for _, v in ipairs(SpecDM.Commands) do
	commands_table[v] = true
end

hook.Add("PlayerSay", "PlayerSay_SpecDM", function(ply, text, public)
	if commands_table[string.lower(text)] then
		SpecDM:WantsToDM(ply)

		return ""
	end
end)

local meta = FindMetaTable("Player")

function meta:SpecDM_Error(error_str)
	net.Start("SpecDM_Error")
	net.WriteString(error_str)
	net.Send(self)
end

function SpecDM:RelationShip(victim)
	for _, npc in ipairs(ents.FindByClass("npc_*")) do
		if isfunction(npc.AddEntityRelationship) then
			npc:AddEntityRelationship(victim, D_NU, 99)
		end
	end
end

function meta:GiveGhostWeapons()
	self.EquippedDM = false
	if not SpecDM.LoadoutEnabled or not self.ghost_primary or self.ghost_primary == "random" or not table.HasValue(SpecDM.Ghost_weapons.primary, self.ghost_primary) then
		self:Give(SpecDM.Ghost_weapons.primary[math.random(#SpecDM.Ghost_weapons.primary)])
	else
		self:Give(self.ghost_primary)
	end

	if not SpecDM.LoadoutEnabled or not self.ghost_secondary or self.ghost_secondary == "random" or not table.HasValue(SpecDM.Ghost_weapons.secondary, self.ghost_secondary) then
		self:Give(SpecDM.Ghost_weapons.secondary[math.random(#SpecDM.Ghost_weapons.secondary)])
	else
		self:Give(self.ghost_secondary)
	end

	self:Give("weapon_ghost_crowbar")
	self.EquippedDM = true
end

hook.Add("WeaponEquip", "WeaponEquip_SpecDM", function(weapon, owner)
	if owner:IsGhost() then
		weapon.AllowDrop = false
	end
end)

function meta:ManageGhost(spawn, silent)
	local silent = silent or false

	if spawn then
		self:SetTeam(TEAM_DEATHMATCH)
		self:Spawn()
		self:GiveGhostWeapons()

		SpecDM:RelationShip(self)
	else
		self:KillSilent()
		self:SetTeam(TEAM_SPEC)
		self:Spectate(OBS_MODE_ROAMING)
	end

	net.Start("SpecDM_Ghost")
	net.WriteUInt(spawn and 1 or 0, 1)
	net.Send(self)

	if silent then return end

	local filter = RecipientFilter()
	filter:AddAllPlayers()
	filter:RemovePlayer(self)

	net.Start("SpecDM_GhostJoin")
	net.WriteUInt(spawn and 1 or 0, 1)
	net.WriteEntity(self)
	net.Send(filter)
end

net.Receive("SpecDM_ChangeState", function(len, ply)
	SpecDM:WantsToDM(ply)
end)



local allowed_groups = {}
for _, v in ipairs(SpecDM.AllowedGroups) do
	allowed_groups[v] = true
end

function SpecDM:WantsToDM(ply)
	local allowed = true

	if SpecDM.RestrictCommand then
		allowed = false

		if allowed_groups[ply:GetUserGroup()] then
			allowed = true
		end
	end

	if allowed then
		if ply:IsActive() then
			ply:SpecDM_Error("You can't enter spectator deathmatch when you're alive.")
		elseif GetRoundState() ~= ROUND_ACTIVE then
			ply:SpecDM_Error("Error: Current round is inactive.")
		elseif not ply.spawning_ghost then
			if tonumber(ply.DMTimer) and ply.DMTimer > CurTime() then
				ply:SpecDM_Error("Wait ".. string.NiceTime(ply.DMTimer - CurTime()).." second(s) before using this command again!")
			else
				ply:ManageGhost(not ply:IsGhost())

				ply.DMTimer = CurTime() + 10

			end
		end
	else
		ply:SpecDM_Error("Error : you are not allowed to enter Spectator Deathmatch")
	end
end

hook.Add("TTTEndRound", "TTTEndRound_Ghost", function()
	for _, v in ipairs(player.GetAll()) do
		if v:IsGhost() then
			v:ManageGhost(false, true)
		end
	end
end)

net.Receive("SpecDM_SendLoadout", function(_, ply)
	local primary = net.ReadString()
	local secondary = net.ReadString()

	if not primary or not secondary then return end

	if primary == "random" or string.Left(primary, #"weapon_ghost") ~= "weapon_ghost" then
		ply.ghost_primary = "random"
	end

	if secondary == "random" or string.Left(secondary, #"weapon_ghost") ~= "weapon_ghost" then
		ply.ghost_primary = "random"
	end

	for _, v in ipairs(weapons.GetList()) do
		if v.ClassName == primary and v.Kind == WEAPON_HEAVY then
			ply.ghost_primary = primary
		elseif v.ClassName == secondary and v.Kind == WEAPON_PISTOL then
			ply.ghost_secondary = secondary
		end
	end
end)

hook.Add("EntityTakeDamage", "EntityTakeDamage_SpecDMHitmarker", function(ent, dmginfo)
	if ent:IsPlayer() and ent:IsGhost() then
		local att = dmginfo:GetAttacker()

		if IsValid(att) and att:IsPlayer() and att:IsGhost() then
			net.Start("SpecDM_Hitmarker")
			net.WriteBool(SpecDM.DeadlyHitmarker and dmginfo:GetDamage() > ent:Health())
			net.Send(att)
		end
	end
end)

if SpecDM.HP_Regen then
	timer.Create("SpecDM_HPRegen", 1, 0, function()
		if GetRoundState() == ROUND_ACTIVE then
			for _, v in ipairs(player.GetAll()) do
				if v:IsGhost() and v:Alive() and v:Health() > 0 and v:Health() < v:GetMaxHealth() then
					v:SetHealth(v:Health() + 1)
				end
			end
		end
	end)
end
