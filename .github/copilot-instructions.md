# EnhanceTBC - GitHub Copilot Instructions

## Project Overview
EnhanceTBC is a quality-of-life addon suite for World of Warcraft: The Burning Crusade Anniversary Edition (TBC 2026, Ver 2.5.5, interface 20505). Built with Ace3 framework, it provides UI enhancements, minimap improvements, action bars, cast bars, unit frames, and various gameplay conveniences.

## Technology Stack
- **Language**: Lua (WoW TBC API)
- **Framework**: Ace3 (AceAddon, AceDB, AceConfig, etc.)
- **Target**: World of Warcraft TBC Anniversary Ver 2.5.5 (20505)
- **License**: MIT

## Project Structure

### Core Architecture
- `Core/` - Bootstrapping and core systems (must load before Settings/Modules)
  - `Defaults.lua` - Default configuration values
  - `Init.lua` - Addon namespace initialization
  - `ApplyBus.lua` - Event bus for settings updates
  - `SettingsRegistry.lua` - Settings registration system
  - `EnhanceTBC.lua` - Main addon initialization
- `Modules/` - Feature implementations
- `Settings/` - AceConfig option definitions (one file per module)
- `UI/` - User interface components
- `Visibility/` - Visibility condition system
- `Libs/` - Embedded Ace3 and other libraries
- `Media/` - Assets (images, cursors, spell icons)
- `locales/` - Localization files

### File Naming Convention
- Settings files: `Settings_<ModuleName>.lua` (e.g., `Settings_MinimapPlus.lua`)
- Module files: `<ModuleName>.lua` in Modules/ (e.g., `MinimapPlus.lua`)
- Always maintain paired Settings/Module files

## Coding Standards

### Lua Conventions

#### Module Pattern
```lua
-- Standard module header
local ADDON_NAME, ETBC = ...

ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.ModuleName = mod
```

#### Database Access Pattern
Every module should have a `GetDB()` function with inline defaults:
```lua
local function GetDB()
  ETBC.db.profile.moduleName = ETBC.db.profile.moduleName or {}
  local db = ETBC.db.profile.moduleName
  
  -- Set defaults inline
  if db.enabled == nil then db.enabled = true end
  if db.someOption == nil then db.someOption = defaultValue end
  
  return db
end
```

#### ApplyBus Pattern
All settings must trigger live updates via ApplyBus:
```lua
-- In Settings files
local function Apply()
  if ETBC.ApplyBus and ETBC.ApplyBus.Notify then
    ETBC.ApplyBus:Notify("modulename")
  end
end

-- In Module files, register listener
ETBC.ApplyBus:Register("modulename", function()
  mod:Apply()
end)
```

### WoW API Conventions

#### Boolean Conversion
WoW API functions return `1` or `nil`, not `true`/`false`. Use double negation to convert:
```lua
-- Correct
local inCombat = not not UnitAffectingCombat("player")

-- Incorrect
local inCombat = UnitAffectingCombat("player") -- This gives 1 or nil
```

#### Nil Safety
**Always check for nil** when unpacking WoW API returns:
```lua
-- Correct
local _, _, sender, subject = GetInboxHeaderInfo(i)
if not sender then
  -- Handle invalid entry
  return nil, nil, 0, 0, 0, false
end

-- Also correct with default values
local money = tonumber(money) or 0
```

#### Unused Return Values
Use underscore `_` for unused return values:
```lua
-- Correct
local _, _, sender, subject = GetInboxHeaderInfo(i)

-- Incorrect - don't use descriptive names for unused values
local packageIcon, stationaryIcon, sender, subject = GetInboxHeaderInfo(i)
```

### Defensive Coding

#### Nil Chain Safety
Some modules use defensive nil checks for initialization:
```lua
if ETBC and ETBC.db and ETBC.db.profile then
  -- Safe to access
end
```
However, most modules assume `ETBC.db` exists after Core bootstrap completes.

#### Function Guards
```lua
if not key or type(fn) ~= "function" then return end
```

### WoW API Compatibility

#### Container API Compatibility (Classic/TBC)
Always use compatibility wrappers for container APIs:
```lua
local C = C_Container  -- May be nil in older versions

local function GetBagNumSlots(bag)
  if C and C.GetContainerNumSlots then
    return C.GetContainerNumSlots(bag) or 0
  end
  if GetContainerNumSlots then
    return GetContainerNumSlots(bag) or 0
  end
  return 0
end
```
See `Modules/Vendor.lua` and `Modules/Mailbox.lua` for complete examples.

### Frame and UI Constraints

#### Frame Resizing Limitation
**CRITICAL**: Do NOT implement width/height resizing for UnitFrames and Castbars
- Changing dimensions causes texture misalignment with Blizzard frame internals
- Use `scale` instead of width/height for size adjustments
- Width/height settings should be disabled with explanatory tooltips:
```lua
disabled = function() return true end,
desc = "Width adjustment disabled - use Scale to resize (Blizzard frame limitations)",
```

### Error Handling
```lua
local ok, err = pcall(functionCall)
if not ok then
  if ETBC and ETBC.Debug then 
    ETBC:Debug("Error message: "..tostring(err)) 
  end
end
```

## Best Practices

### Settings Files (Settings/*.lua)
1. Match the structure of existing settings files
2. Always include `EnsureDefaults()` function
3. All option `set` callbacks must call `Apply()`
4. Use `width = "full"` for toggle options consistently

### Module Files (Modules/*.lua)
1. Include descriptive header comment explaining features
2. Register ApplyBus listener for live config updates
3. Implement `Apply()` or similar function for settings updates
4. Use `GetDB()` pattern for database access
5. Defensive nil checks when accessing API returns

### Minimap and UI Components
- Square minimap requires aggressive re-application due to UI cluster resets
- Use timers and continuous monitoring for persistent changes
- Test minimap changes thoroughly as they're prone to interference

### Code Organization
- Keep files focused on single responsibilities
- Follow existing module patterns strictly (check `Modules/Vendor.lua` for simple example)
- Maintain consistency with paired Settings/Module files
- Load order matters: Core → Settings → Modules → Visibility
- Module complexity ranges from ~200 lines (simple) to ~1700 lines (MinimapPlus)
- Use constants at file top for magic numbers and texture paths
- Group related functionality into local functions before module methods

### Comments
- Add header comments to files explaining purpose
- Comment complex logic and workarounds
- Explain WoW API quirks when encountered
- Keep inline comments minimal unless clarifying non-obvious code

## Common Patterns

### Print Function
```lua
local function Print(msg)
  if ETBC and ETBC.Print then
    ETBC:Print(msg)
  elseif DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99EnhanceTBC|r " .. tostring(msg))
  end
end
```

### Color Tables
```lua
-- RGBA format (values 0.0 to 1.0)
db.latencyColor = { 0.20, 1.00, 0.20, 0.28 }

-- Named format
db.highlightColor = { r = 0.2, g = 1.0, b = 0.2, a = 1.0 }
```

### Frame Creation
```lua
local driver = CreateFrame("Frame", "EnhanceTBC_ModuleName", UIParent)
```

### Slash Commands and UI Access
```lua
-- Addon provides multiple entry points:
/etbc                    -- Open config UI
/etbc config            -- Open config UI (alias)
/etbc reset             -- Reset profile to defaults
/etbc minimap           -- Toggle minimap icon
/etbc moveall [on|off|toggle]  -- Toggle frame mover mode
/etbc listgossip        -- List auto-gossip patterns
/etbc addgossip <text>  -- Add auto-gossip pattern
/enhancetbc             -- Alias for /etbc

-- Opening config programmatically
ETBC:OpenConfig()       -- Preferred method (handles custom UI fallback)
```

### Module Registration Pattern
```lua
-- Standard pattern in all module files
local ADDON_NAME, ETBC = ...
ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.ModuleName = mod

-- Then define module methods
function mod:Initialize()
  -- Setup code
end

function mod:Apply()
  -- Live config update code
end

-- Register with ApplyBus
ETBC.ApplyBus:Register("modulename", function()
  mod:Apply()
end)
```

## Testing

### Automated Testing
- Project uses **Busted** framework with Lua 5.1 for unit tests
- Run tests: `busted` (or `busted --verbose --coverage`)
- Test files: `spec/*_spec.lua` pattern
- WoW API mocks: `spec/wow_mocks.lua` provides LibStub, CreateFrame, C_Timer, etc.
- CI/CD: GitHub Actions runs tests on push/PR (see `.github/workflows/ci.yml`)
- Coverage: Use `luacov` to generate coverage reports

### Loading Core Modules in Tests
```lua
-- Core files expect ADDON_NAME and ETBC via varargs
local ADDON_NAME = "EnhanceTBC"
local ETBC = {}
local chunk, err = loadfile('Core/ApplyBus.lua')
assert(chunk, err)
chunk(ADDON_NAME, ETBC)  -- Pass varargs to match production pattern
```

### Manual Testing
- Test in-game with WoW TBC Anniversary client (Ver 2.5.5, interface 20505)
- Verify settings persist across sessions and `/reload`
- Test ApplyBus updates apply immediately without reload
- Check for nil errors with defensive tests
- Verify minimap features don't break on zone changes
- Test UI changes across different resolutions and UI scales

## Development Workflow
1. Understand the module's purpose and scope
2. Follow existing patterns in similar modules (check similar-sized modules for reference)
3. Implement Settings file first with Apply() callback
4. Implement Module file with ApplyBus registration
5. Add tests if implementing core logic (ApplyBus, utilities, validators)
6. Test live config updates in-game
7. Handle edge cases and nil values
8. Run `busted` to verify tests pass before committing

## Important Notes
- **Do NOT** add new dependencies without careful consideration
- **Do NOT** modify Blizzard frame dimensions (width/height) - use scale
- **ALWAYS** use ApplyBus for settings updates
- **ALWAYS** check for nil when unpacking WoW API returns
- **ALWAYS** use `not not` to convert WoW boolean returns to true/false
- **ALWAYS** use HTTPS URLs in rockspec files (never git:// protocol for security)
- File load order is critical - respect the `.toc` order (Core → Settings → Modules → Visibility)
- The addon namespace is available as both `ETBC` and `EnhanceTBC` globals

## Key Architectural Decisions

### Event Bus Architecture
ApplyBus (`Core/ApplyBus.lua`) is the central event system for settings changes:
- Decouples Settings files from Module implementation
- Allows multiple listeners per key
- Uses pcall for error isolation
- Settings files call `ApplyBus:Notify(key)` on changes
- Modules register with `ApplyBus:Register(key, callback)`

### Database Pattern
Every module follows the same DB access pattern:
1. Settings files have `GetDB()` with `EnsureDefaults()`
2. Module files have `GetDB()` with inline defaults
3. Inline defaults provide runtime safety without reload
4. Example: `if db.enabled == nil then db.enabled = true end`

### Load Order Dependencies
The `.toc` file defines strict load order:
1. **Libs/** - All dependencies (Ace3, LibStub, etc.)
2. **locales/** - Localization tables
3. **Core/** - Bootstrap (Defaults → Print → ApplyBus → SettingsRegistry → Init → EnhanceTBC)
4. **Options/** - Root options builder
5. **UI/** - UI components
6. **Settings/** - AceConfig option tables (one per module)
7. **Modules/** - Feature implementations
8. **Visibility/** - Visibility condition system

Violating this order causes nil reference errors.

### Settings Registry Pattern
Optional but recommended for complex modules:
```lua
-- In Settings file, register capabilities
ETBC.SettingsRegistry:Register("modulename", {
  providesSomeFeature = true,
  version = "1.0"
})

-- Other modules can check capabilities
if ETBC.SettingsRegistry:HasCapability("modulename", "providesSomeFeature") then
  -- Use feature
end
```
