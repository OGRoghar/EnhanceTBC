-- Core/Print.lua
local ADDON_NAME, ETBC = ...

function ETBC:Print(msg)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99EnhanceTBC|r: " .. tostring(msg))
  else
    print("EnhanceTBC: " .. tostring(msg))
  end
end

function ETBC:Debug(msg)
  if self.db and self.db.profile and self.db.profile.general and self.db.profile.general.debug then
    self:Print("|cffffcc00Debug|r: " .. tostring(msg))
  end
end
