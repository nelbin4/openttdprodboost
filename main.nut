// main.nut
require("version.nut");

class ProductionBooster extends GSController {
  static INCREASE_THRESHOLD = 80;
  static DECREASE_THRESHOLD = 60;
  static STEP_SIZE = 8;
  static MIN_LEVEL = 4;
  static MAX_LEVEL = 128;
  static WAIT_TICKS = 74; // Approximate number of ticks per in-game day

  industry_states = null;
  log_level = 3;

  constructor() {
    this.industry_states = {};
  }

  function Start() {
    this.log_level = GSController.GetSetting("log_level");
    local version = GSController.GetVersion();
    this.Log(3, "Production Booster started. Version: " + version);

    local industry_list = GSIndustryList();
    foreach (industry_id, _ in industry_list) {
      if (GSIndustry.IsValidIndustry(industry_id) && this.IsPrimaryIndustry(industry_id)) {
        this.industry_states[industry_id] <- MIN_LEVEL;
      }
    }

    local last_month = GSDate.GetMonth(GSDate.GetCurrentDate());

    while (true) {
      this.Sleep(WAIT_TICKS); // Sleep for the defined number of ticks
      local current_date = GSDate.GetCurrentDate();
      local current_month = GSDate.GetMonth(current_date);

      if (current_month != last_month) {
        last_month = current_month;
        this.ProcessIndustries();
      }
    }
  }

  function ProcessIndustries() {
    foreach (industry_id, _ in this.industry_states) {
      if (!GSIndustry.IsValidIndustry(industry_id)) continue;
      if (!this.IsPrimaryIndustry(industry_id)) continue;

      local cargo_list = this.GetProducedCargo(industry_id);
      if (cargo_list.len() == 0) continue;

      local total_percentage = 0;
      local cargo_count = 0;

      foreach (cargo_type in cargo_list) {
        local transported = GSIndustry.GetLastMonthTransported(industry_id, cargo_type);
        local produced = GSIndustry.GetLastMonthProduction(industry_id, cargo_type);
        if (produced == 0) continue;
        total_percentage += (transported * 100) / produced;
        cargo_count++;
      }

      if (cargo_count == 0) continue;
      local avg_percentage = total_percentage / cargo_count;

      local current_level = GSIndustry.GetProductionLevel(industry_id);
      local new_level = current_level;

      if (avg_percentage >= INCREASE_THRESHOLD) {
        new_level = min(current_level + STEP_SIZE, MAX_LEVEL);
      } else if (avg_percentage < DECREASE_THRESHOLD) {
        new_level = max(current_level - STEP_SIZE, MIN_LEVEL);
      }

      if (new_level != current_level) {
        local flags = GSIndustry.GetControlFlags(industry_id);
        flags = flags & ~GSIndustry.INDCTL_NO_PRODUCTION_INCREASE;
        GSIndustry.SetControlFlags(industry_id, flags);

        if (GSIndustry.SetProductionLevel(industry_id, new_level, false, null)) {
          this.industry_states[industry_id] = new_level;
          this.Log(3, "Industry " + industry_id + " -> " + new_level);
        }
      }
    }
  }

  function IsPrimaryIndustry(industry_id) {
    local industry_type = GSIndustry.GetIndustryType(industry_id);
    return GSIndustryType.IsRawIndustry(industry_type);
  }

  function GetProducedCargo(industry_id) {
    local cargo_list = [];
    local cargo_list_obj = GSCargoList();

    foreach (cargo_id, _ in cargo_list_obj) {
      if (GSIndustry.GetLastMonthProduction(industry_id, cargo_id) > 0) {
        cargo_list.append(cargo_id);
      }
    }

    return cargo_list;
  }

  function Log(level, message) {
    if (this.log_level >= level) {
      if (level == 1) GSLog.Error(message);
      else if (level == 2) GSLog.Warning(message);
      else if (level == 3) GSLog.Info(message);
      else if (level == 4) GSLog.Debug(message);
    }
  }

  function Save() {
    local data = {};
    data.industry_states <- this.industry_states;
    return data;
  }

  function Load(version, data) {
    this.industry_states = data.industry_states;
  }
}

function ProductionBooster::GetVersion() {
  return SELF_VERSION;
}
