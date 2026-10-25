"""Synthetic test-case generator for the data centre cooling and power expert system.

Every case produced here is SYNTHETIC. Values come from the steady-state
physics in docs/05_engineering_model.md with faults injected into that
physics, followed by a sensor layer (bias, noise, stale or missing data).
Nothing generated here may be presented as a real measurement.

Usage (from the project folder):
    python simulator/dc_sim.py                 # default seed and output paths
    python simulator/dc_sim.py --seed 777 --prefix h --split holdout \
        --out data/holdout_cases.pl --csv data/holdout_cases.csv --truth data/holdout_truth.json

The calibration set (default seed) is the one thresholds were checked against.
The held-out set uses another seed and is only used to report performance.

Only the Python standard library is used. The same seed always gives the
same dataset, which is what makes the results reproducible.
"""

import argparse
import csv
import json
import math
import random

# ---------------------------------------------------------------------------
# Design parameters. Values shared with the knowledge base must match
# kb/components.pl and kb/thresholds.pl.
# ---------------------------------------------------------------------------
RACKS = [f"rack_a0{i}" for i in range(1, 7)]
SERVERS_PER_RACK = 20
CRAH, UPS, BATTERY = "crah_1", "ups_1", "battery_1"

CP_AIR, CP_WATER, RHO_AIR = 1.006, 4.186, 1.2           # kJ/(kg K), kg/m3
P_IDLE, P_MAX = 0.40, 0.90                              # kW per server, Eq. 1
CPU_SHARE = 0.55                                        # CPU part of server power
M_SERVER_NOM = 0.055                                    # kg/s at nominal fan speed
OMEGA_NOM, OMEGA_MAX = 9000.0, 16000.0                  # rpm
R_TH_NOM = 90.0                                         # K/kW, Eq. 8
T_J_MAX = 95.0                                          # degC, throttling limit
F_NOM = 2.6                                             # GHz

V_RATED = 7.0                                           # m3/s at 100 % fan speed
P_FAN_RATED = 5.5                                       # kW, Eq. 23
FAN_MIN, FAN_MAX = 40.0, 100.0                          # % speed limits
AIRFLOW_MARGIN = 1.1                                    # CRAH supplies 10 % over demand
K_FILTER_CLEAN = 100.0 / V_RATED ** 2                   # Pa s2/m6: 100 Pa clean at rated flow
FILTER_SHARE = 0.3                                      # filter share of clean system resistance

T_SETPOINT = 20.0                                       # degC supply-air setpoint
T_CHW_SUPPLY = 10.0                                     # degC chilled-water supply
M_CHW_MAX = 8.0                                         # kg/s at full valve opening
VALVE_RANGEABILITY = 50.0                               # Eq. 34
HA_AIR = 15.0                                           # kW/K air-side conductance
HA_WATER_DESIGN = 10.0                                  # kW/K water-side conductance at design flow
M_CHW_DESIGN = 3.2                                      # kg/s design water flow

T_ROOM = 25.0                                           # degC air outside the containment
DEFICIT_HOT_SHARE = 0.4                                 # share of airflow shortfall drawn from the hot aisle
BETA_TOP_BASE = 0.10                                    # natural recirculation at the top of a sealed rack

V_LN, POWER_FACTOR, BREAKER_A = 230.0, 0.95, 32.0       # rack PDU per phase
PDU_EFF, UPS_EFF_DC, UPS_EFF_BYPASS = 0.985, 0.955, 0.99
N_CELLS, V_CELL_FLOAT, R_CELL_BASE = 240, 2.27, 0.65    # V per cell, mOhm

# Standard deviation of measurement noise, by variable.
# ("abs", sigma) adds absolute noise; ("rel", sigma) is relative noise.
NOISE = {
    "t_inlet_mid": ("abs", 0.15), "t_inlet_top": ("abs", 0.15),
    "t_outlet": ("abs", 0.15), "t_outlet_top": ("abs", 0.15),
    "t_supply_air": ("abs", 0.15), "t_return_air": ("abs", 0.15),
    "t_chw_supply": ("abs", 0.1), "t_chw_return": ("abs", 0.1),
    "fan_speed": ("abs", 0.2), "fan_power": ("rel", 0.01),
    "dp_filter": ("rel", 0.02), "valve_position": ("abs", 0.5),
    "m_chw": ("rel", 0.02), "p_rack": ("rel", 0.01), "cpu_util": ("abs", 0.005),
    "i_branch": ("rel", 0.01), "t_cpu": ("abs", 0.5), "server_fan_rpm": ("rel", 0.01),
    "f_cpu": ("abs", 0.01), "p_ups_in": ("rel", 0.005), "p_ups_out": ("rel", 0.005),
    "v_battery": ("rel", 0.002), "r_cell": ("rel", 0.02), "t_battery": ("abs", 0.2),
}

UNITS = {
    "t_inlet_mid": "degC", "t_inlet_top": "degC", "t_outlet": "degC", "t_outlet_top": "degC",
    "t_supply_air": "degC", "t_return_air": "degC", "t_chw_supply": "degC", "t_chw_return": "degC",
    "fan_speed": "percent", "fan_power": "kW", "dp_filter": "Pa", "valve_position": "percent",
    "m_chw": "kg/s", "p_rack": "kW", "cpu_util": "ratio", "i_branch": "A", "t_cpu": "degC",
    "server_fan_rpm": "rpm", "f_cpu": "GHz", "p_ups_in": "kW", "p_ups_out": "kW",
    "ups_mode": "enum", "v_battery": "V", "r_cell": "mOhm", "t_battery": "degC", "sample_age": "s",
}


def clamp(x, lo, hi):
    return max(lo, min(hi, x))


def server_id(rack, j):
    return f"{rack}_s{j:02d}"


def phase_id(rack, p, feed="a"):
    """Rack PDU phase circuit. Each rack has two feeds, a and b (2N power),
    that share the rack load equally."""
    return f"{rack}_{feed}_l{p}"


# ---------------------------------------------------------------------------
# Physics
# ---------------------------------------------------------------------------
def coil_effectiveness(ntu, cr):
    """Counterflow effectiveness, Eq. 33."""
    if abs(1.0 - cr) < 1e-9:
        return ntu / (1.0 + ntu)
    e = math.exp(-ntu * (1.0 - cr))
    return (1.0 - e) / (1.0 - cr * e)


def coil_ua(m_water):
    """Overall coil conductance. The water-side film coefficient scales with
    flow to the power 0.8, so heat transfer falls at low water flow."""
    if m_water <= 0:
        return 0.0
    ha_water = HA_WATER_DESIGN * (m_water / M_CHW_DESIGN) ** 0.8
    return 1.0 / (1.0 / HA_AIR + 1.0 / ha_water)


def coil_heat(m_air, m_water, t_air_in):
    """Coil heat transfer by effectiveness-NTU, Eqs. 31 to 33. Returns kW."""
    c_air, c_water = m_air * CP_AIR, m_water * CP_WATER
    c_min, c_max = min(c_air, c_water), max(c_air, c_water)
    if c_min <= 0 or t_air_in <= T_CHW_SUPPLY:
        return 0.0
    eps = coil_effectiveness(coil_ua(m_water) / c_min, c_min / c_max)
    return eps * c_min * (t_air_in - T_CHW_SUPPLY)


def valve_flow(theta, availability):
    """Equal-percentage valve, Eq. 34, scaled by chilled-water availability."""
    return M_CHW_MAX * VALVE_RANGEABILITY ** (theta - 1.0) * availability


def default_faults():
    return {
        "fan_health": 1.0,          # F1: airflow fraction the fan still delivers
        "fan_power_ratio": 1.0,     # F1: measured over affinity-law power
        "chw_availability": 1.0,    # F2: fraction of design water flow available
        "filter_loading": 1.0,      # F3: K_filt / K_filt,clean, Eq. 27
        "beta_local": {},           # F4: extra top-of-rack recirculation per rack
        "failed_server_fans": set(),  # F5
        "phase_share": {},          # F6: rack -> share of rack power on phase 1
        "battery_r_ratio": 1.0,     # F7
        "battery_v_cell": V_CELL_FLOAT,
        "battery_temp": 23.0,
        "ups_bypass": False,        # F8
    }


def solve_state(util, faults, rng_servers):
    """Steady-state solution of the row for given utilisations and faults.

    util: dict rack -> mean utilisation. rng_servers: per-server utilisation
    offsets, so a case and its fault-free twin share the same workload.
    Returns a dict of true (noise-free) physical values.
    """
    t_sa = T_SETPOINT
    t_mid = {r: 21.0 for r in RACKS}
    t_top = {r: 22.0 for r in RACKS}
    filt_factor = math.sqrt(1.0 / ((1 - FILTER_SHARE) + FILTER_SHARE * faults["filter_loading"]))
    flow_factor = faults["fan_health"] * filt_factor

    for _ in range(400):
        servers = {}
        demand = 0.0
        hot_enthalpy = 0.0
        rack_info = {}
        for r in RACKS:
            p_rack, m_rack, h_rack, h_top, m_top = 0.0, 0.0, 0.0, 0.0, 0.0
            for j in range(1, SERVERS_PER_RACK + 1):
                sid = server_id(r, j)
                u = clamp(util[r] + rng_servers[sid], 0.0, 1.0)
                t_in = t_mid[r] if j <= SERVERS_PER_RACK // 2 else t_top[r]
                omega = OMEGA_NOM * (0.6 + 0.4 * u) * (1 + 0.05 * max(0.0, t_in - 24.0))
                omega = min(omega, OMEGA_MAX)
                m_s = M_SERVER_NOM * omega / OMEGA_NOM
                if sid in faults["failed_server_fans"]:
                    omega, m_s = 0.0, 0.012
                p_s = P_IDLE + (P_MAX - P_IDLE) * u                         # Eq. 1
                p_cpu = CPU_SHARE * p_s
                r_th = R_TH_NOM * (M_SERVER_NOM / m_s) ** 0.8              # Eq. 8
                kappa = clamp((T_J_MAX - t_in) / (r_th * p_cpu), 0.3, 1.0)
                p_cpu_eff = kappa * p_cpu
                p_s_eff = p_s - (1 - kappa) * p_cpu
                t_cpu = t_in + r_th * p_cpu_eff
                t_out = t_in + p_s_eff / (m_s * CP_AIR)                    # Eq. 6
                servers[sid] = dict(u=u, omega=omega, t_cpu=t_cpu,
                                    f_cpu=F_NOM * kappa ** (1 / 3), p=p_s_eff)   # Eq. 9, phi_f = kappa^(1/3)
                p_rack += p_s_eff                                           # Eq. 2
                m_rack += m_s
                h_rack += m_s * t_out
                if j > SERVERS_PER_RACK // 2:
                    h_top += m_s * t_out
                    m_top += m_s
            t_out_rack = h_rack / m_rack                                    # Eq. 7, as the mixed server outlets
            rack_info[r] = dict(p=p_rack, m=m_rack, t_out=t_out_rack, t_out_top=h_top / m_top)
            demand += m_rack
            hot_enthalpy += h_rack

        t_hot = hot_enthalpy / demand

        # CRAH fan: speed set from airflow demand, Eqs. 21 and 23.
        n_fan = clamp(100.0 * demand * AIRFLOW_MARGIN / (RHO_AIR * V_RATED * filt_factor), FAN_MIN, FAN_MAX)
        m_air = RHO_AIR * V_RATED * (n_fan / 100.0) * flow_factor          # Eq. 5
        p_fan_exp = P_FAN_RATED * (n_fan / 100.0) ** 3
        p_fan = p_fan_exp * faults["fan_power_ratio"]                      # Eq. 24, F1 injects the ratio

        # Inlet temperatures. A shortfall is drawn partly from the hot aisle
        # and partly from the room. Top inlets add local recirculation, Eq. 18.
        deficit = max(0.0, demand - m_air)
        supplied = demand - deficit
        t_in_row = (supplied * t_sa + deficit * (DEFICIT_HOT_SHARE * t_hot + (1 - DEFICIT_HOT_SHARE) * T_ROOM)) / demand
        new_mid, new_top = {}, {}
        for r in RACKS:
            beta = clamp(BETA_TOP_BASE + faults["beta_local"].get(r, 0.0), 0.0, 0.8)
            new_mid[r] = t_in_row
            new_top[r] = (1 - beta) * t_in_row + beta * rack_info[r]["t_out_top"]

        # Return air, including bypass of surplus supply air.
        if m_air >= demand:
            t_ra = (demand * t_hot + (m_air - demand) * t_sa) / m_air
        else:
            t_ra = t_hot
        t_coil_in = t_ra + p_fan / (max(m_air, 1e-6) * CP_AIR)

        # Valve controller: smallest opening that meets the setpoint.
        q_req = max(0.0, m_air * CP_AIR * (t_coil_in - T_SETPOINT))
        avail = faults["chw_availability"]
        if coil_heat(m_air, valve_flow(1.0, avail), t_coil_in) <= q_req:
            theta = 1.0
        else:
            lo, hi = 0.0, 1.0
            for _ in range(60):
                mid = (lo + hi) / 2
                if coil_heat(m_air, valve_flow(mid, avail), t_coil_in) < q_req:
                    lo = mid
                else:
                    hi = mid
            theta = hi
        m_w = valve_flow(theta, avail)
        q = coil_heat(m_air, m_w, t_coil_in)
        t_sa_new = t_coil_in - q / (max(m_air, 1e-6) * CP_AIR)
        t_wr = T_CHW_SUPPLY + q / (m_w * CP_WATER)                          # Eqs. 29 and 30

        change = abs(t_sa_new - t_sa) + max(abs(new_mid[r] - t_mid[r]) + abs(new_top[r] - t_top[r]) for r in RACKS)
        t_sa = 0.5 * t_sa + 0.5 * t_sa_new
        for r in RACKS:
            t_mid[r] = 0.5 * t_mid[r] + 0.5 * new_mid[r]
            t_top[r] = 0.5 * t_top[r] + 0.5 * new_top[r]
        if change < 1e-5:
            break

    p_it = sum(info["p"] for info in rack_info.values())                  # Eq. 3
    v_air = m_air / RHO_AIR
    return dict(
        t_sa=t_sa, t_ra=t_ra, n_fan=n_fan, p_fan=p_fan, theta=theta, m_w=m_w, t_wr=t_wr,
        dp_filter=K_FILTER_CLEAN * faults["filter_loading"] * v_air ** 2,    # Eq. 26
        t_mid=t_mid, t_top=t_top, racks=rack_info, servers=servers, p_it=p_it, q=q,
    )


# ---------------------------------------------------------------------------
# Observation layer
# ---------------------------------------------------------------------------
def true_observations(state, util, faults, rng):
    """Turn a physical state into noise-free obs tuples (variable, entity, value)."""
    obs = []
    add = lambda v, e, x: obs.append((v, e, x))
    add("t_supply_air", CRAH, state["t_sa"])
    add("t_return_air", CRAH, state["t_ra"])
    add("fan_speed", CRAH, state["n_fan"])
    add("fan_power", CRAH, state["p_fan"])
    add("dp_filter", CRAH, state["dp_filter"])
    add("valve_position", CRAH, 100.0 * state["theta"])
    add("t_chw_supply", CRAH, T_CHW_SUPPLY)
    add("t_chw_return", CRAH, state["t_wr"])
    add("m_chw", CRAH, state["m_w"])
    for r in RACKS:
        info = state["racks"][r]
        add("t_inlet_mid", r, state["t_mid"][r])
        add("t_inlet_top", r, state["t_top"][r])
        add("t_outlet", r, info["t_out"])
        add("t_outlet_top", r, info["t_out_top"])
        add("p_rack", r, info["p"])
        add("cpu_util", r, util[r])
        for feed in ("a", "b"):
            default = 1 / 3 + rng.uniform(-0.02, 0.02)
            share1 = faults["phase_share"].get(r, default) if feed == "a" else default
            rest = (1 - share1) / 2
            p_feed = info["p"] / 2
            for p, share in zip((1, 2, 3), (share1, rest, rest)):
                add("i_branch", phase_id(r, p, feed), 1000 * p_feed * share / (V_LN * POWER_FACTOR))   # Eq. 42 per phase
        for j in range(1, SERVERS_PER_RACK + 1):
            sid = server_id(r, j)
            s = state["servers"][sid]
            rpm = rng.uniform(0, 200) if sid in faults["failed_server_fans"] else s["omega"]
            add("t_cpu", sid, s["t_cpu"])
            add("server_fan_rpm", sid, rpm)
            add("f_cpu", sid, s["f_cpu"])
    p_out = state["p_it"] / PDU_EFF
    eff = UPS_EFF_BYPASS if faults["ups_bypass"] else UPS_EFF_DC + rng.uniform(-0.003, 0.003)
    add("p_ups_out", UPS, p_out)
    add("p_ups_in", UPS, p_out / eff)                                         # Eq. 45
    add("ups_mode", UPS, "bypass" if faults["ups_bypass"] else "double_conversion")
    add("v_battery", BATTERY, N_CELLS * faults["battery_v_cell"])             # Eq. 48
    add("r_cell", BATTERY, R_CELL_BASE * faults["battery_r_ratio"])           # Eq. 49
    add("t_battery", BATTERY, faults["battery_temp"])
    return obs


def entity_group(entity):
    """Telemetry source an entity reports through (for sample_age and S2)."""
    for r in RACKS:
        if entity.startswith(r):
            return r
    return entity


def measure(obs, rng, noise_scale=1.0, biases=None):
    """Apply sensor bias (S1) and measurement noise."""
    biases = biases or {}
    out = []
    for var, ent, x in obs:
        if isinstance(x, str):
            out.append((var, ent, x))
            continue
        x = x + biases.get((var, ent), 0.0)
        kind, sigma = NOISE.get(var, ("abs", 0.0))
        sigma *= noise_scale
        x = x + rng.gauss(0, sigma) if kind == "abs" else x * (1 + rng.gauss(0, sigma))
        if var in ("valve_position", "fan_speed"):
            x = clamp(x, 0.0, 100.0)
        if var in ("server_fan_rpm", "m_chw", "fan_power", "dp_filter"):
            x = max(0.0, x)
        out.append((var, ent, x))
    return out


# ---------------------------------------------------------------------------
# Case construction
# ---------------------------------------------------------------------------
LOADS = {"low": (0.10, 0.20), "nominal": (0.40, 0.60), "high": (0.80, 0.90)}


class CaseBuilder:
    def __init__(self, rng):
        self.rng = rng

    def utilisation(self, load):
        lo, hi = LOADS[load]
        u_row = self.rng.uniform(lo, hi)
        util = {r: clamp(u_row + self.rng.uniform(-0.05, 0.05), 0.0, 1.0) for r in RACKS}
        offsets = {server_id(r, j): self.rng.gauss(0, 0.03)
                   for r in RACKS for j in range(1, SERVERS_PER_RACK + 1)}
        return util, offsets

    # -- fault injectors: each edits the fault dict and returns its label --
    def f1(self, f, mode):
        if mode == "borderline":
            f["fan_health"], f["fan_power_ratio"] = self.rng.uniform(0.3, 0.5), self.rng.uniform(0.4, 0.6)
        else:
            f["fan_health"], f["fan_power_ratio"] = self.rng.uniform(0.0, 0.1), self.rng.uniform(0.05, 0.15)
        return f"crah_fan_failure({CRAH})"

    def f2(self, f, mode):
        f["chw_availability"] = self.rng.uniform(0.25, 0.4) if mode == "borderline" else self.rng.uniform(0.02, 0.2)
        return f"chw_supply_loss({CRAH})"

    def f3(self, f, mode):
        f["filter_loading"] = self.rng.uniform(1.8, 2.5) if mode == "borderline" else self.rng.uniform(3.0, 6.0)
        f["fan_power_ratio"] = self.rng.uniform(0.93, 1.0)
        return f"filter_clogging({CRAH})"

    def f4(self, f, mode, rack=None):
        rack = rack or self.rng.choice(RACKS)
        f["beta_local"][rack] = self.rng.uniform(0.12, 0.2) if mode == "borderline" else self.rng.uniform(0.25, 0.5)
        return f"hot_air_recirculation({rack})", rack

    def f5(self, f, mode, rack=None):
        rack = rack or self.rng.choice(RACKS)
        sid = server_id(rack, self.rng.randint(1, SERVERS_PER_RACK))
        f["failed_server_fans"].add(sid)
        return f"server_fan_failure({sid})"

    def f6(self, f, mode, rack, rack_power):
        target = self.rng.uniform(24.5, 26.5) if mode == "borderline" else self.rng.uniform(27.0, 30.0)
        f["phase_share"][rack] = clamp(target * V_LN * POWER_FACTOR / (1000 * rack_power / 2), 0.34, 0.95)
        return f"branch_overload({phase_id(rack, 1)})"

    def f7(self, f, mode):
        f["battery_r_ratio"] = self.rng.uniform(1.2, 1.4) if mode == "borderline" else self.rng.uniform(1.5, 2.5)
        f["battery_v_cell"] = self.rng.uniform(2.21, 2.24)
        f["battery_temp"] = self.rng.choice([self.rng.uniform(22, 25), self.rng.uniform(28, 35)])
        return f"battery_degradation({BATTERY})"

    def f8(self, f, mode):
        f["ups_bypass"] = True
        return f"ups_on_bypass({UPS})"

    def build(self, cid, category, load, spec, mode="clear", noise_scale=1.0,
              drop_fraction=0.0, desc="", bias_magnitude=None):
        """spec: list of fault codes, e.g. ["F3", "F4"], or [] for normal.
        bias_magnitude fixes the size of an S1 sensor bias in kelvin."""
        rng = self.rng
        util, offsets = self.utilisation(load)
        f = default_faults()
        f["battery_v_cell"] = rng.uniform(2.25, 2.29)
        f["battery_r_ratio"] = rng.uniform(0.95, 1.12)
        f["battery_temp"] = rng.uniform(22.0, 24.5)
        f["filter_loading"] = rng.uniform(1.0, 1.4)
        f["fan_power_ratio"] = rng.uniform(0.95, 1.05)
        labels, biases, stale, shared_rack = [], {}, None, None

        for code in spec:
            if code == "F1": labels.append(self.f1(f, mode))
            elif code == "F2": labels.append(self.f2(f, mode))
            elif code == "F3": labels.append(self.f3(f, mode))
            elif code == "F4":
                lab, shared_rack = self.f4(f, mode, shared_rack)
                labels.append(lab)
            elif code == "F5": labels.append(self.f5(f, mode, shared_rack))
            elif code == "F7": labels.append(self.f7(f, mode))
            elif code == "F8": labels.append(self.f8(f, mode))

        state = solve_state(util, f, offsets)

        if "F6" in spec:   # needs rack power, so it is applied after solving
            rack = shared_rack or rng.choice(RACKS)
            labels.append(self.f6(f, mode, rack, state["racks"][rack]["p"]))

        for code in spec:
            if code == "S1":
                target = rng.choice([("t_inlet_top", rng.choice(RACKS)), ("t_inlet_mid", rng.choice(RACKS)),
                                     ("t_supply_air", CRAH)])
                # Draw order matters for reproducibility: sign first, then size,
                # exactly as when the published datasets were generated.
                sign = rng.choice([-1, 1])
                size = bias_magnitude if bias_magnitude is not None else rng.uniform(3.0, 8.0)
                biases[target] = sign * size
                labels.append(f"sensor_bias({target[0]}, {target[1]})")
            elif code == "S1mask":   # negative bias on the recirculating rack's top sensor
                rack = shared_rack
                rise = state["t_top"][rack] - state["t_mid"][rack]
                biases[("t_inlet_top", rack)] = -rise + rng.uniform(0.5, 1.5)
                labels.append(f"sensor_bias(t_inlet_top, {rack})")
            elif code == "S2":
                stale = rng.choice(RACKS + [CRAH, UPS, BATTERY])
                labels.append(f"telemetry_dropout({stale})")

        obs = true_observations(state, util, f, rng)
        if stale:   # frozen values: the readings from before any fault
            base_f = default_faults()
            base_obs = true_observations(solve_state(util, base_f, offsets), util, base_f, rng)
            frozen = {(v, e): x for v, e, x in base_obs if entity_group(e) == stale}
            obs = [(v, e, frozen.get((v, e), x)) for v, e, x in obs]
        obs = measure(obs, rng, noise_scale, biases)

        groups = sorted({entity_group(e) for _, e, _ in obs})
        for g in groups:
            age = rng.uniform(300, 1800) if g == stale else rng.uniform(5, 30)
            obs.append(("sample_age", g, age))

        if drop_fraction > 0:
            obs = [o for o in obs if o[0] == "sample_age" or rng.random() >= drop_fraction]

        return dict(id=cid, category=category, load=load, mode=mode, desc=desc,
                    expected=labels or ["normal"], obs=obs,
                    truth=dict(p_it_kw=round(state["p_it"], 2), q_coil_kw=round(state["q"], 2),
                               fan_health=f["fan_health"], chw_availability=f["chw_availability"],
                               filter_loading=f["filter_loading"], beta_local=f["beta_local"],
                               failed_server_fans=sorted(f["failed_server_fans"]),
                               phase_share=f["phase_share"], battery_r_ratio=f["battery_r_ratio"],
                               ups_bypass=f["ups_bypass"], biases={f"{k[0]}@{k[1]}": v for k, v in biases.items()},
                               stale=stale, noise_scale=noise_scale, drop_fraction=drop_fraction))


FAULT_NAMES = {"F1": "CRAH fan failure", "F2": "chilled-water supply loss", "F3": "filter clogging",
               "F4": "hot-air recirculation", "F5": "server fan failure", "F6": "branch overload",
               "F7": "battery degradation", "F8": "UPS on static bypass",
               "S1": "temperature sensor bias", "S2": "telemetry dropout", "S1mask": "sensor bias masking"}

MULTI_COMBOS = [["F3", "F4"], ["F4", "S1mask"], ["F7", "F8"], ["F1", "F6"], ["F4", "F5"]]
SINGLE = ["F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8"]


def generate(seed, prefix="g"):
    rng = random.Random(seed)
    b = CaseBuilder(rng)
    cases, n = [], 0

    def nid():
        nonlocal n
        n += 1
        return f"{prefix}{n:03d}"

    def load_for(code_list):
        if "F6" in code_list:
            return rng.choice(["nominal", "high"])
        return rng.choice(list(LOADS))

    for i in range(30):
        load = list(LOADS)[i % 3]
        cases.append(b.build(nid(), "normal", load, [], desc=f"Normal operation, {load} load"))
    for code in SINGLE:
        for _ in range(15):
            load = load_for([code])
            cases.append(b.build(nid(), "single_fault", load, [code], desc=f"{FAULT_NAMES[code]}, {load} load"))
    for code in ("S1", "S2"):
        for _ in range(15):
            load = load_for([code])
            cases.append(b.build(nid(), "instrumentation", load, [code], desc=f"{FAULT_NAMES[code]}, {load} load"))
    for combo in MULTI_COMBOS:
        for _ in range(6):
            load = load_for(combo)
            name = " + ".join(FAULT_NAMES[c] for c in combo)
            cases.append(b.build(nid(), "multiple", load, combo, desc=f"{name}, {load} load"))
    for _ in range(15):
        code = rng.choice(SINGLE)
        load = load_for([code])
        cases.append(b.build(nid(), "noisy", load, [code], noise_scale=5.0,
                             desc=f"{FAULT_NAMES[code]}, {load} load, 5x sensor noise"))
    for _ in range(15):
        code = rng.choice(SINGLE + [None])
        spec = [code] if code else []
        load = load_for(spec)
        name = FAULT_NAMES[code] if code else "Normal operation"
        cases.append(b.build(nid(), "incomplete", load, spec, drop_fraction=0.15,
                             desc=f"{name}, {load} load, 15% of readings missing"))
    for i in range(15):
        code = ["F1", "F2", "F3", "F4", "F6", "F7", None][i % 7]
        spec = [code] if code else []
        load = "high" if code is None else load_for(spec)
        name = FAULT_NAMES[code] if code else "Normal operation"
        cases.append(b.build(nid(), "borderline", load, spec, mode="borderline",
                             desc=f"{name}, {load} load, near the detection threshold"))
    return cases


# ---------------------------------------------------------------------------
# Writers
# ---------------------------------------------------------------------------
def prolog_value(x):
    if isinstance(x, str):
        return x
    return repr(round(float(x), 3))


def prolog_quote(text):
    return "'" + text.replace("\\", "\\\\").replace("'", "\\'") + "'"


def write_prolog(cases, path, seed, split):
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(f"/*  {path} - GENERATED by simulator/dc_sim.py with seed {seed}. Do not edit by hand.\n\n")
        fh.write("    ALL CASES IN THIS FILE ARE SYNTHETIC. They come from the steady-state model\n")
        fh.write("    in docs/05_engineering_model.md and are not measurements from a real facility.\n*/\n\n")
        fh.write(":- multifile case/3, case_category/2, case_split/2, expected/2, obs/4.\n")
        fh.write(":- discontiguous case/3, case_category/2, case_split/2, expected/2, obs/4.\n\n")
        for c in cases:
            fh.write(f"% ---- {c['id']}: {c['desc']}\n")
            fh.write(f"case({c['id']}, {prolog_quote(c['desc'])}, synthetic).\n")
            fh.write(f"case_category({c['id']}, {c['category']}).\n")
            fh.write(f"case_split({c['id']}, {split}).\n")
            fh.write(f"expected({c['id']}, [{', '.join(c['expected'])}]).\n")
            for var, ent, x in c["obs"]:
                fh.write(f"obs({c['id']}, {var}, {ent}, {prolog_value(x)}).\n")
            fh.write("\n")


def write_csv(cases, path):
    with open(path, "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["case_id", "category", "load", "variable", "entity", "value", "unit"])
        for c in cases:
            for var, ent, x in c["obs"]:
                w.writerow([c["id"], c["category"], c["load"], var, ent, prolog_value(x), UNITS.get(var, "")])


def write_truth(cases, path, seed):
    data = {"seed": seed, "note": "Synthetic ground truth. Not real measurements.",
            "cases": [{k: c[k] for k in ("id", "category", "load", "mode", "desc", "expected", "truth")}
                      for c in cases]}
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=1, default=list)


# ---------------------------------------------------------------------------
# Model-mismatch profiles. Each one changes the simulator's physics while the
# knowledge base stays as it is, to measure how much the diagnosis depends on
# the model being exactly right. Equipment ratings that the knowledge base
# reads from nameplates (fan rated power, rated airflow, valve and filter
# data, battery baseline) are deliberately left unchanged.
# ---------------------------------------------------------------------------
PHYSICS = {
    "nominal": {},
    "mild": {      # changes of about 10 to 25 percent
        "HA_AIR": 12.0, "HA_WATER_DESIGN": 12.0, "DEFICIT_HOT_SHARE": 0.5,
        "P_IDLE": 0.35, "P_MAX": 0.95, "M_SERVER_NOM": 0.05, "AIRFLOW_MARGIN": 1.15,
        "T_ROOM": 26.0, "BETA_TOP_BASE": 0.12, "CPU_SHARE": 0.5, "NOISE_SCALE": 1.25,
    },
    "strong": {    # changes of about 25 to 50 percent
        "HA_AIR": 10.0, "HA_WATER_DESIGN": 14.0, "DEFICIT_HOT_SHARE": 0.6,
        "P_IDLE": 0.30, "P_MAX": 1.05, "M_SERVER_NOM": 0.045, "AIRFLOW_MARGIN": 1.25,
        "T_ROOM": 27.0, "BETA_TOP_BASE": 0.15, "CPU_SHARE": 0.6, "R_TH_NOM": 110.0,
        "NOISE_SCALE": 1.5,
    },
}


def set_physics(name):
    """Apply a model-mismatch profile by overriding the module constants."""
    profile = dict(PHYSICS[name])
    scale = profile.pop("NOISE_SCALE", 1.0)
    for key, value in profile.items():
        if key not in globals():
            raise KeyError(key)
        globals()[key] = value
    if scale != 1.0:
        for var, (kind, sigma) in list(NOISE.items()):
            NOISE[var] = (kind, sigma * scale)


SWEEPS = {
    # kind: (levels, description of the level)
    "noise":   ([1, 2, 3, 4, 5, 6, 8], "sensor noise as a multiple of nominal"),
    "missing": ([0.0, 0.05, 0.1, 0.2, 0.3, 0.4], "share of readings removed"),
    "multi":   ([1, 2, 3, 4], "number of simultaneous faults"),
    "bias":    ([1.0, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0], "sensor bias in kelvin"),
}


def generate_sweep(kind, level, seed, n=60, prefix="s"):
    """Cases for one point of a sensitivity sweep. Every case is synthetic.

    noise    random single fault or normal, at the given noise multiple
    missing  random single fault or normal, with the given share of readings removed
    multi    the given number of distinct random faults at once
    bias     an S1 sensor bias of the given size on a random temperature sensor
    """
    rng = random.Random(seed)
    b = CaseBuilder(rng)
    pool_single = SINGLE + ["S1", "S2", None]
    cases = []
    for i in range(1, n + 1):
        cid = f"{prefix}{i:03d}"
        if kind in ("noise", "missing"):
            code = pool_single[(i - 1) % len(pool_single)]
            spec = [code] if code else []
        elif kind == "multi":
            spec = rng.sample(SINGLE + ["S2"], int(level))
        elif kind == "bias":
            spec = ["S1"]
        else:
            raise ValueError(kind)
        load = rng.choice(["nominal", "high"]) if "F6" in spec else rng.choice(list(LOADS))
        name = " + ".join(FAULT_NAMES[c] for c in spec) if spec else "Normal operation"
        cases.append(b.build(cid, f"sweep_{kind}", load, spec,
                             noise_scale=level if kind == "noise" else 1.0,
                             drop_fraction=level if kind == "missing" else 0.0,
                             bias_magnitude=level if kind == "bias" else None,
                             desc=f"{name}, {load} load, {kind} level {level}"))
    return cases


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--physics", choices=sorted(PHYSICS), default="nominal",
                    help="model-mismatch profile for the simulator physics")
    ap.add_argument("--sweep", choices=sorted(SWEEPS), help="generate one sensitivity-sweep dataset")
    ap.add_argument("--level", type=float, help="sweep level, see SWEEPS")
    ap.add_argument("--n", type=int, default=60, help="cases per sweep dataset")
    ap.add_argument("--seed", type=int, default=20261020)
    ap.add_argument("--out", default="data/generated_cases.pl")
    ap.add_argument("--csv", default="data/generated_cases.csv")
    ap.add_argument("--truth", default="data/generated_truth.json")
    ap.add_argument("--prefix", default="g", help="case id prefix")
    ap.add_argument("--split", default="calibration", help="calibration or holdout")
    args = ap.parse_args()
    set_physics(args.physics)
    if args.sweep:
        cases = generate_sweep(args.sweep, args.level, args.seed, args.n, args.prefix)
        write_prolog(cases, args.out, args.seed, "sweep")
        write_truth(cases, args.truth, args.seed)
        print(f"Generated {len(cases)} synthetic {args.sweep} sweep cases at level {args.level}")
        return
    cases = generate(args.seed, args.prefix)
    write_prolog(cases, args.out, args.seed, args.split)
    write_csv(cases, args.csv)
    write_truth(cases, args.truth, args.seed)
    counts = {}
    for c in cases:
        counts[c["category"]] = counts.get(c["category"], 0) + 1
    print(f"Generated {len(cases)} synthetic cases with seed {args.seed}: {counts}")


if __name__ == "__main__":
    main()
