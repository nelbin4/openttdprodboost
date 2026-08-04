require("version.nut");

class ProductionBooster extends GSController {

  increase_threshold  = 80;
  decrease_threshold  = 60;
  step_size           = 4;
  min_level           = 8;
  max_level           = 128;
  grace_period_months = 3;
  log_level           = 3;
  batch_divisor       = 30;
  invalid_settings    = false;
  is_wallclock        = false;

  static SLEEP_TICKS      = 74;          // wake up ~daily instead of monthly
  static DAYS_PER_MONTH   = 30;
  static OPS_RESERVE      = 2000;
  static OPS_CHECK_STRIDE = 5;           // only poll GetOpsTillSuspend every N industries in a batch
  static OWN_FLAGS        = GSIndustry.INDCTL_NO_PRODUCTION_INCREASE |
                            GSIndustry.INDCTL_NO_PRODUCTION_DECREASE  |
                            GSIndustry.INDCTL_NO_CLOSURE               |
                            GSIndustry.INDCTL_EXTERNAL_PROD_LEVEL;

  // id_set: id -> true, tracks which industries we manage.
  // id_cargo_ids: id -> array of freight cargo IDs (plain ints -- safe to
  // persist, unlike a GSList). Fetched once at registration; an industry's
  // producible cargo types don't change after construction, so this avoids
  // re-running GSCargoList_IndustryProducing + Valuate on every pass.
  id_set       = null;
  id_cargo_ids = null;
  id_can_inc   = null;

  // Round-robin batching state (not persisted; rebuilt on Load/Start)
  scan_ids = null;
  scan_pos = 0;

  constructor() {
    id_set       = {};
    id_cargo_ids = {};
    id_can_inc   = {};
    scan_ids     = null;
    scan_pos     = 0;
  }

  static function IsRawIndustryFilter(industry_id) {
    return GSIndustryType.IsRawIndustry(GSIndustry.GetIndustryType(industry_id));
  }

  // Only used when we don't yet have a cached cargo-id array: at first
  // registration, or if a cache turns out empty and needs a re-check.
  static function FreightCargoIds(industry_id) {
    local cl = GSCargoList_IndustryProducing(industry_id);
    cl.Valuate(GSCargo.IsFreight);
    cl.KeepValue(1);
    local ids = [];
    foreach (cargo_id, _ in cl) ids.push(cargo_id);
    return ids;
  }

  function RegisterIndustry(id, cargo_ids) {
    this.id_set[id]       <- true;
    this.id_cargo_ids[id] <- cargo_ids;
    this.id_can_inc[id]   <- GSIndustryType.ProductionCanIncrease(GSIndustry.GetIndustryType(id));
    this.scan_ids = null; // force scan-order rebuild so new industry gets picked up
  }

  function UnregisterIndustry(id) {
    if (GSIndustry.IsValidIndustry(id)) {
      GSIndustry.SetControlFlags(id, 0);
    }
    delete this.id_set[id];
    delete this.id_cargo_ids[id];
    delete this.id_can_inc[id];
    this.scan_ids = null; // force scan-order rebuild so stale id is dropped
  }

  function ApplyOwnFlagsBatch() {
    local _mode = GSAsyncMode(true);
    foreach (id, _ in this.id_set) {
      GSIndustry.SetControlFlags(id, ProductionBooster.OWN_FLAGS);
    }
  }

  function PurgeStalledIndustries() {
    local stale = [];
    foreach (id, _ in this.id_set) {
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
    this.batch_divisor       = max(GSController.GetSetting("batch_divisor"), 1);

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

  // True if a message at this level would actually be emitted. Lets callers
  // skip building an expensive log string when it would just be discarded.
  function ShouldLog(level) {
    return level <= this.log_level;
  }

  // Loops (instead of a single Sleep(1)) until enough ops headroom is back,
  // so we don't risk stalling under sustained low CPU allowance.
  function ThrottleIfLow() {
    while (this.GetOpsTillSuspend() < ProductionBooster.OPS_RESERVE) {
      this.Sleep(1);
    }
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
             "grace=" + this.grace_period_months + "mo " +
             "batch_divisor=" + this.batch_divisor);

    foreach (id, _ in GSIndustryList(ProductionBooster.IsRawIndustryFilter)) {
      if (id in this.id_set) {
        this.id_can_inc[id] = GSIndustryType.ProductionCanIncrease(GSIndustry.GetIndustryType(id));
        continue;
      }
      local cargo_ids = ProductionBooster.FreightCargoIds(id);
      if (cargo_ids.len() == 0) {
        if (this.ShouldLog(4)) this.Log(4, "Seed skip: " + GSIndustry.GetName(id) + " (ID:" + id + ")");
        continue;
      }
      this.RegisterIndustry(id, cargo_ids);
    }

    this.PurgeStalledIndustries();
    this.ApplyOwnFlagsBatch();
    this.scan_ids = null; // fresh scan order after initial seeding
    this.Log(3, "Tracking " + this.id_set.len() + " primary industries.");

    while (true) {
      this.Sleep(ProductionBooster.SLEEP_TICKS);
      this.ProcessIndustriesBatch();
    }
  }

  function DrainEvents() {
    while (GSEventController.IsEventWaiting()) {
      local ev = GSEventController.GetNextEvent();
      local et = ev.GetEventType();

      if (et == GSEvent.ET_INDUSTRY_OPEN) {
        local id = GSEventIndustryOpen.Convert(ev).GetIndustryID();
        if (id in this.id_set) continue;
        if (!GSIndustryType.IsRawIndustry(GSIndustry.GetIndustryType(id))) continue;
        local cargo_ids = ProductionBooster.FreightCargoIds(id);
        if (cargo_ids.len() == 0) continue;
        this.RegisterIndustry(id, cargo_ids);
        GSIndustry.SetControlFlags(id, ProductionBooster.OWN_FLAGS);
        this.Log(3, "New industry: " + GSIndustry.GetName(id) +
                 " (ID:" + id + ") level=" + GSIndustry.GetProductionLevel(id));
      } else if (et == GSEvent.ET_INDUSTRY_CLOSE) {
        local id = GSEventIndustryClose.Convert(ev).GetIndustryID();
        if (!(id in this.id_set)) continue;
        this.UnregisterIndustry(id);
        if (this.ShouldLog(4)) this.Log(4, "Industry closed: ID:" + id);
      }
    }
  }

  function AvgTransportPct(id, cargo_ids) {
    local total = 0;
    local count = 0;
    foreach (cargo_id in cargo_ids) {
      if (GSIndustry.GetLastMonthProduction(id, cargo_id) <= 0) continue;
      total += GSIndustry.GetLastMonthTransportedPercentage(id, cargo_id);
      count++;
    }
    return count > 0 ? total / count : -1;
  }

  // Processes one industry using its cached cargo-id array -- no
  // GSCargoList/Valuate call on the common path.
  function ProcessOneIndustry(id, cur_date, cur_year) {
    if (!GSIndustry.IsValidIndustry(id)) return;
    if (this.IsDormant(id, cur_year)) return;

    local cargo_ids = this.id_cargo_ids[id];
    if (cargo_ids.len() == 0) {
      // Rare: industry existed but had no freight cargo yet when registered.
      // Re-check occasionally rather than every pass.
      cargo_ids = ProductionBooster.FreightCargoIds(id);
      if (cargo_ids.len() == 0) {
        if (this.ShouldLog(4)) this.Log(4, "Cargo not ready: " + GSIndustry.GetName(id) + " (ID:" + id + ")");
        return;
      }
      this.id_cargo_ids[id] = cargo_ids;
    }

    if (GSIndustry.GetAmountOfStationsAround(id) == 0) return;

    local avg_pct = this.AvgTransportPct(id, cargo_ids);
    if (avg_pct < 0) return;

    local current_level = GSIndustry.GetProductionLevel(id);
    local new_level     = current_level;

    if (avg_pct >= this.increase_threshold && this.id_can_inc[id]) {
      new_level = min(current_level + this.step_size, this.max_level);
    } else if (avg_pct < this.decrease_threshold && !this.IsInGrace(id, cur_date)) {
      new_level = max(current_level - this.step_size, this.min_level);
    }

    if (new_level == current_level) return;

    if (GSIndustry.SetProductionLevel(id, new_level, false, null)) {
      local delta = new_level - current_level;
      this.Log(3, GSIndustry.GetName(id) + " (ID:" + id + ") " +
               (delta > 0 ? "+" : "") + delta + " => " + new_level + " (" + avg_pct + "%)");
    } else {
      this.Log(2, "SetProductionLevel(" + new_level + ") failed for ID:" + id +
               " - industry may have closed mid-tick.");
    }
  }

  // Round-robin: only walk a slice of tracked industries per wake-up,
  // so CPU cost per tick stays flat regardless of map size. A full
  // pass over all industries still completes roughly once a month
  // (SLEEP_TICKS * batch_divisor ~= old monthly cadence). Higher
  // batch_divisor = lighter per-tick CPU but slower reaction time.
  function ProcessIndustriesBatch() {
    this.ReadSettings();
    this.DrainEvents();

    if (this.invalid_settings) return;
    if (this.id_set.len() == 0) return;

    if (this.scan_ids == null || this.scan_pos >= this.scan_ids.len()) {
      this.scan_ids = [];
      foreach (id, _ in this.id_set) this.scan_ids.push(id);
      this.scan_pos = 0;
      if (this.scan_ids.len() == 0) return;
    }

    local batch_size = max(1, this.scan_ids.len() / this.batch_divisor);
    local end = min(this.scan_pos + batch_size, this.scan_ids.len());

    local cur_date = GSDate.GetCurrentDate();
    local cur_year = GSDate.GetYear(cur_date);

    // Async mode avoids blocking on each SetProductionLevel command's
    // result, mirroring what ApplyOwnFlagsBatch already does for flags.
    local _mode = GSAsyncMode(true);

    local checked_since_throttle = 0;
    for (local i = this.scan_pos; i < end; i++) {
      if (checked_since_throttle == 0) this.ThrottleIfLow();
      checked_since_throttle = (checked_since_throttle + 1) % ProductionBooster.OPS_CHECK_STRIDE;

      local id = this.scan_ids[i];
      if (!(id in this.id_set)) continue; // may have been unregistered mid-batch
      this.ProcessOneIndustry(id, cur_date, cur_year);
    }

    this.scan_pos = end;
  }

  function Log(level, message) {
    if (level > this.log_level) return;
    if      (level == 1) GSLog.Error(message);
    else if (level == 2) GSLog.Warning(message);
    else                 GSLog.Info(message);
  }

  // Only plain data goes into the savegame: id_set (bool), id_cargo_ids
  // (arrays of ints), id_can_inc (bool). No GSList objects, which
  // OpenTTD's GS save system can't reliably round-trip.
  function Save() {
    return {
      id_set       = this.id_set,
      id_cargo_ids = this.id_cargo_ids,
      id_can_inc   = this.id_can_inc
    };
  }

  function RestoreTable(data, key, target) {
    if (!(key in data) || typeof data[key] != "table") return;
    foreach (id, val in data[key]) {
      if (typeof id == "integer") target[id] <- val;
    }
  }

  function Load(version, data) {
    // "id_set" is the current key; "id_cargo" is accepted for one version
    // as a migration path from saves made with the old GSList-caching format.
    if ("id_set" in data) {
      this.RestoreTable(data, "id_set", this.id_set);
    } else if ("id_cargo" in data) {
      this.RestoreTable(data, "id_cargo", this.id_set);
      foreach (id, _ in this.id_set) this.id_set[id] = true;
    }

    if ("id_cargo_ids" in data) {
      this.RestoreTable(data, "id_cargo_ids", this.id_cargo_ids);
    }
    // Any tracked industry missing a cargo-id array (e.g. migrating from a
    // save that never had this cache) gets an empty one; ProcessOneIndustry
    // will re-fetch and populate it the first time it's processed.
    foreach (id, _ in this.id_set) {
      if (!(id in this.id_cargo_ids)) this.id_cargo_ids[id] <- [];
    }

    this.RestoreTable(data, "id_can_inc", this.id_can_inc);
    foreach (id, _ in this.id_set) {
      if (!(id in this.id_can_inc)) this.id_can_inc[id] <- false;
    }

    this.scan_ids = null;
    this.scan_pos = 0;
  }
}
