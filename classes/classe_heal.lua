--[[ Esta classe ir� abrigar todo a cura de uma habilidade
Parents:
	addon -> combate atual -> cura -> container de jogadores -> esta classe

]]

--lua locals
local _cstr = string.format
local _math_floor = math.floor
local _setmetatable = setmetatable
local _pairs = pairs
local _ipairs = ipairs
local _unpack = unpack
local _type = type
local _table_sort = table.sort
local _cstr = string.format
local _table_insert = table.insert
local _bit_band = bit.band
local _math_min = math.min
--api locals
local _GetSpellInfo = _detalhes.getspellinfo


local _detalhes = 		_G._detalhes

local AceLocale = LibStub ("AceLocale-3.0")
local Loc = AceLocale:GetLocale ( "Details" )

local gump = 			_detalhes.gump

local alvo_da_habilidade = 	_detalhes.alvo_da_habilidade
local container_habilidades = 	_detalhes.container_habilidades
local container_combatentes =	_detalhes.container_combatentes
local atributo_heal =		_detalhes.atributo_heal
local habilidade_cura = 		_detalhes.habilidade_cura

local container_playernpc = _detalhes.container_type.CONTAINER_PLAYERNPC
local container_heal = _detalhes.container_type.CONTAINER_HEAL_CLASS
local container_heal_target = _detalhes.container_type.CONTAINER_HEALTARGET_CLASS

local modo_ALONE = _detalhes.modos.alone
local modo_GROUP = _detalhes.modos.group
local modo_ALL = _detalhes.modos.all

local class_type = _detalhes.atributos.cura

local DATA_TYPE_START = _detalhes._detalhes_props.DATA_TYPE_START
local DATA_TYPE_END = _detalhes._detalhes_props.DATA_TYPE_END

local DFLAG_player = _detalhes.flags.player
local DFLAG_group = _detalhes.flags.in_group
local DFLAG_player_group = _detalhes.flags.player_in_group

local div_abre = _detalhes.divisores.abre
local div_fecha = _detalhes.divisores.fecha
local div_lugar = _detalhes.divisores.colocacao

local info = _detalhes.janela_info
local keyName

function atributo_heal:NovaTabela (serial, nome, link)
	local esta_tabela = {}
	esta_tabela.quem_sou = "classe_heal" --> DEBUG deleta-me
	
	_setmetatable (esta_tabela, atributo_heal)

	--> grava o tempo que a tabela foi criada para o garbage collector interno
	esta_tabela.CriadaEm = time()
	
	--> dps do objeto inicia sempre desligado
	esta_tabela.iniciar_hps = false  --> sera necessario isso na cura?
	
	esta_tabela.tipo = class_type --> atributo 2 = cura
	
	esta_tabela.total = 0
	esta_tabela.totalover = 0
	esta_tabela.custom = 0
	
	esta_tabela.total_without_pet = 0 --> pet de DK cura
	esta_tabela.totalover_without_pet = 0 --> pet de DK cura
	
	esta_tabela.last_events_table = _detalhes:CreateActorLastEventTable()
	esta_tabela.last_events_table.original = true
	
	esta_tabela.healing_taken = 0 --> total de cura que este jogador recebeu
	esta_tabela.healing_from = {} --> armazena os nomes que deram cura neste jogador
	
	esta_tabela.last_event = 0 --> mantem igual ao dano
	esta_tabela.on_hold = false --> mantem igual ao dano
	esta_tabela.delay = 0 --> mantem igual ao dano
	
	esta_tabela.last_value = nil --> ultimo valor que este jogador teve, salvo quando a barra dele � atualizada
	
	esta_tabela.end_time = nil
	esta_tabela.start_time = 0
	
	esta_tabela.last_hps = 0 --> cura por segundo
	esta_tabela.last_value = 0
	
	esta_tabela.pets = {} --cura n�o tem pet, okey? tem pet sim, as larvas de DK
	
	esta_tabela.heal_enemy = {} --> quando o jogador cura um inimigo

	--container armazenar� os IDs das habilidades usadas por este jogador
	esta_tabela.spell_tables = container_habilidades:NovoContainer (container_heal) 
	
	--container armazenar� os seriais dos alvos que o player aplicou dano
	esta_tabela.targets = container_combatentes:NovoContainer (container_heal_target) 

	if (link) then
		esta_tabela.targets.shadow = link.targets
		esta_tabela.spell_tables.shadow = link.spell_tables
	end
	
	return esta_tabela
end


function atributo_heal:RefreshWindow (instancia, tabela_do_combate, forcar, exportar)
	
	local showing = tabela_do_combate [class_type] --> o que esta sendo mostrado -> [1] - dano [2] - cura

	--> n�o h� barras para mostrar -- not have something to show
	if (#showing._ActorTable < 1) then --> n�o h� barras para mostrar
		--> colocado isso recentemente para fazer as barras de dano sumirem na troca de atributo
		return _detalhes:EsconderBarrasNaoUsadas (instancia, showing) 
	end

	--> total
	local total = 0 
	--> top actor #1
	instancia.top = 0
	
	local sub_atributo = instancia.sub_atributo --> o que esta sendo mostrado nesta inst�ncia
	local conteudo = showing._ActorTable
	local amount = #conteudo
	local modo = instancia.modo
	
	--> pega qual a sub key que ser� usada
	if (exportar) then
	
		if (_type (exportar) == "boolean") then 
			if (sub_atributo == 1) then --> healing DONE
				keyName = "total"
			elseif (sub_atributo == 2) then --> HPS
				keyName = "last_hps"
			elseif (sub_atributo == 3) then --> overheal
				keyName = "totalover"
			elseif (sub_atributo == 4) then --> healing take
				keyName = "healing_taken"
			end
		else
			keyName = exportar.key
			modo = exportar.modo
		end
	elseif (instancia.atributo == 5) then --> custom
		keyName = "custom"
		total = tabela_do_combate.totals [instancia.customName]
	else	
		if (sub_atributo == 1) then --> healing DONE
			keyName = "total"
		elseif (sub_atributo == 2) then --> HPS
			keyName = "last_hps"
		elseif (sub_atributo == 3) then --> overheal
			keyName = "totalover"
		elseif (sub_atributo == 4) then --> healing take
			keyName = "healing_taken"
		end
	end

	if (instancia.atributo == 5) then --> custom
		--> faz o sort da categoria e retorna o amount corrigido
		amount = _detalhes:ContainerSort (conteudo, amount, keyName)
		
		--> grava o total
		instancia.top = conteudo[1][keyName]
	
	elseif (instancia.modo == modo_ALL) then --> mostrando ALL
	
		amount = _detalhes:ContainerSort (conteudo, amount, keyName)
	
		--> faz o sort da categoria
		--_table_sort (conteudo, function (a, b) return a[keyName] > b[keyName] end)
		
		--> n�o mostrar resultados com zero
		--[[for i = amount, 1, -1 do --> de tr�s pra frente
			if (conteudo[i][keyName] < 1) then
				amount = amount-1
			else
				break
			end
		end--]]
		
		--> pega o total ja aplicado na tabela do combate
		total = tabela_do_combate.totals [class_type]
		
		--> grava o total
		instancia.top = conteudo[1][keyName]
		
	elseif (instancia.modo == modo_GROUP) then --> mostrando GROUP

		--> organiza as tabelas
		
		--print ("AQUI")
		--print ("::"..keyName)
		
		--_detalhes:DelayMsg ("==================")
		--_detalhes:DelayMsg (keyName)
		
		--_table_sort (conteudo, _detalhes.SortKeyGroup)
		_detalhes.SortGroup (conteudo, keyName)
		
		--[[_table_sort (conteudo, function (a, b)
				if (a.grupo and b.grupo) then
					return a[keyName] > b[keyName]
				elseif (a.grupo and not b.grupo) then
					return true
				elseif (not a.grupo and b.grupo) then
					return false
				else
					return a[keyName] > b[keyName]
				end
			end)--]]

		for index, player in _ipairs (conteudo) do
			if (_bit_band (player.flag, DFLAG_player_group) >= 0x101) then --> � um player e esta em grupo
				if (player[keyName] < 1) then --> dano menor que 1, interromper o loop
					amount = index - 1
					break
				elseif (index == 1) then --> esse IF aqui, precisa mesmo ser aqui? n�o daria pra pega-lo com uma chave [1] nad grupo == true?
					instancia.top = conteudo[1][keyName]
				end
				
				total = total + player[keyName]
			else
				amount = index-1
				break
			end
		end		
		
	end
	
	--> refaz o mapa do container
	showing:remapear()

	if (exportar) then 
		return total, keyName, instancia.top
	end
	
	if (amount < 1) then --> n�o h� barras para mostrar
		instancia:EsconderScrollBar()
		return _detalhes:EndRefresh (instancia, total, tabela_do_combate, showing) --> retorna a tabela que precisa ganhar o refresh
	end

	--estra mostrando ALL ent�o posso seguir o padr�o correto? primeiro, atualiza a scroll bar...
	instancia:AtualizarScrollBar (amount)
	
	--depois faz a atualiza��o normal dele atrav�s dos iterators
	local qual_barra = 1
	local barras_container = instancia.barras --> evita buscar N vezes a key .barras dentro da inst�ncia
	
	local combat_time = instancia.showing:GetCombatTime()
	for i = instancia.barraS[1], instancia.barraS[2], 1 do --> vai atualizar s� o range que esta sendo mostrado
		--conteudo[i]:AtualizaBarra (instancia, qual_barra, i, total, sub_atributo, forcar) --> inst�ncia, index, total, valor da 1� barra
		conteudo[i]:AtualizaBarra (instancia, barras_container, qual_barra, i, total, sub_atributo, forcar, keyName, combat_time) --> inst�ncia, index, total, valor da 1� barra
		qual_barra = qual_barra+1
	end

	if (instancia.atributo == 5) then --> custom
		--> zerar o .custom dos Actors
		for index, player in _ipairs (conteudo) do
			if (player.custom > 0) then 
				player.custom = 0
			else
				break
			end
		end
	end
	
	--> beta, hidar barras n�o usadas durante um refresh for�ado
	if (forcar) then
		if (instancia.modo == 2) then --> group
			for i = qual_barra, instancia.barrasInfo.cabem  do
				gump:Fade (instancia.barras [i], "in", 0.3)
			end
		end
	end

	-- showing.need_refresh = false
	return _detalhes:EndRefresh (instancia, total, tabela_do_combate, showing) --> retorna a tabela que precisa ganhar o refresh
	
end

function atributo_heal:Custom (_customName, _combat, sub_atributo, spell, alvo)
	local _Skill = self.spell_tables._ActorTable [tonumber (spell)]
	if (_Skill) then
		local spellName = _GetSpellInfo (tonumber (spell))
		local SkillTargets = _Skill.targets._ActorTable
		
		for _, TargetActor in _ipairs (SkillTargets) do 
			local TargetActorSelf = _combat (class_type, TargetActor.nome)
			TargetActorSelf.custom = TargetActor.total + TargetActorSelf.custom
			_combat.totals [_customName] = _combat.totals [_customName] + TargetActor.total
		end
	end
end

--function atributo_heal:AtualizaBarra (instancia, qual_barra, lugar, total, sub_atributo, forcar)
function atributo_heal:AtualizaBarra (instancia, barras_container, qual_barra, lugar, total, sub_atributo, forcar, keyName, combat_time)

	local esta_barra = instancia.barras[qual_barra] --> pega a refer�ncia da barra na janela
	
	if (not esta_barra) then
		print ("DEBUG: problema com <instancia.esta_barra> "..qual_barra.." "..lugar)
		return
	end
	
	local tabela_anterior = esta_barra.minha_tabela
	
	esta_barra.minha_tabela = self --grava uma refer�ncia dessa classe de dano na barra
	self.minha_barra = esta_barra --> salva uma refer�ncia da barra no objeto do jogador
	
	esta_barra.colocacao = lugar --> salva na barra qual a coloca��o dela.
	self.colocacao = lugar --> salva qual a coloca��o do jogador no objeto dele
	
	local healing_total = self.total --> total de dano que este jogador deu
	local hps
	local porcentagem = self [keyName] / total * 100
	local esta_porcentagem

	if (_detalhes.time_type == 2 and self.grupo) then
		hps = healing_total / combat_time
		self.last_hps = hps
	else
		if (not self.on_hold) then
			hps = healing_total/self:Tempo() --calcula o dps deste objeto
			self.last_hps = hps --salva o dps dele
		else
			hps = self.last_hps
			
			if (hps == 0) then --> n�o calculou o dps dele ainda mas entrou em standby
				hps = healing_total/self:Tempo()
				self.last_hps = hps
			end
		end
	end
	
	-- >>>>>>>>>>>>>>> texto da direita
	if (instancia.atributo == 5) then --> custom
		esta_barra.texto_direita:SetText (_detalhes:ToK (self.custom) .." ".. div_abre .. _cstr ("%.1f", porcentagem).."%" .. div_fecha) --seta o texto da direita
		esta_porcentagem = _math_floor ((self.custom/instancia.top) * 100) --> determina qual o tamanho da barra
	else	
		if (sub_atributo == 1) then --> mostrando healing done
			esta_barra.texto_direita:SetText (_detalhes:ToK (healing_total) .." ".. div_abre .. _math_floor (hps) .. ", ".. _cstr ("%.1f", porcentagem).."%" .. div_fecha) --seta o texto da direita
			esta_porcentagem = _math_floor ((healing_total/instancia.top) * 100) --> determina qual o tamanho da barra
			
		elseif (sub_atributo == 2) then --> mostrando hps
			esta_barra.texto_direita:SetText (_cstr("%.1f", hps) .." ".. div_abre .. _detalhes:ToK (healing_total) .. ", ".._cstr("%.1f", porcentagem).."%" .. div_fecha) --seta o texto da direita
			esta_porcentagem = _math_floor ((hps/instancia.top) * 100) --> determina qual o tamanho da barra
			
		elseif (sub_atributo == 3) then --> mostrando overall
			esta_barra.texto_direita:SetText (_detalhes:ToK (self.totalover) .." ".. div_abre .._cstr("%.1f", porcentagem).."%" .. div_fecha) --seta o texto da direita --_cstr("%.1f", dps) .. " - ".. DPS do damage taken n�o ser� possivel correto?
			esta_porcentagem = _math_floor ((self.totalover/instancia.top) * 100) --> determina qual o tamanho da barra
			
		elseif (sub_atributo == 4) then --> mostrando healing take
			esta_barra.texto_direita:SetText (_detalhes:ToK (self.healing_taken) .." ".. div_abre .._cstr("%.1f", porcentagem).."%" .. div_fecha) --seta o texto da direita --_cstr("%.1f", dps) .. " - ".. DPS do damage taken n�o ser� possivel correto?
			esta_porcentagem = _math_floor ((self.healing_taken/instancia.top) * 100) --> determina qual o tamanho da barra
			
		end
	end
	
	if (esta_barra.mouse_over and not instancia.baseframe.isMoving) then --> precisa atualizar o tooltip
		gump:UpdateTooltip (qual_barra, esta_barra, instancia)
	end

	return self:RefreshBarra2 (esta_barra, instancia, tabela_anterior, forcar, esta_porcentagem, qual_barra, barras_container)	
end

--------------------------------------------- // TOOLTIPS // ---------------------------------------------


---------> TOOLTIPS BIFURCA��O
function atributo_heal:ToolTip (instancia, numero, barra)
	--> seria possivel aqui colocar o icone da classe dele?

	if (instancia.atributo == 5) then --> custom
		return self:TooltipForCustom (barra)
	else
		--GameTooltip:ClearLines()
		--GameTooltip:AddLine (barra.colocacao..". "..self.nome)
		if (instancia.sub_atributo <= 3) then --> healing done, HPS or Overheal
			return self:ToolTip_HealingDone (instancia, numero, barra)
		elseif (instancia.sub_atributo == 4) then --> healing taken
			return self:ToolTip_HealingTaken (instancia, numero, barra)
		end
	end
end


---------> HEALING TAKEN
function atributo_heal:ToolTip_HealingTaken (instancia, numero, barra)
	local curadores = self.healing_from
	local total_curado = self.healing_taken
	
	local tabela_do_combate = instancia.showing
	local showing = tabela_do_combate [class_type] --> o que esta sendo mostrado -> [1] - dano [2] - cura --> pega o container com ._NameIndexTable ._ActorTable
	
	local meus_curadores = {}
	
	for nome, _ in _pairs (curadores) do --> agressores seria a lista de nomes
		local este_curador = showing._ActorTable[showing._NameIndexTable[nome]]
		if (este_curador) then --> checagem por causa do total e do garbage collector que n�o limpa os nomes que deram dano
			local alvos = este_curador.targets
			local este_alvo = alvos._ActorTable[alvos._NameIndexTable[self.nome]]
			if (este_alvo) then
				meus_curadores [#meus_curadores+1] = {nome, este_alvo.total, este_curador.classe}
			end
		end
	end
	
	GameTooltip:AddLine (" ")
	
	_table_sort (meus_curadores, function (a, b) return a[2] > b[2] end)
	local max = #meus_curadores
	if (max > 6) then
		max = 6
	end

	for i = 1, max do
		GameTooltip:AddDoubleLine (meus_curadores[i][1]..": ", meus_curadores[i][2].." (".._cstr ("%.1f", (meus_curadores[i][2]/total_curado) * 100).."%)", 1, 1, 1, 1, 1, 1)
		local classe = meus_curadores[i][3]
		if (not classe) then
			classe = "monster"
		end
		GameTooltip:AddTexture ("Interface\\AddOns\\Details\\images\\"..classe:lower().."_small")
	end
	
	return true
end

---------> HEALING DONE / HPS / OVERHEAL
function atributo_heal:ToolTip_HealingDone (instancia, numero, barra)

	local ActorHealingTable = {}
	local ActorHealingTargets = {}
	local ActorSkillsContainer = self.spell_tables._ActorTable

	local actor_key, skill_key = "total", "total"
	if (instancia.sub_atributo == 3) then
		key = "totalover", "overheal"
	end
	
	local ActorTotal = self [actor_key]
	for _spellid, _skill in _pairs (ActorSkillsContainer) do 
		local SkillName, _, SkillIcon = _GetSpellInfo (_spellid)
		_table_insert (ActorHealingTable, {_spellid, _skill [skill_key], _skill [skill_key]/ActorTotal*100, {SkillName, nil, SkillIcon}})
	end
	_table_sort (ActorHealingTable, _detalhes.Sort2)
	
	--> TOP Curados
	ActorSkillsContainer = self.targets._ActorTable
	for _, TargetTable in _ipairs (ActorSkillsContainer) do
		_table_insert (ActorHealingTargets, {TargetTable.nome, TargetTable.total, TargetTable.total/ActorTotal*100})
	end
	_table_sort (ActorHealingTargets, _detalhes.Sort2)

	--> Mostra as habilidades no tooltip
	GameTooltip:AddLine (Loc ["STRING_SPELLS"] .. ":") --> localiza-me
	for i = 1, _math_min (_detalhes.tooltip_max_abilities, #ActorHealingTable) do
		if (ActorHealingTable[i][2] < 1) then
			break
		end
		GameTooltip:AddDoubleLine (ActorHealingTable[i][4][1]..": ", _detalhes:comma_value (ActorHealingTable[i][2]).." (".._cstr ("%.1f", ActorHealingTable[i][3]).."%)", 1, 1, 1, 1, 1, 1)
		GameTooltip:AddTexture (ActorHealingTable[i][4][3])
	end
	
	if (instancia.sub_atributo < 3) then -- 1 or 2 -> healing done or hps
		GameTooltip:AddLine (Loc ["STRING_TARGETS"]..":") --> localiza-me
		for i = 1, _math_min (_detalhes.tooltip_max_targets, #ActorHealingTargets) do
			if (ActorHealingTargets[i][2] < 1) then
				break
			end
			GameTooltip:AddDoubleLine (ActorHealingTargets[i][1]..": ", _detalhes:comma_value (ActorHealingTargets[i][2]) .." (".._cstr ("%.1f", ActorHealingTargets[i][3]).."%)", 1, 1, 1, 1, 1, 1)
			GameTooltip:AddTexture ("Interface\\AddOns\\Details\\images\\espadas")
		end
	end
	
	return true
end


--------------------------------------------- // JANELA DETALHES // ---------------------------------------------
---------- bifurca��o
function atributo_heal:MontaInfo()
	if (info.sub_atributo == 1 or info.sub_atributo == 2) then
		return self:MontaInfoHealingDone()
	elseif (info.sub_atributo == 3) then
		return self:MontaInfoOverHealing()
	elseif (info.sub_atributo == 4) then
		return self:MontaInfoHealTaken()
	end
end

function atributo_heal:MontaInfoHealTaken()

	local healing_taken = self.healing_taken
	local curandeiros = self.healing_from
	local instancia = info.instancia
	local tabela_do_combate = instancia.showing
	local showing = tabela_do_combate [class_type] --> o que esta sendo mostrado -> [1] - dano [2] - cura --> pega o container com ._NameIndexTable ._ActorTable
	local barras = info.barras1
	local meus_curandeiros = {}
	
	local este_curandeiro	
	for nome, _ in _pairs (curandeiros) do
		este_curandeiro = showing._ActorTable[showing._NameIndexTable[nome]]
		if (este_curandeiro) then
			local alvos = este_curandeiro.targets
			local este_alvo = alvos._ActorTable[alvos._NameIndexTable[self.nome]]
			if (este_alvo) then
				meus_curandeiros [#meus_curandeiros+1] = {nome, este_alvo.total, este_alvo.total/healing_taken*100, este_curandeiro.classe}
			end
		end
	end
	
	local amt = #meus_curandeiros
	
	if (amt < 1) then
		return true
	end
	
	_table_sort (meus_curandeiros, function (a, b) return a[2] > b[2] end)
	
	gump:JI_AtualizaContainerBarras (amt)

	local max_ = meus_curandeiros [1] and meus_curandeiros [1][2] or 0
	
	for index, tabela in _ipairs (meus_curandeiros) do
		
		local barra = barras [index]

		if (not barra) then
			barra = gump:CriaNovaBarraInfo1 (instancia, index)
			barra.textura:SetStatusBarColor (1, 1, 1, 1)
			
			barra.on_focus = false
		end

		if (not info.mostrando_mouse_over) then
			if (tabela[1] == self.detalhes) then --> tabela [1] = NOME = NOME que esta na caixa da direita
				if (not barra.on_focus) then --> se a barra n�o tiver no foco
					barra.textura:SetStatusBarColor (129/255, 125/255, 69/255, 1)
					barra.on_focus = true
					if (not info.mostrando) then
						info.mostrando = barra
					end
				end
			else
				if (barra.on_focus) then
					barra.textura:SetStatusBarColor (1, 1, 1, 1) --> volta a cor antiga
					barra:SetAlpha (.9) --> volta a alfa antiga
					barra.on_focus = false
				end
			end
		end

		if (index == 1) then
			barra.textura:SetValue (100)
		else
			barra.textura:SetValue (tabela[2]/max_*100) --> muito mais rapido...
		end

		barra.texto_esquerdo:SetText (index..instancia.divisores.colocacao..tabela[1]) --seta o texto da esqueda
		barra.texto_direita:SetText (tabela[2] .." ".. instancia.divisores.abre .._cstr("%.1f", tabela[3]) .."%".. instancia.divisores.fecha) --seta o texto da direita
		
		local classe = tabela[4]
		if (not classe) then
			classe = "monster"
		end

		barra.icone:SetTexture ("Interface\\AddOns\\Details\\images\\"..classe:lower().."_small")

		barra.minha_tabela = self
		barra.show = tabela[1]
		barra:Show()

		if (self.detalhes and self.detalhes == barra.show) then
			self:MontaDetalhes (self.detalhes, barra)
		end
		
	end
	
end

function atributo_heal:MontaInfoOverHealing()
--> pegar as habilidade de dar sort no heal
	
	local instancia = info.instancia
	local total = self.totalover
	local tabela = self.spell_tables._ActorTable
	local minhas_curas = {}
	local barras = info.barras1

	for spellid, tabela in _pairs (tabela) do
		local nome, rank, icone = _GetSpellInfo (spellid)
		_table_insert (minhas_curas, {spellid, tabela.overheal, tabela.overheal/total*100, nome, icone})
	end

	_table_sort (minhas_curas, function(a, b) return a[2] > b[2] end)

	local amt = #minhas_curas
	gump:JI_AtualizaContainerBarras (amt)

	local max_ = minhas_curas[1] and minhas_curas[1][2] or 0

	for index, tabela in _ipairs (minhas_curas) do

		local barra = barras [index]

		if (not barra) then
			barra = gump:CriaNovaBarraInfo1 (instancia, index)
			barra.textura:SetStatusBarColor (1, 1, 1, 1)
			barra.on_focus = false
		end

		if (not info.mostrando_mouse_over) then
			if (tabela[1] == self.detalhes) then --> tabela [1] = spellid = spellid que esta na caixa da direita
				if (not barra.on_focus) then --> se a barra n�o tiver no foco
					barra.textura:SetStatusBarColor (129/255, 125/255, 69/255, 1)
					barra.on_focus = true
					if (not info.mostrando) then
						info.mostrando = barra
					end
				end
			else
				if (barra.on_focus) then
					barra.textura:SetStatusBarColor (1, 1, 1, 1) --> volta a cor antiga
					barra:SetAlpha (.9) --> volta a alfa antiga
					barra.on_focus = false
				end
			end
		end		

		if (index == 1) then
			barra.textura:SetValue (100)
		else
			barra.textura:SetValue (tabela[2]/max_*100) --> muito mais rapido...
		end

		barra.texto_esquerdo:SetText (index..instancia.divisores.colocacao..tabela[4]) --seta o texto da esqueda
		barra.texto_direita:SetText (tabela[2] .." ".. instancia.divisores.abre .. _cstr ("%.1f", tabela[3]) .."%".. instancia.divisores.fecha) --seta o texto da direita

		barra.icone:SetTexture (tabela[5])

		barra.minha_tabela = self
		barra.show = tabela[1]
		barra:Show()

		if (self.detalhes and self.detalhes == barra.show) then
			self:MontaDetalhes (self.detalhes, barra)
		end
	end
	
	--> TOP OVERHEALED
	local meus_inimigos = {}
	tabela = self.targets._ActorTable
	for _, tabela in _ipairs (tabela) do
		_table_insert (meus_inimigos, {tabela.nome, tabela.overheal, tabela.overheal/total*100})
	end
	_table_sort (meus_inimigos, function(a, b) return a[2] > b[2] end )	
	
	local amt_alvos = #meus_inimigos
	gump:JI_AtualizaContainerAlvos (amt_alvos)
	
	local max_inimigos = meus_inimigos[1] and meus_inimigos[1][2] or 0
	
	for index, tabela in _ipairs (meus_inimigos) do
	
		local barra = info.barras2 [index]
		
		if (not barra) then
			barra = gump:CriaNovaBarraInfo2 (instancia, index)
			barra.textura:SetStatusBarColor (1, 1, 1, 1)
		end
		
		if (index == 1) then
			barra.textura:SetValue (100)
		else
			barra.textura:SetValue (tabela[2]/max_*100) --> muito mais rapido...
		end
		
		barra.texto_esquerdo:SetText (index..instancia.divisores.colocacao..tabela[1]) --seta o texto da esqueda
		barra.texto_direita:SetText (tabela[2] .." ".. instancia.divisores.abre .. _cstr ("%.1f", tabela[3]) .. instancia.divisores.fecha) --seta o texto da direita
		
		-- o que mostrar no local do �cone?
		--barra.icone:SetTexture (tabela[4][3])
		
		barra.minha_tabela = self
		barra.nome_inimigo = tabela [1]
		
		-- no lugar do spell id colocar o que?
		--barra.spellid = tabela[5]
		barra:Show()
		
		--if (self.detalhes and self.detalhes == barra.spellid) then
		--	self:MontaDetalhes (self.detalhes, barra)
		--end
	end
end

function atributo_heal:MontaInfoHealingDone()

	--> pegar as habilidade de dar sort no heal
	
	local instancia = info.instancia
	local total = self.total
	local tabela = self.spell_tables._ActorTable
	local minhas_curas = {}
	local barras = info.barras1

	for spellid, tabela in _pairs (tabela) do
		local nome, rank, icone = _GetSpellInfo (spellid)
		_table_insert (minhas_curas, {spellid, tabela.total, tabela.total/total*100, nome, icone})
	end

	_table_sort (minhas_curas, function(a, b) return a[2] > b[2] end)

	local amt = #minhas_curas
	gump:JI_AtualizaContainerBarras (amt)

	local max_ = minhas_curas[1] and minhas_curas[1][2] or 0

	for index, tabela in _ipairs (minhas_curas) do

		local barra = barras [index]

		if (not barra) then
			barra = gump:CriaNovaBarraInfo1 (instancia, index)
			barra.textura:SetStatusBarColor (1, 1, 1, 1)
			barra.on_focus = false
		end

		self:FocusLock (barra, tabela[1])
		
		self:UpdadeInfoBar (barra, index, tabela[1], tabela[4], tabela[2], max_, tabela[3], tabela[5], true)

		barra.minha_tabela = self
		barra.show = tabela[1]
		barra:Show()

		if (self.detalhes and self.detalhes == barra.show) then
			self:MontaDetalhes (self.detalhes, barra)
		end
	end
	
	--> SERIA TOP CURADOS
	local meus_inimigos = {}
	tabela = self.targets._ActorTable
	for _, tabela in _ipairs (tabela) do
		_table_insert (meus_inimigos, {tabela.nome, tabela.total, tabela.total/total*100})
	end
	_table_sort (meus_inimigos, function(a, b) return a[2] > b[2] end )	
	
	local amt_alvos = #meus_inimigos
	gump:JI_AtualizaContainerAlvos (amt_alvos)
	
	local max_inimigos = meus_inimigos[1] and meus_inimigos[1][2] or 0
	
	for index, tabela in _ipairs (meus_inimigos) do
	
		local barra = info.barras2 [index]
		
		if (not barra) then
			barra = gump:CriaNovaBarraInfo2 (instancia, index)
			barra.textura:SetStatusBarColor (1, 1, 1, 1)
		end
		
		if (index == 1) then
			barra.textura:SetValue (100)
		else
			barra.textura:SetValue (tabela[2]/max_*100) --> muito mais rapido...
		end
		
		barra.texto_esquerdo:SetText (index..instancia.divisores.colocacao..tabela[1]) --seta o texto da esqueda
		barra.texto_direita:SetText (_detalhes:comma_value (tabela[2]) .." ".. instancia.divisores.abre .. _cstr ("%.1f", tabela[3]) .. instancia.divisores.fecha) --seta o texto da direita
		
		-- o que mostrar no local do �cone?
		--barra.icone:SetTexture (tabela[4][3])
		
		barra.minha_tabela = self
		barra.nome_inimigo = tabela [1]
		
		-- no lugar do spell id colocar o que?
		--barra.spellid = tabela[5]
		barra:Show()
		
		--if (self.detalhes and self.detalhes == barra.spellid) then
		--	self:MontaDetalhes (self.detalhes, barra)
		--end
	end
	
end

function atributo_heal:MontaTooltipAlvos (esta_barra, index)
	-- eu ja sei quem � o alvo a mostrar os detalhes
	-- dar foreach no container de habilidades -- pegar os alvos da habilidade -- e ver se dentro do container tem o meu alvo.
	
	local inimigo = esta_barra.nome_inimigo
	local container = self.spell_tables._ActorTable
	local habilidades = {}
	local total = self.total
	
	if (info.instancia.sub_atributo == 3) then --> overheal
		total = self.totalover
		for spellid, tabela in _pairs (container) do
			--> tabela = classe_damage_habilidade
			local alvos = tabela.targets._ActorTable
			for _, tabela in _ipairs (alvos) do
				--> tabela = classe_target
				if (tabela.nome == inimigo) then
					habilidades [#habilidades+1] = {spellid, tabela.overheal}
				end
			end
		end
	else
		for spellid, tabela in _pairs (container) do
			--> tabela = classe_damage_habilidade
			local alvos = tabela.targets._ActorTable
			for _, tabela in _ipairs (alvos) do
				--> tabela = classe_target
				if (tabela.nome == inimigo) then
					habilidades [#habilidades+1] = {spellid, tabela.total}
				end
			end
		end
	
	end
	
	_table_sort (habilidades, function (a, b) return a[2] > b[2] end)
	
	GameTooltip:AddLine (index..". "..inimigo)
	GameTooltip:AddLine (Loc ["STRING_HEALING_FROM"]..":") --> localize-me
	GameTooltip:AddLine (" ")
	
	for index, tabela in _ipairs (habilidades) do
		local nome, rank, icone = _GetSpellInfo (tabela[1])
		if (index < 8) then
			GameTooltip:AddDoubleLine (index..". |T"..icone..":0|t "..nome, _detalhes:comma_value (tabela[2]).." (".. _cstr ("%.1f", tabela[2]/total*100).."%)", 1, 1, 1, 1, 1, 1)
			--GameTooltip:AddTexture (icone)
		else
			GameTooltip:AddDoubleLine (index..". "..nome, _detalhes:comma_value (tabela[2]).." (".. _cstr ("%.1f", tabela[2]/total*100).."%)", .65, .65, .65, .65, .65, .65)
		end
	end
	
	return true
	--GameTooltip:AddDoubleLine (minhas_curas[i][4][1]..": ", minhas_curas[i][2].." (".._cstr ("%.1f", minhas_curas[i][3]).."%)", 1, 1, 1, 1, 1, 1)
	
end

function atributo_heal:MontaDetalhes (spellid, barra)
	--> bifurga��es
	if (info.sub_atributo == 1 or info.sub_atributo == 2 or info.sub_atributo == 3) then
		return self:MontaDetalhesHealingDone (spellid, barra)
	elseif (info.sub_atributo == 4) then
		atributo_heal:MontaDetalhesHealingTaken (spellid, barra)
	end
end

function atributo_heal:MontaDetalhesHealingTaken (nome, barra)

	for _, barra in _ipairs (info.barras3) do 
		barra:Hide()
	end

	local barras = info.barras3
	local instancia = info.instancia
	
	local tabela_do_combate = info.instancia.showing
	local showing = tabela_do_combate [class_type] --> o que esta sendo mostrado -> [1] - dano [2] - cura --> pega o container com ._NameIndexTable ._ActorTable

	local este_curandeiro = showing._ActorTable[showing._NameIndexTable[nome]]
	local conteudo = este_curandeiro.spell_tables._ActorTable --> _pairs[] com os IDs das magias
	
	local actor = info.jogador.nome
	
	local total = este_curandeiro.targets._ActorTable [este_curandeiro.targets._NameIndexTable [actor]].total

	local minhas_magias = {}

	for spellid, tabela in _pairs (conteudo) do --> da foreach em cada spellid do container
	
		--> preciso pegar os alvos que esta magia atingiu
		local alvos = tabela.targets
		local index = alvos._NameIndexTable[actor]
		
		if (index) then --> esta magia deu dano no actor
			local este_alvo = alvos._ActorTable[index] --> pega a classe_target
			local spell_nome, rank, icone = _GetSpellInfo (spellid)
			_table_insert (minhas_magias, {spellid, este_alvo.total, este_alvo.total/total*100, spell_nome, icone})
		end

	end

	_table_sort (minhas_magias, function(a, b) return a[2] > b[2] end)

	--local amt = #minhas_magias
	--gump:JI_AtualizaContainerBarras (amt)

	local max_ = minhas_magias[1] and minhas_magias[1][2] or 0 --> dano que a primeiro magia vez
	
	local barra
	for index, tabela in _ipairs (minhas_magias) do
		barra = barras [index]

		if (not barra) then --> se a barra n�o existir, criar ela ent�o
			barra = gump:CriaNovaBarraInfo3 (instancia, index)
			barra.textura:SetStatusBarColor (1, 1, 1, 1) --> isso aqui � a parte da sele��o e descele��o
		end
		
		if (index == 1) then
			barra.textura:SetValue (100)
		else
			barra.textura:SetValue (tabela[2]/max_*100) --> muito mais rapido...
		end

		barra.texto_esquerdo:SetText (index..instancia.divisores.colocacao..tabela[4]) --seta o texto da esqueda
		barra.texto_direita:SetText (tabela[2] .." ".. instancia.divisores.abre .._cstr("%.1f", tabela[3]) .."%".. instancia.divisores.fecha) --seta o texto da direita
		
		barra.icone:SetTexture (tabela[5])

		barra:Show() --> mostra a barra
		
		if (index == 15) then 
			break
		end
	end
end

function atributo_heal:MontaDetalhesHealingDone (spellid, barra)
	--> localize-me

	local esta_magia = self.spell_tables._ActorTable [spellid]
	if (not esta_magia) then
		return
	end
	
	--> icone direito superior
	local nome, rank, icone = _GetSpellInfo (spellid)
	local infospell = {nome, rank, icone}

	info.spell_icone:SetTexture (infospell[3])

	local total = self.total
	
	local overheal = esta_magia.overheal
	local meu_total = esta_magia.total + overheal
	
	local meu_tempo
	if (_detalhes.time_type == 1 or not self.grupo) then
		meu_tempo = self:Tempo()
	elseif (_detalhes.time_type == 2) then
		meu_tempo = self:GetCombatTime()
	end
	
	--local total_hits = esta_magia.counter
	local total_hits = esta_magia.n_amt+esta_magia.c_amt
	
	local index = 1
	
	local data = {}
	
	if (esta_magia.total > 0) then
	
	--> GERAL
		local media = esta_magia.total/total_hits
		
		local this_hps = nil
		if (esta_magia.counter > esta_magia.c_amt) then
			this_hps = Loc ["STRING_HPS"]..": ".._cstr ("%.1f", esta_magia.total/meu_tempo) --> localiza-me
		else
			this_hps = Loc ["STRING_HPS"]..": 0" --> localiza-me
		end
		
		gump:SetaDetalheInfoTexto ( index, 100, --> Localize-me
			Loc ["STRING_GERAL"], --> localiza-me
			Loc ["STRING_HEAL"]..": ".._detalhes:ToK (esta_magia.total), --> localiza-me
			Loc ["STRING_PERCENTAGE"]..": ".._cstr ("%.1f", esta_magia.total/total*100) .. "%", --> localiza-me
			Loc ["STRING_MEDIA"]..": ".._cstr ("%.1f", media), --> localiza-me
			this_hps,
			Loc ["STRING_HITS"]..": " .. total_hits) --> localiza-me
	
	--> NORMAL
		local normal_hits = esta_magia.n_amt
		if (normal_hits > 0) then
			local normal_curado = esta_magia.n_curado
			local media_normal = normal_curado/normal_hits
			local T = (meu_tempo*normal_curado)/esta_magia.total
			local P = media/media_normal*100
			T = P*T/100

			data[#data+1] = {
				esta_magia.n_amt, 
				normal_hits/total_hits*100, 
				--esta_magia.n_curado/esta_magia.total*100, 
				"Curas Normais", --> localiza-me
				"Minimo: ".._detalhes:comma_value (esta_magia.n_min), --> localiza-me
				"Maximo: ".._detalhes:comma_value (esta_magia.n_max), --> localiza-me
				"Media: ".._cstr ("%.1f", media_normal), --> localiza-me
				"HPS: ".._cstr ("%.1f", normal_curado/T), --> localiza-me
				--normal_hits.. " / ".. _cstr ("%.1f", normal_hits/total_hits*100).."%"
				--normal_hits.. " / ".. _cstr ("%.1f", esta_magia.n_curado/total*100).."%"
				--esta_magia.n_curado.. " / " .. normal_hits .. " / ".. _cstr ("%.1f", esta_magia.n_curado/esta_magia.total*100).."%"
				--esta_magia.n_curado.. " / " .. normal_hits .. " / ".. _cstr ("%.1f", normal_hits/total_hits*100).."%"
				normal_hits .. " / ".. _cstr ("%.1f", normal_hits/total_hits*100).."%"
				}
		end

	--> CRITICO
		if (esta_magia.c_amt > 0) then	
			local media_critico = esta_magia.c_curado/esta_magia.c_amt
			local T = (meu_tempo*esta_magia.c_curado)/esta_magia.total
			local P = media/media_critico*100
			T = P*T/100
			local crit_dps = _cstr ("%.1f", esta_magia.c_curado/T)
			
			data[#data+1] = {
				esta_magia.c_amt,
				esta_magia.c_amt/total_hits*100, 
				--esta_magia.c_curado/esta_magia.total*100,
				"Curas Criticas", --> localiza-me
				"Minimo: ".._detalhes:comma_value (esta_magia.c_min), --> localiza-me
				"Maximo: ".._detalhes:comma_value (esta_magia.c_max), --> localiza-me
				"Media: ".._cstr ("%.1f", media_critico), --> localiza-me
				"HPS: ".._cstr ("%.1f", crit_dps), --> localiza-me
				--esta_magia.c_amt.. " / ".._cstr ("%.1f", esta_magia.c_amt/total_hits*100).."%"
				--esta_magia.c_amt.. " / ".._cstr ("%.1f", esta_magia.c_curado/total*100).."%"
				--esta_magia.c_curado.. " / " .. esta_magia.c_amt .. " / ".._cstr ("%.1f", esta_magia.c_curado/esta_magia.total*100).."%"
				--esta_magia.c_curado.. " / " .. esta_magia.c_amt .. " / ".._cstr ("%.1f", esta_magia.c_amt/total_hits*100).."%"
				esta_magia.c_amt .. " / ".._cstr ("%.1f", esta_magia.c_amt/total_hits*100).."%"
				}
		end
		
	end
	
	_table_sort (data, function (a, b) return a[1] > b[1] end)

	--> Aqui pode vir a cura absorvida

		local absorbed = esta_magia.absorbed

		if (absorbed > 0) then
			local porcentagem_absorbed = absorbed/esta_magia.total*100
			data[#data+1] = {
				absorbed,
				{["p"] = porcentagem_absorbed, ["c"] = {117/255, 58/255, 0/255}},
				"Cura Absorvida", --> localiza-me
				"", --esta_magia.glacing.curado
				"",
				"",
				"",
				absorbed.." / ".._cstr ("%.1f", porcentagem_absorbed).."%"
				}
		end

	for i = #data+1, 3 do --> para o overheal aparecer na ultima barra
		data[i] = nil
	end
		
	--> overhealing

		if (overheal > 0) then
			local porcentagem_overheal = overheal/meu_total*100
			data[4] = { 
				overheal,
				{["p"] = porcentagem_overheal, ["c"] = {0.5, 0.1, 0.1}},
				"Sobrecura", --> localiza-me
				"",
				"",
				"",
				"",
				_detalhes:comma_value (overheal).." / ".._cstr ("%.1f", porcentagem_overheal).."%"
				}
		end
	
	for index = 1, 4 do
		local tabela = data[index]
		if (not tabela) then
			gump:HidaDetalheInfo (index+1)
		else
			gump:SetaDetalheInfoTexto (index+1, tabela[2], tabela[3], tabela[4], tabela[5], tabela[6], tabela[7], tabela[8])
		end
	end

	--for i = #data+2, 5 do
	--	gump:HidaDetalheInfo (i)
	--end

end

--if (esta_magia.counter == esta_magia.c_amt) then --> s� teve critico
--	gump:SetaDetalheInfoTexto (1, nil, nil, nil, nil, nil, "DPS: "..crit_dps)
--end

--controla se o dps do jogador esta travado ou destravado
function atributo_heal:Iniciar (iniciar)
	if (iniciar == nil) then 
		return self.iniciar_hps --retorna se o dps esta aberto ou fechado para este jogador
	elseif (iniciar) then
		self.iniciar_hps = true
		self:RegistrarNaTimeMachine() --coloca ele da timeMachine
		if (self.shadow) then
			self.shadow.iniciar_hps = true --> isso foi posto recentemente
			self.shadow:RegistrarNaTimeMachine()
		end
	else
		self.iniciar_hps = false
		self:DesregistrarNaTimeMachine() --retira ele da timeMachine
		if (self.shadow) then
			self.shadow:DesregistrarNaTimeMachine()
			self.shadow.iniciar_hps = false --> isso foi posto recentemente
		end
	end
end

function atributo_heal:ColetarLixo()
	return _detalhes:ColetarLixo (class_type)
end

function _detalhes.refresh:r_atributo_heal (este_jogador, shadow)
	_setmetatable (este_jogador, atributo_heal)
	este_jogador.__index = atributo_heal
	
	if (shadow ~= -1) then
		este_jogador.shadow = shadow
		_detalhes.refresh:r_container_combatentes (este_jogador.targets, shadow.targets)
		_detalhes.refresh:r_container_habilidades (este_jogador.spell_tables, shadow.spell_tables)
	else
		_detalhes.refresh:r_container_combatentes (este_jogador.targets, -1)
		_detalhes.refresh:r_container_habilidades (este_jogador.spell_tables, -1)
	end
end

function _detalhes.clear:c_atributo_heal (este_jogador)
	este_jogador.__index = {}
	este_jogador.shadow = nil
	este_jogador.links = nil
	este_jogador.minha_barra = nil
	
	_detalhes.clear:c_container_combatentes (este_jogador.targets)
	_detalhes.clear:c_container_habilidades (este_jogador.spell_tables)
end

atributo_heal.__add = function (shadow, tabela2)

	--> tempo decorrido
	local tempo = (tabela2.end_time or time()) - tabela2.start_time
	shadow.start_time = shadow.start_time - tempo

	shadow.total = shadow.total - tabela2.total
	_detalhes.tabela_overall.totals[2] = _detalhes.tabela_overall.totals[2] + tabela2.total
	
	if (tabela2.grupo) then
		_detalhes.tabela_overall.totals_grupo[2] = _detalhes.tabela_overall.totals_grupo[2] + tabela2.total
	end
	
	shadow.totalover = shadow.totalover - tabela2.totalover
	
	shadow.total_without_pet = shadow.total_without_pet - tabela2.total_without_pet
	shadow.totalover_without_pet = shadow.totalover_without_pet - tabela2.totalover_without_pet
	
	shadow.healing_taken = shadow.healing_taken - tabela2.healing_taken
	
	--> copia o healing_from
	for nome, _ in _pairs (tabela2.healing_from) do 
		shadow.healing_from [nome] = true
	end
	
	--> copiar o heal_enemy
	if (tabela2.heal_enemy) then 
		for spellid, amount in _pairs (tabela2.heal_enemy) do 
			if (shadow.heal_enemy [spellid]) then 
				shadow.heal_enemy [spellid] = shadow.heal_enemy [spellid] + amount
			else
				shadow.heal_enemy [spellid] = amount
			end
		end
	end
	
	--> copia o container de alvos
	for index, alvo in _ipairs (tabela2.targets._ActorTable) do 
		local alvo_shadow = shadow.targets:PegarCombatente (alvo.serial, alvo.nome, alvo.flag_original, true)
		alvo_shadow.total = alvo_shadow.total + alvo.total
		alvo_shadow.overheal = alvo_shadow.overheal + alvo.overheal
		alvo_shadow.absorbed = alvo_shadow.absorbed + alvo.absorbed 
	end
	
	--> copia o container de habilidades
	for spellid, habilidade in _pairs (tabela2.spell_tables._ActorTable) do 
		local habilidade_shadow = shadow.spell_tables:PegaHabilidade (spellid, true, nil, true)
		
		for index, alvo in _ipairs (habilidade.targets._ActorTable) do 
			local alvo_shadow = habilidade_shadow.targets:PegarCombatente (alvo.serial, alvo.nome, alvo.flag_original, true)
			alvo_shadow.total = alvo_shadow.total + alvo.total
			alvo_shadow.overheal = alvo_shadow.overheal + alvo.overheal
			alvo_shadow.absorbed = alvo_shadow.absorbed + alvo.absorbed 
		end
		
		for key, value in _pairs (habilidade) do 
			if (_type (value) == "number") then
				if (key ~= "id") then
					if (not habilidade_shadow [key]) then 
						habilidade_shadow [key] = 0
					end
					habilidade_shadow [key] = habilidade_shadow [key] + value
				end
			end
		end
	end
	
	return shadow
end

atributo_heal.__sub = function (tabela1, tabela2)
	tabela1.total = tabela1.total - tabela2.total
	tabela1.totalover = tabela1.totalover - tabela2.totalover
	
	tabela1.total_without_pet = tabela1.total_without_pet - tabela2.total_without_pet
	tabela1.totalover_without_pet = tabela1.totalover_without_pet - tabela2.totalover_without_pet
	
	tabela1.healing_taken = tabela1.healing_taken - tabela2.healing_taken
	
	return tabela1
end