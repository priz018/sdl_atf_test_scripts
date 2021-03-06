---------------------------------------------------------------------------------------------------
-- Proposal: https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0147-template-color-scheme.md
--
-- Description:
-- SDL Core should track the number of attempted SetDisplayLayout requests with the current template and REJECT 
-- any beyond the first with the reason "Using SetDisplayLayout to change the color scheme may only be done once.
-- However, The color scheme can be changed if the layout is also changed.
--
-- Preconditions: Send SetDisplayLayout with a layout and a color scheme.
--
-- Steps: Send additional SetDisplayLayout with a different layout and a different color scheme.
--
-- Expected result: 
-- SDL Core returns SUCCESS
---------------------------------------------------------------------------------------------------

--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonSmoke = require('test_scripts/Smoke/commonSmoke')

local function getRequestParams()
  return { 
    displayLayout = "ONSCREEN_PRESETS",
    dayColorScheme = {
      primaryColor = {
        red = 0,
        green = 255,
        blue = 100
      }
    }
  }
end

local function getRequestParams2()
  return { 
    displayLayout = "MEDIA",
    dayColorScheme = {
      primaryColor = {
        red = 0,
        green = 255,
        blue = 100
      }
    }
  }
end

local function setDisplayWithColorsSuccess(self)
  local responseParams = {}
  local cid = self.mobileSession1:SendRPC("SetDisplayLayout", getRequestParams())
  EXPECT_HMICALL("UI.SetDisplayLayout", getRequestParams())
  :Do(function(_, data)
    self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", responseParams)
  end)
  self.mobileSession1:ExpectResponse(cid, {
    success = true,
    resultCode = "SUCCESS"
  })
end

local function setDisplayWithColorsAndNewLayoutSuccess(self)
  local responseParams = {}
  local cid = self.mobileSession1:SendRPC("SetDisplayLayout", getRequestParams2())
  EXPECT_HMICALL("UI.SetDisplayLayout", getRequestParams2())
  :Do(function(_, data)
    self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", responseParams)
  end)
  self.mobileSession1:ExpectResponse(cid, {
    success = true,
    resultCode = "SUCCESS"
  })
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonSmoke.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonSmoke.start)
runner.Step("RAI", commonSmoke.registerApp)
runner.Step("Activate App", commonSmoke.activateApp)

runner.Title("Test")
runner.Step("SetDisplay Positive Case 1", setDisplayWithColorsSuccess)
runner.Step("SetDisplay Positive Case 2", setDisplayWithColorsAndNewLayoutSuccess)

runner.Title("Postconditions")
runner.Step("Stop SDL", commonSmoke.postconditions)
