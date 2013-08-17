

local _detalhes	= 	_G._detalhes
local Loc = LibStub ("AceLocale-3.0"):GetLocale ( "Details" )

local CreateFrame = CreateFrame
local pairs = pairs 
local UIParent = UIParent
local UnitGUID = UnitGUID 
local tonumber= tonumber 
local LoggingCombat = LoggingCombat

SLASH_DETAILS1, SLASH_DETAILS2, SLASH_DETAILS3 = "/details", "/dt", "/d"

function SlashCmdList.DETAILS (msg, editbox)

	local command, rest = msg:match("^(%S*)%s*(.-)$")
	
	if (command == Loc ["STRING_SLASH_NEW"]) then
	
		_detalhes:CriarInstancia()
		
	elseif (command ==Loc ["STRING_SLASH_SHOW_DESC"]) then
	
		if (_detalhes.opened_windows == 0) then
			_detalhes:CriarInstancia()
		end
	
	elseif (command == Loc ["STRING_SLASH_DISABLE"]) then
	
		_detalhes:CaptureSet (false, "damage", true)
		_detalhes:CaptureSet (false, "heal", true)
		_detalhes:CaptureSet (false, "energy", true)
		_detalhes:CaptureSet (false, "miscdata", true)
		_detalhes:CaptureSet (false, "aura", true)
		print (Loc ["STRING_DETAILS1"] .. Loc ["STRING_SLASH_CAPTUREOFF"])
	
	elseif (command == Loc ["STRING_SLASH_ENABLE"]) then
	
		_detalhes:CaptureSet (true, "damage", true)
		_detalhes:CaptureSet (true, "heal", true)
		_detalhes:CaptureSet (true, "energy", true)
		_detalhes:CaptureSet (true, "miscdata", true)
		_detalhes:CaptureSet (true, "aura", true)
		print (Loc ["STRING_DETAILS1"] .. Loc ["STRING_SLASH_CAPTUREON"])
	
	elseif (command == Loc ["STRING_SLASH_OPTIONS"]) then
	
		if (rest and tonumber (rest)) then
			local instanceN = tonumber (rest)
			if (instanceN > 0 and instanceN <= #_detalhes.tabela_instancias) then
				local instance = _detalhes:GetInstance (instanceN)
				_detalhes:OpenOptionsWindow (instance)
			end
		else
			local lower_instance = _detalhes:GetLowerInstanceNumber()
			print (_detalhes:GetInstance (lower_instance))
			_detalhes:OpenOptionsWindow (_detalhes:GetInstance (lower_instance))
		end
		
	
-------- debug ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	elseif (msg == "copy") then
		_G.DetailsCopy:Show()
		_G.DetailsCopy.MyObject.text:HighlightText()
		_G.DetailsCopy.MyObject.text:SetFocus()
	
	elseif (msg == "comm") then
		
	_detalhes:SendCommMessage ("details_comm", _detalhes:Serialize ("foundcloud", UnitName ("player"), GetRealmName(), _detalhes.realversion), "WHISPER", "Marleyieu-Azralon")
	SendAddonMessage ("details_comm", "text", "WHISPER", "Marleyieu-Azralon")
	SendChatMessage ("Hello Bob!", "WHISPER", "Common", "Marleyieu-Azralon")
		
	elseif (msg == "visao") then
		--_detalhes:VisiblePlayers()
		--local a, b = GetUnitName ("player")
		--print (a,GetRealmName())
		--print (time())
		--print (math.floor (time()/10))
		
		assert (false, "teste")
		
	elseif (msg == "yesno") then
		--_detalhes:Show()
	
	elseif (msg == "imageedit") then
		
		local callback = function (width, height, overlayColor, alpha, texCoords)
			print (width, height, alpha)
			print ("overlay: ", unpack (overlayColor))
			print ("crop: ", unpack (texCoords))
		end
		
		_detalhes.gump:ImageEditor (callback, "Interface\\TALENTFRAME\\bg-paladin-holy", nil, {1, 1, 1, 1}) -- {0.25, 0.25, 0.25, 0.25}

	elseif (msg == "error") then
		a = nil + 1
		
	--> debug
	elseif (command == "resetcapture") then
		_detalhes.capture_real = {
			["damage"] = true,
			["heal"] = true,
			["energy"] = true,
			["miscdata"] = true,
			["aura"] = true,
		}
		_detalhes.capture_current = _detalhes.capture_real
		_detalhes:CaptureRefresh()

	--> debug
	elseif (msg == "opened") then 
		print ("Instances opened: " .. _detalhes.opened_windows)
	
	--> debug, get a guid of something
	elseif (command == "guid") then --> localize-me
	
		local pass_guid = rest:match("^(%S*)%s*(.-)$")
	
		if (not _detalhes.id_frame) then 
		
			local backdrop = {
			bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
			edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
			tile = true, edgeSize = 1, tileSize = 5,
			}
		
			_detalhes.id_frame = CreateFrame ("Frame", "DetailsID", UIParent)
			_detalhes.id_frame:SetHeight(14)
			_detalhes.id_frame:SetWidth(120)
			_detalhes.id_frame:SetPoint ("center", UIParent, "center")
			_detalhes.id_frame:SetBackdrop(backdrop)
			
			tinsert (UISpecialFrames, "DetailsID")
			
			_detalhes.id_frame.texto = CreateFrame ("editbox", nil, _detalhes.id_frame)
			_detalhes.id_frame.texto:SetPoint ("topleft", _detalhes.id_frame, "topleft")
			_detalhes.id_frame.texto:SetAutoFocus(false)
			_detalhes.id_frame.texto:SetFontObject (GameFontHighlightSmall)			
			_detalhes.id_frame.texto:SetHeight(14)
			_detalhes.id_frame.texto:SetWidth(120)
			_detalhes.id_frame.texto:SetJustifyH("CENTER")
			_detalhes.id_frame.texto:EnableMouse(true)
			_detalhes.id_frame.texto:SetBackdrop(ManualBackdrop)
			_detalhes.id_frame.texto:SetBackdropColor(0, 0, 0, 0.5)
			_detalhes.id_frame.texto:SetBackdropBorderColor(0.3, 0.3, 0.30, 0.80)
			_detalhes.id_frame.texto:SetText ("") --localize-me
			_detalhes.id_frame.texto.perdeu_foco = nil
			
			_detalhes.id_frame.texto:SetScript ("OnEnterPressed", function () 
				_detalhes.id_frame.texto:ClearFocus()
				_detalhes.id_frame:Hide() 
			end)
			
			_detalhes.id_frame.texto:SetScript ("OnEscapePressed", function() 
				_detalhes.id_frame.texto:ClearFocus()
				_detalhes.id_frame:Hide() 
			end)
			
		end
		
		_detalhes.id_frame:Show()
		
		if (pass_guid == "-") then
			local guid = UnitGUID ("target")
			if (guid) then 
				print (guid.. " -> " .. tonumber (guid:sub(6, 10), 16))
				_detalhes.id_frame.texto:SetText (""..tonumber (guid:sub(6, 10), 16))
				_detalhes.id_frame.texto:HighlightText()
			end
		
		else
			print (pass_guid.. " -> " .. tonumber (pass_guid:sub(6, 10), 16))
			_detalhes.id_frame.texto:SetText (""..tonumber (pass_guid:sub(6, 10), 16))
			_detalhes.id_frame.texto:HighlightText()
		end
		
	
	--> debug
	elseif (msg == "id") then
		local one, two = rest:match("^(%S*)%s*(.-)$")
		if (one ~= "") then
			print("NPC ID:", one:sub(-12, -9), 16)
			print("NPC ID:", tonumber((one):sub(-12, -9), 16))
		else
			print("NPC ID:", tonumber((UnitGUID("target")):sub(-12, -9), 16) )
		end

	--> debug
	elseif (msg == "debug") then
		if (_detalhes.debug) then
			_detalhes.debug = false
			print ("Details Diagnostic mode OFF")
		else
			_detalhes.debug = true
			print ("Details Diagnostic mode ON")
		end
	
	--> debug combat log
	elseif (msg == "combatlog") then
		if (_detalhes.isLoggingCombat) then
			LoggingCombat (false)
			print ("Wow combatlog record turned OFF.")
			_detalhes.isLoggingCombat = nil
		else
			LoggingCombat (true)
			print ("Wow combatlog record turned ON.")
			_detalhes.isLoggingCombat = true
		end
	
	--> debug
	elseif (msg == "gs") then
		_detalhes:teste_grayscale()
	
	else
		
		--if (_detalhes.opened_windows < 1) then
		--	_detalhes:CriarInstancia()
		--end
		
		print (" ")
		print (Loc ["STRING_DETAILS1"] ..  Loc ["STRING_COMMAND_LIST"])
		print ("|cffffaeae/details " .. Loc ["STRING_SLASH_NEW"] .. "|r: " .. Loc ["STRING_SLASH_NEW_DESC"])
		print ("|cffffaeae/details " .. Loc ["STRING_SLASH_SHOW"] .. "|r: " .. Loc ["STRING_SLASH_SHOW_DESC"])
		print ("|cffffaeae/details " .. Loc ["STRING_SLASH_ENABLE"] .. "|r: " .. Loc ["STRING_SLASH_ENABLE_DESC"])
		print ("|cffffaeae/details " .. Loc ["STRING_SLASH_DISABLE"] .. "|r: " .. Loc ["STRING_SLASH_DISABLE_DESC"])
		print ("|cffffaeae/details " .. Loc ["STRING_SLASH_OPTIONS"] .. "|r|cfffcffb0 <instance number>|r: " .. Loc ["STRING_SLASH_OPTIONS_DESC"])
		print (" ")

	end
end