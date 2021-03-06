---------------------------------------------------------------------------------------------
-- Requirement summary:
-- [ResetGlobalProperties] "MENUICON" reset
-- [INI file] [ApplicationManager] MenuIcon
--
-- Description:
-- Check that SDL correctly retrievs menuIcon from INI file in case ResetGlobalProperties
-- is sent only with MENUICON in Properties array.
--
-- 1. Used preconditions:
-- Check that menuIcon exists in INI file.
-- ResetGlobalProperties and SetGlobalProperties is allowed by policy.
-- menuIcon will be re-written in INI file with absolute path
-- Send SetGlobalProperties(menuIcon = { value = "action.png", imageType = "DYNAMIC" })
-- Perform resumption because of IGN_OFF -> IGN_ON. => menuIcon is resumed
--
-- 2. Performed steps
-- Send ResetGlobalProperties(properties = "MENUICON")
--
-- Expected result:
-- 1. UI.SetGlobalProperties(menuIcon = {imageType = "DYNAMIC", value = absolute path})
-- 2. TTS.SetGlobalProperties is not sent.
---------------------------------------------------------------------------------------------

--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"
--TODO(istoimenova): should be removed when "ATF does not stop HB timers by closing session and connection" is fixed
config.defaultProtocolVersion = 2

--[[ Required Shared libraries ]]
local commonPreconditions = require ('user_modules/shared_testcases/commonPreconditions')
local commonSteps = require ('user_modules/shared_testcases/commonSteps')
local testCasesForPolicyTable = require ('user_modules/shared_testcases/testCasesForPolicyTable')
local commonFunctions = require ('user_modules/shared_testcases/commonFunctions')
local testCasesForMenuIconMenuTitleParameters = require ('user_modules/shared_testcases/testCasesForMenuIconMenuTitleParameters')
local mobile_session = require('mobile_session')

--[[ Local Variables ]]
local empty_menuIcon
local icon_to_check
local absolute_path = testCasesForMenuIconMenuTitleParameters:ReadCmdLine("pwd")
local SGP_path = absolute_path .. "/SDL_bin/./".. "storage/" ..config.application1.registerAppInterfaceParams.appID.. "_" .. config.deviceMAC.. "/"
local SGP_path1 = absolute_path .. "/SDL_bin/".. "storage/" ..config.application1.registerAppInterfaceParams.appID.. "_" .. config.deviceMAC.. "/"

--[[ General Precondition before ATF start ]]
commonSteps:DeleteLogsFiles()
commonPreconditions:BackupFile("sdl_preloaded_pt.json")
commonPreconditions:BackupFile("smartDeviceLink.ini")

testCasesForPolicyTable:precondition_updatePolicy_AllowFunctionInHmiLeves({"BACKGROUND", "FULL", "LIMITED", "NONE"},"SetGlobalProperties")
testCasesForPolicyTable:precondition_updatePolicy_AllowFunctionInHmiLeves({"BACKGROUND", "FULL", "LIMITED", "NONE"},"ResetGlobalProperties")
empty_menuIcon, icon_to_check = testCasesForMenuIconMenuTitleParameters:UpdateINI("absolute")

--[[ General Settings for configuration ]]
Test = require('connecttest')
require('user_modules/AppTypes')

--[[ Preconditions ]]
commonFunctions:newTestCasesGroup("Preconditions")
function Test:Precondition_CheckINI_menuIcon()
  if (empty_menuIcon == true) then
    self:FailTestCase("menuIcon is not found in INI file.")
  end
end

function Test:Precondition_ActivateApp()
	testCasesForMenuIconMenuTitleParameters:ActivateAppDiffPolicyFlag(self, config.application1.registerAppInterfaceParams.appName, config.deviceMAC)
end

commonSteps:PutFile("Precondition_PutFile_action.png", "action.png")

function Test:Precondition_SetGlobalProperties_menuIcon()
  local cid = self.mobileSession:SendRPC("SetGlobalProperties",{ menuIcon = { value = "action.png", imageType = "DYNAMIC" } })

  EXPECT_HMICALL("UI.SetGlobalProperties", { menuIcon = { imageType = "DYNAMIC" } })--, value = SGP_path .. "action.png"} })
  :Do(function(_,data)
      self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {})
    end)
  :ValidIf(function(_,data)
    if(data.params.menuIcon.value ~= nil) then
      if( (data.params.menuIcon.value == SGP_path .. "action.png") or (data.params.menuIcon.value == SGP_path1 .. "action.png") ) then
        return true
      else
        commonFunctions:printError("menuIcon.value is: " ..data.params.menuIcon.value ..". Expected: " .. SGP_path1 .. "action.png")
        return false
      end
    else
      commonFunctions:printError("menuIcon.value has a nil value")
      return false
    end
  end)

  EXPECT_HMICALL("TTS.SetGlobalProperties",{}):Times(0)
  EXPECT_RESPONSE(cid, { success = true, resultCode = "SUCCESS"})
  EXPECT_NOTIFICATION("OnHashChange")
  :Do(function(_, data) self.currentHashID = data.payload.hashID end)

end

function Test:Precondition_Suspend()
  self.hmiConnection:SendNotification("BasicCommunication.OnExitAllApplications", { reason = "SUSPEND" })
  EXPECT_HMINOTIFICATION("BasicCommunication.OnSDLPersistenceComplete")
end


function Test:Precondition_Ignion_OFF()
  StopSDL()
  self.hmiConnection:SendNotification("BasicCommunication.OnExitAllApplications", { reason = "IGNITION_OFF" })
  EXPECT_HMINOTIFICATION("BasicCommunication.OnSDLClose")
  EXPECT_HMINOTIFICATION("BasicCommunication.OnAppUnregistered")
end

function Test.Precondition_StartSDL()
  StartSDL(config.pathToSDL, config.ExitOnCrash)
end

function Test:Precondition_InitHMI()
  self:initHMI()
end

function Test:Precondition_InitHMIOnReady()
  self:initHMI_onReady()
end

function Test:Precondition_ConnectMobile()
  self:connectMobile()
end

function Test:Precondition_StartSession()
  self.mobileSession = mobile_session.MobileSession( self, self.mobileConnection)
end

function Test:Precondition_RegisterAppResumption()
  config.application1.registerAppInterfaceParams.hashID = self.currentHashID

  self.mobileSession:StartService(7)
  :Do(function()
      local CorIdRegister = self.mobileSession:SendRPC("RegisterAppInterface", config.application1.registerAppInterfaceParams)
      EXPECT_HMINOTIFICATION("BasicCommunication.OnAppRegistered", { application = { appName = config.application1.registerAppInterfaceParams.appName }})
      :Do(function(_,data) self.applications[config.application1.registerAppInterfaceParams.appName] = data.params.application.appID end)

      EXPECT_HMICALL("BasicCommunication.ActivateApp")
      :Do(function(_,data) self.hmiConnection:SendResponse(data.id,"BasicCommunication.ActivateApp", "SUCCESS", {}) end)

      self.mobileSession:ExpectResponse(CorIdRegister, { success = true, resultCode = "SUCCESS" })

      EXPECT_NOTIFICATION("OnHMIStatus",
        {hmiLevel = "NONE", systemContext = "MAIN"},
        {hmiLevel = "FULL", systemContext = "MAIN"})
      :Do(function(exp,_)
          if(exp.occurences == 2) then
            local TimeHMILevel = timestamp()
            print("HMI LEVEL is resumed")
            return TimeHMILevel
          end
        end)
      :Times(2)
    end)

  EXPECT_HMICALL("UI.SetGlobalProperties", { menuIcon = { imageType = "DYNAMIC" } })--, value = SGP_path .. "action.png"} })
  :Do(function(_,data) self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {}) end)
  :ValidIf(function(_,data)
      if(data.params.menuIcon.value ~= nil) then
        if( (data.params.menuIcon.value == SGP_path .. "action.png") or (data.params.menuIcon.value == SGP_path1 .. "action.png") ) then
          return true
        else
          commonFunctions:printError("menuIcon.value is: " ..data.params.menuIcon.value ..". Expected: " .. SGP_path1 .. "action.png")
          return false
        end
      else
        commonFunctions:printError("menuIcon.value has a nil value")
        return false
      end
    end)

  EXPECT_HMICALL("TTS.SetGlobalProperties",{}):Times(0)

  EXPECT_NOTIFICATION("OnHashChange")
  :Do(function(_, data) self.currentHashID = data.payload.hashID end)

end

--[[ Test ]]
commonFunctions:newTestCasesGroup("Test")

function Test:TestStep_menuIcon_absolute_path_INI_PrecSGP_Resumption()
  local cid = self.mobileSession:SendRPC("ResetGlobalProperties",{ properties = { "MENUICON" }})

  EXPECT_HMICALL("UI.SetGlobalProperties",{
      menuIcon = {
        imageType = "DYNAMIC",
        value = icon_to_check
      }
    })
  :Do(function(_,data) self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {}) end)

  EXPECT_HMICALL("TTS.SetGlobalProperties",{}):Times(0)
  EXPECT_RESPONSE(cid, { success = true, resultCode = "SUCCESS"})
  EXPECT_NOTIFICATION("OnHashChange")
  :Do(function(_, data) self.currentHashID = data.payload.hashID end)

end

--[[ Postconditions ]]
commonFunctions:newTestCasesGroup("Postconditions")

function Test.Postcondition_RestoreConfigFiles()
  commonPreconditions:RestoreFile("smartDeviceLink.ini")
  commonPreconditions:RestoreFile("sdl_preloaded_pt.json")
end

function Test.Postcondition_StopSDL()
  StopSDL()
end

return Test