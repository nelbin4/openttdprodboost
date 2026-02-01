// main.nut
require("version.nut");
class ProductionBooster extends GSController {
  increase_threshold = 80;
  decrease_threshold = 60;
  step_size = 4;
  min_level = 8;
  max_level = 128;
  grace_period_months = 3;
  static WAIT_TICKS = 74; // Approximate number of ticks per in-game day
  industry_states = null;
  industry_birth_dates = null;
  log_level = 3;
  
  constructor() {
    this.industry_states = {};
    this.industry_birth_dates = {};
  }
  
  function Start() {
    this.log_level = GSController.GetSetting("log_level");
    this.increase_threshold = GSController.GetSetting("increase_threshold");
    this.decrease_threshold = GSController.GetSetting("decrease_threshold");
    this.step_size = GSController.GetSetting("step_size");
    this.min_level = GSController.GetSetting("min_level");
    this.max_level = GSController.GetSetting("max_level");
    this.grace_period_months = GSController.GetSetting("grace_period_months");
    
    // Validate settings
    if (this.increase_threshold <= this.decrease_threshold) {
      this.Log(2, "WARNING: Increase threshold (" + this.increase_threshold + "%) must be greater than decrease threshold (" + this.decrease_threshold + "%). Production changes may not work correctly!");
    }
    
    local version = GSController.GetVersion();
    this.Log(3, "Production Booster started. Version: " + version);
    this.Log(3, "Settings - Increase: " + this.increase_threshold + "%, Decrease: " + this.decrease_threshold + "%, Step: " + this.step_size + ", Range: " + this.min_level + "-" + this.max_level);
    this.Log(3, "Grace period: " + this.grace_period_months + " months");
    
    local current_date = GSDate.GetCurrentDate();
    local industry_list = GSIndustryList();
    foreach (industry_id, _ in industry_list) {
      if (GSIndustry.IsValidIndustry(industry_id) && this.IsPrimaryIndustry(industry_id)) {
        // FIX: Use actual production level instead of hardcoded MIN_LEVEL
        this.industry_states[industry_id] <- GSIndustry.GetProductionLevel(industry_id);
        this.industry_birth_dates[industry_id] <- current_date;
      }
    }
    
    local last_month = GSDate.GetMonth(current_date);
    while (true) {
      this.Sleep(WAIT_TICKS);
      local current_date = GSDate.GetCurrentDate();
      local current_month = GSDate.GetMonth(current_date);
      if (current_month != last_month) {
        last_month = current_month;
        this.ProcessIndustries();
      }
    }
  }
  
  function ProcessIndustries() {
    local current_date = GSDate.GetCurrentDate();
    
    // First, discover any new industries and add them to tracking
    local industry_list = GSIndustryList();
    foreach (industry_id, _ in industry_list) {
      if (!GSIndustry.IsValidIndustry(industry_id)) continue;
      if (!this.IsPrimaryIndustry(industry_id)) continue;
      
      // Add new industries to the tracking table
      if (!(industry_id in this.industry_states)) {
        local prod_level = GSIndustry.GetProductionLevel(industry_id);
        this.industry_states[industry_id] <- prod_level;
        this.industry_birth_dates[industry_id] <- current_date;
        local name = GSIndustry.GetName(industry_id);
        this.Log(3, "New industry discovered: " + name + " (ID: " + industry_id + "), production level: " + prod_level);
      }
    }
    
    // FIX: Remove closed/invalid industries from tracking
    local industries_to_remove = [];
    foreach (industry_id, _ in this.industry_states) {
      if (!GSIndustry.IsValidIndustry(industry_id)) {
        industries_to_remove.append(industry_id);
      }
    }
    foreach (industry_id in industries_to_remove) {
      delete this.industry_states[industry_id];
      delete this.industry_birth_dates[industry_id];
      this.Log(3, "Industry " + industry_id + " removed (closed/demolished)");
    }
    
    // Now process all tracked industries
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
        // FIX: Better precision with integer math (multiply by 100 before dividing)
        total_percentage += (transported * 100) / produced;
        cargo_count++;
      }
      
      if (cargo_count == 0) continue;
      
      local avg_percentage = total_percentage / cargo_count;
      local current_level = GSIndustry.GetProductionLevel(industry_id);
      local new_level = current_level;
      
      // Check if industry is within grace period
      local age_in_days = GSDate.GetCurrentDate() - this.industry_birth_dates[industry_id];
      local age_in_months = age_in_days / 30; // Approximate months
      local in_grace_period = age_in_months < this.grace_period_months;
      
      if (avg_percentage >= this.increase_threshold) {
        new_level = min(current_level + this.step_size, this.max_level);
      } else if (avg_percentage < this.decrease_threshold && !in_grace_period) {
        // Only decrease if not in grace period
        new_level = max(current_level - this.step_size, this.min_level);
      }
      
      if (new_level != current_level) {
        local flags = GSIndustry.GetControlFlags(industry_id);
        flags = flags & ~GSIndustry.INDCTL_NO_PRODUCTION_INCREASE;
        GSIndustry.SetControlFlags(industry_id, flags);
        
        if (GSIndustry.SetProductionLevel(industry_id, new_level, false, null)) {
          this.industry_states[industry_id] = new_level;
          local name = GSIndustry.GetName(industry_id);
          local direction = (new_level > current_level) ? "increased" : "decreased";
          this.Log(3, name + " (ID: " + industry_id + ") " + direction + ": " + current_level + " -> " + new_level + " (transport: " + avg_percentage + "%)");
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
    data.industry_birth_dates <- this.industry_birth_dates;
    data.increase_threshold <- this.increase_threshold;
    data.decrease_threshold <- this.decrease_threshold;
    data.step_size <- this.step_size;
    data.min_level <- this.min_level;
    data.max_level <- this.max_level;
    data.grace_period_months <- this.grace_period_months;
    data.log_level <- this.log_level;
    return data;
  }
  
  function Load(version, data) {
    this.industry_states = data.industry_states;
    
    // Handle industry_birth_dates (might not exist in old saves)
    if ("industry_birth_dates" in data) {
      this.industry_birth_dates = data.industry_birth_dates;
    } else {
      // Initialize with current date for old saves
      this.industry_birth_dates = {};
      local current_date = GSDate.GetCurrentDate();
      foreach (industry_id, _ in this.industry_states) {
        this.industry_birth_dates[industry_id] <- current_date;
      }
    }
    
    if ("increase_threshold" in data) {
      this.increase_threshold = data.increase_threshold;
    }
    if ("decrease_threshold" in data) {
      this.decrease_threshold = data.decrease_threshold;
    }
    if ("step_size" in data) {
      this.step_size = data.step_size;
    }
    if ("min_level" in data) {
      this.min_level = data.min_level;
    }
    if ("max_level" in data) {
      this.max_level = data.max_level;
    }
    if ("grace_period_months" in data) {
      this.grace_period_months = data.grace_period_months;
    }
    if ("log_level" in data) {
      this.log_level = data.log_level;
    }
  }
}

function ProductionBooster::GetVersion() {
  return SELF_VERSION;
}
