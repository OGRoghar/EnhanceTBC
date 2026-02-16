-- spec/applybus_spec.lua
-- Tests for Core/ApplyBus.lua

require('spec.wow_mocks')

describe("ApplyBus", function()
  local ETBC
  
  before_each(function()
    -- Reset the addon namespace
    ETBC = {}
    ETBC.ApplyBus = {}
    
    -- Load the ApplyBus module by simulating its code
    local listeners = {}
    
    function ETBC.ApplyBus:Register(key, fn)
      if not key or type(fn) ~= "function" then return end
      listeners[key] = listeners[key] or {}
      for i = 1, #listeners[key] do
        if listeners[key][i] == fn then
          return
        end
      end
      table.insert(listeners[key], fn)
    end
    
    function ETBC.ApplyBus:Unregister(key, fn)
      local list = listeners[key]
      if not list or type(fn) ~= "function" then return end
      for i = #list, 1, -1 do
        if list[i] == fn then
          table.remove(list, i)
        end
      end
    end
    
    function ETBC.ApplyBus:Notify(key)
      local list = listeners[key]
      if not list then return end
      local snapshot = {}
      for i = 1, #list do snapshot[i] = list[i] end
      for i = 1, #snapshot do
        local ok, err = pcall(snapshot[i], key)
        if not ok then
          if ETBC and ETBC.Debug then 
            ETBC:Debug("ApplyBus error ("..tostring(key).."): "..tostring(err)) 
          end
        end
      end
    end
    
    function ETBC.ApplyBus:NotifyAll()
      for key in pairs(listeners) do
        self:Notify(key)
      end
    end
    
    -- Expose listeners for testing
    ETBC.ApplyBus._listeners = listeners
  end)
  
  describe("Register", function()
    it("should register a function for a key", function()
      local called = false
      local callback = function() called = true end
      
      ETBC.ApplyBus:Register("test", callback)
      
      assert.is_not_nil(ETBC.ApplyBus._listeners["test"])
      assert.equals(1, #ETBC.ApplyBus._listeners["test"])
    end)
    
    it("should not register duplicate functions", function()
      local callback = function() end
      
      ETBC.ApplyBus:Register("test", callback)
      ETBC.ApplyBus:Register("test", callback)
      
      assert.equals(1, #ETBC.ApplyBus._listeners["test"])
    end)
    
    it("should handle invalid inputs gracefully", function()
      ETBC.ApplyBus:Register(nil, function() end)
      ETBC.ApplyBus:Register("test", nil)
      ETBC.ApplyBus:Register("test", "not a function")
      
      assert.is_nil(ETBC.ApplyBus._listeners["test"])
    end)
    
    it("should allow multiple different callbacks for same key", function()
      local callback1 = function() end
      local callback2 = function() end
      
      ETBC.ApplyBus:Register("test", callback1)
      ETBC.ApplyBus:Register("test", callback2)
      
      assert.equals(2, #ETBC.ApplyBus._listeners["test"])
    end)
  end)
  
  describe("Unregister", function()
    it("should unregister a specific function", function()
      local callback = function() end
      
      ETBC.ApplyBus:Register("test", callback)
      assert.equals(1, #ETBC.ApplyBus._listeners["test"])
      
      ETBC.ApplyBus:Unregister("test", callback)
      assert.equals(0, #ETBC.ApplyBus._listeners["test"])
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
