/// Module: reward_vault_sui
module reward_vault_sui::reward_vault_sui {
    use sui::vec_set::{Self, VecSet};
    use reward_vault_sui::signature_utils;
    use sui::clock::Clock;
    use sui::event;
    use sui::coin::{Self, Coin};
    use sui::dynamic_field as df;
    use std::ascii::String;

    const EInvalidOwner: u64 = 0;
    const EInvalidSigner: u64 = 1;
    const EUsedPaymentId: u64 = 2;
    const EExpiration: u64 = 3;
    const ENotExistedSigner: u64 = 4;
    const ENotExistedCoin: u64 = 5;
    const EInsufficientFunds: u64 = 6; 

    public struct RewardVault has key {
        id: UID,
        signers: VecSet<vector<u8>>,
        owner: address,
        used_payment_ids: VecSet<u64>
    }

    public struct CoinType<phantom T> has copy, drop, store {}

    public struct TokenDepositedEvent has copy, store, drop {
        payment_id: u64,
        project_id: u64,
        token: String,
        amount: u64,
        deadline: u64
    }

    public struct TokenWithdrawalEvent has copy, store, drop {
        payment_id: u64,
        project_id: u64,
        token: String,
        amount: u64,
        recipient: address,
        deadline: u64
    }

    public struct RewardsClaimedEvent has copy, store, drop {
        payment_id: u64,
        project_id: u64,
        token: String,
        amount: u64,
        recipient: address,
        deadline: u64
    }

    public fun create_reward_vault(mut signers_vec: vector<vector<u8>>, ctx: &mut TxContext){
        let mut signers = vec_set::empty();
        while(!vector::is_empty(&signers_vec)){
            let addr = vector::pop_back(&mut signers_vec);
            signers.insert(addr);
        };

        let reward_vault = RewardVault {
            id: object::new(ctx),
            signers,
            owner: ctx.sender(),
            used_payment_ids: vec_set::empty()
        };
        transfer::share_object(reward_vault);
    }

    public fun transfer_ownership(reward_vault: &mut RewardVault, new_owner: address, ctx: &TxContext) {
        assert!(reward_vault.owner == ctx.sender(), EInvalidOwner);
        reward_vault.owner = new_owner;
    }

    public fun update_signer(reward_vault: &mut RewardVault, addr: vector<u8>, add_or_remove: bool, ctx: &TxContext) {
        assert!(reward_vault.owner == ctx.sender(), EInvalidOwner);
        if(add_or_remove) {
            assert!(reward_vault.signers.contains(&addr), ENotExistedSigner);
            vec_set::remove(&mut reward_vault.signers, &addr);
        } else {
            vec_set::insert(&mut reward_vault.signers, addr);
        }
    }

    fun validate(self: &mut RewardVault, payment_id: u64, project_id: u64, account: address, coin_type_name: String, coin_amount: u64, deadline: u64, signatures: vector<u8>, clock: &Clock) {
        // check expiration
        assert!(deadline>clock.timestamp_ms(), EExpiration);

        // prevent replay
        assert!(!self.used_payment_ids.contains(&payment_id), EUsedPaymentId);
        self.used_payment_ids.insert(payment_id);

        // check signature
        let signer = signature_utils::recover_signer(account, payment_id, project_id, coin_type_name, coin_amount, deadline, signatures);
        assert!(self.signers.contains(&signer), EInvalidSigner);
    }

    public fun deposit<T>(self: &mut RewardVault, payment_id: u64, project_id: u64, coin: Coin<T>, deadline: u64, signatures: vector<u8>, clock: &Clock, ctx: &mut TxContext) {
        let coin_type_name: String = std::type_name::get<T>().into_string();
        let coin_amount = coin::value(&coin); 
        self.validate(payment_id, project_id, ctx.sender(), coin_type_name, coin_amount, deadline, signatures, clock);
        
        // collect coins from payment
        let coin_type = CoinType<T> {};
        if (df::exists_(&self.id, coin_type)){
            let balance: &mut Coin<T> = df::borrow_mut(&mut self.id, coin_type);
            coin::join(balance, coin);
        } else {
            df::add(&mut self.id, coin_type, coin);
        };

        event::emit(TokenDepositedEvent{
            payment_id,
            project_id,
            token: coin_type_name,
            amount: coin_amount,
            deadline
        });
    }

    public fun withdraw<T>(self: &mut RewardVault, payment_id: u64, project_id: u64, recipient: address, amount: u64, deadline: u64, signatures: vector<u8>, clock: &Clock, ctx: &mut TxContext) {
        let coin_type_name: String = std::type_name::get<T>().into_string();
        self.validate(payment_id, project_id, recipient, coin_type_name,  amount, deadline, signatures, clock);

        let coin_type = CoinType<T>{};
        assert!(df::exists_(&self.id, coin_type), ENotExistedCoin);
        let balance: &mut Coin<T> = df::borrow_mut(&mut self.id, coin_type);
        assert!(coin::value(balance)>=amount, EInsufficientFunds);

        let withdrawal_coin = coin::split(balance, amount, ctx);
        transfer::public_transfer(withdrawal_coin, recipient);

        event::emit(TokenWithdrawalEvent {
            payment_id,
            project_id,
            token: coin_type_name,
            amount,
            recipient,
            deadline,
        });
    }

    public fun claim<T>(self: &mut RewardVault, payment_id: u64, project_id: u64, recipient: address, amount: u64, deadline: u64, signatures: vector<u8>, clock: &Clock, ctx: &mut TxContext) {
        let coin_type_name: String = std::type_name::get<T>().into_string();
        self.validate(payment_id, project_id, recipient, coin_type_name, amount, deadline, signatures, clock);

        let coin_type = CoinType<T>{};
        assert!(df::exists_(&self.id, coin_type), ENotExistedCoin);
        let balance: &mut Coin<T> = df::borrow_mut(&mut self.id, coin_type);
        assert!(coin::value(balance)>=amount, EInsufficientFunds);

        let withdrawal_coin = coin::split(balance, amount, ctx);
        transfer::public_transfer(withdrawal_coin, recipient);

        event::emit(RewardsClaimedEvent {
            payment_id,
            project_id,
            token: coin_type_name,
            amount,
            recipient,
            deadline,
        });
    }
}
