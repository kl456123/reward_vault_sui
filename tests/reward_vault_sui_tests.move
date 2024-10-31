#[test_only]
module reward_vault_sui::reward_vault_sui_tests;
use reward_vault_sui::reward_vault_sui;

const ENotImplemented: u64 = 0;

#[test]
fun test_reward_vault_sui() {
    // pass
}

#[test, expected_failure(abort_code = ::reward_vault_sui::reward_vault_sui_tests::ENotImplemented)]
fun test_reward_vault_sui_fail() {
    abort ENotImplemented
}