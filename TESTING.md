# Testing

## Overview

EnhanceTBC uses [Busted](https://lunarmodules.github.io/busted/) as its testing framework for unit testing pure Lua logic that doesn't depend on WoW API.

## Running Tests Locally

### Prerequisites

1. Install Lua 5.1:
   ```bash
   # On Ubuntu/Debian
   sudo apt-get install lua5.1
   
   # On macOS
   brew install lua@5.1
   ```

2. Install LuaRocks:
   ```bash
   # On Ubuntu/Debian
   sudo apt-get install luarocks
   
   # On macOS
   brew install luarocks
   ```

3. Install test dependencies:
   ```bash
   luarocks install busted
   luarocks install luacov
   ```

### Running Tests

Run all tests:
```bash
busted
```

Run tests with verbose output:
```bash
busted --verbose
```

Run tests with coverage:
```bash
busted --coverage
luacov
```

View coverage report:
```bash
cat luacov.report.out
```

## Continuous Integration

Tests are automatically run on every push and pull request via GitHub Actions. See `.github/workflows/ci.yml` for the CI configuration.

## Writing Tests

Test files should be placed in the `spec/` directory and follow the naming pattern `*_spec.lua`.

### Example Test

```lua
require('spec.wow_mocks')

describe("MyModule", function()
  before_each(function()
    -- Setup
  end)
  
  it("should do something", function()
    assert.is_true(true)
  end)
end)
```

### WoW API Mocks

Since WoW addons depend on the game client's API, we provide mock implementations in `spec/wow_mocks.lua`. These mocks allow testing pure Lua logic without requiring the WoW client.

## Limitations

- Tests can only cover pure Lua logic that doesn't depend on WoW client internals
- UI-related features require manual testing in-game
- Some modules heavily depend on WoW API and may not be easily testable in isolation
- The primary testing strategy remains manual in-game testing

## Test Coverage

Current test coverage focuses on:
- ApplyBus event system
- Pure utility functions
- Configuration validation

Future coverage may include:
- Settings validation
- Data transformation utilities
- Non-UI business logic
