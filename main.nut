require("version.nut");

class ProductionBooster extends GSController {
  increase_threshold  = 70;
  decrease_threshold  = 50;
  step_size           = 4;
  min_level           = 8;
  max_level           = 128;
  grace_period_months = 3;
  log_level           = 3;
  invalid_settings    = false;
  loop_count          = 0;

  static SLEEP_TICKS = 74 * 30;

  industry_tracked = null;
  id_cargo         = null;
  raw_types        = null;

  constructor() {
    industry_tracked = {};
    id_cargo         = {};
    raw_types        = {};
  }

  function ReadSettings() {
    this.log_level           = GSController.GetSetting("log_level");
    this.increase_threshold  = GSController.GetSetting("increase_threshold");
    this.decrease_threshold  = GSController.GetSetting("decrease_threshold");
    this.step_size           = GSController.GetSetting("step_size");
    this.min_level           = GSController.GetSetting("min_level");
    this.max_level           = GSController.GetSetting("max_level");
    this.grace_period_months = GSController.GetSetting("grace_period_months");

    local invalid = this.increase_threshold <= this.decrease_threshold;
    if (invalid && !this.invalid_settings) {
      this.Log(2, "increase_threshold (" + this.increase_threshold +
               "%) must be > decrease_threshold (" + this.decrease_threshold + "%)");
    }
    this.invalid_settings = invalid;
  }

  function FreightCargoList(industry_id) {
    local cl = GSCargoList_IndustryProducing(industry_id);
    cl.Valuate(GSCargo.IsFreight);
    cl.KeepValue(1);
    return cl;
  }

  function Start() {
    this.ReadSettings();

    this.Log(3, "Production Booster v" + SELF_VERSION + " started. " +
             "increase=" + this.increase_threshold + "% " +
             "decrease=" + this.decrease_threshold + "% " +
             "step=" + this.step_size + " " +
             "range=" + this.min_level + "-" + this.max_level + " " +
             "grace=" + this.grace_period_months + "mo");

    local type_list = GSIndustryTypeList();
    type_list.Valuate(GSIndustryType.IsRawIndustry);
    type_list.KeepValue(1);
    foreach (t, _ in type_list) this.raw_types[t] <- true;

    foreach (id, _ in GSIndustryList()) {
      if (!(GSIndustry.GetIndustryType(id) in this.raw_types)) continue;
      local cl = this.FreightCargoList(id);
      if (cl.IsEmpty()) continue;
      this.id_cargo[id] <- cl;
      if (!(id in this.industry_tracked)) this.industry_tracked[id] <- -1;
    }

    local clean = {};
    foreach (id, v in this.industry_tracked) {
      if (id in this.id_cargo) clean[id] <- v;
    }
    this.industry_tracked = clean;

    this.Log(3, "Tracking " + this.industry_tracked.len() + " primary industries.");

    while (true) {
      this.Sleep(SLEEP_TICKS);
      this.ProcessIndustries();
    }
  }

  function ProcessIndustries() {
    this.ReadSettings();
    if (this.invalid_settings) { this.loop_count++; return; }

    local inc_thr   = this.increase_threshold;
    local dec_thr   = this.decrease_threshold;
    local grace     = this.grace_period_months;
    local lcount    = this.loop_count;
    local max_lvl   = this.max_level;
    local step      = this.step_size;
    local clamp_min = max(this.min_level, 4);
    local do_log    = this.log_level >= 3;
    local tracked   = this.industry_tracked;
    local ic        = this.id_cargo;
    local rt        = this.raw_types;

    while (GSEventController.IsEventWaiting()) {
      local ev = GSEventController.GetNextEvent();
      local et = ev.GetEventType();

      if (et == GSEvent.ET_INDUSTRY_OPEN) {
        local id = GSEventIndustryOpen.Convert(ev).GetIndustryID();
        if (GSIndustry.GetIndustryType(id) in rt) {
          local cl = this.FreightCargoList(id);
          if (!cl.IsEmpty()) {
            ic[id]      <- cl;
            tracked[id] <- lcount;
            if (do_log) {
              this.Log(3, "New industry: " + GSIndustry.GetName(id) +
                       " (ID:" + id + ") level=" + GSIndustry.GetProductionLevel(id));
            }
          }
        }
      } else if (et == GSEvent.ET_INDUSTRY_CLOSE) {
        local id = GSEventIndustryClose.Convert(ev).GetIndustryID();
        if (id in tracked) {
          delete tracked[id];
          delete ic[id];
        }
      }
    }

    foreach (id, birth_loop in tracked) {
      local cargo_types = ic[id];
      local total_pct   = 0;
      local cargo_count = 0;
      foreach (cargo_id, _ in cargo_types) {
        if (GSIndustry.GetLastMonthProduction(id, cargo_id) <= 0) continue;
        total_pct += GSIndustry.GetLastMonthTransportedPercentage(id, cargo_id);
        cargo_count++;
      }
      if (cargo_count == 0) continue;

      local avg_pct       = total_pct / cargo_count;
      local current_level = GSIndustry.GetProductionLevel(id);
      local new_level     = current_level;

      if (avg_pct >= inc_thr) {
        new_level = min(current_level + step, max_lvl);
      } else if (avg_pct < dec_thr &&
                 (birth_loop < 0 || (lcount - birth_loop) >= grace)) {
        new_level = max(current_level - step, clamp_min);
      }

      if (new_level == current_level) continue;

      if (GSIndustry.SetProductionLevel(id, new_level, false, null)) {
        if (do_log) {
          this.Log(3, GSIndustry.GetName(id) + " (ID:" + id + ") " +
                   ((new_level > current_level) ? "+" : "") +
                   (new_level - current_level) +
                   " => " + new_level + " (" + avg_pct + "%)");
        }
      }
    }

    this.loop_count++;
  }

  function Log(level, message) {
    if (level > this.log_level) return;
    if      (level == 1) GSLog.Error(message);
    else if (level == 2) GSLog.Warning(message);
    else if (level == 3) GSLog.Info(message);
    else                 GSLog.Debug(message);
  }

  function Save() {
    return {
      industry_tracked = this.industry_tracked,
      loop_count       = this.loop_count
    };
  }

  function Load(version, data) {
    if ("loop_count" in data) this.loop_count = data.loop_count;
    if ("industry_tracked" in data) {
      foreach (id, val in data.industry_tracked) {
        this.industry_tracked[id] <- (typeof val == "bool") ? -1 : val;
      }
    }
  }
}
