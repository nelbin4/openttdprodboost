require("version.nut");

class ProductionBooster extends GSInfo {
  function GetAuthor()      { return "Nelbin"; }
  function GetName()        { return "Production Booster"; }
  function GetDescription() { return "Primary industry production increases if 80% of goods are transported; decreases if below 60%."; }
  function GetVersion()     { return SELF_VERSION; }
  function GetDate()        { return "2025-05-11"; }
  function CreateInstance() { return "ProductionBooster"; }
  function GetShortName()   { return "PRDB"; }
  function GetAPIVersion()  { return "14"; }
  function GetURL()         { return ""; }
  function GetSettings() {
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
