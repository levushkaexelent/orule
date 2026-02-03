script_version('1.9.0')
script_name('Orule - Менеджер правил')
script_author('Lev Exelent (vk.com/e11evated)')
script_moonloader(26)

require('lib.moonloader')
local imgui = require('mimgui')
local encoding = require('encoding')
local ffi = require('ffi')
local bit = require('bit')
require('lib.sampfuncs')
local wm = require('lib.windows.message')
local mimgui_blur = require('mimgui_blur')
local vkeys = require('vkeys')
local inicfg = require('inicfg')

local function bringFloatTo(current, target, speed)
    local delta = imgui.GetIO().DeltaTime
    local diff = target - current

    if math.abs(diff) < 0.001 then 
        return target 
    end

    local next_value = current + diff * speed * delta * 60

    if (diff > 0 and next_value > target) or (diff < 0 and next_value < target) then
        return target
    end

    return next_value
end

local function bringVec4To(current, target, speed)
    return imgui.ImVec4(
        bringFloatTo(current.x, target.x, speed),
        bringFloatTo(current.y, target.y, speed),
        bringFloatTo(current.z, target.z, speed),
        bringFloatTo(current.w, target.w, speed)
    )
end

function string.levenshtein(str1, str2)
    local len1 = #str1
    local len2 = #str2
    
    if len1 == 0 then return len2 end
    if len2 == 0 then return len1 end
    if str1 == str2 then return 0 end

    local matrix = {}
    
    for i = 0, len1 do
        matrix[i] = {[0] = i}
    end
    
    for j = 0, len2 do
        matrix[0][j] = j
    end
    
    for i = 1, len1 do
        for j = 1, len2 do
            local cost = (string.byte(str1, i) == string.byte(str2, j)) and 0 or 1
            matrix[i][j] = math.min(
                matrix[i-1][j] + 1,
                matrix[i][j-1] + 1,
                matrix[i-1][j-1] + cost
            )
        end
    end
    
    return matrix[len1][len2]
end

local toggle_anims = {}

function imgui.ToggleButton(str_id, bool_var)
    local p = imgui.GetCursorScreenPos()
    local dl = imgui.GetWindowDrawList()
    
    local height = imgui.GetFrameHeight()
    local width = height * 1.65
    local radius = height * 0.50
    
    local current_val = bool_var[0]
    
    local clicked = imgui.InvisibleButton(str_id, imgui.ImVec2(width, height))
    if clicked then
        bool_var[0] = not bool_var[0]
    end
    
    if not toggle_anims[str_id] then
        toggle_anims[str_id] = { val = current_val and 1.0 or 0.0 }
    end
    
    local anim = toggle_anims[str_id]
    local target = bool_var[0] and 1.0 or 0.0
    
    if math.abs(anim.val - target) > 0.01 then
        local speed = 10.0 * imgui.GetIO().DeltaTime
        if anim.val < target then
            anim.val = math.min(anim.val + speed, target)
        else
            anim.val = math.max(anim.val - speed, target)
        end
    else
        anim.val = target
    end
    
    local col_bg_active = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.50, 0.45, 1.00, 1.00))
    local col_bg_inactive = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.20, 0.20, 0.25, 1.00))
    local col_circle = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1.00, 1.00, 1.00, 1.00))
    
    local t = anim.val
    local col_bg = col_bg_inactive
    if t > 0.5 then col_bg = col_bg_active end
    
    dl:AddRectFilled(p, imgui.ImVec2(p.x + width, p.y + height), col_bg, radius)
    
    local circle_x = p.x + radius + (width - radius * 2.0) * t
    local circle_y = p.y + radius
    
    dl:AddCircleFilled(imgui.ImVec2(circle_x, circle_y), radius - 1.5, col_circle)
    
    imgui.SameLine()
    imgui.SetCursorPosX(imgui.GetCursorPosX() + 5)
    imgui.Text(str_id:gsub("##.+$", ""))
    
    return clicked
end

function imgui.GradientButton(label, size_arg)
    local dl = imgui.GetWindowDrawList()
    local p = imgui.GetCursorScreenPos()
    local size = size_arg or imgui.ImVec2(0, 0)
    
    if size.x == 0 and size.y == 0 then
        local text_size = imgui.CalcTextSize(label)
        size = imgui.ImVec2(text_size.x + 30, text_size.y + 10)
    end
    
    local clicked = imgui.InvisibleButton(label, size)
    local hovered = imgui.IsItemHovered()
    local active = imgui.IsItemActive()
    
    local col1, col2
    
    if active then
        col1 = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.30, 0.25, 0.80, 1.00))
        col2 = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.10, 0.40, 0.80, 1.00))
    elseif hovered then
        col1 = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.60, 0.55, 1.00, 1.00))
        col2 = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.30, 0.70, 1.00, 1.00))
    else
        col1 = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.50, 0.45, 1.00, 1.00))
        col2 = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.20, 0.60, 1.00, 1.00))
    end
    
    dl:AddRectFilledMultiColor(
        p, 
        imgui.ImVec2(p.x + size.x, p.y + size.y), 
        col1, col2, col2, col1,
        6.0
    )
    
    local text_size = imgui.CalcTextSize(label:gsub("##.+$", ""))
    local text_pos = imgui.ImVec2(
        p.x + (size.x - text_size.x) / 2, 
        p.y + (size.y - text_size.y) / 2
    )
    dl:AddText(text_pos, imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1.00, 1.00, 1.00, 1.00)), label:gsub("##.+$", ""))
    
    return clicked
end

imgui._SmoothScroll = { defaultSpeed = 20, xAxisKey = 0x10, pos = {} }

function imgui.SmoothScroll(id, speed, lockX, lockY)
    if imgui._SmoothScroll.pos[id] == nil then imgui._SmoothScroll.pos[id] = {x = 0.0, y = 0.0} end
    speed = speed or imgui._SmoothScroll.defaultSpeed

    local io = imgui.GetIO()
    local is_hovered = imgui.IsWindowHovered()
    
    if is_hovered and not imgui.IsMouseDown(0) then
        if not lockY and io.MouseWheel ~= 0 and (not isKeyDown(imgui._SmoothScroll.xAxisKey) or lockX) then
            imgui._SmoothScroll.pos[id].y = imgui.GetScrollY() + (-io.MouseWheel) * speed
        end
        
        imgui._SmoothScroll.pos[id].y = math.max(math.min(imgui._SmoothScroll.pos[id].y, imgui.GetScrollMaxY()), 0)
        local current_y = imgui.GetScrollY()
        local target_y = imgui._SmoothScroll.pos[id].y
        local diff = target_y - current_y
        if math.abs(diff) > 0.05 then
            imgui.SetScrollY(current_y + diff * 0.6)
        else
            imgui.SetScrollY(target_y)
        end

        if not lockX and io.MouseWheel ~= 0 and (isKeyDown(imgui._SmoothScroll.xAxisKey) or lockY) then
            imgui._SmoothScroll.pos[id].x = imgui.GetScrollX() + (-io.MouseWheel) * speed
        end
        imgui._SmoothScroll.pos[id].x = math.max(math.min(imgui._SmoothScroll.pos[id].x, imgui.GetScrollMaxX()), 0)
        local current_x = imgui.GetScrollX()
        local target_x = imgui._SmoothScroll.pos[id].x
        local diff_x = target_x - current_x
        if math.abs(diff_x) > 0.05 then
            imgui.SetScrollX(current_x + diff_x * 0.6)
        else
            imgui.SetScrollX(target_x)
        end
    else
        imgui._SmoothScroll.pos[id].x, imgui._SmoothScroll.pos[id].y = imgui.GetScrollX(), imgui.GetScrollY()
    end
end

pcall(ffi.cdef, [[
   int OpenClipboard(void* hWnd);
   int EmptyClipboard();
   void* SetClipboardData(unsigned int uFormat, void* hMem);
   int CloseClipboard();
   void* GlobalAlloc(unsigned int uFlags, unsigned int dwBytes);
   void* GlobalLock(void* hMem);
   int GlobalUnlock(void* hMem);

   typedef short SHORT;
   SHORT GetKeyState(int nVirtKey);
   bool SetCursorPos(int X, int Y);
]])

local user32 = ffi.load('user32')
local kernel32 = ffi.load('kernel32')

local lower_map = { [string.char(168)] = string.char(184) }
for i = 192, 223 do 
   lower_map[string.char(i)] = string.char(i + 32) 
end

local upper_map = { [string.char(184)] = string.char(168) }
for i = 224, 255 do 
   upper_map[string.char(i)] = string.char(i - 32) 
end

local orig_lower = string.lower
local orig_upper = string.upper

function string.lower(str)
   if type(str) ~= 'string' then return str end
   
   local result = (str:gsub(".", lower_map))
   return orig_lower(result)
end

function string.upper(str)
   if type(str) ~= 'string' then return str end
   local result = (str:gsub(".", upper_map))
   return orig_upper(result)
end

encoding.default = 'CP1251'
local u8 = encoding.UTF8

local CONSTANTS = {
    DEFAULT_WIDTH = 820,
    DEFAULT_HEIGHT = 850,
    CARD_HEIGHT = 183,
    MAX_KEY_CODE = 511,
    CHANGELOG_VER = "1.9.0",
    PATHS = {
        ROOT = getWorkingDirectory() .. '\\OverlayRules',
        LOG = getWorkingDirectory() .. '\\OverlayRules\\orule_errors.log',
        CONFIG = getWorkingDirectory() .. '\\OverlayRules\\orule_settings.ini',
    }
}

local updater = {
    json_url = 'https://raw.githubusercontent.com/levushkaexelent/orule/refs/heads/main/update.json',
    temp_json = getWorkingDirectory() .. '\\OverlayRules\\update_check.json'
}

function updater:check()
    if doesFileExist(self.temp_json) then os.remove(self.temp_json) end

    downloadUrlToFile(self.json_url, self.temp_json, function(id, status)
        if status == require('moonloader').download_status.STATUSEX_ENDDOWNLOAD then
            local file = io.open(self.temp_json, 'rb')
            if file then
                local content = file:read('*all')
                file:close()
                os.remove(self.temp_json)

                local success, data = pcall(decodeJson, content)
                if success and data and data.last and data.url then
                    if data.last ~= thisScript().version then
                        sampAddChatMessage(string.format('[ORULE] Доступно обновление: %s -> %s. Введите /scriptupd', thisScript().version, data.last), 0x45AFFF)
                        
                        sampRegisterChatCommand('scriptupd', function()
                            updater:download(data.url)
                        end)
                    else
                        print('[ORULE] Версия актуальна: ' .. thisScript().version)
                    end
                else
                    print('[ORULE] Ошибка парсинга JSON обновления')
                end
            end
        elseif status == require('moonloader').download_status.STATUSEX_HTTPERROR then
            print('[ORULE] Ошибка сети при проверке обновлений')
        end
    end)
end

function updater:download(url)
    local dlstatus = require('moonloader').download_status
    local temp_path = thisScript().path .. ".tmp"
    
    sampAddChatMessage('[ORULE] Начало загрузки обновления...', 0x45AFFF)
    
    downloadUrlToFile(url, temp_path, function(id, status)
        if status == dlstatus.STATUSEX_ENDDOWNLOAD then
            local file = io.open(temp_path, 'rb')
            if not file then 
                sampAddChatMessage('[ORULE] Критическая ошибка: файл не найден.', 0xFF0000)
                return 
            end
            local content = file:read('*all')
            file:close()

            local decode_ok, decoded_text = pcall(encoding.UTF8.decode, encoding.UTF8, content)
            
            if decode_ok and decoded_text then
                local encode_ok, final_content = pcall(encoding.CP1251.encode, encoding.CP1251, decoded_text)
                if encode_ok then
                    content = final_content
                end
            end

            local out_file = io.open(temp_path, 'wb')
            if out_file then
                out_file:write(content)
                out_file:close()

                os.remove(thisScript().path)
                if os.rename(temp_path, thisScript().path) then
                    sampAddChatMessage('[ORULE] Обновление успешно! Перезагрузка...', 0x00FF00)
                    orule.config.lastChangelogVersion = "0"
                    saveConfig()
                    thisScript():reload()
                else
                    sampAddChatMessage('[ORULE] Ошибка: не удалось заменить файл скрипта.', 0xFF0000)
                end
            else
                sampAddChatMessage('[ORULE] Ошибка: не удалось записать обновленный файл.', 0xFF0000)
            end
        elseif status == dlstatus.STATUSEX_HTTPERROR then
            sampAddChatMessage('[ORULE] Ошибка сети при скачивании обновления!', 0xFF0000)
        end
    end)
end


local state = {
    windows = {
        main = imgui.new.bool(false),
        info = imgui.new.bool(false),
        player_menu = imgui.new.bool(false),
        interaction_editor = imgui.new.bool(false),
        radial_editor = imgui.new.bool(false)
    },
    interaction = {
        target_ped = nil,
        target_id = -1,
        edit_index = -1,
        edit_mode = "content",
        buffers = {
            name = imgui.new.char[65](),
            content = imgui.new.char[4097](),
            enabled = imgui.new.bool(true)
        },
        
        key_capture = {
            active = false,
            mode = nil,
            index = -1
        }
    },
    overlay = {
        visible = false,
        rule_index = nil,
        active_tabs = {
            police = imgui.new.int(0),
            legal = imgui.new.int(0),
            territory = imgui.new.int(0)
        },
        search_buf = imgui.new.char[257](),
        text_alpha = 1.0,
        prev_tab_police = 0,
        prev_tab_legal = 0,
        prev_tab_territory = 0
    },
    autoinsert = {
        menu_active = false
    },
    radial_edit = {
        index = 0,
        name_buffer = imgui.new.char[65](),
        content_buffer = imgui.new.char[4097](),
        enabled = imgui.new.bool(true),
        mode = "content",
        should_open = false
    },
    first_render = false,
    preload_complete = false,
    fonts = { main = nil, title = nil, radial = nil },
    textures = { radar = nil, territory = {} },
    active_tab = 1,
    window_alpha = 0.0,
    tab_offset_y = 0.0,
    prev_tab = 1,
    tab_anim_y = nil,
    next_tab = nil,
    is_tab_switching = false
}

local RENDER_CONST = {
    BG_OVERLAY = imgui.ImVec4(0, 0, 0, 0.6),
    BG_MAIN    = imgui.ImVec4(0, 0, 0, 0.5),
    ZERO       = imgui.ImVec2(0, 0),
    COL_WHITE  = imgui.ImVec4(1, 1, 1, 1),
    COL_ERROR  = imgui.ImVec4(1, 0, 0, 1),
    WIN_PADDING = imgui.ImVec2(35.0, 8.0)
}

local orule = {
    rulesDB = {},
    text_cache = {},
    autoInsertCards = {},
    config = {
        command = "orule",
        lastChangelogVersion = "0",
        globalHotkey = 0,
        overlayBgAlpha = 0.85,
        fontSize = 18.0,
        lineSpacing = 0.0,
        windowWidth = CONSTANTS.DEFAULT_WIDTH,
        windowHeight = CONSTANTS.DEFAULT_HEIGHT,
        ruleCardHeight = CONSTANTS.CARD_HEIGHT,
        firstLaunch = true,
        autoUpdateTexts = true,
        autoInsertEnabled = true,
        interactionEnabled = true,
        interactionMode = 1,
        showImages = true
    }
}

local cache = {
    userQMs = nil,
    interactionQMs = nil,
    interactionKeys = nil,
    search = { query = "", rule = nil, tab = nil, res = nil, lines = nil, text = nil }
}

orule.AUTOINSERT_FILE = CONSTANTS.PATHS.ROOT .. '\\autoinsert_cards.json'
orule.FONTS_DIR = CONSTANTS.PATHS.ROOT .. '\\fonts'
orule.IMAGES_DIR = CONSTANTS.PATHS.ROOT .. '\\images'
orule.TEXTS_DIR = CONSTANTS.PATHS.ROOT .. '\\texts'

local function logError(message)
    pcall(function() 
        local file = io.open(CONSTANTS.PATHS.LOG, 'a')
        if file then
            local timestamp = os.date('%Y-%m-%d %H:%M:%S')
            file:write(string.format('[%s] %s\n', timestamp, tostring(message)))
            file:close()
        end
    end)
end

local SCRIPT_VERSION = "1.9.0"

local function resetIO()
    local io = imgui.GetIO()
    for i = 0, CONSTANTS.MAX_KEY_CODE do io.KeysDown[i] = false end
    for i = 0, 4 do io.MouseDown[i] = false end
    io.KeyCtrl, io.KeyShift, io.KeyAlt, io.KeySuper = false, false, false, false
end

local function ensureDirectories()
    if not doesDirectoryExist(CONSTANTS.PATHS.ROOT) then 
        createDirectory(CONSTANTS.PATHS.ROOT) 
    end
    local dirs = {orule.FONTS_DIR, orule.IMAGES_DIR, orule.TEXTS_DIR}
    for _, dir in ipairs(dirs) do
        if not doesDirectoryExist(dir) then createDirectory(dir) end
    end
end

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

local function withFont(font, func)
    if font then imgui.PushFont(font) end
    func()
    if font then imgui.PopFont() end
end

local last_window_width, last_window_height = 0, 0
local commandBuf = imgui.new.char[33]()
local config_save_timer = 0
local config_save_pending = false
local key_capture_mode, key_capture_type = nil, nil
local is_capturing_keys = false
local texture_cache = {}
local info_window_shown_once = false

local radialMenu = {
    active = false,
    anim = 0.0,
    pendingActivation = false,
    releasePending = false,
    isHeld = false,
    center = imgui.ImVec2(0, 0),
    selected = nil,
    radius = 220,
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


local userQMs_cache_dirty = true
local interactionQMs_cache_dirty = true

local CONFIG_SAVE_DELAY = 500
local INTERACTION_QMS_FILE = getWorkingDirectory() .. '\\OverlayRules\\interactionQMs.json'

local USER_QMS_FILE = getWorkingDirectory() .. '\\OverlayRules\\userQMs.json'
local function processSpecialTags(text)
    if not text then return text end

    text = text:gsub("{time}", function()
        local hours = tonumber(os.date("%H", os.time() + 3 * 3600))
        local minutes = os.date("%M", os.time() + 3 * 3600)
        return string.format("%02d:%02d", hours, minutes)
    end)

    return text
end

local function parseRoleplayCommands(content)
    local commands = {}
    local current_delay = 0

    content = processSpecialTags(content)
    for line in content:gmatch("[^\r\n]+") do
        line = line:gsub("^%s*(.-)%s*$", "%1")

        if line ~= "" then
            local delay_match = line:match("^<(%d+)>$")
            if delay_match then
                current_delay = current_delay + tonumber(delay_match)
            elseif line == "*" then
                table.insert(commands, {
                    type = "screenshot",
                    delay = current_delay
                })
                current_delay = 0
            elseif line:match("^>>(.+)") then
                local chat_text = line:match("^>>(.+)")
                table.insert(commands, {
                    type = "chat_input",
                    text = chat_text,
                    delay = current_delay
                })
                current_delay = 0
            else
                table.insert(commands, {
                    type = "chat",
                    text = line,
                    delay = current_delay
                })
                current_delay = 0
            end
        end
    end

    return commands
end

local function executeRoleplay(commands)
    if not (isSampLoaded() and isSampAvailable()) then
        sampAddChatMessage('[ORULE] Отыгровка не выполнена - SAMP не загружен', 0xFF0000)
        return
    end

    lua_thread.create(function()
        for _, cmd in ipairs(commands) do
            if cmd.delay > 0 then
                wait(cmd.delay)
            end

            if cmd.type == "chat" and cmd.text and cmd.text ~= "" then
                sampSendChat(cmd.text)
            elseif cmd.type == "screenshot" then
                setVirtualKeyDown(119, true)
                wait(50)
                setVirtualKeyDown(119, false)
            elseif cmd.type == "chat_input" and cmd.text then
                sampSetChatInputText(cmd.text)
                sampSetChatInputEnabled(true)
            end
        end
    end)
end

local function saveUserQMs(data)
    local dir = getWorkingDirectory() .. '\\OverlayRules'
    if not doesDirectoryExist(dir) then
        createDirectory(dir)
    end

    local exportData = {}
    for i, item in ipairs(data) do
        exportData[i] = {
            enabled = item.enabled,
            title = item.title and u8(item.title) or "",
            content = item.content and u8(item.content) or ""
        }
    end
    local success, json_str = pcall(encodeJson, exportData)
    if not success then
        logError('Ошибка сериализации данных в JSON: ' .. tostring(json_str))
        sampAddChatMessage('[ORULE] Ошибка сохранения данных', 0xFF0000)
        return false
    end

    local file = io.open(USER_QMS_FILE, 'w')
    if not file then
        logError('Не удалось открыть файл для записи: ' .. USER_QMS_FILE)
        sampAddChatMessage('[ORULE] Ошибка сохранения файла', 0xFF0000)
        return false
    end

    file:write(json_str)
    file:close()

    cache.userQMs = data
    userQMs_cache_dirty = false

    return true
end
local function loadUserQMs()
    if not userQMs_cache_dirty and cache.userQMs then
        return cache.userQMs
    end

    local file = io.open(USER_QMS_FILE, 'r')
    if not file then
        local defaultData = {
            {content = "", title = "Мегафон", enabled = true},
            {content = "", title = "Миранда", enabled = true},
            {content = "", title = "Обыск", enabled = true},
            {content = "", title = "Удостоверение", enabled = true},
            {content = "", title = "Фоторобот", enabled = true},
            {content = "", title = "Тонировка", enabled = true}
        }
        saveUserQMs(defaultData)
        cache.userQMs = defaultData
        userQMs_cache_dirty = false
        return defaultData
    end

    local content = file:read('*a')
    file:close()

    if content == '' then
        cache.userQMs = {}
        userQMs_cache_dirty = false
        return {}
    end

    local success, data = pcall(decodeJson, content)
    if not success or not data then
        logError('Ошибка парсинга userQMs.json: ' .. tostring(data))
        cache.userQMs = {}
        userQMs_cache_dirty = false
        return {}
    end

    local luaData = {}
    for i, item in ipairs(data) do
        luaData[i] = {
            enabled = item.enabled,
            title = item.title and u8:decode(item.title) or "",
            content = item.content and u8:decode(item.content) or ""
        }
    end

    cache.userQMs = luaData
    userQMs_cache_dirty = false
    return luaData
end
local function saveAutoInsertCards(data)
    local dir = getWorkingDirectory() .. '\\OverlayRules'
    if not doesDirectoryExist(dir) then
        createDirectory(dir)
    end

    local exportData = {}
    for i, card in ipairs(data) do
        exportData[i] = {
            title = card.title and u8(card.title) or "",
            content = card.content and u8(card.content) or ""
        }
    end

    local success, json_str = pcall(encodeJson, exportData)
    if not success then
        logError('Ошибка сериализации карточек автовставки в JSON: ' .. tostring(json_str))
        sampAddChatMessage('[ORULE] Ошибка сохранения карточек автовставки', 0xFF0000)
        return false
    end
    local file = io.open(orule.AUTOINSERT_FILE, 'w')
    if not file then
        logError('Не удалось открыть файл для записи: ' .. orule.AUTOINSERT_FILE)
        sampAddChatMessage('[ORULE] Ошибка сохранения файла карточек автовставки', 0xFF0000)
        return false
    end

    file:write(json_str)
    file:close()

    return true
end
local function loadAutoInsertCards()
    local file = io.open(orule.AUTOINSERT_FILE, 'r')
    if not file then
        return {}
    end

    local content = file:read('*a')
    file:close()

    if content == '' then return {} end

    local success, data = pcall(decodeJson, content)
    if not success or not data then
        logError('Ошибка парсинга autoinsert_cards.json: ' .. tostring(data))
        return {}
    end
    local luaData = {}
    for i, card in ipairs(data) do
        luaData[i] = {
            title = card.title and u8:decode(card.title) or "",
            content = card.content and u8:decode(card.content) or ""
        }
    end

    return luaData
end

local function saveInteractionQMs(data)
    local dir = getWorkingDirectory() .. '\\OverlayRules'
    if not doesDirectoryExist(dir) then
        createDirectory(dir)
    end

    local exportData = {}
    for i, item in ipairs(data) do
        exportData[i] = {
            enabled = item.enabled,
            title = item.title and u8(item.title) or "",
            content = item.content and u8(item.content) or "",
            action = item.action
        }
    end
    local success, json_str = pcall(encodeJson, exportData)
    if not success then
        logError('Ошибка сериализации данных взаимодействия в JSON: ' .. tostring(json_str))
        sampAddChatMessage('[ORULE] Ошибка сохранения отыгровок взаимодействия', 0xFF0000)
        return false
    end

    local file = io.open(INTERACTION_QMS_FILE, 'w')
    if not file then
        logError('Не удалось открыть файл для записи: ' .. INTERACTION_QMS_FILE)
        sampAddChatMessage('[ORULE] Ошибка сохранения файла отыгровок взаимодействия', 0xFF0000)
        return false
    end

    file:write(json_str)
    file:close()

    cache.interactionQMs = data
    interactionQMs_cache_dirty = false

    return true
end

local function loadInteractionQMs()
    if not interactionQMs_cache_dirty and cache.interactionQMs then
        return cache.interactionQMs
    end

    local file = io.open(INTERACTION_QMS_FILE, 'r')
    if not file then
        local defaultData = {
            {action = "showpass", content = "/me достал удостоверение и показал его {player}\n/me показал удостоверение", title = "Показать документы", enabled = true},
            {action = "search", content = "/me обыскал {player}\n/do В карманах найдено: {search_result}", title = "Обыскать", enabled = true},
            {action = "cuff", content = "/me надел наручники на {player}\n/do Наручники защелкнулись", title = "Надеть наручники", enabled = true},
            {action = "uncuff", content = "/me снял наручники с {player}\n/do Наручники сняты", title = "Снять наручники", enabled = true},
            {action = "arrest", content = "/arrest {id}", title = "Арестовать", enabled = true},
            {action = "ticket", content = "/ticket {id} 10000 Нарушение ПДД", title = "Выписать штраф", enabled = true}
        }
        saveInteractionQMs(defaultData)
        cache.interactionQMs = defaultData
        interactionQMs_cache_dirty = false
        return defaultData
    end

    local content = file:read('*a')
    file:close()

    if content == '' then
        cache.interactionQMs = {}
        interactionQMs_cache_dirty = false
        return {}
    end

    local success, data = pcall(decodeJson, content)
    if not success or not data then
        logError('Ошибка парсинга interactionQMs.json: ' .. tostring(data))
        cache.interactionQMs = {}
        interactionQMs_cache_dirty = false
        return {}
    end

    local luaData = {}
    for i, item in ipairs(data) do
        luaData[i] = {
            enabled = item.enabled,
            title = item.title and u8:decode(item.title) or "",
            content = item.content and u8:decode(item.content) or "",
            action = item.action or ""
        }
    end

    cache.interactionQMs = luaData
    interactionQMs_cache_dirty = false
    return luaData
end

local function loadInteractionKeyBinds()
    local file = io.open(getWorkingDirectory() .. '\\OverlayRules\\interactionKeyBinds.json', 'r')
    if not file then
        return {
            {action = "showpass", key = {49}},
            {action = "search", key = {50}},
            {action = "cuff", key = {51}},
            {action = "uncuff", key = {52}},
            {action = "arrest", key = {53}},
            {action = "ticket", key = {54}}
        }
    end

    local content = file:read('*a')
    file:close()

    if content == '' then
        return {}
    end

    local success, data = pcall(decodeJson, content)
    if not success or not data then
        logError('Ошибка парсинга interactionKeyBinds.json: ' .. tostring(data))
        return {}
    end

    return data
end

local function saveInteractionKeyBinds(data)
    local dir = getWorkingDirectory() .. '\\OverlayRules'
    if not doesDirectoryExist(dir) then
        createDirectory(dir)
    end

    local success, json_str = pcall(encodeJson, data)
    if not success then
        logError('Ошибка сериализации биндов взаимодействия в JSON: ' .. tostring(json_str))
        sampAddChatMessage('[ORULE] Ошибка сохранения биндов взаимодействия', 0xFF0000)
        return false
    end

    local file = io.open(getWorkingDirectory() .. '\\OverlayRules\\interactionKeyBinds.json', 'w')
    if not file then
        logError('Не удалось открыть файл для записи биндов взаимодействия')
        sampAddChatMessage('[ORULE] Ошибка сохранения файла биндов взаимодействия', 0xFF0000)
        return false
    end

    file:write(json_str)
    file:close()
    return true
end

local function syncUserQMsWithRadialMenu()
    local userData = cache.userQMs or loadUserQMs()

    for i, item in ipairs(userData) do
        if radialMenu.buttons[i] then
            if item.title and item.title ~= '' then
                radialMenu.buttons[i].name = item.title
            end
        end
    end
end

local function get_middle_button_x(count)
    local width = imgui.GetContentRegionAvail().x
    local space = imgui.GetStyle().ItemSpacing.x
    return count == 1 and width or width / count - ((space * (count - 1)) / count)
end

local function executeRadialAction(index)
    if not index then return end

    local userData = cache.userQMs or loadUserQMs()

    if not userData[index] or not userData[index].content or userData[index].content == "" then
        return
    end

    if not radialMenu.buttons[index] or not radialMenu.buttons[index].enabled then
        return
    end

    local commands = parseRoleplayCommands(userData[index].content)
    if #commands > 0 then
        executeRoleplay(commands)
    end
end

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

local function isShortcutPressed(shortcut_keys)
    if type(shortcut_keys) == "number" then
        return isKeyJustPressed(shortcut_keys)
    end
    if type(shortcut_keys) ~= "table" or #shortcut_keys == 0 then return false end

    for i = 1, #shortcut_keys - 1 do
        if not isKeyDown(shortcut_keys[i]) then
            return false
        end
    end

    return isKeyJustPressed(shortcut_keys[#shortcut_keys])
end

local function isShortcutAlreadyUsed(shortcut_keys, exclude_rule_index)
    if type(shortcut_keys) ~= "table" or #shortcut_keys == 0 then return false end

    for _, vk_code in ipairs(shortcut_keys) do
        if SAMP_RESERVED_KEYS[vk_code] then
            return true, "содержит зарезервированную SAMP клавишу: " .. SAMP_RESERVED_KEYS[vk_code]
        end
    end
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
    local default_color_vec = imgui.ImVec4(1.0, 1.0, 1.0, 1.0)
    local line_height = imgui.GetTextLineHeight()
    local space_width = imgui.CalcTextSize(' ').x
    local window_pos = imgui.GetCursorScreenPos()
    local line_width = imgui.GetWindowContentRegionMax().x - imgui.GetStyle().WindowPadding.x
    local current_pos = imgui.ImVec2(window_pos.x, window_pos.y)
    local line_spacing = (orule.config.lineSpacing or 0.0) * line_height

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

end

local function saveIniDirectly(ini_data, filepath)
    local dir_path = filepath:match("(.+)\\[^\\]+$")
    if dir_path and not doesDirectoryExist(dir_path) then
        createDirectory(dir_path)
    end
    
    local file = io.open(filepath, 'w')
    if not file then
        return false
    end
    
    local function formatValue(value)
        if type(value) == "boolean" then
            return value and "true" or "false"
        elseif type(value) == "string" then
            return value:gsub("\r", ""):gsub("\n", "\\n")
        else
            return tostring(value)
        end
    end
    
    local function writeSection(section_name, section_data)
        file:write('[' .. tostring(section_name) .. ']\n')
        for key, value in pairs(section_data) do
            if value ~= nil then
                file:write(tostring(key) .. '=' .. formatValue(value) .. '\n')
            end
        end
        file:write('\n')
    end
    
    local section_order = {'settings', 'radial', 'rules'}
    for _, section_name in ipairs(section_order) do
        if ini_data[section_name] and type(ini_data[section_name]) == 'table' then
            writeSection(section_name, ini_data[section_name])
        end
    end
    
    for section_name, section_data in pairs(ini_data) do
        local found = false
        for _, ordered_name in ipairs(section_order) do
            if section_name == ordered_name then
                found = true
                break
            end
        end
        if not found and type(section_data) == 'table' then
            writeSection(section_name, section_data)
        end
    end
    
    file:close()
    return true
end

local function saveConfig()
    ensureDirectories()
    
    if not doesDirectoryExist(CONSTANTS.PATHS.ROOT) then
        createDirectory(CONSTANTS.PATHS.ROOT)
    end
    
    local ini_data = {
        settings = {
            command = orule.config.command,
            globalHotkey = (type(orule.config.globalHotkey) == "table") and table.concat(orule.config.globalHotkey, ",") or orule.config.globalHotkey,
            windowWidth = orule.config.windowWidth,
            windowHeight = orule.config.windowHeight,
            ruleCardHeight = orule.config.ruleCardHeight,
            firstLaunch = orule.config.firstLaunch,
            radialMenuEnabled = radialMenu.globalEnabled,
            autoUpdateTexts = orule.config.autoUpdateTexts,
            autoInsertEnabled = orule.config.autoInsertEnabled,
            lastChangelogVersion = orule.config.lastChangelogVersion,
            interactionEnabled = orule.config.interactionEnabled,
            interactionMode = orule.config.interactionMode,
            showImages = orule.config.showImages
        },
        radial = {},
        rules = {}
    }
    for i, btn in ipairs(radialMenu.buttons) do
        ini_data.radial["button_" .. i .. "_name"] = btn.name
        ini_data.radial["button_" .. i .. "_enabled"] = btn.enabled
    end
    for i, rule in ipairs(orule.rulesDB) do
        if type(rule.key) == "table" and #rule.key > 0 then
            ini_data.rules["rule_" .. i .. "_key"] = table.concat(rule.key, ",")
        else
            ini_data.rules["rule_" .. i .. "_key"] = 0
        end
        ini_data.rules["rule_" .. i .. "_holdMode"] = rule.holdMode
    end
    
    if not saveIniDirectly(ini_data, CONSTANTS.PATHS.CONFIG) then
        ensureDirectories()
        if not saveIniDirectly(ini_data, CONSTANTS.PATHS.CONFIG) then
            logError("Failed to save config: cannot create file " .. CONSTANTS.PATHS.CONFIG)
        end
    end
end

local function processConfigSave()
    if config_save_pending then
        local now = os.clock() * 1000
        if now - config_save_timer >= CONFIG_SAVE_DELAY then
            saveConfig()
            config_save_pending = false
        end
    end
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
    file:close()

    if not success or not content then
        return "{FF0000}Ошибка чтения файла " .. filename
    end

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

local function searchInText(text, query)
    if not query or #query == 0 then return {}, {} end
    
    local query_clean = query:gsub("^%s*(.-)%s*$", "%1")
    if #query_clean == 0 then return {}, {} end
    
    local decode_success, query_cp1251 = pcall(encoding.UTF8.decode, encoding.UTF8, query_clean)
    if not decode_success then
        query_cp1251 = query_clean
    end
    query_cp1251 = query_cp1251:lower()
    
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
    
    local query_words = {}
    for word in search_query:gmatch("%S+") do
        table.insert(query_words, word)
    end

    for line_num, line in ipairs(lines) do
        local clean_line = line:gsub("{%x%x%x%x%x%x}", "")
        local lower_line = clean_line:lower()
        
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
                    local relevance = variant.boost + (1000 - pos) + math.max(0, 500 - #clean_line)
                    if pos == 1 or lower_line:sub(pos - 1, pos - 1):match("%s") then relevance = relevance + 1000 end
                    
                    if relevance > max_relevance then
                        max_relevance = relevance
                        best_match = {variant = variant.type, position = pos, word = variant.pattern}
                    end
                end
            end

            if max_relevance == 0 and #query_words > 0 then
                for line_word in lower_line:gmatch("%S+") do
                    if #line_word > 3 then
                        for _, q_word in ipairs(query_words) do
                            if #q_word > 3 then
                                local dist = string.levenshtein(q_word, line_word)
                                local allowed_errors = math.min(2, math.floor(#q_word * 0.3))
                                
                                if dist <= allowed_errors then
                                    local relevance = 2500 - (dist * 500) 
                                    if relevance > max_relevance then
                                        max_relevance = relevance
                                        local pos = lower_line:find(line_word, 1, true) or 1
                                        best_match = {variant = "fuzzy", position = pos, word = line_word}
                                    end
                                end
                            end
                        end
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
                    match_word = best_match.word 
                })
            end
        end
    end
    
    table.sort(results, function(a, b) return a.relevance > b.relevance end)
    return results, lines
end

local function searchInTextCached(full_text, query, rule_index, tab_index)
    local query_str = query or ""

    if cache.search.query == query_str
       and cache.search.rule_index == rule_index
       and cache.search.tab_index == tab_index
       and cache.search.full_text == full_text then
        return cache.search.results, cache.search.lines
    end

    local results, lines = searchInText(full_text, query)

    cache.search.query = query_str
    cache.search.rule_index = rule_index
    cache.search.tab_index = tab_index
    cache.search.full_text = full_text
    cache.search.results = results
    cache.search.lines = lines

    return results, lines
end


local function renderHighlightedText(text, match_word)
    if not match_word or match_word == "" then
        imgui.TextWrapped(u8(text))
        return
    end

    local text_lower = text:lower()
    local s, e = text_lower:find(match_word, 1, true)

    if s then
        
        if s > 1 then
            local part1 = text:sub(1, s - 1)
            imgui.TextColored(imgui.ImVec4(0.8, 0.8, 0.8, 1.0), u8(part1))
            imgui.SameLine(nil, 0)
        end

        
        local part2 = text:sub(s, e)
        imgui.TextColored(imgui.ImVec4(1.0, 0.8, 0.2, 1.0), u8(part2))

        
        if e < #text then
            imgui.SameLine(nil, 0)
            local part3 = text:sub(e + 1)
            imgui.TextColored(imgui.ImVec4(0.8, 0.8, 0.8, 1.0), u8(part3))
        end
    else
        
        imgui.TextWrapped(u8(text))
    end
end


local function renderSearchResults(full_text, query, rule_index, tab_index)
    if not query or #query == 0 then
        imgui.PushTextWrapPos(0)
        renderFormattedText(full_text)
        imgui.PopTextWrapPos()
        return
    end
    
    local results, all_lines = searchInTextCached(full_text, query, rule_index or 0, tab_index or 0)
    
    if #results == 0 then
        imgui.TextColored(imgui.ImVec4(1.0, 0.5, 0.5, 1.0), u8'Ничего не найдено')
        imgui.Spacing()
        imgui.TextColored(imgui.ImVec4(0.7, 0.7, 0.75, 1.0), u8'Попробуйте:')
        imgui.BulletText(u8'Использовать синонимы')
        imgui.BulletText(u8'Проверить опечатки (авто-поиск исправляет только мелкие)')
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
    local context_size = 1 
    
    for i, result in ipairs(results) do
        if i > 15 then break end
        
        local start_line = math.max(1, result.line_num - context_size)
        local end_line = math.min(#all_lines, result.line_num + context_size)
        
        
        local already_shown = false
        for shown_start, shown_end in pairs(shown_lines) do
            if result.line_num >= shown_start and result.line_num <= shown_end then
                already_shown = true
                break
            end
        end
        
        if not already_shown then
            shown_lines[start_line] = end_line
            
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.7, 0.85, 1.0, 1.0))
            imgui.Text(u8(string.format('Результат #%d', i)))
            imgui.PopStyleColor()
            
            for line_idx = start_line, end_line do
                if line_idx == result.line_num then
                    
                    imgui.TextColored(imgui.ImVec4(0.0, 1.0, 0.0, 1.0), u8"> ")
                    imgui.SameLine()
                    
                    imgui.PushTextWrapPos(imgui.GetWindowContentRegionWidth())
                    
                    renderHighlightedText(result.clean_line, result.match_word)
                    imgui.PopTextWrapPos()
                else
                    
                    imgui.PushTextWrapPos(imgui.GetWindowContentRegionWidth())
                    imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.65, 1.0), u8("  " .. all_lines[line_idx]:gsub("{%x%x%x%x%x%x}", "")))
                    imgui.PopTextWrapPos()
                end
            end
            
            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()
        end
    end
end

local function loadConfig()
    ensureDirectories()
    
    local default_ini = {
        settings = {
            command = "orule",
            globalHotkey = 0,
            windowWidth = 1600,
            windowHeight = 1100,
            ruleCardHeight = 183,
            firstLaunch = true,
            radialMenuEnabled = true,
            autoUpdateTexts = true,
            autoInsertEnabled = true,
            lastChangelogVersion = "0",
            interactionEnabled = true,
            interactionMode = 1,
            showImages = true
        },
        radial = {},
        rules = {}
    }
    
    
    
    local function unescape(str)
        if type(str) ~= 'string' then return str end
        return str:gsub("\\n", "\n") 
    end
    
    local config_exists = doesFileExist(CONSTANTS.PATHS.CONFIG)
    
    local loaded_ini = inicfg.load(default_ini, CONSTANTS.PATHS.CONFIG)
    
    local needs_save = false
    if loaded_ini.settings.windowHeight < 1100 or loaded_ini.settings.windowWidth < 1600 then
        loaded_ini.settings.windowHeight = 1100
        loaded_ini.settings.windowWidth = 1600
        print("[ORULE] Window size auto-fixed to 1600x1100")
        needs_save = true
    end
   
    if not config_exists then
        if not doesDirectoryExist(CONSTANTS.PATHS.ROOT) then
            createDirectory(CONSTANTS.PATHS.ROOT)
            ensureDirectories()
        end
        if not saveIniDirectly(loaded_ini, CONSTANTS.PATHS.CONFIG) then
             ensureDirectories()
             saveIniDirectly(loaded_ini, CONSTANTS.PATHS.CONFIG)
        end
    elseif needs_save then
        saveIniDirectly(loaded_ini, CONSTANTS.PATHS.CONFIG)
    end
    local current_version = SCRIPT_VERSION
    local s = loaded_ini.settings or {}
    if s.lastChangelogVersion ~= current_version then
        state.active_tab = 6
        state.tab_anim_y = 0
        state.windows.main[0] = true
        imgui.Process = true
        s.lastChangelogVersion = current_version
        saveIniDirectly(loaded_ini, CONSTANTS.PATHS.CONFIG)
    end
    
    orule.config.command = unescape(s.command)
    orule.config.windowWidth = s.windowWidth
    orule.config.windowHeight = s.windowHeight
    orule.config.ruleCardHeight = s.ruleCardHeight
    orule.config.firstLaunch = s.firstLaunch
    radialMenu.globalEnabled = s.radialMenuEnabled
    orule.config.autoUpdateTexts = s.autoUpdateTexts
    orule.config.autoInsertEnabled = s.autoInsertEnabled
    orule.config.lastChangelogVersion = s.lastChangelogVersion
    orule.config.interactionEnabled = s.interactionEnabled
    orule.config.interactionMode = s.interactionMode
    orule.config.showImages = (s.showImages ~= false)
    if type(s.globalHotkey) == "string" and s.globalHotkey:find(",") then
        local keys = {}
        for k in s.globalHotkey:gmatch("[^,]+") do
            table.insert(keys, tonumber(k))
        end
        orule.config.globalHotkey = keys
    else
        local k = tonumber(s.globalHotkey) or 0
        orule.config.globalHotkey = (k ~= 0) and {k} or 0
    end
    
    for i = 1, 6 do
        
        local name = unescape(loaded_ini.radial["button_" .. i .. "_name"])
        local enabled = loaded_ini.radial["button_" .. i .. "_enabled"]
        if radialMenu.buttons[i] then
            if name ~= nil then radialMenu.buttons[i].name = name end
            if enabled ~= nil then radialMenu.buttons[i].enabled = enabled end
        end
    end
    for i, rule in ipairs(orule.rulesDB) do
        local key_val = loaded_ini.rules["rule_" .. i .. "_key"]
        local hold_val = loaded_ini.rules["rule_" .. i .. "_holdMode"]
        if key_val ~= nil then
            if type(key_val) == "string" and key_val:find(",") then
                local keys = {}
                for k in key_val:gmatch("[^,]+") do
                    table.insert(keys, tonumber(k))
                end
                rule.key = keys
            else
                local k = tonumber(key_val) or 0
                rule.key = (k ~= 0) and {k} or {}
            end
            rule.keyName = getShortcutName(rule.key)
        end
        if hold_val ~= nil then rule.holdMode = hold_val end
    end
    if orule.config.command then
        ffi.fill(commandBuf, 33, 0)
        ffi.copy(commandBuf, orule.config.command, math.min(#orule.config.command, 31))
    end
   
    saveConfig()
end

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
    syncUserQMsWithRadialMenu()
    orule.autoInsertCards = loadAutoInsertCards()
end

imgui.OnInitialize(function()
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
    local bg_medium = ImVec4(0.05, 0.05, 0.08, 0.98)
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

    local io = imgui.GetIO()
    local font_path = orule.FONTS_DIR .. '\\EagleSans-Regular.ttf'
    
    local font_config = imgui.ImFontConfig()
    font_config.SizePixels = 17.0
    font_config.PixelSnapH = true
    
    if doesFileExist(font_path) then
        local ranges = io.Fonts:GetGlyphRangesCyrillic()
        state.fonts.main = io.Fonts:AddFontFromFileTTF(font_path, 17.0, font_config, ranges)
        
        local title_config = imgui.ImFontConfig()
        title_config.SizePixels = 22.0
        title_config.PixelSnapH = true
        state.fonts.title = io.Fonts:AddFontFromFileTTF(font_path, 22.0, title_config, ranges)
        
        local radial_config = imgui.ImFontConfig()
        radial_config.SizePixels = 24.0
        radial_config.PixelSnapH = true
        state.fonts.radial = io.Fonts:AddFontFromFileTTF(font_path, 24.0, radial_config, ranges)
    end
    
    io.Fonts:Build()

    
    if orule.config.showImages then
        local radar_map_path = orule.IMAGES_DIR .. '\\radar_map.png'
        if doesFileExist(radar_map_path) then
            state.textures.radar = imgui.CreateTextureFromFile(radar_map_path)
        end

        for i = 1, 20 do
            local ter_path = orule.IMAGES_DIR .. '\\ter_' .. i .. '.jpg'
            if doesFileExist(ter_path) then
                state.textures.territory[i] = imgui.CreateTextureFromFile(ter_path)
            end
        end
    end
end)

local function unloadTextures()
    if state.textures.radar then
        imgui.ReleaseTexture(state.textures.radar)
        state.textures.radar = nil
    end

    for i = 1, 20 do
        if state.textures.territory[i] then
            imgui.ReleaseTexture(state.textures.territory[i])
            state.textures.territory[i] = nil
        end
    end
    print('[ORULE] Текстуры выгружены')
end

local function reloadTextures()
    unloadTextures()
    
    local radar_map_path = orule.IMAGES_DIR .. '\\radar_map.png'
    if doesFileExist(radar_map_path) then
        state.textures.radar = imgui.CreateTextureFromFile(radar_map_path)
    end

    for i = 1, 20 do
        local ter_path = orule.IMAGES_DIR .. '\\ter_' .. i .. '.jpg'
        if doesFileExist(ter_path) then
            state.textures.territory[i] = imgui.CreateTextureFromFile(ter_path)
        end
    end
end

local function OverlayRender()
    local sw, sh = getScreenResolution()

    local bg_draw_list = imgui.GetBackgroundDrawList()
    mimgui_blur.apply(bg_draw_list, 8.0)

    local bg_color_u32 = imgui.ColorConvertFloat4ToU32(RENDER_CONST.BG_OVERLAY)
    bg_draw_list:AddRectFilled(RENDER_CONST.ZERO, imgui.ImVec2(sw, sh), bg_color_u32)
        
        local rule = orule.rulesDB[state.overlay.rule_index]
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
            
            withFont(state.fonts.title, function()
                imgui.SetWindowFontScale(1.3)
                imgui.TextColored(RENDER_CONST.COL_WHITE, u8(rule.name or ''))
                imgui.SetWindowFontScale(1.0)
            end)
            
            if rule.updateDate then
                imgui.Spacing()
                imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.75, 1.0), u8('Последнее обновление: ' .. rule.updateDate))
            end

            if state.overlay.rule_index == 1 then
                imgui.Spacing()
                local button_width = get_middle_button_x(4)
                local current_tab = state.overlay.active_tabs.police[0] or 0
                local labels = {u8'Правила для полицейских', u8'Правила использования радара', u8'Порядок снятия масок', u8'Регламент проверки тонировки'}
                
                for i = 0, 3 do
                    if i > 0 then imgui.SameLine() end
                    if current_tab == i then
                        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.50, 0.45, 1.00, 1.00))
                        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.60, 0.55, 1.00, 1.00))
                        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.40, 0.35, 0.90, 1.00))
                    end
                    if imgui.Button(labels[i+1]..'##police_tab_'..i, imgui.ImVec2(button_width, 37)) then
                        state.overlay.active_tabs.police[0] = i
                    end
                    if current_tab == i then imgui.PopStyleColor(3) end
                end
                imgui.Spacing()
            end
                
            if state.overlay.rule_index == 2 then
                imgui.Spacing()
                local button_width = get_middle_button_x(3)
                local current_tab = state.overlay.active_tabs.legal[0] or 0
                local button_texts = {u8'КОНСТИТУЦИЯ', u8'ФЕДЕРАЛЬНОЕ ПОСТАНОВЛЕНИЕ', u8'УГОЛОВНЫЙ КОДЕКС', u8'КоАП', u8'ЗАКОН О ПОЛИЦИИ', u8'ЗАКОН О ФСБ'}
                
                if state.overlay.prev_tab_legal ~= current_tab then
                    state.overlay.text_alpha = 0.0
                    state.overlay.prev_tab_legal = current_tab
                end
                
                for i = 0, 5 do
                    if i > 0 and i % 3 == 0 then imgui.Spacing() end
                    if i > 0 and i % 3 ~= 0 then imgui.SameLine() end
                    if current_tab == i then
                        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.50, 0.45, 1.00, 1.00))
                        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.60, 0.55, 1.00, 1.00))
                        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.40, 0.35, 0.90, 1.00))
                    end
                    if imgui.Button(button_texts[i + 1]..'##legal_tab_'..i, imgui.ImVec2(button_width, 37)) then
                        state.overlay.active_tabs.legal[0] = i
                    end
                    if current_tab == i then imgui.PopStyleColor(3) end
                end
                imgui.Spacing()
            end

            if state.overlay.rule_index == 3 then
                imgui.Spacing()
                local button_width = get_middle_button_x(3)
                local current_tab = state.overlay.active_tabs.territory[0] or 0
                local button_texts = {u8'Основные положения', u8'МВД', u8'ФСБ', u8'АРМИЯ', u8'ФСИН', u8'МЧС', u8'БОЛЬНИЦА', u8'СМИ', u8'ПРАВИТЕЛЬСТВО'}
                
                if state.overlay.prev_tab_territory ~= current_tab then
                    state.overlay.text_alpha = 0.0
                    state.overlay.prev_tab_territory = current_tab
                end
                
                for i = 0, 8 do
                    if i > 0 and i % 3 == 0 then imgui.Spacing() end
                    if i > 0 and i % 3 ~= 0 then imgui.SameLine() end
                    if current_tab == i then
                        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.50, 0.45, 1.00, 1.00))
                        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.60, 0.55, 1.00, 1.00))
                        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.40, 0.35, 0.90, 1.00))
                    end
                    if imgui.Button(button_texts[i + 1]..'##territory_tab_'..i, imgui.ImVec2(button_width, 37)) then
                        state.overlay.active_tabs.territory[0] = i
                    end
                    if current_tab == i then imgui.PopStyleColor(3) end
                end
                imgui.Spacing()
            end
                
            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            if state.fonts.main then imgui.PushFont(state.fonts.main) end
            imgui.SetWindowFontScale(orule.config.fontSize / 17.0)
            
            local full_text = ''
            if state.overlay.rule_index == 1 then full_text = getPoliceRuleText(state.overlay.active_tabs.police[0] or 0)
            elseif state.overlay.rule_index == 2 then full_text = getLegalBaseText(state.overlay.active_tabs.legal[0] or 0)
            elseif state.overlay.rule_index == 3 then
                local tabIndex = state.overlay.active_tabs.territory[0] or 0
                full_text = getTerritoryText(tabIndex)
                if tabIndex == 3 then full_text = full_text .. "\n\n" .. getTerritoryArmySupplementText()
                elseif tabIndex == 4 then full_text = full_text .. "\n\n" .. getTerritoryFsinSupplementText() end
            elseif state.overlay.rule_index == 4 then full_text = getHierarchyText()
            elseif state.overlay.rule_index == 5 then full_text = getUPKText()
            elseif state.overlay.rule_index == 6 then full_text = getLaborCodeText()
            elseif state.overlay.rule_index == 7 then full_text = getMVDHandbookText()
            elseif state.overlay.rule_index == 8 then full_text = getMVDDrillRegulationsText()
            elseif state.overlay.rule_index == 9 then full_text = getMVDStatuteText()
            end

            if not full_text or #full_text == 0 or full_text:match("^{FF0000}Ошибка") then
                full_text = "{FF6B6B}Ошибка загрузки текста.\n{FFFFFF}Проверьте наличие файлов в папке texts/"
            end
            
            resetIO()

            imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 20.0)
            imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, RENDER_CONST.WIN_PADDING)
            imgui.PushStyleColor(imgui.Col.FrameBg, imgui.ImVec4(0.08, 0.08, 0.1, 0.8))

            imgui.SetCursorPosX(imgui.GetCursorPosX() + 5)
            imgui.PushItemWidth(-1)
            imgui.InputTextWithHint('##search_overlay', u8'Поиск по тексту...', state.overlay.search_buf, 256)
            imgui.PopItemWidth()

            local search_pos = imgui.GetItemRectMin()
            imgui.GetWindowDrawList():AddCircle(imgui.ImVec2(search_pos.x + 15, search_pos.y + 15), 5, 0xFFAAAAAA, 12, 1.5)
            imgui.GetWindowDrawList():AddLine(imgui.ImVec2(search_pos.x + 19, search_pos.y + 19), imgui.ImVec2(search_pos.x + 24, search_pos.y + 24), 0xFFAAAAAA, 1.5)

            imgui.PopStyleColor()
            imgui.PopStyleVar(2)

            imgui.Spacing(); imgui.Spacing()

            local current_tab = 0
            if state.overlay.rule_index == 1 then 
                current_tab = state.overlay.active_tabs.police[0] or 0
                if state.overlay.prev_tab_police ~= current_tab then
                    state.overlay.text_alpha = 0.0
                    state.overlay.prev_tab_police = current_tab
                end
            elseif state.overlay.rule_index == 2 then 
                current_tab = state.overlay.active_tabs.legal[0] or 0
                if state.overlay.prev_tab_legal ~= current_tab then
                    state.overlay.text_alpha = 0.0
                    state.overlay.prev_tab_legal = current_tab
                end
            elseif state.overlay.rule_index == 3 then 
                current_tab = state.overlay.active_tabs.territory[0] or 0
                if state.overlay.prev_tab_territory ~= current_tab then
                    state.overlay.text_alpha = 0.0
                    state.overlay.prev_tab_territory = current_tab
                end
            end

            state.overlay.text_alpha = bringFloatTo(state.overlay.text_alpha, 1.0, 0.25)
            imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, state.overlay.text_alpha)

            if full_text and #full_text > 0 then
                local query = ffi.string(state.overlay.search_buf) or ""
                renderSearchResults(full_text, query, state.overlay.rule_index, current_tab)
            end
            
            imgui.PopStyleVar(1)
            if state.overlay.rule_index == 3 then
               local tab = state.overlay.active_tabs.territory[0]
               local headers = { [1]=u8'Фотографии##mvd', [2]=u8'Фотографии##fsb', [3]=u8'Фотографии##army', [5]=u8'Фотографии##mchs', [6]=u8'Фотографии##hosp', [7]=u8'Фотографии##smi', [8]=u8'Фотографии##gov' }
               local ranges = { [1]={1,6}, [2]={7,7}, [3]={8,8}, [5]={9,12}, [6]={13,15}, [7]={16,17}, [8]={18,20} }
               
               if headers[tab] and ranges[tab] then
                    imgui.Spacing(); imgui.Spacing()
                    if imgui.CollapsingHeader(headers[tab]) then
                        local window_width = imgui.GetWindowWidth()
                        local spacing = imgui.GetStyle().ItemSpacing.x
                        local padding = imgui.GetStyle().WindowPadding.x * 2
                        local avail_width = window_width - padding
                        local images_per_row = 3
                        local image_width = math.floor((avail_width - spacing * (images_per_row - 1)) / images_per_row)
                        local image_height = math.floor(image_width * 0.57)
                        
                        local start_i, end_i = ranges[tab][1], ranges[tab][2]
                        local counter = 0
                        for i = start_i, end_i do
                            counter = counter + 1
                            if counter > 1 and (counter - 1) % images_per_row ~= 0 then imgui.SameLine() end
                            
                            if orule.config.showImages then
                                if state.textures.territory[i] then
                                    pcall(function() imgui.Image(state.textures.territory[i], imgui.ImVec2(image_width, image_height)) end)
                                else
                                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.1, 0.1, 0.1, 0.5))
                                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.1, 0.1, 0.1, 0.5))
                                    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.1, 0.1, 0.1, 0.5))
                                    imgui.Button(u8'Загрузка...##stub_' .. i, imgui.ImVec2(image_width, image_height))
                                    imgui.PopStyleColor(3)
                                end
                            else
                                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.1, 0.1, 0.12, 0.4))
                                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.15, 0.15, 0.18, 0.5))
                                imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.1, 0.1, 0.12, 0.4))
                                imgui.Button(u8'Изображения\nотключены##disabled_' .. i, imgui.ImVec2(image_width, image_height))
                                imgui.PopStyleColor(3)
                            end
                            
                            if counter % images_per_row == 0 and i < end_i then imgui.Spacing() end
                        end
                    end
               end
            end
            
            if state.overlay.rule_index == 1 and state.overlay.active_tabs.police[0] == 1 then
                imgui.Spacing(); imgui.Spacing()
                if imgui.CollapsingHeader(u8'Карта радаров##radar_map') then
                    if orule.config.showImages then
                        if state.textures.radar then
                            local avail_width = imgui.GetContentRegionAvail().x
                            local image_width = avail_width * 0.95
                            local image_height = image_width * 0.75
                            pcall(function() imgui.Image(state.textures.radar, imgui.ImVec2(image_width, image_height)) end)
                        else
                            local avail_width = imgui.GetContentRegionAvail().x
                            local image_width = avail_width * 0.95
                            local image_height = image_width * 0.75
                            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.1, 0.1, 0.1, 0.5))
                            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.1, 0.1, 0.1, 0.5))
                            imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.1, 0.1, 0.1, 0.5))
                            imgui.Button(u8'Загрузка карты...##stub_radar', imgui.ImVec2(image_width, image_height))
                            imgui.PopStyleColor(3)
                        end
                    else
                        imgui.TextColored(imgui.ImVec4(0.7, 0.7, 0.7, 1.0), u8'Изображение скрыто. Включите "Отображать изображения" в настройках.')
                    end
                end
            end

            imgui.SetWindowFontScale(1.0)
            if state.fonts.main then imgui.PopFont() end
            
            imgui.SmoothScroll('##overlay_content_scroll', 180)
        end
        imgui.End()

        imgui.PopStyleColor(2)
        imgui.PopStyleVar(2)
    end
end

jit.off(OverlayRender, true)

imgui.OnFrame(
    function() return state.overlay.visible end,
    OverlayRender
)

local function renderRulesTab()
    local is_capturing_any = (key_capture_mode ~= nil)
    
    if state.fonts.title then imgui.PushFont(state.fonts.title) end
    local title_text = u8'Список правил'
    local title_w = imgui.CalcTextSize(title_text).x
    local window_w = imgui.GetWindowWidth()
    imgui.SetCursorPosX((window_w - title_w) / 2)
    imgui.TextColored(RENDER_CONST.COL_WHITE, title_text)
    if state.fonts.title then imgui.PopFont() end
    imgui.Spacing()
    imgui.Spacing()

    local colors = {
        bg_normal = imgui.ImVec4(0.05, 0.05, 0.08, 1.00),
        border_normal = imgui.ImVec4(0.50, 0.45, 1.00, 0.50),
        bg_active = imgui.ImVec4(0.15, 0.12, 0.18, 1.00),
        border_active = imgui.ImVec4(0.90, 0.60, 0.20, 0.80),
        text_white = imgui.ImVec4(0.95, 0.95, 1.00, 1.00),
        text_gray = imgui.ImVec4(0.70, 0.70, 0.75, 0.90),
        text_accent = imgui.ImVec4(0.50, 0.45, 1.00, 0.70),
        btn_def = imgui.ImVec4(0.50, 0.45, 1.00, 0.80),
        btn_hov = imgui.ImVec4(0.60, 0.55, 1.00, 0.90),
        btn_act = imgui.ImVec4(0.40, 0.35, 0.90, 1.00),
        btn_dis = imgui.ImVec4(0.30, 0.30, 0.35, 0.60),
        btn_del = imgui.ImVec4(0.60, 0.20, 0.20, 0.80),
        btn_del_hov = imgui.ImVec4(0.70, 0.25, 0.25, 0.90),
        btn_del_act = imgui.ImVec4(0.50, 0.15, 0.15, 1.00),
        btn_wait = imgui.ImVec4(0.90, 0.60, 0.20, 1.00),
        btn_wait_hov = imgui.ImVec4(0.95, 0.65, 0.25, 1.00),
        btn_wait_act = imgui.ImVec4(0.85, 0.55, 0.15, 1.00),
        hold_inactive = imgui.ImVec4(0.40, 0.40, 0.45, 0.80)
    }

    imgui.Columns(3, 'rules_grid', false) 

    for i, rule in ipairs(orule.rulesDB) do
        local is_capturing_this = (key_capture_type == "rule" and key_capture_mode and key_capture_mode.index == i)
        local is_blocked_by_other = (is_capturing_any and not is_capturing_this)

        local has_key = (type(rule.key) == "table" and #rule.key > 0)
        local current_card_height = has_key and 241 or 195

        local current_bg = is_capturing_this and colors.bg_active or colors.bg_normal
        local current_border = is_capturing_this and colors.border_active or colors.border_normal
        
        imgui.PushStyleColor(imgui.Col.ChildBg, current_bg)
        imgui.PushStyleColor(imgui.Col.Border, current_border)
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 6.0)
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildBorderSize, 1.5)
        
        if imgui.BeginChild('##rule_card_' .. i, imgui.ImVec2(0, current_card_height), true) then
            imgui.Spacing()
            
            imgui.PushStyleColor(imgui.Col.Text, colors.text_white)
            imgui.Text(u8(rule.name or 'Без названия'))
            imgui.PopStyleColor(1)
            
            if rule.updateDate then
                imgui.Spacing()
                imgui.TextColored(colors.text_gray, u8'Обновлено: ')
                imgui.SameLine(0, 5)
                imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 0.70), u8(rule.updateDate))
            end
            
            imgui.Spacing()
            
            local key_name = getKeyName(rule.key)
            imgui.TextColored(colors.text_gray, u8'Клавиша: ')
            imgui.SameLine(0, 5)
            
            if has_key then
                imgui.TextColored(colors.text_accent, u8(key_name))
            else
                imgui.TextColored(imgui.ImVec4(0.60, 0.60, 0.65, 0.70), u8(key_name))
            end
            
            imgui.Spacing()
            imgui.Spacing()
            
            local button_height = 32
            local button_width = get_middle_button_x(2) 

            local holdModeText = rule.holdMode and u8'Удержание' or u8'Без удерж.'
            local hold_col = rule.holdMode and colors.btn_def or colors.hold_inactive

            imgui.PushStyleColor(imgui.Col.Button, hold_col)
            imgui.PushStyleColor(imgui.Col.ButtonHovered, colors.btn_hov)
            imgui.PushStyleColor(imgui.Col.ButtonActive, colors.btn_act)

            if imgui.Button(holdModeText .. '##hold_' .. i, imgui.ImVec2(button_width, button_height)) and not is_capturing_any then
                rule.holdMode = not rule.holdMode
                saveConfig()
            end
            imgui.PopStyleColor(3)

            imgui.SameLine()

            local bind_text = is_capturing_this and u8'Жду...' or u8'Назначить'
            
            if is_capturing_this then
                imgui.PushStyleColor(imgui.Col.Button, colors.btn_wait)
                imgui.PushStyleColor(imgui.Col.ButtonHovered, colors.btn_wait_hov)
                imgui.PushStyleColor(imgui.Col.ButtonActive, colors.btn_wait_act)
            elseif is_blocked_by_other then
                imgui.PushStyleColor(imgui.Col.Button, colors.btn_dis)
                imgui.PushStyleColor(imgui.Col.ButtonHovered, colors.btn_dis)
                imgui.PushStyleColor(imgui.Col.ButtonActive, colors.btn_dis)
            else
                imgui.PushStyleColor(imgui.Col.Button, colors.btn_def)
                imgui.PushStyleColor(imgui.Col.ButtonHovered, colors.btn_hov)
                imgui.PushStyleColor(imgui.Col.ButtonActive, colors.btn_act)
            end

            if imgui.Button(bind_text..'##bind_'..i, imgui.ImVec2(button_width, button_height)) and not is_blocked_by_other then
                if is_capturing_this then
                    key_capture_mode, key_capture_type = nil, nil
                else
                    key_capture_mode = {index = i}
                    key_capture_type = "rule"
                end
            end
            imgui.PopStyleColor(3)

            if has_key then
                imgui.Spacing()
                
                if is_capturing_any then
                     imgui.PushStyleColor(imgui.Col.Button, colors.btn_dis)
                     imgui.PushStyleColor(imgui.Col.ButtonHovered, colors.btn_dis)
                     imgui.PushStyleColor(imgui.Col.ButtonActive, colors.btn_dis)
                else
                     imgui.PushStyleColor(imgui.Col.Button, colors.btn_del)
                     imgui.PushStyleColor(imgui.Col.ButtonHovered, colors.btn_del_hov)
                     imgui.PushStyleColor(imgui.Col.ButtonActive, colors.btn_del_act)
                end

                if imgui.Button(u8'Удалить бинд##del_'..i, imgui.ImVec2(-1, 30)) and not is_capturing_any then
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
        
        imgui.NextColumn()
    end
    
    imgui.Columns(1)
end

local function renderRadialMenuTab()
    local is_capturing_any = (key_capture_mode ~= nil)

    if state.fonts.title then imgui.PushFont(state.fonts.title) end
    local title_text = u8'Настройки радиального меню'
    local title_w = imgui.CalcTextSize(title_text).x
    local window_w = imgui.GetWindowWidth()
    imgui.SetCursorPosX((window_w - title_w) / 2)
    imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), title_text)
    if state.fonts.title then imgui.PopFont() end
    imgui.Spacing()
    imgui.Spacing()

    if is_capturing_any then
        imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, 0.5)
    end

    imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.05, 0.05, 0.08, 0.98))
    imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.50, 0.45, 1.00, 0.50))
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 6.0)
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildBorderSize, 1.5)

    if imgui.BeginChild('##radial_global_settings', imgui.ImVec2(0, 122), true) then
        imgui.Spacing()
        imgui.TextColored(imgui.ImVec4(0.95, 0.95, 1.00, 1.00), u8'Глобальные настройки')
        imgui.Spacing()

        local enabled_checkbox = imgui.new.bool(radialMenu.globalEnabled)
        if imgui.ToggleButton(u8'Включить радиальное меню (средняя кнопка мыши)##radial_global', enabled_checkbox) and not is_capturing_any then
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

    if state.fonts.title then imgui.PushFont(state.fonts.title) end
    local title_text = u8'Настройка кнопок радиального меню'
    local title_w = imgui.CalcTextSize(title_text).x
    local window_w = imgui.GetWindowWidth()
    imgui.SetCursorPosX((window_w - title_w) / 2)
    imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), title_text)
    if state.fonts.title then imgui.PopFont() end
    imgui.Spacing()
    if state.fonts.title then imgui.PushFont(state.fonts.title) end
    local desc_text = u8'Всего доступно 6 кнопок. Можно менять названия и включать/выключать их.'
    local desc_w = imgui.CalcTextSize(desc_text).x
    local window_w_desc = imgui.GetWindowWidth()
    imgui.SetCursorPosX((window_w_desc - desc_w) / 2)
    imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), desc_text)
    if state.fonts.title then imgui.PopFont() end
    imgui.Spacing()
    imgui.Spacing()

    imgui.Columns(2, 'radial_btns_grid', false)

    for i, btn in ipairs(radialMenu.buttons) do
        local card_bg = imgui.ImVec4(0.05, 0.05, 0.08, 0.98)
        local card_border = imgui.ImVec4(0.50, 0.45, 1.00, 0.50)

        imgui.PushStyleColor(imgui.Col.ChildBg, card_bg)
        imgui.PushStyleColor(imgui.Col.Border, card_border)
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 6.0)
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildBorderSize, 1.5)

        if imgui.BeginChild('##radial_button_card_' .. i, imgui.ImVec2(0, 168), true) then
            imgui.Spacing()
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.95, 0.95, 1.00, 1.00))
            imgui.Text(u8(btn.name or ('Кнопка #' .. i)))
            imgui.PopStyleColor(1)
            imgui.Spacing()

            local btn_enabled = imgui.new.bool(btn.enabled)
            if imgui.ToggleButton(u8('Включена##btn_' .. i), btn_enabled) and not is_capturing_any then
                btn.enabled = btn_enabled[0]
                saveConfig()
            end

            imgui.Spacing()
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.30, 0.60, 1.00, 0.80))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.40, 0.70, 1.00, 0.90))
            imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.20, 0.50, 0.90, 1.00))
            if imgui.Button(u8('Редактировать##edit_btn_' .. i), imgui.ImVec2(-1, 30)) and not is_capturing_any then
                state.radial_edit.index = i
                state.radial_edit.enabled[0] = btn.enabled
                state.radial_edit.mode = "content"
                ffi.fill(state.radial_edit.name_buffer, 65, 0)
                ffi.fill(state.radial_edit.content_buffer, 4097, 0)

                local name_cp1251 = btn.name or ("Кнопка #" .. i)
                local name_utf8 = u8(name_cp1251)
                ffi.copy(state.radial_edit.name_buffer, name_utf8, math.min(#name_utf8, 63))
                local userData = cache.userQMs or loadUserQMs()
                local content_cp1251 = ""

                if userData[i] and userData[i].content then
                    content_cp1251 = userData[i].content
                else
                    content_cp1251 = "Введите текст отыгровки..."
                end

                local content_utf8 = u8(content_cp1251)
                ffi.copy(state.radial_edit.content_buffer, content_utf8, math.min(#content_utf8, 4095))

                state.windows.radial_editor[0] = true
                state.radial_edit.should_open = true
                resetIO()
            end
            imgui.PopStyleColor(3)
            imgui.Spacing()
        end
        imgui.EndChild()
        imgui.PopStyleVar(2)
        imgui.PopStyleColor(2)
        imgui.Spacing()
        
        imgui.NextColumn()
    end
    imgui.Columns(1)

    if is_capturing_any then
        imgui.PopStyleVar(1)
    end

    imgui.Spacing()
    imgui.Spacing()

    imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.08, 0.08, 0.12, 1.00))
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 6.0)
    if imgui.BeginChild('##radial_info', imgui.ImVec2(0, 350), true) then
        imgui.Spacing()
        imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8'Как работает радиальное меню')
        imgui.Spacing()

        imgui.PushTextWrapPos(0)
        imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.90, 1.00), u8('1. Зажмите среднюю кнопку мыши (колесико) для открытия меню\n2. Наведите курсор на нужную секцию меню\n3. Отпустите кнопку мыши для выбора действия\n4. Меню автоматически закроется после выбора\n5. Для отмены просто отпустите кнопку без выбора секции'))
        imgui.PopTextWrapPos()

        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8'Создание и редактирование отыгровок')
        imgui.Spacing()

        imgui.PushTextWrapPos(0)
        imgui.TextColored(imgui.ImVec4(0.80, 0.80, 0.85, 1.00), u8('1. Нажмите кнопку "Редактировать" напротив нужной секции\n2. В поле "Название отыгровки" введите понятное название\n3. В поле "Содержимое отыгровки" введите текст отыгровки\n4. Используйте <число> для задержек между командами (например: /me текст<1000>/do действие)\n5. Сохраните изменения кнопкой "Сохранить"\n6.Отыгровка будет выполняться при выборе секции в радиальном меню'))
        imgui.PopTextWrapPos()
    end
    imgui.EndChild()
    imgui.PopStyleVar(1)
    imgui.PopStyleColor(1)
end

local function validateCommand(cmd)
    if not cmd or #cmd == 0 then return false, "Команда не может быть пустой" end
    if #cmd > 31 then return false, "Команда слишком длинная (макс. 31 символ)" end
    if cmd:match("[^%w_]") then return false, "Команда может содержать только буквы, цифры и _" end
    return true
end

local function renderNewsTab()
    if state.fonts.title then imgui.PushFont(state.fonts.title) end
    local title_text = u8'Список обновлений'
    local title_w = imgui.CalcTextSize(title_text).x
    local window_w = imgui.GetWindowWidth()
    
    imgui.SetCursorPosX((window_w - title_w) / 2)
    imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), title_text)
    if state.fonts.title then imgui.PopFont() end

    imgui.Spacing()
    imgui.Spacing()

    imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.08, 0.08, 0.12, 0.60))
    imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.50, 0.45, 1.00, 0.30))
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 8.0)
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildBorderSize, 1.0)

    if imgui.BeginChild('##current_version_banner', imgui.ImVec2(0, 130), true) then
        imgui.Spacing()
        if state.fonts.title then imgui.PushFont(state.fonts.title) end
        imgui.TextColored(imgui.ImVec4(0.40, 1.00, 0.50, 1.00), u8('Текущая версия: ' .. SCRIPT_VERSION))
        if state.fonts.title then imgui.PopFont() end
        
        imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.75, 1.00), u8('Спасибо, что используете Orule!'))
        imgui.TextColored(imgui.ImVec4(0.50, 0.50, 0.55, 1.00), u8('Автор: Lev Exelent'))
    end
    imgui.EndChild()
    imgui.PopStyleVar(2)
    imgui.PopStyleColor(2)

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    if imgui.BeginChild('##news_content', imgui.ImVec2(0, 0), false) then
        
        imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.25, 0.18, 0.08, 0.60))
        imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(1.00, 0.75, 0.20, 0.80))
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 8.0)
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildBorderSize, 2.0)
        if imgui.BeginChild('##v19', imgui.ImVec2(0, 230), true) then
            imgui.TextColored(imgui.ImVec4(1.00, 0.85, 0.30, 1.00), u8' v1.9.0 - Глобальное обновление')
            imgui.Separator()
            imgui.Spacing()
            imgui.BulletText(u8'Проведен полный редизайн интерфейса скрипта')
            imgui.BulletText(u8'Глобальная оптимизация кода (улучшена производительность)')
            imgui.BulletText(u8'Добавлены новые плавные анимации элементов')
            imgui.BulletText(u8'Вкладка правил: добавлена кнопка "Удалить бинд"')
            imgui.BulletText(u8'Улучшен алгоритм поиска в оверлее правил')
            imgui.BulletText(u8'Исправления мелких ошибок и доработки')
        end
        imgui.EndChild()
        imgui.PopStyleVar(2)
        imgui.PopStyleColor(2)

        imgui.Spacing()
        
        imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.18, 0.12, 0.18, 0.40))
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 6.0)
        if imgui.BeginChild('##v18', imgui.ImVec2(0, 200), true) then
            imgui.TextColored(imgui.ImVec4(0.90, 0.60, 1.00, 1.00), u8' v1.8.0 - Взаимодействие с клавишами')
            imgui.Separator()
            imgui.Spacing()
            imgui.BulletText(u8'Новая вкладка "Взаимодействие" с режимом горячих клавиш')
            imgui.BulletText(u8'Привязка действий к комбинациям клавиш (до 3 клавиш)')
            imgui.BulletText(u8'Быстрое взаимодействие с игроками через горячие клавиши')
            imgui.BulletText(u8'Редактируемые отыгровки для каждого действия')
            imgui.BulletText(u8'Добавлены живые частицы на фон главного окна')
        end
        imgui.EndChild()
        imgui.PopStyleVar(1)
        imgui.PopStyleColor(1)

        imgui.Spacing()

        
        imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.12, 0.16, 0.12, 0.40))
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 6.0)
        if imgui.BeginChild('##v17', imgui.ImVec2(0, 180), true) then
            imgui.TextColored(imgui.ImVec4(0.40, 0.80, 0.60, 1.00), u8' v1.7 - Взаимодействие с меню')
            imgui.Separator()
            imgui.Spacing()
            imgui.BulletText(u8'Полная система взаимодействия с игроками через меню')
            imgui.BulletText(u8'ПКМ + L.ALT для открытия меню взаимодействия')
            imgui.BulletText(u8'Показать документы, обыскать, надеть/снять наручники')
            imgui.BulletText(u8'Посадить в авто, выписать штраф и другие действия')
        end
        imgui.EndChild()
        imgui.PopStyleVar(1)
        imgui.PopStyleColor(1)

        imgui.Spacing()

        
        imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.12, 0.18, 0.12, 0.40))
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 6.0)
        if imgui.BeginChild('##v16', imgui.ImVec2(0, 260), true) then
            imgui.TextColored(imgui.ImVec4(0.40, 1.00, 0.50, 1.00), u8' v1.6 - Оптимизация и стабильность')
            imgui.Separator()
            imgui.Spacing()
            imgui.TextColored(imgui.ImVec4(0.50, 0.95, 0.60, 1.00), u8'  Производительность:')
            imgui.BulletText(u8'Кеширование результатов поиска - больше никаких лагов')
            imgui.BulletText(u8'Оптимизация загрузки UserQMs - файл читается один раз')
            imgui.BulletText(u8'Отложенное сохранение конфига при изменении размера окна')
            imgui.Spacing()
            imgui.TextColored(imgui.ImVec4(0.50, 0.95, 0.60, 1.00), u8'  Исправления:')
            imgui.BulletText(u8'Исправлена ошибка с imgui.IsTextureValid')
            imgui.BulletText(u8'Улучшена стабильность при открытии фотографий')
        end
        imgui.EndChild()
        imgui.PopStyleVar(1)
        imgui.PopStyleColor(1)

        imgui.Spacing()

        
        imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.10, 0.12, 0.16, 0.40))
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 6.0)
        if imgui.BeginChild('##v15', imgui.ImVec2(0, 175), true) then
            imgui.TextColored(imgui.ImVec4(0.50, 0.70, 1.00, 1.00), u8' v1.5 - Автовставка')
            imgui.Separator()
            imgui.Spacing()
            imgui.BulletText(u8'Новая вкладка "Автовставка" в меню настроек')
            imgui.BulletText(u8'Создавайте карточки с готовым текстом для быстрой вставки в чат')
            imgui.BulletText(u8'Кнопка автовставки появляется при открытии чата')
            imgui.BulletText(u8'Возможность включать/выключать функцию автовставки')
        end
        imgui.EndChild()
        imgui.PopStyleVar(1)
        imgui.PopStyleColor(1)

        imgui.Spacing()

        
        imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.14, 0.10, 0.16, 0.40))
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 6.0)
        if imgui.BeginChild('##v14', imgui.ImVec2(0, 150), true) then
            imgui.TextColored(imgui.ImVec4(0.85, 0.50, 1.00, 1.00), u8' v1.4 - Улучшения интерфейса')
            imgui.Separator()
            imgui.Spacing()
            imgui.BulletText(u8'Добавлен blur-эффект на фон при открытии меню')
            imgui.BulletText(u8'Улучшен дизайн радиального меню')
            imgui.BulletText(u8'Добавлены анимации и визуальные эффекты')
        end
        imgui.EndChild()
        imgui.PopStyleVar(1)
        imgui.PopStyleColor(1)

        imgui.Spacing()

        
        imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.16, 0.12, 0.10, 0.40))
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 6.0)
        if imgui.BeginChild('##v13', imgui.ImVec2(0, 150), true) then
            imgui.TextColored(imgui.ImVec4(1.00, 0.70, 0.40, 1.00), u8' v1.3 - Комбинации клавиш')
            imgui.Separator()
            imgui.Spacing()
            imgui.BulletText(u8'Поддержка комбинаций клавиш (Ctrl+X, Alt+X, Shift+X)')
            imgui.BulletText(u8'До 3 клавиш в одной комбинации')
            imgui.BulletText(u8'Защита от конфликтов с системными клавишами SAMP')
        end
        imgui.EndChild()
        imgui.PopStyleVar(1)
        imgui.PopStyleColor(1)

        imgui.Spacing()

        
        imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.10, 0.14, 0.14, 0.40))
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 6.0)
        if imgui.BeginChild('##v12', imgui.ImVec2(0, 175), true) then
            imgui.TextColored(imgui.ImVec4(0.40, 0.90, 0.90, 1.00), u8' v1.2 - Автообновление')
            imgui.Separator()
            imgui.Spacing()
            imgui.BulletText(u8'Автоматическая проверка обновлений при запуске')
            imgui.BulletText(u8'Команда /scriptupd для обновления скрипта')
            imgui.BulletText(u8'Автозагрузка недостающих ресурсов (тексты, изображения, шрифты)')
            imgui.BulletText(u8'Опция выборочного обновления текстовых файлов')
        end
        imgui.EndChild()
        imgui.PopStyleVar(1)
        imgui.PopStyleColor(1)

        imgui.Spacing()

        
        imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.12, 0.10, 0.14, 0.40))
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 6.0)
        if imgui.BeginChild('##v11', imgui.ImVec2(0, 260), true) then
            imgui.TextColored(imgui.ImVec4(0.70, 0.50, 0.90, 1.00), u8' v1.1 - Первый релиз')
            imgui.Separator()
            imgui.Spacing()
            imgui.BulletText(u8'9 готовых правил для МВД с актуальной информацией')
            imgui.BulletText(u8'Полная законодательная база (Конституция, УК, КоАП, ФЗ)')
            imgui.BulletText(u8'Информация о закрытых территориях всех фракций')
            imgui.BulletText(u8'Интерактивные карты радаров и фотографии территорий')
            imgui.BulletText(u8'Радиальное меню с настраиваемыми кнопками')
            imgui.BulletText(u8'Умный поиск с синонимами')
            imgui.BulletText(u8'Гибкая система настройки под себя')
        end
        imgui.EndChild()
        imgui.PopStyleVar(1)
        imgui.PopStyleColor(1)

        imgui.SmoothScroll('##news_scroll', 80)
    end
    imgui.EndChild()
end

local function renderSettingsTab()
    resetIO()

    local is_capturing_any = (key_capture_mode ~= nil)
    local is_capturing_global = (key_capture_type == "global")
    local disabled_color = imgui.ImVec4(0.30, 0.30, 0.35, 0.60)

    if state.fonts.title then imgui.PushFont(state.fonts.title) end
    local title_text = u8'Команда активации'
    local title_w = imgui.CalcTextSize(title_text).x
    local window_w = imgui.GetWindowWidth()
    imgui.SetCursorPosX((window_w - title_w) / 2)
    imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), title_text)
    if state.fonts.title then imgui.PopFont() end
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
    
    if state.fonts.title then imgui.PushFont(state.fonts.title) end
    local title_text = u8'Горячие клавиши'
    local title_w = imgui.CalcTextSize(title_text).x
    local window_w = imgui.GetWindowWidth()
    imgui.SetCursorPosX((window_w - title_w) / 2)
    imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), title_text)
    if state.fonts.title then imgui.PopFont() end
    imgui.Spacing()
    
    local bind_text_global = is_capturing_global and u8'Нажмите клавишу или комбинацию... (Backspace отмена)' or (u8'Клавиша: '..u8(getKeyName(orule.config.globalHotkey))..u8' (нажмите для изменения)')
    local is_blocked_global = is_capturing_any and not is_capturing_global
    
    local desc_text = u8'Глобальная горячая клавиша для меню:'
    local desc_w = imgui.CalcTextSize(desc_text).x
    local window_w_desc = imgui.GetWindowWidth()
    imgui.SetCursorPosX((window_w_desc - desc_w) / 2)
    imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.90, 1.00), desc_text)
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
    
    
    imgui.Spacing()
    imgui.Spacing()

    if state.fonts.title then imgui.PushFont(state.fonts.title) end
    local title_text = u8'Обновление ресурсов'
    local title_w = imgui.CalcTextSize(title_text).x
    local window_w = imgui.GetWindowWidth()
    imgui.SetCursorPosX((window_w - title_w) / 2)
    imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), title_text)
    if state.fonts.title then imgui.PopFont() end
    imgui.Spacing()
    
    if is_capturing_any then
        imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, 0.5)
    end
    
    local auto_update_checkbox = imgui.new.bool(orule.config.autoUpdateTexts)
    if imgui.ToggleButton(u8'Автоматически обновлять текстовые файлы##auto_update', auto_update_checkbox) and not is_capturing_any then
        orule.config.autoUpdateTexts = auto_update_checkbox[0]
        saveConfig()
    end
    
    if imgui.IsItemHovered() then
        imgui.SetTooltip(u8'При выключении текстовые файлы не будут перезаписываться при обновлении.\nШрифты и изображения всё равно будут обновляться.')
    end
    
    imgui.Spacing()
    
    local show_images_checkbox = imgui.new.bool(orule.config.showImages)
    if imgui.ToggleButton(u8'Отображать изображения в правилах##show_img', show_images_checkbox) and not is_capturing_any then
        orule.config.showImages = show_images_checkbox[0]
        saveConfig()
        
        if orule.config.showImages then
            reloadTextures()
        else
            unloadTextures()
        end
    end
    
    if imgui.IsItemHovered() then
        imgui.SetTooltip(u8'Выключите, если при запуске скрипта игра зависает на пару секунд.\nКартинки территорий и карта радаров не будут загружаться.')
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

local function renderInteractionEditor()
    if state.fonts.main then imgui.PushFont(state.fonts.main) end

    local sw, sh = getScreenResolution()
    imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(600, 660), imgui.Cond.Always)

    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 10.0)
    imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.08, 0.08, 0.12, 0.98))
    imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.50, 0.45, 1.00, 0.50))

    local interaction_window_flags = imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize
    if imgui.Begin(u8'Редактор отыгровок взаимодействия##interaction_editor', state.windows.interaction_editor, interaction_window_flags) then
        if state.interaction.edit_index > 0 then
            local interactionQMs = cache.interactionQMs or loadInteractionQMs()
            local item = interactionQMs[state.interaction.edit_index]

            if item then
                imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8('Редактирование: ' .. item.title))
                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()

                imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.75, 1.00), u8'Название действия:')
                imgui.PushItemWidth(-1)
                if imgui.InputText('##interaction_name', state.interaction.buffers.name, 64) then
                    item.title = u8:decode(ffi.string(state.interaction.buffers.name))
                    saveInteractionQMs(interactionQMs)
                end
                imgui.PopItemWidth()

                imgui.Spacing()

                local enabled_checkbox = imgui.new.bool(item.enabled)
                if imgui.ToggleButton(u8('Включено##interaction_' .. state.interaction.edit_index), enabled_checkbox) then
                    item.enabled = enabled_checkbox[0]
                    saveInteractionQMs(interactionQMs)
                end

                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()

                if state.interaction.edit_mode == "content" then
                    imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.75, 1.00), u8'Текст отыгровки:')
                    imgui.TextColored(imgui.ImVec4(0.60, 0.60, 0.65, 0.90), u8'Нажмите кнопку "Теги и функции" для справки.')

                    local text_height = 280
                    imgui.PushStyleColor(imgui.Col.FrameBg, imgui.ImVec4(0.15, 0.15, 0.18, 1.00))
                    imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.50, 0.45, 1.00, 0.50))
                    imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 5.0)
                    imgui.PushStyleVarFloat(imgui.StyleVar.FrameBorderSize, 1.0)

                    if imgui.InputTextMultiline('##interaction_content', state.interaction.buffers.content, 4096,
                        imgui.ImVec2(-1, text_height)) then
                        item.content = u8:decode(ffi.string(state.interaction.buffers.content))
                        saveInteractionQMs(interactionQMs)
                    end

                    imgui.PopStyleVar(2)
                    imgui.PopStyleColor(2)
                else
                    imgui.BeginChild("##tags_help_interaction", imgui.ImVec2(-1, 310), false, imgui.WindowFlags.NoBackground)
                        imgui.Text(u8('Список доступных функций и тегов:'))
                        imgui.Spacing()

                        imgui.TextColored(imgui.ImVec4(1.0, 0.8, 0.2, 1.0), u8('Основные возможности:'))

                        local function copyToClipboard(text)
                            local len = #text + 1
                            local h_mem = kernel32.GlobalAlloc(0x0042, len)
                            
                            if h_mem ~= 0 then
                                local p_mem = kernel32.GlobalLock(h_mem)
                                if p_mem ~= nil then
                                    ffi.copy(p_mem, text, len - 1)
                                    kernel32.GlobalUnlock(h_mem)
                                    
                                    if user32.OpenClipboard(nil) ~= 0 then
                                        user32.EmptyClipboard()
                                        user32.SetClipboardData(1, h_mem)
                                        user32.CloseClipboard()
                                    end
                                end
                            end
                            sampAddChatMessage('[ORULE] Скопировано: ' .. text, 0x00FF00)
                        end

                        imgui.Text(u8('- ')); imgui.SameLine()
                        if imgui.Button(u8('<X>'), imgui.ImVec2(50, 25)) then copyToClipboard("<X>") end
                        imgui.SameLine()
                        imgui.TextColored(imgui.ImVec4(0.8, 0.8, 0.8, 1.0), u8('- Задержка (мс). 1000 = 1 сек.'))
                        imgui.TextColored(imgui.ImVec4(0.5, 0.5, 0.5, 1.0), u8('  Пример: /me взял паспорт<1500>/me открыл его'))

                        imgui.Text(u8('- ')); imgui.SameLine()
                        if imgui.Button(u8('*'), imgui.ImVec2(30, 25)) then copyToClipboard("*") end
                        imgui.SameLine()
                        imgui.TextColored(imgui.ImVec4(0.8, 0.8, 0.8, 1.0), u8('- Скриншот экрана (F8)'))
                        imgui.TextColored(imgui.ImVec4(0.5, 0.5, 0.5, 1.0), u8('  Пример: /time<300>*'))

                        imgui.Text(u8('- ')); imgui.SameLine()
                        if imgui.Button(u8('>>X'), imgui.ImVec2(50, 25)) then copyToClipboard(">>X") end
                        imgui.SameLine()
                        imgui.TextColored(imgui.ImVec4(0.8, 0.8, 0.8, 1.0), u8('- Вписать текст в чат (без отправки)'))
                        imgui.TextColored(imgui.ImVec4(0.5, 0.5, 0.5, 1.0), u8('  Пример: >>/ticket'))

                        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
                        imgui.TextColored(imgui.ImVec4(1.0, 0.8, 0.2, 1.0), u8('Теги:'))

                        imgui.Text(u8('- ')); imgui.SameLine()
                        if imgui.Button(u8('{id}'), imgui.ImVec2(50, 25)) then copyToClipboard("{id}") end
                        imgui.SameLine()
                        imgui.TextColored(imgui.ImVec4(0.8, 0.8, 0.8, 1.0), u8('- ID выбранного игрока'))
                        imgui.TextColored(imgui.ImVec4(0.5, 0.5, 0.5, 1.0), u8('  Пример: /cuff {id}'))

                        imgui.Text(u8('- ')); imgui.SameLine()
                        if imgui.Button(u8('{time}'), imgui.ImVec2(60, 25)) then copyToClipboard("{time}") end
                        imgui.SameLine()
                        imgui.TextColored(imgui.ImVec4(0.8, 0.8, 0.8, 1.0), u8('- Текущее время (МСК)'))

                        imgui.Text(u8('- ')); imgui.SameLine()
                        if imgui.Button(u8('{player}'), imgui.ImVec2(75, 25)) then copyToClipboard("{player}") end
                        imgui.SameLine()
                        imgui.TextColored(imgui.ImVec4(0.8, 0.8, 0.8, 1.0), u8('- Имя игрока (Nick_Name)'))

                    imgui.EndChild()
                end

                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()

                local button_width = (imgui.GetContentRegionAvail().x - imgui.GetStyle().ItemSpacing.x) / 2

                if imgui.Button(u8'Сохранить и закрыть', imgui.ImVec2(button_width, 35)) then
                    saveInteractionQMs(interactionQMs)
                    state.windows.interaction_editor[0] = false
                    state.interaction.edit_index = -1
                end

                imgui.SameLine()

                local toggle_text = state.interaction.edit_mode == "content" and u8'Теги и функции' or u8'К содержимому'
                if imgui.Button(toggle_text, imgui.ImVec2(button_width, 35)) then
                    state.interaction.edit_mode = (state.interaction.edit_mode == "content") and "tags" or "content"
                end

            else
                imgui.TextColored(imgui.ImVec4(1.0, 0.5, 0.5, 1.0), u8'Ошибка: действие не найдено')
                if imgui.Button(u8'Закрыть', imgui.ImVec2(-1, 35)) then
                    state.windows.interaction_editor[0] = false
                    state.interaction.edit_index = -1
                end
            end
        else
            imgui.TextColored(imgui.ImVec4(1.0, 0.5, 0.5, 1.0), u8'Ошибка: не выбрано действие для редактирования')
            if imgui.Button(u8'Закрыть', imgui.ImVec2(-1, 35)) then
                state.windows.interaction_editor[0] = false
            end
        end
    end
    imgui.End()
    imgui.PopStyleColor(2)
    imgui.PopStyleVar(1)
    if state.fonts.main then imgui.PopFont() end
end

local function renderRadialEditor()
    if state.fonts.main then imgui.PushFont(state.fonts.main) end

    local sw, sh = getScreenResolution()
    imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(600, 660), imgui.Cond.Always)

    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 10.0)
    imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.08, 0.08, 0.12, 0.98))
    imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.50, 0.45, 1.00, 0.50))

    local radial_window_flags = imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize
    if imgui.Begin(u8'Редактор радиального меню##radial_editor', state.windows.radial_editor, radial_window_flags) then
        if state.radial_edit.index > 0 and state.radial_edit.index <= #radialMenu.buttons then
            local btn = radialMenu.buttons[state.radial_edit.index]
            local userData = cache.userQMs or loadUserQMs()
            local item = userData[state.radial_edit.index]

            if btn then
                imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8('Кнопка #' .. state.radial_edit.index))
                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()

                imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.75, 1.00), u8('Название кнопки:'))
                imgui.PushItemWidth(-1)
                if imgui.InputText('##radial_name', state.radial_edit.name_buffer, 64) then
                    btn.name = u8:decode(ffi.string(state.radial_edit.name_buffer))
                    if item then
                        item.title = btn.name
                    end
                    saveConfig()
                    saveUserQMs(userData)
                end
                imgui.PopItemWidth()

                imgui.Spacing()

                if imgui.ToggleButton(u8('Включено##radial_edit'), state.radial_edit.enabled) then
                    btn.enabled = state.radial_edit.enabled[0]
                    if item then
                        item.enabled = btn.enabled
                    end
                    saveConfig()
                    saveUserQMs(userData)
                end

                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()

                if state.radial_edit.mode == "content" then
                    imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.75, 1.00), u8('Текст отыгровки:'))
                    imgui.TextColored(imgui.ImVec4(0.60, 0.60, 0.65, 0.90), u8('Используйте теги "тег в теге" для задержки.'))

                    local text_height = 280
                    imgui.PushStyleColor(imgui.Col.FrameBg, imgui.ImVec4(0.15, 0.15, 0.18, 1.00))
                    imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.50, 0.45, 1.00, 0.50))
                    imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 5.0)
                    imgui.PushStyleVarFloat(imgui.StyleVar.FrameBorderSize, 1.0)

                    if imgui.InputTextMultiline('##radial_content', state.radial_edit.content_buffer, 4096,
                        imgui.ImVec2(-1, text_height)) then
                        if item then
                            item.content = u8:decode(ffi.string(state.radial_edit.content_buffer))
                            saveUserQMs(userData)
                        end
                    end

                    imgui.PopStyleVar(2)
                    imgui.PopStyleColor(2)
                else
                    imgui.BeginChild("##tags_help_radial", imgui.ImVec2(-1, 310), false, imgui.WindowFlags.NoBackground)
                        imgui.Text(u8('Доступные специальные теги в тегах:'))

                        imgui.Spacing()

                        imgui.TextColored(imgui.ImVec4(1.0, 0.8, 0.2, 1.0), u8('Специальные теги:'))

                        local function copyToClipboard(text)
                            local len = #text + 1
                            local h_mem = kernel32.GlobalAlloc(0x0042, len)
                            
                            if h_mem ~= 0 then
                                local p_mem = kernel32.GlobalLock(h_mem)
                                if p_mem ~= nil then
                                    ffi.copy(p_mem, text, len - 1)
                                    kernel32.GlobalUnlock(h_mem)
                                    
                                    if user32.OpenClipboard(nil) ~= 0 then
                                        user32.EmptyClipboard()
                                        user32.SetClipboardData(1, h_mem)
                                        user32.CloseClipboard()
                                    end
                                end
                            end
                            sampAddChatMessage('[ORULE] Скопировано: ' .. text, 0x00FF00)
                        end

                        imgui.Text(u8('- ')); imgui.SameLine()
                        if imgui.Button(u8('<X>'), imgui.ImVec2(50, 35)) then copyToClipboard("<X>") end
                        imgui.SameLine()
                        imgui.TextColored(imgui.ImVec4(0.8, 0.8, 0.8, 1.0), u8('- Задержка (мс). 1000 = 1 сек.'))
                        imgui.TextColored(imgui.ImVec4(0.5, 0.5, 0.5, 1.0), u8('  Пример: /me начал проверять<1500>/me закончил осмотр'))

                        imgui.Text(u8('- ')); imgui.SameLine()
                        if imgui.Button(u8('*'), imgui.ImVec2(30, 35)) then copyToClipboard("*") end
                        imgui.SameLine()
                        imgui.TextColored(imgui.ImVec4(0.8, 0.8, 0.8, 1.0), u8('- Нажатие клавиши (F8)'))
                        imgui.TextColored(imgui.ImVec4(0.5, 0.5, 0.5, 1.0), u8('  Пример: /time<300>*'))

                        imgui.Text(u8('- ')); imgui.SameLine()
                        if imgui.Button(u8('>>X'), imgui.ImVec2(50, 35)) then copyToClipboard(">>X") end
                        imgui.SameLine()
                        imgui.TextColored(imgui.ImVec4(0.8, 0.8, 0.8, 1.0), u8('- Отправка команды в чат (для команд)'))
                        imgui.TextColored(imgui.ImVec4(0.5, 0.5, 0.5, 1.0), u8('  Пример: >>/ticket'))

                        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
                        imgui.TextColored(imgui.ImVec4(1.0, 0.8, 0.2, 1.0), u8('Теги:'))

                        imgui.Text(u8('- ')); imgui.SameLine()
                        if imgui.Button(u8('{id}'), imgui.ImVec2(50, 35)) then copyToClipboard("{id}") end
                        imgui.SameLine()
                        imgui.TextColored(imgui.ImVec4(0.8, 0.8, 0.8, 1.0), u8('- ID выбранного игрока'))
                        imgui.TextColored(imgui.ImVec4(0.5, 0.5, 0.5, 1.0), u8('  Пример: /cuff {id}'))

                        imgui.Text(u8('- ')); imgui.SameLine()
                        if imgui.Button(u8('{time}'), imgui.ImVec2(60, 35)) then copyToClipboard("{time}") end
                        imgui.SameLine()
                        imgui.TextColored(imgui.ImVec4(0.8, 0.8, 0.8, 1.0), u8('- Текущее время (час)'))

                        imgui.Text(u8('- ')); imgui.SameLine()
                        if imgui.Button(u8('{player}'), imgui.ImVec2(75, 35)) then copyToClipboard("{player}") end
                        imgui.SameLine()
                        imgui.TextColored(imgui.ImVec4(0.8, 0.8, 0.8, 1.0), u8('- Имя игрока (Nick_Name)'))

                    imgui.EndChild()
                end

                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()

                local button_width = (imgui.GetContentRegionAvail().x - imgui.GetStyle().ItemSpacing.x) / 2

                if imgui.Button(u8'Сохранить и закрыть', imgui.ImVec2(button_width, 35)) then
                    saveUserQMs(userData)
                    saveConfig()
                    state.windows.radial_editor[0] = false
                    state.radial_edit.index = 0
                end

                imgui.SameLine()

                local toggle_text = state.radial_edit.mode == "content" and u8'К тегам' or u8'К содержимому'
                if imgui.Button(toggle_text, imgui.ImVec2(button_width, 35)) then
                    state.radial_edit.mode = (state.radial_edit.mode == "content") and "tags" or "content"
                end

            else
                imgui.TextColored(imgui.ImVec4(1.0, 0.5, 0.5, 1.0), u8'Ошибка: кнопка не найдена')
                if imgui.Button(u8'Закрыть', imgui.ImVec2(-1, 35)) then
                    state.windows.radial_editor[0] = false
                    state.radial_edit.index = 0
                end
            end
        else
            imgui.TextColored(imgui.ImVec4(1.0, 0.5, 0.5, 1.0), u8'Ошибка: не выбран индекс для редактирования')
            if imgui.Button(u8'Закрыть', imgui.ImVec2(-1, 35)) then
                state.windows.radial_editor[0] = false
                state.radial_edit.index = 0
            end
        end
    end
    imgui.End()
    imgui.PopStyleColor(2)
    imgui.PopStyleVar(1)
    if state.fonts.main then imgui.PopFont() end
end

local function renderAutoInsertTab()
    resetIO()

    if state.fonts.title then imgui.PushFont(state.fonts.title) end
    local title_text = u8'Автовставка'
    local title_w = imgui.CalcTextSize(title_text).x
    local window_w = imgui.GetWindowWidth()
    imgui.SetCursorPosX((window_w - title_w) / 2)
    imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), title_text)
    if state.fonts.title then imgui.PopFont() end
    imgui.Spacing()

    local auto_insert_checkbox = imgui.new.bool(orule.config.autoInsertEnabled)
    if imgui.ToggleButton(u8'Включить автовставку##auto_insert', auto_insert_checkbox) then
        orule.config.autoInsertEnabled = auto_insert_checkbox[0]
        saveConfig()
    end
    imgui.Spacing()

    if imgui.Button(u8'Создать новую карточку', imgui.ImVec2(-1, 35)) then
        table.insert(orule.autoInsertCards, {title = "Новая карточка", content = ""})
        saveAutoInsertCards(orule.autoInsertCards)
    end
    imgui.Spacing()

    imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.80, 1.00), u8('Количество карточек: ') .. #orule.autoInsertCards)
    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    for i, card in ipairs(orule.autoInsertCards) do
        local card_bg = imgui.ImVec4(0.05, 0.05, 0.08, 0.98)
        local card_border = imgui.ImVec4(0.50, 0.45, 1.00, 0.50)

        imgui.PushStyleColor(imgui.Col.ChildBg, card_bg)
        imgui.PushStyleColor(imgui.Col.Border, card_border)
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 6.0)
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildBorderSize, 1.5)

        if imgui.BeginChild('##autoinsert_card_' .. i, imgui.ImVec2(0, 240), true) then
            imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8'Название карточки:')

            if not card.title_buffer then
                card.title_buffer = imgui.new.char[257](u8(card.title or ""))
            end

            imgui.SetNextItemWidth(-1)
            imgui.InputText('##title_' .. i, card.title_buffer, 256)

            imgui.Spacing()
            imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8'Текст для вставки:')
            imgui.Spacing()

            if not card.input_buffer then
                card.input_buffer = imgui.new.char[1025](u8(card.content or ""))
            end

            imgui.SetNextItemWidth(-1)
            imgui.InputText('##content_' .. i, card.input_buffer, 1024)

            imgui.Spacing()
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.60, 0.20, 0.20, 0.80))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.70, 0.25, 0.25, 0.90))
            imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.50, 0.15, 0.15, 1.00))

            if imgui.Button(u8'Удалить##delete_' .. i, imgui.ImVec2(80, 35)) then
                table.remove(orule.autoInsertCards, i)
                saveAutoInsertCards(orule.autoInsertCards)
                sampAddChatMessage('[ORULE] Карточка удалена!', 0xFF4444)
            end

            imgui.PopStyleColor(3)

            imgui.SameLine()

            if imgui.Button(u8'Сохранить##save_' .. i, imgui.ImVec2(-1, 35)) then
                local title_utf8 = ffi.string(card.title_buffer):gsub('\0', '')
                local content_utf8 = ffi.string(card.input_buffer):gsub('\0', '')
                local success_title, title_cp1251 = pcall(u8.decode, u8, title_utf8)
                local success_content, content_cp1251 = pcall(u8.decode, u8, content_utf8)

                if success_title and success_content then
                    card.title = title_cp1251
                    card.content = content_cp1251
                    saveAutoInsertCards(orule.autoInsertCards)
                    sampAddChatMessage('[ORULE] Карточка сохранена!', 0x45AFFF)
                else
                    sampAddChatMessage('[ORULE] Ошибка сохранения: некорректные символы!', 0xFF4444)
                end
            end
        end
        imgui.EndChild()

        imgui.PopStyleVar(2)
        imgui.PopStyleColor(2)

        imgui.Spacing()
    end

    if #orule.autoInsertCards == 0 then
        imgui.TextColored(imgui.ImVec4(0.60, 0.60, 0.70, 1.00), u8'Карточки отсутствуют. Нажмите "Создать новую карточку" для добавления первой.')
    end
end

local function renderInteractionTab()
    if state.fonts.title then imgui.PushFont(state.fonts.title) end
    local title_text = u8'Взаимодействие с игроками'
    local title_w = imgui.CalcTextSize(title_text).x
    local window_w = imgui.GetWindowWidth()
    imgui.SetCursorPosX((window_w - title_w) / 2)
    imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), title_text)
    if state.fonts.title then imgui.PopFont() end
    imgui.Spacing()
    local subtitle_text = u8'Быстрые действия для взаимодействия с другими игроками'
    local subtitle_w = imgui.CalcTextSize(subtitle_text).x
    local window_w = imgui.GetWindowWidth()
    imgui.SetCursorPosX((window_w - subtitle_w) / 2)
    imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.75, 0.90), subtitle_text)
    imgui.Spacing()
    imgui.Spacing()

    imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.05, 0.05, 0.08, 0.98))
    imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.50, 0.45, 1.00, 0.50))
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 8.0)
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildBorderSize, 1.5)

    if imgui.BeginChild('##interaction_toggle', imgui.ImVec2(0, 115), true) then
        imgui.Spacing()
        imgui.Indent(10)

        local enabled_checkbox = imgui.new.bool(orule.config.interactionEnabled)
        if imgui.ToggleButton(u8('Включить модуль взаимодействия##interaction_global'), enabled_checkbox) then
            orule.config.interactionEnabled = enabled_checkbox[0]
            saveConfig()
        end

        imgui.Spacing()
        imgui.TextColored(imgui.ImVec4(0.60, 0.60, 0.65, 0.90), u8'Включает/выключает все функции взаимодействия')

        imgui.Unindent(10)
    end
    imgui.EndChild()
    imgui.PopStyleVar(2)
    imgui.PopStyleColor(2)

    imgui.Spacing()
    imgui.Spacing()

    if not orule.config.interactionEnabled then
        imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.15, 0.10, 0.10, 0.95))
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 8.0)
        if imgui.BeginChild('##interaction_disabled', imgui.ImVec2(0, 60), true) then
            imgui.Spacing()
            local text = u8'Модуль взаимодействия отключён'
            local text_width = imgui.CalcTextSize(text).x
            imgui.SetCursorPosX((imgui.GetWindowWidth() - text_width) / 2)
            imgui.TextColored(imgui.ImVec4(1.0, 0.5, 0.5, 1.0), text)
        end
        imgui.EndChild()
        imgui.PopStyleVar(1)
        imgui.PopStyleColor(1)
        return
    end

    if state.fonts.title then imgui.PushFont(state.fonts.title) end
    local title_text = u8'Режим активации'
    local title_w = imgui.CalcTextSize(title_text).x
    local window_w = imgui.GetWindowWidth()
    imgui.SetCursorPosX((window_w - title_w) / 2)
    imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), title_text)
    if state.fonts.title then imgui.PopFont() end
    imgui.Spacing()

    imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.05, 0.05, 0.08, 0.98))
    imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.50, 0.45, 1.00, 0.50))
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 8.0)
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildBorderSize, 1.5)

    if imgui.BeginChild('##interaction_mode', imgui.ImVec2(0, 120), true) then
        imgui.Spacing()
        
        local padding = 15
        local available_width = imgui.GetContentRegionAvail().x - (padding * 2)
        local spacing = 10
        local btn_width = (available_width - spacing) / 2

        imgui.SetCursorPosX(imgui.GetCursorPosX() + padding)

        imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(0, 0))
        imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 8.0)

        local keys_active = (orule.config.interactionMode == 0)
        if keys_active then
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.50, 0.45, 1.00, 1.00))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.55, 0.50, 1.00, 1.00))
            imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.45, 0.40, 0.95, 1.00))
        else
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.20, 0.20, 0.25, 0.80))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.30, 0.30, 0.35, 0.90))
            imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.25, 0.25, 0.30, 1.00))
        end

        if imgui.Button(u8'Клавиши##mode_keys', imgui.ImVec2(btn_width, 40)) then
            orule.config.interactionMode = 0
            saveConfig()
        end
        imgui.PopStyleColor(3)

        imgui.SameLine(0, spacing)

        
        local menu_active = (orule.config.interactionMode == 1)
        if menu_active then
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.50, 0.45, 1.00, 1.00))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.55, 0.50, 1.00, 1.00))
            imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.45, 0.40, 0.95, 1.00))
        else
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.20, 0.20, 0.25, 0.80))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.30, 0.30, 0.35, 0.90))
            imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.25, 0.25, 0.30, 1.00))
        end

        if imgui.Button(u8'Меню##mode_menu', imgui.ImVec2(btn_width, 40)) then
            orule.config.interactionMode = 1
            saveConfig()
        end
        imgui.PopStyleColor(3)

        imgui.PopStyleVar(2) 

        imgui.Spacing()
        
        
        imgui.SetCursorPosX(imgui.GetCursorPosX() + padding)
        local mode_desc = orule.config.interactionMode == 0
            and u8'Используйте горячие клавиши для быстрых действий'
            or u8'Используйте меню на экране для выбора действий'
        imgui.TextColored(imgui.ImVec4(0.60, 0.60, 0.65, 0.90), mode_desc)
    end
    imgui.EndChild()
    imgui.PopStyleVar(2)
    imgui.PopStyleColor(2)

    imgui.Spacing()
    imgui.Spacing()

    
    if orule.config.interactionMode == 0 then
        
        
        if state.fonts.title then imgui.PushFont(state.fonts.title) end
        local title_text = u8'Настройка горячих клавиш'
        local title_w = imgui.CalcTextSize(title_text).x
        local window_w = imgui.GetWindowWidth()
        imgui.SetCursorPosX((window_w - title_w) / 2)
        imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), title_text)
        if state.fonts.title then imgui.PopFont() end
        imgui.Spacing()
        
        if state.fonts.title then imgui.PushFont(state.fonts.title) end
        local desc_text = u8'Наведите прицел на игрока и нажмите клавишу/комбинацию'
        local desc_w = imgui.CalcTextSize(desc_text).x
        local window_w_desc = imgui.GetWindowWidth()
        imgui.SetCursorPosX((window_w_desc - desc_w) / 2)
        imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.75, 0.90), desc_text)
        if state.fonts.title then imgui.PopFont() end
        imgui.Spacing()
        imgui.Spacing()

        
        local interactionQMs = cache.interactionQMs or loadInteractionQMs()

        
        local action_titles = {}
        for _, item in ipairs(interactionQMs) do
            if item.enabled then
                action_titles[item.action] = item.title
            end
        end

        
        imgui.Columns(2, 'key_binds_grid', false)

        
        for i, bind in ipairs(cache.interactionKeys) do
            local action_title = action_titles[bind.action] or (bind.action .. " (неактивно)")
            local has_key = (bind.key and #bind.key > 0)
            local current_card_height = has_key and 207 or 160

            imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.05, 0.05, 0.08, 0.98))
            imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.50, 0.45, 1.00, 0.50))
            imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 6.0)
            imgui.PushStyleVarFloat(imgui.StyleVar.ChildBorderSize, 1.0)

            if imgui.BeginChild('##key_bind_' .. i, imgui.ImVec2(0, current_card_height), true) then
                imgui.Spacing()
                
                
                imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8(action_title))
                
                imgui.Spacing()

                
                local key_text = "Не назначено"
                if bind.key and #bind.key > 0 then
                    local key_names = {}
                    for _, key_code in ipairs(bind.key) do
                        table.insert(key_names, getKeyName(key_code))
                    end
                    key_text = table.concat(key_names, " + ")
                end

                imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.75, 1.00), u8('Клавиша: '))
                imgui.SameLine()
                imgui.TextColored(imgui.ImVec4(0.90, 0.90, 0.95, 1.00), u8(key_text))

                imgui.Spacing()
                imgui.Spacing()

                
                local is_capturing_this = (interaction_key_capture_mode == "waiting" and interaction_key_capture_index == i)
                local is_capturing_any = (interaction_key_capture_mode == "waiting")
                
                if is_capturing_this then
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.90, 0.60, 0.20, 1.00))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.95, 0.65, 0.25, 1.00))
                    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.85, 0.55, 0.15, 1.00))
                    if imgui.Button(u8'Нажмите клавишу...##wait_' .. i, imgui.ImVec2(-1, 30)) then
                        
                    end
                    imgui.PopStyleColor(3)
                else
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.50, 0.45, 1.00, 0.80))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.60, 0.55, 1.00, 0.90))
                    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.40, 0.35, 0.90, 1.00))
                    if imgui.Button(u8('Изменить##' .. i), imgui.ImVec2(-1, 30)) and not is_capturing_any then
                        interaction_key_capture_mode = "waiting"
                        interaction_key_capture_index = i
                        sampAddChatMessage('[ORULE] Нажмите клавишу или комбинацию клавиш для действия "' .. action_title .. '"', 0x00FF00)
                    end
                    imgui.PopStyleColor(3)
                end

                
                if has_key then
                    imgui.Spacing()
                    
                    if is_capturing_any then
                        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.30, 0.30, 0.35, 0.60))
                        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.30, 0.30, 0.35, 0.60))
                        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.30, 0.30, 0.35, 0.60))
                    else
                        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.60, 0.20, 0.20, 0.80))
                        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.70, 0.25, 0.25, 0.90))
                        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.50, 0.15, 0.15, 1.00))
                    end

                    if imgui.Button(u8('Удалить бинд##del_' .. i), imgui.ImVec2(-1, 30)) and not is_capturing_any then
                        bind.key = {}
                        saveInteractionKeyBinds(cache.interactionKeys)
                        sampAddChatMessage('[ORULE] Бинд для действия "' .. action_title .. '" удален', 0x00FF00)
                    end
                    
                    imgui.PopStyleColor(3)
                end
                
                imgui.Spacing()
            end
            imgui.EndChild()
            imgui.PopStyleVar(2)
            imgui.PopStyleColor(2)

            imgui.NextColumn()
        end
        
        imgui.Columns(1)

        imgui.Spacing()
        imgui.TextColored(imgui.ImVec4(0.60, 0.60, 0.70, 0.90), u8('Поддерживаются комбинации клавиш (до 3 клавиш)'))
        imgui.TextColored(imgui.ImVec4(0.60, 0.60, 0.70, 0.90), u8('Пример: Ctrl + Shift + 1, Alt + 2, просто 3'))

    else
        
        imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8'Меню взаимодействия')
        imgui.Spacing()


        
        imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8'Превью меню')
        imgui.Spacing()

        imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.05, 0.05, 0.08, 0.98))
        imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.50, 0.45, 1.00, 0.50))
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 10.0)
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildBorderSize, 2.0)

        if imgui.BeginChild('##interaction_preview', imgui.ImVec2(0, 370), true) then
            imgui.Spacing()

            
            local preview_title = u8'Взаимодействие с игроком'
            local title_width = imgui.CalcTextSize(preview_title).x
            imgui.SetCursorPosX((imgui.GetWindowWidth() - title_width) / 2)
            imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), preview_title)

            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            
            local interactionQMs = cache.interactionQMs or loadInteractionQMs()
            local enabled_actions = {}

            for i, item in ipairs(interactionQMs) do
                if item.enabled then
                    table.insert(enabled_actions, {index = i, item = item})
                end
            end

            for i, action_data in ipairs(enabled_actions) do
                local item = action_data.item
                local original_index = action_data.index

                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.15, 0.15, 0.20, 0.90))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.25, 0.25, 0.35, 1.00))
                imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.20, 0.20, 0.30, 1.00))
                imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 6.0)

                local btn_text = u8('[' .. i .. '] ' .. item.title)
                if imgui.Button(btn_text .. '##preview_' .. i, imgui.ImVec2(-1, 32)) then
                    
                    state.windows.interaction_editor[0] = true
                    state.interaction.edit_index = original_index
                    state.interaction.edit_mode = "content" 

                    
                    
                    
                    
                    ffi.fill(state.interaction.buffers.name, 65, 0)
                    ffi.fill(state.interaction.buffers.content, 4097, 0)

                    
                    local title_u8 = u8(item.title or "")
                    local content_u8 = u8(item.content or "")

                    
                    
                    ffi.copy(state.interaction.buffers.name, title_u8, math.min(#title_u8, 64))
                    ffi.copy(state.interaction.buffers.content, content_u8, math.min(#content_u8, 4096))

                    state.interaction.buffers.enabled[0] = item.enabled
                end

                imgui.PopStyleVar(1)
                imgui.PopStyleColor(3)

                if i < #enabled_actions then
                    imgui.Spacing()
                end
            end
        end
        imgui.EndChild()
        imgui.PopStyleVar(2)
        imgui.PopStyleColor(2)
    end

    imgui.Spacing()
    imgui.Spacing()

    
    imgui.TextColored(imgui.ImVec4(0.60, 0.60, 0.70, 0.90), u8'Нажмите на кнопку действия выше, чтобы отредактировать отыгровку')

    imgui.Spacing()
    imgui.Spacing()

    
    imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.08, 0.08, 0.12, 1.00))
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 6.0)
    if imgui.BeginChild('##interaction_info', imgui.ImVec2(0, 125), true) then
        imgui.Spacing()
        imgui.Indent(10)
        imgui.TextColored(imgui.ImVec4(1.00, 0.80, 0.30, 1.00), u8'Примечание:')
        imgui.Spacing()
        imgui.PushTextWrapPos(0)
        imgui.TextColored(imgui.ImVec4(0.75, 0.75, 0.80, 0.90), u8'Данный модуль находится в разработке. Все действия будут выполняться с автоматическими отыгровками согласно правилам сервера.')
        imgui.PopTextWrapPos()
        imgui.Unindent(10)
    end
    imgui.EndChild()
    imgui.PopStyleVar(1)
    imgui.PopStyleColor(1)

    imgui.Spacing()
    imgui.Spacing()
end

local function renderAutoInsertButton()
    if state.fonts.main then imgui.PushFont(state.fonts.main) end

    local sw, sh = getScreenResolution()
    local btn_x = 15
    local btn_y = sh * 0.45

    local btn_width = 140
    local btn_height = 35
    imgui.SetNextWindowPos(imgui.ImVec2(btn_x, btn_y), imgui.Cond.Always)
    imgui.SetNextWindowSize(imgui.ImVec2(btn_width, btn_height), imgui.Cond.Always)

    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(0, 0))
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 5.0)

    imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0, 0, 0, 0))
    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.2, 0.4, 0.8, 0.9))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.3, 0.5, 0.9, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.1, 0.3, 0.7, 1.0))
    if imgui.Begin('##auto_insert_button', nil, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoBackground) then
        
        if imgui.Button(u8'Автовставка', imgui.ImVec2(btn_width, btn_height)) then
            state.autoinsert.menu_active = not state.autoinsert.menu_active
        end

        imgui.End()
    end

    imgui.PopStyleColor(4)
    imgui.PopStyleVar(2)
    if state.autoinsert.menu_active then
        imgui.SetNextWindowPos(imgui.ImVec2(btn_x, btn_y + btn_height + 5), imgui.Cond.Always)
        imgui.SetNextWindowSize(imgui.ImVec2(300, 200), imgui.Cond.Always)

        imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(8, 8))
        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.1, 0.1, 0.13, 0.95))
        
        if imgui.Begin('##auto_insert_menu', nil, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse) then
            
            imgui.TextColored(imgui.ImVec4(0.7, 0.7, 1.0, 1.0), u8'Выберите карточку:')
            imgui.Separator()
            imgui.Spacing()

            if #orule.autoInsertCards == 0 then
                imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.7, 1.0), u8('Список пуст.'))
                if imgui.Button(u8'Настроить', imgui.ImVec2(-1, 25)) then
                    state.windows.main[0] = true
                    state.autoinsert.menu_active = false
                end
            else
                for i, card in ipairs(orule.autoInsertCards) do
                    local btn_name = (card.title and #card.title > 0) and card.title or ("Карточка #"..i)
                    
                    if imgui.Button(u8(btn_name) .. '##card_' .. i, imgui.ImVec2(-1, 30)) then
                        if card.content and #card.content > 0 then
                            sampSetChatInputText(card.content)
                            sampAddChatMessage('[ORULE] Текст вставлен!', 0x45AFFF)
                        end
                        state.autoinsert.menu_active = false
                    end
                end
            end

            imgui.End()
        end
        imgui.PopStyleColor(1)
        imgui.PopStyleVar(1)
    end

    if state.fonts.main then imgui.PopFont() end
end

local function renderInfoWindow()
    local sw, sh = getScreenResolution()
    local adaptive_height = math.min(orule.config.windowHeight or 700, sh * 0.75)
    local adaptive_width = math.min(orule.config.windowWidth or 750, sw * 0.75)

    local window_pos_x = math.max(10, math.min(sw / 2 - adaptive_width / 2, sw - adaptive_width - 10))
    local window_pos_y = math.max(10, math.min(sh / 2 - adaptive_height / 2, sh - adaptive_height - 10))

    imgui.SetNextWindowPos(imgui.ImVec2(window_pos_x, window_pos_y), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(adaptive_width, adaptive_height), imgui.Cond.FirstUseEver)

    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 12.0)
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 2.0)
    imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.50, 0.45, 1.00, 0.90))

    local window_flags = imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize

    if imgui.Begin(u8'Добро пожаловать в ORULE!##info_window', state.windows.info, window_flags) then
        imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.08, 0.08, 0.12, 1.00))
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 8.0)
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildBorderSize, 1.0)

        if imgui.BeginChild('##info_header', imgui.ImVec2(0, 121), true) then
            if state.fonts.title then imgui.PushFont(state.fonts.title) end

            local window_width = imgui.GetWindowWidth()
            local title_text = u8('ORULE v' .. SCRIPT_VERSION)
            local title_width = imgui.CalcTextSize(title_text).x

            imgui.SetCursorPosY(15)
            imgui.SetCursorPosX((window_width - title_width) * 0.5)
            imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), title_text)

            if state.fonts.title then imgui.PopFont() end

            imgui.Spacing()

            if state.fonts.main then imgui.PushFont(state.fonts.main) end
            local subtitle_text = u8'Продвинутый менеджер правил с overlay-интерфейсом'
            local subtitle_width = imgui.CalcTextSize(subtitle_text).x
            imgui.SetCursorPosX((window_width - subtitle_width) * 0.5)
            imgui.TextColored(imgui.ImVec4(0.90, 0.90, 0.95, 1.00), subtitle_text)

            imgui.Spacing()

            local author_text = u8'Автор: Lev Exelent (vk.com/e11evated)'
            local author_width = imgui.CalcTextSize(author_text).x
            imgui.SetCursorPosX((window_width - author_width) * 0.5)
            imgui.TextColored(imgui.ImVec4(0.80, 0.80, 0.85, 1.00), author_text)
            if state.fonts.main then imgui.PopFont() end
        end
        imgui.EndChild()
        imgui.PopStyleVar(2)
        imgui.PopStyleColor(1)

        imgui.Spacing()
        imgui.Spacing()

        if state.fonts.main then imgui.PushFont(state.fonts.main) end

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
            
            imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.05, 0.05, 0.08, 0.98))
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
            
            imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.05, 0.05, 0.08, 0.98))
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
            
            imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.05, 0.05, 0.08, 0.98))
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
            
            imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.05, 0.05, 0.08, 0.98))
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
        
        imgui.SmoothScroll('##info_content_scroll', 80)
        imgui.EndChild()
        imgui.PopStyleColor(1)

        if state.fonts.main then imgui.PopFont() end

        imgui.Spacing()

        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.50, 0.45, 1.00, 0.90))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.60, 0.55, 1.00, 1.00))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.40, 0.35, 0.90, 1.00))
        if state.fonts.title then imgui.PushFont(state.fonts.title) end

        local button_text = u8'Продолжить'
        
        local button_width = get_middle_button_x(1)
        local window_width = imgui.GetWindowWidth()
        imgui.SetCursorPosX((window_width - button_width) * 0.5)

        if imgui.Button(button_text, imgui.ImVec2(button_width, 45)) then
            state.windows.info[0] = false
            info_window_shown_once = true
            orule.config.firstLaunch = false
            saveConfig()
            state.windows.main[0] = true
            imgui.Process = true
        end

        if state.fonts.title then imgui.PopFont() end
        imgui.PopStyleColor(3)
    end
    imgui.End()

    imgui.PopStyleColor(1)
    imgui.PopStyleVar(2)
end

local function renderWindow()
    local sw, sh = getScreenResolution()
    local bg_draw_list = imgui.GetBackgroundDrawList()
    mimgui_blur.apply(bg_draw_list, 12.0)

    
    local bg_color_u32 = imgui.ColorConvertFloat4ToU32(RENDER_CONST.BG_MAIN)
    bg_draw_list:AddRectFilled(RENDER_CONST.ZERO, imgui.ImVec2(sw, sh), bg_color_u32)

    
    local win_w = orule.config.windowWidth or 1600
    local win_h = orule.config.windowHeight or 1100
    win_w = math.min(win_w, sw * 0.95)
    win_h = math.min(win_h, sh * 0.95)

    local win_x = (sw - win_w) / 2
    local win_y = (sh - win_h) / 2

    imgui.SetNextWindowPos(imgui.ImVec2(win_x, win_y), imgui.Cond.Appearing)
    imgui.SetNextWindowSize(imgui.ImVec2(win_w, win_h), imgui.Cond.Appearing)

    if state.fonts.main then imgui.PushFont(state.fonts.main) end

    
    imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0, 0, 0, 0))
    imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0, 0, 0, 0))
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(0, 0))

    local main_flags = imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize 
    
    if imgui.Begin('##main_container', state.windows.main, main_flags) then
         if not state.first_render then
            state.first_render = true
            imgui.Text(u8'Загрузка...')
            imgui.End()
            imgui.PopStyleVar(1)
            imgui.PopStyleColor(2)
            if state.fonts.main then imgui.PopFont() end
            return
        end
        
        
        local sidebar_width = 220 
        
        
        imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.08, 0.08, 0.12, 0.98))
        imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.50, 0.45, 1.00, 0.50))
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 10.0)
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildBorderSize, 1.0) 
        imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(10, 8)) 
        
        local sidebar_flags = imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse

        if imgui.BeginChild('##sidebar', imgui.ImVec2(sidebar_width, 0), true, sidebar_flags) then
            
            
            if state.fonts.title then imgui.PushFont(state.fonts.title) end
            local logo_text = u8'ORULE'
            local logo_w = imgui.CalcTextSize(logo_text).x
            imgui.SetCursorPosX((sidebar_width - logo_w) / 2)
            imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), logo_text)
            if state.fonts.title then imgui.PopFont() end
            
            
            local ver_text = u8('v'..SCRIPT_VERSION)
            local ver_w = imgui.CalcTextSize(ver_text).x
            imgui.SetCursorPosX((sidebar_width - ver_w) / 2)
            imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.65, 1.0), ver_text)
            
            imgui.Spacing(); imgui.Separator(); imgui.Spacing(); imgui.Spacing()
            
            
            local tabs = {
                {id = 6, label = "Новости"},
                {id = 1, label = "Правила"},
                {id = 2, label = "Радиальное меню"},
                {id = 4, label = "Автовставка"},
                {id = 5, label = "Взаимодействие"},
                {id = 3, label = "Настройки"}
            }
            
            local btn_height = 45
            
            local spacing_size = imgui.GetStyle().ItemSpacing.y
            local start_pos = imgui.GetCursorScreenPos()
            local dl = imgui.GetWindowDrawList()
            
            local target_y = 0
            
            
            for i, tab in ipairs(tabs) do
                if state.active_tab == tab.id then
                    
                    target_y = (i - 1) * (btn_height + spacing_size)
                    break
                end
            end
            
            if state.tab_anim_y == nil then state.tab_anim_y = target_y end
            state.tab_anim_y = bringFloatTo(state.tab_anim_y, target_y, 0.35)
            
            
            local anim_rect_min = imgui.ImVec2(start_pos.x, start_pos.y + state.tab_anim_y)
            local anim_rect_max = imgui.ImVec2(start_pos.x + sidebar_width - 20, start_pos.y + state.tab_anim_y + btn_height)
            local active_col = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.50, 0.45, 1.00, 0.60))
            
            dl:AddRectFilled(anim_rect_min, anim_rect_max, active_col, 10.0)
            
            imgui.SetWindowFontScale(1.15)
            
            
            for i, tab in ipairs(tabs) do
                
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0,0,0,0))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(1, 1, 1, 0.05))
                imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(1, 1, 1, 0.1))
                
                local is_selected = (state.active_tab == tab.id)
                local text_color = is_selected and imgui.ImVec4(1, 1, 1, 1) or imgui.ImVec4(0.60, 0.60, 0.65, 0.80)
                
                imgui.PushStyleColor(imgui.Col.Text, text_color)

                if imgui.Button(u8(tab.label), imgui.ImVec2(-1, btn_height)) then
                    if state.active_tab ~= tab.id then
                        state.prev_tab = state.active_tab
                        state.active_tab = tab.id
                        state.tab_offset_y = 20.0
                    end
                end
                
                imgui.PopStyleColor(4)
                
                
                
                
            end
            
            imgui.SetWindowFontScale(1.0)
            
            
            imgui.SetCursorPosY(imgui.GetWindowHeight() - 60)
            imgui.Separator()
            imgui.Spacing()
            if imgui.Button(u8'Закрыть', imgui.ImVec2(-1, 35)) then
                state.windows.main[0] = false
            end

        end
        imgui.EndChild()
        imgui.PopStyleColor(2) 
        imgui.PopStyleVar(3)   

        imgui.SameLine()
        
        
        if state.prev_tab ~= state.active_tab then
            state.tab_offset_y = 30.0
            state.prev_tab = state.active_tab
        end
        
        state.tab_offset_y = bringFloatTo(state.tab_offset_y, 0.0, 0.2)
        local tab_alpha = 1.0 - math.abs(state.tab_offset_y) / 30.0
        tab_alpha = math.max(0.0, math.min(1.0, tab_alpha))
        
        
        imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.08, 0.08, 0.10, 0.98))
        imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.50, 0.45, 1.00, 0.50))
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 10.0)
        imgui.PushStyleVarFloat(imgui.StyleVar.ChildBorderSize, 1.0)
        imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(20, 20))
        imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, tab_alpha)
        
        if imgui.BeginChild('##content', imgui.ImVec2(0, 0), true) then
            imgui.SetCursorPosY(imgui.GetCursorPosY() + state.tab_offset_y)
            
            if state.active_tab == 6 then renderNewsTab() end
            if state.active_tab == 1 then renderRulesTab() end
            if state.active_tab == 2 then renderRadialMenuTab() end
            if state.active_tab == 3 then renderSettingsTab() end
            if state.active_tab == 4 then renderAutoInsertTab() end
            if state.active_tab == 5 then renderInteractionTab() end
            
            imgui.SmoothScroll('##content_scroll', 120)
        end
        imgui.EndChild()
        
        imgui.PopStyleVar(4)
        imgui.PopStyleColor(2)

    end
    imgui.End()
    
    imgui.PopStyleVar(1)   
    imgui.PopStyleColor(2) 
    
    if state.fonts.main then imgui.PopFont() end
end


local function renderRadialMenu()
    if not radialMenu.globalEnabled then return end

    
    
    local target_anim = (radialMenu.active or radialMenu.isHeld or radialMenu.pendingActivation) and 1.0 or 0.0
    
    
    radialMenu.anim = bringFloatTo(radialMenu.anim or 0.0, target_anim, 0.25) 

    
    if radialMenu.anim < 0.01 then return end

    
    local fontApplied = false
    if state.fonts.radial then
        imgui.PushFont(state.fonts.radial)
        fontApplied = true
    end

    
    if radialMenu.pendingActivation then
        imgui.OpenPopup('##radial_menu')
        local io = imgui.GetIO()
        radialMenu.center = imgui.ImVec2(io.DisplaySize.x * 0.5, io.DisplaySize.y * 0.5)
        radialMenu.active = true
        radialMenu.pendingActivation = false
        radialMenu.selected = nil
    end

    
    local io = imgui.GetIO()
    if not radialMenu.isHeld then
        radialMenu.center = imgui.ImVec2(io.DisplaySize.x * 0.5, io.DisplaySize.y * 0.5)
    end
    
    local center = radialMenu.center
    local draw_list = imgui.GetForegroundDrawList()

    
    local enabled_buttons = {}
    for i, btn in ipairs(radialMenu.buttons) do
        if btn.enabled then
            table.insert(enabled_buttons, {index = i, name = btn.name})
        end
    end

    local segments = #enabled_buttons
    if segments == 0 then return end

    
    local anim_scale = radialMenu.anim 
    
    
    local radius_outer = radialMenu.radius * anim_scale 
    local radius_inner = (radialMenu.radius * 0.45) * anim_scale 
    local thickness = radius_outer - radius_inner

    
    
    if radialMenu.anim > 0.1 then
        
        
        draw_list:AddCircleFilled(center, radius_outer + 20, imgui.GetColorU32Vec4(imgui.ImVec4(0, 0, 0, 0.4 * anim_scale)), 128)
    end

    
    local step = (2 * math.pi) / segments
    local startAngle = -math.pi / 2 - (step * 0.5) 
    
    
    local diffX = io.MousePos.x - center.x
    local diffY = io.MousePos.y - center.y
    local distance = math.sqrt(diffX * diffX + diffY * diffY)
    
    local selectedIndex = nil
    
    
    if distance >= radius_inner then
        local angle = math.atan2(diffY, diffX)
        if angle < 0 then angle = angle + (2 * math.pi) end
        
        local normalized = angle - startAngle
        while normalized < 0 do normalized = normalized + (2 * math.pi) end
        while normalized >= (2 * math.pi) do normalized = normalized - (2 * math.pi) end
        
        selectedIndex = math.floor(normalized / step) + 1
        if selectedIndex > segments then selectedIndex = segments end
    end
    
    radialMenu.selected = selectedIndex

    
    
    
    local arc_segments = math.max(32, 128 / segments) 

    for i = 1, segments do
        local angle_s = startAngle + (i - 1) * step
        local angle_e = angle_s + step
        
        
        local is_hovered = (selectedIndex == i)
        local col_bg, col_border
        local current_radius_outer = radius_outer
        
        if is_hovered then
            
            col_bg = imgui.GetColorU32Vec4(imgui.ImVec4(0.50, 0.45, 1.00, 0.85 * anim_scale))
            
            current_radius_outer = (radialMenu.radius + 10) * anim_scale
        else
            
            col_bg = imgui.GetColorU32Vec4(imgui.ImVec4(0.12, 0.12, 0.15, 0.85 * anim_scale))
            current_radius_outer = radius_outer
        end

        
        draw_list:PathClear()
        
        draw_list:PathArcTo(center, current_radius_outer, angle_s, angle_e, arc_segments)
        
        draw_list:PathArcTo(center, radius_inner, angle_e, angle_s, arc_segments)
        draw_list:PathFillConvex(col_bg)

        
        local line_col = imgui.GetColorU32Vec4(imgui.ImVec4(0, 0, 0, 0.5 * anim_scale))
        draw_list:AddLine(
            imgui.ImVec2(center.x + math.cos(angle_s) * radius_inner, center.y + math.sin(angle_s) * radius_inner),
            imgui.ImVec2(center.x + math.cos(angle_s) * current_radius_outer, center.y + math.sin(angle_s) * current_radius_outer),
            line_col, 2.0
        )

        
        local mid_angle = angle_s + (step / 2)
        
        local text_radius = (radius_inner + current_radius_outer) / 2
        local text_pos = imgui.ImVec2(
            center.x + math.cos(mid_angle) * text_radius,
            center.y + math.sin(mid_angle) * text_radius
        )

        local label = enabled_buttons[i].name
        local text_size = imgui.CalcTextSize(u8(label))
        
        
        text_pos.x = text_pos.x - text_size.x / 2
        text_pos.y = text_pos.y - text_size.y / 2

        
        local text_col = is_hovered and 0xFFFFFFFF or imgui.GetColorU32Vec4(imgui.ImVec4(0.8, 0.8, 0.8, 0.9 * anim_scale))
        
        draw_list:AddText(text_pos, text_col, u8(label))
    end

    
    
    if not selectedIndex then
        local center_col = imgui.GetColorU32Vec4(imgui.ImVec4(1, 0.3, 0.3, 0.5 * anim_scale))
        draw_list:AddCircleFilled(center, 5 * anim_scale, center_col)
    end

    
    if not radialMenu.isHeld then
        if radialMenu.active and radialMenu.selected then
            radialMenu.action = enabled_buttons[radialMenu.selected].index
            
            addOneOffSound(0, 0, 0, 1134)
        end
        radialMenu.active = false
        radialMenu.pendingActivation = false
        radialMenu.releasePending = false
        radialMenu.selected = nil
    end

    if radialMenu.action then
        executeRadialAction(radialMenu.action)
        radialMenu.action = nil
        radialMenu.releasePending = false
    end

    if fontApplied then imgui.PopFont() end
end


local function shouldProcessImGui()
    return state.windows.main[0] 
        or state.windows.info[0] 
        or state.windows.interaction_editor[0]
        or state.windows.radial_editor[0]
        or state.overlay.visible
        or radialMenu.active 
        or radialMenu.pendingActivation 
        or radialMenu.releasePending 
        or radialMenu.isHeld
end


local function renderPlayerMenu()
    if state.fonts.main then imgui.PushFont(state.fonts.main) end

    local sw, sh = getScreenResolution()
    imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(250, 300), imgui.Cond.Always)

    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 10.0)
    imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.08, 0.08, 0.12, 0.98))
    imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.50, 0.45, 1.00, 0.50))

    if imgui.Begin(u8'Взаимодействие с игроком##player_menu', state.windows.player_menu, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize) then
        if state.interaction.target_ped and doesCharExist(state.interaction.target_ped) then
            local result, id = sampGetPlayerIdByCharHandle(state.interaction.target_ped)
            if result then
                imgui.TextColored(imgui.ImVec4(0.50, 0.45, 1.00, 1.00), u8("Игрок ID: " .. id))

                local player_name = sampGetPlayerNickname(id)
                if player_name then
                    imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.75, 1.00), u8("Имя: " .. player_name))
                end

                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()

                
                local interactionQMs = cache.interactionQMs or loadInteractionQMs()

                
                for i, item in ipairs(interactionQMs) do
                    if item.enabled then
                        if imgui.Button(u8(item.title), imgui.ImVec2(-1, 35)) then
                            
                            local player_name = sampGetPlayerNickname(id) or "Игрок"

                            
                            local content = item.content
                            content = content:gsub("{player}", player_name)
                            content = content:gsub("{id}", tostring(id))
                            content = content:gsub("{search_result}", "Ничего не найдено") 

                            
                            local commands = parseRoleplayCommands(content)
                            if #commands > 0 then
                                executeRoleplay(commands)
                            end

                            state.windows.player_menu[0] = false
                        end
                    end
                end

                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()

                if imgui.Button(u8'Закрыть (ESC)', imgui.ImVec2(-1, 30)) then
                    state.windows.player_menu[0] = false
                end
            else
                imgui.TextColored(imgui.ImVec4(1.0, 0.5, 0.5, 1.0), u8'Не удалось определить ID игрока')
            end
        else
            imgui.TextColored(imgui.ImVec4(1.0, 0.5, 0.5, 1.0), u8'Цель не найдена')
        end
    end
    imgui.End()
    imgui.PopStyleColor(2)
    imgui.PopStyleVar(1)
    if state.fonts.main then imgui.PopFont() end
end


local function MainRender()
    
    local windows_need_cursor = state.windows.main[0] 
        or state.windows.info[0] 
        or state.windows.player_menu[0] 
        or state.windows.interaction_editor[0]
        or state.windows.radial_editor[0]
        or (orule.config.autoInsertEnabled and sampIsChatInputActive() and state.autoinsert.menu_active)

    imgui.ShowCursor = windows_need_cursor
    
    if state.windows.main[0] then
        state.window_alpha = bringFloatTo(state.window_alpha, 1.0, 0.12)
    else
        state.window_alpha = bringFloatTo(state.window_alpha, 0.0, 0.12)
    end
    
    if state.window_alpha > 0.01 then
        imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, state.window_alpha)
        renderWindow()
        imgui.PopStyleVar(1)
    end
    if state.windows.info[0] then renderInfoWindow() end
    if state.windows.interaction_editor[0] then renderInteractionEditor() end
    if state.windows.radial_editor[0] then renderRadialEditor() end
    
    
    if radialMenu.globalEnabled then
        renderRadialMenu()
    end

    
    if orule.config.autoInsertEnabled and sampIsChatInputActive() then
        renderAutoInsertButton()
    end
    
    
    if state.windows.player_menu[0] then
        renderPlayerMenu()
    end

    
end


jit.off(MainRender, true)


imgui.OnFrame(
    function() 
        return shouldProcessImGui() 
            or state.windows.player_menu[0] 
            or (orule.config.autoInsertEnabled and sampIsChatInputActive()) 
    end, 
    MainRender
)

function onWindowMessage(msg, wparam, lparam)
    if (msg == wm.WM_KEYDOWN or msg == wm.WM_SYSKEYDOWN) then
        if state.overlay.visible and wparam == 27 then
            consumeWindowMessage(true, true)
            state.overlay.visible = false
            return
        end
        if state.windows.info[0] and not isPauseMenuActive() and wparam == 27 then
            consumeWindowMessage(true, false)
            state.windows.info[0] = false
            info_window_shown_once = true
            orule.config.firstLaunch = false
            saveConfig()
            state.windows.main[0] = true
            imgui.Process = true
            return
        end
        if state.windows.main[0] and not isPauseMenuActive() and wparam == 27 then
            if key_capture_mode then return end
            consumeWindowMessage(true, false)
            state.windows.main[0] = false
            imgui.Process = false
            return
        end
        
        
        if interaction_key_capture_mode == "waiting" and interaction_key_capture_index > 0 then
            is_capturing_keys = true
            local code = wparam
            if code == 27 or code == 0x08 then
                
                interaction_key_capture_mode = nil
                interaction_key_capture_index = -1
                sampAddChatMessage('[ORULE] Захват клавиши отменен', 0xFF0000)
                consumeWindowMessage(true, true)
            elseif code ~= 0x10 and code ~= 0x11 and code ~= 0x12 then
                
                local shortcut_keys = {}

                if isKeyDown(0xA2) or isKeyDown(0xA3) or isKeyDown(0x11) then table.insert(shortcut_keys, 0xA2) end
                if isKeyDown(0xA4) or isKeyDown(0xA5) or isKeyDown(0x12) then table.insert(shortcut_keys, 0xA4) end
                if isKeyDown(0xA0) or isKeyDown(0xA1) or isKeyDown(0x10) then table.insert(shortcut_keys, 0xA0) end

                table.insert(shortcut_keys, code)

                if #shortcut_keys >= 1 and #shortcut_keys <= 3 then
                    
                    cache.interactionKeys[interaction_key_capture_index].key = shortcut_keys
                    saveInteractionKeyBinds(cache.interactionKeys)

                    local key_names = {}
                    for _, key_code in ipairs(shortcut_keys) do
                        table.insert(key_names, getKeyName(key_code))
                    end
                    local key_text = table.concat(key_names, " + ")

                    sampAddChatMessage('[ORULE] Клавиша назначена: ' .. key_text, 0x00FF00)

                    interaction_key_capture_mode = nil
                    interaction_key_capture_index = -1
                    consumeWindowMessage(true, true)
                elseif #shortcut_keys > 3 then
                    sampAddChatMessage('[ORULE] Слишком много клавиш в комбинации (макс. 3)', 0xFF0000)
                    interaction_key_capture_mode = nil
                    interaction_key_capture_index = -1
                    consumeWindowMessage(true, true)
                end
            end
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
                local shortcut_keys = {}

                if isKeyDown(0xA2) or isKeyDown(0xA3) or isKeyDown(0x11) then table.insert(shortcut_keys, 0xA2) end
                if isKeyDown(0xA4) or isKeyDown(0xA5) or isKeyDown(0x12) then table.insert(shortcut_keys, 0xA4) end
                if isKeyDown(0xA0) or isKeyDown(0xA1) or isKeyDown(0x10) then table.insert(shortcut_keys, 0xA0) end

                table.insert(shortcut_keys, code)

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
                        if key_capture_type == "rule" and key_capture_mode and key_capture_mode.index then
                            local rule = orule.rulesDB[key_capture_mode.index]
                            if rule then
                                rule.key = shortcut_keys
                                rule.keyName = getShortcutName(shortcut_keys)
                                
                            end
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
                if key_capture_type == "rule" and key_capture_mode and key_capture_mode.index then
                    local rule = orule.rulesDB[key_capture_mode.index]
                    if rule then
                        rule.key = code
                        rule.keyName = getKeyName(code)
                    end
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

            if sampIsChatInputActive() or sampIsDialogActive() or isSampfuncsConsoleActive() or isPauseMenuActive() then
                return
            end
            
            radialMenu.pendingActivation = true
            radialMenu.releasePending = false
            radialMenu.isHeld = true
            imgui.Process = true
        elseif msg == wm.WM_MBUTTONUP then
            if radialMenu.active then
                radialMenu.releasePending = true
            end
            radialMenu.isHeld = false
            if not shouldProcessImGui() then
                imgui.Process = false
            end
        end
    end
end

local function cmd_help()
    sampAddChatMessage("======================", 0x45AFFF)
    sampAddChatMessage("Orule - Менеджер правил v1.6", 0x45AFFF)
    sampAddChatMessage("/" .. orule.config.command .. " - открыть меню", 0xFFFFFF)
    sampAddChatMessage("Средняя кнопка мыши (удержание) - радиальное меню", 0xFFFFFF)
    sampAddChatMessage("Автор: Lev Exelent", 0xFFFFFF)
    sampAddChatMessage("======================", 0x45AFFF)
end

local function preloadMenuData()
    if not cache.userQMs then
        loadUserQMs()
    end
    if not cache.interactionQMs then
        loadInteractionQMs()
    end
    if not cache.interactionKeys or #cache.interactionKeys == 0 then
        cache.interactionKeys = loadInteractionKeyBinds()
    end
end

local function toggle()
    if orule.config.firstLaunch and not info_window_shown_once then
        state.windows.info[0] = true
        imgui.Process = true
    elseif (orule.config.lastChangelogVersion or "0") ~= CONSTANTS.CHANGELOG_VER then
        state.active_tab = 6
        state.tab_anim_y = 0
        state.windows.main[0] = true
        imgui.Process = true
    else
        if not state.windows.main[0] then
            
            lua_thread.create(function()
                preloadMenuData()
            end)
        end
        state.windows.main[0] = not state.windows.main[0]
        imgui.Process = state.windows.main[0]
    end
end


local function downloadResource(url, path, resource_type, callback)
    local dir = path:match('(.+)\\[^\\]+$')
    if dir and not doesDirectoryExist(dir) then
        createDirectory(dir)
    end

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

local function checkAndDownloadResources()
    local base_url = "https://raw.githubusercontent.com/levushkaexelent/orule/main/resources/"
    local base_path = getWorkingDirectory() .. "\\OverlayRules\\"

    local downloaded_count = 0
    local processed_count = 0
    local images_downloaded = false

    local resources = {
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

        {url = base_url .. "fonts/EagleSans-Regular.ttf", path = base_path .. "fonts\\EagleSans-Regular.ttf", type = "font"},
    }

    local total = #resources
    sampAddChatMessage('[ORULE] Проверка ресурсов... (' .. total .. ' файлов)', 0xFFFFFF)

    for i, res in ipairs(resources) do
        downloadResource(res.url, res.path, res.type, function(was_downloaded)
            processed_count = processed_count + 1
            if was_downloaded then
                downloaded_count = downloaded_count + 1
                if res.type == "image" then
                    images_downloaded = true
                end
            end

            if processed_count % 10 == 0 or processed_count == total then
                sampAddChatMessage('[ORULE] Проверено: ' .. processed_count .. '/' .. total, 0xFFFFFF)
            end

            if processed_count == total then
                if downloaded_count > 0 then
                    sampAddChatMessage('[ORULE] Загружено новых ресурсов: ' .. downloaded_count, 0x00FF00)
                    if images_downloaded and orule.config.showImages then
                        reloadTextures()
                    end
                else
                    sampAddChatMessage('[ORULE] Все ресурсы актуальны', 0x00FF00)
                end
            end
        end)

        wait(100)
    end
end

function safeMain()
    if not isSampLoaded() then 
        print('[ORULE] Ошибка: SA-MP не загружен')
        return 
    end
    while not isSampAvailable() do wait(100) end

    sampToggleCursor(false) 

    
    
    
    updater:check()


    sampAddChatMessage("[ORULE] Загрузка...", 0x45AFFF)

    loadAllRules()
    preloadMenuData()

    if orule.config.command and #orule.config.command > 0 then
        sampRegisterChatCommand(orule.config.command, toggle)
        sampRegisterChatCommand(orule.config.command .. "_help", cmd_help)
        sampAddChatMessage("[ORULE] Готов! Используйте /" .. orule.config.command, 0x00FF00)
    else
        sampAddChatMessage("[ORULE] Готов!", 0x00FF00)
    end

    
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
        state.preload_complete = true
    end)

    
    lua_thread.create(function()
        wait(2000)
        checkAndDownloadResources()
    end)

    local held_rule_active = false
    
    
    local last_interaction_time = 0 
    local last_radial_menu_time = 0 
    local COOLDOWN_DELAY = 0.5 
    local RADIAL_COOLDOWN = 0.3 
    
    
    while true do
        wait(0) 
        processConfigSave()
        
        local current_time = os.clock() 

        
        if orule.config.interactionEnabled then
            
             if orule.config.interactionMode == 1 then
                
                
                local result, ped = getCharPlayerIsTargeting(PLAYER_HANDLE)

                
                if result and doesCharExist(ped) and isKeyDown(vkeys.VK_LMENU) and isKeyJustPressed(vkeys.VK_RBUTTON) then
                    
                    if current_time - last_radial_menu_time > RADIAL_COOLDOWN then
                        
                        state.interaction.target_ped = ped
                        state.windows.player_menu[0] = true
                        imgui.Process = true
                        last_radial_menu_time = current_time 
                    end
                end

                
                if state.windows.player_menu[0] and isKeyJustPressed(vkeys.VK_ESCAPE) then
                    state.windows.player_menu[0] = false
                    imgui.Process = shouldProcessImGui()
                end
            elseif orule.config.interactionMode == 0 then
                
                
                local result, ped = getCharPlayerIsTargeting(PLAYER_HANDLE)

                if result and doesCharExist(ped) then
                    
                    local player_name = sampGetPlayerNickname(sampGetPlayerIdByCharHandle(ped)) or "Игрок"
                    local player_id = sampGetPlayerIdByCharHandle(ped)

                    
                    if cache.interactionKeys then
                        for _, bind in ipairs(cache.interactionKeys) do
                            if bind.key and #bind.key > 0 then
                                local all_pressed = true
                                for _, key_code in ipairs(bind.key) do
                                    if not isKeyDown(key_code) then
                                        all_pressed = false
                                        break
                                    end
                                end

                                if all_pressed then
                                    
                                    if current_time - last_interaction_time > COOLDOWN_DELAY then
                                        
                                        local interactionQMs = cache.interactionQMs or loadInteractionQMs()
                                        for _, item in ipairs(interactionQMs) do
                                            if item.action == bind.action and item.enabled then
                                                
                                                local content = item.content
                                                content = content:gsub("{player}", player_name)
                                                content = content:gsub("{id}", tostring(player_id))
                                                content = content:gsub("{search_result}", "Ничего не найдено")

                                                
                                                local commands = parseRoleplayCommands(content)
                                                if #commands > 0 then
                                                    executeRoleplay(commands)
                                                end

                                                last_interaction_time = current_time 
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        local is_game_focused = not (sampIsChatInputActive() or sampIsDialogActive() or isSampfuncsConsoleActive() or isPauseMenuActive())
        
        if is_game_focused and not is_capturing_keys then
            
            if type(orule.config.globalHotkey) == "table" and #orule.config.globalHotkey > 0 then
                if isShortcutPressed(orule.config.globalHotkey) then
                    toggle()
                end
            elseif type(orule.config.globalHotkey) == "number" and orule.config.globalHotkey > 0 then
                if isKeyJustPressed(orule.config.globalHotkey) then
                    toggle()
                end
            end

            held_rule_active = false
            for i, rule in ipairs(orule.rulesDB) do
                
                if rule.key and type(rule.key) == "table" and #rule.key > 0 then
                    if rule.holdMode then
                        local all_pressed = true
                        for _, key in ipairs(rule.key) do
                            if not isKeyDown(key) then
                                all_pressed = false
                                break
                            end
                        end

                        if all_pressed then
                            if state.overlay.rule_index ~= i then
                                ffi.fill(state.overlay.search_buf, 257, 0) 
                            end
                            state.overlay.rule_index, state.overlay.visible = i, true
                            held_rule_active = true
                            break
                        end
                    else
                        if isShortcutPressed(rule.key) then
                            if state.overlay.visible and state.overlay.rule_index == i then
                                state.overlay.visible = false
                                state.first_render = false
                            else
                                state.overlay.rule_index, state.overlay.visible = i, true
                                ffi.fill(state.overlay.search_buf, 257, 0) 
                            end
                        end
                    end
                end
            end

            if not held_rule_active and state.overlay.visible then
                local rule = orule.rulesDB[state.overlay.rule_index]
                if rule and rule.holdMode then
                    state.overlay.visible = false
                end
            end

            if radialMenu.action then
                executeRadialAction(radialMenu.action)
                radialMenu.action = nil
            end
        end
    end
end


function onScriptTerminate(script, quitGame)
   if script == thisScript() then
      
      if state.textures.radar then
         imgui.ReleaseTexture(state.textures.radar)
         state.textures.radar = nil
      end
      
      for i, tex in pairs(state.textures.territory) do
         if tex then
            imgui.ReleaseTexture(tex)
            state.textures.territory[i] = nil
         end
      end
      
      
      saveConfig()
   end
end

function main()
    local ok, err = pcall(safeMain)
    if not ok then logError('CRASH: ' .. tostring(err)) end
end