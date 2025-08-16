
local component = require("component")
local event = require("event")
local internet = require("internet")
local os = require("os")
local json = require("json")  -- Requires the installed json.lua library

-- Configuration
local token = "tokenID"  -- Replace with your Telegram bot token
local chat_id = "-1001993395217"  -- Replace with your Telegram chat ID (string or number)
local bot_username = "GTchat"  -- Optional: Replace to filter bot's own messages
local base_url = "https://api.telegram.org/bot" .. token .. "/"
local chat_box = component.chat_box

-- Set Chat Box properties (optional)
chat_box.setName("MC-Telegram Sync")
chat_box.setDistance(64)  -- Adjust range as needed

-- Function to urlencode strings
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

-- Function to send message to Telegram
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

-- Main loop
local last_offset = 0
print("Synchronization started. Press Ctrl+C to stop.")
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
