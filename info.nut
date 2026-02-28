require("version.nut");
class ProductionBooster extends GSInfo {
  function GetAuthor()      { return "nelbin4"; }
  function GetName()        { return "Production Booster"; }
  function GetDescription() { return "Dynamically adjusts primary industry production levels based on cargo transport efficiency. Production increases when transport rates are high and decreases when transport rates are low, encouraging better network coverage. https://github.com/nelbin4/openttdprodboost"; }
  function GetVersion()     { return SELF_VERSION; }
  function GetDate()        { return "2026-02-28"; }
  function CreateInstance() { return "ProductionBooster"; }
  function GetShortName()   { return "PRDB"; }
  function GetAPIVersion()  { return "14"; }
  function GetURL()         { return ""; }
  function GetSettings() {
    AddSetting({
      name = "increase_threshold", 
      description = "Transport % needed to increase production", 
      min_value = 50, 
      max_value = 100, 
      easy_value = 75, 
      medium_value = 80, 
      hard_value = 85, 
      custom_value = 80, 
      flags = CONFIG_INGAME
    });
    AddSetting({
      name = "decrease_threshold", 
      description = "Transport % below which production decreases", 
      min_value = 0, 
      max_value = 95, 
      easy_value = 65, 
      medium_value = 60, 
      hard_value = 55, 
      custom_value = 60, 
      flags = CONFIG_INGAME
    });
    AddSetting({
      name = "step_size", 
      description = "Production level change per adjustment", 
      min_value = 1, 
      max_value = 16, 
      easy_value = 8, 
      medium_value = 4, 
      hard_value = 2, 
      custom_value = 4, 
      flags = CONFIG_INGAME
    });
    AddSetting({
      name = "min_level", 
      description = "Minimum production level", 
      min_value = 4, 
      max_value = 64, 
      easy_value = 8, 
      medium_value = 8, 
      hard_value = 4, 
      custom_value = 8, 
      flags = CONFIG_INGAME
    });
    AddSetting({
      name = "max_level", 
      description = "Maximum production level", 
      min_value = 4, 
      max_value = 128, 
      easy_value = 128, 
      medium_value = 128, 
      hard_value = 96, 
      custom_value = 128, 
      flags = CONFIG_INGAME
    });
    AddSetting({
      name = "grace_period_months", 
      description = "Grace period months before new industries can decrease production", 
      min_value = 0, 
      max_value = 12, 
      easy_value = 6, 
      medium_value = 3, 
      hard_value = 1, 
      custom_value = 3, 
      flags = CONFIG_INGAME
    });
    AddSetting({
      name = "log_level", 
      description = "Log level (1=error, 2=warning, 3=info, 4=debug)", 
      min_value = 1, 
      max_value = 4, 
      easy_value = 3, 
      medium_value = 3, 
      hard_value = 3, 
      custom_value = 3, 
      flags = CONFIG_INGAME
    });
  }
}
RegisterGS(ProductionBooster());
