local state, data, reactor, turbine, info_window, rules_window

local STATES = {
	READY = 1, -- Reaktor ist ausgeschaltet // Kann gestartet werden
	RUNNING = 2, -- Reaktor in Betrieb // Sicherheit inaktiv
	ESTOP = 3, -- Reaktor ist ausgeschaltet // Sicherheit aktiv
	UNKNOWN = 4, -- Reaktor oder Turbine "Peripherals" fehlen
}

------------------------------------------------

local rules = {}

local function add_rule(name, fn)
	table.insert(rules, function()
		local ok, rule_met, value = pcall(fn)
		if ok then
			return rule_met, string.format("%s (%s)", name, value)
		else
			return false, name
		end
	end)
end

add_rule("REAKTOR // TEMPERATUR  = 745K", function()
	local value = string.format("%3dK", math.ceil(data.reactor_temp))
	return data.reactor_temp <= 745, value
end)

add_rule("REAKTOR // SCHADEN     =  10%", function()
	local value = string.format("%3d%%", math.ceil(data.reactor_damage * 100))
	return data.reactor_damage <= 0.10, value
end)

add_rule("REAKTOR // NATRIUM     =  10%", function()
	local value = string.format("%3d%%", math.floor(data.reactor_coolant * 100))
	return data.reactor_coolant >= 0.10, value
end)

add_rule("REAKTOR // ABFALL      =  90%", function()
	local value = string.format("%3d%%", math.ceil(data.reactor_waste * 100))
	return data.reactor_waste <= 0.90, value
end)

add_rule("TURBINE // ENERGIE     =  95%", function()
	local value = string.format("%3d%%", math.ceil(data.turbine_energy * 100))
	return data.turbine_energy <= 0.95, value
end)

local function all_rules_met()
	for i, rule in ipairs(rules) do
		if not rule() then
			return false
		end
	end
	-- Manuelle Stop durch RESA Knopf
	return state ~= STATES.RUNNING or data.reactor_on
end

------------------------------------------------

local function update_data()
	data = {
		lever_on = redstone.getInput("top"),

		reactor_on = reactor.getStatus(),
		reactor_burn_rate = reactor.getBurnRate(),
		reactor_max_burn_rate = reactor.getMaxBurnRate(),
		reactor_temp = reactor.getTemperature(),
		reactor_damage = reactor.getDamagePercent(),
		reactor_coolant = reactor.getCoolantFilledPercentage(),
		reactor_waste = reactor.getWasteFilledPercentage(),

		turbine_energy = turbine.getEnergyFilledPercentage(),
	}
end

------------------------------------------------

local function colored(text, fg, bg)
	term.setTextColor(fg or colors.white)
	term.setBackgroundColor(bg or colors.black)
	term.write(text)
end

local function make_section(name, x, y, w, h)
	for row = 1, h do
		term.setCursorPos(x, y + row - 1)
		local char = (row == 1 or row == h) and "\127" or " "
		colored("\127" .. string.rep(char, w - 2) .. "\127", colors.gray)
	end

	term.setCursorPos(x + 2, y)
	colored(" " .. name .. " ")

	return window.create(term.current(), x + 2, y + 2, w - 4, h - 4)
end

local function update_info()
	local prev_term = term.redirect(info_window)

	term.clear()
	term.setCursorPos(1, 1)

	if state == STATES.UNKNOWN then
		colored("VERBINDUNG FEHLGESCHLAGEN", colors.red)
		return
	end

	colored("REAKTOR: ")
	colored(data.reactor_on and "ON " or "OFF", data.reactor_on and colors.green or colors.red)
	colored("  STROM: ")
	colored(data.lever_on and "ON " or "OFF", data.lever_on and colors.green or colors.red)
	colored("  R. LIMIT: ")
	colored(string.format("%4.1f", data.reactor_burn_rate), colors.blue)
	colored("/", colors.lightGray)
	colored(string.format("%4.1f", data.reactor_max_burn_rate), colors.blue)

	term.setCursorPos(1, 3)

	colored("STATUS: ")
	if state == STATES.READY then
		colored("BEREIT!", colors.blue)
	elseif state == STATES.RUNNING then
		colored("IN BETRIEB...", colors.green)
	elseif state == STATES.ESTOP and not all_rules_met() then
		colored("RESA // SICHERHEIT AKTIV", colors.red)
	elseif state == STATES.ESTOP then
		colored("RESA // BITTE NEUSTARTEN", colors.red)
	end -- STATES.UNKNOWN Fälle

	term.redirect(prev_term)
end

local estop_reasons = {}

local function update_rules()
	local prev_term = term.redirect(rules_window)

	term.clear()

	if state ~= STATES.ESTOP then
		estop_reasons = {}
	end

	for i, rule in ipairs(rules) do
		local ok, text = rule()
		term.setCursorPos(1, i)
		if ok and not estop_reasons[i] then
			colored("[  OK  ] ", colors.green)
			colored(text, colors.lightGray)
		else
			colored("[ RESA ] ", colors.red)
			colored(text, colors.red)
			estop_reasons[i] = true
		end
	end

	term.redirect(prev_term)
end

------------------------------------------------

local function main_loop()
	-- Search for peripherals again if one or both are missing
	if not state or state == STATES.UNKNOWN then
		reactor = peripheral.find("fissionReactorLogicAdapter")
		turbine = peripheral.find("turbineValve")
	end

	if not pcall(update_data) then
		-- Fehler bei Datenbeschaffung
		data = {}
		state = STATES.UNKNOWN
	elseif data.reactor_on == nil then
		-- Reaktor nicht verbunden
		state = STATES.UNKNOWN
	elseif data.turbine_energy == nil then
		-- Turbine nicht verbunden
		state = STATES.UNKNOWN
	elseif not state then
		-- Programm gestartet
		state = data.lever_on and STATES.RUNNING or STATES.READY
	elseif state == STATES.READY and data.lever_on then
		-- READY -> RUNNING
		state = STATES.RUNNING
		-- Activate reactor
		pcall(reactor.activate)
		data.reactor_on = true
	elseif state == STATES.RUNNING and not data.lever_on then
		-- BETRIEB -> BEREIT
		state = STATES.READY
	elseif state == STATES.ESTOP and not data.lever_on then
		-- RESA -> BEREIT
		state = STATES.READY
	elseif state == STATES.UNKNOWN then
		-- UNBEKANNT -> RESA
		state = data.lever_on and STATES.ESTOP or STATES.READY
		estop_reasons = {}
	end

	-- RESA wenn Sicherheit aktiv
	if state ~= STATES.UNKNOWN and not all_rules_met() then
		state = STATES.ESTOP
	end

	-- SCRAM Reaktor wenn Inaktiv
	if state ~= STATES.RUNNING and reactor then
		pcall(reactor.scram)
	end

	-- Info Neuladen
	pcall(update_info)
	pcall(update_rules)

	sleep()
	return main_loop()
end

term.setPaletteColor(colors.black, 0x000000)
term.setPaletteColor(colors.gray, 0x343434)
term.setPaletteColor(colors.lightGray, 0xababab)
term.setPaletteColor(colors.red, 0xdb2d20)
term.setPaletteColor(colors.green, 0x01a252)
term.setPaletteColor(colors.blue, 0x01a0e4)

term.clear()
local width = term.getSize()
info_window = make_section("INFORMATIONEN", 2, 2, width - 2, 7)
rules_window = make_section("SICHERHEIT", 2, 10, width - 2, 9)

parallel.waitForAny(main_loop, function()
	os.pullEventRaw("BEENDET")
end)

os.reboot()