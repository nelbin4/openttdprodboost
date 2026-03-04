require("version.nut");

class ProductionBooster extends GSInfo {
  function GetAuthor()      { return "nelbin4"; }
  function GetName()        { return "Production Booster"; }
  function GetDescription() { return "Dynamically adjusts primary industry production levels based on cargo transport efficiency. Production increases when transport rates are high and decreases when transport rates are low, encouraging better network coverage."; }
  function GetVersion()     { return SELF_VERSION; }
  function GetDate()        { return "2026-03-05"; }
  function CreateInstance() { return "ProductionBooster"; }
  function GetShortName()   { return "PRDB"; }
  function GetAPIVersion()  { return "15"; }
  function GetURL()         { return "https://github.com/nelbin4/openttdprodboost"; }
  function GetSettings() {
    AddSetting({
      name = "increase_threshold",
      description = "Transport % needed to increase production",
      min_value = 50,
      max_value = 100,
      default_value = 80,
      flags = CONFIG_INGAME
    });
    AddSetting({
      name = "decrease_threshold",
      description = "Transport % below which production decreases",
      min_value = 0,
      max_value = 95,
      default_value = 60,
      flags = CONFIG_INGAME
    });
    AddSetting({
      name = "step_size",
      description = "Production level change per adjustment",
      min_value = 1,
      max_value = 16,
      default_value = 4,
      flags = CONFIG_INGAME
    });
    AddSetting({
      name = "min_level",
      description = "Minimum production level (API hard minimum: 4)",
      min_value = 4,
      max_value = 64,
      default_value = 8,
      flags = CONFIG_INGAME
    });
    AddSetting({
      name = "max_level",
      description = "Maximum production level (API hard maximum: 128)",
      min_value = 4,
      max_value = 128,
      default_value = 128,
      flags = CONFIG_INGAME
    });
    AddSetting({
      name = "grace_period_months",
      description = "Months before a new industry can have production decreased",
      min_value = 0,
      max_value = 12,
      default_value = 3,
      flags = CONFIG_INGAME
    });
    AddSetting({
      name = "log_level",
      description = "Log level (1=error, 2=warning, 3=info, 4=debug)",
      min_value = 1,
      max_value = 4,
      default_value = 3,
      flags = CONFIG_INGAME
    });
  }
}
RegisterGS(ProductionBooster());
