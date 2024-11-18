#[test_only]
module reward_vault_sui::reward_vault_sui_tests;
use reward_vault_sui::reward_vault_sui::{Self, RewardVault};
use sui::test_scenario::{Self as ts, Scenario};
use sui::coin::{Self, Coin};
use sui::clock::{Self, Clock};
use sui::sui::SUI;



#[test_only]
fun test_coin(amount: u64, ts: &mut Scenario): Coin<SUI> {
    coin::mint_for_testing<SUI>(amount, ts.ctx())
}

#[test]
fun test_reward_vault_sui() {
    let mut signers_vec: vector<vector<u8>> = vector::empty();
    signers_vec.push_back(x"bd11861d13cafa8ad6e143da7034f8a907cd47a8");
    let owner = @0xCAFE;
    let project_owner = @0xFACE;
    let user = @0xFACE;
    let mut ts = ts::begin(owner);
    // prepare clock
    {
        clock::share_for_testing(clock::create_for_testing(ts.ctx()));
    };

    // create reward vault
    ts.next_tx(owner);
    let clock = ts.take_shared<Clock>();
    {
        reward_vault_sui::create_reward_vault(signers_vec, ts.ctx());
    };

    // deposit
    ts.next_tx(project_owner);
    let mut reward_vault = ts.take_shared<RewardVault>();
    let init_amount = 100;
    {
        let payment_id: u64 = 0;
        let project_id: u64 = 0;
        let coin = test_coin(init_amount, &mut ts);
        let deadline: u64 = 101;
        let signatures: vector<u8> = x"86fb8bf3f29d3a003402b425aa324da4e23820d3b327862d72d3e1ab517fad0162a7323f0269b185f4a63949b61f195bc580c3f8a23af9eba654a1ffea3035381c";
        reward_vault.deposit<SUI>(payment_id, project_id,  coin, deadline, signatures, &clock, ts.ctx());
    };

    // claim
    ts.next_tx(user);
    let claimed_amount = 20;
    {
        // TODO( cannot use duplicated payment id)
        let payment_id: u64 = 1;
        let project_id: u64 = 0;
        let deadline: u64 = 101;
        let recipient: address = user;
        let signatures: vector<u8> = x"c7f7b4022552ff1a0cfd3bf2d8a2c6a2390f0bc1267c7a17c75f94aa461a023a7245012bceafbffabd8578e605016ac6394c0a46b4ec5c685d8f9a40ad7bbabb1c";
        reward_vault.claim<SUI>(payment_id, project_id, recipient, claimed_amount, deadline, signatures, &clock, ts.ctx());
    };
    // take effect for the claim
    ts.next_tx(user);
    {
        let coin = ts.take_from_address<Coin<SUI>>(user);
        assert!(coin.value()==claimed_amount);
        ts.return_to_sender(coin);
    };

    // withdraw the remaining
    ts.next_tx(project_owner);
    let withdraw_amount: u64 = init_amount - claimed_amount;
    {
        let payment_id: u64 = 2;
        let project_id: u64 = 0;
        let deadline: u64 = 101;
        let recipient: address = project_owner;
        let signatures: vector<u8> = x"ea9c685d7f6f943806797c30af5502ae161579348a6981e475a38b02b2fddd715eab8fd00805e70f34933134a8132b4fd9f2878e2b378626b2e8c05829c7536d1c";
        reward_vault.withdraw<SUI>(payment_id, project_id, recipient, withdraw_amount, deadline, signatures, &clock, ts.ctx());
    };

    // take effect
    ts.next_tx(project_owner);
    {
        let coin = ts.take_from_address<Coin<SUI>>(project_owner);
        assert!(coin.value()==withdraw_amount);
        ts.return_to_sender(coin);
    };

    // clean all resource
    ts::return_shared(reward_vault);
    clock.destroy_for_testing();

    {
        let type_name = std::type_name::get<SUI>();
        std::debug::print(&type_name.get_module());
        let addr = sui::address::from_ascii_bytes(&type_name.get_address().into_bytes());
        std::debug::print(&addr);
        std::debug::print(&type_name.into_string());
    };

    ts.end();
}

const ENotImplemented: u64 = 0;

#[test, expected_failure(abort_code = ::reward_vault_sui::reward_vault_sui_tests::ENotImplemented)]
fun test_reward_vault_sui_fail() {
    abort ENotImplemented
}
