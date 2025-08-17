-- Импорт компонентов
local component = require("component")
local event = require("event")
local internet = require("internet")
local os = require("os")
local json = require("json")  -- Requires the installed json.lua library
local chat_box = component.chat_box

-- Конфигурационные переменные
local token = "TokenID" -- Заменить своим токеном бота Telegram
local chat_id = "-1001993395217" -- Указать ID чата с которым будет происходить синхронизация
local bot_username = "GTchat" -- Имя бота в Telegram чтобы исключить его из списка синхронизации.
chat_box.setName("MC-Telegram Sync") -- Имя от которого будут отправляться сообщения в чат Minecraft
chat_box.setDistance(64) -- Радиус действия чатбокса (В стандартной конфигурации мода используется[range: 4 ~ 32767, default: 40])
local base_url = "https://api.telegram.org/bot" .. token .. "/"

-- Function to urlencode strings (не понимаю что делает эта хуета)
local function urlencode(str)
    if (str) then
        str = str:gsub("\n", "\r\n")
        str = str:gsub("([^%w _%%%-%.~])", function(c)
            return string.format("%%%02X", string.byte(c))
        end)
        str = str:gsub(" ", "%%20")
    end
    return str
end

-- Функция отправки сообщений в Telegram
local function sendToTelegram(text)
    local url = base_url .. "sendMessage?chat_id=" .. chat_id .. "&text=" .. urlencode(text)
    local handle = internet.request(url)
    for _ in handle do end  -- Consume response to close handle
end

-- Function to get Telegram updates (short polling)
local function getTelegramUpdates(offset, timeout)
    local url = base_url .. "getUpdates?offset=" .. offset .. "&timeout=" .. (timeout or 0) .. "&limit=10"
    local handle = internet.request(url)
    local result = ""
    for chunk in handle do
        result = result .. chunk
    end
    local data = json.decode(result)
    if data.ok then
        return data.result
    else
        print("API error: " .. (data.description or "Unknown"))
        return {}
    end
end

-- Основной цикл
local last_offset = 0
print("Программа запущенна, cообщения синхронизируются. Нажимите Ctrl+Alt+C для остановки.")
while true do
    -- Pull events with timeout (handles MC chat messages)
    local e = {event.pull(1)}
    if e[1] == "chat_message" then
        local username = e[3]  -- Event: address, ?, username, message, uuid?
        local message = e[4]
        if username and message then
            sendToTelegram("[" .. username .. "] " .. message)
        end
    end

    -- Poll Telegram every second
    local updates = getTelegramUpdates(last_offset + 1, 0)
    for _, update in ipairs(updates) do
        if update.update_id > last_offset then
            last_offset = update.update_id
        end
        local msg = update.message
        if msg and msg.text and tostring(msg.chat.id) == tostring(chat_id) then
            local from = msg.from.username or msg.from.first_name
            if from ~= bot_username then  -- Avoid echoing bot's own messages
                chat_box.say("[" .. from .. "] " .. msg.text)
            end
        end
    end
end
