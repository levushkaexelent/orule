script_name('Orule -  ')
script_author('Lev Exelent (vk.com/e11evated)')
script_version('1.1')

require('lib.moonloader')
local imgui = require('mimgui')
local encoding = require('encoding')
local ffi = require('ffi')
local bit = require('bit')
require('lib.sampfuncs')
local wm = require('lib.windows.message')

encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- ============================================================
--  
-- ============================================================
local SCRIPT_VERSION = "1.1"

local enable_autoupdate = true
local autoupdate_loaded = false
local Update = nil

if enable_autoupdate then
    local updater_loaded, Updater = pcall(loadstring, [[
        return {
            check = function(a, b, c)
                local d = require('moonloader').download_status
                local e = os.tmpname()
                local f = os.clock()
                
                if doesFileExist(e) then os.remove(e) end
                
                downloadUrlToFile(a, e, function(g, h, i, j)
                    if h == d.STATUSEX_ENDDOWNLOAD then
                        if doesFileExist(e) then
                            local k = io.open(e, 'r')
                            if k then
                                local l = decodeJson(k:read('*a'))
                                updatelink = l.updateurl
                                updateversion = l.latest
                                k:close()
                                os.remove(e)
                                
                                if updateversion ~= thisScript().version then
                                    lua_thread.create(function(b)
                                        local d = require('moonloader').download_status
                                        local m = -1
                                        sampAddChatMessage(b..'Обнаружено обновление. Пытаюсь обновиться c '..thisScript().version..' на '..updateversion, m)
                                        wait(250)
                                        
                                        downloadUrlToFile(updatelink, thisScript().path, function(n, o, p, q)
                                            if o == d.STATUS_DOWNLOADINGDATA then
                                                print(string.format('Загружено %d из %d.', p, q))
                                            elseif o == d.STATUS_ENDDOWNLOADDATA then
                                                print('Загрузка обновления завершена.')
                                                
                                                -- Конвертация UTF-8 ? CP1251
                                                lua_thread.create(function()
                                                    wait(100)
                                                    local file = io.open(thisScript().path, 'rb')
                                                    if file then
                                                        local content = file:read('*a')
                                                        file:close()
                                                        
                                                        -- Проверяем BOM UTF-8
                                                        local is_utf8 = false
                                                        if content:sub(1, 3) == '\xEF\xBB\xBF' then
                                                            content = content:sub(4)
                                                            is_utf8 = true
                                                        elseif content:find('[\xC0-\xDF][\x80-\xBF]') or content:find('[\xE0-\xEF][\x80-\xBF][\x80-\xBF]') then
                                                            is_utf8 = true
                                                        end
                                                        
                                                        -- Конвертация только если это UTF-8
                                                        if is_utf8 then
                                                            local encoding = require('encoding')
                                                            encoding.default = 'CP1251'
                                                            
                                                            local success, converted = pcall(encoding.UTF8.decode, encoding.UTF8, content)
                                                            if success and converted then
                                                                local out = io.open(thisScript().path, 'wb')
                                                                if out then
                                                                    out:write(converted)
                                                                    out:close()
                                                                    print('Конвертация UTF-8 -> CP1251 завершена')
                                                                end
                                                            else
                                                                print('Ошибка конвертации, оставляем как есть')
                                                            end
                                                        else
                                                            print('Файл уже в CP1251, конвертация не требуется')
                                                        end
                                                        
                                                        sampAddChatMessage(b..'Обновление завершено!', m)
                                                        goupdatestatus = true
                                                        wait(500)
                                                        thisScript():reload()
                                                    end
                                                end)
                                            end
                                            
                                            if o == d.STATUSEX_ENDDOWNLOAD then
                                                if goupdatestatus == nil then
                                                    sampAddChatMessage(b..'Обновление прошло неудачно. Запускаю устаревшую версию..', m)
                                                    update = false
                                                end
                                            end
                                        end)
                                    end, b)
                                else
                                    update = false
                                    print('v'..thisScript().version..': Обновление не требуется.')
                                end
                            end
                        else
                            print('v'..thisScript().version..': Не могу проверить обновление. Смиритесь или проверьте самостоятельно на '..c)
                            update = false
                        end
                    end
                end)
                
                while update ~= false and os.clock() - f < 10 do
                    wait(100)
                end
                
                if os.clock() - f >= 10 then
                    print('v'..thisScript().version..': timeout, выходим из ожидания проверки обновления. Смиритесь или проверьте самостоятельно на '..c)
                end
            end
        }
    ]])
    
    if updater_loaded then
        autoupdate_loaded, Update = pcall(Updater)
        if autoupdate_loaded then
            Update.json_url = "https://raw.githubusercontent.com/levushkaexelent/orule/main/version.json?" .. tostring(os.clock())
            Update.prefix = "[ORULE]: "
            Update.url = "https://github.com/levushkaexelent/orule"
        end
    end
end

-- ============================================================
--  CP1251
-- ============================================================
local function utf8_lower(str)
    local cp1251_upper = ""
    local cp1251_lower = ""
    
    local result = str
    for i = 1, #cp1251_upper do
        local upper_char = cp1251_upper:sub(i, i)
        local lower_char = cp1251_lower:sub(i, i)
        result = result:gsub(upper_char, lower_char)
    end
    
    return result:lower()
end

-- ============================================================
--   
-- ============================================================
local search_synonyms = {
    [""] = {"", "", ""},
    [""] = {"", "", ""},
    [""] = {"", "", ""},
    [""] = {"", "", ""},
    [""] = {"", "", ""},
    [""] = {"", "", ""},
    [""] = {"", "", ""},
    [" "] = {"", " ", " "},
    [""] = {"", "", "", ""},
    [""] = {"", "", "", ""}
}

-- ============================================================
--   
-- ============================================================
local SCRIPT_DIR = getWorkingDirectory() .. '\\OverlayRules'
local CONFIG_FILE = SCRIPT_DIR .. '\\config.txt'
local FONTS_DIR = SCRIPT_DIR .. '\\fonts'
local IMAGES_DIR = SCRIPT_DIR .. '\\images'
local TEXTS_DIR = SCRIPT_DIR .. '\\texts'

-- ============================================================
-- 
-- ============================================================
local rulesDB = {}
local text_cache = {}

local config = {
    command = "orule",
    globalHotkey = 0,
    overlayBgAlpha = 0.85,
    fontSize = 18.0,
    lineSpacing = 0.1,
    windowWidth = 820,
    windowHeight = 1200,
    ruleCardHeight = 183,
    firstLaunch = true
}

local show_window = imgui.new.bool(false)
local show_info_window = imgui.new.bool(false)
local info_window_shown_once = false
local main_font, title_font = nil, nil
local overlay_visible = false
local overlay_rule_index = nil
local last_window_width = 0
local last_window_height = 0
local commandBuf = imgui.new.char[32]()
local radar_map_texture = nil
local territory_textures = {}
local first_render_done = false
local preload_complete = false
local key_capture_mode = nil
local key_capture_type = nil
local texture_cache = {}

local radialMenu = {
    active = false,
    pendingActivation = false,
    releasePending = false,
    isHeld = false,
    center = imgui.ImVec2(0, 0),
    selected = nil,
    radius = 120,
    deadzone = 28,
    buttons = {
        {name = "", enabled = true},
        {name = "", enabled = true},
        {name = "", enabled = true},
        {name = "", enabled = true},
        {name = "", enabled = true},
        {name = "", enabled = true}
    },
    action = nil,
    globalEnabled = true
}

local radialButtonBuffers = {}
for i = 1, 6 do
    radialButtonBuffers[i] = imgui.new.char[64]()
end

local search_buffer = imgui.new.char[256]()
local policeRuleActiveTab = imgui.new.int(0)
local legalBaseActiveTab = imgui.new.int(0)
local territoryActiveTab = imgui.new.int(0)

-- ============================================================
--   
-- ============================================================
local function executeRadialAction(index)
    if not index then return end

    if index == 1 then
        lua_thread.create(function()
            if not (isSampLoaded() and isSampAvailable()) then return end
            sampSendChat('/m [] -  , ,      !')
            wait(1500)
            sampSendChat('/m [] -      !')
        end)
    elseif index == 2 then
        lua_thread.create(function()
            if not (isSampLoaded() and isSampAvailable()) then return end
            sampSendChat('    ...')
            wait(1300)
            sampSendChat('...    , . .')
            wait(1300)
            sampSendChat("  .")
            wait(1300)
            sampSendChat('      л.')
            wait(1000)
            local hour = os.date('%H')
            local min = os.date('%M')
            local sec = os.date('%S')
            sampSendChat(string.format('/do  .  : %s:%s:%s.', hour, min, sec))
            wait(1000)
            sampSendChat('  .')
            wait(1300)
            sampSendChat('    .')
            wait(1300)
            sampSendChat('     ,   .')
            wait(1300)
            sampSendChat('           .')
            wait(1300)
            sampSendChat('     .')
            wait(1500)
            sampSendChat('     ,      .')
            wait(1500)
            sampSendChat('      .')
            wait(1500)
            sampSendChat('   ?')
        end)
    elseif index == 3 then
        lua_thread.create(function()
            if not (isSampLoaded() and isSampAvailable()) then return end
            sampSendChat('        .')
            wait(1500)
            sampSendChat('     л.')
            wait(1500)
            local hour = os.date('%H')
            local min = os.date('%M')
            sampSendChat(string.format('    : %s:%s.', hour, min))
            wait(1500)
            sampSendChat('/me   ,   ,   ')
            wait(1500)
            lua_thread.create(function()
                if not (isSampLoaded() and isSampAvailable()) then return end
                if not sampIsChatInputActive() and not sampIsDialogActive() and not isSampfuncsConsoleActive() then
                    sampSetChatInputEnabled(true)
                end
                wait(50)
                local old_buf = getClipboardText()
                setClipboardText('/frisk ')
                setVirtualKeyDown(17, true)
                setVirtualKeyDown(86, true)
                wait(10)
                setVirtualKeyDown(86, false)
                setVirtualKeyDown(17, false)
                wait(10)
                setClipboardText(old_buf)
            end)
        end)
    elseif index == 4 then
        lua_thread.create(function()
            if not (isSampLoaded() and isSampAvailable()) then return end
            sampSendChat('/me        ')
            wait(1000)
            sampSendChat('/me  ,           ')
            wait(1000)
            lua_thread.create(function()
                if not (isSampLoaded() and isSampAvailable()) then return end
                if not sampIsChatInputActive() and not sampIsDialogActive() and not isSampfuncsConsoleActive() then
                    sampSetChatInputEnabled(true)
                end
                wait(50)
                local old_buf = getClipboardText()
                setClipboardText('/doc ')
                setVirtualKeyDown(17, true)
                setVirtualKeyDown(86, true)
                wait(10)
                setVirtualKeyDown(86, false)
                setVirtualKeyDown(17, false)
                wait(10)
                setClipboardText(old_buf)
            end)
        end)
    elseif index == 5 then
        lua_thread.create(function()
            if not (isSampLoaded() and isSampAvailable()) then return end
            sampSendChat('/me    ,     ')
            wait(1500)
            sampSendChat('/do   .')
            wait(1500)
            sampSendChat('/me   ,      ')
            wait(1500)
            sampSendChat('/do  .')
        end)
    elseif index == 6 then
        lua_thread.create(function()
            if not (isSampLoaded() and isSampAvailable()) then return end
            sampSendChat('   .')
            wait(1500)
            sampSendChat('/me    ,   ')
            wait(1500)
            sampSendChat('/do  .')
            wait(1500)
            sampSendChat('/me      ,    ')
            wait(1500)
            sampSendChat('/do     70 .')
        end)
    end
end

-- ============================================================
--  
-- ============================================================
local VK_NAMES = {
    [0x01] = "  ", [0x02] = "  ", [0x04] = "  ",
    [0x05] = "   1 ()", [0x06] = "   2 ()",
    [0x08] = "BACKSPACE", [0x09] = "TAB", [0x0D] = "ENTER", [0x10] = "SHIFT", [0x11] = "CTRL", [0x12] = "ALT",
    [0x13] = "PAUSE", [0x14] = "CAPS LOCK", [0x1B] = "ESCAPE", [0x20] = "SPACE",
    [0x21] = "PAGE UP", [0x22] = "PAGE DOWN", [0x23] = "END", [0x24] = "HOME",
    [0x25] = " ", [0x26] = " ", [0x27] = " ", [0x28] = " ",
    [0x2D] = "INSERT", [0x2E] = "DELETE",
    [0x30] = "0", [0x31] = "1", [0x32] = "2", [0x33] = "3", [0x34] = "4",
    [0x35] = "5", [0x36] = "6", [0x37] = "7", [0x38] = "8", [0x39] = "9",
    [0x41] = "A", [0x42] = "B", [0x43] = "C", [0x44] = "D", [0x45] = "E",
    [0x46] = "F", [0x47] = "G", [0x48] = "H", [0x49] = "I", [0x4A] = "J",
    [0x4B] = "K", [0x4C] = "L", [0x4D] = "M", [0x4E] = "N", [0x4F] = "O",
    [0x50] = "P", [0x51] = "Q", [0x52] = "R", [0x53] = "S", [0x54] = "T",
    [0x55] = "U", [0x56] = "V", [0x57] = "W", [0x58] = "X", [0x59] = "Y", [0x5A] = "Z",
    [0x60] = "NUM 0", [0x61] = "NUM 1", [0x62] = "NUM 2", [0x63] = "NUM 3", [0x64] = "NUM 4",
    [0x65] = "NUM 5", [0x66] = "NUM 6", [0x67] = "NUM 7", [0x68] = "NUM 8", [0x69] = "NUM 9",
    [0x6A] = "NUM *", [0x6B] = "NUM +", [0x6D] = "NUM -", [0x6E] = "NUM .", [0x6F] = "NUM /",
    [0x70] = "F1", [0x71] = "F2", [0x72] = "F3", [0x73] = "F4", [0x74] = "F5", [0x75] = "F6",
    [0x76] = "F7", [0x77] = "F8", [0x78] = "F9", [0x79] = "F10", [0x7A] = "F11", [0x7B] = "F12",
    [0x90] = "NUM LOCK", [0x91] = "SCROLL LOCK",
    [0xA0] = "L-SHIFT", [0xA1] = "R-SHIFT",
    [0xA2] = "L-CTRL", [0xA3] = "R-CTRL",
    [0xA4] = "L-ALT", [0xA5] = "R-ALT",
    [0xBA] = ";", [0xBB] = "=", [0xBC] = ",", [0xBD] = "-", [0xBE] = ".", [0xBF] = "/",
    [0xC0] = "`", [0xDB] = "[", [0xDC] = "\\", [0xDD] = "]", [0xDE] = "'"
}

local function getKeyName(vk_code)
    if vk_code == 0 or not vk_code then return "  " end
    return VK_NAMES[vk_code] or ("VK:"..tostring(vk_code))
end

local function isKeyAlreadyUsed(vk_code, exclude_rule_index)
    if vk_code == 0 or not vk_code then return false end
    if config.globalHotkey == vk_code then return true end
    for i, rule in ipairs(rulesDB) do
        if i ~= exclude_rule_index and rule.key == vk_code then return true end
    end
    return false
end

-- ============================================================
--  
-- ============================================================
local function renderFormattedText(text)
    local default_color_vec = imgui.ImVec4(1.0, 1.0, 1.0, 1.0)
    local line_height = imgui.GetTextLineHeight()
    local space_width = imgui.CalcTextSize(' ').x
    local window_pos = imgui.GetCursorScreenPos()
    local line_width = imgui.GetWindowContentRegionMax().x - imgui.GetStyle().WindowPadding.x
    local current_pos = imgui.ImVec2(window_pos.x, window_pos.y)
    local line_spacing = (config.lineSpacing or 0.1) * line_height

    local lines = {}
    for line in text:gmatch("[^\r\n]*") do table.insert(lines, line) end

    for i, line in ipairs(lines) do
        if #line == 0 then
            current_pos.y = current_pos.y + line_height * 0.3
            goto continue
        end

        current_pos.x = window_pos.x
        local segments = {}
        local current_color = default_color_vec
        local last_pos = 1
        
        while true do
            local s, e, _, hex = line:find("({(%x%x%x%x%x%x)})", last_pos)
            if not s then
                local remaining_text = line:sub(last_pos)
                if #remaining_text > 0 then table.insert(segments, {text = remaining_text, color = current_color}) end
                break
            end
            
            local pretext = line:sub(last_pos, s - 1)
            if #pretext > 0 then table.insert(segments, {text = pretext, color = current_color}) end

            local r = tonumber(hex:sub(1, 2), 16) / 255.0
            local g = tonumber(hex:sub(3, 4), 16) / 255.0
            local b = tonumber(hex:sub(5, 6), 16) / 255.0
            current_color = imgui.ImVec4(r, g, b, 1.0)
            last_pos = e + 1
        end

        for _, segment in ipairs(segments) do
            local words = {}
            for word in segment.text:gmatch("%S+") do table.insert(words, word) end
            
            for _, word in ipairs(words) do
                local word_u8 = u8(word)
                local word_width = imgui.CalcTextSize(word_u8).x
                
                if current_pos.x > window_pos.x and current_pos.x + word_width > window_pos.x + line_width then
                    current_pos.x = window_pos.x
                    current_pos.y = current_pos.y + line_height
                end
                
                imgui.SetCursorScreenPos(current_pos)
                imgui.TextColored(segment.color, word_u8)
                current_pos.x = current_pos.x + word_width + space_width
            end
        end
        
        if i < #lines then
            current_pos.y = current_pos.y + line_height + line_spacing
        end

        ::continue::
    end
    imgui.SetCursorScreenPos(imgui.ImVec2(window_pos.x, current_pos.y))
end

-- ============================================================
-- 
-- ============================================================
local function saveConfig()
    local file = io.open(CONFIG_FILE, "w")
    if not file then return end
    
    file:write("config_version:1\n")
    file:write("command:" .. (config.command or "orule") .. "\n")
    file:write("globalHotkey:" .. tostring(config.globalHotkey or 0) .. "\n")
    file:write("overlayBgAlpha:" .. tostring(config.overlayBgAlpha or 0.85) .. "\n")
    file:write("fontSize:" .. tostring(config.fontSize or 18.0) .. "\n")
    file:write("lineSpacing:" .. tostring(config.lineSpacing or 0.1) .. "\n")
    file:write("windowWidth:" .. tostring(config.windowWidth or 820) .. "\n")
    file:write("windowHeight:" .. tostring(config.windowHeight or 1200) .. "\n")
    file:write("ruleCardHeight:" .. tostring(config.ruleCardHeight or 183) .. "\n")
    file:write("firstLaunch:" .. tostring(config.firstLaunch and "1" or "0") .. "\n")
    file:write("radialMenuEnabled:" .. tostring(radialMenu.globalEnabled and "1" or "0") .. "\n")
    for i, btn in ipairs(radialMenu.buttons) do
        file:write("radialButton_" .. i .. "_name:" .. (btn.name or "") .. "\n")
        file:write("radialButton_" .. i .. "_enabled:" .. tostring(btn.enabled and "1" or "0") .. "\n")
    end
    
    for i, rule in ipairs(rulesDB) do
        file:write("rule_" .. i .. "_key:" .. tostring(rule.key or 0) .. "\n")
        file:write("rule_" .. i .. "_holdMode:" .. tostring(rule.holdMode and "1" or "0") .. "\n")
    end
    
    file:close()
end

local function ensureDirectories()
    if not doesDirectoryExist(SCRIPT_DIR) then createDirectory(SCRIPT_DIR) end
    if not doesDirectoryExist(FONTS_DIR) then createDirectory(FONTS_DIR) end
    if not doesDirectoryExist(IMAGES_DIR) then createDirectory(IMAGES_DIR) end
    if not doesDirectoryExist(TEXTS_DIR) then createDirectory(TEXTS_DIR) end
end

local function clearTextCache()
    text_cache = {}
end

local function loadTextFromFile(filename)
    if text_cache[filename] then return text_cache[filename] end
    
    local filepath = TEXTS_DIR .. '\\' .. filename
    
    if not doesFileExist(filepath) then
        return "{FF0000}:   .\n{FFFFFF}   " .. filename .. "   texts/"
    end
    
    local file = io.open(filepath, 'rb')
    if not file then
        return "{FF0000}:     " .. filename
    end
    
    local content = file:read('*a')
    file:close()
    
    if content:sub(1, 3) == '\xEF\xBB\xBF' then
        content = content:sub(4)
        content = encoding.UTF8:decode(content)
    else
        local is_utf8 = content:find('[\xD0-\xD1][\x80-\xBF]')
        if is_utf8 then
            local success, decoded = pcall(encoding.UTF8.decode, encoding.UTF8, content)
            if success then content = decoded end
        end
    end
    
    text_cache[filename] = content
    return content
end

-- ============================================================
-- 
-- ============================================================
local function searchInText(text, query)
    if not query or #query == 0 then return {}, {} end
    
    query = query:gsub("^%s*(.-)%s*$", "%1")
    if #query == 0 then return {}, {} end
    
    local query_text = ffi.string(query)
    local query_cp1251 = encoding.UTF8:decode(query_text)
    query_cp1251 = utf8_lower(query_cp1251)
    
    local exclude_words = {}
    local search_query = query_cp1251
    
    for word in query_cp1251:gmatch("%-(%S+)") do
        exclude_words[word] = true
        search_query = search_query:gsub("%-%S+", "")
    end
    
    search_query = search_query:gsub("^%s*(.-)%s*$", "%1")
    if #search_query == 0 then return {}, {} end
    
    local results = {}
    local lines = {}
    
    for line in text:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    
    local search_variants = {}
    table.insert(search_variants, {pattern = search_query, boost = 5000, type = "exact"})
    
    for original, synonyms in pairs(search_synonyms) do
        if search_query:find(original, 1, true) then
            for _, synonym in ipairs(synonyms) do
                table.insert(search_variants, {pattern = synonym, boost = 4000, type = "synonym"})
            end
        end
    end
    
    local words = {}
    for word in search_query:gmatch("%S+") do
        table.insert(words, word)
    end
    
    local query_no_special = search_query:gsub("[%-_%.,;:!?%(%)%[%]%{%}]", "")
    if query_no_special ~= search_query and #query_no_special > 0 then
        table.insert(search_variants, {pattern = query_no_special, boost = 3000, type = "no_special"})
    end
    
    for line_num, line in ipairs(lines) do
        local clean_line = line:gsub("{%x%x%x%x%x%x}", "")
        local lower_line = utf8_lower(clean_line)
        
        local has_excluded = false
        for exclude_word, _ in pairs(exclude_words) do
            if lower_line:find(exclude_word, 1, true) then
                has_excluded = true
                break
            end
        end
        
        if not has_excluded then
            local max_relevance = 0
            local best_match = nil
            
            for _, variant in ipairs(search_variants) do
                local pos = lower_line:find(variant.pattern, 1, true)
                if pos then
                    local relevance = variant.boost
                    relevance = relevance + (1000 - pos)
                    relevance = relevance + math.max(0, 500 - #clean_line)
                    
                    if pos == 1 or lower_line:sub(pos - 1, pos - 1):match("%s") then
                        relevance = relevance + 1000
                    end
                    
                    local word_end = pos + #variant.pattern
                    if (pos == 1 or lower_line:sub(pos - 1, pos - 1):match("[%s%p]")) and
                       (word_end > #lower_line or lower_line:sub(word_end, word_end):match("[%s%p]")) then
                        relevance = relevance + 2000
                    end
                    
                    if relevance > max_relevance then
                        max_relevance = relevance
                        best_match = {variant = variant.type, position = pos}
                    end
                end
            end
            
            if max_relevance == 0 and #words > 1 then
                local words_found = 0
                local total_positions = 0
                
                for _, word in ipairs(words) do
                    local pos = lower_line:find(word, 1, true)
                    if pos then
                        words_found = words_found + 1
                        total_positions = total_positions + pos
                    end
                end
                
                if words_found > 0 then
                    local relevance = (words_found / #words) * 2000
                    relevance = relevance + (1000 - (total_positions / words_found))
                    relevance = relevance + math.max(0, 500 - #clean_line)
                    
                    if relevance > max_relevance then
                        max_relevance = relevance
                        best_match = {variant = "partial_words", position = total_positions / words_found}
                    end
                end
            end
            
            if max_relevance > 0 and best_match then
                table.insert(results, {
                    line_num = line_num,
                    line = line,
                    clean_line = clean_line,
                    relevance = max_relevance,
                    position = best_match.position,
                    match_type = best_match.variant
                })
            end
        end
    end
    
    table.sort(results, function(a, b) return a.relevance > b.relevance end)
    return results, lines
end

local function renderSearchResults(full_text, query)
    if not query or #query == 0 then
        imgui.PushTextWrapPos(0)
        renderFormattedText(full_text)
        imgui.PopTextWrapPos()
        return
    end
    
    local results, all_lines = searchInText(full_text, query)
    
    if #results == 0 then
        imgui.TextColored(imgui.ImVec4(1.0, 0.5, 0.5, 1.0), u8'  ')
        imgui.Spacing()
        imgui.TextColored(imgui.ImVec4(0.7, 0.7, 0.75, 1.0), u8':')
        imgui.BulletText(u8'    ')
        imgui.BulletText(u8'  ')
        imgui.BulletText(u8'   ')
        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()
        imgui.PushTextWrapPos(0)
        renderFormattedText(full_text)
        imgui.PopTextWrapPos()
        return
    end
    
    imgui.TextColored(imgui.ImVec4(0.5, 1.0, 0.5, 1.0), u8(string.format(': %d', #results)))
    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()
    
    local shown_lines = {}
    local context_size = 2
    
    for i, result in ipairs(results) do
        if i > 15 then break end
        
        local start_line = math.max(1, result.line_num - context_size)
        local end_line = math.min(#all_lines, result.line_num + context_size)
        
        local already_shown = false
        for shown_start, shown_end in pairs(shown_lines) do
            if not (end_line < shown_start or start_line > shown_end) then
                already_shown = true
                break
            end
        end
        
        if not already_shown then
            shown_lines[start_line] = end_line
            
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.7, 0.85, 1.0, 1.0))
            imgui.Text(u8(string.format(' #%d', i)))
            imgui.PopStyleColor()
            imgui.Spacing()
            
            local context_text = ""
            for line_idx = start_line, end_line do
                if line_idx == result.line_num then
                    context_text = context_text .. "{00FF00}> " .. all_lines[line_idx] .. "{FFFFFF}\n"
                else
                    context_text = context_text .. "  " .. all_lines[line_idx] .. "\n"
                end
            end
            
            imgui.PushTextWrapPos(0)
            renderFormattedText(context_text)
            imgui.PopTextWrapPos()
            
            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()
        end
    end
end

local function loadConfig()
    ensureDirectories()
    
    local file = io.open(CONFIG_FILE, "r")
    if not file then return end

    for line in file:lines() do
        local cmd = line:match("^command:(.+)")
        if cmd then config.command = cmd end

        local ghk = line:match("^globalHotkey:(.+)")
        if ghk then config.globalHotkey = tonumber(ghk) or 0 end

        local alpha = line:match("^overlayBgAlpha:(.+)")
        if alpha then config.overlayBgAlpha = tonumber(alpha) or 0.85 end

        local fsize = line:match("^fontSize:(.+)")
        if fsize then config.fontSize = tonumber(fsize) or 18.0 end

        local lspace = line:match("^lineSpacing:(.+)")
        if lspace then config.lineSpacing = tonumber(lspace) or 0.1 end

        local wwidth = line:match("^windowWidth:(.+)")
        if wwidth then config.windowWidth = tonumber(wwidth) or 820 end

        local wheight = line:match("^windowHeight:(.+)")
        if wheight then config.windowHeight = tonumber(wheight) or 1200 end

        local rcheight = line:match("^ruleCardHeight:(.+)")
        if rcheight then config.ruleCardHeight = 183 end
        
        local first_launch = line:match("^firstLaunch:(.+)")
        if first_launch then
            config.firstLaunch = (first_launch == "1")
        end
        
        local radial_enabled = line:match("^radialMenuEnabled:(.+)")
        if radial_enabled then
            radialMenu.globalEnabled = (radial_enabled == "1")
        end

        local btn_idx, btn_name = line:match("^radialButton_(%d+)_name:(.+)")
        if btn_idx and radialMenu.buttons[tonumber(btn_idx)] then
            radialMenu.buttons[tonumber(btn_idx)].name = btn_name
        end

        local btn_idx_enabled, btn_enabled = line:match("^radialButton_(%d+)_enabled:(.+)")
        if btn_idx_enabled and radialMenu.buttons[tonumber(btn_idx_enabled)] then
            radialMenu.buttons[tonumber(btn_idx_enabled)].enabled = (btn_enabled == "1")
        end
        
        local r_idx, r_key = line:match("^rule_(%d+)_key:(.+)")
        if r_idx and rulesDB[tonumber(r_idx)] then
            local key_val = tonumber(r_key) or 0
            rulesDB[tonumber(r_idx)].key = key_val
            rulesDB[tonumber(r_idx)].keyName = getKeyName(key_val)
        end

        local h_idx, h_mode = line:match("^rule_(%d+)_holdMode:(.+)")
        if h_idx and rulesDB[tonumber(h_idx)] then
            rulesDB[tonumber(h_idx)].holdMode = (h_mode == "1")
        end
    end
    file:close()
    
    if config.command then
        ffi.fill(commandBuf, 32, 0)
        ffi.copy(commandBuf, config.command, math.min(#config.command, 31))
    end
    
    config.ruleCardHeight = 183
    saveConfig()
end

local function initRadialBuffers()
    for i, btn in ipairs(radialMenu.buttons) do
        local name = btn.name or (" " .. i)
        ffi.fill(radialButtonBuffers[i], 64, 0)
        
        --     (    CP1251)
        if #name > 0 then
            ffi.copy(radialButtonBuffers[i], name, math.min(#name, 63))
        end
    end
end

-- ============================================================
-- 
-- ============================================================
local function getPoliceRuleText(tabIndex)
    local files = {"police_main.txt", "police_radar.txt", "police_mask.txt", "police_tint.txt"}
    return loadTextFromFile(files[math.max(1, math.min(tabIndex + 1, 4))])
end

local function getLegalBaseText(tabIndex)
    local files = {"legal_constitution.txt", "legal_federal.txt", "legal_uk.txt", "legal_koap.txt", "legal_police_law.txt", "legal_fsb_law.txt"}
    return loadTextFromFile(files[math.max(1, math.min(tabIndex + 1, 6))])
end

local function getTerritoryText(tabIndex)
    local files = {"territory_main.txt", "territory_mvd.txt", "territory_fsb.txt", "territory_army.txt", "territory_fsin.txt", "territory_mchs.txt", "territory_hospital.txt", "territory_smi.txt", "territory_government.txt"}
    return loadTextFromFile(files[math.max(1, math.min(tabIndex + 1, 9))])
end

local function getTerritoryArmySupplementText() return loadTextFromFile("territory_army_supplement.txt") end
local function getTerritoryFsinSupplementText() return loadTextFromFile("territory_fsin_supplement.txt") end
local function getHierarchyText() return loadTextFromFile("hierarchy.txt") end
local function getUPKText() return loadTextFromFile("upk.txt") end
local function getLaborCodeText() return loadTextFromFile("labor_code.txt") end
local function getMVDHandbookText() return loadTextFromFile("mvd_handbook.txt") end
local function getMVDDrillRegulationsText() return loadTextFromFile("mvd_drill.txt") end
local function getMVDStatuteText() return loadTextFromFile("mvd_statute.txt") end

local function initStaticRules()
    rulesDB = {
        {name = "  ", updateDate = "08.11.2025", key = 0, keyName = "  ", holdMode = false},
        {name = " ", updateDate = "08.11.2025", key = 0, keyName = "  ", holdMode = false},
        {name = " \"    \"", updateDate = "08.11.2025", key = 0, keyName = "  ", holdMode = false},
        {name = " \"  -   \"", updateDate = "08.11.2025", key = 0, keyName = "  ", holdMode = false},
        {name = "- ", updateDate = "08.11.2025", key = 0, keyName = "  ", holdMode = false},
        {name = " ", updateDate = "08.11.2025", key = 0, keyName = "  ", holdMode = false},
        {name = "   |  ", updateDate = "08.11.2025", key = 0, keyName = "  ", holdMode = false},
        {name = "   |   ", updateDate = "08.11.2025", key = 0, keyName = "  ", holdMode = false},
        {name = "   | ", updateDate = "08.11.2025", key = 0, keyName = "  ", holdMode = false}
    }
end

local function loadAllRules()
    clearTextCache()
    initStaticRules()
    loadConfig()
    initRadialBuffers()
end

-- ============================================================
-- 
-- ============================================================
local function ApplyCustomTheme()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local icol = imgui.Col
    local ImVec4 = imgui.ImVec4
    local ImVec2 = imgui.ImVec2
    
    style.WindowRounding = 12.0
    style.ChildRounding = 10.0
    style.FrameRounding = 6.0
    style.PopupRounding = 8.0
    style.ScrollbarRounding = 10.0
    style.GrabRounding = 6.0
    style.TabRounding = 8.0
    
    style.WindowPadding = ImVec2(18, 18)
    style.FramePadding = ImVec2(12, 8)
    style.ItemSpacing = ImVec2(10, 8)
    style.ItemInnerSpacing = ImVec2(8, 6)
    style.IndentSpacing = 22.0
    style.ScrollbarSize = 16.0
    style.GrabMinSize = 14.0
    
    style.WindowBorderSize = 1.0
    style.ChildBorderSize = 1.0
    style.PopupBorderSize = 1.0
    style.FrameBorderSize = 0.0
    style.TabBorderSize = 0.0
    
    style.WindowTitleAlign = ImVec2(0.5, 0.5)
    style.ButtonTextAlign = ImVec2(0.5, 0.5)
    
    local bg_dark = ImVec4(0.08, 0.08, 0.10, 0.98)
    local bg_medium = ImVec4(0.11, 0.11, 0.13, 1.00)
    local bg_light = ImVec4(0.15, 0.15, 0.18, 1.00)
    local bg_lighter = ImVec4(0.20, 0.20, 0.24, 1.00)
    
    local accent = ImVec4(0.50, 0.45, 1.00, 1.00)
    local accent_hover = ImVec4(0.60, 0.55, 1.00, 1.00)
    local accent_active = ImVec4(0.40, 0.35, 0.90, 1.00)
    local accent_dim = ImVec4(0.50, 0.45, 1.00, 0.50)
    
    local text = ImVec4(0.98, 0.98, 1.00, 1.00)
    local text_disabled = ImVec4(0.50, 0.50, 0.55, 1.00)
    
    local border = ImVec4(0.30, 0.30, 0.35, 1.00)
    local border_light = ImVec4(0.40, 0.40, 0.45, 1.00)
    
    colors[icol.Text] = text
    colors[icol.TextDisabled] = text_disabled
    colors[icol.TextSelectedBg] = ImVec4(0.50, 0.45, 1.00, 0.35)
    
    colors[icol.WindowBg] = bg_dark
    colors[icol.ChildBg] = bg_medium
    colors[icol.PopupBg] = bg_dark
    colors[icol.Border] = border
    colors[icol.BorderShadow] = ImVec4(0.00, 0.00, 0.00, 0.50)
    
    colors[icol.FrameBg] = bg_light
    colors[icol.FrameBgHovered] = bg_lighter
    colors[icol.FrameBgActive] = ImVec4(0.22, 0.22, 0.26, 1.00)
    
    colors[icol.TitleBg] = bg_medium
    colors[icol.TitleBgActive] = accent_dim
    colors[icol.TitleBgCollapsed] = bg_medium
    
    colors[icol.MenuBarBg] = bg_medium
    
    colors[icol.ScrollbarBg] = bg_medium
    colors[icol.ScrollbarGrab] = ImVec4(0.35, 0.35, 0.40, 1.00)
    colors[icol.ScrollbarGrabHovered] = ImVec4(0.45, 0.45, 0.50, 1.00)
    colors[icol.ScrollbarGrabActive] = accent
    
    colors[icol.CheckMark] = accent
    colors[icol.SliderGrab] = accent
    colors[icol.SliderGrabActive] = accent_active
    
    colors[icol.Button] = accent
    colors[icol.ButtonHovered] = accent_hover
    colors[icol.ButtonActive] = accent_active
    
    colors[icol.Header] = accent_dim
    colors[icol.HeaderHovered] = ImVec4(0.50, 0.45, 1.00, 0.70)
    colors[icol.HeaderActive] = accent
    
    colors[icol.Separator] = border
    colors[icol.SeparatorHovered] = border_light
    colors[icol.SeparatorActive] = accent
    
    colors[icol.ResizeGrip] = ImVec4(0.35, 0.35, 0.40, 0.50)
    colors[icol.ResizeGripHovered] = accent_dim
    colors[icol.ResizeGripActive] = accent
    
    colors[icol.Tab] = bg_light
    colors[icol.TabHovered] = bg_lighter
    colors[icol.TabActive] = accent
    colors[icol.TabUnfocused] = bg_medium
    colors[icol.TabUnfocusedActive] = ImVec4(0.50, 0.45, 1.00, 0.60)
    
    colors[icol.PlotLines] = accent
    colors[icol.PlotLinesHovered] = accent_hover
    colors[icol.PlotHistogram] = accent
    colors[icol.PlotHistogramHovered] = accent_hover
    
    colors[icol.DragDropTarget] = ImVec4(0.50, 0.45, 1.00, 0.90)
    colors[icol.NavHighlight] = accent
    colors[icol.NavWindowingHighlight] = ImVec4(1.00, 1.00, 1.00, 0.70)
    colors[icol.NavWindowingDimBg] = ImVec4(0.80, 0.80, 0.80, 0.20)
    colors[icol.ModalWindowDimBg] = ImVec4(0.00, 0.00, 0.00, 0.60)
end

imgui.OnInitialize(function()
    ApplyCustomTheme()
    local io = imgui.GetIO()
    local font_path = FONTS_DIR .. '\\EagleSans-Regular.ttf'
    
    if doesFileExist(font_path) then
        local ranges = io.Fonts:GetGlyphRangesCyrillic()
        main_font = io.Fonts:AddFontFromFileTTF(font_path, 17.0, nil, ranges)
        title_font = io.Fonts:AddFontFromFileTTF(font_path, 22.0, nil, ranges)
    end
    
    local radar_map_path = IMAGES_DIR .. '\\radar_map.png'
    if doesFileExist(radar_map_path) then
        radar_map_texture = imgui.CreateTextureFromFile(radar_map_path)
    end

    for i = 1, 20 do
        local ter_path = IMAGES_DIR .. '\\ter_' .. i .. '.jpg'
        if doesFileExist(ter_path) then
            territory_textures[i] = imgui.CreateTextureFromFile(ter_path)
        end
    end
end)

-- ============================================================
-- OVERLAY 
-- ============================================================
imgui.OnFrame(
    function() return overlay_visible end,
    function(this)
        local sw, sh = getScreenResolution()
        
        local bg_color_struct = imgui.ImVec4(0, 0, 0, config.overlayBgAlpha)
        local bg_color_u32 = imgui.ColorConvertFloat4ToU32(bg_color_struct)
        imgui.GetBackgroundDrawList():AddRectFilled(imgui.ImVec2(0, 0), imgui.ImVec2(sw, sh), bg_color_u32)
        
        local rule = rulesDB[overlay_rule_index]
        if rule then
            local wrap_w = sw * 0.95
            local vertical_margin = sh * 0.03
            local content_h = sh - (vertical_margin * 2)
            local content_x = (sw - wrap_w) / 2
            
            imgui.SetNextWindowPos(imgui.ImVec2(content_x, vertical_margin))
            imgui.SetNextWindowSize(imgui.ImVec2(wrap_w, content_h))
            
            imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 10.0)
            imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 2.0)
            imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.50, 0.45, 1.00, 1.00))
            imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0, 0, 0, 0.0))

            local content_flags = bit.bor(imgui.WindowFlags.NoTitleBar, imgui.WindowFlags.NoMove, imgui.WindowFlags.NoResize)
            if imgui.Begin('##content_window', nil, content_flags) then
            
                if title_font then imgui.PushFont(title_font) end
                imgui.SetWindowFontScale(1.3)
                imgui.TextColored(imgui.ImVec4(1.0, 1.0, 1.0, 1.0), u8(rule.name or ''))
                imgui.SetWindowFontScale(1.0)
                if title_font then imgui.PopFont() end
                
                if rule.updateDate then
                    imgui.Spacing()
                    imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.75, 1.0), u8(' : ' .. rule.updateDate))
                end
                
                --    
                if overlay_rule_index == 1 then
                    imgui.Spacing()
                    local avail_width = imgui.GetContentRegionAvail().x
                    local spacing = imgui.GetStyle().ItemSpacing.x
                    local button_width = (avail_width - spacing * 3) / 4
                    
                    local active_color = imgui.ImVec4(0.50, 0.45, 1.00, 1.00)
                    local current_tab = policeRuleActiveTab[0] or 0
                    
                    for i = 0, 3 do
                        if i > 0 then imgui.SameLine() end
                        if current_tab == i then
                            imgui.PushStyleColor(imgui.Col.Button, active_color)
                            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.60, 0.55, 1.00, 1.00))
                            imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.40, 0.35, 0.90, 1.00))
                        end
                        
                        local labels = {u8'  ', u8'  ', u8'  ', u8'  '}
                        if imgui.Button(labels[i+1]..'##police_tab_'..i, imgui.ImVec2(button_width, 30)) then
                            policeRuleActiveTab[0] = i
                        end
                        
                        if current_tab == i then imgui.PopStyleColor(3) end
                    end
                    imgui.Spacing()
                end
                
                --    
                if overlay_rule_index == 2 then
                    imgui.Spacing()
                    local avail_width = imgui.GetContentRegionAvail().x
                    local spacing = imgui.GetStyle().ItemSpacing.x
                    local button_width = (avail_width - spacing * 2) / 3
                    
                    local active_color = imgui.ImVec4(0.50, 0.45, 1.00, 1.00)
                    local current_tab = legalBaseActiveTab[0] or 0
                    
                    local button_texts = {
                        u8'', u8' ', u8' ',
                        u8'', u8'  ', u8'  '
                    }
                    
                    for i = 0, 5 do
                        if i > 0 and i % 3 == 0 then imgui.Spacing() end
                        if i > 0 and i % 3 ~= 0 then imgui.SameLine() end
                        
                        if current_tab == i then
                            imgui.PushStyleColor(imgui.Col.Button, active_color)
                            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.60, 0.55, 1.00, 1.00))
                            imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.40, 0.35, 0.90, 1.00))
                        end
                        
                        if imgui.Button(button_texts[i + 1]..'##legal_tab_'..i, imgui.ImVec2(button_width, 30)) then
                            legalBaseActiveTab[0] = i
                        end
                        
                        if current_tab == i then imgui.PopStyleColor(3) end
                    end
                    imgui.Spacing()
                end
                
                --   
                if overlay_rule_index == 3 then
                    imgui.Spacing()
                    local avail_width = imgui.GetContentRegionAvail().x
                    local spacing = imgui.GetStyle().ItemSpacing.x
                    local button_width = (avail_width - spacing * 2) / 3
                    
                    local active_color = imgui.ImVec4(0.50, 0.45, 1.00, 1.00)
                    local current_tab = territoryActiveTab[0] or 0
                    
                    local button_texts = {
                        u8' ', u8'', u8'', u8'', u8'',
                        u8'', u8'', u8'', u8''
                    }
                    
                    for i = 0, 8 do
                        if i > 0 and i % 3 == 0 then imgui.Spacing() end
                        if i > 0 and i % 3 ~= 0 then imgui.SameLine() end
                        
                        if current_tab == i then
                            imgui.PushStyleColor(imgui.Col.Button, active_color)
                            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.60, 0.55, 1.00, 1.00))
                            imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.40, 0.35, 0.90, 1.00))
                        end
                        
                        if imgui.Button(button_texts[i + 1]..'##territory_tab_'..i, imgui.ImVec2(button_width, 30)) then
                            territoryActiveTab[0] = i
                        end
                        
                        if current_tab == i then imgui.PopStyleColor(3) end
                    end
                    imgui.Spacing()
                end
                
                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()

                if main_font then imgui.PushFont(main_font) end
                imgui.SetWindowFontScale(config.fontSize / 17.0)
                
                --  
                local full_text = ''
                if overlay_rule_index == 1 then
                    full_text = getPoliceRuleText(policeRuleActiveTab[0] or 0)
                elseif overlay_rule_index == 2 then
                    full_text = getLegalBaseText(legalBaseActiveTab[0] or 0)
                elseif overlay_rule_index == 3 then
                    local tabIndex = territoryActiveTab[0] or 0
                    full_text = getTerritoryText(tabIndex)
                    if tabIndex == 3 then
                        full_text = full_text .. "\n\n" .. getTerritoryArmySupplementText()
                    elseif tabIndex == 4 then
                        full_text = full_text .. "\n\n" .. getTerritoryFsinSupplementText()
                    end
                elseif overlay_rule_index == 4 then
                    full_text = getHierarchyText()
                elseif overlay_rule_index == 5 then
                    full_text = getUPKText()
                elseif overlay_rule_index == 6 then
                    full_text = getLaborCodeText()
                elseif overlay_rule_index == 7 then
                    full_text = getMVDHandbookText()
                elseif overlay_rule_index == 8 then
                    full_text = getMVDDrillRegulationsText()
                elseif overlay_rule_index == 9 then
                    full_text = getMVDStatuteText()
                end

                if not full_text or #full_text == 0 or full_text:match("^{FF0000}") then
                    full_text = "{FF6B6B}  .\n{FFFFFF}     texts/"
                end
                
                --  
                imgui.PushStyleColor(imgui.Col.FrameBg, imgui.ImVec4(0.15, 0.15, 0.18, 0.95))
                imgui.PushStyleColor(imgui.Col.FrameBgHovered, imgui.ImVec4(0.20, 0.20, 0.24, 0.95))
                imgui.PushStyleColor(imgui.Col.FrameBgActive, imgui.ImVec4(0.25, 0.25, 0.30, 0.95))
                imgui.PushItemWidth(-1)
                imgui.InputTextWithHint('##search_overlay', u8'  ...', search_buffer, 256)
                imgui.PopItemWidth()
                imgui.PopStyleColor(3)

                imgui.Spacing()
                imgui.Spacing()

                if full_text and #full_text > 0 then
                    local query = ffi.string(search_buffer)
                    renderSearchResults(full_text, query)
                end
                
                --   
                if overlay_rule_index == 3 and territoryActiveTab[0] == 1 then
                    imgui.Spacing()
                    imgui.Spacing()
                    if imgui.CollapsingHeader(u8'##territory_mvd_photos') then
                        local window_width = imgui.GetWindowWidth()
                        local spacing = imgui.GetStyle().ItemSpacing.x
                        local padding = imgui.GetStyle().WindowPadding.x * 2
                        local avail_width = window_width - padding
                        local images_per_row = 3
                        local image_width = math.floor((avail_width - spacing * (images_per_row - 1)) / images_per_row)
                        local image_height = math.floor(image_width * 0.57)
                        
                        for i = 1, 6 do
                            if i > 1 and (i - 1) % images_per_row ~= 0 then imgui.SameLine() end
                            if territory_textures[i] then
                                imgui.Image(territory_textures[i], imgui.ImVec2(image_width, image_height))
                            else
                                imgui.TextColored(imgui.ImVec4(1.0, 0.0, 0.0, 1.0), u8(': ter_' .. i .. '.jpg'))
                            end
                            if i % images_per_row == 0 and i < 6 then imgui.Spacing() end
                        end
                    end
                end
                
                --   
                if overlay_rule_index == 3 and territoryActiveTab[0] == 2 then
                    imgui.Spacing()
                    imgui.Spacing()
                    if imgui.CollapsingHeader(u8'##territory_fsb_photos') then
                        if territory_textures[7] then
                            local window_width = imgui.GetWindowWidth()
                            local spacing = imgui.GetStyle().ItemSpacing.x
                            local padding = imgui.GetStyle().WindowPadding.x * 2
                            local avail_width = window_width - padding
                            local images_per_row = 3
                            local image_width = math.floor((avail_width - spacing * (images_per_row - 1)) / images_per_row)
                            local image_height = math.floor(image_width * 0.57)
                            imgui.Image(territory_textures[7], imgui.ImVec2(image_width, image_height))
                        else
                            imgui.TextColored(imgui.ImVec4(1.0, 0.0, 0.0, 1.0), u8':  ter_7.jpg  !')
                        end
                    end
                end
                
                --   
                if overlay_rule_index == 3 and territoryActiveTab[0] == 3 then
                    imgui.Spacing()
                    imgui.Spacing()
                    if imgui.CollapsingHeader(u8'##territory_army_photos') then
                        if territory_textures[8] then
                            local window_width = imgui.GetWindowWidth()
                            local spacing = imgui.GetStyle().ItemSpacing.x
                            local padding = imgui.GetStyle().WindowPadding.x * 2
                            local avail_width = window_width - padding
                            local images_per_row = 3
                            local image_width = math.floor((avail_width - spacing * (images_per_row - 1)) / images_per_row)
                            local image_height = math.floor(image_width * 0.57)
                            imgui.Image(territory_textures[8], imgui.ImVec2(image_width, image_height))
                        else
                            imgui.TextColored(imgui.ImVec4(1.0, 0.0, 0.0, 1.0), u8':  ter_8.jpg  !')
                        end
                    end
                end
                
                --   
                if overlay_rule_index == 3 and territoryActiveTab[0] == 5 then
                    imgui.Spacing()
                    imgui.Spacing()
                    if imgui.CollapsingHeader(u8'##territory_mchs_photos') then
                        local window_width = imgui.GetWindowWidth()
                        local spacing = imgui.GetStyle().ItemSpacing.x
                        local padding = imgui.GetStyle().WindowPadding.x * 2
                        local avail_width = window_width - padding
                        local images_per_row = 3
                        local image_width = math.floor((avail_width - spacing * (images_per_row - 1)) / images_per_row)
                        local image_height = math.floor(image_width * 0.57)
                        
                        for i = 9, 12 do
                            local idx = i - 8
                            if idx > 1 and (idx - 1) % images_per_row ~= 0 then imgui.SameLine() end
                            if territory_textures[i] then
                                imgui.Image(territory_textures[i], imgui.ImVec2(image_width, image_height))
                            else
                                imgui.TextColored(imgui.ImVec4(1.0, 0.0, 0.0, 1.0), u8(': ter_' .. i .. '.jpg'))
                            end
                            if idx % images_per_row == 0 and i < 12 then imgui.Spacing() end
                        end
                    end
                end
                
                --  
                if overlay_rule_index == 3 and territoryActiveTab[0] == 6 then
                    imgui.Spacing()
                    imgui.Spacing()
                    if imgui.CollapsingHeader(u8'##territory_hospital_photos') then
                        local window_width = imgui.GetWindowWidth()
                        local spacing = imgui.GetStyle().ItemSpacing.x
                        local padding = imgui.GetStyle().WindowPadding.x * 2
                        local avail_width = window_width - padding
                        local images_per_row = 3
                        local image_width = math.floor((avail_width - spacing * (images_per_row - 1)) / images_per_row)
                        local image_height = math.floor(image_width * 0.57)
                        
                        for i = 13, 15 do
                            local idx = i - 12
                            if idx > 1 and (idx - 1) % images_per_row ~= 0 then imgui.SameLine() end
                            if territory_textures[i] then
                                imgui.Image(territory_textures[i], imgui.ImVec2(image_width, image_height))
                            else
                                imgui.TextColored(imgui.ImVec4(1.0, 0.0, 0.0, 1.0), u8(': ter_' .. i .. '.jpg'))
                            end
                            if idx % images_per_row == 0 and i < 15 then imgui.Spacing() end
                        end
                    end
                end
                
                --  
                if overlay_rule_index == 3 and territoryActiveTab[0] == 7 then
                    imgui.Spacing()
                    imgui.Spacing()
                    if imgui.CollapsingHeader(u8'##territory_smi_photos') then
                        local window_width = imgui.GetWindowWidth()
                        local spacing = imgui.GetStyle().ItemSpacing.x
                        local padding = imgui.GetStyle().WindowPadding.x * 2
                        local avail_width = window_width - padding
                        local images_per_row = 3
                        local image_width = math.floor((avail_width - spacing * (images_per_row - 1)) / images_per_row)
                        local image_height = math.floor(image_width * 0.57)
                        
                        for i = 16, 17 do
                            local idx = i - 15
                            if idx > 1 and (idx - 1) % images_per_row ~= 0 then imgui.SameLine() end
                            if territory_textures[i] then
                                imgui.Image(territory_textures[i], imgui.ImVec2(image_width, image_height))
                            else
                                imgui.TextColored(imgui.ImVec4(1.0, 0.0, 0.0, 1.0), u8(': ter_' .. i .. '.jpg'))
                            end
                        end
                    end
                end
                
                --  
                if overlay_rule_index == 3 and territoryActiveTab[0] == 8 then
                    imgui.Spacing()
                    imgui.Spacing()
                    if imgui.CollapsingHeader(u8'##territory_government_photos') then
                        local window_width = imgui.GetWindowWidth()
                        local spacing = imgui.GetStyle().ItemSpacing.x
                        local padding = imgui.GetStyle().WindowPadding.x * 2
                        local avail_width = window_width - padding
                        local images_per_row = 3
                        local image_width = math.floor((avail_width - spacing * (images_per_row - 1)) / images_per_row)
                        local image_height = math.floor(image_width * 0.57)
                        
                        for i = 18, 20 do
                            local idx = i - 17
                            if idx > 1 and (idx - 1) % images_per_row ~= 0 then imgui.SameLine() end
                            if territory_textures[i] then
                                imgui.Image(territory_textures[i], imgui.ImVec2(image_width, image_height))
                            else
                                imgui.TextColored(imgui.ImVec4(1.0, 0.0, 0.0, 1.0), u8(': ter_' .. i .. '.jpg'))
                            end
                            if idx % images_per_row == 0 and i < 20 then imgui.Spacing() end
                        end
                    end
                end
                
                --  
                if overlay_rule_index == 1 and policeRuleActiveTab[0] == 1 then
                    imgui.Spacing()
                    imgui.Spacing()
                    if imgui.CollapsingHeader(u8' ##radar_map') then
                        if radar_map_texture then
                            local avail_width = imgui.GetContentRegionAvail().x
                            local image_width = avail_width * 0.95
                            local image_height = image_width * 0.75
                            imgui.Image(radar_map_texture, imgui.ImVec2(image_width, image_height))
                        else
                            imgui.TextColored(imgui.ImVec4(1.0, 0.0, 0.0, 1.0), u8':    !')
                        end
                    end
                end

                imgui.SetWindowFontScale(1.0)
                if main_font then imgui.PopFont() end
            end
            imgui.End()

            imgui.PopStyleColor(2)
            imgui.PopStyleVar(2)
        end
    end
)

-- ============================================================
--  
-- ============================================================
local function renderRulesTab()
    local is_capturing_any = (key_capture_mode ~= nil)
    
    imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8' ')
    imgui.Spacing()
    imgui.Spacing()
    
    for i, rule in ipairs(rulesDB) do
        local is_capturing_this = (key_capture_type == "rule" and key_capture_mode and key_capture_mode.index == i)
        local is_blocked_by_other = (is_capturing_any and not is_capturing_this)

        local card_bg = imgui.ImVec4(0.11, 0.11, 0.13, 1.00)
        local card_border = imgui.ImVec4(0.30, 0.30, 0.35, 0.50)
        if is_capturing_this then
            card_bg = imgui.ImVec4(0.15, 0.12, 0.18, 1.00)
            card_border = imgui.ImVec4(0.90, 0.60, 0.20, 0.80)
        end
        
        imgui.PushStyleColor(imgui.Col.ChildBg, card_bg)
        imgui.PushStyleColor(imgui.Col.Border, card_border)
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 6.0)
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildBorderSize, 1.5)
        
        if imgui.BeginChild('##rule_card_' .. i, imgui.ImVec2(0, config.ruleCardHeight), true) then
            imgui.Spacing()
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.95, 0.95, 1.00, 1.00))
            imgui.Text(u8(rule.name or ' '))
            imgui.PopStyleColor(1)
            
            if rule.updateDate then
                imgui.Spacing()
                imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.75, 0.90), u8' : ')
                imgui.SameLine(0, 5)
                imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 0.70), u8(rule.updateDate))
            end
            
            imgui.Spacing()
            
            local key_name = getKeyName(rule.key)
            local key_color = (rule.key == 0) and imgui.ImVec4(0.60, 0.60, 0.65, 0.70) or imgui.ImVec4(0.50, 0.45, 1.00, 0.90)
            imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8': ')
            imgui.SameLine(0, 5)
            imgui.TextColored(key_color, u8(key_name))
            
            imgui.Spacing()
            
            local button_height = 32
            local window_width = imgui.GetWindowWidth()
            local padding = imgui.GetStyle().WindowPadding.x * 2
            local avail_width = window_width - padding - 24
            local spacing = imgui.GetStyle().ItemSpacing.x
            
            local holdModeText = rule.holdMode and u8'' or u8' '
            local hold_color = rule.holdMode and imgui.ImVec4(0.50, 0.45, 1.00, 0.80) or imgui.ImVec4(0.40, 0.40, 0.45, 0.80)
            imgui.PushStyleColor(imgui.Col.Button, hold_color)
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.60, 0.55, 1.00, 0.90))
            imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.40, 0.35, 0.90, 1.00))
            
            local button_width_hold = (avail_width - spacing * 2) / 3
            if imgui.Button(holdModeText .. '##hold_' .. i, imgui.ImVec2(button_width_hold, button_height)) and not is_capturing_any then
                rule.holdMode = not rule.holdMode
                saveConfig()
            end
            imgui.PopStyleColor(3)
            
            imgui.SameLine()

            local bind_text = is_capturing_this and u8' ... (Backspace )' or u8' '
            
            if is_capturing_this then
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.90, 0.60, 0.20, 1.00))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.95, 0.65, 0.25, 1.00))
                imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.85, 0.55, 0.15, 1.00))
            elseif is_blocked_by_other then
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.30, 0.30, 0.35, 0.60))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.30, 0.30, 0.35, 0.60))
                imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.30, 0.30, 0.35, 0.60))
            else
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.50, 0.45, 1.00, 0.80))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.60, 0.55, 1.00, 0.90))
                imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.40, 0.35, 0.90, 1.00))
            end

            local button_width_bind = (avail_width - spacing * 2) / 3
            if imgui.Button(bind_text..'##bind_'..i, imgui.ImVec2(button_width_bind, button_height)) and not is_blocked_by_other then
                if is_capturing_this then
                    key_capture_mode, key_capture_type = nil, nil
                else
                    key_capture_mode = {index = i}
                    key_capture_type = "rule"
                end
            end
            imgui.PopStyleColor(3)
            
            imgui.SameLine()
            
            if rule.key and rule.key > 0 then
                if is_capturing_any then
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.30, 0.30, 0.35, 0.60))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.30, 0.30, 0.35, 0.60))
                    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.30, 0.30, 0.35, 0.60))
                else
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.80, 0.30, 0.30, 0.80))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.90, 0.35, 0.35, 0.90))
                    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.70, 0.25, 0.25, 1.00))
                end
                
                local button_width_reset = (avail_width - spacing * 2) / 3
                if imgui.Button(u8' ##reset_'..i, imgui.ImVec2(button_width_reset, button_height)) and not is_capturing_any then
                    rule.key = 0
                    rule.keyName = "  "
                    saveConfig()
                end
                imgui.PopStyleColor(3)
            end
            
            imgui.Spacing()
        end
        imgui.EndChild()
        imgui.PopStyleVar(2)
        imgui.PopStyleColor(2)
        
        imgui.Spacing()
    end
end

local function renderRadialMenuTab()
    local is_capturing_any = (key_capture_mode ~= nil)

    imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8'  ')
    imgui.Spacing()
    imgui.Spacing()

    if is_capturing_any then
        imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, 0.5)
    end

    imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.11, 0.11, 0.13, 1.00))
    imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.30, 0.30, 0.35, 0.50))
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 6.0)
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildBorderSize, 1.5)

    if imgui.BeginChild('##radial_global_settings', imgui.ImVec2(0, 118), true) then
        imgui.Spacing()
        imgui.TextColored(imgui.ImVec4(0.95, 0.95, 1.00, 1.00), u8' ')
        imgui.Spacing()

        local enabled_checkbox = imgui.new.bool(radialMenu.globalEnabled)
        if imgui.Checkbox(u8'   (  )', enabled_checkbox) and not is_capturing_any then
            radialMenu.globalEnabled = enabled_checkbox[0]
            saveConfig()
        end

        if imgui.IsItemHovered() then
            imgui.SetTooltip(u8'      ')
        end

        imgui.Spacing()
    end
    imgui.EndChild()
    imgui.PopStyleVar(2)
    imgui.PopStyleColor(2)

    imgui.Spacing()
    imgui.Spacing()

    imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8'   ')
    imgui.Spacing()
    imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8'  6 .     / .')
    imgui.Spacing()
    imgui.Spacing()

    for i, btn in ipairs(radialMenu.buttons) do
        local card_bg = imgui.ImVec4(0.11, 0.11, 0.13, 1.00)
        local card_border = imgui.ImVec4(0.30, 0.30, 0.35, 0.50)

        imgui.PushStyleColor(imgui.Col.ChildBg, card_bg)
        imgui.PushStyleColor(imgui.Col.Border, card_border)
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 6.0)
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildBorderSize, 1.5)

        if imgui.BeginChild('##radial_button_card_' .. i, imgui.ImVec2(0, 167), true) then
            imgui.Spacing()
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.95, 0.95, 1.00, 1.00))
            imgui.Text(u8(' #' .. i))
            imgui.PopStyleColor(1)
            imgui.Spacing()

            local btn_enabled = imgui.new.bool(btn.enabled)
            if imgui.Checkbox(u8('##btn_' .. i), btn_enabled) and not is_capturing_any then
                btn.enabled = btn_enabled[0]
                saveConfig()
            end

            imgui.Spacing()
            imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8':')
            imgui.SameLine()
            imgui.PushItemWidth(-100)

            -- InputText     
            imgui.InputText('##radial_btn_name_' .. i, radialButtonBuffers[i], 64)

            imgui.PopItemWidth()
            imgui.SameLine()

            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.50, 0.45, 1.00, 0.80))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.60, 0.55, 1.00, 0.90))
            imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.40, 0.35, 0.90, 1.00))
            if imgui.Button(u8'##save_btn_' .. i, imgui.ImVec2(90, 0)) and not is_capturing_any then
                --    (  CP1251)
                local new_name_cp1251 = ffi.string(radialButtonBuffers[i])
                
                if #new_name_cp1251 > 0 and #new_name_cp1251 <= 63 then
                    --    (CP1251),    
                    btn.name = new_name_cp1251
                    saveConfig()
                    sampAddChatMessage('[ORULE]   #' .. i .. ' !', 0x00FF00)
                else
                    sampAddChatMessage('[ORULE] :        ', 0xFF0000)
                end
            end
            imgui.PopStyleColor(3)
            imgui.Spacing()
        end
        imgui.EndChild()
        imgui.PopStyleVar(2)
        imgui.PopStyleColor(2)
        imgui.Spacing()
    end

    if is_capturing_any then
        imgui.PopStyleVar(1)
    end

    imgui.Spacing()
    imgui.Spacing()

    imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.08, 0.08, 0.12, 1.00))
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 6.0)
    if imgui.BeginChild('##radial_info', imgui.ImVec2(0, 499), true) then
        imgui.Spacing()
        imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8'   ')
        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        local descriptions = {
            u8'   ',
            u8'   ()',
            u8'      /frisk',
            u8'    /doc',
            u8'   ',
            u8'  '
        }

        for i, desc in ipairs(descriptions) do
            imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.90, 1.00), u8(' #' .. i .. ':'))
            imgui.BulletText(desc)
            imgui.Spacing()
        end

        imgui.Separator()
        imgui.Spacing()
        imgui.PushTextWrapPos(0)
        imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.75, 0.90), u8':             .')
        imgui.PopTextWrapPos()
        imgui.Spacing()
    end
    imgui.EndChild()
    imgui.PopStyleVar(1)
    imgui.PopStyleColor(1)
end

-- ============================================================
--  
-- ============================================================
local function validateCommand(cmd)
    if not cmd or #cmd == 0 then return false, "    " end
    if #cmd > 31 then return false, "   (. 31 )" end
    if cmd:match("[^%w_]") then return false, "    ,   _" end
    return true
end

local function renderSettingsTab()
    local is_capturing_any = (key_capture_mode ~= nil)
    local is_capturing_global = (key_capture_type == "global")
    local disabled_color = imgui.ImVec4(0.30, 0.30, 0.35, 0.60)

    imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8' ')
    imgui.Spacing()

    if is_capturing_any and not is_capturing_global then
        imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, 0.5)
    end
    
    imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.90, 1.00), u8'   :')
    imgui.Spacing()
    
    imgui.PushItemWidth(-1)
    imgui.InputText('##command', commandBuf, 32)
    imgui.PopItemWidth()
    if imgui.IsItemHovered() then 
        imgui.SetTooltip(u8'    (: /orule)') 
    end
    
    if is_capturing_any and not is_capturing_global then
        imgui.PopStyleVar(1)
    end
    
    imgui.Spacing()
    imgui.Spacing()
    
    imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8' ')
    imgui.Spacing()
    
    local bind_text_global = is_capturing_global and u8' ... (Backspace )' or (u8': '..u8(getKeyName(config.globalHotkey))..u8' (  )')
    local is_blocked_global = is_capturing_any and not is_capturing_global
    
    imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.90, 1.00), u8'    :')
    imgui.Spacing()
    
    if is_capturing_global then
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.90, 0.60, 0.20, 1.00))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.95, 0.65, 0.25, 1.00))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.85, 0.55, 0.15, 1.00))
    elseif is_blocked_global then
        imgui.PushStyleColor(imgui.Col.Button, disabled_color)
        imgui.PushStyleColor(imgui.Col.ButtonHovered, disabled_color)
        imgui.PushStyleColor(imgui.Col.ButtonActive, disabled_color)
    else
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.50, 0.45, 1.00, 0.80))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.60, 0.55, 1.00, 0.90))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.40, 0.35, 0.90, 1.00))
    end
    
    if imgui.Button(bind_text_global, imgui.ImVec2(-1, 40)) and not is_blocked_global and not is_capturing_global then
        key_capture_mode, key_capture_type = {}, "global"
    end
    imgui.PopStyleColor(3)
    
    if imgui.IsItemHovered() then 
        imgui.SetTooltip(u8'      (0 = )') 
    end
    
    imgui.Spacing()
    
    if config.globalHotkey and config.globalHotkey > 0 then
        if is_capturing_any then
            imgui.PushStyleColor(imgui.Col.Button, disabled_color)
            imgui.PushStyleColor(imgui.Col.ButtonHovered, disabled_color)
            imgui.PushStyleColor(imgui.Col.ButtonActive, disabled_color)
        else
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.80, 0.30, 0.30, 0.80))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.90, 0.35, 0.35, 0.90))
            imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.70, 0.25, 0.25, 1.00))
        end
        
        if imgui.Button(u8' ##reset_global', imgui.ImVec2(-1, 40)) and not is_capturing_any then
            config.globalHotkey = 0
            saveConfig()
        end
        imgui.PopStyleColor(3)
    end
    
    imgui.Spacing()
    imgui.Spacing()
    
    imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8'  overlay')
    imgui.Spacing()
    
    if is_capturing_any then
        imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, 0.5)
    end

    imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.90, 1.00), u8' :')
    local alpha_val = imgui.new.float[1](config.overlayBgAlpha)
    imgui.PushItemWidth(-1)
    if imgui.SliderFloat('##alpha', alpha_val, 0.0, 1.0, u8'%.2f') and not is_capturing_any then 
        config.overlayBgAlpha = alpha_val[0]
        saveConfig() 
    end
    imgui.PopItemWidth()
    
    imgui.Spacing()
    imgui.Spacing()
    
    imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.90, 1.00), u8' :')
    local font_val = imgui.new.float[1](config.fontSize)
    imgui.PushItemWidth(-1)
    if imgui.SliderFloat('##fontsize', font_val, 12.0, 32.0, u8'%.0f') and not is_capturing_any then 
        config.fontSize = font_val[0]
        saveConfig() 
    end
    imgui.PopItemWidth()
    
    imgui.Spacing()
    imgui.Spacing()
    
    imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.90, 1.00), u8'  :')
    local spacing_val = imgui.new.float[1](config.lineSpacing)
    imgui.PushItemWidth(-1)
    if imgui.SliderFloat('##linespacing', spacing_val, 0.0, 1.0, u8'%.2f') and not is_capturing_any then 
        config.lineSpacing = spacing_val[0]
        saveConfig() 
    end
    imgui.PopItemWidth()
    if imgui.IsItemHovered() then 
        imgui.SetTooltip(u8'    (   )') 
    end
    
    if is_capturing_any then
        imgui.PopStyleVar(1)
    end
    
    imgui.Spacing()
    imgui.Spacing()
    
    if is_capturing_any then
        imgui.PushStyleColor(imgui.Col.Button, disabled_color)
        imgui.PushStyleColor(imgui.Col.ButtonHovered, disabled_color)
        imgui.PushStyleColor(imgui.Col.ButtonActive, disabled_color)
    else
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.50, 0.45, 1.00, 0.90))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.60, 0.55, 1.00, 1.00))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.40, 0.35, 0.90, 1.00))
    end
    
    if imgui.Button(u8'  ', imgui.ImVec2(-1, 45)) and not is_capturing_any then
        local new_command = ffi.string(commandBuf)
        local valid, error_msg = validateCommand(new_command)
        
        if not valid then
            sampAddChatMessage('[ORULE] : ' .. error_msg, 0xFF0000)
        else
            config.command = new_command
            saveConfig()
            sampAddChatMessage('[ORULE]  !   (CTRL+R)', 0x45AFFF)
        end
    end
    
    imgui.PopStyleColor(3)
end

-- ============================================================
--  
-- ============================================================
local function renderInfoWindow()
    local sw, sh = getScreenResolution()
    imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(config.windowWidth or 820, config.windowHeight or 1200), imgui.Cond.FirstUseEver)

    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 12.0)
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 2.0)
    imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.50, 0.45, 1.00, 0.90))

    local window_flags = imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize

    if imgui.Begin(u8'   ORULE!', show_info_window, window_flags) then
        imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.08, 0.08, 0.12, 1.00))
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 8.0)
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildBorderSize, 1.0)

        if imgui.BeginChild('##info_header', imgui.ImVec2(0, 121), true) then
            if title_font then imgui.PushFont(title_font) end

            local window_width = imgui.GetWindowWidth()
            local title_text = u8'ORULE v1.0'
            local title_width = imgui.CalcTextSize(title_text).x

            imgui.SetCursorPosY(15)
            imgui.SetCursorPosX((window_width - title_width) * 0.5)
            imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), title_text)

            if title_font then imgui.PopFont() end

            imgui.Spacing()

            if main_font then imgui.PushFont(main_font) end
            local subtitle_text = u8'    overlay-'
            local subtitle_width = imgui.CalcTextSize(subtitle_text).x
            imgui.SetCursorPosX((window_width - subtitle_width) * 0.5)
            imgui.TextColored(imgui.ImVec4(0.90, 0.90, 0.95, 1.00), subtitle_text)

            imgui.Spacing()

            local author_text = u8': Lev Exelent (vk.com/e11evated)'
            local author_width = imgui.CalcTextSize(author_text).x
            imgui.SetCursorPosX((window_width - author_width) * 0.5)
            imgui.TextColored(imgui.ImVec4(0.80, 0.80, 0.85, 1.00), author_text)
            if main_font then imgui.PopFont() end
        end
        imgui.EndChild()
        imgui.PopStyleVar(2)
        imgui.PopStyleColor(1)

        imgui.Spacing()
        imgui.Spacing()

        if main_font then imgui.PushFont(main_font) end

        imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.0, 0.0, 0.0, 0.0))
        if imgui.BeginChild('##info_content', imgui.ImVec2(0, -61), false) then
            imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8' !')
            imgui.Spacing()
            imgui.PushTextWrapPos(0)
            imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.90, 1.00), u8',   ORULE -      MoonLoader!')
            imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8'         Cyber Russia.')
            imgui.PopTextWrapPos()

            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8' ')
            imgui.Spacing()
            imgui.BulletText(u8'Overlay- -      ')
            imgui.BulletText(u8'  -      ')
            imgui.BulletText(u8'  -    /me /do ')
            imgui.BulletText(u8'  -       ')
            imgui.BulletText(u8'  -      ')
            imgui.BulletText(u8'   - , , ')
            imgui.BulletText(u8'     -   ')

            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8' ')
            imgui.Spacing()
            imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.90, 1.00), u8' 1:')
            imgui.SameLine(0, 5)
            imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8'   ""    ')
            imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.90, 1.00), u8' 2:')
            imgui.SameLine(0, 5)
            imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8'   overlay   ""')
            imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.90, 1.00), u8' 3:')
            imgui.SameLine(0, 5)
            imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8'     overlay')
            imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.90, 1.00), u8' 4:')
            imgui.SameLine(0, 5)
            imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8'     ')

            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8'')
            imgui.Spacing()
            imgui.Columns(2, nil, false)
            imgui.SetColumnWidth(0, 250)
            imgui.TextColored(imgui.ImVec4(0.60, 0.55, 1.00, 1.00), u8'/' .. u8(config.command))
            imgui.NextColumn()
            imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8'/  ')
            imgui.NextColumn()
            imgui.TextColored(imgui.ImVec4(0.60, 0.55, 1.00, 1.00), u8'  ')
            imgui.NextColumn()
            imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8'  ()')
            imgui.NextColumn()
            imgui.TextColored(imgui.ImVec4(0.60, 0.55, 1.00, 1.00), u8'ESC')
            imgui.NextColumn()
            imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8' overlay  ')
            imgui.NextColumn()
            imgui.TextColored(imgui.ImVec4(0.60, 0.55, 1.00, 1.00), u8' ')
            imgui.NextColumn()
            imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8'/  ')
            imgui.Columns(1)

            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8' ')
            imgui.Spacing()
            imgui.PushTextWrapPos(0)
            imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8'      .')
            imgui.PopTextWrapPos()
            imgui.Spacing()
            imgui.Indent(20)
            imgui.BulletText(u8' -    ')
            imgui.BulletText(u8' -   ')
            imgui.BulletText(u8' -     ')
            imgui.BulletText(u8' -   ')
            imgui.BulletText(u8' -    ')
            imgui.BulletText(u8' -   ')
            imgui.Unindent(20)

            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8'    1.0')
            imgui.Spacing()
            imgui.BulletText(u8'  ')
            imgui.BulletText(u8'9       ')
            imgui.BulletText(u8'   (, , , )')
            imgui.BulletText(u8'     ')
            imgui.BulletText(u8'   ')
            imgui.BulletText(u8'    ')

            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8' ')
            imgui.Spacing()
            imgui.BulletText(u8'    (-)   ')
            imgui.BulletText(u8'       ')
            imgui.BulletText(u8'  overlay   ')
            imgui.BulletText(u8'      moonloader/OverlayRules/texts/')
            imgui.BulletText(u8'        ')
        end
        imgui.EndChild()
        imgui.PopStyleColor(1)

        if main_font then imgui.PopFont() end

        imgui.Spacing()

        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.50, 0.45, 1.00, 0.90))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.60, 0.55, 1.00, 1.00))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.40, 0.35, 0.90, 1.00))
        if title_font then imgui.PushFont(title_font) end

        local button_text = u8''
        local button_width = imgui.CalcTextSize(button_text).x + 80
        local window_width = imgui.GetWindowWidth()
        imgui.SetCursorPosX((window_width - button_width) * 0.5)

        if imgui.Button(button_text, imgui.ImVec2(button_width, 45)) then
            show_info_window[0] = false
            info_window_shown_once = true
            config.firstLaunch = false
            saveConfig()
            show_window[0] = true
            imgui.Process = true
        end

        if title_font then imgui.PopFont() end
        imgui.PopStyleColor(3)
    end
    imgui.End()

    imgui.PopStyleColor(1)
    imgui.PopStyleVar(2)
end

local function renderWindow()
    local sw, sh = getScreenResolution()
    imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(config.windowWidth or 820, config.windowHeight or 1200), imgui.Cond.FirstUseEver)

    if imgui.Begin(u8' ', show_window, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize) then
        if not first_render_done then
            first_render_done = true
            imgui.Text(u8' ...')
            imgui.End()
            return
        end
        local current_size = imgui.GetWindowSize()
        local current_width = math.floor(current_size.x)
        local current_height = math.floor(current_size.y)
        
        if (last_window_width ~= current_width or last_window_height ~= current_height) and (last_window_width > 0 or last_window_height > 0) then
            config.windowWidth = current_width
            config.windowHeight = current_height
            saveConfig()
        end
        
        last_window_width = current_width
        last_window_height = current_height
        
        local header_color1 = imgui.ImVec4(0.08, 0.08, 0.12, 1.00)
        
        imgui.PushStyleColor(imgui.Col.ChildBg, header_color1)
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 8.0)
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildBorderSize, 1.0)
        
        if imgui.BeginChild('##header', imgui.ImVec2(0, 128), true) then
            if title_font then imgui.PushFont(title_font) end

            imgui.SetCursorPos(imgui.ImVec2(20, 12))
            local window_width = imgui.GetWindowWidth()
            local available_width = window_width - 40

            local title_text = u8'ORULE'
            local title_width = imgui.CalcTextSize(title_text).x
            imgui.SetCursorPosX(20 + (available_width - title_width) * 0.5)

            local colors_gradient = {
                imgui.ImVec4(0.70, 0.65, 1.00, 1.00),
                imgui.ImVec4(0.50, 0.45, 1.00, 1.00),
                imgui.ImVec4(0.40, 0.35, 0.90, 1.00)
            }
            imgui.TextColored(colors_gradient[2], title_text)

            imgui.Spacing()

            local desc_text = u8'    overlay-'
            local desc_width = imgui.CalcTextSize(desc_text).x
            imgui.SetCursorPosX(20 + (available_width - desc_width) * 0.5)
            imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.95), desc_text)

            imgui.Spacing()

            local author_text = u8': Lev Exelent (vk.com/e11evated)'
            local author_width = imgui.CalcTextSize(author_text).x
            imgui.SetCursorPosX(20 + (available_width - author_width) * 0.5)
            imgui.TextColored(imgui.ImVec4(0.65, 0.65, 0.70, 0.90), author_text)

            if title_font then imgui.PopFont() end
        end
        imgui.EndChild()
        imgui.PopStyleVar(2)
        imgui.PopStyleColor(1)
        
        imgui.Spacing()
        imgui.Spacing()
        
        if imgui.BeginTabBar('##main_tabs') then
            if imgui.BeginTabItem(u8'') then 
                if main_font then imgui.PushFont(main_font) end
                
                local content_height = imgui.GetContentRegionAvail().y
                imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.0, 0.0, 0.0, 0.0))
                if imgui.BeginChild('##rules_scroll', imgui.ImVec2(0, content_height), false) then
                    imgui.Spacing()
                    renderRulesTab()
                end
                imgui.EndChild()
                imgui.PopStyleColor(1)
                
                if main_font then imgui.PopFont() end
                imgui.EndTabItem() 
            end
            if imgui.BeginTabItem(u8' ') then
                if main_font then imgui.PushFont(main_font) end
                
                local content_height = imgui.GetContentRegionAvail().y
                imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.0, 0.0, 0.0, 0.0))
                if imgui.BeginChild('##radial_scroll', imgui.ImVec2(0, content_height), false) then
                    imgui.Spacing()
                    renderRadialMenuTab()
                end
                imgui.EndChild()
                imgui.PopStyleColor(1)
                
                if main_font then imgui.PopFont() end
                imgui.EndTabItem()
            end
            if imgui.BeginTabItem(u8'') then 
                if main_font then imgui.PushFont(main_font) end
                
                local content_height = imgui.GetContentRegionAvail().y
                imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.0, 0.0, 0.0, 0.0))
                if imgui.BeginChild('##settings_scroll', imgui.ImVec2(0, content_height), false) then
                    imgui.Spacing()
                    renderSettingsTab()
                end
                imgui.EndChild()
                imgui.PopStyleColor(1)
                
                if main_font then imgui.PopFont() end
                imgui.EndTabItem() 
            end
            imgui.EndTabBar()
        end
    end
    imgui.End()
end

-- ============================================================
--  
-- ============================================================
local function renderRadialMenu()
    if not radialMenu.globalEnabled then return end
    if not (radialMenu.active or radialMenu.pendingActivation or radialMenu.releasePending) then
        return
    end

    if radialMenu.pendingActivation then
        local io = imgui.GetIO()
        radialMenu.center = imgui.ImVec2(io.DisplaySize.x * 0.5, io.DisplaySize.y * 0.5)
        radialMenu.active = true
        radialMenu.pendingActivation = false
        radialMenu.selected = nil
    end

    if not radialMenu.isHeld then
        if radialMenu.releasePending or radialMenu.active then
            if radialMenu.active and radialMenu.selected then
                local enabled_buttons = {}
                for i, btn in ipairs(radialMenu.buttons) do
                    if btn.enabled then
                        table.insert(enabled_buttons, i)
                    end
                end
                if enabled_buttons[radialMenu.selected] then
                    radialMenu.action = enabled_buttons[radialMenu.selected]
                end
            end
        end
        radialMenu.active = false
        radialMenu.releasePending = false
        radialMenu.selected = nil
        return
    end

    radialMenu.releasePending = false

    local io = imgui.GetIO()
    local center = radialMenu.center
    local draw_list = imgui.GetForegroundDrawList()
    local radius = radialMenu.radius
    local baseColor = imgui.ImVec4(0.12, 0.13, 0.19, 0.94)
    local baseAltColor = imgui.ImVec4(0.11, 0.12, 0.18, 0.94)
    local accentColor = imgui.ImVec4(0.57, 0.52, 1.00, 1.00)
    local accentSoft = imgui.ImVec4(0.43, 0.40, 0.88, 0.85)
    local shadowColor = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.0, 0.0, 0.0, 0.45))
    local ringOuterColor = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.09, 0.10, 0.16, 0.96))
    local ringHighlight = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.35, 0.36, 0.55, 0.45))
    local ringInnerBorder = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.32, 0.35, 0.68, 0.92))
    local textColor = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.94, 0.96, 1.00, 1.00))
    local dividerColor = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.22, 0.25, 0.40, 0.85))
    local highlightRingColor = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.62, 0.64, 1.00, 0.95))
    local centerCircleColor = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.09, 0.10, 0.15, 0.97))

    local outerRadius = radius
    local innerRadius = radius * 0.55
    local accentRadius = radius + 12
    draw_list:AddCircleFilled(center, accentRadius, shadowColor, 96)
    draw_list:AddCircle(center, outerRadius + 6, ringOuterColor, 96, 5.0)
    draw_list:AddCircle(center, outerRadius + 2, ringHighlight, 96, 2.0)
    draw_list:AddCircle(center, innerRadius, ringInnerBorder, 96, 2.4)
    draw_list:AddCircleFilled(center, radialMenu.deadzone, centerCircleColor, 48)

    local diffX = io.MousePos.x - center.x
    local diffY = io.MousePos.y - center.y
    local distance = math.sqrt(diffX * diffX + diffY * diffY)

    local enabled_buttons = {}
    for i, btn in ipairs(radialMenu.buttons) do
        if btn.enabled then
            table.insert(enabled_buttons, {index = i, name = btn.name})
        end
    end
    local segments = #enabled_buttons
    if segments == 0 then return end

    local step = (2 * math.pi) / segments
    local startAngle = -math.pi / 2 - (step * 0.5)

    local selectedIndex = nil
    if distance >= radialMenu.deadzone then
        local angle = math.atan2(diffY, diffX)
        if angle < 0 then angle = angle + (2 * math.pi) end
        local normalized = angle - startAngle
        while normalized < 0 do normalized = normalized + (2 * math.pi) end
        while normalized >= (2 * math.pi) do normalized = normalized - (2 * math.pi) end
        selectedIndex = math.floor(normalized / step) + 1
        if selectedIndex > segments then selectedIndex = segments end
    end
    radialMenu.selected = selectedIndex

    local arcSegments = 18
    local flareRadius = outerRadius + 26
    if selectedIndex then
        local flareAngle = startAngle + (selectedIndex - 0.5) * step
        local flarePos = imgui.ImVec2(center.x + math.cos(flareAngle) * flareRadius,
                                      center.y + math.sin(flareAngle) * flareRadius)
        draw_list:AddCircleFilled(flarePos, 38, imgui.ColorConvertFloat4ToU32(imgui.ImVec4(accentColor.x, accentColor.y, accentColor.z, 0.22)), 64)
    end

    for i = 1, segments do
        local angleStart = startAngle + (i - 1) * step
        local angleEnd = angleStart + step

        local points = {}
        for s = 0, arcSegments do
            local t = angleStart + (angleEnd - angleStart) * (s / arcSegments)
            points[#points + 1] = imgui.ImVec2(center.x + math.cos(t) * outerRadius,
                                               center.y + math.sin(t) * outerRadius)
        end
        for s = arcSegments, 0, -1 do
            local t = angleStart + (angleEnd - angleStart) * (s / arcSegments)
            points[#points + 1] = imgui.ImVec2(center.x + math.cos(t) * innerRadius,
                                               center.y + math.sin(t) * innerRadius)
        end

        local baseVec = ((i % 2) == 0) and baseColor or baseAltColor
        local fillColor = imgui.ColorConvertFloat4ToU32(baseVec)
        draw_list:PathClear()
        for _, pt in ipairs(points) do
            draw_list:PathLineTo(pt)
        end
        draw_list:PathFillConvex(fillColor)

        if selectedIndex == i then
            local glowVec = imgui.ImVec4(
                math.min(accentSoft.x + accentColor.x * 0.25, 1.0),
                math.min(accentSoft.y + accentColor.y * 0.25, 1.0),
                math.min(accentSoft.z + accentColor.z * 0.25, 1.0),
                0.90
            )
            local glowColor = imgui.ColorConvertFloat4ToU32(glowVec)
            draw_list:PathClear()
            local insetOuter = outerRadius - 4
            local insetInner = innerRadius + 2
            for s = 0, arcSegments do
                local t = angleStart + (angleEnd - angleStart) * (s / arcSegments)
                draw_list:PathLineTo(imgui.ImVec2(center.x + math.cos(t) * insetOuter,
                                                  center.y + math.sin(t) * insetOuter))
            end
            for s = arcSegments, 0, -1 do
                local t = angleStart + (angleEnd - angleStart) * (s / arcSegments)
                draw_list:PathLineTo(imgui.ImVec2(center.x + math.cos(t) * insetInner,
                                                  center.y + math.sin(t) * insetInner))
            end
            draw_list:PathFillConvex(glowColor)
        end

        local dividerStart = imgui.ImVec2(center.x + math.cos(angleStart) * innerRadius,
                                          center.y + math.sin(angleStart) * innerRadius)
        local dividerEnd = imgui.ImVec2(center.x + math.cos(angleStart) * (outerRadius + 4),
                                        center.y + math.sin(angleStart) * (outerRadius + 4))
        draw_list:AddLine(dividerStart, dividerEnd, dividerColor, 2.0)

        if selectedIndex == i then
            draw_list:PathClear()
            draw_list:PathArcTo(center, outerRadius + 5, angleStart, angleEnd, arcSegments)
            draw_list:PathStroke(highlightRingColor, false, 3.5)
        end

        local midAngle = angleStart + step * 0.5
        local label = enabled_buttons[i].name or ""
        -- label   CP1251,   
        local label_u8 = label
        local textSize = imgui.CalcTextSize(label_u8)
        local textRadius = (innerRadius + outerRadius) * 0.5
        local textPos = imgui.ImVec2(center.x + math.cos(midAngle) * textRadius - textSize.x * 0.5,
                                     center.y + math.sin(midAngle) * textRadius - textSize.y * 0.5)
        local labelColor = (selectedIndex == i) and highlightRingColor or textColor
        draw_list:AddText(textPos, labelColor, label_u8)
    end

    if selectedIndex then
        local angleStart = startAngle + (selectedIndex - 1) * step
        local midAngle = angleStart + step * 0.5
        local indicatorRadius = (innerRadius + outerRadius) * 0.5
        local indicatorPos = imgui.ImVec2(center.x + math.cos(midAngle) * indicatorRadius,
                                          center.y + math.sin(midAngle) * indicatorRadius)
        draw_list:AddCircleFilled(indicatorPos, 7.5, highlightRingColor, 24)
        draw_list:AddLine(center, indicatorPos, highlightRingColor, 3.0)
    end

    draw_list:AddCircle(center, radialMenu.deadzone + 1.5, highlightRingColor, 48, 1.6)
end

local function shouldProcessImGui()
    return show_window[0] or show_info_window[0] or radialMenu.active or radialMenu.pendingActivation or radialMenu.releasePending or radialMenu.isHeld
end

imgui.OnFrame(function() 
    return shouldProcessImGui()
end, function() 
    imgui.Process = shouldProcessImGui()
    if show_info_window[0] then
        renderInfoWindow()
    end
    if show_window[0] then
        renderWindow()
    end
    renderRadialMenu()
end)

-- ============================================================
--  
-- ============================================================
function onWindowMessage(msg, wparam, lparam)
    if (msg == wm.WM_KEYDOWN or msg == wm.WM_SYSKEYDOWN) then
        if overlay_visible and wparam == 27 then
            consumeWindowMessage(true, true)
            overlay_visible = false
            return
        end
        if show_info_window[0] and not isPauseMenuActive() and wparam == 27 then
            consumeWindowMessage(true, false)
            show_info_window[0] = false
            info_window_shown_once = true
            config.firstLaunch = false
            saveConfig()
            show_window[0] = true
            imgui.Process = true
            return
        end
        if show_window[0] and not isPauseMenuActive() and wparam == 27 then
            if key_capture_mode then return end
            consumeWindowMessage(true, false)
            show_window[0] = false
            imgui.Process = false
            return
        end
        
        if key_capture_mode and key_capture_type then
            local code = wparam
            if code == 27 then
                key_capture_mode, key_capture_type = nil, nil
                consumeWindowMessage(true, true)
            elseif code == 0x08 then
                key_capture_mode, key_capture_type = nil, nil
                consumeWindowMessage(true, true)
            elseif code ~= 0x10 and code ~= 0x11 and code ~= 0x12 then
                local exclude_index = nil
                if key_capture_type == "rule" and key_capture_mode and key_capture_mode.index then
                    exclude_index = key_capture_mode.index
                end
                
                if isKeyAlreadyUsed(code, exclude_index) then
                    local key_name = getKeyName(code)
                    local used_by = ""
                    if config.globalHotkey == code then
                        used_by = "  "
                    else
                        for i, rule in ipairs(rulesDB) do
                            if i ~= exclude_index and rule.key == code then
                                used_by = " \"" .. rule.name .. "\""
                                break
                            end
                        end
                    end
                    
                    if isSampLoaded() and isSampAvailable() then
                        sampAddChatMessage(string.format('[ORULE]  "%s"   %s', key_name, used_by), 0xFF0000)
                    end
                    
                    key_capture_mode, key_capture_type = nil, nil
                    consumeWindowMessage(true, true)
                else
                    if key_capture_type == "rule" and key_capture_mode and key_capture_mode.index and rulesDB[key_capture_mode.index] then
                        rulesDB[key_capture_mode.index].key = code
                        rulesDB[key_capture_mode.index].keyName = getKeyName(code)
                    elseif key_capture_type == "global" then
                        config.globalHotkey = code
                    end
                    key_capture_mode, key_capture_type = nil, nil
                    saveConfig()
                    consumeWindowMessage(true, true)
                end
            end
        end
    end
    
    if key_capture_mode and key_capture_type and (msg == wm.WM_LBUTTONDOWN or msg == wm.WM_RBUTTONDOWN or msg == wm.WM_MBUTTONDOWN or msg == wm.WM_XBUTTONDOWN) then
        local code = nil
        if msg == wm.WM_LBUTTONDOWN then
            code = 0x01
        elseif msg == wm.WM_RBUTTONDOWN then
            code = 0x02
        elseif msg == wm.WM_MBUTTONDOWN then
            code = 0x04
        elseif msg == wm.WM_XBUTTONDOWN then
            local xbutton = bit.band(bit.rshift(wparam, 16), 0xFFFF)
            if xbutton == 1 then
                code = 0x05
            elseif xbutton == 2 then
                code = 0x06
            end
        end
        
        if code then
            local exclude_index = nil
            if key_capture_type == "rule" and key_capture_mode and key_capture_mode.index then
                exclude_index = key_capture_mode.index
            end
            
            if isKeyAlreadyUsed(code, exclude_index) then
                local key_name = getKeyName(code)
                local used_by = ""
                if config.globalHotkey == code then
                    used_by = "  "
                else
                    for i, rule in ipairs(rulesDB) do
                        if i ~= exclude_index and rule.key == code then
                            used_by = " \"" .. rule.name .. "\""
                            break
                        end
                    end
                end
                
                if isSampLoaded() and isSampAvailable() then
                    sampAddChatMessage(string.format('[ORULE]  "%s"   %s', key_name, used_by), 0xFF0000)
                end
                
                key_capture_mode, key_capture_type = nil, nil
                consumeWindowMessage(true, true)
            else
                if key_capture_type == "rule" and key_capture_mode and key_capture_mode.index and rulesDB[key_capture_mode.index] then
                    rulesDB[key_capture_mode.index].key = code
                    rulesDB[key_capture_mode.index].keyName = getKeyName(code)
                elseif key_capture_type == "global" then
                    config.globalHotkey = code
                end
                key_capture_mode, key_capture_type = nil, nil
                saveConfig()
                consumeWindowMessage(true, true)
            end
        end
    end

    if not key_capture_mode and radialMenu.globalEnabled then
        if msg == wm.WM_MBUTTONDOWN then
            radialMenu.pendingActivation = true
            radialMenu.releasePending = false
            radialMenu.isHeld = true
            consumeWindowMessage(true, true)
            imgui.Process = true
        elseif msg == wm.WM_MBUTTONUP then
            if radialMenu.active then
                radialMenu.releasePending = true
            end
            radialMenu.isHeld = false
            consumeWindowMessage(true, true)
            if not shouldProcessImGui() then
                imgui.Process = false
            end
        end
    end
end

-- ============================================================
--  
-- ============================================================
local function cmd_help()
    sampAddChatMessage("???????????????????????????", 0x45AFFF)
    sampAddChatMessage("Orule -   v1.0", 0x45AFFF)
    sampAddChatMessage("/" .. config.command .. " -  ", 0xFFFFFF)
    sampAddChatMessage("   () -  ", 0xFFFFFF)
    sampAddChatMessage(": Lev Exelent", 0xFFFFFF)
    sampAddChatMessage("???????????????????????????", 0x45AFFF)
end

local function toggle()
    if config.firstLaunch and not info_window_shown_once then
        show_info_window[0] = true
        imgui.Process = true
    else
        show_window[0] = not show_window[0]
        imgui.Process = show_window[0]
    end
end

function main()
    if not isSampLoaded() then return end
    while not isSampAvailable() do wait(100) end

    --  
    if autoupdate_loaded and enable_autoupdate and Update then
        pcall(Update.check, Update.json_url, Update.prefix, Update.url)
    end
    
    sampAddChatMessage("[ORULE] ...", 0x45AFFF)
    
    loadAllRules()
    
    if config.command and #config.command > 0 then 
        sampRegisterChatCommand(config.command, toggle)
        sampRegisterChatCommand(config.command .. "_help", cmd_help)
    end
    
    sampAddChatMessage("[ORULE] !  /" .. config.command, 0x00FF00)
    
    lua_thread.create(function()
        wait(2000)
        
        local files_to_preload = {
            "police_main.txt", "police_radar.txt", "police_mask.txt", "police_tint.txt",
            "legal_constitution.txt", "legal_federal.txt", "legal_uk.txt", "legal_koap.txt", 
            "legal_police_law.txt", "legal_fsb_law.txt",
            "territory_main.txt", "territory_mvd.txt", "territory_fsb.txt", "territory_army.txt", 
            "territory_fsin.txt", "territory_mchs.txt", "territory_hospital.txt", "territory_smi.txt", 
            "territory_government.txt", "territory_army_supplement.txt", "territory_fsin_supplement.txt",
            "hierarchy.txt", "upk.txt", "labor_code.txt", "mvd_handbook.txt", 
            "mvd_drill.txt", "mvd_statute.txt"
        }
        
        for i, filename in ipairs(files_to_preload) do
            loadTextFromFile(filename)
            wait(100)
        end
        
        preload_complete = true
    end)

    local held_rule_active = false
    while true do
        wait(0)
        local is_game_focused = not (sampIsChatInputActive() or sampIsDialogActive() or isSampfuncsConsoleActive() or isPauseMenuActive())
        
        if is_game_focused then
            if config.globalHotkey and config.globalHotkey > 0 and isKeyJustPressed(config.globalHotkey) then
                toggle()
            end

            held_rule_active = false
            for i, rule in ipairs(rulesDB) do
                if rule.key and rule.key > 0 then
                    if rule.holdMode then
                        if isKeyDown(rule.key) then
                            if overlay_rule_index ~= i then
                                ffi.fill(search_buffer, 256, 0)
                            end
                            overlay_rule_index, overlay_visible = i, true
                            held_rule_active = true
                            break
                        end
                    else
                        if isKeyJustPressed(rule.key) then
                            if overlay_visible and overlay_rule_index == i then 
                                overlay_visible = false
                                first_render_done = false
                            else 
                                overlay_rule_index, overlay_visible = i, true
                                ffi.fill(search_buffer, 256, 0)
                            end
                        end
                    end
                end
            end

            if not held_rule_active and overlay_visible and rulesDB[overlay_rule_index] and rulesDB[overlay_rule_index].holdMode then
                overlay_visible = false
            end

            if radialMenu.action then
                executeRadialAction(radialMenu.action)
                radialMenu.action = nil
            end
        end
    end
end