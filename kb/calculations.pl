/*  kb/calculations.pl - engineering-calculation predicates.

    Each predicate implements one equation from docs/05_engineering_model.md; numbers match that document.
    calc_pred/1 tells the explanation facility which proof leaves are
    calculations, so they are reported as "derived engineering quantities".
*/

calc_pred(inlet_max(_, _, _)).
calc_pred(inlet_stratification(_, _, _)).
calc_pred(hot_rack_fraction(_, _)).
calc_pred(expected_fan_power(_, _, _)).
calc_pred(fan_power_ratio(_, _, _)).
calc_pred(chw_delta_t(_, _, _)).
calc_pred(expected_chw_flow(_, _, _)).
calc_pred(chw_flow_ratio(_, _, _)).
calc_pred(outlet_stratification(_, _, _)).
calc_pred(mid_inlet_deviation(_, _, _)).
calc_pred(supply_air_deviation(_, _, _)).
calc_pred(air_side_heat(_, _, _)).
calc_pred(water_side_heat(_, _, _)).
calc_pred(coil_balance_residual(_, _, _)).
calc_pred(filter_loading(_, _, _)).
calc_pred(branch_loading(_, _, _)).
calc_pred(cell_resistance_ratio(_, _, _)).
calc_pred(ups_efficiency(_, _, _)).
calc_pred(top_inlet_deviation(_, _, _)).
calc_pred(coil_balance_residual_corrected(_, _, _)).

%   calc_uses(+CalcGoal, -Obs): the observations a calculation reads, so the
%   explanation facility can list them as observed evidence.
calc_uses(inlet_max(C, R, _), obs(C, V, R, X)) :-
    member(V, [t_inlet_mid, t_inlet_top]), obs(C, V, R, X).
calc_uses(inlet_stratification(C, R, _), obs(C, V, R, X)) :-
    member(V, [t_inlet_mid, t_inlet_top]), obs(C, V, R, X).
calc_uses(hot_rack_fraction(C, _), obs(C, t_inlet_top, R, X)) :-
    component(R, rack), obs(C, t_inlet_top, R, X).
calc_uses(expected_fan_power(C, U, _), obs(C, fan_speed, U, X)) :-
    obs(C, fan_speed, U, X).
calc_uses(fan_power_ratio(C, U, _), obs(C, V, U, X)) :-
    member(V, [fan_speed, fan_power]), obs(C, V, U, X).
calc_uses(chw_flow_ratio(C, U, _), obs(C, V, U, X)) :-
    member(V, [valve_position, m_chw]), obs(C, V, U, X).
calc_uses(outlet_stratification(C, R, _), obs(C, V, R, X)) :-
    member(V, [t_outlet, t_outlet_top]), obs(C, V, R, X).
calc_uses(mid_inlet_deviation(C, _, _), obs(C, t_inlet_mid, R, X)) :-
    obs(C, t_inlet_mid, R, X).
calc_uses(supply_air_deviation(C, U, _), O) :-
    (   O = obs(C, t_supply_air, U, X), obs(C, t_supply_air, U, X)
    ;   O = obs(C, t_inlet_mid, R, X), obs(C, t_inlet_mid, R, X)
    ).
calc_uses(coil_balance_residual(C, U, _), obs(C, V, U, X)) :-
    member(V, [fan_speed, t_return_air, t_supply_air, m_chw, t_chw_supply, t_chw_return]),
    obs(C, V, U, X).
calc_uses(top_inlet_deviation(C, _, _), obs(C, t_inlet_top, R, X)) :-
    obs(C, t_inlet_top, R, X).
calc_uses(coil_balance_residual_corrected(C, U, _), O) :-
    (   O = obs(C, V, U, X), member(V, [fan_speed, t_return_air, m_chw, t_chw_supply, t_chw_return]), obs(C, V, U, X)
    ;   O = obs(C, t_inlet_mid, R, X), obs(C, t_inlet_mid, R, X)
    ).
calc_uses(filter_loading(C, U, _), obs(C, V, U, X)) :-
    member(V, [dp_filter, fan_speed]), obs(C, V, U, X).
calc_uses(branch_loading(C, B, _), obs(C, i_branch, B, X)) :-
    obs(C, i_branch, B, X).
calc_uses(cell_resistance_ratio(C, B, _), obs(C, r_cell, B, X)) :-
    obs(C, r_cell, B, X).
calc_uses(ups_efficiency(C, U, _), obs(C, V, U, X)) :-
    member(V, [p_ups_in, p_ups_out]), obs(C, V, U, X).
calc_uses(chw_delta_t(C, U, _), obs(C, V, U, X)) :-
    member(V, [t_chw_supply, t_chw_return]), obs(C, V, U, X).

%   Eq. 10  T_in,max(r) = max(T_in,top(r), T_in,mid(r))
inlet_max(C, R, T) :-
    obs(C, t_inlet_top, R, Tt),
    obs(C, t_inlet_mid, R, Tm),
    T is max(Tt, Tm).

%   Eq. 11  dT_strat(r) = T_in,top(r) - T_in,mid(r)
inlet_stratification(C, R, D) :-
    obs(C, t_inlet_top, R, Tt),
    obs(C, t_inlet_mid, R, Tm),
    D is Tt - Tm.

%   Eq. 12-13  phi_hot = |{r : T_in,max(r) > T_rec,max}| / |racks|
%   A rack with missing inlet data is not counted as hot. Stage 11 will
%   treat incomplete evidence explicitly.
hot_rack_fraction(C, F) :-
    threshold(t_inlet_rec_max, Th),
    findall(R, component(R, rack), Racks),
    length(Racks, N),
    N > 0,
    findall(R, ( member(R, Racks), inlet_max(C, R, T), T > Th ), Hot),
    length(Hot, H),
    F is H / N.

%   Eq. 23  P_f,exp = P_f,rated * (N / N_rated)^3      fan affinity law
expected_fan_power(C, U, P) :-
    obs(C, fan_speed, U, N),
    rated(U, fan_power_rated, Pr, _),
    rated(U, fan_speed_rated, Nr, _),
    P is Pr * (N / Nr) ** 3.

%   Eq. 24  rho_f = P_f,measured / P_f,exp
fan_power_ratio(C, U, Ratio) :-
    obs(C, fan_power, U, Pm),
    expected_fan_power(C, U, Pe),
    Pe > 0,
    Ratio is Pm / Pe.

%   Eq. 34  m_w,exp = m_w,max * R_v^(theta_v - 1)   equal-percentage valve
expected_chw_flow(C, U, M) :-
    obs(C, valve_position, U, V),
    rated(U, chw_flow_max, Mmax, _),
    rated(U, valve_rangeability, Rv, _),
    M is Mmax * Rv ** (V / 100 - 1).

%   Eq. 34a  rho_w = m_w,measured / m_w,exp
chw_flow_ratio(C, U, Ratio) :-
    obs(C, m_chw, U, Mm),
    expected_chw_flow(C, U, Me),
    Me > 0,
    Ratio is Mm / Me.

%   Eq. 29  dT_w = T_chw,return - T_chw,supply
chw_delta_t(C, U, DT) :-
    obs(C, t_chw_return, U, Tr),
    obs(C, t_chw_supply, U, Ts),
    DT is Tr - Ts.

%   Eq. 11a  dT_strat,out(r) = T_out,top(r) - T_out,bottom(r)
%   The rear probe reads the mean of two halves with similar airflow, so
%   T_out,bottom = 2 T_out - T_out,top and the difference is 2 (T_out,top - T_out).
outlet_stratification(C, R, D) :-
    obs(C, t_outlet_top, R, Ttop),
    obs(C, t_outlet, R, Tmean),
    D is 2 * (Ttop - Tmean).

%   median(+Numbers, -Median)
median(Xs, M) :-
    msort(Xs, S),
    length(S, N),
    N > 0,
    (   N mod 2 =:= 1
    ->  I is N // 2, nth0(I, S, M)
    ;   I is N // 2 - 1, J is N // 2, nth0(I, S, A), nth0(J, S, B), M is (A + B) / 2
    ).

%   Eq. 41  r_S,r = T_in,mid(r) - median of the other racks' middle inlets.
%   All middle inlets see the same supply air, so one outlier is suspect.
%   Needs at least three neighbours.
mid_inlet_deviation(C, R, D) :-
    obs(C, t_inlet_mid, R, T),
    findall(X, ( obs(C, t_inlet_mid, R2, X), R2 \== R ), Xs),
    length(Xs, N),
    N >= 3,
    median(Xs, M),
    D is T - M.

%   Eq. 41a  supply sensor check: T_sa - median of all middle inlets.
supply_air_deviation(C, U, D) :-
    obs(C, t_supply_air, U, Tsa),
    findall(X, obs(C, t_inlet_mid, _, X), Xs),
    length(Xs, N),
    N >= 3,
    median(Xs, M),
    D is Tsa - M.

%   Eq. 20 with Eqs. 5 and 21: Q_a = rho_a V_rated (N / N_rated) c_p,a (T_ra - T_sa)
air_side_heat(C, U, Q) :-
    obs(C, fan_speed, U, N),
    obs(C, t_return_air, U, Tra),
    obs(C, t_supply_air, U, Tsa),
    rated(U, airflow_rated, Vr, _),
    rated(U, fan_speed_rated, Nr, _),
    Q is 1.2 * Vr * (N / Nr) * 1.006 * (Tra - Tsa).

%   Eq. 30  Q_w = m_w c_p,w (T_wr - T_ws)
water_side_heat(C, U, Q) :-
    obs(C, m_chw, U, M),
    chw_delta_t(C, U, DT),
    Q is M * 4.186 * DT.

%   Eq. 38  r_2 = (Q_w - Q_a) / Q_a
coil_balance_residual(C, U, R) :-
    air_side_heat(C, U, Qa),
    water_side_heat(C, U, Qw),
    abs(Qa) > 1.0,
    R is (Qw - Qa) / Qa.

%   Eq. 27 with Eq. 21: lambda = dp_filt / (K_clean V_est^2)
%   V_est comes from the affinity law, so lambda is underestimated when a
%   clogged filter has already cut the real airflow. That errs on the safe side.
filter_loading(C, U, L) :-
    obs(C, dp_filter, U, Dp),
    obs(C, fan_speed, U, N),
    rated(U, airflow_rated, Vr, _),
    rated(U, fan_speed_rated, Nr, _),
    rated(U, filter_k_clean, K, _),
    V is Vr * N / Nr,
    V > 0,
    L is Dp / (K * V * V).

%   Eq. 43  L_b = I_b / I_brk
branch_loading(C, B, L) :-
    obs(C, i_branch, B, I),
    rated(breaker, current, Imax, _),
    L is I / Imax.

%   Eq. 49  rho_R = R_cell / R_cell,0
cell_resistance_ratio(C, B, Ratio) :-
    obs(C, r_cell, B, R),
    rated(B, r_cell_baseline, R0, _),
    Ratio is R / R0.

%   Eq. 45  eta_UPS = P_out / P_in
ups_efficiency(C, U, Eta) :-
    obs(C, p_ups_out, U, Pout),
    obs(C, p_ups_in, U, Pin),
    Pin > 0,
    Eta is Pout / Pin.

%   Eq. 41 applied to top inlets.
top_inlet_deviation(C, R, D) :-
    obs(C, t_inlet_top, R, T),
    findall(X, ( obs(C, t_inlet_top, R2, X), R2 \== R ), Xs),
    length(Xs, N),
    N >= 3,
    median(Xs, M),
    D is T - M.

%   Eq. 38 recomputed under the hypothesis that the supply-air sensor is
%   wrong: the median middle inlet stands in for the supply-air temperature.
%   If the hypothesis is right, this residual closes.
coil_balance_residual_corrected(C, U, R) :-
    obs(C, fan_speed, U, N),
    obs(C, t_return_air, U, Tra),
    findall(X, obs(C, t_inlet_mid, _, X), Xs),
    median(Xs, Tsa),
    rated(U, airflow_rated, Vr, _),
    rated(U, fan_speed_rated, Nr, _),
    Qa is 1.2 * Vr * (N / Nr) * 1.006 * (Tra - Tsa),
    abs(Qa) > 1.0,
    water_side_heat(C, U, Qw),
    R is (Qw - Qa) / Qa.

%   Median of the rack maximum inlet temperatures. Used for the graded
%   row_inlet_hot symptom, the graded counterpart of Eq. 13.
median_inlet_max(C, M) :-
    findall(T, ( component(R, rack), inlet_max(C, R, T) ), Ts),
    length(Ts, N),
    N >= 4,
    median(Ts, M).

%   Rack power balance, Eq. 42 per phase:
%   r_P = (sum of V_LN I_p cos(phi) over six phases - P_rack) / P_rack.
%   Only computed when every phase current is present.
rack_power_residual(C, R, Res) :-
    obs(C, p_rack, R, P),
    P > 0,
    findall(I, ( phase_of_rack(R, B), obs(C, i_branch, B, I) ), Is),
    length(Is, 6),
    sum_list(Is, Sum),
    rated(rack_pdu, v_ln, V, _),
    rated(rack_pdu, power_factor, Pf, _),
    Res is (Sum * V * Pf / 1000 - P) / P.
