local _, ETBC = ...
if not ETBC then return end

ETBC.UI = ETBC.UI or {}
local ConfigWindow = ETBC.UI.ConfigWindow
local Model = ETBC.UI.ControlCenterModel
local History = ETBC.UI.ChangeHistory
if not (ConfigWindow and Model and History) then return end

local CC = { frame=nil, model=nil, route="home", nav={}, controls={}, overlays={} }
ETBC.UI.ControlCenter = CC

local T = {
  bg={0.018,0.024,0.030,0.99}, surface={0.035,0.044,0.052,0.99}, raised={0.052,0.064,0.073,1},
  hover={0.075,0.087,0.095,1}, border={0.16,0.18,0.18,0.9}, gold={0.88,0.68,0.27,1},
  green={0.24,0.76,0.39,1}, red={0.90,0.31,0.28,1}, text={0.94,0.93,0.88,1}, muted={0.62,0.65,0.66,1},
}
local BACKDROP={bgFile="Interface\\Buttons\\WHITE8x8",edgeFile="Interface\\Buttons\\WHITE8x8",edgeSize=1}

local function DB()
  local p=ETBC.db and ETBC.db.profile; if not p then return nil end
  p.ui=p.ui or {}; p.ui.config=p.ui.config or {}; local db=p.ui.config
  if tonumber(db.layoutVersion)~=2 then
    db.layoutVersion=2; db.route=db.lastModule or "home"; db.sidebarCollapsed=false; db.textScale=1
    db.reducedMotion=false; db.highContrast=false; db.scrollPositions=db.scrollPositions or {}; db.theme=nil
  end
  db.theme=nil; db.treeStatus=nil; db.treewidth=nil; db.previewCollapsed=nil
  db.moduleFavorites=db.moduleFavorites or {}; db.recentModules=db.recentModules or {}; db.sectionCollapsed=db.sectionCollapsed or {}
  return db
end

local function Color(frame,bg,border)
  if not frame or not frame.SetBackdrop then return end
  frame:SetBackdrop(BACKDROP); bg=bg or T.surface; border=border or T.border
  frame:SetBackdropColor(bg[1],bg[2],bg[3],bg[4] or 1); frame:SetBackdropBorderColor(border[1],border[2],border[3],border[4] or 1)
end
local function Font(parent,text,size,color)
  local fs=parent:CreateFontString(nil,"OVERLAY",size and "GameFontNormal" or "GameFontHighlightSmall")
  fs:SetText(text or ""); color=color or T.text; fs:SetTextColor(color[1],color[2],color[3],color[4] or 1)
  local db=DB(); if fs.GetFont and fs.SetFont then local path,old,flags=fs:GetFont(); if path then fs:SetFont(path,(size or old or 12)*(db and db.textScale or 1),flags) end end
  return fs
end
local function Clear(frame)
  if not frame then return end
  local children={frame:GetChildren()}; for i=1,#children do children[i]:Hide(); children[i]:SetParent(nil) end
  local regions={frame:GetRegions()}; for i=1,#regions do if regions[i].Hide then regions[i]:Hide() end end
end
local function Button(parent,text,width,height,onClick,quiet)
  local b=CreateFrame("Button",nil,parent,BackdropTemplateMixin and "BackdropTemplate" or nil); b:SetSize(width or 120,height or 30)
  Color(b,quiet and T.surface or T.raised,T.border); local label=Font(b,text,11,T.text); label:SetPoint("CENTER"); b.label=label
  b:SetScript("OnEnter",function(self) Color(self,T.hover,T.gold) end); b:SetScript("OnLeave",function(self) Color(self,quiet and T.surface or T.raised,T.border) end)
  b:SetScript("OnClick",function() if onClick then onClick() end end); return b
end
local function SetEnabled(frame,enabled)
  frame._disabled=not enabled; frame:SetAlpha(enabled and 1 or .48); if frame.EnableMouse then frame:EnableMouse(enabled) end
end
local function Info(control)
  local info={control.pageKey}; for i=1,#control.path do info[#info+1]=control.path[i] end
  return info
end
local function Eval(value,control,fallback)
  if type(value)~="function" then if value==nil then return fallback end return value end
  local ok,result=pcall(value,Info(control)); if not ok then ok,result=pcall(value,control.option) end
  return ok and result or fallback
end
local function Get(control)
  local fn=control.option.get; if type(fn)~="function" then return nil end
  local ok,a,b,c,d=pcall(fn,Info(control)); if not ok then ok,a,b,c,d=pcall(fn,control.option) end
  if ok then return a,b,c,d end; return nil
end
local function RememberModule(key)
  local db=DB(); if not db then return end
  for i=#db.recentModules,1,-1 do if db.recentModules[i]==key then table.remove(db.recentModules,i) end end
  table.insert(db.recentModules,1,key); while #db.recentModules>8 do table.remove(db.recentModules) end
end

function CC:Toast(message,canUndo,errorState)
  local f=self.toast; if not f then return end
  f.text:SetText(message or "Updated"); f.undo:SetShown(canUndo and true or false)
  Color(f,errorState and {0.16,0.045,0.04,1} or T.raised,errorState and T.red or T.gold); f:Show()
  if self.toastTimer and self.toastTimer.Cancel then self.toastTimer:Cancel() end
  if ETBC.StartTimer then self.toastTimer=ETBC:StartTimer(4,function() if f then f:Hide() end end) end
end

local function Set(control,...)
  local fn=control.option.set; if type(fn)~="function" then return false,"setting is read-only" end
  local old={Get(control)}; local values={...}; local ok,err=pcall(fn,Info(control),unpack(values))
  if not ok then ok,err=pcall(fn,control.option,unpack(values)) end
  if not ok then CC:Toast("Could not update "..control.name..": "..tostring(err),false,true); return false,err end
  RememberModule(control.pageKey)
  History:Record(control.key,control.name,old,values,function(previous)
    local args=previous or old; local success=pcall(fn,Info(control),unpack(args)); if not success then pcall(fn,control.option,unpack(args)) end
    CC:RenderRoute(CC.route)
  end)
  CC:Toast(control.name.." updated",true,false); return true
end
local function Hidden(c) return Eval(c.option.hidden,c,false) and true or false end
local function Disabled(c) return Eval(c.option.disabled,c,false) and true or false end
local function Values(c) local v=Eval(c.option.values,c,{}); return type(v)=="table" and v or {} end

local function AddDescription(parent,text,top)
  if not text or text=="" then return top end
  local d=Font(parent,text,10,T.muted); d:SetPoint("TOPLEFT",parent,"TOPLEFT",18,-top); d:SetPoint("TOPRIGHT",parent,"TOPRIGHT",-18,-top); d:SetJustifyH("LEFT"); d:SetJustifyV("TOP"); d:SetWordWrap(true)
  return top+28
end

local function RenderControl(parent,c,top)
  if Hidden(c) then return top end
  if c.id == "enabled" and c.type == "toggle" then return top end
  local row=CreateFrame("Frame",nil,parent,BackdropTemplateMixin and "BackdropTemplate" or nil); row:SetPoint("TOPLEFT",parent,"TOPLEFT",12,-top); row:SetPoint("TOPRIGHT",parent,"TOPRIGHT",-12,-top)
  CC.controlOffsets[c.key]=(parent._pageOffset or 0)+top
  local desc=c.description~="" and c.description or nil; row:SetHeight(desc and 58 or 42); Color(row,T.surface,{T.border[1],T.border[2],T.border[3],.45})
  local name=Font(row,c.name,11,T.text); name:SetPoint("TOPLEFT",row,"TOPLEFT",12,-9); name:SetPoint("RIGHT",row,"RIGHT",-210,0); name:SetJustifyH("LEFT")
  if desc then local d=Font(row,desc,9,T.muted); d:SetPoint("TOPLEFT",name,"BOTTOMLEFT",0,-4); d:SetPoint("RIGHT",row,"RIGHT",-210,0); d:SetJustifyH("LEFT"); d:SetWordWrap(false) end
  local disabled=Disabled(c); local control
  if c.type=="toggle" then
    control=Button(row,Get(c) and "ON" or "OFF",82,26,function() Set(c,not (Get(c) and true or false)); CC:RenderRoute(CC.route) end,true)
    if Get(c) then Color(control,{0.035,0.14,0.075,1},T.green); control.label:SetTextColor(T.green[1],T.green[2],T.green[3],1) end
  elseif c.type=="range" then
    local min,max,step=tonumber(c.option.min) or 0,tonumber(c.option.max) or 100,tonumber(c.option.step) or 1
    control=CreateFrame("Slider",nil,row,BackdropTemplateMixin and "BackdropTemplate" or nil); control:SetSize(150,12); control:SetOrientation("HORIZONTAL"); Color(control,T.bg,T.border); control:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal"); control:SetMinMaxValues(min,max); control:SetValueStep(step); control:SetObeyStepOnDrag(true); control:SetValue(tonumber(Get(c)) or min)
    local valueText=Font(row,tostring(Get(c) or min),9,T.muted); valueText:SetPoint("BOTTOM",control,"TOP",0,3); control.valueText=valueText
    control:SetScript("OnValueChanged",function(self,v,user) if self.valueText then self.valueText:SetText(tostring(math.floor(v/step+.5)*step)) end if user then Set(c,v) end end)
  elseif c.type=="select" then
    local values,current=Values(c),Get(c); local keys={}; for key in pairs(values) do keys[#keys+1]=key end; table.sort(keys,function(a,b)return tostring(values[a])<tostring(values[b])end)
    control=Button(row,tostring(values[current] or current or "Select"),170,26,function()
      local idx=1; for i=1,#keys do if keys[i]==current then idx=i+1 end end; if idx>#keys then idx=1 end
      if keys[idx]~=nil then Set(c,keys[idx]); CC:RenderRoute(CC.route) end
    end,true)
  elseif c.type=="input" then
    control=CreateFrame("EditBox",nil,row,"InputBoxTemplate"); control:SetSize(170,26); control:SetAutoFocus(false); control:SetText(tostring(Get(c) or "")); control:SetTextInsets(7,7,0,0); Color(control,T.bg,T.border)
    control:SetScript("OnEnterPressed",function(self) Set(c,self:GetText()); self:ClearFocus() end); control:SetScript("OnEscapePressed",function(self) self:SetText(tostring(Get(c) or "")); self:ClearFocus() end)
  elseif c.type=="execute" then
    control=Button(row,"Run",90,26,function()
      local function Run() local ok,err=pcall(c.option.func,Info(c)); if not ok then ok,err=pcall(c.option.func,c.option) end; if ok then CC:Toast(c.name.." completed",false) else CC:Toast(tostring(err),false,true) end end
      if c.option.confirm then StaticPopup_Show("ETBC_EXEC_CONFIRM",tostring(Eval(c.option.confirmText,c,"Are you sure?")),nil,{exec=Run}) else Run() end
    end,false)
  elseif c.type=="color" then
    control=Button(row,"Choose color",120,26,function()
      local r,g,b,a=Get(c); if not ColorPickerFrame then return end
      ColorPickerFrame.func=function() local nr,ng,nb=ColorPickerFrame:GetColorRGB(); Set(c,nr,ng,nb,a) end
      ColorPickerFrame.opacityFunc=function() local nr,ng,nb=ColorPickerFrame:GetColorRGB(); Set(c,nr,ng,nb,1-(OpacitySliderFrame:GetValue() or 0)) end
      ColorPickerFrame:SetColorRGB(r or 1,g or 1,b or 1); ColorPickerFrame.hasOpacity=c.option.hasAlpha and true or false; ColorPickerFrame.opacity=1-(a or 1); ColorPickerFrame:Show()
    end,true)
  else
    control=Button(row,"Compatibility",120,26,function() CC:Toast("This setting uses the compatibility renderer.",false,true) end,true)
  end
  if control then control:SetPoint("RIGHT",row,"RIGHT",-12,0); SetEnabled(control,not disabled) end
  return top+row:GetHeight()+7
end

local function Card(parent,top,title,description)
  local f=CreateFrame("Frame",nil,parent,BackdropTemplateMixin and "BackdropTemplate" or nil); f:SetPoint("TOPLEFT",parent,"TOPLEFT",10,-top); f:SetPoint("TOPRIGHT",parent,"TOPRIGHT",-10,-top); Color(f,T.raised,T.border)
  local h=Font(f,title,13,T.text); h:SetPoint("TOPLEFT",f,"TOPLEFT",16,-14); h:SetJustifyH("LEFT")
  local used=42; if description and description~="" then local d=Font(f,description,10,T.muted); d:SetPoint("TOPLEFT",h,"BOTTOMLEFT",0,-6); d:SetPoint("RIGHT",f,"RIGHT",-16,0); d:SetJustifyH("LEFT"); used=66 end
  return f,used
end

function CC:RenderDashboard()
  local canvas=self.canvas; Clear(canvas); local top=12
  local title=Font(canvas,"Control Center",22,T.text); title:SetPoint("TOPLEFT",canvas,"TOPLEFT",16,-top); top=top+34
  local sub=Font(canvas,"Your interface at a glance",11,T.muted); sub:SetPoint("TOPLEFT",canvas,"TOPLEFT",17,-top); top=top+38
  local diag=ETBC.GetDiagnostics and ETBC:GetDiagnostics() or {}; local card,used=Card(canvas,top,"System status","EnhanceTBC is ready and settings apply live."); card:SetHeight(116)
  local status=Font(card,diag.masterEnabled and "●  Addon enabled" or "●  Addon disabled",11,diag.masterEnabled and T.green or T.red); status:SetPoint("TOPLEFT",card,"TOPLEFT",16,-used)
  local modules=Font(card,("%s of %s modules enabled"):format(tostring(diag.enabledModules or 0),tostring(diag.knownModules or 0)),10,T.muted); modules:SetPoint("TOPLEFT",status,"BOTTOMLEFT",0,-8)
  local profile=ETBC.db and ETBC.db.GetCurrentProfile and ETBC.db:GetCurrentProfile() or "Default"; local pf=Font(card,"Profile: "..tostring(profile),10,T.muted); pf:SetPoint("LEFT",card,"LEFT",250,-used+8)
  top=top+128
  local perf=diag.performance; local health=Card(canvas,top,"Performance health","Live profiler capability and warning status."); health:SetHeight(90)
  local perfText=Font(health,perf and perf.available and (perf.warning and "Performance warning active" or "Profiler available") or "Profiler unavailable",10,perf and perf.warning and T.red or T.muted); perfText:SetPoint("BOTTOMLEFT",health,"BOTTOMLEFT",16,18)
  top=top+102
  local actions=Card(canvas,top,"Quick actions","Common tools without hunting through module pages."); actions:SetHeight(98)
  local edit=Button(actions,"Edit layout",112,30,function() ConfigWindow:Close(); if ETBC.Mover then ETBC.Mover:SetMoveMode(true) end end); edit:SetPoint("BOTTOMLEFT",actions,"BOTTOMLEFT",16,14)
  local test=Button(actions,"Run self-test",112,30,function() if ETBC.RunSelfTest then ETBC:RunSelfTest() end end,true); test:SetPoint("LEFT",edit,"RIGHT",8,0)
  local undo=Button(actions,"Undo change",112,30,function() local ok,label=History:UndoLatest(); CC:Toast(ok and ("Restored "..tostring(label)) or tostring(label),false,not ok); CC:RenderRoute(CC.route) end,true); undo:SetPoint("LEFT",test,"RIGHT",8,0)
  top=top+110
  local db=DB(); local favoriteNames={}; for key in pairs(db.moduleFavorites) do if self.model.byKey[key] then favoriteNames[#favoriteNames+1]=self.model.byKey[key].name end end; table.sort(favoriteNames)
  local favorites=Card(canvas,top,"Favorites",#favoriteNames==0 and "Mark frequently used modules as favorites from their page header." or table.concat(favoriteNames,"  •  ")); favorites:SetHeight(82); top=top+94
  local recent=History:GetRecent(5); local rc=Card(canvas,top,"Recent changes",#recent==0 and "Changes made this session will appear here." or "Use Undo change to restore the latest value."); rc:SetHeight(math.max(82,54+#recent*22))
  for i=1,#recent do local line=Font(rc,"• "..recent[i].label,10,T.muted); line:SetPoint("TOPLEFT",rc,"TOPLEFT",18,-48-(i-1)*22) end
  top=top+rc:GetHeight()+12; canvas:SetHeight(math.max(top,500))
end

function CC:RenderPage(page,focusKey)
  local canvas=self.canvas; Clear(canvas); self.controlOffsets={}; local db=DB(); local top=12
  local crumb=Font(canvas,"SETTINGS  /  "..page.category:upper(),9,T.gold); crumb:SetPoint("TOPLEFT",canvas,"TOPLEFT",16,-top); top=top+25
  local title=Font(canvas,page.name,20,T.text); title:SetPoint("TOPLEFT",canvas,"TOPLEFT",16,-top)
  local favorite=Button(canvas,db.moduleFavorites[page.key] and "★ Favorite" or "☆ Favorite",104,28,function() db.moduleFavorites[page.key]=not db.moduleFavorites[page.key]; CC:RenderRoute(page.key) end,true); favorite:SetPoint("TOPRIGHT",canvas,"TOPRIGHT",-14,-top+4)
  local enabledControl
  for i=1,#page.controls do if page.controls[i].id=="enabled" and page.controls[i].type=="toggle" then enabledControl=page.controls[i] break end end
  if enabledControl then
    local state=Get(enabledControl) and true or false
    local master=Button(canvas,state and "Enabled" or "Disabled",88,28,function() Set(enabledControl,not state); CC:RenderRoute(page.key) end,true); master:SetPoint("RIGHT",favorite,"LEFT",-8,0)
    if state then Color(master,{0.035,0.14,0.075,1},T.green); master.label:SetTextColor(T.green[1],T.green[2],T.green[3],1) end
  end
  local reset=Button(canvas,"Reset",62,28,function()
    StaticPopup_Show("ETBC_EXEC_CONFIRM","Reset this module to its defaults?",nil,{exec=function() if ETBC.ResetModuleProfile then ETBC:ResetModuleProfile(page.key); History:Clear(); CC:Toast(page.name.." reset",false); CC:RenderRoute(page.key) end end})
  end,true); reset:SetPoint("RIGHT",favorite,"LEFT",enabledControl and -104 or -8,0)
  top=top+34; top=AddDescription(canvas,page.description,top); top=top+8
  if page.error then local notice=Card(canvas,top,"Could not load this page",page.error); notice:SetHeight(82); top=top+94 end
  for s=1,#page.sectionOrder do
    local section=page.sections[page.sectionOrder[s]]
    if section and #section.controls>0 then
      local collapseKey=page.key..":"..section.key
      if db.sectionCollapsed[collapseKey]==nil and section.advanced then db.sectionCollapsed[collapseKey]=true end
      local collapsed=db.sectionCollapsed[collapseKey] and true or false
      local card,used=Card(canvas,top,section.name,section.advanced and "Specialist controls. Change these only when needed." or nil)
      card._pageOffset=top
      local toggle=Button(card,collapsed and "Expand" or "Collapse",74,24,function() db.sectionCollapsed[page.key..":"..section.key]=not collapsed; CC:RenderRoute(page.key) end,true); toggle:SetPoint("TOPRIGHT",card,"TOPRIGHT",-12,-10)
      local innerTop=used
      if not collapsed then for i=1,#section.controls do innerTop=RenderControl(card,section.controls[i],innerTop) end end
      card:SetHeight(collapsed and used+12 or innerTop+5); top=top+card:GetHeight()+12
    end
  end
  canvas:SetHeight(math.max(top,500)); RememberModule(page.key); if focusKey and self.controlOffsets[focusKey] then self.scroll:SetVerticalScroll(math.max(0,self.controlOffsets[focusKey]-80)) end
end

function CC:RenderSearch(query)
  local canvas=self.canvas; Clear(canvas); local results=Model:Search(self.model,query); self.searchResults=results; self.searchRows={}; self.searchIndex=math.min(self.searchIndex or 1,math.max(1,#results)); local top=14
  local title=Font(canvas,"Search",20,T.text); title:SetPoint("TOPLEFT",canvas,"TOPLEFT",16,-top); top=top+36
  local count=Font(canvas,("%d result%s for “%s”"):format(#results,#results==1 and "" or "s",query),10,T.muted); count:SetPoint("TOPLEFT",canvas,"TOPLEFT",16,-top); top=top+32
  if #results==0 then local empty=Card(canvas,top,"No settings found","Try a module name, setting, category, or behavior."); empty:SetHeight(88); top=top+100 end
  for i=1,#results do local c=results[i].control; local row=Button(canvas,c.name,400,44,function() self.search:SetText(""); self:Navigate(c.pageKey,c.key) end,true); row:SetPoint("TOPLEFT",canvas,"TOPLEFT",12,-top); row:SetPoint("TOPRIGHT",canvas,"TOPRIGHT",-12,-top); row.label:ClearAllPoints(); row.label:SetPoint("TOPLEFT",row,"TOPLEFT",12,-8); row.label:SetJustifyH("LEFT"); local path=Font(row,c.pageKey.."  ›  "..c.section,9,T.muted); path:SetPoint("BOTTOMLEFT",row,"BOTTOMLEFT",12,7); self.searchRows[i]=row; if i==self.searchIndex then Color(row,T.hover,T.gold) end; top=top+50 end
  canvas:SetHeight(math.max(top,500))
end

function CC:MoveSearchSelection(delta)
  local count=#(self.searchResults or {}); if count==0 then return end
  self.searchIndex=(self.searchIndex or 1)+delta; if self.searchIndex<1 then self.searchIndex=count elseif self.searchIndex>count then self.searchIndex=1 end
  for i,row in ipairs(self.searchRows or {}) do Color(row,i==self.searchIndex and T.hover or T.surface,i==self.searchIndex and T.gold or T.border) end
end

function CC:ActivateSearchSelection()
  local result=self.searchResults and self.searchResults[self.searchIndex or 1]; if not result then return end
  local c=result.control; self.search:SetText(""); self.search:ClearFocus(); self:Navigate(c.pageKey,c.key)
end

function CC:RenderRoute(route,focusKey)
  if not self.model then return end; local resolved=Model:Resolve(self.model,route) or "home"; self.route=resolved; local db=DB(); db.route=resolved
  self.breadcrumb:SetText(resolved=="home" and "Home" or ((self.model.byKey[resolved] and self.model.byKey[resolved].name) or resolved))
  if resolved=="home" then self:RenderDashboard() else self:RenderPage(self.model.byKey[resolved],focusKey) end
  self:RefreshNavigation(); if not focusKey then self.scroll:SetVerticalScroll(db.scrollPositions[resolved] or 0) end
end
function CC:Navigate(route,focusKey) self:RenderRoute(route,focusKey) end

function CC:RefreshNavigation()
  for _,entry in pairs(self.nav) do local selected=entry.key==self.route; Color(entry,selected and T.hover or T.surface,selected and T.gold or {0,0,0,0}); entry.label:SetTextColor(selected and T.gold[1] or T.muted[1],selected and T.gold[2] or T.muted[2],selected and T.gold[3] or T.muted[3],1) end
end

local function AddNav(parent,key,text,y)
  local b=Button(parent,text,190,30,function() CC:Navigate(key) end,true); b.key=key; b.fullText=text; b:SetPoint("TOPLEFT",parent,"TOPLEFT",10,-y); b.label:ClearAllPoints(); b.label:SetPoint("LEFT",b,"LEFT",12,0); b.label:SetJustifyH("LEFT")
  b:SetScript("OnEnter",function(self) Color(self,T.hover,T.gold); if CC.sidebar and CC.sidebar.compact and GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine(self.fullText,T.gold[1],T.gold[2],T.gold[3]); GameTooltip:Show() end end)
  b:SetScript("OnLeave",function(self) CC:RefreshNavigation(); if GameTooltip then GameTooltip:Hide() end end)
  CC.nav[#CC.nav+1]=b; return y+34
end

function CC:Build()
  if self.frame then return end; local db=DB(); self.model=Model:Build()
  local f=CreateFrame("Frame","EnhanceTBC_ControlCenter",UIParent,BackdropTemplateMixin and "BackdropTemplate" or nil); f:SetSize(db.w or 1080,db.h or 760); f:SetPoint(db.point or "CENTER",UIParent,db.relPoint or "CENTER",db.x or 0,db.y or 0); f:SetScale(db.scale or 1); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:SetMovable(true); f:SetResizable(true); f:SetMinResize(780,560); f:EnableMouse(true); f:EnableKeyboard(true); f:RegisterForDrag("LeftButton"); Color(f,T.bg,T.border)
  f:SetScript("OnDragStart",function(self) self:StartMoving() end); f:SetScript("OnDragStop",function(self) self:StopMovingOrSizing(); CC:Save() end)
  f:SetScript("OnSizeChanged",function(self,w) local compact=w<900; CC.sidebar:SetWidth(compact and 74 or 220); CC.sidebar.compact=compact; if CC.navCanvas then CC.navCanvas:SetWidth(compact and 70 or 216) end; for _,b in pairs(CC.nav) do b:SetWidth(compact and 54 or 190); b.label:SetText(compact and b.fullText:sub(1,1) or b.fullText) end end)
  f:SetScript("OnKeyDown",function(_,key) if key=="ESCAPE" then if CC.search:GetText()~="" then CC.search:SetText(""); CC:RenderRoute(CC.route) else ConfigWindow:Close() end elseif key=="/" or (key=="F" and IsControlKeyDown and IsControlKeyDown()) then CC.search:SetFocus() end end)
  self.frame=f

  local resize=CreateFrame("Button",nil,f); resize:SetSize(22,22); resize:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-2,2)
  local resizeMark=resize:CreateTexture(nil,"ARTWORK"); resizeMark:SetTexture("Interface\\Buttons\\WHITE8x8"); resizeMark:SetSize(12,2); resizeMark:SetPoint("BOTTOMRIGHT",resize,"BOTTOMRIGHT",-3,4); resizeMark:SetVertexColor(T.gold[1],T.gold[2],T.gold[3],.75)
  resize:SetScript("OnMouseDown",function() f:StartSizing("BOTTOMRIGHT") end); resize:SetScript("OnMouseUp",function() f:StopMovingOrSizing(); CC:Save() end)

  local top=CreateFrame("Frame",nil,f,BackdropTemplateMixin and "BackdropTemplate" or nil); top:SetPoint("TOPLEFT",f,"TOPLEFT",1,-1); top:SetPoint("TOPRIGHT",f,"TOPRIGHT",-1,-1); top:SetHeight(68); Color(top,T.surface,{0,0,0,0})
  local logo=top:CreateTexture(nil,"ARTWORK"); logo:SetTexture("Interface\\AddOns\\EnhanceTBC\\Media\\Images\\logo.tga"); logo:SetSize(52,52); logo:SetPoint("LEFT",top,"LEFT",10,0)
  local brand=Font(top,"EnhanceTBC",16,T.text); brand:SetPoint("LEFT",logo,"RIGHT",8,8); local tagline=Font(top,"CONTROL CENTER",8,T.gold); tagline:SetPoint("TOPLEFT",brand,"BOTTOMLEFT",0,-3)
  local search=CreateFrame("EditBox",nil,top,BackdropTemplateMixin and "BackdropTemplate" or nil); search:SetSize(330,34); search:SetPoint("CENTER",top,"CENTER",45,0); search:SetAutoFocus(false); search:SetTextInsets(12,12,0,0); Color(search,T.bg,T.border); search:SetText(db.search or ""); self.search=search
  local placeholder=Font(search,"Search every setting…",10,T.muted); placeholder:SetPoint("LEFT",search,"LEFT",12,0); search.placeholder=placeholder
  local function SearchChanged() local q=search:GetText() or ""; placeholder:SetShown(q==""); db.search=q; if CC.searchTimer and CC.searchTimer.Cancel then CC.searchTimer:Cancel() end; local render=function() CC.searchTimer=nil; if q~="" then CC:RenderSearch(q) else CC:RenderRoute(CC.route) end end; if ETBC.StartTimer then CC.searchTimer=ETBC:StartTimer(.12,render) else render() end end
  search:SetScript("OnTextChanged",SearchChanged); search:SetScript("OnEscapePressed",function(self) self:SetText(""); self:ClearFocus() end); search:SetScript("OnArrowPressed",function(_,key) CC:MoveSearchSelection(key=="UP" and -1 or 1) end); search:SetScript("OnEnterPressed",function() CC:ActivateSearchSelection() end)
  local edit=Button(top,"Edit UI",82,30,function() ConfigWindow:Close(); if ETBC.Mover then ETBC.Mover:SetMoveMode(true) end end,true); edit:SetPoint("RIGHT",top,"RIGHT",-54,0)
  local close=Button(top,"×",32,30,function() ConfigWindow:Close() end,true); close:SetPoint("RIGHT",top,"RIGHT",-12,0)

  local side=CreateFrame("Frame",nil,f,BackdropTemplateMixin and "BackdropTemplate" or nil); side:SetPoint("TOPLEFT",f,"TOPLEFT",1,-70); side:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",1,1); side:SetWidth(220); Color(side,T.surface,{0,0,0,0}); self.sidebar=side
  local navScroll=CreateFrame("ScrollFrame",nil,side); navScroll:SetPoint("TOPLEFT",side,"TOPLEFT",0,-4); navScroll:SetPoint("BOTTOMRIGHT",side,"BOTTOMRIGHT",-3,4); navScroll:EnableMouseWheel(true)
  local navCanvas=CreateFrame("Frame",nil,navScroll); navCanvas:SetWidth(216); navCanvas:SetHeight(600); navScroll:SetScrollChild(navCanvas); self.navCanvas=navCanvas
  navScroll:SetScript("OnMouseWheel",function(self,delta) self:SetVerticalScroll(math.max(0,self:GetVerticalScroll()-delta*38)) end)
  local y=14; y=AddNav(navCanvas,"home","Home",y)
  for _,category in ipairs(self.model.categoryOrder) do local pages=self.model.categories[category]; if pages and #pages>0 then local h=Font(navCanvas,category:upper(),8,T.gold); h:SetPoint("TOPLEFT",navCanvas,"TOPLEFT",16,-y-5); y=y+24; for i=1,#pages do y=AddNav(navCanvas,pages[i].key,pages[i].name,y) end end end
  navCanvas:SetHeight(y+18)

  local work=CreateFrame("Frame",nil,f,BackdropTemplateMixin and "BackdropTemplate" or nil); work:SetPoint("TOPLEFT",side,"TOPRIGHT",1,0); work:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-1,1); Color(work,T.bg,{0,0,0,0})
  local bar=CreateFrame("Frame",nil,work); bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT"); bar:SetHeight(42); local bread=Font(bar,"Home",10,T.muted); bread:SetPoint("LEFT",bar,"LEFT",16,0); self.breadcrumb=bread
  local scroll=CreateFrame("ScrollFrame",nil,work); scroll:SetPoint("TOPLEFT",bar,"BOTTOMLEFT",0,0); scroll:SetPoint("BOTTOMRIGHT",work,"BOTTOMRIGHT",-8,8); scroll:EnableMouseWheel(true); self.scroll=scroll
  local canvas=CreateFrame("Frame",nil,scroll); canvas:SetWidth(700); canvas:SetHeight(600); scroll:SetScrollChild(canvas); self.canvas=canvas
  scroll:SetScript("OnSizeChanged",function(_,w) canvas:SetWidth(math.max(420,w-12)) end); scroll:SetScript("OnMouseWheel",function(self,delta) local value=math.max(0,self:GetVerticalScroll()-delta*48); self:SetVerticalScroll(value); db.scrollPositions[CC.route]=value end)

  local toast=CreateFrame("Frame",nil,f,BackdropTemplateMixin and "BackdropTemplate" or nil); toast:SetSize(390,46); toast:SetPoint("BOTTOM",f,"BOTTOM",100,18); toast:SetFrameLevel((f:GetFrameLevel() or 1)+20); Color(toast,T.raised,T.gold); local tt=Font(toast,"Updated",10,T.text); tt:SetPoint("LEFT",toast,"LEFT",14,0); toast.text=tt; local undoBtn=Button(toast,"Undo",70,28,function() local ok,label=History:UndoLatest(); CC:Toast(ok and ("Restored "..tostring(label)) or tostring(label),false,not ok); CC:RenderRoute(CC.route) end,true); undoBtn:SetPoint("RIGHT",toast,"RIGHT",-8,0); toast.undo=undoBtn; toast:Hide(); self.toast=toast
  self:RenderRoute(db.route or "home"); f:Hide()
end

function CC:Save()
  local db=DB(); if not (db and self.frame) then return end; db.w=self.frame:GetWidth(); db.h=self.frame:GetHeight(); db.scale=self.frame:GetScale(); local point,rel,relPoint,x,y=self.frame:GetPoint(1); db.point=point; db.rel=rel and rel.GetName and rel:GetName() or "UIParent"; db.relPoint=relPoint; db.x=x; db.y=y
end
function CC:Open(route)
  self:Build(); self.model=Model:Build(); local requested=route or ETBC._requestedConfigSection; ETBC._requestedConfigSection=nil; self:RenderRoute(requested or DB().route or "home"); self.frame:Show(); self.frame:Raise()
end
function CC:Close() if not self.frame then return end; self:Save(); self.frame:Hide() end

function ConfigWindow:Open(section) CC:Open(section) end
function ConfigWindow:Close() CC:Close() end
function ConfigWindow:Toggle() if CC.frame and CC.frame:IsShown() then self:Close() else self:Open() end end

function CC:InvalidateProfile()
  History:Clear()
  if self.frame and self.frame:IsShown() then self.model=Model:Build(); self:RenderRoute(self.route) end
end

function CC:RefreshAccessibility()
  local db=DB()
  if db and db.highContrast then T.border={0.42,0.44,0.42,1}; T.muted={0.76,0.78,0.76,1}
  else T.border={0.16,0.18,0.18,0.9}; T.muted={0.62,0.65,0.66,1} end
  if self.frame and self.frame:IsShown() then self:RenderRoute(self.route); Color(self.frame,T.bg,T.border) end
end
