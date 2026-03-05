require("version.nut");

class ProductionBooster extends GSController {

  increase_threshold  = 80;
  decrease_threshold  = 60;
  step_size           = 4;
  min_level           = 8;
  max_level           = 128;
  grace_period_months = 3;
  log_level           = 3;
  invalid_settings    = false;
  is_wallclock        = false;

  static SLEEP_TICKS    = 74 * 30;
  static DAYS_PER_MONTH = 30;
  static OPS_RESERVE    = 2000;
  static OWN_FLAGS      = GSIndustry.INDCTL_NO_PRODUCTION_INCREASE |
                          GSIndustry.INDCTL_NO_PRODUCTION_DECREASE  |
                          GSIndustry.INDCTL_NO_CLOSURE               |
                          GSIndustry.INDCTL_EXTERNAL_PROD_LEVEL;

  id_cargo   = null;
  id_can_inc = null;

  constructor() {
    id_cargo   = {};
    id_can_inc = {};
  }

  static function IsRawIndustryFilter(industry_id) {
    return GSIndustryType.IsRawIndustry(GSIndustry.GetIndustryType(industry_id));
  }

  static function FreightCargoList(industry_id) {
    local cl = GSCargoList_IndustryProducing(industry_id);
    cl.Valuate(GSCargo.IsFreight);
    cl.KeepValue(1);
    return cl;
  }

  function RegisterIndustry(id, cargo_list) {
    this.id_cargo[id]   <- cargo_list;
    this.id_can_inc[id] <- GSIndustryType.ProductionCanIncrease(GSIndustry.GetIndustryType(id));
  }

  function UnregisterIndustry(id) {
    if (GSIndustry.IsValidIndustry(id)) {
      GSIndustry.SetControlFlags(id, 0);
    }
    delete this.id_cargo[id];
    delete this.id_can_inc[id];
  }

  function ApplyOwnFlagsBatch() {
    local _mode = GSAsyncMode(true);
    foreach (id, _ in this.id_cargo) {
      GSIndustry.SetControlFlags(id, ProductionBooster.OWN_FLAGS);
    }
  }

  function PurgeStalledIndustries() {
    local stale = [];
    foreach (id, _ in this.id_cargo) {
      if (!GSIndustry.IsValidIndustry(id)) stale.push(id);
    }
    foreach (id in stale) this.UnregisterIndustry(id);
  }

  function IsDormant(id, cur_year) {
    if (this.is_wallclock) return false;
    local last_year = GSIndustry.GetLastProductionYear(id);
    return (last_year > 0) && ((cur_year - last_year) >= 2);
  }

  function IsInGrace(id, cur_date) {
    if (this.is_wallclock) return false;
    local built = GSIndustry.GetConstructionDate(id);
    return GSDate.IsValidDate(built) &&
           (cur_date - built) < (this.grace_period_months * ProductionBooster.DAYS_PER_MONTH);
  }

  function ReadSettings() {
    this.log_level           = GSController.GetSetting("log_level");
    this.increase_threshold  = GSController.GetSetting("increase_threshold");
    this.decrease_threshold  = GSController.GetSetting("decrease_threshold");
    this.step_size           = GSController.GetSetting("step_size");
    this.min_level           = max(GSController.GetSetting("min_level"), 4);
    this.max_level           = min(GSController.GetSetting("max_level"), 128);
    this.grace_period_months = GSController.GetSetting("grace_period_months");

    local invalid = this.increase_threshold <= this.decrease_threshold;
    if (invalid != this.invalid_settings) {
      this.Log(2, invalid
        ? ("Settings invalid: increase_threshold (" + this.increase_threshold +
           "%) must be > decrease_threshold (" + this.decrease_threshold +
           "%). Production changes suspended.")
        : ("Settings valid: production adjustment resumed (" +
           this.increase_threshold + "% / " + this.decrease_threshold + "%)."));
    }
    this.invalid_settings = invalid;
  }

  function Start() {
    this.ReadSettings();
    this.is_wallclock = GSGameSettings.IsValid("economy.timekeeping_units") &&
                        GSGameSettings.GetValue("economy.timekeeping_units") != 0;

    this.Log(3, "Production Booster v" + SELF_VERSION + " started. " +
             "Climate=" + ["Temperate", "Arctic", "Tropic", "Toyland"][GSGame.GetLandscape()] + " " +
             (GSGame.IsMultiplayer() ? "MP " : "SP ") +
             "increase=" + this.increase_threshold + "% " +
             "decrease=" + this.decrease_threshold + "% " +
             "step=" + this.step_size + " " +
             "range=" + this.min_level + "-" + this.max_level + " " +
             "grace=" + this.grace_period_months + "mo");

    foreach (id, _ in GSIndustryList(ProductionBooster.IsRawIndustryFilter)) {
      if (id in this.id_cargo) {
        this.id_can_inc[id] = GSIndustryType.ProductionCanIncrease(GSIndustry.GetIndustryType(id));
        continue;
      }
      local cl = ProductionBooster.FreightCargoList(id);
      if (cl.IsEmpty()) {
        this.Log(4, "Seed skip: " + GSIndustry.GetName(id) + " (ID:" + id + ")");
        continue;
      }
      this.RegisterIndustry(id, cl);
    }

    this.PurgeStalledIndustries();
    this.ApplyOwnFlagsBatch();
    this.Log(3, "Tracking " + this.id_cargo.len() + " primary industries.");

    while (true) {
      this.Sleep(ProductionBooster.SLEEP_TICKS);
      this.ProcessIndustries();
    }
  }

  function DrainEvents() {
    while (GSEventController.IsEventWaiting()) {
      local ev = GSEventController.GetNextEvent();
      local et = ev.GetEventType();

      if (et == GSEvent.ET_INDUSTRY_OPEN) {
        local id = GSEventIndustryOpen.Convert(ev).GetIndustryID();
        if (id in this.id_cargo) continue;
        if (!GSIndustryType.IsRawIndustry(GSIndustry.GetIndustryType(id))) continue;
        local cl = ProductionBooster.FreightCargoList(id);
        if (cl.IsEmpty()) continue;
        this.RegisterIndustry(id, cl);
        GSIndustry.SetControlFlags(id, ProductionBooster.OWN_FLAGS);
        this.Log(3, "New industry: " + GSIndustry.GetName(id) +
                 " (ID:" + id + ") level=" + GSIndustry.GetProductionLevel(id));
      } else if (et == GSEvent.ET_INDUSTRY_CLOSE) {
        local id = GSEventIndustryClose.Convert(ev).GetIndustryID();
        if (!(id in this.id_cargo)) continue;
        this.UnregisterIndustry(id);
        this.Log(4, "Industry closed: ID:" + id);
      }
    }
  }

  function AvgTransportPct(id, cargo_types) {
    local total = 0;
    local count = 0;
    foreach (cargo_id, _ in cargo_types) {
      if (GSIndustry.GetLastMonthProduction(id, cargo_id) <= 0) continue;
      total += GSIndustry.GetLastMonthTransportedPercentage(id, cargo_id);
      count++;
    }
    return count > 0 ? total / count : -1;
  }

  function ProcessIndustries() {
    this.ReadSettings();
    this.DrainEvents();

    if (this.invalid_settings) return;

    local cur_date = GSDate.GetCurrentDate();
    local cur_year = GSDate.GetYear(cur_date);

    foreach (id, cargo_types in this.id_cargo) {
      if (this.GetOpsTillSuspend() < ProductionBooster.OPS_RESERVE) this.Sleep(1);

      if (!GSIndustry.IsValidIndustry(id)) continue;
      if (this.IsDormant(id, cur_year)) continue;

      if (cargo_types.IsEmpty()) {
        cargo_types = ProductionBooster.FreightCargoList(id);
        if (cargo_types.IsEmpty()) {
          this.Log(4, "Cargo not ready: " + GSIndustry.GetName(id) + " (ID:" + id + ")");
          continue;
        }
        this.id_cargo[id]   = cargo_types;
        this.id_can_inc[id] = GSIndustryType.ProductionCanIncrease(GSIndustry.GetIndustryType(id));
      }

      if (GSIndustry.GetAmountOfStationsAround(id) == 0) continue;

      local avg_pct = this.AvgTransportPct(id, cargo_types);
      if (avg_pct < 0) continue;

      local current_level = GSIndustry.GetProductionLevel(id);
      local new_level     = current_level;

      if (avg_pct >= this.increase_threshold && this.id_can_inc[id]) {
        new_level = min(current_level + this.step_size, this.max_level);
      } else if (avg_pct < this.decrease_threshold && !this.IsInGrace(id, cur_date)) {
        new_level = max(current_level - this.step_size, this.min_level);
      }

      if (new_level == current_level) continue;

      if (GSIndustry.SetProductionLevel(id, new_level, false, null)) {
        local delta = new_level - current_level;
        this.Log(3, GSIndustry.GetName(id) + " (ID:" + id + ") " +
                 (delta > 0 ? "+" : "") + delta + " => " + new_level + " (" + avg_pct + "%)");
      } else {
        this.Log(2, "SetProductionLevel(" + new_level + ") failed for ID:" + id +
                 " - industry may have closed mid-tick.");
      }
    }
  }

  function Log(level, message) {
    if (level > this.log_level) return;
    if      (level == 1) GSLog.Error(message);
    else if (level == 2) GSLog.Warning(message);
    else                 GSLog.Info(message);
  }

  function Save() {
    return { id_cargo = this.id_cargo, id_can_inc = this.id_can_inc };
  }

  function RestoreTable(data, key, target) {
    if (!(key in data) || typeof data[key] != "table") return;
    foreach (id, val in data[key]) {
      if (typeof id == "integer") target[id] <- val;
    }
  }

  function Load(version, data) {
    this.RestoreTable(data, "id_cargo",   this.id_cargo);
    this.RestoreTable(data, "id_can_inc", this.id_can_inc);
    foreach (id, _ in this.id_cargo) {
      if (!(id in this.id_can_inc)) this.id_can_inc[id] <- false;
    }
  }
}
