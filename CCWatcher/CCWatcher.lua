--[[------------------------------------------------------------
--                                                            --
--                                                            --
--  CC Watcher Addon - TBC Ready                              --
--  ============================                              --
--                                                            --
--    Author: NaliLord                                        --
--    Version: 1.0.1 - 2021-05-31                             --
--                                                            --
--                                                            --
--  Changelog                                                 --
--  ~~~~~~~~~                                                 --
--                                                            --
--    [1.0.1] - Updated for TBC Classic and made public       --
--    [1.0.0] - Initial Working Version for Classic           --
--                                                            --
--                                                            --
--  Credits                                                   --
--  ~~~~~~~                                                   --
--                                                            --
--    Original Source by Bigmack_1861                         --
--    https://www.curseforge.com/wow/addons/cctracker         --
--                                                            --
--                                                            --
------------------------------------------------------------]]--

CCWatcher = CreateFrame("Frame");

local CUR_VER = 1;

local RaidIconMaskToIndex = {
	[COMBATLOG_OBJECT_RAIDTARGET1] = 1,
	[COMBATLOG_OBJECT_RAIDTARGET2] = 2,
	[COMBATLOG_OBJECT_RAIDTARGET3] = 3,
	[COMBATLOG_OBJECT_RAIDTARGET4] = 4,
	[COMBATLOG_OBJECT_RAIDTARGET5] = 5,
	[COMBATLOG_OBJECT_RAIDTARGET6] = 6,
	[COMBATLOG_OBJECT_RAIDTARGET7] = 7,
	[COMBATLOG_OBJECT_RAIDTARGET8] = 8
};

local currentCC = {};
local currentTick = "";
local tickDamage = {};
local tickCCBreak = {};

SLASH_CCWATCHER1 = "/ccw"

CCWatcher:RegisterEvent("ADDON_LOADED", "CheckVersion");
CCWatcher:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "CombatLogEvnt");

CCWatcher:SetScript("OnEvent", function(self, event, ...)
	if (event == "COMBAT_LOG_EVENT_UNFILTERED") then
		CCWatcher:CombatLogEvnt(event,...);
	elseif (event == "ADDON_LOADED") then
		CCWatcher:CheckVersion();
	end
end)

function CCWatcher:PrintMessage(message)
	--print(message);
end

function CCWatcher:ccApply(spellID, spellName, sourceGUID, sourceName, destGUID)
	CCWatcher:PrintMessage("cc applied | Dst:" .. destGUID .. " | Spell:" .. spellID .. " (" .. spellName .. ") | Src:" .. sourceGUID .. " (" .. sourceName .. ")");
	
	if (currentCC[destGUID] == nil)	then
		currentCC[destGUID] = {}
	end
	
	currentCC[destGUID][spellName] = {};
	currentCC[destGUID][spellName]["srcGUID"] = sourceGUID;
	currentCC[destGUID][spellName]["srcName"] = sourceName;
end

function CCWatcher:ccDamage(sourceName, spellID, spellName, destGUID, destName, destFlags, destFlags2)
	CCWatcher:PrintMessage("cc damaged | " .. destGUID .. " | " .. spellName);
	
	if (tickCCBreak[destGUID] ~= nil) then
		for k,v in pairs(tickCCBreak[destGUID]) do
			CCWatcher:ccBreak(sourceName, k, k, destGUID, destName, destFlags, destFlags2, spellID, spellName);
		end
		CCWatcher:ccClear(destGUID, spellName); 
	else
		tickDamage[destGUID] = {}
		tickDamage[destGUID]["srcName"] = sourceName;
		tickDamage[destGUID]["spellId"] = spellID;
		tickDamage[destGUID]["spellName"] = spellName;
	end
end

function CCWatcher:ccBreak(sourceName, spellID, spellName, destGUID, destName, destFlags, destFlags2, otherSpellID, otherSpellName)
	local spellLink, craftingLink, otherSpellLink, otherCraftingLink, raidIconIndex

	CCWatcher:PrintMessage("cc broken | " .. destGUID .. " | " .. spellName .. " | " .. otherSpellName);

	if (destGUID ~= nil) then
		if (currentCC[destGUID] ~= nil)	then
			currentCC[destGUID][spellName] = nil;
		end
		raidIconIndex = RaidIconMaskToIndex[bit.band(destFlags2, COMBATLOG_OBJECT_RAIDTARGET_MASK)];
	else
		raidIconIndex = nil;
	end
	
	if (spellID == -1) then
		if (raidIconIndex ~= nil) then
			CCWatcher:Output(spellName .. " was broken on [{rt" .. raidIconIndex .. "}" .. destName .. "] by environmental damage");
		else
			CCWatcher:Output(spellName .. " was broken on [" .. destName .. "] by environmental damage");
		end
	elseif (spellID ~= nil and spellID ~= 0)	then
		spellLink, craftingLink = GetSpellLink(spellID);
		otherSpellLink, otherCraftingLink = GetSpellLink(otherSpellID);
	else -- for /ccw test <cc breaker> <cc'd target> <cc spell> <breaking spell>
		spellLink = spellName;
		otherSpellLink = otherSpellName;
	end
	
	if (CCWatcher:SourceEnabled(sourceName) and CCWatcher:TargetEnabled(destName)) then
		if (raidIconIndex ~= nil) then
			CCWatcher:Output(sourceName .. " broke " .. spellLink .. " on [{rt" .. raidIconIndex .. "}" .. destName.. "] with " .. otherSpellLink .. "");
		else
			CCWatcher:Output(sourceName .. " broke " .. spellLink .. " on [" .. destName .. "] with "..otherSpellLink .. "");
		end
	end
end

function CCWatcher:ccRemoved(spellID, spellName, destGUID, destName, destFlags, destFlags2)
	if (tickDamage ~= nil and tickDamage[destGUID] ~= nil) then
		CCWatcher:PrintMessage("cc broke | " .. destGUID .. " | " .. spellName);

		CCWatcher:ccBreak(tickDamage[destGUID]["srcName"], spellID, spellName, destGUID, destName, destFlags, destFlags2, tickDamage[destGUID]["spellId"], tickDamage[destGUID]["spellName"]);
		CCWatcher:ccClear(destGUID, spellName);
	else
		CCWatcher:PrintMessage("cc removed | " .. destGUID .. " | " .. spellName);

		CCWatcher:ccExpired(spellID, spellName, destGUID, destName, destFlags2);
		CCWatcher:ccClear(destGUID, spellName);
	end
end

function CCWatcher:ccExpired(spellID, spellName, destGUID, destName, destFlags2)
	CCWatcher:PrintMessage("cc expired | " .. destGUID .. " | " .. spellName);

	if (currentCC[destGUID] ~= nil) then
		if (destGUID ~= nil) then
			raidIconIndex = RaidIconMaskToIndex[bit.band(destFlags2, COMBATLOG_OBJECT_RAIDTARGET_MASK)];
		else
			raidIconIndex = nil;
		end

		spellLink, craftingLink = GetSpellLink(spellID);

		if (CCWatcher:TargetEnabled(destName)) then
			if (raidIconIndex ~= nil) then
				CCWatcher:Output("Warning! " .. spellLink .. " expired on [{rt" .. raidIconIndex .. "}" .. destName.. "]");
			else
				CCWatcher:Output("Warning! " .. spellLink .. " expired on [" .. destName .. "]");
			end
		end
	end
end

function CCWatcher:ccClear(destGUID, spellName)
	CCWatcher:PrintMessage("cc clear | " .. destGUID .. " | " .. spellName);

	tickDamage[destGUID] = nil;
	currentCC[destGUID] = nil;
	
	if (tickCCBreak[destGUID] == nil) then
		tickCCBreak[destGUID] = {};
	end
	
	tickCCBreak[destGUID][spellName] = {};
	tickCCBreak[destGUID][spellName]["destName"] = "";
end

function CCWatcher:CombatLogEvnt()
	local timestamp, type, hideCaster, sourceGUID, sourceName, sourceFlags, sourceFlags2, destGUID, destName, destFlags, destFlags2, spellID, spellName, something, otherSpellID, otherSpellName = CombatLogGetCurrentEventInfo(); 
  
	if (currentTick ~= timestamp) then
		if (tickCCBreak[destGUID] ~= nil) then --must have expired naturally
			for k,v in pairs(tickCCBreak[destGUID]) do
				if (currentCC[destGUID] ~= nil)	then
					currentCC[destGUID][k] = nil;
				end
				
				if (currentCC[destGUID] == {}) then
					currentCC[destGUID] = nil;
				end
			end
		end
		
		tickCCBreak = {}
		tickDamage = {};
		currentTick = timestamp;
	end
	
	local targetIsFriend = destName ~= nil and UnitIsFriend("player", destName) == true
	local targetIsEnemy = destName ~= nil and UnitIsFriend("player", destName) == false

	if (type == "SWING_DAMAGE" and currentCC[destGUID] ~= nil) then
		if (CCWatcher:SourceEnabled(sourceName) and CCWatcher:TargetEnabled(destName)) then
			CCWatcher:ccDamage(sourceName, 6603, destGUID, destName, destFlags, destFlags2); --AutoAttack
		end
	elseif ((type == "SPELL_DAMAGE" or type == "RANGE_DAMAGE" or type == "SPELL_PERIODIC_DAMAGE" or type == "SPELL_BUILDING_DAMAGE") and currentCC[destGUID] ~= nil) then 
		if (CCWatcher:SourceEnabled(sourceName) and CCWatcher:TargetEnabled(destName)) then
			CCWatcher:ccDamage(sourceName, spellID, destGUID, destName, destFlags, destFlags2);
		end
	elseif (type == "ENVIRONMENTAL_DAMAGE" and currentCC[destGUID] ~= nil) then
		if (CCWatcher:TargetEnabled(destName)) then
			CCWatcher:ccDamage(sourceName, -1, destGUID, destName, destFlags, destFlags2);
		end
	elseif ((type == "SPELL_AURA_APPLIED" or type == "SPELL_AURA_REFRESH") and targetIsEnemy) then
		if (CCWatcher:SpellEnabled(spellName) and CCWatcher:TargetEnabled(destName)) then
			CCWatcher:ccApply(spellID, spellName, sourceGUID, sourceName, destGUID);
		end
	elseif (type == "SPELL_AURA_REMOVED" and targetIsEnemy) then
		if (CCWatcher:SpellEnabled(spellName) and CCWatcher:TargetEnabled(destName)) then
			CCWatcher:ccRemoved(spellID, spellName, destGUID, destName, destFlags, destFlags2);
		end
	elseif (type == "SPELL_AURA_BROKEN_SPELL" and targetIsEnemy) then
		if (CCWatcher:SpellEnabled(spellName) and CCWatcher:SourceEnabled(sourceName) and CCWatcher:TargetEnabled(destName)) then
			CCWatcher:ccBreak(sourceName, spellID, spellName, destGUID, destName, destFlags, destFlags2, otherSpellID, otherSpellName);
			CCWatcher:ccClear(destGUID, spellName);
		end
	end
	
	for gui, guiData in pairs(currentCC) do
		keepTarget = false;
		for cc, ccData in pairs(currentCC[gui]) do
			if (ccData ~= nil) then
				keepTarget = true;
			end
		end
		if (keepTarget == false) then
			currentCC[gui] = nil;
		end
	end
end

function CCWatcher:Output(msg)
	if (CCWatcherSettings["channel"] == "SELF") then
		local subbedMsg = string.gsub(msg,"{rt(%d)}","\124TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%1:12\124t");
	
		DEFAULT_CHAT_FRAME:AddMessage(subbedMsg);
	else
		SendChatMessage(msg, CCWatcherSettings["channel"], nil, nil);
	end
end

function CCWatcher:ResetTargets()
	CCWatcherSettings["ccTargets"] = {};
end

function CCWatcher:TargetEnabled(targetName)
	for k,v in pairs(CCWatcherSettings["ccTargets"]) do
		if (targetName == k and v == 1) then
			CCWatcher:PrintMessage("Target Enabled:" .. targetName);

			return true;
		elseif (targetName == k and v == 0) then
			CCWatcher:PrintMessage("Target Disabled:" .. targetName);

			return false;
		end
	end
	
	--CCWatcher:PrintMessage("Target Allowed:" .. targetName);
	
	return true;
end

function CCWatcher:EnableTarget(targetName)
	if (CCWatcherSettings["ccTargets"][targetName] == 0) then
		CCWatcherSettings["ccTargets"][targetName] = nil;
	end
end

function CCWatcher:DisableTarget(targetName)
	CCWatcherSettings["ccTargets"][targetName] = 0;
end

function CCWatcher:ListTargets()
	local targets = "";

	print("Targets that are disabled:");

	for k,v in pairs(CCWatcherSettings["ccTargets"]) do
		if v == 0 then
			if targets ~= "" then
				targets = targets .. ", ";
			end
			targets = targets .. k;
		end
	end

	print(targets);
	print("Any targets not listed here is enabled by default.");
end

function CCWatcher:ResetSources()
	CCWatcherSettings["ccSources"] = {};
end

function CCWatcher:SourceEnabled(sourceName)
	for k,v in pairs(CCWatcherSettings["ccSources"]) do
		if (sourceName == k and v == 1) then
			CCWatcher:PrintMessage("Source Enabled:" .. sourceName);
			return true;
		elseif (sourceName == k and v == 0) then
			CCWatcher:PrintMessage("Source Disabled:" .. sourceName);
			return false;
		end
	end
	
	--CCWatcher:PrintMessage("Source Allowed:" .. sourceName);
	
	return true;
end

function CCWatcher:EnableSource(sourceName)
	if (CCWatcherSettings["ccSources"][sourceName] == 0) then
		CCWatcherSettings["ccSources"][sourceName] = nil;
	end
end

function CCWatcher:DisableSource(sourceName)
	CCWatcherSettings["ccSources"][sourceName] = 0;
end

function CCWatcher:ListSources()
	local sources = "";

	print("Sources that are disabled:");

	for k,v in pairs(CCWatcherSettings["ccSources"]) do
		if v == 0 then
			if sources ~= "" then
				sources = sources .. ", ";
			end
			sources = sources .. k;
		end
	end

	print(sources);
	print("Any sources not listed here is enabled by default.");
end

function CCWatcher:ResetSpells()
	CCWatcherSettings["ccSpells"] = {}
	
	--rogue
	CCWatcherSettings["ccSpells"]["Sap"] = 1;
	CCWatcherSettings["ccSpells"]["Blind"] = 1;
	CCWatcherSettings["ccSpells"]["Gouge"] = 1;

	--shaman
	CCWatcherSettings["ccSpells"]["Hex"] = 1;
	CCWatcherSettings["ccSpells"]["Bind Elemental"] = 1;

	--pally
	CCWatcherSettings["ccSpells"]["Repentance"] = 1;
	CCWatcherSettings["ccSpells"]["Turn Evil"] = 1;
	CCWatcherSettings["ccSpells"]["Blinding Light"] = 1;

	--hunter
	CCWatcherSettings["ccSpells"]["Scatter Shot"] = 1;
	CCWatcherSettings["ccSpells"]["Freezing Trap"] = 1;
	CCWatcherSettings["ccSpells"]["Wyvern Sting"] = 1;

	--warrior
	CCWatcherSettings["ccSpells"]["Intimidating Shout"] = 1;

	--mage
	CCWatcherSettings["ccSpells"]["Polymorph"] = 1;
	CCWatcherSettings["ccSpells"]["Ring of Frost"] = 1;

	--priest
	CCWatcherSettings["ccSpells"]["Psychic Scream"] = 1;
	CCWatcherSettings["ccSpells"]["Psychic Terror"] = 1;
	CCWatcherSettings["ccSpells"]["Holy Word: Chastise"] = 1;
	CCWatcherSettings["ccSpells"]["Shackle Undead"] = 1;

	--warlock
	CCWatcherSettings["ccSpells"]["Fear"] = 1;
	CCWatcherSettings["ccSpells"]["Seduction"] = 1;
	CCWatcherSettings["ccSpells"]["Howl of Terror"] = 1;

	--druid
	CCWatcherSettings["ccSpells"]["Hibernate"] = 1;
	CCWatcherSettings["ccSpells"]["Entangling Roots"] = 0;
	CCWatcherSettings["ccSpells"]["Mass Entanglement"] = 0;
	CCWatcherSettings["ccSpells"]["Incapacitating Roar"] = 1;
end

function CCWatcher:RemoveSpell(spellName)
	for k,v in pairs(CCWatcherSettings["ccSpells"]) do
		if(v==spellName) then
			table.remove(CCWatcherSettings["ccSpells"], k);
			return true;
		end
	end

	return false;
end

function CCWatcher:AddSpell(spellName)
	CCWatcherSettings["ccSpells"][spellName] = 1;
end

function CCWatcher:DisableSpell(spellName)
	if (CCWatcherSettings["ccSpells"][spellName] == 1) then
		CCWatcherSettings["ccSpells"][spellName] = 0;
	end
end

function CCWatcher:SpellEnabled(spellName)
	for k,v in pairs(CCWatcherSettings["ccSpells"]) do
		if (spellName == k and v == 1) then
			--CCWatcher:PrintMessage("Spell Enabled:" .. spellName);
			return true;
		end
	end

	CCWatcher:PrintMessage("Spell Disabled:" .. spellName);

	return false;
end

function CCWatcher:ListSpells()
	local spells = "";

	print("Spells in all uppercase are disabled:");

	for k,v in pairs(CCWatcherSettings["ccSpells"]) do
		local spellName = k;
		if (v == 0) then
			spellName = spellName:upper();
		end
		if spells ~= "" then
			spells = spells .. ", ";
		end
		spells = spells .. spellName;
	end

	print(spells);
	print("Any spell not listed here is disabled by default.");
end

function CCWatcher:CheckVersion()
	if CCWatcherSettings ~= nil and CCWatcherSettings["ver"] > CUR_VER then
		CCWatcherSettings = nil;
	end

	if CCWatcherSettings == nil then
		CCWatcherSettings = {}
		CCWatcher:ResetSpells();
		CCWatcher:ResetTargets();
		CCWatcher:ResetSources();
		CCWatcherSettings["ver"] = CUR_VER;
		CCWatcherSettings["channel"] = "SELF";
	end

	if CCWatcherSettings["ver"] < 1 then
		CCWatcher:ResetSpells();
		CCWatcher:ResetTargets();
		CCWatcher:ResetSources();
		CCWatcherSettings["ver"] = 1;
	end
end

SlashCmdList["CCWATCHER"] = function(msg)
	local cmd, arg = string.split(" ", msg, 2);
	
	cmd = cmd:lower();

	if cmd == "test" then
		local person, target, ccSpell, breakingSpell = string.split(" ", arg);
		CCWatcher:CombatLog(nil, nil, "SPELL_AURA_BROKEN_SPELL", false, nil, person, nil, nil, nil, target, nil, nil, nil, ccSpell, nil, nil, breakingSpell);
	elseif cmd == "channel" then
		arg = arg:lower();
		if arg == "" or arg == "self" then
			arg = "SELF";
		end
		CCWatcherSettings["channel"] = arg;
		print("Channel Set");
	elseif cmd == "spell" then
		local option, spellName = string.split(" ", arg, 2);
		option = option:lower();
		if option == "add" then
			CCWatcher:AddSpell(spellName);
			print("Spell Added.");
		elseif option == "remove" then
			CCWatcher:DisableSpell(spellName);
			print("Spell removed.");
		else
			print("Unknown option '" .. option .. "'");
		end
	elseif cmd == "source" then
		local option, sourceName = string.split(" ", arg, 2);
		option = option:lower();
		if option == "enable" then
			CCWatcher:EnableSource(sourceName);
			print("Now tracking from this source.");
		elseif option == "disable" then
			CCWatcher:DisableSource(sourceName);
			print("No longer tracking from this source.");
		else
			print("Unknown option '" .. option .. "'");
		end
	elseif cmd == "target" then
		local option, targetName = string.split(" ", arg, 2);
		option = option:lower();
		if option == "enable" then
			CCWatcher:EnableTarget(targetName);
			print("Now tracking from this target.");
		elseif option == "disable" then
			CCWatcher:DisableTarget(targetName);
			print("No longer tracking from this target.");
		else
			print("Unknown option '" .. option .. "'");
		end
	elseif cmd == "reset" then
		arg = arg:lower();
		if arg == "spells" then
			CCWatcher:ResetSpells();
			print("Spell tracking reset to default.");
		elseif arg == "sources" then
			CCWatcher:ResetSources();
			print("Source tracking reset to default.");
		elseif arg == "targets" then
			CCWatcher:ResetTargets();
			print("Target tracking reset to default.");
		else
			print("Unknown option '" .. arg .. "'");
		end
	elseif cmd == "list" then
		arg = arg:lower();
		if arg == "spells" then
			CCWatcher:ListSpells();
		elseif arg == "targets" then
			CCWatcher:ListTargets();
		elseif arg == "sources" then
			CCWatcher:ListSources();
		end
	elseif cmd == "?" then
		print("Usage:")
		print("/ccw channel <SELF|RAID|PARTY|SAY|etc>");
		print("Sets output channel");
		
		print("/ccw spell <add|remove> <spellname>");
		print("Adds or removes spells from tracking");
		
		print("/ccw source <enable|disable> <sourceName>");
		print("Adds or removes tracking of cc breaking by source. IE your tanks name, or an npc.");
		
		print("/ccw target <enable|disable> <targetName>");
		print("Adds or removes tracking of cc breaking on specific targets.");
		
		print("/ccw list <targets|spells|sources>");
		print("Lists current target, spell or source options.");
		
		print("/ccw reset spells");
		print("Resets cc that is tracked to default.");
		
		print("/ccw reset sources");
		print("Resets sources that are tracked to default.");
		
		print("/ccw reset targets");
		print("Resets targets that are tracked to default.");
		
		print("/ccw test <Person> <CCSpell> <Target> <BreakingSpell>");
		print("Tests outputing a message.");
	else
		print("Unknown command '" .. cmd .. "'.");
		print("Type '/ccw ?' for usage information");
	end
end

--http://wow.mmoui.com/forums/showthread.php?p=232488
local function GetIconIndex(flags)
    local number, mask, mark
    if bit.band(flags, COMBATLOG_OBJECT_SPECIAL_MASK) ~= 0 then
        for i=1,8 do
            mask = COMBATLOG_OBJECT_RAIDTARGET1 * (2 ^ (i - 1))
            mark = bit.band(flags, mask) == mask
            if mark then number = i break end
        end
    end
	
    return number
end