MISSION: ETHENA P14 FULL MINT PROOF

OBJECTIVE:
Determine whether the integer-rounding behavior in
EthenaMinting.verifyStablesLimit can produce an exploitable
effect in the complete mint-order validation and execution path.

TARGET:
EthenaMinting
0xe3490297a08d6fC8Da46Edb7B6142E4F461b62D3

MODE:
LOCAL FORK ONLY

MANDATORY SAFETY:
- No Mainnet transactions.
- No live execution.
- No private keys or production credentials.
- Do not modify the original protocol contract.
- Do not bypass signature validation.
- Do not weaken assertions to make tests pass.
- Do not fabricate transactions, balances, results, or evidence.
- Use only public, read-only Mainnet state as fork input.
- Do not submit a bug bounty report unless the evidence
  demonstrates a reproducible security impact.

TASKS:
1. Inspect the existing P14 tests and source code.
2. Trace the complete mint-order validation path.
3. Determine whether collateral and USDe amounts are
   cryptographically bound to the signed order.
4. Test rounding boundary values on a local fork.
5. Include positive and negative control cases.
6. Record actual collateral received and USDe minted.
7. Calculate any measurable discrepancy and net economic impact.
8. Verify that all existing authorization and signature checks
   remain enabled.
9. Preserve complete test output and reproducibility details.

REQUIRED OUTCOMES:
- PASS: No exploitable impact demonstrated.
- VULNERABILITY_REPRODUCED: Complete local reproduction
  demonstrates a security-relevant impact.
- INCONCLUSIVE: Evidence is insufficient.

REQUIRED REPORT:
- Exact test commands and outputs.
- Relevant source-code locations.
- Input values and observed outputs.
- Explanation of the signed-order constraints.
- Economic-impact calculation, if any.
- Clear separation between observed facts and hypotheses.

Do not claim a vulnerability merely because a view function
returns true for a rounded value.

LIVE_TRADING = PROHIBITED
MAINNET_EXECUTION = PROHIBITED
AUTHORIZATION = NOT_AUTHORIZED
