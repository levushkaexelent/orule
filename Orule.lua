script_name('Orule - Менеджер правил')
script_author('Lev Exelent (vk.com/e11evated)')
script_version('1.2')

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
-- МОДУЛЬ ДАННЫХ
-- ============================================================
local orule = {
    -- Система логирования
    LOG_FILE = getWorkingDirectory() .. '\\OverlayRules\\orule_errors.log',

    -- Пути к файлам
    SCRIPT_DIR = getWorkingDirectory() .. '\\OverlayRules',
    CONFIG_FILE = nil, -- будет инициализировано позже
    FONTS_DIR = nil,
    IMAGES_DIR = nil,
    TEXTS_DIR = nil,

    -- Переменные
    rulesDB = {},
    text_cache = {},
    config = {
        command = "orule",
        globalHotkey = 0,
        overlayBgAlpha = 0.85,
        fontSize = 18.0,
        lineSpacing = 0.1,
        windowWidth = 820,
        windowHeight = 800,
        ruleCardHeight = 183,
        firstLaunch = true,
        autoUpdateTexts = true
    }
}

-- Инициализация путей
orule.CONFIG_FILE = orule.SCRIPT_DIR .. '\\config.txt'
orule.FONTS_DIR = orule.SCRIPT_DIR .. '\\fonts'
orule.IMAGES_DIR = orule.SCRIPT_DIR .. '\\images'
orule.TEXTS_DIR = orule.SCRIPT_DIR .. '\\texts'

-- ============================================================
-- СИСТЕМА ЛОГИРОВАНИЯ
-- ============================================================
local function logError(message)
    local file = io.open(orule.LOG_FILE, 'a')
    if file then
        local timestamp = os.date('%Y-%m-%d %H:%M:%S')
        file:write(string.format('[%s] %s\n', timestamp, message))
        file:close()
    end
end

-- ============================================================
-- СИСТЕМА АВТООБНОВЛЕНИЯ
-- ============================================================
local SCRIPT_VERSION = "1.2"
local enable_autoupdate = true
local autoupdate_loaded = false
local Update = nil

if enable_autoupdate then
    local updater_loaded, Updater = pcall(loadstring, [[
        return {
            check = function(json_url, prefix, repo_url)
                local dlstatus = require('moonloader').download_status
                local temp_json = os.tmpname()
                local script_path = thisScript().path
                local backup_path = script_path .. '.backup'
                
                -- Создаем резервную копию
                local function createBackup()
                    local original = io.open(script_path, 'rb')
                    if not original then return false end
                    local content = original:read('*a')
                    original:close()
                    
                    local backup = io.open(backup_path, 'wb')
                    if not backup then return false end
                    backup:write(content)
                    backup:close()
                    return true
                end
                
                -- Восстанавливаем из резервной копии
                local function restoreBackup()
                    if not doesFileExist(backup_path) then return false end
                    
                    local backup = io.open(backup_path, 'rb')
                    if not backup then return false end
                    local content = backup:read('*a')
                    backup:close()
                    
                    local original = io.open(script_path, 'wb')
                    if not original then return false end
                    original:write(content)
                    original:close()
                    
                    os.remove(backup_path)
                    return true
                end
                
                if doesFileExist(temp_json) then os.remove(temp_json) end
                
                downloadUrlToFile(json_url, temp_json, function(id, status, p1, p2)
                    if status == dlstatus.STATUSEX_ENDDOWNLOAD then
                        if doesFileExist(temp_json) then
                            local json_file = io.open(temp_json, 'r')
                            if json_file then
                                local json_data = decodeJson(json_file:read('*a'))
                                json_file:close()
                                os.remove(temp_json)
                                
                                if json_data and json_data.latest and json_data.updateurl then
                                    local updateversion = json_data.latest
                                    local updatelink = json_data.updateurl
                                    
                                    if tostring(updateversion) ~= tostring(thisScript().version) then
                                        lua_thread.create(function()
                                            sampAddChatMessage(prefix..'Обнаружено обновление '..thisScript().version..' ? '..updateversion, -1)
                                            wait(500)
                                            
                                            -- Создаем резервную копию
                                            if not createBackup() then
                                                sampAddChatMessage(prefix..'Ошибка: не удалось создать резервную копию', -1)
                                                return
                                            end
                                            
                                            local temp_update = os.getenv('TEMP') .. '\\orule_update.lua'
                                            
                                            downloadUrlToFile(updatelink, temp_update, function(id2, status2, p3, p4)
                                                if status2 == dlstatus.STATUS_ENDDOWNLOADDATA then
                                                    lua_thread.create(function()
                                                        wait(300)
                                                        
                                                        local temp_file = io.open(temp_update, 'rb')
                                                        if not temp_file then
                                                            sampAddChatMessage(prefix..'Ошибка: не могу открыть загруженный файл', -1)
                                                            restoreBackup()
                                                            return
                                                        end
                                                        
                                                        local utf8_content = temp_file:read('*a')
                                                        temp_file:close()
                                                        
                                                        -- Убираем BOM
                                                        if utf8_content:sub(1, 3) == '\xEF\xBB\xBF' then
                                                            utf8_content = utf8_content:sub(4)
                                                        end
                                                        
                                                        -- Используем встроенный декодер
                                                        local success, cp1251_content = pcall(function()
                                                            return encoding.UTF8:decode(utf8_content)
                                                        end)
                                                        
                                                        if not success or not cp1251_content then
                                                            sampAddChatMessage(prefix..'Ошибка конвертации кодировки', -1)
                                                            restoreBackup()
                                                            os.remove(temp_update)
                                                            return
                                                        end
                                                        
                                                        -- Сохраняем
                                                        local output_file = io.open(script_path, 'wb')
                                                        if not output_file then
                                                            sampAddChatMessage(prefix..'Ошибка записи файла', -1)
                                                            restoreBackup()
                                                            os.remove(temp_update)
                                                            return
                                                        end
                                                        
                                                        output_file:write(cp1251_content)
                                                        output_file:close()
                                                        os.remove(temp_update)
                                                        
                                                        -- Удаляем резервную копию при успехе
                                                        if doesFileExist(backup_path) then
                                                            os.remove(backup_path)
                                                        end
                                                        
                                                        sampAddChatMessage(prefix..'Обновление завершено успешно!', -1)
                                                        wait(1000)
                                                        thisScript():reload()
                                                    end)
                                                end
                                            end)
                                        end)
                                    else
                                        print('v'..thisScript().version..': Обновление не требуется.')
                                    end
                                end
                            end
                        end
                    end
                end)
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
-- ПОДДЕРЖКА CP1251
-- ============================================================
-- Расширение string.lower() для корректной работы с кириллицей CP1251
do
    local cp1251_map = {}
    -- Заполняем маппинг для символов кириллицы (коды 192-223 в CP1251)
    for i = 192, 223 do
        cp1251_map[string.char(i)] = string.char(i + 32)
    end

    local original_lower = string.lower
    function string.lower(str)
        if type(str) ~= "string" then return original_lower(str) end

        -- Применяем маппинг для кириллицы
        local result = str:gsub("[\192-\223]", function(c)
            return cp1251_map[c] or c
        end)

        -- Используем стандартный lower для остальных символов
        return original_lower(result)
    end
end

-- Функция utf8_lower теперь просто обертка для совместимости
local function utf8_lower(str)
    return string.lower(str)
end

-- ============================================================
-- СИНОНИМЫ ДЛЯ ПОИСКА
-- ============================================================
local search_synonyms = {
    ["тонировка"] = {"тонировочная", "затемнение", "тонирование"},
    ["полиция"] = {"мвд", "полицейский", "правоохранитель"},
    ["обыск"] = {"досмотр", "проверка", "обыскивание"},
    ["задержание"] = {"арест", "задержать", "задержали"},
    ["радар"] = {"радары", "радаром", "скорость"},
    ["маска"] = {"маски", "снятие", "замаскированный"},
    ["удостоверение"] = {"документ", "удостоверения", "корочка"},
    ["закрытая территория"] = {"зт", "закрытые территории", "охраняемая зона"},
    ["автомобиль"] = {"машина", "транспорт", "авто", "тс"},
    ["оружие"] = {"пушка", "ствол", "огнестрел", "травмат"}
}

-- ============================================================
-- ДОПОЛНИТЕЛЬНЫЕ ПЕРЕМЕННЫЕ
-- ============================================================

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
local is_capturing_keys = false
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
        {name = "Мегафон", enabled = true},
        {name = "Миранда", enabled = true},
        {name = "Обыск", enabled = true},
        {name = "Удостоверение", enabled = true},
        {name = "Фоторобот", enabled = true},
        {name = "Тонировка", enabled = true}
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
-- ДЕЙСТВИЯ РАДИАЛЬНОГО МЕНЮ
-- ============================================================
local function executeRadialAction(index)
    if not index then return end

    if index == 1 then
        lua_thread.create(function()
            if not (isSampLoaded() and isSampAvailable()) then return end
            sampSendChat('/m [МВД] - Говорит МВД, водитель, прижмитесь к обочине и заглушите двигатель!')
            wait(1500)
            sampSendChat('/m [МВД] - В противном случае мы применим спецсредства!')
        end)
    elseif index == 2 then
        lua_thread.create(function()
            if not (isSampLoaded() and isSampAvailable()) then return end
            sampSendChat('Были задержаны территориальным управлением Министерства...')
            wait(1300)
            sampSendChat('...Внутренних Дел по Нижегородской области, г. Арзамас.')
            wait(1300)
            sampSendChat("Являюсь курсантом МВД.")
            wait(1300)
            sampSendChat('Ваше задержание фиксируется на нательную камеру ВДОЗОРВ.')
            wait(1000)
            local hour = os.date('%H')
            local min = os.date('%M')
            local sec = os.date('%S')
            sampSendChat(string.format('/do Ведётся видеофиксация. Текущее время: %s:%s:%s.', hour, min, sec))
            wait(1000)
            sampSendChat('Согласно Конституции РФ.')
            wait(1300)
            sampSendChat('Вы имеете право хранить молчание.')
            wait(1300)
            sampSendChat('Право на ознакомление со всеми протоколами, составленными при задержании.')
            wait(1300)
            sampSendChat('Имеете право на отказ от дачи показаний против себя и своих близких.')
            wait(1300)
            sampSendChat('На юридическую помощь в лице адвоката.')
            wait(1500)
            sampSendChat('Адвоката можете вызвать в следственном изоляторе, телефон у Вас изыматься не будет.')
            wait(1500)
            sampSendChat('Все мои действия можете обжаловать в суде.')
            wait(1500)
            sampSendChat('Вам ясны ваши права?')
        end)
    elseif index == 3 then
        lua_thread.create(function()
            if not (isSampLoaded() and isSampAvailable()) then return end
            sampSendChat('Сейчас я проведу Ваш обыск на наличие запрещенных предметов.')
            wait(1500)
            sampSendChat('Ваш обыск фиксируется нательную камеру ВДОЗОРВ.')
            wait(1500)
            local hour = os.date('%H')
            local min = os.date('%M')
            sampSendChat(string.format('Время обыска по местному времени: %s:%s.', hour, min))
            wait(1500)
            sampSendChat('/me надел резиновые перчатки, прохлопал по торсу, рукавам и ногам')
            wait(1500)
            -- Вставка команды /frisk в чат (без вложенного потока для безопасности)
            if not sampIsChatInputActive() and not sampIsDialogActive() and not isSampfuncsConsoleActive() then
                sampSetChatInputEnabled(true)
                wait(50)
                local old_buf = getClipboardText()
                setClipboardText('/frisk ')
                setVirtualKeyDown(17, true) -- Ctrl
                setVirtualKeyDown(86, true) -- V
                wait(10)
                setVirtualKeyDown(86, false)
                setVirtualKeyDown(17, false)
                wait(10)
                setClipboardText(old_buf)
            end
        end)
    elseif index == 4 then
        lua_thread.create(function()
            if not (isSampLoaded() and isSampAvailable()) then return end
            sampSendChat('/me открыв правый нагрудный карман достал от туда удостоверение')
            wait(1000)
            sampSendChat('/me раскрыв удостоверение, предъявил его человеку напротив на уровне глаз не передавая в руки')
            wait(1000)
            -- Вставка команды /doc в чат (без вложенного потока для безопасности)
            if not sampIsChatInputActive() and not sampIsDialogActive() and not isSampfuncsConsoleActive() then
                sampSetChatInputEnabled(true)
                wait(50)
                local old_buf = getClipboardText()
                setClipboardText('/doc ')
                setVirtualKeyDown(17, true) -- Ctrl
                setVirtualKeyDown(86, true) -- V
                wait(10)
                setVirtualKeyDown(86, false)
                setVirtualKeyDown(17, false)
                wait(10)
                setClipboardText(old_buf)
            end
        end)
    elseif index == 5 then
        lua_thread.create(function()
            if not (isSampLoaded() and isSampAvailable()) then return end
            sampSendChat('/me достал телефон из кармана, затем авторизовался в базе данных')
            wait(1500)
            sampSendChat('/do Телефон в руке.')
            wait(1500)
            sampSendChat('/me сделал фото подозреваемого, затем установил его личность по фотографии')
            wait(1500)
            sampSendChat('/do Личность установлена.')
        end)
    elseif index == 6 then
        lua_thread.create(function()
            if not (isSampLoaded() and isSampAvailable()) then return end
            sampSendChat('Сейчас измерим вашу тонировку.')
            wait(1500)
            sampSendChat('/me достал тауметр из кармана, затем включил его')
            wait(1500)
            sampSendChat('/do Прибор включен.')
            wait(1500)
            sampSendChat('/me приложил прибор к обоим сторонам стекла, затем посмотрел на дисплей')
            wait(1500)
            sampSendChat('/do Прибор показал затемнение больше 70 процентов.')
        end)
    end
end

-- ============================================================
-- УПРАВЛЕНИЕ КЛАВИШАМИ
-- ============================================================
local VK_NAMES = {
    [0x01] = "Левая кнопка мыши", [0x02] = "Правая кнопка мыши", [0x04] = "Средняя кнопка мыши",
    [0x05] = "Боковая кнопка мыши 1 (Назад)", [0x06] = "Боковая кнопка мыши 2 (Вперед)",
    [0x08] = "BACKSPACE", [0x09] = "TAB", [0x0D] = "ENTER", [0x10] = "SHIFT", [0x11] = "CTRL", [0x12] = "ALT",
    [0x13] = "PAUSE", [0x14] = "CAPS LOCK", [0x1B] = "ESCAPE", [0x20] = "SPACE",
    [0x21] = "PAGE UP", [0x22] = "PAGE DOWN", [0x23] = "END", [0x24] = "HOME",
    [0x25] = "Стрелка влево", [0x26] = "Стрелка вверх", [0x27] = "Стрелка вправо", [0x28] = "Стрелка вниз",
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

local function getShortcutName(shortcut_keys)
    if type(shortcut_keys) ~= "table" or #shortcut_keys == 0 then
        return "Не назначено"
    end

    local names = {}
    for _, vk_code in ipairs(shortcut_keys) do
        if vk_code and vk_code ~= 0 then
            local name = VK_NAMES[vk_code] or ("VK:"..tostring(vk_code))
            table.insert(names, name)
        end
    end

    if #names == 0 then
        return "Не назначено"
    end

    return table.concat(names, " + ")
end

-- Обратная совместимость
local function getKeyName(vk_code)
    if type(vk_code) == "table" then
        return getShortcutName(vk_code)
    elseif vk_code == 0 or not vk_code then
        return "Не назначено"
    else
        return VK_NAMES[vk_code] or ("VK:"..tostring(vk_code))
    end
end

local SAMP_RESERVED_KEYS = {
    [0x70] = "F1 (Помощь SAMP)",
    [0x71] = "F2 (Настройки)",
    [0x74] = "F5 (Чат)",
    [0x75] = "F6 (Список игроков)",
    [0x76] = "F7 (Радар)",
    [0x7A] = "F11 (Скрыть чат)",
    [0x09] = "TAB (Список игроков)",
    [0x0D] = "ENTER (Чат)",
    [0x54] = "T (Чат)",
}

-- Функция проверки комбинации клавиш
local function isShortcutPressed(shortcut_keys)
    if type(shortcut_keys) ~= "table" or #shortcut_keys == 0 then return false end

    -- Проверяем, что все клавиши, кроме последней, зажаты
    for i = 1, #shortcut_keys - 1 do
        if not isKeyDown(shortcut_keys[i]) then
            return false
        end
    end

    -- Последняя клавиша должна быть только что нажата
    return isKeyJustPressed(shortcut_keys[#shortcut_keys])
end

-- Функция проверки конфликтов комбинаций клавиш
local function isShortcutAlreadyUsed(shortcut_keys, exclude_rule_index)
    if type(shortcut_keys) ~= "table" or #shortcut_keys == 0 then return false end

    -- Проверка на SAMP клавиши
    for _, vk_code in ipairs(shortcut_keys) do
        if SAMP_RESERVED_KEYS[vk_code] then
            return true, "содержит зарезервированную SAMP клавишу: " .. SAMP_RESERVED_KEYS[vk_code]
        end
    end

    -- Проверка на глобальную клавишу
    if type(orule.config.globalHotkey) == "table" then
        if #shortcut_keys == #orule.config.globalHotkey then
            local match = true
            for i, key in ipairs(shortcut_keys) do
                if key ~= orule.config.globalHotkey[i] then
                    match = false
                    break
                end
            end
            if match then
                return true, "глобальной горячей клавишей"
            end
        end
    elseif orule.config.globalHotkey ~= 0 and #shortcut_keys == 1 and shortcut_keys[1] == orule.config.globalHotkey then
        return true, "глобальной горячей клавишей"
    end

    -- Проверка на клавиши правил
    for i, rule in ipairs(orule.rulesDB) do
        if i ~= exclude_rule_index and type(rule.key) == "table" and #rule.key > 0 then
            if #shortcut_keys == #rule.key then
                local match = true
                for j, key in ipairs(shortcut_keys) do
                    if key ~= rule.key[j] then
                        match = false
                        break
                    end
                end
                if match then
                    return true, 'правилом "' .. rule.name .. '"'
                end
            end
        elseif i ~= exclude_rule_index and type(rule.key) ~= "table" and rule.key ~= 0 and #shortcut_keys == 1 and shortcut_keys[1] == rule.key then
            return true, 'правилом "' .. rule.name .. '"'
        end
    end

    return false
end

local function isKeyAlreadyUsed(vk_code, exclude_rule_index)
    if type(vk_code) == "table" then
        return isShortcutAlreadyUsed(vk_code, exclude_rule_index)
    elseif vk_code == 0 or not vk_code then
        return false
    else
        return isShortcutAlreadyUsed({vk_code}, exclude_rule_index)
    end
end

-- ============================================================
-- РЕНДЕР ТЕКСТА
-- ============================================================
local color_cache = {}
local function getColorFromHex(hex)
    if not color_cache[hex] then
        local r = tonumber(hex:sub(1, 2), 16) / 255.0
        local g = tonumber(hex:sub(3, 4), 16) / 255.0
        local b = tonumber(hex:sub(5, 6), 16) / 255.0
        color_cache[hex] = imgui.ImVec4(r, g, b, 1.0)
    end
    return color_cache[hex]
end

local function renderFormattedText(text)
    -- #region agent log
    local file = io.open("c:\\Games\\CyberRussia\\gtacr\\moonloader\\.cursor\\debug.log", "a")
    if file then
        local timestamp = os.time()
        file:write(string.format('{"id":"log_%d","timestamp":%d,"location":"renderFormattedText","message":"renderFormattedText called","data":{"text_length":%d},"sessionId":"debug-session","runId":"perf-test","hypothesisId":"PERF_001"}\n', timestamp, timestamp*1000, #text))
        file:close()
    end
    -- #endregion

    local default_color_vec = imgui.ImVec4(1.0, 1.0, 1.0, 1.0)
    local line_height = imgui.GetTextLineHeight()
    local space_width = imgui.CalcTextSize(' ').x
    local window_pos = imgui.GetCursorScreenPos()
    local line_width = imgui.GetWindowContentRegionMax().x - imgui.GetStyle().WindowPadding.x
    local current_pos = imgui.ImVec2(window_pos.x, window_pos.y)
    local line_spacing = (orule.config.lineSpacing or 0.1) * line_height

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

            current_color = getColorFromHex(hex)
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

    -- #region agent log
    local file2 = io.open("c:\\Games\\CyberRussia\\gtacr\\moonloader\\.cursor\\debug.log", "a")
    if file2 then
        local timestamp2 = os.time()
        file2:write(string.format('{"id":"log_%d","timestamp":%d,"location":"renderFormattedText","message":"renderFormattedText completed","data":{"lines_processed":%d},"sessionId":"debug-session","runId":"perf-test","hypothesisId":"PERF_001"}\n', timestamp2, timestamp2*1000, #lines))
        file2:close()
    end
    -- #endregion
end

-- ============================================================
-- КОНФИГУРАЦИЯ
-- ============================================================
local function saveConfig()
    local file = io.open(orule.CONFIG_FILE, "w")
    if not file then
        local error_msg = "[ORULE] Ошибка: Не удалось открыть файл настроек для записи!"
        sampAddChatMessage(error_msg, 0xFF0000)
        logError("saveConfig: Failed to open config file for writing: " .. orule.CONFIG_FILE)
        return
    end
    
    file:write("config_version:1\n")
    file:write("command:" .. (orule.config.command or "orule") .. "\n")
    if type(orule.config.globalHotkey) == "table" then
        file:write("globalHotkey:" .. table.concat(orule.config.globalHotkey, ",") .. "\n")
    else
        file:write("globalHotkey:" .. tostring(orule.config.globalHotkey or 0) .. "\n")
    end
    file:write("overlayBgAlpha:" .. tostring(orule.config.overlayBgAlpha or 0.85) .. "\n")
    file:write("fontSize:" .. tostring(orule.config.fontSize or 18.0) .. "\n")
    file:write("lineSpacing:" .. tostring(orule.config.lineSpacing or 0.1) .. "\n")
    file:write("windowWidth:" .. tostring(orule.config.windowWidth or 820) .. "\n")
    file:write("windowHeight:" .. tostring(orule.config.windowHeight or 800) .. "\n")
    file:write("ruleCardHeight:" .. tostring(orule.config.ruleCardHeight or 183) .. "\n")
    file:write("firstLaunch:" .. tostring(orule.config.firstLaunch and "1" or "0") .. "\n")
    file:write("radialMenuEnabled:" .. tostring(radialMenu.globalEnabled and "1" or "0") .. "\n")
    file:write("autoUpdateTexts:" .. tostring(orule.config.autoUpdateTexts and "1" or "0") .. "\n")
    for i, btn in ipairs(radialMenu.buttons) do
        file:write("radialButton_" .. i .. "_name:" .. (btn.name or "") .. "\n")
        file:write("radialButton_" .. i .. "_enabled:" .. tostring(btn.enabled and "1" or "0") .. "\n")
    end
    
    for i, rule in ipairs(orule.rulesDB) do
        if type(rule.key) == "table" then
            file:write("rule_" .. i .. "_key:" .. table.concat(rule.key, ",") .. "\n")
        else
            file:write("rule_" .. i .. "_key:" .. tostring(rule.key or 0) .. "\n")
        end
        file:write("rule_" .. i .. "_holdMode:" .. tostring(rule.holdMode and "1" or "0") .. "\n")
    end
    
    file:close()
end

local function ensureDirectories()
    if not doesDirectoryExist(orule.SCRIPT_DIR) then createDirectory(orule.SCRIPT_DIR) end
    if not doesDirectoryExist(orule.FONTS_DIR) then createDirectory(orule.FONTS_DIR) end
    if not doesDirectoryExist(orule.IMAGES_DIR) then createDirectory(orule.IMAGES_DIR) end
    if not doesDirectoryExist(orule.TEXTS_DIR) then createDirectory(orule.TEXTS_DIR) end
end

local function clearTextCache()
    orule.text_cache = {}
end

local function loadTextFromFile(filename)
    if orule.text_cache[filename] then return orule.text_cache[filename] end
    
    local filepath = orule.TEXTS_DIR .. '\\' .. filename
    
    if not doesFileExist(filepath) then
        return "{FF0000}Ошибка: текст не найден.\n{FFFFFF}Проверьте наличие файла " .. filename .. " в папке texts/"
    end
    
    local file = io.open(filepath, 'rb')
    if not file then
        return "{FF0000}Ошибка: не удалось открыть файл " .. filename
    end
    
    local success, content = pcall(file.read, file, '*a')
    file:close() -- ЗАКРЫВАЕМ ВСЕГДА
    
    if not success or not content then
        return "{FF0000}Ошибка чтения файла " .. filename
    end
    
    -- Обработка BOM и кодировок
    if content:sub(1, 3) == '\xEF\xBB\xBF' then
        content = content:sub(4)
        local decode_success, decoded = pcall(encoding.UTF8.decode, encoding.UTF8, content)
        if decode_success then
            content = decoded
        end
    else
        local is_utf8 = content:find('[\xD0-\xD1][\x80-\xBF]')
        if is_utf8 then
            local decode_success, decoded = pcall(encoding.UTF8.decode, encoding.UTF8, content)
            if decode_success then content = decoded end
        end
    end
    
    orule.text_cache[filename] = content
    return content
end

-- ============================================================
-- ПОИСК
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
        imgui.TextColored(imgui.ImVec4(1.0, 0.5, 0.5, 1.0), u8'Ничего не найдено')
        imgui.Spacing()
        imgui.TextColored(imgui.ImVec4(0.7, 0.7, 0.75, 1.0), u8'Попробуйте:')
        imgui.BulletText(u8'Использовать другие слова или синонимы')
        imgui.BulletText(u8'Проверить правильность написания')
        imgui.BulletText(u8'Использовать более короткий запрос')
        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()
        imgui.PushTextWrapPos(0)
        renderFormattedText(full_text)
        imgui.PopTextWrapPos()
        return
    end
    
    imgui.TextColored(imgui.ImVec4(0.5, 1.0, 0.5, 1.0), u8(string.format('Найдено: %d', #results)))
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
            imgui.Text(u8(string.format('Результат #%d', i)))
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

    local file = io.open(orule.CONFIG_FILE, "r")
    if not file then
        -- Файл настроек не найден - это нормально при первом запуске
        -- Не показываем ошибку пользователю, но логируем для отладки
        logError("loadConfig: Config file not found (first run?): " .. orule.CONFIG_FILE)
        return
    end

    for line in file:lines() do
        local cmd = line:match("^command:(.+)")
        if cmd then orule.config.command = cmd end

        local ghk = line:match("^globalHotkey:(.+)")
        if ghk then
            -- Проверяем, содержит ли строка запятые (массив клавиш)
            if string.find(ghk, ",") then
                local key_array = {}
                for key_str in string.gmatch(ghk, "[^,]+") do
                    local key_num = tonumber(key_str)
                    if key_num and key_num > 0 then
                        table.insert(key_array, key_num)
                    end
                end
                if #key_array > 0 then
                    orule.config.globalHotkey = key_array
                else
                    orule.config.globalHotkey = 0
                end
            else
                -- Одиночная клавиша (для обратной совместимости)
                orule.config.globalHotkey = tonumber(ghk) or 0
            end
        end

        local alpha = line:match("^overlayBgAlpha:(.+)")
        if alpha then orule.config.overlayBgAlpha = tonumber(alpha) or 0.85 end

        local fsize = line:match("^fontSize:(.+)")
        if fsize then orule.config.fontSize = tonumber(fsize) or 18.0 end

        local lspace = line:match("^lineSpacing:(.+)")
        if lspace then orule.config.lineSpacing = tonumber(lspace) or 0.1 end

        local wwidth = line:match("^windowWidth:(.+)")
        if wwidth then orule.config.windowWidth = tonumber(wwidth) or 820 end

        local wheight = line:match("^windowHeight:(.+)")
        if wheight then orule.config.windowHeight = tonumber(wheight) or 800 end

        local rcheight = line:match("^ruleCardHeight:(.+)")
        if rcheight then orule.config.ruleCardHeight = 183 end

        local first_launch = line:match("^firstLaunch:(.+)")
        if first_launch then
            orule.config.firstLaunch = (first_launch == "1")
        end

        local radial_enabled = line:match("^radialMenuEnabled:(.+)")
        if radial_enabled then
            radialMenu.globalEnabled = (radial_enabled == "1")
        end

        local auto_update_texts = line:match("^autoUpdateTexts:(.+)")
        if auto_update_texts then
            orule.config.autoUpdateTexts = (auto_update_texts == "1")
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
        if r_idx and orule.rulesDB[tonumber(r_idx)] then
            -- Проверяем, содержит ли строка запятые (массив клавиш)
            if string.find(r_key, ",") then
                local key_array = {}
                for key_str in string.gmatch(r_key, "[^,]+") do
                    local key_num = tonumber(key_str)
                    if key_num and key_num > 0 then
                        table.insert(key_array, key_num)
                    end
                end
                if #key_array > 0 then
                    orule.rulesDB[tonumber(r_idx)].key = key_array
                    orule.rulesDB[tonumber(r_idx)].keyName = getShortcutName(key_array)
                end
            else
                -- Одиночная клавиша (для обратной совместимости)
                local key_val = tonumber(r_key) or 0
                orule.rulesDB[tonumber(r_idx)].key = key_val
                orule.rulesDB[tonumber(r_idx)].keyName = getKeyName(key_val)
            end
        end

        local h_idx, h_mode = line:match("^rule_(%d+)_holdMode:(.+)")
        if h_idx and orule.rulesDB[tonumber(h_idx)] then
            orule.rulesDB[tonumber(h_idx)].holdMode = (h_mode == "1")
        end
    end
    file:close()
    
    if orule.config.command then
        ffi.fill(commandBuf, 32, 0)
        ffi.copy(commandBuf, orule.config.command, math.min(#orule.config.command, 31))
    end
    
    orule.config.ruleCardHeight = 183
    saveConfig()
end

local function initRadialBuffers()
    for i, btn in ipairs(radialMenu.buttons) do
        local name_cp1251 = btn.name or ("Кнопка " .. i)
        -- Конвертируем CP1251 ? UTF-8 для ImGui
        local name_utf8 = u8(name_cp1251)
        ffi.copy(radialButtonBuffers[i], name_utf8, math.min(#name_utf8, 63))
    end
end

-- ============================================================
-- ПРАВИЛА
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
    orule.rulesDB = {
        {name = "Правила для полицейских", updateDate = "08.11.2025", key = {}, keyName = "Не назначено", holdMode = false},
        {name = "Законодательная база", updateDate = "08.11.2025", key = {}, keyName = "Не назначено", holdMode = false},
        {name = "ФЗ \"О закрытых и охраняемых территориях\"", updateDate = "08.11.2025", key = {}, keyName = "Не назначено", holdMode = false},
        {name = "ФЗ \"О системе нормативно-правовых актов Нижегородской области\"", updateDate = "08.11.2025", key = {}, keyName = "Не назначено", holdMode = false},
        {name = "Уголовно-процессуальный кодекс", updateDate = "08.11.2025", key = {}, keyName = "Не назначено", holdMode = false},
        {name = "Трудовой кодекс", updateDate = "08.11.2025", key = {}, keyName = "Не назначено", holdMode = false},
        {name = "Министерство Внутренних Дел | Справочник Сотрудника", updateDate = "08.11.2025", key = {}, keyName = "Не назначено", holdMode = false},
        {name = "Министерство Внутренних дел | Правила строевого устава", updateDate = "08.11.2025", key = {}, keyName = "Не назначено", holdMode = false},
        {name = "Министерство Внутренних Дел | Устав", updateDate = "08.11.2025", key = {}, keyName = "Не назначено", holdMode = false}
    }
end

local function loadAllRules()
    clearTextCache()
    initStaticRules()
    loadConfig()
    initRadialBuffers()
end

-- ============================================================
-- СТИЛИ
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
    local font_path = orule.FONTS_DIR .. '\\EagleSans-Regular.ttf'
    
    if doesFileExist(font_path) then
        local ranges = io.Fonts:GetGlyphRangesCyrillic()
        main_font = io.Fonts:AddFontFromFileTTF(font_path, 17.0, nil, ranges)
        title_font = io.Fonts:AddFontFromFileTTF(font_path, 22.0, nil, ranges)
    end
    
    local radar_map_path = orule.IMAGES_DIR .. '\\radar_map.png'
    if doesFileExist(radar_map_path) then
        radar_map_texture = imgui.CreateTextureFromFile(radar_map_path)
        if not radar_map_texture then
            print('[ORULE] Ошибка загрузки текстуры: radar_map.png')
        end
    end

    for i = 1, 20 do
        local ter_path = orule.IMAGES_DIR .. '\\ter_' .. i .. '.jpg'
        if doesFileExist(ter_path) then
            territory_textures[i] = imgui.CreateTextureFromFile(ter_path)
            if not territory_textures[i] then
                print('[ORULE] Ошибка загрузки текстуры: ter_' .. i .. '.jpg')
            end
        end
    end
end)

-- ============================================================
-- OVERLAY ИНТЕРФЕЙС
-- ============================================================
imgui.OnFrame(
    function() return overlay_visible end,
    function(this)
        local sw, sh = getScreenResolution()
        
        local bg_color_struct = imgui.ImVec4(0, 0, 0, orule.config.overlayBgAlpha)
        local bg_color_u32 = imgui.ColorConvertFloat4ToU32(bg_color_struct)
        imgui.GetBackgroundDrawList():AddRectFilled(imgui.ImVec2(0, 0), imgui.ImVec2(sw, sh), bg_color_u32)
        
        local rule = orule.rulesDB[overlay_rule_index]
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
                    imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.75, 1.0), u8('Последнее обновление: ' .. rule.updateDate))
                end
                
                -- Вкладки для правил полиции
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
                        
                        local labels = {u8'Правила для полицейских', u8'Правила использования радара', u8'Порядок снятия масок', u8'Регламент проверки тонировки'}
                        if imgui.Button(labels[i+1]..'##police_tab_'..i, imgui.ImVec2(button_width, 30)) then
                            policeRuleActiveTab[0] = i
                        end
                        
                        if current_tab == i then imgui.PopStyleColor(3) end
                    end
                    imgui.Spacing()
                end
                
                -- Вкладки для законодательной базы
                if overlay_rule_index == 2 then
                    imgui.Spacing()
                    local avail_width = imgui.GetContentRegionAvail().x
                    local spacing = imgui.GetStyle().ItemSpacing.x
                    local button_width = (avail_width - spacing * 2) / 3
                    
                    local active_color = imgui.ImVec4(0.50, 0.45, 1.00, 1.00)
                    local current_tab = legalBaseActiveTab[0] or 0
                    
                    local button_texts = {
                        u8'КОНСТИТУЦИЯ', u8'ФЕДЕРАЛЬНОЕ ПОСТАНОВЛЕНИЕ', u8'УГОЛОВНЫЙ КОДЕКС',
                        u8'КоАП', u8'ЗАКОН О ПОЛИЦИИ', u8'ЗАКОН О ФСБ'
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
                
                -- Вкладки для территорий
                if overlay_rule_index == 3 then
                    imgui.Spacing()
                    local avail_width = imgui.GetContentRegionAvail().x
                    local spacing = imgui.GetStyle().ItemSpacing.x
                    local button_width = (avail_width - spacing * 2) / 3
                    
                    local active_color = imgui.ImVec4(0.50, 0.45, 1.00, 1.00)
                    local current_tab = territoryActiveTab[0] or 0
                    
                    local button_texts = {
                        u8'Основные положения', u8'МВД', u8'ФСБ', u8'АРМИЯ', u8'ФСИН',
                        u8'МЧС', u8'БОЛЬНИЦА', u8'СМИ', u8'ПРАВИТЕЛЬСТВО'
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
                imgui.SetWindowFontScale(orule.config.fontSize / 17.0)
                
                -- Загрузка текста
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

                if not full_text or #full_text == 0 or full_text:match("^{FF0000}Ошибка") then
                    full_text = "{FF6B6B}Ошибка загрузки текста.\n{FFFFFF}Проверьте наличие файлов в папке texts/"
                end
                
                -- Поле поиска
                imgui.PushStyleColor(imgui.Col.FrameBg, imgui.ImVec4(0.15, 0.15, 0.18, 0.95))
                imgui.PushStyleColor(imgui.Col.FrameBgHovered, imgui.ImVec4(0.20, 0.20, 0.24, 0.95))
                imgui.PushStyleColor(imgui.Col.FrameBgActive, imgui.ImVec4(0.25, 0.25, 0.30, 0.95))
                imgui.PushItemWidth(-1)
                imgui.InputTextWithHint('##search_overlay', u8'Поиск по тексту...', search_buffer, 256)
                imgui.PopItemWidth()
                imgui.PopStyleColor(3)

                imgui.Spacing()
                imgui.Spacing()

                if full_text and #full_text > 0 then
                    -- #region agent log
                    local file3 = io.open("c:\\Games\\CyberRussia\\gtacr\\moonloader\\.cursor\\debug.log", "a")
                    if file3 then
                        local timestamp3 = os.time()
                        file3:write(string.format('{"id":"log_%d","timestamp":%d,"location":"overlay_render","message":"renderSearchResults called","data":{"text_length":%d},"sessionId":"debug-session","runId":"perf-test","hypothesisId":"PERF_002"}\n', timestamp3, timestamp3*1000, #full_text))
                        file3:close()
                    end
                    -- #endregion

                    local query = ffi.string(search_buffer)
                    renderSearchResults(full_text, query)
                end
                
                -- Фотографии территорий МВД
                if overlay_rule_index == 3 and territoryActiveTab[0] == 1 then
                    imgui.Spacing()
                    imgui.Spacing()
                    if imgui.CollapsingHeader(u8'Фотографии##territory_mvd_photos') then
                        local window_width = imgui.GetWindowWidth()
                        local spacing = imgui.GetStyle().ItemSpacing.x
                        local padding = imgui.GetStyle().WindowPadding.x * 2
                        local avail_width = window_width - padding
                        local images_per_row = 3
                        local image_width = math.floor((avail_width - spacing * (images_per_row - 1)) / images_per_row)
                        local image_height = math.floor(image_width * 0.57)
                        
                        for i = 1, 6 do
                            if i > 1 and (i - 1) % images_per_row ~= 0 then imgui.SameLine() end
                            if territory_textures[i] and imgui.IsTextureValid(territory_textures[i]) then
                                pcall(function() imgui.Image(territory_textures[i], imgui.ImVec2(image_width, image_height)) end)
                            else
                                imgui.TextColored(imgui.ImVec4(1.0, 0.0, 0.0, 1.0), u8('Ошибка: ter_' .. i .. '.jpg'))
                            end
                            if i % images_per_row == 0 and i < 6 then imgui.Spacing() end
                        end
                    end
                end
                
                -- Фотографии территорий ФСБ
                if overlay_rule_index == 3 and territoryActiveTab[0] == 2 then
                    imgui.Spacing()
                    imgui.Spacing()
                    if imgui.CollapsingHeader(u8'Фотографии##territory_fsb_photos') then
                        if territory_textures[7] and imgui.IsTextureValid(territory_textures[7]) then
                            local window_width = imgui.GetWindowWidth()
                            local spacing = imgui.GetStyle().ItemSpacing.x
                            local padding = imgui.GetStyle().WindowPadding.x * 2
                            local avail_width = window_width - padding
                            local images_per_row = 3
                            local image_width = math.floor((avail_width - spacing * (images_per_row - 1)) / images_per_row)
                            local image_height = math.floor(image_width * 0.57)
                            pcall(function() imgui.Image(territory_textures[7], imgui.ImVec2(image_width, image_height)) end)
                        else
                            imgui.TextColored(imgui.ImVec4(1.0, 0.0, 0.0, 1.0), u8'Ошибка: Фотография ter_7.jpg не найдена!')
                        end
                    end
                end
                
                -- Фотографии территорий АРМИЯ
                if overlay_rule_index == 3 and territoryActiveTab[0] == 3 then
                    imgui.Spacing()
                    imgui.Spacing()
                    if imgui.CollapsingHeader(u8'Фотографии##territory_army_photos') then
                        if territory_textures[8] and imgui.IsTextureValid(territory_textures[8]) then
                            local window_width = imgui.GetWindowWidth()
                            local spacing = imgui.GetStyle().ItemSpacing.x
                            local padding = imgui.GetStyle().WindowPadding.x * 2
                            local avail_width = window_width - padding
                            local images_per_row = 3
                            local image_width = math.floor((avail_width - spacing * (images_per_row - 1)) / images_per_row)
                            local image_height = math.floor(image_width * 0.57)
                            pcall(function() imgui.Image(territory_textures[8], imgui.ImVec2(image_width, image_height)) end)
                        else
                            imgui.TextColored(imgui.ImVec4(1.0, 0.0, 0.0, 1.0), u8'Ошибка: Фотография ter_8.jpg не найдена!')
                        end
                    end
                end
                
                -- Фотографии территорий МЧС
                if overlay_rule_index == 3 and territoryActiveTab[0] == 5 then
                    imgui.Spacing()
                    imgui.Spacing()
                    if imgui.CollapsingHeader(u8'Фотографии##territory_mchs_photos') then
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
                            if territory_textures[i] and imgui.IsTextureValid(territory_textures[i]) then
                                pcall(function() imgui.Image(territory_textures[i], imgui.ImVec2(image_width, image_height)) end)
                            else
                                imgui.TextColored(imgui.ImVec4(1.0, 0.0, 0.0, 1.0), u8('Ошибка: ter_' .. i .. '.jpg'))
                            end
                            if idx % images_per_row == 0 and i < 12 then imgui.Spacing() end
                        end
                    end
                end
                
                -- Фотографии больницы
                if overlay_rule_index == 3 and territoryActiveTab[0] == 6 then
                    imgui.Spacing()
                    imgui.Spacing()
                    if imgui.CollapsingHeader(u8'Фотографии##territory_hospital_photos') then
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
                            if territory_textures[i] and imgui.IsTextureValid(territory_textures[i]) then
                                pcall(function() imgui.Image(territory_textures[i], imgui.ImVec2(image_width, image_height)) end)
                            else
                                imgui.TextColored(imgui.ImVec4(1.0, 0.0, 0.0, 1.0), u8('Ошибка: ter_' .. i .. '.jpg'))
                            end
                            if idx % images_per_row == 0 and i < 15 then imgui.Spacing() end
                        end
                    end
                end
                
                -- Фотографии СМИ
                if overlay_rule_index == 3 and territoryActiveTab[0] == 7 then
                    imgui.Spacing()
                    imgui.Spacing()
                    if imgui.CollapsingHeader(u8'Фотографии##territory_smi_photos') then
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
                            if territory_textures[i] and imgui.IsTextureValid(territory_textures[i]) then
                                pcall(function() imgui.Image(territory_textures[i], imgui.ImVec2(image_width, image_height)) end)
                            else
                                imgui.TextColored(imgui.ImVec4(1.0, 0.0, 0.0, 1.0), u8('Ошибка: ter_' .. i .. '.jpg'))
                            end
                        end
                    end
                end
                
                -- Фотографии правительства
                if overlay_rule_index == 3 and territoryActiveTab[0] == 8 then
                    imgui.Spacing()
                    imgui.Spacing()
                    if imgui.CollapsingHeader(u8'Фотографии##territory_government_photos') then
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
                            if territory_textures[i] and imgui.IsTextureValid(territory_textures[i]) then
                                pcall(function() imgui.Image(territory_textures[i], imgui.ImVec2(image_width, image_height)) end)
                            else
                                imgui.TextColored(imgui.ImVec4(1.0, 0.0, 0.0, 1.0), u8('Ошибка: ter_' .. i .. '.jpg'))
                            end
                            if idx % images_per_row == 0 and i < 20 then imgui.Spacing() end
                        end
                    end
                end
                
                -- Карта радаров
                if overlay_rule_index == 1 and policeRuleActiveTab[0] == 1 then
                    imgui.Spacing()
                    imgui.Spacing()
                    if imgui.CollapsingHeader(u8'Карта радаров##radar_map') then
                        if radar_map_texture and imgui.IsTextureValid(radar_map_texture) then
                            local avail_width = imgui.GetContentRegionAvail().x
                            local image_width = avail_width * 0.95
                            local image_height = image_width * 0.75
                            pcall(function() imgui.Image(radar_map_texture, imgui.ImVec2(image_width, image_height)) end)
                        else
                            imgui.TextColored(imgui.ImVec4(1.0, 0.0, 0.0, 1.0), u8'Ошибка: Карта радаров не найдена!')
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
-- ВКЛАДКА ПРАВИЛ
-- ============================================================
local function renderRulesTab()
    local is_capturing_any = (key_capture_mode ~= nil)
    
    imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8'Список правил')
    imgui.Spacing()
    imgui.Spacing()
    
    for i, rule in ipairs(orule.rulesDB) do
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
        
        if imgui.BeginChild('##rule_card_' .. i, imgui.ImVec2(-20, orule.config.ruleCardHeight), true) then
            imgui.Spacing()
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.95, 0.95, 1.00, 1.00))
            imgui.Text(u8(rule.name or 'Без названия'))
            imgui.PopStyleColor(1)
            
            if rule.updateDate then
                imgui.Spacing()
                imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.75, 0.90), u8'Последнее обновление: ')
                imgui.SameLine(0, 5)
                imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 0.70), u8(rule.updateDate))
            end
            
            imgui.Spacing()
            
            local key_name = getKeyName(rule.key)
            local has_key = (type(rule.key) == "table" and #rule.key > 0) or (type(rule.key) ~= "table" and rule.key > 0)
            local key_color = not has_key and imgui.ImVec4(0.60, 0.60, 0.65, 0.70) or imgui.ImVec4(0.50, 0.45, 1.00, 0.90)
            imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8'Клавиша: ')
            imgui.SameLine(0, 5)
            imgui.TextColored(key_color, u8(key_name))
            
            imgui.Spacing()
            
            local button_height = 32
            local window_width = imgui.GetWindowWidth()
            local padding = imgui.GetStyle().WindowPadding.x * 2
            local avail_width = window_width - padding - 24
            local spacing = imgui.GetStyle().ItemSpacing.x
            
            local holdModeText = rule.holdMode and u8'Удержание' or u8'Без удержания'
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

            local bind_text = is_capturing_this and u8'Нажмите клавишу или комбинацию... (Backspace отмена)' or u8'Назначить клавишу'
            
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
            
            if (type(rule.key) == "table" and #rule.key > 0) or (type(rule.key) ~= "table" and rule.key > 0) then
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
                if imgui.Button(u8'Сбросить клавишу##reset_'..i, imgui.ImVec2(button_width_reset, button_height)) and not is_capturing_any then
                    rule.key = {}
                    rule.keyName = "Не назначено"
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

    imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8'Настройки радиального меню')
    imgui.Spacing()
    imgui.Spacing()

    if is_capturing_any then
        imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, 0.5)
    end

    imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.11, 0.11, 0.13, 1.00))
    imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.30, 0.30, 0.35, 0.50))
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 6.0)
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildBorderSize, 1.5)

    if imgui.BeginChild('##radial_global_settings', imgui.ImVec2(-20, 118), true) then
        imgui.Spacing()
        imgui.TextColored(imgui.ImVec4(0.95, 0.95, 1.00, 1.00), u8'Глобальные настройки')
        imgui.Spacing()

        local enabled_checkbox = imgui.new.bool(radialMenu.globalEnabled)
        if imgui.Checkbox(u8'Включить радиальное меню (средняя кнопка мыши)', enabled_checkbox) and not is_capturing_any then
            radialMenu.globalEnabled = enabled_checkbox[0]
            saveConfig()
        end

        if imgui.IsItemHovered() then
            imgui.SetTooltip(u8'При отключении радиальное меню не будет открываться')
        end

        imgui.Spacing()
    end
    imgui.EndChild()
    imgui.PopStyleVar(2)
    imgui.PopStyleColor(2)

    imgui.Spacing()
    imgui.Spacing()

    imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8'Настройка кнопок радиального меню')
    imgui.Spacing()
    imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8'Всего доступно 6 кнопок. Можно менять названия и включать/выключать их.')
    imgui.Spacing()
    imgui.Spacing()

    for i, btn in ipairs(radialMenu.buttons) do
        local card_bg = imgui.ImVec4(0.11, 0.11, 0.13, 1.00)
        local card_border = imgui.ImVec4(0.30, 0.30, 0.35, 0.50)

        imgui.PushStyleColor(imgui.Col.ChildBg, card_bg)
        imgui.PushStyleColor(imgui.Col.Border, card_border)
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 6.0)
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildBorderSize, 1.5)

        if imgui.BeginChild('##radial_button_card_' .. i, imgui.ImVec2(-20, 167), true) then
            imgui.Spacing()
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.95, 0.95, 1.00, 1.00))
            imgui.Text(u8('Кнопка #' .. i))
            imgui.PopStyleColor(1)
            imgui.Spacing()

            local btn_enabled = imgui.new.bool(btn.enabled)
            if imgui.Checkbox(u8('Включена##btn_' .. i), btn_enabled) and not is_capturing_any then
                btn.enabled = btn_enabled[0]
                saveConfig()
            end

            imgui.Spacing()
            imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8'Название:')
            imgui.SameLine()
            imgui.PushItemWidth(-100)

            -- InputText в реальном времени обновляет буфер
            imgui.InputText('##radial_btn_name_' .. i, radialButtonBuffers[i], 64)

            imgui.PopItemWidth()
            imgui.SameLine()

            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.50, 0.45, 1.00, 0.80))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.60, 0.55, 1.00, 0.90))
            imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.40, 0.35, 0.90, 1.00))
            if imgui.Button(u8'Сохранить##save_btn_' .. i, imgui.ImVec2(90, 0)) and not is_capturing_any then
                -- Читаем из буфера (UTF-8 от ImGui)
                local new_name_utf8 = ffi.string(radialButtonBuffers[i])
                -- Конвертируем UTF-8 ? CP1251 для сохранения
                local new_name_cp1251 = encoding.UTF8:decode(new_name_utf8)
                
                if #new_name_cp1251 > 0 and #new_name_cp1251 <= 63 then
                    btn.name = new_name_cp1251
                    saveConfig()
                    -- После сохранения обновляем буфер
                    local name_utf8_updated = u8(new_name_cp1251)
                    ffi.copy(radialButtonBuffers[i], name_utf8_updated, math.min(#name_utf8_updated, 63))
                    sampAddChatMessage('[ORULE] Название кнопки #' .. i .. ' сохранено!', 0x00FF00)
                else
                    sampAddChatMessage('[ORULE] Ошибка: название не может быть пустым или слишком длинным', 0xFF0000)
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
    if imgui.BeginChild('##radial_info', imgui.ImVec2(-20, 499), true) then
        imgui.Spacing()
        imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8'Информация о действиях кнопок')
        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        local descriptions = {
            u8'Предупреждение водителю через громкоговоритель',
            u8'Чтение прав задержанному (Миранда)',
            u8'Проведение обыска с нательной камерой и /frisk',
            u8'Предъявление служебного удостоверения и /doc',
            u8'Установление личности по фотографии',
            u8'Проверка тонировки тауметром'
        }

        for i, desc in ipairs(descriptions) do
            imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.90, 1.00), u8('Кнопка #' .. i .. ':'))
            imgui.BulletText(desc)
            imgui.Spacing()
        end

        imgui.Separator()
        imgui.Spacing()
        imgui.PushTextWrapPos(0)
        imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.75, 0.90), u8'Примечание: Изменение названия кнопки влияет только на отображение в меню и не меняет действие.')
        imgui.PopTextWrapPos()
        imgui.Spacing()
    end
    imgui.EndChild()
    imgui.PopStyleVar(1)
    imgui.PopStyleColor(1)
end

-- ============================================================
-- ВКЛАДКА НАСТРОЕК
-- ============================================================
local function validateCommand(cmd)
    if not cmd or #cmd == 0 then return false, "Команда не может быть пустой" end
    if #cmd > 31 then return false, "Команда слишком длинная (макс. 31 символ)" end
    if cmd:match("[^%w_]") then return false, "Команда может содержать только буквы, цифры и _" end
    return true
end

local function renderSettingsTab()
    local is_capturing_any = (key_capture_mode ~= nil)
    local is_capturing_global = (key_capture_type == "global")
    local disabled_color = imgui.ImVec4(0.30, 0.30, 0.35, 0.60)

    imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8'Команда активации')
    imgui.Spacing()

    if is_capturing_any and not is_capturing_global then
        imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, 0.5)
    end
    
    imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.90, 1.00), u8'Команда для открытия меню:')
    imgui.Spacing()
    
    imgui.PushItemWidth(-20)
    imgui.InputText('##command', commandBuf, 32)
    imgui.PopItemWidth()
    if imgui.IsItemHovered() then 
        imgui.SetTooltip(u8'Команда для открытия меню (например: /orule)') 
    end
    
    if is_capturing_any and not is_capturing_global then
        imgui.PopStyleVar(1)
    end
    
    imgui.Spacing()
    imgui.Spacing()
    
    imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8'Горячие клавиши')
    imgui.Spacing()
    
    local bind_text_global = is_capturing_global and u8'Нажмите клавишу или комбинацию... (Backspace отмена)' or (u8'Клавиша: '..u8(getKeyName(orule.config.globalHotkey))..u8' (нажмите для изменения)')
    local is_blocked_global = is_capturing_any and not is_capturing_global
    
    imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.90, 1.00), u8'Глобальная горячая клавиша для меню:')
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
    
    if imgui.Button(bind_text_global, imgui.ImVec2(-20, 40)) and not is_blocked_global and not is_capturing_global then
        key_capture_mode, key_capture_type = {}, "global"
    end
    imgui.PopStyleColor(3)
    
    if imgui.IsItemHovered() then 
        imgui.SetTooltip(u8'Горячая клавиша для быстрого открытия меню (0 = отключена)') 
    end
    
    imgui.Spacing()
    
    if (type(orule.config.globalHotkey) == "table" and #orule.config.globalHotkey > 0) or (type(orule.config.globalHotkey) ~= "table" and orule.config.globalHotkey > 0) then
        if is_capturing_any then
            imgui.PushStyleColor(imgui.Col.Button, disabled_color)
            imgui.PushStyleColor(imgui.Col.ButtonHovered, disabled_color)
            imgui.PushStyleColor(imgui.Col.ButtonActive, disabled_color)
        else
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.80, 0.30, 0.30, 0.80))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.90, 0.35, 0.35, 0.90))
            imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.70, 0.25, 0.25, 1.00))
        end
        
        if imgui.Button(u8'Сбросить клавишу##reset_global', imgui.ImVec2(-20, 40)) and not is_capturing_any then
            orule.config.globalHotkey = {}
            saveConfig()
        end
        imgui.PopStyleColor(3)
    end
    
    imgui.Spacing()
    imgui.Spacing()
    
    imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8'Настройки отображения overlay')
    imgui.Spacing()
    
    if is_capturing_any then
        imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, 0.5)
    end

    imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.90, 1.00), u8'Прозрачность фона:')
    local alpha_val = imgui.new.float[1](orule.config.overlayBgAlpha)
    imgui.PushItemWidth(-20)
    if imgui.SliderFloat('##alpha', alpha_val, 0.0, 1.0, u8'%.2f') and not is_capturing_any then
        orule.config.overlayBgAlpha = alpha_val[0]
        saveConfig() 
    end
    imgui.PopItemWidth()
    
    imgui.Spacing()
    imgui.Spacing()
    
    imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.90, 1.00), u8'Размер шрифта:')
    local font_val = imgui.new.float[1](orule.config.fontSize)
    imgui.PushItemWidth(-20)
    if imgui.SliderFloat('##fontsize', font_val, 12.0, 32.0, u8'%.0f') and not is_capturing_any then
        orule.config.fontSize = font_val[0]
        saveConfig() 
    end
    imgui.PopItemWidth()
    
    imgui.Spacing()
    imgui.Spacing()
    
    imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.90, 1.00), u8'Расстояние между строками:')
    local spacing_val = imgui.new.float[1](orule.config.lineSpacing)
    imgui.PushItemWidth(-20)
    if imgui.SliderFloat('##linespacing', spacing_val, 0.0, 1.0, u8'%.2f') and not is_capturing_any then
        orule.config.lineSpacing = spacing_val[0]
        saveConfig() 
    end
    imgui.PopItemWidth()
    if imgui.IsItemHovered() then 
        imgui.SetTooltip(u8'Расстояние между строками текста (множитель от высоты строки)') 
    end
    
    if is_capturing_any then
        imgui.PopStyleVar(1)
    end
    
    imgui.Spacing()
    imgui.Spacing()

    imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8'Обновление ресурсов')
    imgui.Spacing()
    
    if is_capturing_any then
        imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, 0.5)
    end
    
    local auto_update_checkbox = imgui.new.bool(orule.config.autoUpdateTexts)
    if imgui.Checkbox(u8'Автоматически обновлять текстовые файлы', auto_update_checkbox) and not is_capturing_any then
        orule.config.autoUpdateTexts = auto_update_checkbox[0]
        saveConfig()
    end
    
    if imgui.IsItemHovered() then
        imgui.SetTooltip(u8'При выключении текстовые файлы не будут перезаписываться при обновлении.\nШрифты и изображения всё равно будут обновляться.')
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
    
    if imgui.Button(u8'Сохранить настройки команды', imgui.ImVec2(-20, 45)) and not is_capturing_any then
        local new_command = ffi.string(commandBuf)
        local valid, error_msg = validateCommand(new_command)
        
        if not valid then
            sampAddChatMessage('[ORULE] Ошибка: ' .. error_msg, 0xFF0000)
        else
            orule.config.command = new_command
            saveConfig()
            sampAddChatMessage('[ORULE] Настройки сохранены! Перезапустите скрипт (CTRL+R)', 0x45AFFF)
        end
    end
    
    imgui.PopStyleColor(3)
end

-- ============================================================
-- ГЛАВНОЕ ОКНО
-- ============================================================
local function renderInfoWindow()
    local sw, sh = getScreenResolution()
    -- Адаптивный размер: максимум 90% от высоты экрана
    local adaptive_height = math.min(orule.config.windowHeight or 800, sh * 0.9)
    local adaptive_width = math.min(orule.config.windowWidth or 820, sw * 0.9)

    imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(adaptive_width, adaptive_height), imgui.Cond.FirstUseEver)

    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 12.0)
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 2.0)
    imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.50, 0.45, 1.00, 0.90))

    local window_flags = imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize

    if imgui.Begin(u8'Добро пожаловать в ORULE!', show_info_window, window_flags) then
        imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.08, 0.08, 0.12, 1.00))
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 8.0)
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildBorderSize, 1.0)

        if imgui.BeginChild('##info_header', imgui.ImVec2(0, 121), true) then
            if title_font then imgui.PushFont(title_font) end

            local window_width = imgui.GetWindowWidth()
            local title_text = u8('ORULE v' .. SCRIPT_VERSION)
            local title_width = imgui.CalcTextSize(title_text).x

            imgui.SetCursorPosY(15)
            imgui.SetCursorPosX((window_width - title_width) * 0.5)
            imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), title_text)

            if title_font then imgui.PopFont() end

            imgui.Spacing()

            if main_font then imgui.PushFont(main_font) end
            local subtitle_text = u8'Продвинутый менеджер правил с overlay-интерфейсом'
            local subtitle_width = imgui.CalcTextSize(subtitle_text).x
            imgui.SetCursorPosX((window_width - subtitle_width) * 0.5)
            imgui.TextColored(imgui.ImVec4(0.90, 0.90, 0.95, 1.00), subtitle_text)

            imgui.Spacing()

            local author_text = u8'Автор: Lev Exelent (vk.com/e11evated)'
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
            imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8'Добро пожаловать в ORULE!')
            imgui.Spacing()
            imgui.PushTextWrapPos(0)
            imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.90, 1.00), u8'Спасибо, что выбрали ORULE - самый функциональный менеджер правил для MoonLoader!')
            imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8'Этот инструмент создан специально для сотрудников государственных организаций на Cyber Russia.')
            imgui.PopTextWrapPos()

            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8'Основные возможности')
            imgui.Spacing()
            imgui.BulletText(u8'Overlay-интерфейс - просмотр правил поверх игры без сворачивания')
            imgui.BulletText(u8'Горячие клавиши - назначьте свои биндки для каждого правила')
            imgui.BulletText(u8'Радиальное меню - быстрый доступ к командам через среднюю кнопку мыши')
            imgui.BulletText(u8'Умный поиск - находит информацию с учетом синонимов и контекста')
            imgui.BulletText(u8'Режим удержания - показывайте правило только пока удерживаете клавишу')
            imgui.BulletText(u8'Настройка внешнего вида - шрифт, прозрачность, размеры окон')
            imgui.BulletText(u8'Карты радаров и фотографии территорий - все под рукой')
            imgui.BulletText(u8'Автообновление - скрипт и ресурсы обновляются автоматически')
            imgui.BulletText(u8'9 готовых правил для МВД с актуальной информацией')
            imgui.BulletText(u8'Полная законодательная база (Конституция, УК, КоАП, ФЗ)')
            imgui.BulletText(u8'Информация о закрытых территориях всех фракций')

            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8'Быстрый старт')
            imgui.Spacing()
            
            imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.11, 0.11, 0.13, 0.95))
            imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 6.0)
            if imgui.BeginChild('##quick_start', imgui.ImVec2(0, 210), true) then
                imgui.Spacing()
                imgui.Indent(10)
                
                imgui.TextColored(imgui.ImVec4(0.90, 0.85, 1.00, 1.00), u8'Шаг 1:')
                imgui.SameLine(0, 5)
                imgui.PushTextWrapPos(imgui.GetWindowWidth() - 20)
                imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8'Перейдите во вкладку "Правила" и назначьте горячие клавиши')
                imgui.PopTextWrapPos()
                imgui.Spacing()
                
                imgui.TextColored(imgui.ImVec4(0.90, 0.85, 1.00, 1.00), u8'Шаг 2:')
                imgui.SameLine(0, 5)
                imgui.PushTextWrapPos(imgui.GetWindowWidth() - 20)
                imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8'Настройте радиальное меню во вкладке "Радиальное меню"')
                imgui.PopTextWrapPos()
                imgui.Spacing()
                
                imgui.TextColored(imgui.ImVec4(0.90, 0.85, 1.00, 1.00), u8'Шаг 3:')
                imgui.SameLine(0, 5)
                imgui.PushTextWrapPos(imgui.GetWindowWidth() - 20)
                imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8'Настройте внешний вид overlay во вкладке "Настройки"')
                imgui.PopTextWrapPos()
                imgui.Spacing()
                
                imgui.TextColored(imgui.ImVec4(0.90, 0.85, 1.00, 1.00), u8'Шаг 4:')
                imgui.SameLine(0, 5)
                imgui.PushTextWrapPos(imgui.GetWindowWidth() - 20)
                imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8'Нажмите назначенную клавишу для открытия overlay с правилом')
                imgui.PopTextWrapPos()
                imgui.Spacing()
                
                imgui.TextColored(imgui.ImVec4(0.90, 0.85, 1.00, 1.00), u8'Шаг 5:')
                imgui.SameLine(0, 5)
                imgui.PushTextWrapPos(imgui.GetWindowWidth() - 20)
                imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8'Используйте поиск для быстрого нахождения нужной информации')
                imgui.PopTextWrapPos()
                
                imgui.Unindent(10)
                imgui.Spacing()
            end
            imgui.EndChild()
            imgui.PopStyleVar(1)
            imgui.PopStyleColor(1)

            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8'Управление')
            imgui.Spacing()
            
            imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.11, 0.11, 0.13, 0.95))
            imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 6.0)
            if imgui.BeginChild('##controls', imgui.ImVec2(0, 180), true) then
                imgui.Spacing()
                imgui.Indent(10)
                
                imgui.Columns(2, nil, false)
                imgui.SetColumnWidth(0, 250)
                
                imgui.TextColored(imgui.ImVec4(0.60, 0.55, 1.00, 1.00), u8'/' .. u8(orule.config.command))
                imgui.NextColumn()
                imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8'Открыть/закрыть меню настроек')
                imgui.NextColumn()
                imgui.Spacing()
                
                imgui.TextColored(imgui.ImVec4(0.60, 0.55, 1.00, 1.00), u8'Средняя кнопка мыши')
                imgui.NextColumn()
                imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8'Радиальное меню (удерживать)')
                imgui.NextColumn()
                imgui.Spacing()
                
                imgui.TextColored(imgui.ImVec4(0.60, 0.55, 1.00, 1.00), u8'ESC')
                imgui.NextColumn()
                imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8'Закрыть overlay с правилом')
                imgui.NextColumn()
                imgui.Spacing()
                
                imgui.TextColored(imgui.ImVec4(0.60, 0.55, 1.00, 1.00), u8'Назначенная клавиша')
                imgui.NextColumn()
                imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8'Открыть/закрыть конкретное правило')
                imgui.NextColumn()
                
                imgui.Columns(1)
                imgui.Unindent(10)
                imgui.Spacing()
            end
            imgui.EndChild()
            imgui.PopStyleVar(1)
            imgui.PopStyleColor(1)

            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8'Радиальное меню')
            imgui.Spacing()
            imgui.PushTextWrapPos(0)
            imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8'Удерживайте среднюю кнопку мыши и выберите действие.')
            imgui.PopTextWrapPos()
            imgui.Spacing()
            
            imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.11, 0.11, 0.13, 0.95))
            imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 6.0)
            if imgui.BeginChild('##radial_actions', imgui.ImVec2(0, 385), true) then
                imgui.Spacing()
                imgui.Indent(10)
                
                imgui.TextColored(imgui.ImVec4(0.90, 0.85, 1.00, 1.00), u8'Кнопка 1 - Мегафон')
                imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.75, 0.90), u8'Предупреждение водителю через громкоговоритель')
                imgui.Spacing()
                
                imgui.TextColored(imgui.ImVec4(0.90, 0.85, 1.00, 1.00), u8'Кнопка 2 - Миранда')
                imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.75, 0.90), u8'Чтение прав задержанному')
                imgui.Spacing()
                
                imgui.TextColored(imgui.ImVec4(0.90, 0.85, 1.00, 1.00), u8'Кнопка 3 - Обыск')
                imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.75, 0.90), u8'Проведение обыска с нательной камерой и /frisk')
                imgui.Spacing()
                
                imgui.TextColored(imgui.ImVec4(0.90, 0.85, 1.00, 1.00), u8'Кнопка 4 - Удостоверение')
                imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.75, 0.90), u8'Предъявление служебного удостоверения и /doc')
                imgui.Spacing()
                
                imgui.TextColored(imgui.ImVec4(0.90, 0.85, 1.00, 1.00), u8'Кнопка 5 - Фоторобот')
                imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.75, 0.90), u8'Установление личности по фотографии')
                imgui.Spacing()
                
                imgui.TextColored(imgui.ImVec4(0.90, 0.85, 1.00, 1.00), u8'Кнопка 6 - Тонировка')
                imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.75, 0.90), u8'Проверка тонировки тауметром')
                
                imgui.Unindent(10)
                imgui.Spacing()
            end
            imgui.EndChild()
            imgui.PopStyleVar(1)
            imgui.PopStyleColor(1)

            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8'Что нового в версии 1.1')
            imgui.Spacing()
            imgui.BulletText(u8'Первый публичный релиз')
            imgui.BulletText(u8'9 готовых правил для МВД с актуальной информацией')
            imgui.BulletText(u8'Полная законодательная база (Конституция, УК, КоАП, ФЗ)')
            imgui.BulletText(u8'Информация о закрытых территориях всех фракций')
            imgui.BulletText(u8'Интерактивные карты радаров и фотографии территорий')
            imgui.BulletText(u8'Радиальное меню с настраиваемыми кнопками')
            imgui.BulletText(u8'Умный поиск с синонимами')
            imgui.BulletText(u8'Автообновление скрипта и ресурсов')
            imgui.BulletText(u8'Селективное обновление текстовых файлов')
            imgui.BulletText(u8'Гибкая система настройки под себя')

            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8'Полезные советы')
            imgui.Spacing()
            imgui.BulletText(u8'Используйте поиск с минусом (-слово) для исключения результатов')
            imgui.BulletText(u8'Режим удержания идеален для быстрого показа правил игрокам')
            imgui.BulletText(u8'Настройте прозрачность overlay под свои предпочтения')
            imgui.BulletText(u8'Все файлы правил находятся в папке moonloader/OverlayRules/texts/')
            imgui.BulletText(u8'Вы можете редактировать тексты правил в любом текстовом редакторе')
            imgui.BulletText(u8'Отключите "Автообновление текстов" если изменяли файлы правил')
            
            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()
            
            imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.11, 0.11, 0.13, 0.95))
            imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 6.0)
            if imgui.BeginChild('##warning', imgui.ImVec2(0, 136), true) then
                imgui.Spacing()
                imgui.Indent(10)
                imgui.TextColored(imgui.ImVec4(1.00, 0.70, 0.30, 1.00), u8'ВАЖНО:')
                imgui.Spacing()
                imgui.PushTextWrapPos(imgui.GetWindowWidth() - 20)
                imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.90, 1.00), u8'Если вы изменили текстовые файлы правил, обязательно отключите опцию "Автоматически обновлять текстовые файлы" в настройках, иначе ваши изменения будут перезаписаны при следующем запуске скрипта.')
                imgui.PopTextWrapPos()
                imgui.Unindent(10)
                imgui.Spacing()
            end
            imgui.EndChild()
            imgui.PopStyleVar(1)
            imgui.PopStyleColor(1)
        end
        imgui.EndChild()
        imgui.PopStyleColor(1)

        if main_font then imgui.PopFont() end

        imgui.Spacing()

        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.50, 0.45, 1.00, 0.90))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.60, 0.55, 1.00, 1.00))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.40, 0.35, 0.90, 1.00))
        if title_font then imgui.PushFont(title_font) end

        local button_text = u8'Продолжить'
        local button_width = imgui.CalcTextSize(button_text).x + 80
        local window_width = imgui.GetWindowWidth()
        imgui.SetCursorPosX((window_width - button_width) * 0.5)

        if imgui.Button(button_text, imgui.ImVec2(button_width, 45)) then
            show_info_window[0] = false
            info_window_shown_once = true
            orule.config.firstLaunch = false
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
    -- Адаптивный размер: максимум 90% от высоты экрана
    local adaptive_height = math.min(orule.config.windowHeight or 800, sh * 0.9)
    local adaptive_width = math.min(orule.config.windowWidth or 820, sw * 0.9)

    imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(adaptive_width, adaptive_height), imgui.Cond.FirstUseEver)

    if imgui.Begin(u8'Менеджер правил', show_window, imgui.WindowFlags.NoCollapse) then
        if not first_render_done then
            first_render_done = true
            imgui.Text(u8'Загрузка интерфейса...')
            imgui.End()
            return
        end
        local current_size = imgui.GetWindowSize()
        local current_width = math.floor(current_size.x)
        local current_height = math.floor(current_size.y)
        
        -- Ограничиваем сохранение размера разумными пределами
        if current_width >= 600 and current_height >= 400 then
            if (last_window_width ~= current_width or last_window_height ~= current_height) and (last_window_width > 0 or last_window_height > 0) then
                orule.config.windowWidth = current_width
                orule.config.windowHeight = current_height
                saveConfig()
            end
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

            local title_text = u8('ORULE v' .. SCRIPT_VERSION)
            local title_width = imgui.CalcTextSize(title_text).x
            imgui.SetCursorPosX(20 + (available_width - title_width) * 0.5)

            local colors_gradient = {
                imgui.ImVec4(0.70, 0.65, 1.00, 1.00),
                imgui.ImVec4(0.50, 0.45, 1.00, 1.00),
                imgui.ImVec4(0.40, 0.35, 0.90, 1.00)
            }
            imgui.TextColored(colors_gradient[2], title_text)

            imgui.Spacing()

            local desc_text = u8'Продвинутый менеджер правил с overlay-интерфейсом'
            local desc_width = imgui.CalcTextSize(desc_text).x
            imgui.SetCursorPosX(20 + (available_width - desc_width) * 0.5)
            imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.95), desc_text)

            imgui.Spacing()

            local author_text = u8'Автор: Lev Exelent (vk.com/e11evated)'
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
            if imgui.BeginTabItem(u8'Правила') then 
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
            if imgui.BeginTabItem(u8'Радиальное меню') then
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
            if imgui.BeginTabItem(u8'Настройки') then 
                if main_font then imgui.PushFont(main_font) end
                
                local content_height = imgui.GetContentRegionAvail().y
                imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.0, 0.0, 0.0, 0.0))
                if imgui.BeginChild('##settings_scroll', imgui.ImVec2(-20, content_height), false) then
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
-- РАДИАЛЬНОЕ МЕНЮ
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
        -- Конвертируем CP1251 ? UTF-8 для ImGui
        local label_u8 = u8(label)
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
-- ОБРАБОТКА НАЖАТИЙ
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
            orule.config.firstLaunch = false
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
            is_capturing_keys = true
            local code = wparam
            if code == 27 then
                key_capture_mode, key_capture_type = nil, nil
                is_capturing_keys = false
                consumeWindowMessage(true, true)
            elseif code == 0x08 then
                key_capture_mode, key_capture_type = nil, nil
                is_capturing_keys = false
                consumeWindowMessage(true, true)
            elseif code ~= 0x10 and code ~= 0x11 and code ~= 0x12 then
                -- Собираем комбинацию: модификаторы + нажатая клавиша
                local shortcut_keys = {}

                -- Добавляем зажатые модификаторы
                if isKeyDown(0xA2) or isKeyDown(0xA3) or isKeyDown(0x11) then table.insert(shortcut_keys, 0xA2) end -- LCTRL
                if isKeyDown(0xA4) or isKeyDown(0xA5) or isKeyDown(0x12) then table.insert(shortcut_keys, 0xA4) end -- LALT
                if isKeyDown(0xA0) or isKeyDown(0xA1) or isKeyDown(0x10) then table.insert(shortcut_keys, 0xA0) end -- LSHIFT

                -- Добавляем нажатую клавишу
                table.insert(shortcut_keys, code)

                -- Ограничиваем максимальное количество клавиш в комбинации
                if #shortcut_keys >= 1 and #shortcut_keys <= 3 then
                    local exclude_index = nil
                    if key_capture_type == "rule" and key_capture_mode and key_capture_mode.index then
                        exclude_index = key_capture_mode.index
                    end

                    local is_used, reason = isShortcutAlreadyUsed(shortcut_keys, exclude_index)
                    if is_used then
                        local shortcut_name = getShortcutName(shortcut_keys)

                        if isSampLoaded() and isSampAvailable() then
                            sampAddChatMessage(string.format('[ORULE] Комбинация "%s" уже использована %s', shortcut_name, reason), 0xFF0000)
                        end

                        key_capture_mode, key_capture_type = nil, nil
                        is_capturing_keys = false
                        consumeWindowMessage(true, true)
                    else
                        if key_capture_type == "rule" and key_capture_mode and key_capture_mode.index and orule.rulesDB[key_capture_mode.index] then
                            orule.rulesDB[key_capture_mode.index].key = shortcut_keys
                            orule.rulesDB[key_capture_mode.index].keyName = getShortcutName(shortcut_keys)
                        elseif key_capture_type == "global" then
                            orule.config.globalHotkey = shortcut_keys
                        end
                        key_capture_mode, key_capture_type = nil, nil
                        is_capturing_keys = false
                        saveConfig()
                        consumeWindowMessage(true, true)
                    end
                elseif #shortcut_keys > 3 then
                    if isSampLoaded() and isSampAvailable() then
                        sampAddChatMessage('[ORULE] Слишком много клавиш в комбинации (макс. 3)', 0xFF0000)
                    end
                    key_capture_mode, key_capture_type = nil, nil
                    is_capturing_keys = false
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
            
            local is_used, reason = isKeyAlreadyUsed(code, exclude_index)
            if is_used then
                local key_name = getKeyName(code)
                
                if isSampLoaded() and isSampAvailable() then
                    sampAddChatMessage(string.format('[ORULE] Клавиша "%s" уже использована %s', key_name, reason), 0xFF0000)
                end
                
                key_capture_mode, key_capture_type = nil, nil
                consumeWindowMessage(true, true)
            else
                if key_capture_type == "rule" and key_capture_mode and key_capture_mode.index and orule.rulesDB[key_capture_mode.index] then
                    orule.rulesDB[key_capture_mode.index].key = code
                    orule.rulesDB[key_capture_mode.index].keyName = getKeyName(code)
                elseif key_capture_type == "global" then
                    orule.config.globalHotkey = code
                end
                key_capture_mode, key_capture_type = nil, nil
                saveConfig()
                consumeWindowMessage(true, true)
            end
        end
    end

    if not key_capture_mode and radialMenu.globalEnabled then
        if msg == wm.WM_MBUTTONDOWN then
            -- Проверяем блокировки ПЕРЕД активацией
            if sampIsChatInputActive() or sampIsDialogActive() or isSampfuncsConsoleActive() or isPauseMenuActive() then
                return -- НЕ активируем меню
            end
            
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
-- ГЛАВНАЯ ЛОГИКА
-- ============================================================
local function cmd_help()
    sampAddChatMessage("======================", 0x45AFFF)
    sampAddChatMessage("Orule - Менеджер правил v1.1", 0x45AFFF)
    sampAddChatMessage("/" .. orule.config.command .. " - открыть меню", 0xFFFFFF)
    sampAddChatMessage("Средняя кнопка мыши (удержание) - радиальное меню", 0xFFFFFF)
    sampAddChatMessage("Автор: Lev Exelent", 0xFFFFFF)
    sampAddChatMessage("======================", 0x45AFFF)
end

local function toggle()
    if orule.config.firstLaunch and not info_window_shown_once then
        show_info_window[0] = true
        imgui.Process = true
    else
        show_window[0] = not show_window[0]
        imgui.Process = show_window[0]
    end
end

local function checkMoonLoaderVersion()
    local ml_version = getMoonloaderVersion()
    if ml_version < 026 then
        print('[ORULE] Ошибка: требуется MoonLoader 0.26+')
        print('[ORULE] Текущая версия: ' .. string.format('0.%d', ml_version))
        if isSampLoaded() and isSampAvailable() then
            sampAddChatMessage('[ORULE] Ошибка: требуется MoonLoader 0.26+', 0xFF0000)
        end
        thisScript():unload()
    end
end

function safeMain()
    if not isSampLoaded() then 
        print('[ORULE] Ошибка: SA-MP не загружен')
        return 
    end
    while not isSampAvailable() do wait(100) end

    checkMoonLoaderVersion()

    -- Проверка обновлений
    if autoupdate_loaded and enable_autoupdate and Update then
        pcall(Update.check, Update.json_url, Update.prefix, Update.url)
    end
    
    sampAddChatMessage("[ORULE] Загрузка...", 0x45AFFF)
    
    loadAllRules()
    
    if orule.config.command and #orule.config.command > 0 then 
        sampRegisterChatCommand(orule.config.command, toggle)
        sampRegisterChatCommand(orule.config.command .. "_help", cmd_help)
    end
    
    sampAddChatMessage("[ORULE] Готов! Используйте /" .. orule.config.command, 0x00FF00)
    
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

    -- ============================================================
    -- АВТОЗАГРУЗКА РЕСУРСОВ С GITHUB
    -- ============================================================
    function downloadResource(url, path, resource_type, callback)
        local dir = path:match('(.+)\\[^\\]+$')
        if dir and not doesDirectoryExist(dir) then
            createDirectory(dir)
        end
        
        -- Логика для текстовых файлов
        if resource_type == "text" then
            if orule.config.autoUpdateTexts then
                print('[ORULE] Обновляю текст: ' .. path:match('([^\\]+)$'))
                downloadUrlToFile(url, path, function(id, status)
                    if status == require('moonloader').download_status.STATUSEX_ENDDOWNLOAD then
                        if callback then callback(true) end
                    end
                end)
                return true
            else
                if not doesFileExist(path) then
                    print('[ORULE] Создаю текст: ' .. path:match('([^\\]+)$'))
                    downloadUrlToFile(url, path, function(id, status)
                        if status == require('moonloader').download_status.STATUSEX_ENDDOWNLOAD then
                            if callback then callback(true) end
                        end
                    end)
                    return true
                else
                    print('[ORULE] Пропускаю: ' .. path:match('([^\\]+)$'))
                    if callback then callback(false) end
                    return false
                end
            end
        end
        
        -- Для шрифтов и картинок
        if not doesFileExist(path) then
            print('[ORULE] Загружаю: ' .. path:match('([^\\]+)$'))
            downloadUrlToFile(url, path, function(id, status)
                if status == require('moonloader').download_status.STATUSEX_ENDDOWNLOAD then
                    if callback then callback(true) end
                end
            end)
            return true
        end
        if callback then callback(false) end
        return false
    end

    function checkAndDownloadResources()
        local base_url = "https://raw.githubusercontent.com/levushkaexelent/orule/main/resources/"
        local base_path = getWorkingDirectory() .. "\\OverlayRules\\"
        
        local downloaded_count = 0
        local processed_count = 0
        
        local resources = {
            -- === ТЕКСТОВЫЕ ФАЙЛЫ ===
            {url = base_url .. "texts/hierarchy.txt", path = base_path .. "texts\\hierarchy.txt", type = "text"},
            {url = base_url .. "texts/labor_code.txt", path = base_path .. "texts\\labor_code.txt", type = "text"},
            {url = base_url .. "texts/legal_constitution.txt", path = base_path .. "texts\\legal_constitution.txt", type = "text"},
            {url = base_url .. "texts/legal_federal.txt", path = base_path .. "texts\\legal_federal.txt", type = "text"},
            {url = base_url .. "texts/legal_fsb_law.txt", path = base_path .. "texts\\legal_fsb_law.txt", type = "text"},
            {url = base_url .. "texts/legal_koap.txt", path = base_path .. "texts\\legal_koap.txt", type = "text"},
            {url = base_url .. "texts/legal_police_law.txt", path = base_path .. "texts\\legal_police_law.txt", type = "text"},
            {url = base_url .. "texts/legal_uk.txt", path = base_path .. "texts\\legal_uk.txt", type = "text"},
            {url = base_url .. "texts/mvd_drill.txt", path = base_path .. "texts\\mvd_drill.txt", type = "text"},
            {url = base_url .. "texts/mvd_handbook.txt", path = base_path .. "texts\\mvd_handbook.txt", type = "text"},
            {url = base_url .. "texts/mvd_statute.txt", path = base_path .. "texts\\mvd_statute.txt", type = "text"},
            {url = base_url .. "texts/police_main.txt", path = base_path .. "texts\\police_main.txt", type = "text"},
            {url = base_url .. "texts/police_mask.txt", path = base_path .. "texts\\police_mask.txt", type = "text"},
            {url = base_url .. "texts/police_radar.txt", path = base_path .. "texts\\police_radar.txt", type = "text"},
            {url = base_url .. "texts/police_tint.txt", path = base_path .. "texts\\police_tint.txt", type = "text"},
            {url = base_url .. "texts/territory_army.txt", path = base_path .. "texts\\territory_army.txt", type = "text"},
            {url = base_url .. "texts/territory_army_supplement.txt", path = base_path .. "texts\\territory_army_supplement.txt", type = "text"},
            {url = base_url .. "texts/territory_fsb.txt", path = base_path .. "texts\\territory_fsb.txt", type = "text"},
            {url = base_url .. "texts/territory_fsin.txt", path = base_path .. "texts\\territory_fsin.txt", type = "text"},
            {url = base_url .. "texts/territory_fsin_supplement.txt", path = base_path .. "texts\\territory_fsin_supplement.txt", type = "text"},
            {url = base_url .. "texts/territory_government.txt", path = base_path .. "texts\\territory_government.txt", type = "text"},
            {url = base_url .. "texts/territory_hospital.txt", path = base_path .. "texts\\territory_hospital.txt", type = "text"},
            {url = base_url .. "texts/territory_main.txt", path = base_path .. "texts\\territory_main.txt", type = "text"},
            {url = base_url .. "texts/territory_mchs.txt", path = base_path .. "texts\\territory_mchs.txt", type = "text"},
            {url = base_url .. "texts/territory_mvd.txt", path = base_path .. "texts\\territory_mvd.txt", type = "text"},
            {url = base_url .. "texts/territory_smi.txt", path = base_path .. "texts\\territory_smi.txt", type = "text"},
            {url = base_url .. "texts/upk.txt", path = base_path .. "texts\\upk.txt", type = "text"},
            
            -- === ИЗОБРАЖЕНИЯ ===
            {url = base_url .. "images/radar_map.png", path = base_path .. "images\\radar_map.png", type = "image"},
            {url = base_url .. "images/ter_1.jpg", path = base_path .. "images\\ter_1.jpg", type = "image"},
            {url = base_url .. "images/ter_2.jpg", path = base_path .. "images\\ter_2.jpg", type = "image"},
            {url = base_url .. "images/ter_3.jpg", path = base_path .. "images\\ter_3.jpg", type = "image"},
            {url = base_url .. "images/ter_4.jpg", path = base_path .. "images\\ter_4.jpg", type = "image"},
            {url = base_url .. "images/ter_5.jpg", path = base_path .. "images\\ter_5.jpg", type = "image"},
            {url = base_url .. "images/ter_6.jpg", path = base_path .. "images\\ter_6.jpg", type = "image"},
            {url = base_url .. "images/ter_7.jpg", path = base_path .. "images\\ter_7.jpg", type = "image"},
            {url = base_url .. "images/ter_8.jpg", path = base_path .. "images\\ter_8.jpg", type = "image"},
            {url = base_url .. "images/ter_9.jpg", path = base_path .. "images\\ter_9.jpg", type = "image"},
            {url = base_url .. "images/ter_10.jpg", path = base_path .. "images\\ter_10.jpg", type = "image"},
            {url = base_url .. "images/ter_11.jpg", path = base_path .. "images\\ter_11.jpg", type = "image"},
            {url = base_url .. "images/ter_12.jpg", path = base_path .. "images\\ter_12.jpg", type = "image"},
            {url = base_url .. "images/ter_13.jpg", path = base_path .. "images\\ter_13.jpg", type = "image"},
            {url = base_url .. "images/ter_14.jpg", path = base_path .. "images\\ter_14.jpg", type = "image"},
            {url = base_url .. "images/ter_15.jpg", path = base_path .. "images\\ter_15.jpg", type = "image"},
            {url = base_url .. "images/ter_16.jpg", path = base_path .. "images\\ter_16.jpg", type = "image"},
            {url = base_url .. "images/ter_17.jpg", path = base_path .. "images\\ter_17.jpg", type = "image"},
            {url = base_url .. "images/ter_18.jpg", path = base_path .. "images\\ter_18.jpg", type = "image"},
            {url = base_url .. "images/ter_19.jpg", path = base_path .. "images\\ter_19.jpg", type = "image"},
            {url = base_url .. "images/ter_20.jpg", path = base_path .. "images\\ter_20.jpg", type = "image"},
            
            -- === ШРИФТ ===
            {url = base_url .. "fonts/EagleSans-Regular.ttf", path = base_path .. "fonts\\EagleSans-Regular.ttf", type = "font"},
        }
        
        local total = #resources
        sampAddChatMessage('[ORULE] Проверка ресурсов... (' .. total .. ' файлов)', 0xFFFFFF)
        
        -- Асинхронная загрузка
        for i, res in ipairs(resources) do
            downloadResource(res.url, res.path, res.type, function(was_downloaded)
                processed_count = processed_count + 1
                if was_downloaded then
                    downloaded_count = downloaded_count + 1
                end
                
                -- Показываем прогресс
                if processed_count % 10 == 0 or processed_count == total then
                    sampAddChatMessage('[ORULE] Проверено: ' .. processed_count .. '/' .. total, 0xFFFFFF)
                end
                
                -- Финальное сообщение
                if processed_count == total then
                    if downloaded_count > 0 then
                        sampAddChatMessage('[ORULE] Загружено новых ресурсов: ' .. downloaded_count, 0x00FF00)
                    else
                        sampAddChatMessage('[ORULE] Все ресурсы актуальны', 0x00FF00)
                    end
                end
            end)
            
            wait(100) -- Задержка между запросами
        end
    end

    -- Запускаем проверку ресурсов
    lua_thread.create(function()
        wait(2000) -- Ждём инициализацию MoonLoader
        checkAndDownloadResources()
    end)

    while true do
        wait(0)
        local is_game_focused = not (sampIsChatInputActive() or sampIsDialogActive() or isSampfuncsConsoleActive() or isPauseMenuActive())
        
        if is_game_focused and not is_capturing_keys then
            -- Проверка глобальной горячей клавиши (теперь поддерживает комбинации)
            if ((type(orule.config.globalHotkey) == "table" and isShortcutPressed(orule.config.globalHotkey)) or
                (type(orule.config.globalHotkey) ~= "table" and orule.config.globalHotkey > 0 and isKeyJustPressed(orule.config.globalHotkey))) then
                toggle()
            end

            held_rule_active = false
            for i, rule in ipairs(orule.rulesDB) do
                if rule.key and ((type(rule.key) == "table" and #rule.key > 0) or (type(rule.key) ~= "table" and rule.key > 0)) then
                    if rule.holdMode then
                        -- Для режима удержания проверяем все клавиши комбинации
                        local all_pressed = true
                        if type(rule.key) == "table" then
                            for _, key in ipairs(rule.key) do
                                if not isKeyDown(key) then
                                    all_pressed = false
                                    break
                                end
                            end
                        else
                            all_pressed = isKeyDown(rule.key)
                        end

                        if all_pressed then
                            if overlay_rule_index ~= i then
                                ffi.fill(search_buffer, 256, 0)
                            end
                            overlay_rule_index, overlay_visible = i, true
                            held_rule_active = true
                            break
                        end
                    else
                        -- Для обычного режима проверяем комбинацию
                        if (type(rule.key) == "table" and isShortcutPressed(rule.key)) or
                           (type(rule.key) ~= "table" and isKeyJustPressed(rule.key)) then
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

            if not held_rule_active and overlay_visible and orule.rulesDB[overlay_rule_index] and orule.rulesDB[overlay_rule_index].holdMode then
                overlay_visible = false
            end

            if radialMenu.action then
                executeRadialAction(radialMenu.action)
                radialMenu.action = nil
            end
        end
    end
end

function main()
    local success, error_msg = pcall(safeMain)
    if not success then
        logError('CRITICAL ERROR: ' .. tostring(error_msg))
        sampAddChatMessage('[ORULE] Критическая ошибка! Проверьте orule_errors.log', 0xFF0000)
    end
end
