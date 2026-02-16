-- spec/applybus_spec.lua
-- Tests for Core/ApplyBus.lua

require('spec.wow_mocks')

describe("ApplyBus", function()
  local ETBC
  local ADDON_NAME = "EnhanceTBC"
  
  before_each(function()
    -- Reset the addon namespace
    ETBC = {}
    
    -- Load the real ApplyBus module
    local chunk, err = loadfile('Core/ApplyBus.lua')
    if not chunk then
      error("Failed to load Core/ApplyBus.lua: " .. tostring(err))
    end
    chunk(ADDON_NAME, ETBC)
  end)
  
  describe("Register", function()
    it("should register a function for a key", function()
      local called = false
      local callback = function() called = true end
      
      ETBC.ApplyBus:Register("test", callback)
      ETBC.ApplyBus:Notify("test")
      
      assert.is_true(called)
    end)
    
    it("should not register duplicate functions", function()
      local count = 0
      local callback = function() count = count + 1 end
      
      ETBC.ApplyBus:Register("test", callback)
      ETBC.ApplyBus:Register("test", callback)
      ETBC.ApplyBus:Notify("test")
      
      -- Should only be called once despite double registration
      assert.equals(1, count)
    end)
    
    it("should handle invalid inputs gracefully", function()
      -- These should not error
      ETBC.ApplyBus:Register(nil, function() end)
      ETBC.ApplyBus:Register("test", nil)
      ETBC.ApplyBus:Register("test", "not a function")
    end)
    
    it("should allow multiple different callbacks for same key", function()
      local count = 0
      local callback1 = function() count = count + 1 end
      local callback2 = function() count = count + 1 end
      
      ETBC.ApplyBus:Register("test", callback1)
      ETBC.ApplyBus:Register("test", callback2)
      ETBC.ApplyBus:Notify("test")
      
      assert.equals(2, count)
    end)
  end)
  
  describe("Unregister", function()
    it("should unregister a specific function", function()
      local count = 0
      local callback = function() count = count + 1 end
      
      ETBC.ApplyBus:Register("test", callback)
      ETBC.ApplyBus:Notify("test")
      assert.equals(1, count)
      
      ETBC.ApplyBus:Unregister("test", callback)
      ETBC.ApplyBus:Notify("test")
      
      -- Count should still be 1 (not incremented after unregister)
      assert.equals(1, count)
    end)
    
    it("should handle unregistering non-existent callbacks gracefully", function()
      local callback = function() end
      
      ETBC.ApplyBus:Unregister("test", callback)
      -- Should not error
    end)
    
    it("should handle invalid inputs gracefully", function()
      ETBC.ApplyBus:Unregister(nil, function() end)
      ETBC.ApplyBus:Unregister("test", nil)
      -- Should not error
    end)
  end)
  
  describe("Notify", function()
    it("should call registered callbacks when notified", function()
      local called = false
      local callback = function() called = true end
      
      ETBC.ApplyBus:Register("test", callback)
      ETBC.ApplyBus:Notify("test")
      
      assert.is_true(called)
    end)
    
    it("should pass the key to callbacks", function()
      local receivedKey = nil
      local callback = function(key) receivedKey = key end
      
      ETBC.ApplyBus:Register("mykey", callback)
      ETBC.ApplyBus:Notify("mykey")
      
      assert.equals("mykey", receivedKey)
    end)
    
    it("should call all registered callbacks", function()
      local count = 0
      local callback1 = function() count = count + 1 end
      local callback2 = function() count = count + 1 end
      local callback3 = function() count = count + 1 end
      
      ETBC.ApplyBus:Register("test", callback1)
      ETBC.ApplyBus:Register("test", callback2)
      ETBC.ApplyBus:Register("test", callback3)
      ETBC.ApplyBus:Notify("test")
      
      assert.equals(3, count)
    end)
    
    it("should handle callbacks that error gracefully", function()
      local called1 = false
      local called2 = false
      
      local callback1 = function() called1 = true end
      local callback2 = function() error("Test error") end
      local callback3 = function() called2 = true end
      
      ETBC.ApplyBus:Register("test", callback1)
      ETBC.ApplyBus:Register("test", callback2)
      ETBC.ApplyBus:Register("test", callback3)
      
      -- Should not throw
      ETBC.ApplyBus:Notify("test")
      
      assert.is_true(called1)
      assert.is_true(called2)
    end)
    
    it("should handle notifying non-existent keys gracefully", function()
      -- Should not error
      ETBC.ApplyBus:Notify("nonexistent")
    end)
  end)
  
  describe("NotifyAll", function()
    it("should notify all registered keys", function()
      local count = 0
      
      ETBC.ApplyBus:Register("key1", function() count = count + 1 end)
      ETBC.ApplyBus:Register("key2", function() count = count + 10 end)
      ETBC.ApplyBus:Register("key3", function() count = count + 100 end)
      
      ETBC.ApplyBus:NotifyAll()
      
      assert.equals(111, count)
    end)
    
    it("should handle empty listener list gracefully", function()
      -- Should not error
      ETBC.ApplyBus:NotifyAll()
    end)
  end)
end)
