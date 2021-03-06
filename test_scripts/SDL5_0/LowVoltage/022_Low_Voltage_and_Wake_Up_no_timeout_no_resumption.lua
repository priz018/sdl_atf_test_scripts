---------------------------------------------------------------------------------------------------
-- In case:
-- 1. Mobile app is in FULL HMILevel
-- 2. App sends AddCommand, however SDL is not saved resumption data since timer (10s) has not expired yet
-- 3. SDL get LOW_VOLTAGE signal
-- 4. App closes connection
-- 5. And then SDL get WAKE_UP signal
-- SDL does:
-- 1. not resume FULL HMILevel for app
-- 2. not resume persistent data
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/SDL5_0/LowVoltage/common')
local runner = require('user_modules/script_runner')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Functions ]]
local function addCommand()
  common.rpcSend.AddCommand(1, 1)
end

local function checkResumptionData()
  common.getHMIConnection():ExpectRequest("VR.AddCommand")
  :Times(0)
end

local function checkResumptionHMILevel()
  common.getHMIConnection():ExpectRequest("BasicCommunication.ActivateApp")
  :Times(0)
  common.getMobileSession():ExpectNotification("OnHMIStatus",
    { hmiLevel = "NONE", audioStreamingState = "NOT_AUDIBLE", systemContext = "MAIN" })
end

local function checkAppId(pAppId, pData)
  if pData.params.application.appID == common.getHMIAppId(pAppId) then
    return false, "App " .. pAppId .. " is registered with the same HMI App Id"
  end
  return true
end

local function sendWakeUpSignal()
  common.cleanSessions()
  common.sendWakeUpSignal()
  common.getHMIConnection():ExpectNotification("BasicCommunication.OnAppUnregistered")
  :Times(0)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile", common.start)
runner.Step("Register App ", common.registerApp)
runner.Step("PolicyTableUpdate", common.policyTableUpdate)
runner.Step("Activate app", common.activateApp)
runner.Step("Add command data for App ", addCommand)

runner.Title("Test")
runner.Step("Send LOW_VOLTAGE signal", common.sendLowVoltageSignal)
runner.Step("Send WAKE_UP signal", sendWakeUpSignal)
runner.Step("Re-connect Mobile", common.connectMobile)
runner.Step("Re-register App, check resumption data and HMI level", common.reRegisterApp, {
  1, checkAppId, checkResumptionData, checkResumptionHMILevel, "RESUME_FAILED", 11000
})

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
