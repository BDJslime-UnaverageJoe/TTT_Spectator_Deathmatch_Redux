include("sh_spectator_deathmatch.lua")
include("cl_specdm_hud.lua")
include("vgui/spec_dm_loadout.lua")
include("cl_stats.lua")
include("cl_quakesounds.lua")

local ghosttable = {}
local livingtable = {}

local showalive = CreateClientConVar("ttt_specdm_showaliveplayers", 1, FCVAR_ARCHIVE)

function SpecDM.UpdatePartDrawing(enabled)
	if pac then
        for _, v in ipairs(player.GetHumans()) do
            if not v:IsGhost() then
                if enabled and not showalive:GetBool() then
					pac.TogglePartDrawing(v, false)
                    continue
                end
            end
            pac.TogglePartDrawing(v, true)
        end
    end
end

if pac then
   cvars.AddChangeCallback("ttt_specdm_showaliveplayers", function()
      if LocalPlayer():IsGhost() then
         SpecDM.UpdatePartDrawing(true)
      end
   end)
end

net.Receive("SpecDM_Error", function()
	chat.AddText(Color(255, 62, 62, 255), net.ReadString())
end)

net.Receive("SpecDM_Ghost", function()
	local enabled = net.ReadUInt(1) == 1
	if enabled then
		TIPS.Hide()

		if SpecDM.MuteAlive then
			RunConsoleCommand("ttt_mute_team", TEAM_TERROR)
		end
	else
		TIPS:Show()
	end
   SpecDM.UpdatePartDrawing(enabled)
end)

net.Receive("SpecDM_GhostJoin", function()
	local joined = net.ReadUInt(1) == 1
	local ply = net.ReadEntity()

    if not IsValid(ply) then return end
    if joined then
        table.insert(ghosttable, ply)
        table.RemoveByValue(livingtable, ply)
    else
        table.RemoveByValue(ghosttable, ply)
        table.insert(livingtable, ply)
    end
    if LocalPlayer():IsActive() then return end
    if pac and not joined then
       pac.TogglePartDrawing(ply, false)
   end

   if not SpecDM.EnableJoinMessages then return end
	chat.AddText(Color(255,128,0), ply:Nick().." has ", joined and "joined" or "left", " the deathmatch!")
end)

local emitter
local color_modify = CreateClientConVar("ttt_specdm_enablecoloreffect", 1, FCVAR_ARCHIVE)
local color_tbl = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0,
	["$pp_colour_contrast"] = 1,
	["$pp_colour_colour"] = 0,
	["$pp_colour_mulr"] = 0.05,
	["$pp_colour_mulg"] = 0.05,
	["$pp_colour_mulb"] = 0.05
}

hook.Add("RenderScreenspaceEffects", "RenderScreenspaceEffects_Ghost", function()
	if LocalPlayer():IsGhost() and color_modify:GetBool() then
		DrawColorModify(color_tbl)

		cam.Start3D(EyePos(), EyeAngles())

        for _, v in ipairs(player.GetAll()) do
            if v:IsGhost() and v:Alive() then
                render.SuppressEngineLighting(true)
                render.SetColorModulation(1, 1, 1)

                if emitter then
                    emitter:Draw()
                end

                if not v:IsDormant() then
                    v:DrawModel()
                end

                render.SuppressEngineLighting(false)
            end
        end

		cam.End3D()
	end
end)

local RagdollEntities = {}
hook.Add("OnEntityCreated", "AddRagdolls_SpecDM", function(ent)
	if ent:GetClass() == "prop_ragdoll" and not RagdollEntities[ent:EntIndex()] then
		RagdollEntities[ent:EntIndex()] = ent
	elseif IsValid(LocalPlayer()) and not LocalPlayer():IsGhost() and ent:GetClass() == "class C_HL2MPRagdoll" then
		if IsValid(ent:GetRagdollOwner()) and ent:GetRagdollOwner():IsGhost() then
			ent:SetNoDraw(true)
			ent:PhysicsDestroy()
		end
	end
end)

hook.Add("EntityRemoved", "RemoveRagdolls_SpecDM", function(ent)
	if ent:GetClass() == "prop_ragdoll" and RagdollEntities[ent:EntIndex()] then
		RagdollEntities[ent:EntIndex()] = nil
	end
end)

local COLOR_WHITE = Color(255,255,255,255)
local COLOR_LIGHTGREY = Color(225, 225, 225, 200)
local COLOR_GREY = Color(255, 255, 255, 100)
local COLOR_RED = Color(255, 16, 16, 255)


hook.Add("Think", "Think_Ghost", function()
	for _, v in ipairs(RagdollEntities) do
		if LocalPlayer():IsGhost() then
			v:SetRenderMode(RENDERMODE_TRANSALPHA)
			v:SetColor(COLOR_GREY)
		else
			v:SetColor(COLOR_WHITE)
		end
	end
end)

hook.Add("PrePlayerDraw", "PrePlayerDraw_SpecDM", function(ply)
    if IsValid(LocalPlayer()) and LocalPlayer():IsGhost() then
        if not ply:IsGhost() and not showalive:GetBool() then
            ply:DrawShadow(false)

            if IsValid(ply:GetActiveWeapon()) then
                ply:GetActiveWeapon():DrawShadow(false)
            end

            return true
        elseif ply:IsTerror() then
            ply:SetRenderMode(RENDERMODE_TRANSALPHA)
            ply:SetColor(COLOR_GREY)
            ply:DrawShadow(true)

            if IsValid(ply:GetActiveWeapon()) then
                ply:GetActiveWeapon():DrawShadow(true)
            end
        end
    else
        if ply:IsGhost() then
            ply:DrawShadow(false)

            if IsValid(ply:GetActiveWeapon()) then
                ply:GetActiveWeapon():DrawShadow(false)
            end

            return true
        else
            ply:SetRenderMode(RENDERMODE_NORMAL)
            ply:SetColor(COLOR_WHITE)
            ply:DrawShadow(true)

            if IsValid(ply:GetActiveWeapon()) then
                ply:GetActiveWeapon():DrawShadow(true)
            end
        end
    end
end)

local function SendHeartbeat()
	if not IsValid(LocalPlayer()) or not LocalPlayer():IsGhost() then return end

	for _, v in ipairs(player.GetAll()) do
		if v ~= LocalPlayer() and v:IsGhost() and v:Alive() then
			emitter = ParticleEmitter(LocalPlayer():GetPos())

			local heartbeat = emitter:Add("sprites/light_glow02_add_noz", v:GetPos() + Vector(0, 0, 50))

			heartbeat:SetDieTime(0.5)
			heartbeat:SetStartAlpha(255)
			heartbeat:SetEndAlpha(0)
			heartbeat:SetStartSize(50)
			heartbeat:SetEndSize(0)
			heartbeat:SetColor(255,0,0)
		end
	end
end
timer.Create("SpecDMHeartbeat", 5, 0, SendHeartbeat)

if not SpecDM.IsScoreboardCustom then
	hook.Add("TTTScoreGroups", "TTTScoreGroups_GhostDM", function(can, pg)
		if not GROUP_DEATHMATCH then
			AddScoreGroup("DEATHMATCH")
		end

		local t = vgui.Create("TTTScoreGroup", can)
		t:SetGroupInfo("Spectator Deathmatch", Color(255, 127, 39, 100), GROUP_DEATHMATCH)

		pg[GROUP_DEATHMATCH] = t
	end)

	hook.Add("InitPostEntity", "InitPostEntity_ScoreboardOverride", function()
		local sgtbl = vgui.GetControlTable("TTTScoreGroup")

		function sgtbl:AddPlayerRow(ply)
			if (self.group == GROUP_DEATHMATCH or ScoreGroup(ply) == self.group) and not self.rows[ply] then
				local row = vgui.Create("TTTScorePlayerRow", self)
				row:SetPlayer(ply)

				self.rows[ply] = row
				self.rowcount = table.Count(self.rows)

				self:PerformLayout()
			end
		end

		function sgtbl:UpdatePlayerData()
			local to_remove = {}
			for k, v in pairs(self.rows) do
				if IsValid(v) and IsValid(v:GetPlayer()) and (self.group == GROUP_DEATHMATCH and v:GetPlayer():IsGhost() and LocalPlayer():IsSpec() or ScoreGroup(v:GetPlayer()) == self.group) then
					v:UpdatePlayerData()
				else
					table.insert(to_remove, k)
				end
			end

			if #to_remove == 0 then return end

			for _, ply in ipairs(to_remove) do
				local pnl = self.rows[ply]

				if IsValid(pnl) then
					pnl:Remove()
				end

				self.rows[ply] = nil
			end

			self.rowcount = table.Count(self.rows)

			self:UpdateSortCache()
			self:InvalidateLayout()
		end

		local sbtbl = vgui.GetControlTable("TTTScoreboard")
		local old_UpdateScoreboard = sbtbl["UpdateScoreboard"]

		function sbtbl:UpdateScoreboard(force)
			if not force and not self:IsVisible() then return end

			for _, v in ipairs(player.GetAll()) do
				if v:IsGhost() and LocalPlayer():IsGhost() then
					if self.ply_groups[GROUP_DEATHMATCH] and not self.ply_groups[GROUP_DEATHMATCH]:HasPlayerRow(v) then
						self.ply_groups[GROUP_DEATHMATCH]:AddPlayerRow(v)
					end
				end
			end

			old_UpdateScoreboard(self, force)
		end
	end)
end

-- Messy and untested, but at least its not overriding
-- Ghosts are assumed to IsSpec and not Alive
hook.Add("TTTScoreGroup", "TTTScoreGroup_SpecDM", function(ply)
	if ply:IsGhost() then
		if not ply:GetNWBool("PlayedSRound", false) then return GROUP_SPEC end
		if DetectiveMode() then
			if CR_VERSION and p.search_result or p:GetNWBool("body_searched", false) then
				return GROUP_SEARCHED
			elseif p:GetNWBool("body_found", false) then
				return GROUP_FOUND
			else
				local client = LocalPlayer()
				-- To terrorists, missing players show as alive
				if CR_VERSION and (client:IsActiveTraitorTeam() or client:IsActiveMonsterTeam() or (client:IsActiveIndependentTeam() and cvars.Bool("ttt_" .. ROLE_STRINGS_RAW[client:GetRole()] .. "_update_scoreboard", false))) 
				or client:IsActiveTraitor() 
				or ((GAMEMODE.round_state ~= ROUND_ACTIVE) and client:IsTerror()) then
					return GROUP_NOTFOUND
				else
					return GROUP_TERROR
				end
			end
		end
		return GROUP_SPEC
	end
end)

hook.Add("Initialize", "Initialize_Ghost", function()

   local oldTraceLine = util.TraceLine
   function util.TraceLine(tbl)
      local plyghost = LocalPlayer():IsGhost()
      if not istable(tbl) or (plyghost and showalive:GetBool()) then
         return oldTraceLine(tbl)
      end

      local filt = tbl.filter
      local ignoretbl = {}

      if plyghost then
          for k, v in ipairs(livingtable) do
              if !IsValid(v) then livingtable[k] = nil continue end
              table.insert(ignoretbl, v)
          end
      else
          for k, v in ipairs(ghosttable) do
              if !IsValid(v) then ghosttable[k] = nil continue end
              table.insert(ignoretbl, v)
          end
      end

      if filt then
         if isentity(filt) then
            tbl.filter = {}
            table.insert(tbl.filter, filt)
            table.Add(tbl.filter, ignoretbl)
         elseif istable(filt) then
            table.Add(tbl.filter, ignoretbl)
         elseif isfunction(filt) then
            tbl.filter = function(ent)
               if ignoretbl[ent] then
                  return false
               end
               return filt()
            end
         end
      else
          tbl.filter = ignoretbl
      end
      return oldTraceLine(tbl)
	end
end)

hook.Add("TTTBeginRound", "TTTBeginRound_TableGhost", function()
    table.Empty(ghosttable)
    table.Empty(livingtable)
    for _, v in ipairs(player.GetAll()) do
        table.insert(livingtable, v)
    end
end)

local primary = CreateClientConVar("ttt_specdm_primaryweapon", "random", FCVAR_ARCHIVE)
local secondary = CreateClientConVar("ttt_specdm_secondaryweapon", "random", FCVAR_ARCHIVE)
local force_deathmatch = CreateClientConVar("ttt_specdm_forcedeathmatch", 1, FCVAR_ARCHIVE)
local autoswitch = CreateClientConVar("ttt_specdm_autoswitch", 0, FCVAR_ARCHIVE)

function SpecDM.UpdateLoadout()
	net.Start("SpecDM_SendLoadout")
	net.WriteString(primary:GetString())
	net.WriteString(secondary:GetString())
	net.SendToServer()
end
hook.Add("InitPostEntity", "SpecDM_InitPostEntity", SpecDM.UpdateLoadout)

cvars.AddChangeCallback("ttt_specdm_primaryweapon", SpecDM.UpdateLoadout)
cvars.AddChangeCallback("ttt_specdm_secondaryweapon", SpecDM.UpdateLoadout)

hook.Add("TTTSettingsTabs", "SpecDM_TTTSettingsTab", function(dtabs)
	local dsettings = vgui.Create("DScrollPanel", dtabs)

	if SpecDM.LoadoutEnabled then
		local primary_loadout = vgui.Create("SpecDM_LoadoutPanel")

		primary_loadout.cvar = "ttt_specdm_primaryweapon"

		primary_loadout:SetCategory("Primary weapons")
		primary_loadout:SetWeapons(SpecDM.Ghost_weapons.primary)
		primary_loadout:SetSize(550, 50)
		primary_loadout:SetPos(10, 10)

		dsettings:AddItem(primary_loadout)

		local secondary_loadout = vgui.Create("SpecDM_LoadoutPanel")
		secondary_loadout.cvar = "ttt_specdm_secondaryweapon"

		secondary_loadout:SetCategory("Secondary weapons")
		secondary_loadout:SetWeapons(SpecDM.Ghost_weapons.secondary)
		secondary_loadout:SetSize(550, 50)
		secondary_loadout:SetPos(10, 140)

		dsettings:AddItem(secondary_loadout)
	end

	local dgui = vgui.Create("DForm", dsettings)
	dgui:SetName("General settings")

	if not SpecDM.ForceDeathmatch then
		dgui:CheckBox("Enable autoswitch", "ttt_specdm_autoswitch")
	else
		dgui:CheckBox("Always go to deathmatch mode after dying", "ttt_specdm_forcedeathmatch")
	end

	dgui:CheckBox("Enable Quake sounds + texts", "ttt_specdm_quakesounds")
	dgui:CheckBox("Show alive players", "ttt_specdm_showaliveplayers")
	dgui:CheckBox("Enable the color effect", "ttt_specdm_enablecoloreffect")
	dgui:CheckBox("Enable the hitmarker", "ttt_specdm_hitmarker")

	dgui:SetSize(555, 50)
	dgui:SetPos(10, 270)

	dsettings:AddItem(dgui)

	dtabs:AddSheet("Spectator Deathmatch", dsettings, "icon16/gun.png", false, false, "Spectator deathmatch related settings")
end)

net.Receive("SpecDM_Autoswitch", function()
	local spawned = false

	if ((SpecDM.ForceDeathmatch and force_deathmatch:GetBool()) or (not SpecDM.ForceDeathmatch and autoswitch:GetBool())) and GetRoundState() == ROUND_ACTIVE and not LocalPlayer():IsGhost() then
		spawned = true

		RunConsoleCommand(specdm)
	elseif not SpecDM.ForceDeathmatch and SpecDM.PopUp then
		local frame = vgui.Create("DFrame")
		frame:SetSize(250, 120)
		frame:SetTitle("Spectator Deathmatch")
		frame:Center()

		local reason = vgui.Create("DLabel", frame)
		reason:SetText("You can play while you are dead!")
		reason:SizeToContents()
		reason:SetPos(5, 32)

		local report = vgui.Create("DButton", frame)
		report:SetPos(5, 55)
		report:SetSize(240, 25)
		report:SetText("Join the Spectator Deathmatch")

		report.DoClick = function()
			RunConsoleCommand(specdm)

			frame:Close()
		end

		local report_icon = vgui.Create("DImageButton", report)
		report_icon:SetMaterial("materials/icon16/report_go.png")
		report_icon:SetPos(1, 5)
		report_icon:SizeToContents()

		local close = vgui.Create("DButton", frame)
		close:SetPos(5, 85)
		close:SetSize(240, 25)
		close:SetText("No, stay as a spectator")

		close.DoClick = function()
			frame:Close()
		end
        local close_icon = vgui.Create("DImageButton", close)

		close_icon:SetPos(2, 5)
		close_icon:SetMaterial("materials/icon16/cross.png")
		close_icon:SizeToContents()
        frame:MakePopup()

	end
	if SpecDM.DisplayMessage and not spawned then
		chat.AddText(Color(255, 62, 62), "[DM] ", color_white, "You've died! Type ", Color(98,176,255), SpecDM.Commands[1], COLOR_WHITE, " to enter deathmatch mode and ", Color(255,62,62), "keep killing", COLOR_WHITE, "!")
		-- Now this will say !dm instead of !deathmatch. (see specdm_config.lua)
	end
end)

local hitmarker = CreateClientConVar("ttt_specdm_hitmarker", 1, FCVAR_ARCHIVE)
local hitmarker_deadly = false

local respawntime = -2
local autorespawntime = -2

hook.Add("HUDPaint", "HUDPaint_SpecDM", function()
	if not IsValid(LocalPlayer()) or not LocalPlayer():IsGhost() then return end

	if hitmarker:GetBool() and hitmarker_remain and hitmarker_remain > CurTime() then
		local x = ScrW() / 2
		local y = ScrH() / 2

		if hitmarker_deadly then
			surface.SetDrawColor(COLOR_RED)
		else
			surface.SetDrawColor(COLOR_LIGHTGREY)
		end

		surface.DrawLine(x + 7, y - 7, x + 15, y - 15)
		surface.DrawLine(x - 7, y + 7, x - 15, y + 15)
		surface.DrawLine(x + 7, y + 7, x + 15, y + 15)
		surface.DrawLine(x - 7, y - 7, x - 15, y - 15)

		return
	end

	if LocalPlayer():Alive() then return end

	local x = ScrW() / 2
	local y = ScrH() / 4

	if autorespawntime ~= -2 then
		if SpecDM.AutomaticRespawnTime > 0 then
			local rtime = math.Round(autorespawntime - CurTime())

			draw.DrawText("Press a key to respawn!\nYou will be automaticly respawned in " .. rtime .. " second" .. (rtime ~= 1 and "s" or ""), "Trebuchet24", x, y, COLOR_WHITE, TEXT_ALIGN_CENTER)
		else
			draw.DrawText("Press a key to respawn!", "Trebuchet24", x, y, COLOR_WHITE, TEXT_ALIGN_CENTER)
		end
	elseif respawntime ~= -2 then
		local waittime = math.Round(respawntime - CurTime())

		if waittime > -1 then
			draw.DrawText("You need to wait " .. waittime .. " second(s) before you can respawn", "Trebuchet24", x, y, COLOR_WHITE, TEXT_ALIGN_CENTER)
		end
	end
end)

net.Receive("SpecDM_Hitmarker", function()
	if net.ReadBool() then
		hitmarker_deadly = true
	else
		hitmarker_deadly = false
	end

	hitmarker_remain = CurTime() + 0.35
end)

net.Receive("SpecDM_RespawnTimer", function()
	autorespawntime = -2
	respawntime = CurTime() + SpecDM.RespawnTime

	timer.Simple(SpecDM.RespawnTime, function()
		autorespawntime = CurTime() + SpecDM.AutomaticRespawnTime
		respawntime = -2
	end)
end)

concommand.Add("specdm", function()
	net.Start("SpecDM_ChangeState")
	net.SendToServer()
end)