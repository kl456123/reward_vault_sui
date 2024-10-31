/// Module: reward_vault_sui
module reward_vault_sui::reward_vault_sui {
    use sui::vec_set::{Self, VecSet};
    use reward_vault_sui::signature_utils;
    use sui::clock::Clock;
    use sui::coin::{Self, Coin, CoinMetadata};
    use sui::dynamic_field as df;

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

    fun validate<T>(self: &mut RewardVault, payment_id: u64, project_id: u64, account: address, coin_metadata: &CoinMetadata<T>, coin_amount: u64, deadline: u64, signatures: vector<u8>, clock: &Clock) {
        // check expiration
        assert!(deadline>clock.timestamp_ms(), EExpiration);

        // prevent replay
        assert!(!self.used_payment_ids.contains(&payment_id), EUsedPaymentId);
        self.used_payment_ids.insert(payment_id);

        // check signature
        let signer = signature_utils::recover_signer<T>(account, payment_id, project_id, coin_metadata, coin_amount, deadline, signatures);
        assert!(self.signers.contains(&signer), EInvalidSigner);
    }

    public fun deposit<T: store >(self: &mut RewardVault, payment_id: u64, project_id: u64, coin_metadata: &CoinMetadata<T>, coin: Coin<T>, deadline: u64, signatures: vector<u8>, clock: &Clock, ctx: &mut TxContext) {
        self.validate(payment_id, project_id, ctx.sender(), coin_metadata,  coin::value(&coin), deadline, signatures, clock);
        
        // collect coins from payment
        let coin_type = CoinType<T> {};
        if (df::exists_(&self.id, coin_type)){
            let balance: &mut Coin<T> = df::borrow_mut(&mut self.id, coin_type);
            coin::join(balance, coin);
        } else {
            df::add(&mut self.id, coin_type, coin);
        }
    }

    public fun withdraw<T: store>(self: &mut RewardVault, payment_id: u64, project_id: u64, coin_metadata: &CoinMetadata<T>, amount: u64, deadline: u64, signatures: vector<u8>, clock: &Clock, ctx: &mut TxContext): Coin<T> {
        self.validate(payment_id, project_id, ctx.sender(), coin_metadata,  amount, deadline, signatures, clock);

        let coin_type = CoinType<T>{};
        assert!(df::exists_(&self.id, coin_type), ENotExistedCoin);
        let balance: &mut Coin<T> = df::borrow_mut(&mut self.id, coin_type);
        assert!(coin::value(balance)>=amount, EInsufficientFunds);

        coin::split(balance, amount, ctx)
    }

    public fun claim<T: store>(self: &mut RewardVault, payment_id: u64, project_id: u64, coin_metadata: &CoinMetadata<T>, amount: u64, deadline: u64, signatures: vector<u8>, clock: &Clock, ctx: &mut TxContext): Coin<T> {
        self.validate(payment_id, project_id, ctx.sender(), coin_metadata,  amount, deadline, signatures, clock);

        let coin_type = CoinType<T>{};
        assert!(df::exists_(&self.id, coin_type), ENotExistedCoin);
        let balance: &mut Coin<T> = df::borrow_mut(&mut self.id, coin_type);
        assert!(coin::value(balance)>=amount, EInsufficientFunds);

        coin::split(balance, amount, ctx)
    }
}
