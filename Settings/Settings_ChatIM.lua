-- Settings/Settings_ChatIM.lua
local ADDON_NAME, ETBC = ...
local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceTBC")
local function GetDB()
  ETBC.db.profile.chatim = ETBC.db.profile.chatim or {}
  local db = ETBC.db.profile.chatim

  if db.enabled == nil then db.enabled = true end

  if db.timestamps == nil then db.timestamps = false end
  if db.timestampFormat == nil then db.timestampFormat = "%H:%M" end

  if db.urlLinks == nil then db.urlLinks = true end
  if db.emailLinks == nil then db.emailLinks = true end

  if db.shortenChannels == nil then db.shortenChannels = true end

  if db.whisperSound == nil then db.whisperSound = false end
  if db.whisperSoundIncoming == nil then db.whisperSoundIncoming = true end
  if db.whisperSoundOutgoing == nil then db.whisperSoundOutgoing = false end
  if db.whisperSoundThrottle == nil then db.whisperSoundThrottle = 1.5 end

  if db.copyLines == nil then db.copyLines = 200 end
  if db.copyButton == nil then db.copyButton = true end
  if db.copyButtonScale == nil then db.copyButtonScale = 1.0 end
  if db.copyButtonAlpha == nil then db.copyButtonAlpha = 0.95 end

  -- NEW: copy target
  -- "follow" => use current chat frame/tab
  -- number => chat frame id (1..NUM_CHAT_WINDOWS)
  if db.copyTarget == nil then db.copyTarget = "follow" end

  return db
end

ETBC.SettingsRegistry:RegisterGroup("chatim", {
  name = "ChatIM",
  order = 25,
  options = function()
    local db = GetDB()

    local tsValues = {
      ["%H:%M"] = "24h (HH:MM)",
      ["%H:%M:%S"] = "24h (HH:MM:SS)",
      ["%I:%M%p"] = "12h (HH:MMAM)",
      ["%I:%M:%S%p"] = "12h (HH:MM:SSAM)",
    }

    return {
      enabled = {
        type = "toggle",
        name = "Enable ChatIM",
        order = 1,
        get = function() return db.enabled end,
        set = function(_, v) db.enabled = v and true or false; ETBC.ApplyBus:Notify("chatim") end,
      },

      timestamps = {
        type = "group",
        name = "Timestamps",
        order = 10,
        inline = true,
        args = {
          enabled = {
            type = "toggle",
            name = "Show Timestamps",
            order = 1,
            get = function() return db.timestamps end,
            set = function(_, v) db.timestamps = v and true or false; ETBC.ApplyBus:Notify("chatim") end,
            disabled = function() return not db.enabled end,
          },
          format = {
            type = "select",
            name = "Format",
            order = 2,
            values = tsValues,
            get = function() return db.timestampFormat end,
            set = function(_, v) db.timestampFormat = v; ETBC.ApplyBus:Notify("chatim") end,
            disabled = function() return not (db.enabled and db.timestamps) end,
          },
        },
      },

      links = {
        type = "group",
        name = "Clickable Links",
        order = 20,
        inline = true,
        args = {
          urlLinks = {
            type = "toggle",
            name = "Make URLs Clickable",
            order = 1,
            get = function() return db.urlLinks end,
            set = function(_, v) db.urlLinks = v and true or false; ETBC.ApplyBus:Notify("chatim") end,
            disabled = function() return not db.enabled end,
          },
          emailLinks = {
            type = "toggle",
            name = "Make Emails Clickable",
            order = 2,
            get = function() return db.emailLinks end,
            set = function(_, v) db.emailLinks = v and true or false; ETBC.ApplyBus:Notify("chatim") end,
            disabled = function() return not (db.enabled and db.urlLinks) end,
          },
        },
      },

      channels = {
        type = "group",
        name = "Channel Formatting",
        order = 30,
        inline = true,
        args = {
          shortenChannels = {
            type = "toggle",
            name = "Shorten Channel Tags",
            order = 1,
            get = function() return db.shortenChannels end,
            set = function(_, v) db.shortenChannels = v and true or false; ETBC.ApplyBus:Notify("chatim") end,
            disabled = function() return not db.enabled end,
          },
        },
      },

      whisper = {
        type = "group",
        name = "Whisper Sounds",
        order = 40,
        inline = true,
        args = {
          whisperSound = {
            type = "toggle",
            name = "Enable Whisper Sound",
            order = 1,
            get = function() return db.whisperSound end,
            set = function(_, v) db.whisperSound = v and true or false; ETBC.ApplyBus:Notify("chatim") end,
            disabled = function() return not db.enabled end,
          },
          incoming = {
            type = "toggle",
            name = "Incoming Whispers",
            order = 2,
            get = function() return db.whisperSoundIncoming end,
            set = function(_, v) db.whisperSoundIncoming = v and true or false; ETBC.ApplyBus:Notify("chatim") end,
            disabled = function() return not (db.enabled and db.whisperSound) end,
          },
          outgoing = {
            type = "toggle",
            name = "Outgoing Whispers",
            order = 3,
            get = function() return db.whisperSoundOutgoing end,
            set = function(_, v) db.whisperSoundOutgoing = v and true or false; ETBC.ApplyBus:Notify("chatim") end,
            disabled = function() return not (db.enabled and db.whisperSound) end,
          },
          throttle = {
            type = "range",
            name = "Throttle (sec)",
            order = 4,
            min = 0, max = 10, step = 0.1,
            get = function() return db.whisperSoundThrottle end,
            set = function(_, v) db.whisperSoundThrottle = v; ETBC.ApplyBus:Notify("chatim") end,
            disabled = function() return not (db.enabled and db.whisperSound) end,
          },
        },
      },

      copy = {
        type = "group",
        name = "Copy Chat",
        order = 50,
        inline = true,
        args = {
          copyLines = {
            type = "range",
            name = "Lines to Copy",
            order = 1,
            min = 50, max = 2000, step = 10,
            get = function() return db.copyLines end,
            set = function(_, v) db.copyLines = v end,
            disabled = function() return not db.enabled end,
          },
          copyButton = {
            type = "toggle",
            name = "Show Copy Button Near Chat",
            order = 2,
            get = function() return db.copyButton end,
            set = function(_, v) db.copyButton = v and true or false; ETBC.ApplyBus:Notify("chatim") end,
            disabled = function() return not db.enabled end,
          },
          copyButtonScale = {
            type = "range",
            name = "Button Scale",
            order = 3,
            min = 0.75, max = 1.5, step = 0.05,
            get = function() return db.copyButtonScale end,
            set = function(_, v) db.copyButtonScale = v; ETBC.ApplyBus:Notify("chatim") end,
            disabled = function() return not (db.enabled and db.copyButton) end,
          },
          copyButtonAlpha = {
            type = "range",
            name = "Button Alpha",
            order = 4,
            min = 0.2, max = 1.0, step = 0.05,
            get = function() return db.copyButtonAlpha end,
            set = function(_, v) db.copyButtonAlpha = v; ETBC.ApplyBus:Notify("chatim") end,
            disabled = function() return not (db.enabled and db.copyButton) end,
          },
          copyTarget = {
            type = "select",
            name = "Copy Source",
            order = 5,
            values = function()
              local values = { follow = "Follow current tab" }
              local n = NUM_CHAT_WINDOWS or 10
              for i = 1, n do
                local title = GetChatWindowInfo and select(1, GetChatWindowInfo(i))
                if not title or title == "" then
                  title = "ChatFrame" .. i
                end
                values[tostring(i)] = title
              end
              return values
            end,
            get = function() return db.copyTarget end,
            set = function(_, v) db.copyTarget = v; ETBC.ApplyBus:Notify("chatim") end,
            disabled = function() return not db.enabled end,
          },
          hint = {
            type = "description",
            name = "Command: |cff33ff99/etbccopy|r",
            order = 6,
          },
        },
      },
    }
  end,
})
