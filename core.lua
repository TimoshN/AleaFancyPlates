if IsAddOnLoaded('Alea_TestAddon') then return end

local addon, core = ...
_G[addon] = core

local config
local PlateWidth, PlateHeight = 110, 10
local texture = 'Interface\\AddOns\\'.. addon ..'\\Minimalist.tga'
local font    = 'Interface\\AddOns\\'.. addon ..'\\GOTHICB.TTF'

local targetTexture = 'Interface\\AddOns\\'.. addon ..'\\gw001.blp'

local VirtualPlateWidth, VirtualPlateHeight = 80, 8

local plateAuraSize = 18

local ENABLE_LINES = true
local LINEFACTOR = 256/254;
local LINEFACTOR_2 = LINEFACTOR / 2;
local size = 512
local MAX_ICONS_PER_NAMEPLATE = 5
local COLORING_NAME = false
local SearchByName = {}
local raidRoster = {}
local SHOW_AURA_FLOAT = false
local FONT_SIZE_REAL_NP = 12
local FONT_SIZE_REAL_NP_CASTBAR = 8
local FONT_SIZE_REAL_NP_LEVEL = 8
local FONT_SIZE_FAKE_NP_LEFT = 7
local FONT_SIZE_FAKE_NP_RIGHT = 7

-- Mind Harvest Stuff
local custom_icon_plate = "Interface\\icons\\spell_warlock_harvestoflife"
local custom_icon_text_size_plate = 22
local custom_icon_size_plate = 20

local custom_icon = "Interface\\icons\\spell_warlock_harvestoflife"
local custom_icon_text_size = 12
local custom_icon_size = 10

local mind_harvest_enable_state = false
core.MindHarvest = {}

-- DEBUGG STUFF
local GUID_COUNTER = {}
local COUNTE_GUIDS = true
local testing = false
local CLEAR_GUID = {}
-------------------

local options = {
	reactions = {		
		tapped  		= { r = 0.6, 		g = 0.6, 	 b = 0.6 },
		neutral 		= { r = 218/255, 	g = 197/255, b = 92/255 },
		enemy 			= { r = 0.78, 		g = 0.25, 	 b = 0.25 },
		friendlyNPC 	= { r = 0.31,		g = 0.45, 	 b = 0.63},
		friendlyPlayer 	= { r = 75/255,  	g = 175/255, b = 76/255},
	},
	['threat'] = {
		["goodColor"] = {r = 75/255,  g = 175/255, b = 76/255},
		["badColor"] = {r = 0.78, g = 0.25, b = 0.25},
		["goodTransitionColor"] = {r = 218/255, g = 197/255, b = 92/255},
		["badTransitionColor"] = {r = 240/255, g = 154/255, b = 17/255},
	},
	castBar_color 		= {1,208/255,0 },
	castBar_noInterrupt = {0.78,0.25,0.25 },
}

local nameHighlight = {}
local namesublist = {}


 function core:UpdateNamePlateCvars()
	SetCVar('threatWarning', 3)
	SetCVar("ShowClassColorInNameplate", 1)	
	SetCVar("repositionfrequency", 0)
	--[[
		0 Overlapping
		1 Stacking
		2 Spreading
	]]
--	SetCVar("nameplateMotion",0)
	SetCVar('bloatthreat', 0)
 end
 
local FSPAT = "%s*"..((_G.FOREIGN_SERVER_LABEL:gsub("^%s", "")):gsub("[%*()]", "%%%1")).."$"

local function RawGetPlateName(frame)
    local name = frame.name:GetText();
    return frame.name:GetText():gsub(FSPAT,"");
end

local function RawGetName(name)
    return name:gsub(FSPAT,"");
end

local function DrawLine(T, C, sx, sy, ex, ey, w, relPoint)
   if (not relPoint) then relPoint = "BOTTOMLEFT"; end

   local dx,dy = ex - sx, ey - sy;
   local cx,cy = (sx + ex) / 2, (sy + ey) / 2;

   if (dx < 0) then
      dx,dy = -dx,-dy;
   end

   local l = sqrt((dx * dx) + (dy * dy));

   if (l == 0) then
      T:SetTexCoord(0,0,0,0,0,0,0,0);
      T:SetPoint("BOTTOMLEFT", C, relPoint, cx,cy);
      T:SetPoint("TOPRIGHT",   C, relPoint, cx,cy);
      return;
   end

   local s,c = -dy / l, dx / l;
   local sc = s * c;

   local Bwid, Bhgt, BLx, BLy, TLx, TLy, TRx, TRy, BRx, BRy;
   if (dy >= 0) then
      Bwid = ((l * c) - (w * s)) * LINEFACTOR_2;
      Bhgt = ((w * c) - (l * s)) * LINEFACTOR_2;
      BLx, BLy, BRy = (w / l) * sc, s * s, (l / w) * sc;
      BRx, TLx, TLy, TRx = 1 - BLy, BLy, 1 - BRy, 1 - BLx; 
      TRy = BRx;
   else
      Bwid = ((l * c) + (w * s)) * LINEFACTOR_2;
      Bhgt = ((w * c) + (l * s)) * LINEFACTOR_2;
      BLx, BLy, BRx = s * s, -(l / w) * sc, 1 + (w / l) * sc;
      BRy, TLx, TLy, TRy = BLx, 1 - BRx, 1 - BLx, 1 - BLy;
      TRx = TLy;
   end

   T:SetTexCoord(TLx, TLy, BLx, BLy, TRx, TRy, BRx, BRy);
   T:SetPoint("BOTTOMLEFT", C, relPoint, cx - Bwid, cy - Bhgt);
   T:SetPoint("TOPRIGHT",   C, relPoint, cx + Bwid, cy + Bhgt);
end

local AuraCache = {}
local named = {}
local RaidIconIndex = {
	"STAR",
	"CIRCLE",
	"DIAMOND",
	"TRIANGLE",
	"MOON",
	"SQUARE",
	"CROSS",
	"SKULL",
}

core.RaidTargetReference = {
	["STAR"] = 0x00000001,
	["CIRCLE"] = 0x00000002,
	["DIAMOND"] = 0x00000004,
	["TRIANGLE"] = 0x00000008,
	["MOON"] = 0x00000010,
	["SQUARE"] = 0x00000020,
	["CROSS"] = 0x00000040,
	["SKULL"] = 0x00000080,
}

local flagtort = {
   [COMBATLOG_OBJECT_RAIDTARGET8] = "SKULL",
   [COMBATLOG_OBJECT_RAIDTARGET7] = "CROSS",
   [COMBATLOG_OBJECT_RAIDTARGET6] = "SQUARE",
   [COMBATLOG_OBJECT_RAIDTARGET5] = "MOON",
   [COMBATLOG_OBJECT_RAIDTARGET4] = "TRIANGLE",
   [COMBATLOG_OBJECT_RAIDTARGET3] = "DIAMOND",
   [COMBATLOG_OBJECT_RAIDTARGET2] = "CIRCLE",
   [COMBATLOG_OBJECT_RAIDTARGET1] = "STAR",
 }
 
local Mover = CreateFrame("Frame", nil, WorldFrame, 'SecureHandlerStateTemplate')
Mover:SetSize(PlateWidth-20, 10)
Mover:SetPoint("CENTER", WorldFrame, "CENTER", 0, 0)
Mover:EnableMouse(true)
Mover:SetFrameStrata('BACKGROUND')
Mover:SetFrameLevel(0)
Mover:SetMovable(true)
Mover:RegisterForDrag("LeftButton")
Mover:SetScript("OnDragStart", function(self)  
	self:StartMoving()
end)
Mover:SetScript("OnDragStop", function(self) 
	self:StopMovingOrSizing()
	
	local x, y = self:GetCenter()
	local ux, uy = self:GetParent():GetCenter()

	config.pos = { floor(x - ux + 0.5),floor(y - uy + 0.5) }
end)

local LineCanvas = CreateFrame("Frame", nil, UIParent)
LineCanvas:SetAlpha(0.8)
LineCanvas:SetSize(1,1)
LineCanvas:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', 0, 0)
LineCanvas:SetPoint('BOTTOMRIGHT', UIParent, 'BOTTOMRIGHT', 0, 0)
LineCanvas:Hide()
local LineTexture = LineCanvas:CreateTexture(nil, 'ARTWORK')
LineTexture:SetTexture("Interface\\AddOns\\"..addon.."\\LineTemplate")
LineCanvas:SetScript('OnUpdate', function(self, elapsed)
	
	if not LineCanvas.from:IsShown() or not LineCanvas.to:IsShown() then 
		core.HideDrawLine()
		return 
	end
	
	local x1, y1 = self.from:GetCenter()
	local x2, y2 = self.to:GetCenter()	
	local esc = self.from:GetParent():GetEffectiveScale()/self.to:GetParent():GetEffectiveScale()
	x1 = (x1-55)*esc
	y1 = y1*esc
	DrawLine(LineTexture, self, x1, y1, x2+30, y2, 2);
end)

function core.SetDrawLine(from, to)

	if not ENABLE_LINES then
		core.HideDrawLine()
		return 
	end
	
	LineCanvas.from = from
	LineCanvas.to = to
	
	if not LineCanvas.from or not LineCanvas.to then return end
	if not LineCanvas.from:IsShown() or not LineCanvas.to:IsShown() then return end
	LineCanvas:Show()
	LineTexture:Show()
end

function core.HideDrawLine()
	LineCanvas.from = nil
	LineCanvas.to = nil
	LineCanvas:Hide()
	LineTexture:Hide()
end

local function CreateBackdrop(parent, point, scale)
	point = point or parent
	local noscalemult = scale or ( 1 * parent:GetScale() )
	
--	print("T", UIParent:GetScale(), parent:GetScale())
	if point.bordertop then return end

	point.backdrop = parent:CreateTexture(nil, "BORDER")
	point.backdrop:SetDrawLayer("BORDER", -4)
	point.backdrop:SetAllPoints(point)
	point.backdrop:SetTexture(0,0,0,0)		

	point.bordertop = parent:CreateTexture(nil, "BORDER")
	point.bordertop:SetPoint("TOPLEFT", point, "TOPLEFT", -noscalemult, noscalemult)
	point.bordertop:SetPoint("TOPRIGHT", point, "TOPRIGHT", noscalemult, noscalemult)
	point.bordertop:SetHeight(noscalemult)
	point.bordertop:SetTexture(0,0,0,1)	
	point.bordertop:SetDrawLayer("BORDER", 1)
		
	point.borderbottom = parent:CreateTexture(nil, "BORDER")
	point.borderbottom:SetPoint("BOTTOMLEFT", point, "BOTTOMLEFT", -noscalemult, -noscalemult)
	point.borderbottom:SetPoint("BOTTOMRIGHT", point, "BOTTOMRIGHT", noscalemult, -noscalemult)
	point.borderbottom:SetHeight(noscalemult)
	point.borderbottom:SetTexture(0,0,0,1)	
	point.borderbottom:SetDrawLayer("BORDER", 1)
		
	point.borderleft = parent:CreateTexture(nil, "BORDER")
	point.borderleft:SetPoint("TOPLEFT", point, "TOPLEFT", -noscalemult, noscalemult)
	point.borderleft:SetPoint("BOTTOMLEFT", point, "BOTTOMLEFT", noscalemult, -noscalemult)
	point.borderleft:SetWidth(noscalemult)
	point.borderleft:SetTexture(0,0,0,1)	
	point.borderleft:SetDrawLayer("BORDER", 1)
		
	point.borderright = parent:CreateTexture(nil, "BORDER")
	point.borderright:SetPoint("TOPRIGHT", point, "TOPRIGHT", noscalemult, noscalemult)
	point.borderright:SetPoint("BOTTOMRIGHT", point, "BOTTOMRIGHT", -noscalemult, -noscalemult)
	point.borderright:SetWidth(noscalemult)
	point.borderright:SetTexture(0,0,0,1)
	point.borderright:SetDrawLayer("BORDER", 1)	
end

local bg = Mover:CreateTexture(nil, "BACKGROUND", nil, -5)
bg:SetPoint("TOPLEFT", Mover, "TOPLEFT")
bg:SetPoint("BOTTOMRIGHT", Mover, "BOTTOMRIGHT")
bg:SetTexture(0,0,0,0.8)
	
local PlateSizer = CreateFrame('Frame', nil, WorldFrame, 'SecureHandlerStateTemplate')
PlateSizer:SetFrameRef('temp', Mover)
PlateSizer:Execute('Children, TempFrames, PlateChilds, PlateFrames, WorldFrame, Mover = newtable(), newtable(), newtable(), newtable(), self:GetParent(), self:GetFrameRef("temp")')

local durationCache = {}

local function CacheDuration(spellID, duration)
	if spellID and duration and not durationCache[spellID] then
		durationCache[spellID] = duration
	end
end

local SizePlates = format([[

 if newstate ~= 'off' then
	 wipe(Children)
	 local index = 0
	 WorldFrame:GetChildList(Children)

	 for i = 1, #Children do
		 local f = Children[i]
		 local name = f:GetName()
		 if name and strmatch(name, '^NamePlate%%d+$') then
			 if f:IsVisible() then
				f:SetWidth(%d)
				f:SetHeight(%d)
				f:ClearAllPoints()
				index = index + 1
				f:SetPoint("BOTTOM", Mover, "BOTTOM", 0, 0 + ( %d * index ) )
			 end
		
			 if not f:GetAttribute('WrappedForSizing') then
				 local temp = tremove(TempFrames, 1)
				 f:SetAttribute('WrappedForSizing', true)
				 temp:SetParent(f)
				 tinsert(TempFrames, temp)
				 
				 temp:Hide() 
				 temp:Show()
			 end
		 end
	 end
 end
]], PlateWidth, PlateHeight, (PlateHeight+3))

local TempFrames = {}
for i = 1, 100 do
 local f = CreateFrame('Frame', nil, nil, 'SecureHandlerShowHideTemplate')
 PlateSizer:WrapScript(f, 'OnShow', SizePlates)
 PlateSizer:WrapScript(f, 'OnHide', SizePlates)
 PlateSizer:SetFrameRef('temp', f)
 PlateSizer:Execute('tinsert(TempFrames, self:GetFrameRef("temp"))')
 tinsert(TempFrames, f)
end

PlateSizer:SetAttribute('_onstate-mousestate', SizePlates)
RegisterStateDriver(PlateSizer, 'mousestate', '[@mouseover,noexists,combat] on1; [@mouseover,exists,combat] on; off')

local secureHandlers = {
	{
		name = 'targetstate',
		data = '[@target, exists] showed; hidden',
		script = [[
		--	print('T', 'targetstate', newstate)
			self:Hide()
			self:Show()
		]],
	},
	{
		name = 'combatstate',
		data = '[combat] on; off',
		script = [[
		--	print('T', 'combatstate', newstate)
			self:Hide()
			self:Show()
		]],
	},
	{
		name = 'petstate',
		data = '[@pet, exists] on; off',
		script = [[
		--	print('T', 'petstate', newstate)
			self:Hide()
			self:Show()
		]],
	},
	{
		name = 'channeling',
		data = '[channeling] on; off',
		script = [[
		--	print('T', 'channeling', newstate)
			self:Hide()
			self:Show()
		]],
	
	},
	{
		name = 'wordlstate',
		data = '[mounted] mounted; [swimming] swimming; [flyable] flyable; [flying] flying; [indoors] indoors; [outdoors] outdoors;',
		script = [[
		--	print('T', 'wordlstate', newstate)
			self:Hide()
			self:Show()
		]],
	},
	{
		name = 'modifstates',
		data = '[nomod] nomod; [modifier:shift] shift; [modifier:ctrl] ctrl; [modifier:alt] alt;',
		script = [[
		--	print('T', 'modifstates', newstate)
			self:Hide()
			self:Show()
		]],
	},
}

for i=1, 5 do
	table.insert(secureHandlers, {
		name = 'boss'..i..'state',
		data = '[@boss'..i..',exists] on; off',
		script = [[
		--	print('T', 'bossstate', newstate)
			self:Hide()
			self:Show()
		]],
	})
end


local secureHandlertsFrames = {}


for i, datas in ipairs(secureHandlers) do
	secureHandlertsFrames[i] = CreateFrame('Frame', nil, UIParent, 'SecureHandlerStateTemplate')
	secureHandlertsFrames[i]:SetSize(1, 1)
	secureHandlertsFrames[i]:SetPoint('CENTER')
	secureHandlertsFrames[i]:SetAttribute('_onstate-'..datas.name, datas.script)

	RegisterStateDriver(secureHandlertsFrames[i], datas.name, datas.data)
	PlateSizer:WrapScript(secureHandlertsFrames[i], 'OnShow', SizePlates)
--	PlateSizer:WrapScript(secureHandlertsFrames[i], 'OnHide', SizePlates)
end



local Wrapped, PrevWorldChildren = {}, 0
local index2 = 0
local function IterateChildren(f, ...)
 if not f then return end
 local name = f:GetName()
 local isnameplate = (name and strmatch(name, '^NamePlate%d+$'))
 if isnameplate and f:IsVisible() then
	index2 = index2 + 1
 end

 if not Wrapped[f] and isnameplate then
 Wrapped[f] = true
 
	f.barFrame = f.ArtContainer
	f.nameFrame = f.NameContainer


	f.healthBar = f.ArtContainer.HealthBar
	-- f.healthBar.texture = f.healthBar:GetRegions() --No parentKey, yet?

	-- f.absorbBar = f.ArtContainer.AbsorbBar
	f.border = f.ArtContainer.Border
	f.highlight = f.ArtContainer.Highlight
	f.level = f.ArtContainer.LevelText
	f.raidIcon = f.ArtContainer.RaidTargetIcon
	f.eliteIcon = f.ArtContainer.EliteIcon
	f.threat = f.ArtContainer.AggroWarningTexture
	f.bossIcon = f.ArtContainer.HighLevelIcon
	f.name = f.NameContainer.NameText

	f.castBar = f.ArtContainer.CastBar
	-- f.castBar.texture = f.castBar:GetRegions() --No parentKey, yet?
	f.castBar.border = f.ArtContainer.CastBarBorder
	f.castBar.icon = f.ArtContainer.CastBarSpellIcon
	f.castBar.shield = f.ArtContainer.CastBarFrameShield
	f.castBar.name = f.ArtContainer.CastBarText
	f.castBar.shadow = f.ArtContainer.CastBarTextBG

 local x, y = f.barFrame:GetLeft(), f.barFrame:GetBottom()

 f.barFrame:SetSize(1, 1)
 
 --print('T1', f.barFrame:GetBottom())
 --print('T2', f.barFrame:GetLeft())
 --print('T3', f.barFrame:GetCenter())
 --print('T4', WorldFrame:GetCenter())
 
 local x1, y1 = f.barFrame:GetCenter()
 local x2, y2 = WorldFrame:GetCenter()
 
 --print('T5', x1 - x2, y1 - y2)
 
 f.barFrame:ClearAllPoints()
 f.barFrame:SetPoint("BOTTOM", WorldFrame, 'BOTTOM', x1 - x2, y)
 f.barFrame:SetSize(PlateWidth, PlateHeight)

  if f:IsVisible() then
	f:ClearAllPoints()
	f:SetSize(PlateWidth, PlateHeight)
	f:SetPoint("BOTTOM", Mover, "BOTTOM", 0, 0 + ( (PlateHeight+3) * index2 ) )
 end

 PlateSizer:WrapScript(f, 'OnShow', SizePlates)
 PlateSizer:WrapScript(f, 'OnHide', SizePlates)
 
 -- print('OutCombatWrapper')
 
 f:SetAttribute('WrappedForSizing', true)
 end
 IterateChildren(...)
end

PlateSizer:SetScript('OnUpdate', function()
 local numChildren = WorldFrame:GetNumChildren()
 if numChildren ~= PrevWorldChildren then PrevWorldChildren = numChildren
 index2 = 0
 IterateChildren(WorldFrame:GetChildren())
 end
end)

local lastNumNames = 0

local function OnSizeChanged(self, width, height)	
	self.f:Hide()
	self.f:SetPoint('CENTER', WorldFrame, 'BOTTOMLEFT', width, height)
	self.f:Show()
end

local function OnShow(self)
	local myPlate = named[self] 
	myPlate:Show()	
	local name = self.name:GetText()
	myPlate.name:SetText(name)
	myPlate.nameTarget:SetText(name)
	myPlate.healthBar.text1:SetText(name)
	
	local objectType
	for object in pairs(self.queue) do		
		objectType = object:GetObjectType()  
		if objectType == "Texture" then
			object.OldTexture = object:GetTexture()
			object:SetTexture("")
			object:SetTexCoord(0, 0, 0, 0)
		elseif objectType == 'FontString' then
			object:SetWidth(0.001)
		elseif objectType == 'StatusBar' then
			object:SetStatusBarTexture("")
		end
		object:Hide()
	end
	
	local plateName = RawGetName(name)
	
	self._rawName = plateName
	self.allowCheck = true
	self._postShowAllow = GetTime()+0.1

--	core.SetUnitInfo(self,myPlate)
	core.ColorizeAndScale(self,myPlate)
	core.UpdateLevelAndName(self,myPlate)
	
	core.HealthBar_OnValueChanged(self.healthBar, self.healthBar:GetValue())
	
	if SearchByName[plateName] then
		self.guid = SearchByName[plateName]
		core:UpdateAuras(self)
	else
		for i=1, MAX_ICONS_PER_NAMEPLATE do
			myPlate.healthBar.icons[i]:Hide()
			myPlate.healthBar_plate.icons[i]:Hide()
		end
	end
end

local function OnHide(self)
	local myPlate = named[self]
	self.unitType = nil
	self.guid = nil
	self.unit = nil
	self.raidIconType = nil
	self.customScale = nil
	self.isSmall = nil
	self.allowCheck = nil
	self._postShowAllow = 0
	
	core.targetArrow:ClearOwner(myPlate)
	
	for i=1, MAX_ICONS_PER_NAMEPLATE do
		myPlate.healthBar.icons[i]:Hide()
		myPlate.healthBar_plate.icons[i]:Hide()
	end
end

core.targetArrow = CreateFrame("Frame")
core.targetArrow:Hide()
core.targetArrow:SetSize(26, 26)
core.targetArrow:SetScript('OnUpdate', function(self, elapsed)		
	if self.down then
		self.elapsed = self.elapsed + elapsed
		if self.elapsed >= 0.4 then
			self.elapsed = 0.4
			self.down = false
		end
	else
		self.elapsed = self.elapsed - elapsed
		if self.elapsed <= 0 then
			self.elapsed = 0
			self.down = true
		end
	end

	self:SetPoint('BOTTOM', self.owner, 'BOTTOM', 0, 20+ 60*self.elapsed)
end)
core.targetArrow.SetOwner = function(self, owner)
	if self.owner ~= owner then
		self.owner = owner
		self.elapsed = 0
		self.down = true
		self:SetParent(owner)
	end
	self:Show()
end

core.targetArrow.ClearOwner = function(self, owner)
	if self.owner == owner then
		self.owner = nil
		self:Hide()
	end
end

core.targetArrow.texture = core.targetArrow:CreateTexture(nil, 'ARTWORK')
core.targetArrow.texture:SetAllPoints()
core.targetArrow.texture:SetTexture(targetTexture)
core.targetArrow.texture:SetTexCoord(0.03, 0.53, 0.05, 0.6)
core.targetArrow.texture:SetVertexColor(1,0,0,1)

core.targetArrow.texture_shadow = core.targetArrow:CreateTexture(nil, 'BACKGROUND')
core.targetArrow.texture_shadow:SetPoint('TOPLEFT', core.targetArrow.texture, 'TOPLEFT', -2, 2)
core.targetArrow.texture_shadow:SetPoint('BOTTOMRIGHT', core.targetArrow.texture, 'BOTTOMRIGHT', 2, -2)
core.targetArrow.texture_shadow:SetTexture(targetTexture)
core.targetArrow.texture_shadow:SetTexCoord(0.03, 0.53, 0.05, 0.6)
core.targetArrow.texture_shadow:SetVertexColor(0,0,0,1)

function core:QueueObject(frame, object)
	frame.queue = frame.queue or {}
	frame.queue[object] = true

	if object.OldTexture then
		object:SetTexture(object.OldTexture)
	end
end

function core:UpdateLevelAndName(myPlate)

	if self.level:IsShown() then
		local level, elite, boss, mylevel = self.level:GetObjectType() == 'FontString' and tonumber(self.level:GetText()) or nil, self.eliteIcon:IsShown(), self.bossIcon:IsShown(), UnitLevel("player")
		if boss then
			myPlate.level:SetText("??")
			myPlate.level:SetTextColor(0.8, 0.05, 0)
		elseif level then
			myPlate.level:SetText(level..(elite and "+" or ""))
			myPlate.level:SetTextColor(self.level:GetTextColor())
		end
	elseif self.bossIcon:IsShown() and myPlate.level:GetText() ~= '??' then
		myPlate.level:SetText("??")
		myPlate.level:SetTextColor(0.8, 0.05, 0)
	end

	if self.isSmall then
		myPlate.level:SetText("")
		myPlate.level:Hide()
	elseif not myPlate.level:IsShown() then
		myPlate.level:Show()
	end
	
	local name = self.name:GetText()
	
	if namesublist[name] then
		myPlate.name:SetText(namesublist[name])
	else
		myPlate.name:SetText(name)
	end
	
	myPlate.realname = name
end

function core:SetAlpha(myPlate)
	if self:GetAlpha() < 1 then
		myPlate:SetAlpha(0.6)
	else
		myPlate:SetAlpha(1)
	end
end


local green =  {0, 1, 0}
function core:CastBar_OnValueChanged(value)
	local blizzPlate = self:GetParent():GetParent()
	local myPlate = named[blizzPlate]
	local min, max = self:GetMinMaxValues()
	local isChannel = value < myPlate.castBar_plate:GetValue()
	local castBarIcon = blizzPlate.castBar.icon:GetTexture()
	local spellName = blizzPlate.castBar.name:GetText()
	
	myPlate.castBar_plate:SetMinMaxValues(min, max)
	myPlate.castBar_plate:SetValue(value)
	myPlate.castBar_plate.texture:SetTexture(castBarIcon)
	myPlate.castBar_plate.name:SetText(spellName)
	myPlate.castBar_plate.time:SetFormattedText('%.1f', value)

	myPlate.healthBar_castBarMirror:SetMinMaxValues(min, max)
	myPlate.healthBar_castBarMirror:SetValue(value)
	myPlate.healthBar_castBarMirror.icons.texture:SetTexture(castBarIcon)
	myPlate.healthBar_castBarMirror.name:SetText(spellName)
	myPlate.healthBar_castBarMirror.timer:SetFormattedText('%.1f', value)
	
	local color
	if(self.shield:IsShown()) then
		color = options.castBar_noInterrupt
	else
		if value > 0 and (isChannel and (value/max) <= 0.02 or (value/max) >= 0.98) then
			color = green
		else
			color = options.castBar_color
		end
	end			

	myPlate.castBar_plate:SetStatusBarColor(color[1], color[2], color[3])	
	myPlate.healthBar_castBarMirror:SetStatusBarColor(color[1], color[2], color[3])
end

function core:CastBar_OnShow()
	local blizzPlate = self:GetParent():GetParent()
	local myPlate = named[blizzPlate]

	blizzPlate.castBar.icon:SetAlpha(0)
	
	myPlate.castBar_plate:Show()
	myPlate.healthBar_castBarMirror:Show()
end

function core:CastBar_OnHide()
	local myPlate = named[self:GetParent():GetParent()]

	myPlate.castBar_plate:Hide()
	myPlate.healthBar_castBarMirror:Hide()
end

function core:healthBar_icons_OnUpdate(elapsed)			
	if self.endTime-GetTime() > 3 then
		self.text1:SetText(format('%d', self.endTime-GetTime()))
	elseif self.endTime-GetTime() > 0 then
		self.text1:SetText(format((SHOW_AURA_FLOAT and '%.1f' or '%d'), self.endTime-GetTime()))
	else
		self:Hide()
		core:UpdateAuras(self.blizzPlate)
	end
end


local function IterateChildren_Named(f, ...)
	if not f then return end
	local name = f:GetName()
	if not named[f] and name and strmatch(name, '^NamePlate%d+$') then
	
		f.barFrame = f.ArtContainer
		f.nameFrame = f.NameContainer
		
		
		f.healthBar = f.ArtContainer.HealthBar
		-- f.healthBar.texture = f.healthBar:GetRegions() --No parentKey, yet?

		-- f.absorbBar = f.ArtContainer.AbsorbBar
		f.border = f.ArtContainer.Border
		f.highlight = f.ArtContainer.Highlight
		f.level = f.ArtContainer.LevelText
		f.raidIcon = f.ArtContainer.RaidTargetIcon
		f.eliteIcon = f.ArtContainer.EliteIcon
		f.threat = f.ArtContainer.AggroWarningTexture
		f.bossIcon = f.ArtContainer.HighLevelIcon
		f.name = f.NameContainer.NameText
		
		f.castBar = f.ArtContainer.CastBar
		-- f.castBar.texture = f.castBar:GetRegions() --No parentKey, yet?
		f.castBar.border = f.ArtContainer.CastBarBorder
		f.castBar.icon = f.ArtContainer.CastBarSpellIcon
		f.castBar.shield = f.ArtContainer.CastBarFrameShield
		f.castBar.name = f.ArtContainer.CastBarText
		f.castBar.shadow = f.ArtContainer.CastBarTextBG

 
		local point = f.barFrame --f.barFrame or f:GetChildren()
		
		local myPlate = CreateFrame("Frame", nil, UIParent)
		myPlate.blizzPlate = f
		
		myPlate:SetSize(1, 1)
	
		local sizer = CreateFrame('frame', nil, myPlate)
		sizer.f = myPlate
		myPlate.sizer = sizer
		sizer:SetScript('OnSizeChanged', OnSizeChanged)
		sizer:SetPoint('BOTTOMLEFT', WorldFrame)
		sizer:SetPoint('TOPRIGHT', point, 'CENTER')
	
		OnSizeChanged(sizer, sizer:GetSize())
		
		core:QueueObject(f, f.healthBar)
		core:QueueObject(f, f.castBar)
		core:QueueObject(f, f.level)
		core:QueueObject(f, f.name)
		core:QueueObject(f, f.threat)
		core:QueueObject(f, f.border)
		core:QueueObject(f, f.castBar.shield)
		core:QueueObject(f, f.castBar.border)
		core:QueueObject(f, f.castBar.shadow)
		core:QueueObject(f, f.castBar.name)
		core:QueueObject(f, f.castBar.icon)
		core:QueueObject(f, f.bossIcon)
		core:QueueObject(f, f.eliteIcon)
		
		myPlate.healthBar_plate = CreateFrame("StatusBar", nil, myPlate)
		myPlate.healthBar_plate:SetSize(VirtualPlateWidth, VirtualPlateHeight)
		myPlate.healthBar_plate:SetPoint('TOP', myPlate, 'TOP', 0, -2)
		myPlate.healthBar_plate:SetStatusBarTexture(texture)
		myPlate.healthBar_plate:GetStatusBarTexture():SetDrawLayer('OVERLAY', 1)
		
		myPlate.name = myPlate.healthBar_plate:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
		myPlate.name:SetJustifyH("LEFT")
		myPlate.name:SetFont(font, FONT_SIZE_REAL_NP, 'NONE')
		myPlate.name:SetTextColor(1,1,1,1)
		myPlate.name:SetWordWrap(false)
		myPlate.name:SetPoint("BOTTOM", myPlate,"BOTTOM")
		myPlate.name:SetText("TEST")
		
		myPlate.nameTarget = myPlate.healthBar_plate:CreateFontString(nil, 'OVERLAY', 'GameFontNormal', 2)
		myPlate.nameTarget:SetJustifyH("LEFT")
		myPlate.nameTarget:SetFont(font, FONT_SIZE_REAL_NP, 'OUTLINE')
		myPlate.nameTarget:SetTextColor(1,1,1,1)
		myPlate.nameTarget:SetWordWrap(false)
		myPlate.nameTarget:SetPoint("BOTTOM", myPlate,"BOTTOM", 1, 0)
		myPlate.nameTarget:SetText("TEST")
		
		CreateBackdrop(myPlate.healthBar_plate)
		
		myPlate.healthBar_plate.texture = myPlate.healthBar_plate:CreateTexture()
		myPlate.healthBar_plate.texture:SetAllPoints()
		myPlate.healthBar_plate.texture:SetDrawLayer('BACKGROUND')
		myPlate.healthBar_plate.texture:SetTexture(0, 0, 0, 0.5)

		myPlate.mh_nameplate_fake = CreateFrame("Frame", nil, myPlate.healthBar_plate)
		myPlate.mh_nameplate_fake:SetSize(custom_icon_size_plate, custom_icon_size_plate)
		myPlate.mh_nameplate_fake:SetPoint("BOTTOMRIGHT", myPlate.healthBar_plate, "TOPLEFT", 0, 15)
		myPlate.mh_nameplate_fake:Hide()
	--	myPlate.mh_nameplate_fake:SetScale(0.0001)
		
		myPlate.mh_nameplate_fake.icon = myPlate.mh_nameplate_fake:CreateTexture(nil, 'OVERLAY')
		myPlate.mh_nameplate_fake.icon:SetTexCoord(.1, .9, .2, .8)
		myPlate.mh_nameplate_fake.icon:SetTexture(custom_icon_plate)
		myPlate.mh_nameplate_fake.icon:SetAllPoints(myPlate.mh_nameplate_fake)
	   
		myPlate.mh_nameplate_fake.status = myPlate.mh_nameplate_fake:CreateFontString(nil, 'OVERLAY')
		myPlate.mh_nameplate_fake.status:SetPoint("CENTER", myPlate.mh_nameplate_fake, "CENTER", 1, -1)
		myPlate.mh_nameplate_fake.status:SetJustifyH("LEFT")
		myPlate.mh_nameplate_fake.status:SetFont(STANDARD_TEXT_FONT, custom_icon_text_size_plate, "THICKOUTLINE")	
		if mind_harvest_enable_state then 
			myPlate.mh_nameplate_fake:Show() 
	--		myPlate.mh_nameplate_fake:SetScale(1)
		end
		CreateBackdrop(myPlate.mh_nameplate_fake, myPlate.mh_nameplate_fake.icon)
		
		myPlate._testing = myPlate.healthBar_plate:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
		myPlate._testing:SetJustifyH("CENTER")
		myPlate._testing:SetFont(font, 10, 'OUTLINE')
		myPlate._testing:SetTextColor(1,1,1,1)
		myPlate._testing:SetPoint("BOTTOM", myPlate,"BOTTOM", 0, 15)
		myPlate._testing:SetText("TEST")
		myPlate._testing:Hide()
		if testing then
			myPlate._testing:Show()
		end
		
		
		myPlate.castBar_plate = CreateFrame("StatusBar", nil, myPlate.healthBar_plate)
		myPlate.castBar_plate:SetPoint('TOP', myPlate.healthBar_plate, 'BOTTOM', 0, -3)
		myPlate.castBar_plate:SetSize(VirtualPlateWidth, 5)
		myPlate.castBar_plate:SetFrameStrata("BACKGROUND")
		myPlate.castBar_plate:SetFrameLevel(0)
		myPlate.castBar_plate:SetStatusBarTexture(texture)
		
		CreateBackdrop(myPlate.castBar_plate)
		
		myPlate.castBar_plate.texture = myPlate.castBar_plate:CreateTexture(nil, 'BACKGROUND')
		myPlate.castBar_plate.texture:SetSize(20, 20)
		myPlate.castBar_plate.texture:SetTexCoord(.07, .93, .07, .93)
		myPlate.castBar_plate.texture:SetDrawLayer("OVERLAY")
		myPlate.castBar_plate.texture:SetPoint("TOPLEFT", myPlate.healthBar_plate, "TOPRIGHT", 5, 0)
		
		myPlate.castBar_plate.time = myPlate.castBar_plate:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
		myPlate.castBar_plate.time:SetPoint("TOPRIGHT", myPlate.castBar_plate, "BOTTOMRIGHT", 6, -2)
		myPlate.castBar_plate.time:SetTextColor(1,1,1,1)
		myPlate.castBar_plate.time:SetJustifyH("RIGHT")
		myPlate.castBar_plate.time:SetFont(font, FONT_SIZE_REAL_NP_CASTBAR)
		myPlate.castBar_plate.time:SetWordWrap(false)
		
		myPlate.castBar_plate.name = myPlate.castBar_plate:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
		myPlate.castBar_plate.name:SetPoint("TOPLEFT", myPlate.castBar_plate, "BOTTOMLEFT", 0, -2)
		myPlate.castBar_plate.name:SetPoint("TOPRIGHT", myPlate.castBar_plate.time, "TOPLEFT", 0, -2)
		myPlate.castBar_plate.name:SetJustifyH("LEFT")
		myPlate.castBar_plate.name:SetWordWrap(false)
		myPlate.castBar_plate.name:SetTextColor(1,1,1,1)
		f.castBar.icon:SetAlpha(0)
	
		myPlate.level = myPlate.healthBar_plate:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
		myPlate.level:SetFont(font, FONT_SIZE_REAL_NP_LEVEL, 'OUTLINE')
		myPlate.level:SetTextColor(1,1,1,1)
		myPlate.level:SetPoint('TOPLEFT', myPlate.healthBar_plate,  "TOPRIGHT", 1, 0)
		myPlate.level:SetJustifyH("RIGHT")
		
		myPlate.healthBar = CreateFrame("StatusBar", nil, f)
		myPlate.healthBar:SetSize(1, 1)
		myPlate.healthBar:SetPoint('TOPLEFT', f, 'TOPLEFT', 0, 0)
		myPlate.healthBar:SetPoint('BOTTOMRIGHT', f, 'BOTTOMRIGHT', 0, 0)
		myPlate.healthBar:SetFrameStrata("BACKGROUND")
		myPlate.healthBar:SetFrameLevel(2)
		myPlate.healthBar:SetStatusBarTexture(texture)
		CreateBackdrop(myPlate.healthBar, nil, UIParent:GetScale())
		
		myPlate.raidIconParent = CreateFrame('Frame', nil, myPlate.healthBar)
		myPlate.raidIconParent:SetPoint("CENTER")
		myPlate.raidIconParent:SetSize(1,1)
		
		f.raidIcon:SetAlpha(0)
		
		myPlate.raidIcon = myPlate.raidIconParent:CreateTexture(nil, 'OVERLAY', nil, 3)
		myPlate.raidIcon:SetSize(16, 16)
		myPlate.raidIcon:SetPoint("CENTER", myPlate.healthBar, "CENTER", 0, 0)
		myPlate.raidIcon:SetTexture([[Interface\TargetingFrame\UI-RaidTargetingIcons]])
		myPlate.raidIcon:Hide()
		
		myPlate.mh_nameplate = CreateFrame("Frame", nil, myPlate.healthBar)
		myPlate.mh_nameplate:SetSize(custom_icon_size, custom_icon_size)
		myPlate.mh_nameplate:SetPoint("BOTTOMRIGHT", myPlate.healthBar, "BOTTOMLEFT", -3, 0)
		myPlate.mh_nameplate:Hide()
		myPlate.mh_nameplate:SetScale(0.0001)
		
		myPlate.mh_nameplate.icon = myPlate.mh_nameplate:CreateTexture(nil, 'OVERLAY')
		myPlate.mh_nameplate.icon:SetTexCoord(.1, .9, .2, .8)
		myPlate.mh_nameplate.icon:SetTexture(custom_icon)
		myPlate.mh_nameplate.icon:SetAllPoints(myPlate.mh_nameplate)
	   
	    CreateBackdrop(myPlate.mh_nameplate, myPlate.mh_nameplate.icon, UIParent:GetScale())
	   
		myPlate.mh_nameplate.status = myPlate.mh_nameplate:CreateFontString(nil, 'OVERLAY')
		myPlate.mh_nameplate.status:SetPoint("CENTER", myPlate.mh_nameplate, "CENTER", 1, -1)
		myPlate.mh_nameplate.status:SetJustifyH("LEFT")
		myPlate.mh_nameplate.status:SetFont(STANDARD_TEXT_FONT, custom_icon_text_size, "THICKOUTLINE")		
		if mind_harvest_enable_state then 
			myPlate.mh_nameplate:SetScale(1)
			myPlate.mh_nameplate:Show() 
		end
		
		myPlate.aggro = CreateFrame("Frame", nil, myPlate)
		myPlate.aggro:SetPoint('TOPLEFT', f, 'TOPLEFT', -4, 4)
		myPlate.aggro:SetPoint('BOTTOMRIGHT', f, 'BOTTOMRIGHT', 4, -4)
		myPlate.aggro:SetFrameStrata("BACKGROUND")
		myPlate.aggro:SetBackdrop( {	
			edgeFile = "Interface\\AddOns\\"..addon.."\\glow", edgeSize = 3,
			insets = {left = 5, right = 5, top = 5, bottom = 5},
		})		
		myPlate.aggro:SetBackdropBorderColor(1, 0, 0, 1)
		myPlate.aggro:SetScale(1)
	
		myPlate.raidIcon_main = myPlate.healthBar_plate:CreateTexture(nil, 'OVERLAY', nil, 3)
		myPlate.raidIcon_main:SetSize(16, 16)
		myPlate.raidIcon_main:SetTexture([[Interface\TargetingFrame\UI-RaidTargetingIcons]])
		myPlate.raidIcon_main:SetPoint("RIGHT", myPlate.healthBar_plate, 'LEFT', -2, 0)
		myPlate.raidIcon_main:Hide()
		
		myPlate.healthBar.overlay = myPlate.healthBar:CreateTexture(nil, 'OVERLAY')
		myPlate.healthBar.overlay:SetAllPoints()
		myPlate.healthBar.overlay:SetTexture(1, 1, 1, 0.2)
		
		myPlate.healthBar.texture = myPlate.healthBar:CreateTexture(nil, 'BACKGROUND')
		myPlate.healthBar.texture:SetAllPoints()
		myPlate.healthBar.texture:SetTexture(0, 0, 0, 0.5)
		
		myPlate.healthBar.text = myPlate.healthBar:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
		myPlate.healthBar.text:SetFont(font, FONT_SIZE_FAKE_NP_LEFT, 'OUTLINE')
		myPlate.healthBar.text:SetTextColor(1,1,1,1)
		myPlate.healthBar.text:SetPoint("BOTTOMRIGHT", myPlate.healthBar, "BOTTOMRIGHT", 3, 1)
		myPlate.healthBar.text:SetJustifyH("CENTER")
		myPlate.healthBar.text:SetWordWrap(false)
		
		myPlate.healthBar.text1 = myPlate.healthBar:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
		myPlate.healthBar.text1:SetFont(font, FONT_SIZE_FAKE_NP_RIGHT, 'OUTLINE')
		myPlate.healthBar.text1:SetJustifyH("LEFT")
		myPlate.healthBar.text1:SetTextColor(1,1,1,1)
		myPlate.healthBar.text1:SetPoint("BOTTOMRIGHT", myPlate.healthBar.text, "BOTTOMLEFT", 0, 1)
		myPlate.healthBar.text1:SetPoint("BOTTOMLEFT", myPlate.healthBar, "BOTTOMLEFT", 0, 1)
		myPlate.healthBar.text1:SetWordWrap(false)
		---------------------------------
		-- Cast bar for real plates
		---------------------------------
		
		myPlate.healthBar_castBarMirror = CreateFrame("StatusBar", nil, myPlate.healthBar)
		myPlate.healthBar_castBarMirror:SetSize(80, 80)
		myPlate.healthBar_castBarMirror:SetPoint('TOPLEFT', myPlate.healthBar, 'TOPRIGHT', 5+PlateHeight, 0)
		myPlate.healthBar_castBarMirror:SetPoint('BOTTOMLEFT', myPlate.healthBar, 'BOTTOMRIGHT', 5+PlateHeight, 0)
		myPlate.healthBar_castBarMirror:SetFrameStrata("BACKGROUND")
		myPlate.healthBar_castBarMirror:SetFrameLevel(4)
		myPlate.healthBar_castBarMirror:SetStatusBarTexture(texture)
		myPlate.healthBar_castBarMirror:Hide()
		CreateBackdrop(myPlate.healthBar_castBarMirror, nil, UIParent:GetScale())
		
		
		myPlate.healthBar_castBarMirror.icons = CreateFrame("Frame", nil, myPlate.healthBar_castBarMirror)		
		myPlate.healthBar_castBarMirror.icons:SetPoint('TOPRIGHT', myPlate.healthBar_castBarMirror, 'TOPLEFT', -1, 0)	
		myPlate.healthBar_castBarMirror.icons:SetSize(PlateHeight, PlateHeight)
		myPlate.healthBar_castBarMirror.icons.texture = myPlate.healthBar_castBarMirror.icons:CreateTexture(nil, 'ARTWORK')
		myPlate.healthBar_castBarMirror.icons.texture:SetAllPoints()
		myPlate.healthBar_castBarMirror.icons.texture:SetTexture(1, 0, 0, 1)		
		myPlate.healthBar_castBarMirror.icons.texture:SetTexCoord(.07, .93, .07, .93)
		CreateBackdrop(	myPlate.healthBar_castBarMirror.icons, 	myPlate.healthBar_castBarMirror.icons.texture, UIParent:GetScale())
		
		myPlate.healthBar_castBarMirror.timer = myPlate.healthBar_castBarMirror:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
		myPlate.healthBar_castBarMirror.timer:SetFont(font, 8, 'OUTLINE')
		myPlate.healthBar_castBarMirror.timer:SetJustifyH("LEFT")
		myPlate.healthBar_castBarMirror.timer:SetTextColor(1,1,1,1)
		myPlate.healthBar_castBarMirror.timer:SetPoint("BOTTOMRIGHT", myPlate.healthBar_castBarMirror, "BOTTOMRIGHT", 0, 1)
		myPlate.healthBar_castBarMirror.timer:SetWordWrap(false)
		myPlate.healthBar_castBarMirror.timer:SetText('0:00')
		
		myPlate.healthBar_castBarMirror.name = myPlate.healthBar_castBarMirror:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
		myPlate.healthBar_castBarMirror.name:SetFont(font, 8, 'OUTLINE')
		myPlate.healthBar_castBarMirror.name:SetJustifyH("LEFT")
		myPlate.healthBar_castBarMirror.name:SetTextColor(1,1,1,1)
		myPlate.healthBar_castBarMirror.name:SetPoint("BOTTOMLEFT", myPlate.healthBar_castBarMirror, "BOTTOMLEFT", 0, 1)
		myPlate.healthBar_castBarMirror.name:SetPoint("BOTTOMRIGHT", myPlate.healthBar_castBarMirror.timer, "BOTTOMLEFT", 0, 1)
		myPlate.healthBar_castBarMirror.name:SetWordWrap(false)
		myPlate.healthBar_castBarMirror.name:SetText('HelloName')


		f.healthBar:HookScript("OnValueChanged", core.HealthBar_OnValueChanged)
		f:HookScript("OnShow", OnShow)
		f:HookScript("OnHide", OnHide)

		f.castBar:HookScript("OnShow", core.CastBar_OnShow)
		f.castBar:HookScript("OnHide", core.CastBar_OnHide)
		f.castBar:HookScript("OnValueChanged", core.CastBar_OnValueChanged)

		myPlate.healthBar.icons = {}
		for i=1, MAX_ICONS_PER_NAMEPLATE do
			myPlate.healthBar.icons[i] = CreateFrame("Frame", nil, myPlate.healthBar)
			myPlate.healthBar.icons[i]:SetSize(PlateHeight, PlateHeight)
			myPlate.healthBar.icons[i].blizzPlate = f
			if i == 1 then
				myPlate.healthBar.icons[i]:SetPoint('BOTTOMRIGHT', myPlate.mh_nameplate, "BOTTOMLEFT", -2, 0)
			else
				myPlate.healthBar.icons[i]:SetPoint('RIGHT', myPlate.healthBar.icons[i-1], "LEFT",  -2, 0)
			end
			
			myPlate.healthBar.icons[i].texture = myPlate.healthBar.icons[i]:CreateTexture(nil, 'ARTWORK')
			myPlate.healthBar.icons[i].texture:SetAllPoints()
			myPlate.healthBar.icons[i].texture:SetTexture(1, 0, 0, 1)
			
			myPlate.healthBar.icons[i].texture:SetTexCoord(.07, .93, .07, .93)
			
			CreateBackdrop(myPlate.healthBar.icons[i], myPlate.healthBar.icons[i].texture, UIParent:GetScale())
			
			myPlate.healthBar.icons[i].text1 = myPlate.healthBar.icons[i]:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
			myPlate.healthBar.icons[i].text1:SetFont(font, 7, 'OUTLINE')
			myPlate.healthBar.icons[i].text1:SetTextColor(1,1,1,1)
			myPlate.healthBar.icons[i].text1:SetPoint("TOPLEFT", myPlate.healthBar.icons[i], "TOPLEFT", 0, 0)
			myPlate.healthBar.icons[i].text1:SetJustifyH("CENTER")
			myPlate.healthBar.icons[i].text1:SetWordWrap(false)
			myPlate.healthBar.icons[i].text1:SetText('')
			
			myPlate.healthBar.icons[i].text = myPlate.healthBar.icons[i]:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
			myPlate.healthBar.icons[i].text:SetFont(font, 7, 'OUTLINE')
			myPlate.healthBar.icons[i].text:SetTextColor(1,1,1,1)
			myPlate.healthBar.icons[i].text:SetPoint("BOTTOMRIGHT", myPlate.healthBar.icons[i], "BOTTOMRIGHT", 0, 0)
			myPlate.healthBar.icons[i].text:SetJustifyH("CENTER")
			myPlate.healthBar.icons[i].text:SetWordWrap(false)
			myPlate.healthBar.icons[i].text:SetText('')
			
			myPlate.healthBar.icons[i]:Hide()

			myPlate.healthBar.icons[i]:SetScript("OnUpdate", core.healthBar_icons_OnUpdate)
		end
		
		myPlate.healthBar_plate.icons = {}
		for i=1, MAX_ICONS_PER_NAMEPLATE do
			myPlate.healthBar_plate.icons[i] = CreateFrame("Frame", nil, myPlate.healthBar_plate)
			myPlate.healthBar_plate.icons[i]:SetSize(plateAuraSize, plateAuraSize)
			myPlate.healthBar_plate.icons[i].blizzPlate = f
			if i == 1 then
				myPlate.healthBar_plate.icons[i]:SetPoint('BOTTOMLEFT', myPlate.mh_nameplate_fake, "BOTTOMRIGHT", 3, 0)
			else
				myPlate.healthBar_plate.icons[i]:SetPoint('LEFT', myPlate.healthBar_plate.icons[i-1], "RIGHT", 3, 0)
			end
			
			myPlate.healthBar_plate.icons[i].texture = myPlate.healthBar_plate.icons[i]:CreateTexture(nil, 'OVERLAY')
			myPlate.healthBar_plate.icons[i].texture:SetAllPoints()
			myPlate.healthBar_plate.icons[i].texture:SetTexture(1, 0, 0, 1)
			
			CreateBackdrop(myPlate.healthBar_plate.icons[i], myPlate.healthBar_plate.icons[i].texture)
			
			myPlate.healthBar_plate.icons[i].texture:SetTexCoord(.07, .93, .07, .93)
			
			myPlate.healthBar_plate.icons[i].text1 = myPlate.healthBar_plate.icons[i]:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
			myPlate.healthBar_plate.icons[i].text1:SetFont(font, 10, 'OUTLINE')
			myPlate.healthBar_plate.icons[i].text1:SetTextColor(1,1,1,1)
			myPlate.healthBar_plate.icons[i].text1:SetPoint("TOPLEFT", myPlate.healthBar_plate.icons[i], "TOPLEFT", 0, 0)
			myPlate.healthBar_plate.icons[i].text1:SetJustifyH("CENTER")
			myPlate.healthBar_plate.icons[i].text1:SetWordWrap(false)
			myPlate.healthBar_plate.icons[i].text1:SetText('')
			
			myPlate.healthBar_plate.icons[i].text = myPlate.healthBar_plate.icons[i]:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
			myPlate.healthBar_plate.icons[i].text:SetFont(font, 10, 'OUTLINE')
			myPlate.healthBar_plate.icons[i].text:SetTextColor(1,1,1,1)
			myPlate.healthBar_plate.icons[i].text:SetPoint("BOTTOMRIGHT", myPlate.healthBar_plate.icons[i], "BOTTOMRIGHT", 0, 0)
			myPlate.healthBar_plate.icons[i].text:SetJustifyH("CENTER")
			myPlate.healthBar_plate.icons[i].text:SetWordWrap(false)
			myPlate.healthBar_plate.icons[i].text:SetText('')
			
			myPlate.healthBar_plate.icons[i]:Hide()
			
			myPlate.healthBar_plate.icons[i]:SetScript("OnUpdate", core.healthBar_icons_OnUpdate)
		end

		named[f] = myPlate
		
		core.HealthBar_OnValueChanged(f.healthBar, f.healthBar:GetValue())
		OnShow(f)
		core.UpdateLevelAndName(f, myPlate)
		core.ColorizeAndScale(f, myPlate)
		core.SetAlpha(f, myPlate)
		
		if not f.castBar:IsShown() then
			myPlate.castBar_plate:Hide()
			myPlate.healthBar_castBarMirror:Hide()
		else
			core.CastBar_OnShow(f.castBar)
		end
	end
	IterateChildren_Named(...)
end

core.targetName = nil
core.NumTargetChecks = 0

function core.HealthBar_OnValueChanged(self, value)
	local myPlate = named[self:GetParent():GetParent()]
	local minValue, maxValue = self:GetMinMaxValues()
	myPlate.healthBar:SetMinMaxValues(minValue, maxValue)
	myPlate.healthBar:SetValue(value)
	
	myPlate.healthBar_plate:SetMinMaxValues(minValue, maxValue)
	myPlate.healthBar_plate:SetValue(value)
	
	if value and maxValue and maxValue > 0 and self:GetScale() == 1 then
		myPlate.healthBar.text:Show()
		myPlate.healthBar.text:SetText(format('%d%%', (value * 100)/maxValue))
	else
		myPlate.healthBar.text:Hide()
	end
	
end

function core:UpdateAuras(frame)
	local guid = frame.guid
	local myPlate = named[frame]
	
	local data = AuraCache[guid]
		
	local index = 1
	
	for i = 1, MAX_ICONS_PER_NAMEPLATE do
		myPlate.healthBar.icons[i]:Hide()
		myPlate.healthBar_plate.icons[i]:Hide()
	end

	if not data then return end
	
	for spellID, spells in pairs(data) do
		if spells and spells[2] > GetTime() then
			myPlate.healthBar.icons[index].texture:SetTexture(GetSpellTexture(spellID))			
			myPlate.healthBar.icons[index].endTime = spells[2]
			myPlate.healthBar.icons[index].duration = spells[1]
			myPlate.healthBar.icons[index]:Show()
			myPlate.healthBar.icons[index].texture:SetDesaturated(false)
			
			myPlate.healthBar_plate.icons[index].texture:SetTexture(GetSpellTexture(spellID))			
			myPlate.healthBar_plate.icons[index].endTime = spells[2]
			myPlate.healthBar_plate.icons[index].duration = spells[1]
			myPlate.healthBar_plate.icons[index]:Show()
			myPlate.healthBar_plate.icons[index].texture:SetDesaturated(false)
			
			index = index + 1
			
			if index > MAX_ICONS_PER_NAMEPLATE then
				break
			end
		elseif spells then
			data[spellID] = nil
		end
	end
end

local spellName, _, icon, amount, debuffType, duration, endTime, sUnit, spellID
function core:UpdateAurasByUnitID(unit)
	local guid = UnitGUID(unit)
	local name = UnitName(unit)
	local index = 1
	while ( true ) do
		spellName, _, icon, amount, debuffType, duration, endTime, sUnit, _, _, spellID = UnitAura(unit, index, 'PLAYER|HARMFUL')		
		if not spellName then break end

		index = index + 1
		
		CacheDuration(spellID, duration)
		
		AuraCache[guid] = AuraCache[guid] or {}
		AuraCache[guid][spellID] = AuraCache[guid][spellID] or {}	
		AuraCache[guid][spellID][1] = duration
		AuraCache[guid][spellID][2] = endTime
		AuraCache[guid][spellID][3] = spellID
		AuraCache[guid][spellID][4] = amount
		
		if index > MAX_ICONS_PER_NAMEPLATE then
			break
		end
	end
	
	local raidIcon = RaidIconIndex[GetRaidTargetIndex(unit) or ""]
	
	local frame = core:SearchForFrame(guid, raidIcon, name)
	
	if frame then
		core:UpdateAuras(frame)
	end
end

function core.SetUnitInfo(self, myPlate)
	local plateName = RawGetName(self.name:GetText())

	if ( self._postShowAllow or 0 ) < GetTime() and self:GetAlpha() == 1 and core.targetName and (core.targetName == plateName) then
	
		self.guid = UnitGUID("target")
		
		core.UpdateMindHarvestStatus(self, myPlate)
		
		self.unit = "target"
		myPlate.nameTarget:Show()
		myPlate.name:Hide()
		myPlate:SetFrameLevel(2)
		myPlate.aggro:Show()		
		myPlate.healthBar.overlay:Hide()

		if(core.NumTargetChecks > -1) then
			core.NumTargetChecks = core.NumTargetChecks + 1
			if core.NumTargetChecks > 0 then
				core.NumTargetChecks = -1
			end

			core:UpdateAurasByUnitID('target')
			self.allowCheck = nil
		end
		
		core.targetArrow:SetOwner(myPlate)
	elseif self.highlight:IsShown() and UnitExists("mouseover") and (UnitName("mouseover") == plateName) then
		self.guid = UnitGUID("mouseover")
		
		core.UpdateMindHarvestStatus(self, myPlate)
		
		myPlate.nameTarget:Hide()
		myPlate.name:Show()
		if(self.unit ~= "mouseover" or self.allowCheck) then
			myPlate:SetFrameLevel(1)
			self.allowCheck = nil
		end
		self.unit = "mouseover"
		core:UpdateAurasByUnitID('mouseover')
	
		core.SetDrawLine(self, myPlate)
		
		myPlate.healthBar.overlay:Show()
		myPlate.aggro:Hide()		
	else
	
		core.UpdateMindHarvestStatus(self, myPlate)
		
		myPlate.nameTarget:Hide()
		myPlate.name:Show()
		myPlate.healthBar.overlay:Hide()
		myPlate:SetFrameLevel(0)
		myPlate.aggro:Hide()
		self.unit = nil
	end
end

function core:RoundColors(r, g, b)	
	return floor(r*100+.5)/100, floor(g*100+.5)/100, floor(b*100+.5)/100
end

function core:GetReaction(frame)
	local r, g, b = core:RoundColors(frame.healthBar:GetStatusBarColor())
	
	for class, _ in pairs(RAID_CLASS_COLORS) do
		local bb = b
		if class == 'MONK' then
			bb = bb - 0.01
		end
		
		if RAID_CLASS_COLORS[class].r == r and RAID_CLASS_COLORS[class].g == g and RAID_CLASS_COLORS[class].b == bb then
			return class
		end
	end

	if (r + b + b) == 1.59 then
		return 'TAPPED_NPC'
	elseif g + b == 0 then
		return 'HOSTILE_NPC'
	elseif r + b == 0 then
		return 'FRIENDLY_NPC'
	elseif r + g > 1.95 then
		return 'NEUTRAL_NPC'
	elseif r + g == 0 then
		return 'FRIENDLY_PLAYER'
	else
		return 'HOSTILE_PLAYER'
	end
end

function core:GetThreatReaction(frame)
	if frame.threat:IsShown() then
		local r, g, b = frame.threat:GetVertexColor()
		if g + b == 0 then
			return 'FULL_THREAT'
		else
			if self.threatReaction == 'FULL_THREAT' then
				return 'GAINING_THREAT'
			else
				return 'LOSING_THREAT'
			end
		end
	else
		return 'NO_THREAT'
	end
end

local color, scale
local default_trcolor = { r = 1, g = 1, b = 1 }
function core:ColorizeAndScale(myPlate)
	local unitType = core:GetReaction(self)
	local scale = 1
	local trcolor = default_trcolor
	
	self.unitType = unitType
	if RAID_CLASS_COLORS[unitType] then
		color = RAID_CLASS_COLORS[unitType]
	elseif unitType == "TAPPED_NPC" then
		color = options.reactions.tapped
	elseif unitType == "HOSTILE_NPC" or unitType == "NEUTRAL_NPC" then
		local threatReaction = core:GetThreatReaction(self)
		local classRole
		
		if unitType == "NEUTRAL_NPC" then
			color = options.reactions.neutral
		else
			color = options.reactions.enemy
		end
		
		if threatReaction == 'FULL_THREAT' then
			if classRole == 'Tank' then
				trcolor = options.threat.goodColor
			else
				trcolor = options.threat.badColor
			end
		elseif threatReaction == 'GAINING_THREAT' then
			if classRole == 'Tank' then
				trcolor = options.threat.goodTransitionColor
			else
				trcolor = options.threat.badTransitionColor
			end
		elseif threatReaction == 'LOSING_THREAT' then
			if classRole == 'Tank' then
				trcolor = options.threat.badTransitionColor
			else
				trcolor = options.threat.goodTransitionColor
			end
		elseif InCombatLockdown() then
			if classRole == 'Tank' then
				trcolor = options.threat.badColor
			else
				trcolor = options.threat.goodColor
			end
		end
	
		
		self.threatReaction = threatReaction
	elseif unitType == "FRIENDLY_NPC" then
		color = options.reactions.friendlyNPC
	elseif unitType == "FRIENDLY_PLAYER" then
		color = options.reactions.friendlyPlayer
	else
		color = options.reactions.enemy
	end
	
	if COLORING_NAME then
		myPlate.name:SetTextColor(color.r, color.g, color.b, 1)
	else
		myPlate.name:SetTextColor(1, 1, 1, 1)
	end
	
	myPlate.aggro:SetBackdropBorderColor(trcolor.r, trcolor.g, trcolor.b, 1)

	local r1, g1, b1 = self.name:GetTextColor()
	
--	myPlate.name:SetTextColor(r1, g1, b1)
--	myPlate.nameTarget:SetTextColor(r1, g1, b1)

	if b1 and g1 + b1 == 0 then
		g1 = g1 + 0.5
		b1 = b1 + 0.5
	end
	
	myPlate.healthBar.text1:SetTextColor(r1, g1, b1)

	myPlate.healthBar:SetStatusBarColor(color.r, color.g, color.b)
	myPlate.healthBar_plate:SetStatusBarColor(color.r, color.g, color.b)

	if self.raidIcon:IsShown() then
		myPlate.raidIcon:SetTexCoord(self.raidIcon:GetTexCoord())
		myPlate.raidIcon:Show()
		myPlate.raidIcon_main:SetTexCoord(self.raidIcon:GetTexCoord())
		myPlate.raidIcon_main:Show()
	else
		myPlate.raidIcon:Hide()
		myPlate.raidIcon_main:Hide()
	end
end

core.namePointer = CreateFrame('Frame')
core.namePointer.elapsed = 0
core.namePointer:SetScript('OnUpdate', function(self, elapsed)
	local numChildren = WorldFrame:GetNumChildren()
	 if numChildren ~= lastNumNames then lastNumNames = numChildren
	 IterateChildren_Named(WorldFrame:GetChildren())
	end
	
	for blizzPlate, plate in pairs(named) do
		if(blizzPlate:IsShown()) then
			core.SetAlpha(blizzPlate, plate)
			OnSizeChanged(plate.sizer, plate.sizer:GetSize())
			--[==[
			if blizzPlate.guid and CLEAR_GUID[blizzPlate.guid] then
				blizzPlate.guid = nil
			end
			]==]
		else
			plate:Hide()
		end
	end
	
--	wipe(CLEAR_GUID)
	
	if(self.elapsed and self.elapsed > 0.2) then
		--[[
		if COUNTE_GUIDS then
			wipe(GUID_COUNTER)
		end
		]]
		for blizzPlate, plate in pairs(named) do
			if(blizzPlate:IsShown() and plate:IsShown() ) then			
				core.SetUnitInfo(blizzPlate, plate)
				core.ColorizeAndScale(blizzPlate, plate)
				core.UpdateLevelAndName(blizzPlate, plate)
	
				--[==[
				if COUNTE_GUIDS and blizzPlate.guid then
					if not GUID_COUNTER[blizzPlate.guid] then GUID_COUNTER[blizzPlate.guid] = 0 end
					GUID_COUNTER[blizzPlate.guid] = GUID_COUNTER[blizzPlate.guid] + 1
					
					if GUID_COUNTER[blizzPlate.guid] > 1 then
						print('Error while scanning', plate.realname, blizzPlate.unit, GUID_COUNTER[blizzPlate.guid])	
						
						CLEAR_GUID[blizzPlate.guid] = GUID_COUNTER[blizzPlate.guid]
					end
				end
				]==]
				
				if testing then
					plate._testing:SetText(format('%s %s %s %d\n%5s', blizzPlate.unitType, ( blizzPlate.unit or 'unknown' ), ( plate.realname or 'unknown'), ( GUID_COUNTER[blizzPlate.guid] or 0 ), ( blizzPlate.guid and 'Guid Done' or 'nil' ) ))
				end
			end
		end
		
		if not UnitExists('mouseover') then
			core.HideDrawLine()
		end
		
		self.elapsed = 0
	else
		self.elapsed = (self.elapsed or 0) + elapsed
	end	
end)

local function ResetTargetInfo()
--	print('T ResetTargetInfo')
	
	core.targetName = UnitName("target")
	core.elapsed = 0.3
	core.NumTargetChecks = 0
end

local COMBATLOG_OBJECT_TYPE_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER
local band = bit.band

function core.MindHarvestAssist(destGUID,destName,isPlayer)	
	if destGUID and not core.MindHarvest[destGUID] then

		local name
		if destName and isPlayer then 
			local rawName = strsplit("-", destName)
			name = rawName
			SearchByName[name] = destGUID
--			print('T', 'MindHarvestAssist', name, 'add to SearchByName')
		end

			
		core.MindHarvest[destGUID] = true
	end
end

core.namePointer:SetScript("OnEvent", function(self, event, ...)	
	if event == "PLAYER_TARGET_CHANGED" or ( event == "UNIT_NAME_UPDATE" and select(1, ...) == 'target' ) then
		core.targetArrow:Hide()		
		core.targetName = nil
		
		if(UnitExists("target")) then
			C_Timer.After(0.1, ResetTargetInfo)
		end
	elseif event == "UPDATE_MOUSEOVER_UNIT"  then
		self.elapsed = 0.2
	elseif event == "UNIT_AURA" then
		local unit = ...
		
		if unit == 'target' or unit == 'focus' or ( unit == 'boss1' and ( not UnitIsUnit('target', 'boss1')))  then	
			core:UpdateAurasByUnitID(unit)
		end
	elseif event == 'ARENA_OPPONENT_UPDATE' then
		
		for i=1, 5 do
			local name = UnitName('arena'..i)
			local guid = UnitGUID('arena'..i)
			
			if name and guid then			
				SearchByName[name] = guid			
		--		print('T', 'ARENA_OPPONENT_UPDATE', name, 'add to SearchByName')
			end
		end
	
	elseif event == 'INSTANCE_ENCOUNTER_ENGAGE_UNIT' then		
	--	local name = nil	
		for i=1, 5 do
			local unit = format("boss%d", i)
			if UnitExists(unit) and UnitCanAttack("player", unit) then
				local lastName = UnitName(unit)
				local classif = UnitClassification(unit)
				--[[
					elite
					minus
					normal
					rare
					rareelite
					worldboss
				]]
				
				if 'worldboss' == classif then
				--	if name ~= lastName then
						SearchByName[lastName] = UnitGUID(unit)
				--		print('T', 'INSTANCE_ENCOUNTER_ENGAGE_UNIT', name, 'add to SearchByName')
				--	elseif name == lastName then
				--		SearchByName[lastName] = nil
				--		print('T', 'INSTANCE_ENCOUNTER_ENGAGE_UNIT', name, 'remove from SearchByName')
				--	end				
				--	name = lastName
				end
			end
		end
	elseif event == 'GROUP_ROSTER_UPDATE' then		
		for name in pairs(raidRoster) do
			SearchByName[name] = nil
		end
		wipe(raidRoster)
		if IsInRaid() then
			for i=1, 40 do
				if UnitExists('raid'..i) then					
					local name = UnitName('raid'..i)
					local guid = UnitGUID('raid'..i)					
					raidRoster[name] = guid
					SearchByName[name] = guid
					
			--		print('T', 'GROUP_ROSTER_UPDATE', name, 'add to SearchByName')
				end
			end
		elseif IsInGroup() then
			for i=1, 5 do
				if UnitExists('party'..i) then					
					local name = UnitName('party'..i)
					local guid = UnitGUID('party'..i)					
					raidRoster[name] = guid
					SearchByName[name] = guid
					
			--		print('T', 'GROUP_ROSTER_UPDATE', name, 'add to SearchByName')
				end
			end
		end
	elseif event == 'ADDON_LOADED' then
		local addonName = ...	
		if addonName == addon then		
			Alea_TESTDB = Alea_TESTDB or {}
			
			Alea_TESTDB.TestNamePlates = Alea_TESTDB.TestNamePlates or {}

			Alea_TESTDB.TestNamePlates.pos = Alea_TESTDB.TestNamePlates.pos or { 0, 0 }
			
			config = Alea_TESTDB.TestNamePlates
			
			Mover:SetPoint("CENTER", WorldFrame, "CENTER", config.pos[1], config.pos[2])
		end	
	elseif event == 'COMBAT_LOG_EVENT_UNFILTERED' then
		local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, _, auraType, stackCount  = ...
		
		if subevent == "SPELL_DAMAGE" and sourceGUID == UnitGUID("player") and spellID == 8092 then
			local isPlayer = ( band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == COMBATLOG_OBJECT_TYPE_PLAYER ) or false
			
			core.MindHarvestAssist(destGUID,destName,isPlayer)
		end
	
	
		if  subevent == "SPELL_AURA_APPLIED" or 
		subevent == "SPELL_AURA_REFRESH" or 
		subevent == "SPELL_AURA_APPLIED_DOSE" or 
		subevent == "SPELL_AURA_REMOVED_DOSE" or 
		subevent == "SPELL_AURA_BROKEN" or 
		subevent == "SPELL_AURA_BROKEN_SPELL" or 
		subevent == "SPELL_AURA_REMOVED" 
		then
			if sourceGUID ~= UnitGUID('player') then return end
			local isPlayer = ( band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) == COMBATLOG_OBJECT_TYPE_PLAYER ) or false
			
	--		print('T', destGUID, destName, isPlayer)
			if subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" then
				if durationCache[spellID] then
					AuraCache[destGUID] = AuraCache[destGUID] or {}
					AuraCache[destGUID][spellID] = AuraCache[destGUID][spellID] or {}	
					AuraCache[destGUID][spellID][1] = durationCache[spellID]
					AuraCache[destGUID][spellID][2] = GetTime()+durationCache[spellID]
					AuraCache[destGUID][spellID][3] = spellID
					AuraCache[destGUID][spellID][4] = stackCount				
				end
			elseif subevent == "SPELL_AURA_APPLIED_DOSE" or subevent == "SPELL_AURA_REMOVED_DOSE" then
			
			elseif subevent == "SPELL_AURA_REMOVED" then
				if AuraCache[destGUID] then
					AuraCache[destGUID][spellID] = nil
				end
			elseif subevent == "SPELL_AURA_BROKEN" or subevent == "SPELL_AURA_BROKEN_SPELL" then
				if AuraCache[destGUID] then
					AuraCache[destGUID][spellID] = nil
				end
			elseif subevent == "UNIT_DIED" or subevent == "SPELL_INSTAKILL" then		
				AuraCache[destGUID] = nil
			end	
	
			local name, raidIcon
			if destName and isPlayer then 
				local rawName = strsplit("-", destName)
				name = rawName
				
				SearchByName[name] = destGUID
				
		--		print('T', 'CLEU', name, 'add to SearchByName')
			elseif destName and SearchByName[destName] then		
				name = destName
			end
			
			if flagtort[destRaidFlags] then
				raidIcon = flagtort[destRaidFlags]
			end

			local frame = core:SearchForFrame(destGUID, raidIcon, name)
			if(frame) then
				core:UpdateAuras(frame)
			end
		end
	end
end)
core.namePointer:RegisterEvent('PLAYER_TARGET_CHANGED')
core.namePointer:RegisterEvent('UNIT_NAME_UPDATE')
core.namePointer:RegisterEvent('UPDATE_MOUSEOVER_UNIT')
core.namePointer:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
core.namePointer:RegisterEvent('UNIT_AURA')
core.namePointer:RegisterEvent('ARENA_OPPONENT_UPDATE')
--core.namePointer:RegisterEvent('INSTANCE_ENCOUNTER_ENGAGE_UNIT')
core.namePointer:RegisterEvent('GROUP_ROSTER_UPDATE')
core.namePointer:RegisterEvent('ADDON_LOADED')

PlateSizer:SetScript('OnEvent', function(self, event)
 if event == 'PLAYER_REGEN_ENABLED' then
	for i = 1, #TempFrames do
		TempFrames[i]:SetParent(nil)
	end
	
	core:UpdateNamePlateCvars()
	
	self:Show()
	SecureStateDriverManager:UnregisterEvent('UPDATE_MOUSEOVER_UNIT')
--	SecureStateDriverManager:UnregisterEvent('PLAYER_TARGET_UPDATE')
 elseif event == "PLAYER_LOGIN" and not InCombatLockdown() then
 
	core:UpdateNamePlateCvars()
	
	local numChildren = WorldFrame:GetNumChildren()
	if numChildren ~= PrevWorldChildren then PrevWorldChildren = numChildren
		IterateChildren(WorldFrame:GetChildren())
	end
 else
	self:Hide()
	SecureStateDriverManager:RegisterEvent('UPDATE_MOUSEOVER_UNIT')
--	SecureStateDriverManager:RegisterEvent('PLAYER_TARGET_UPDATE')
 end
end)

PlateSizer:RegisterEvent('PLAYER_REGEN_ENABLED')
PlateSizer:RegisterEvent('PLAYER_REGEN_DISABLED')
PlateSizer:RegisterEvent('PLAYER_LOGIN')

core.RaidIconCoordinate = {
	[0]		= { [0]		= "STAR", [0.25]	= "MOON", },
	[0.25]	= { [0]		= "CIRCLE", [0.25]	= "SQUARE",	},
	[0.5]	= { [0]		= "DIAMOND", [0.25]	= "CROSS", },
	[0.75]	= { [0]		= "TRIANGLE", [0.25]	= "SKULL", }, 
}

function core:CheckRaidIcon(frame)
	if frame.raidIcon:IsShown() then
		local ux, uy = frame.raidIcon:GetTexCoord()
		frame.raidIconType = core.RaidIconCoordinate[ux][uy]	
	else
		frame.raidIconType = nil;
	end
end

function core:SearchNameplateByGUID(guid)
	for frame, _ in pairs(named) do
		if frame and frame:IsShown() and frame.guid == guid then
			return frame
		end
	end
end

function core:SearchNameplateByName(sourceName)
	if not sourceName then return; end
	
	for frame, myPlate in pairs(named) do
		if frame and frame:IsShown() then
			if ( myPlate.nameText == sourceName and RAID_CLASS_COLORS[frame.unitType] ) then
				return frame
			elseif myPlate.nameText == sourceName and SearchByName[sourceName] then
			
		--		print('Search plate by name', sourceName)
				return frame
			end
		end
	end
end

function core:SearchNameplateByIconName(raidIcon)
	for frame, _ in pairs(named) do
		core:CheckRaidIcon(frame)
		if frame and frame:IsShown() and frame.raidIcon:IsShown() and (frame.raidIconType == raidIcon) then
			return frame
		end
	end		
end

function core:SearchForFrame(guid, raidIcon, name, source)
	local frame

	if guid then frame = self:SearchNameplateByGUID(guid) end
	if (not frame) and name then frame = self:SearchNameplateByName(name) end
	if (not frame) and raidIcon then frame = self:SearchNameplateByIconName(raidIcon) end

	return frame
end

local glyphChecker = CreateFrame("Frame")
glyphChecker:RegisterEvent("PLAYER_LOGIN")
glyphChecker:SetScript("OnEvent", function(self, event, ...)	
	self[event](self, event, ...)
end)

function glyphChecker:PLAYER_LOGIN()

	self:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
	self:RegisterEvent("PLAYER_TALENT_UPDATE")
	self:RegisterEvent("PLAYER_LEVEL_UP")
	self:RegisterEvent("GLYPH_UPDATE")
	
	self:GLYPH_UPDATE()
end

local function IsGlyphKnown(spellID)
	for i=1, 6 do
		local enabled, glyphType, glyphTooltipIndex, glyphSpellID = GetGlyphSocketInfo(i)	   
		if glyphSpellID == spellID then 
			return true
		end		
	end
	
	return false
end

function glyphChecker:GLYPH_UPDATE()

	local picked = IsGlyphKnown(162532)
	
	if picked then
		if mind_harvest_enable_state ~= picked then
			mind_harvest_enable_state = picked
			print("Enable Mind Harvest")
		end
	else
		if mind_harvest_enable_state ~= picked then
			mind_harvest_enable_state = picked
			print("Disable Mind Harvest")
		end
	end
	for blizzPlate, plate in pairs(named) do
		core.UpdateMindHarvestStatus(blizzPlate, plate)
	end
end

function core.UpdateMindHarvestStatus(frame, plate)
	
	if not mind_harvest_enable_state then
		plate.mh_nameplate_fake:Hide()
	--	plate.mh_nameplate_fake:SetScale(0.0001)
		plate.mh_nameplate:Hide()
		plate.mh_nameplate:SetScale(0.0001)
		return
	end

	if frame.guid and core.MindHarvest[frame.guid] then
		plate.mh_nameplate_fake:Hide()
	--	plate.mh_nameplate_fake:SetScale(0.0001)
		plate.mh_nameplate:Hide()
		plate.mh_nameplate:SetScale(0.0001)
	else	
		plate.mh_nameplate_fake:Show()
	--	plate.mh_nameplate_fake:SetScale(1)
		plate.mh_nameplate:Show()
		plate.mh_nameplate:SetScale(1)
		 if frame.guid then
			plate.mh_nameplate_fake.status:SetText("|cff66ff00+|r")
			plate.mh_nameplate.status:SetText("|cff66ff00+|r")
		else
			plate.mh_nameplate_fake.status:SetText("|cffff0000?|r")
			plate.mh_nameplate.status:SetText("|cffff0000?|r")
		end
	end
	
end

glyphChecker.PLAYER_LEVEL_UP 				= glyphChecker.GLYPH_UPDATE
glyphChecker.PLAYER_TALENT_UPDATE 			= glyphChecker.GLYPH_UPDATE
glyphChecker.PLAYER_SPECIALIZATION_CHANGED 	= glyphChecker.GLYPH_UPDATE
