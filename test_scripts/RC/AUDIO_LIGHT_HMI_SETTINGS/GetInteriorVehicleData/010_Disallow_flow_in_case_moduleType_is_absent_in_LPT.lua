---------------------------------------------------------------------------------------------------
-- User story: https://github.com/smartdevicelink/sdl_requirements/issues/2
-- Use case: https://github.com/smartdevicelink/sdl_requirements/blob/master/detailed_docs/current_module_status_data.md
-- Item: Use Case 1: Main Flow
--
-- Requirement summary:
-- [SDL_RC] Current module status data GetInteriorVehicleData
-- [SDL_RC] Policy support of basic RC functionality
--
-- Description:
-- In case:
-- 1) "moduleType" does not exist in app's assigned policies
-- 2) and RC app sends GetInteriorVehicleData request with valid parameters
-- SDL must:
-- 1) Disallow this RPC to be processed (success:false, "DISALLOWED")
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require("test_scripts/RC/commonRC")

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

local function PTUfunc(tbl)
  local appId = config.application1.registerAppInterfaceParams.appID
  tbl.policy_table.app_policies[appId] = common.getRCAppConfig()
  tbl.policy_table.app_policies[config.application1.registerAppInterfaceParams.appID].moduleType = nil
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions, { false })
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("RAI", common.registerApp)
runner.Step("PTU", common.policyTableUpdate, { PTUfunc })
runner.Step("Activate App", common.activateApp)

runner.Title("Test")

for _, mod in pairs(common.newModules) do
  runner.Step("GetInteriorVehicleData " .. mod, common.rpcDenied, { mod, 1, "GetInteriorVehicleData", "DISALLOWED" })
end

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
