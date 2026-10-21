# Knowledge Acquisition Log

Every rule and threshold in the knowledge base should trace back to a row here. The trace runs from literature to knowledge, then to a rule, a Prolog predicate and a test.

**Important:** the candidate sources below are well-known works in this area, but you must check every detail before citing. That means the edition, year, pages and the exact claim. Add each one to EndNote only after you have read the relevant part yourself.

## Knowledge-to-rule table

| Knowledge | Source | Evidence | Converted into | Prolog |
|---|---|---|---|---|
| Recommended inlet envelope of 18 to 27 °C | ASHRAE TC 9.9 (2021) | Thermal guideline table | Threshold fact | `threshold(t_inlet_rec_max, 27.0, ...)` |
| Fan power scales with speed cubed | ASHRAE Handbook, fans chapter *[confirm]* | Affinity laws | Calculation plus rule R07 | `expected_fan_power/3` |
| Blanking panels prevent recirculation | EU Code of Conduct on Data Centre Energy Efficiency *[confirm]* | Best-practice guideline | Maintenance rule for F4 | `maintenance(hot_air_recirculation, ...)` |
| Server power is roughly linear in utilisation | Fan, Weber and Barroso (2007) | Measured power model | Planned calculation | planned |
| Supply and return heat indices | Sharma, Bash and Patel (2002) | Dimensionless indices | Planned calculation | planned |
| Rack cooling index | Herrlin (2005) | Index definition | Planned calculation | planned |
| Battery ohmic monitoring | IEEE Std 1188 and IEEE Std 1491 *[confirm]* | Maintenance guidance | F7 thresholds | planned |
| Consistency-based diagnosis | Reiter (1987); de Kleer and Williams (1987) | Formal theory | Consistency engine | planned |
| Abductive diagnosis | Poole (1989); Console and Torasso (1991) | Formal theory | Abductive engine | planned |

## Engineering assumptions currently in the knowledge base

These are marked `assumption` in [kb/sources.pl](../kb/sources.pl). Each one needs either a source or an explicit justification in the report.

| ID | Assumption |
|---|---|
| a1_supply_setpoint | Supply-air setpoint 20 °C with a 2 K tolerance band |
| a2_row_fraction | Overheating at half or more of the racks points to a row-level cause |
| a3_valve_open | A valve open by 50% or more should produce a measurable water temperature rise |
| a4_chw_flow | Measured water flow below 30% of the valve-characteristic prediction means chilled-water supply is lost |
| a5_stratification | A top-to-middle inlet difference above 3 K indicates recirculation |
| a6_fan_ratio | Fan power below 50% of the affinity-law prediction means the fan is not moving air |

## Candidate reading list to verify and grow toward 70 to 90 sources

- ASHRAE TC 9.9. (2021). *Thermal guidelines for data processing environments* (5th ed.).
- Barroso, L. A., Hölzle, U., & Ranganathan, P. (2018). *The datacenter as a computer* (3rd ed.).
- Fan, X., Weber, W.-D., & Barroso, L. A. (2007). Power provisioning for a warehouse-sized computer. *ISCA*.
- Sharma, R. K., Bash, C. E., & Patel, C. D. (2002). Dimensionless parameters for evaluation of thermal design and performance of large-scale data centers. *AIAA*.
- Herrlin, M. K. (2005). Rack cooling effectiveness in data centers and telecom central offices: The rack cooling index. *ASHRAE Transactions*.
- The Green Grid. Power usage effectiveness white papers.
- Reiter, R. (1987). A theory of diagnosis from first principles. *Artificial Intelligence, 32*.
- de Kleer, J., & Williams, B. C. (1987). Diagnosing multiple faults. *Artificial Intelligence, 32*.
- Poole, D. (1989). Explanation and prediction: An architecture for default and abductive reasoning. *Computational Intelligence*.
- Console, L., & Torasso, P. (1991). A spectrum of logical definitions of model-based diagnosis. *Computational Intelligence*.
- Isermann, R. (2006). *Fault-diagnosis systems*. Springer.
- Venkatasubramanian, V., et al. (2003). A review of process fault detection and diagnosis, parts I to III. *Computers & Chemical Engineering*.
- Bratko, I. (2012). *Prolog programming for artificial intelligence* (4th ed.).
- Peng, Y., & Reggia, J. A. (1990). *Abductive inference models for diagnostic problem-solving*. Springer. Basis of the parsimonious covering in `engine/abductive.pl`.
- Struss, P., & Dressler, O. (1989). "Physical negation": Integrating fault models into the general diagnostic engine. *IJCAI*. Basis of the fault models in `kb/arr.pl`.
- Cordier, M.-O., Dague, P., Lévy, F., Montmain, J., Staroswiecki, M., & Travé-Massuyès, L. (2004). Conflicts versus analytical redundancy relations. *IEEE Transactions on Systems, Man, and Cybernetics, Part B*. Links the redundancy relations to consistency-based diagnosis.
- Rousseeuw, P. J., & Croux, C. (1993). Alternatives to the median absolute deviation. *Journal of the American Statistical Association*. Background for the robust noise estimate.
- IEEE Std 1188 for VRLA battery maintenance, and IEEE Std 1491 for battery monitoring.
