-- Core/Print.lua
local _, ETBC = ...
function ETBC.Print(_, msg)
  local ok, str = pcall(tostring, msg)
  str = ok and str or "<?>"

  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99EnhanceTBC|r: " .. str)
  else
    print("EnhanceTBC: " .. str)
  end
end

function ETBC:Debug(msg)
  if self.db and self.db.profile and self.db.profile.general and self.db.profile.general.debug then
    local ok, str = pcall(tostring, msg)
    str = ok and str or "<?>"
    self:Print("|cffffcc00Debug|r: " .. str)
  end
end
