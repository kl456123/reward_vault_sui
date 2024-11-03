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
        let signatures: vector<u8> = x"a97ada8d607a863b04d305578c348b139e32aa71f969e921168044d2ff1b3d6213c7e70efc10afb2b61b0f0bcd5efc2d306b1d9132d3286dc340e769b4780dca1c";
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
        let signatures: vector<u8> = x"2d74babc91e5a3650bb245e0769fddff6e56d2532602e7d49b79a05ccd43583c4bad6c9d9df902044075eb8c4f01dedca90c84162cb4465e00dd37207eb35b771c";
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
        let signatures: vector<u8> = x"6c042a1a2bcc23fa113884f3d2ed61b50842ddd7103c4e5f0f97e679608f4e2d1d02d15cd00695e9858aec6e07fbb8a05ba58fedba82408a0b20e00fc97e49ee1b";
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
