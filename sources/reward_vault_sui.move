/// Module: reward_vault_sui
module reward_vault_sui::reward_vault_sui {
    use sui::vec_set::{Self, VecSet};
    use reward_vault_sui::signature_utils;
    use sui::clock::Clock;
    use sui::event;
    use sui::table::{Self, Table};
    use sui::coin::{Self, Coin};
    use sui::dynamic_field as df;
    use sui::address;
    use std::ascii::String;
    use std::bcs;

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
        used_payment_ids: Table<u64, bool>
    }

    public struct CoinType<phantom T> has copy, drop, store {}

    public enum ActionType has drop {
        Deposit,
        Withdraw,
        Claim
    }

    public struct RewardVaultCreatedEvent has copy, store, drop {
        reward_vault_id: address,
        owner: address,
        signers: vector<vector<u8>>
    }

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

        let owner = ctx.sender();

        let reward_vault = RewardVault {
            id: object::new(ctx),
            signers,
            owner,
            used_payment_ids: table::new<u64, bool>(ctx)
        };
        let reward_vault_id = object::id_address<RewardVault>(&reward_vault);
        transfer::share_object(reward_vault);

        event::emit(RewardVaultCreatedEvent{
            reward_vault_id,
            owner,
            signers: signers_vec,
        });
    }

    public fun transfer_ownership(reward_vault: &mut RewardVault, new_owner: address, ctx: &mut TxContext) {
        assert!(reward_vault.owner == ctx.sender(), EInvalidOwner);
        reward_vault.owner = new_owner;
    }

    public fun update_signer(reward_vault: &mut RewardVault, addr: vector<u8>, add_or_remove: bool, ctx: &mut TxContext) {
        assert!(reward_vault.owner == ctx.sender(), EInvalidOwner);
        if(add_or_remove) {
            assert!(reward_vault.signers.contains(&addr), ENotExistedSigner);
            vec_set::remove(&mut reward_vault.signers, &addr);
        } else {
            vec_set::insert(&mut reward_vault.signers, addr);
        }
    }

    fun encode_coin_type_name(coin_type_name: String): vector<u8> {
        let len = address::length() * 2;
        let str_bytes = coin_type_name.as_bytes();
        let mut addr_bytes = vector[];
        let mut i = 0;

        // Read `len` bytes from the type name and push them to addr_bytes.
        while (i < len) {
            addr_bytes.push_back(str_bytes[i]);
            i = i + 1;
        };
        let mut res = sui::hex::decode(addr_bytes);
        let total_len = str_bytes.length();
        while(i < total_len) {
            res.push_back(str_bytes[i]);
            i = i + 1;
        };
        res
    }

    fun encode_msg(payment_id: u64, project_id: u64, account: address, action_type: ActionType, coin_type_name: String, coin_amount: u64, deadline: u64): vector<u8> {
        let mut msg: vector<u8> = vector::empty();
        msg.append(bcs::to_bytes(&payment_id));
        msg.append(bcs::to_bytes(&project_id));

        msg.append(address::to_bytes(account));
        msg.append(bcs::to_bytes(&action_type));
        // package_id::module_id::coin_type, for example get 0x02::sui::SUI for SUI
        msg.append(encode_coin_type_name(coin_type_name));
        msg.append(bcs::to_bytes(&coin_amount));
        msg.append(bcs::to_bytes(&deadline));

        msg
    }

    fun validate(self: &mut RewardVault, payment_id: u64, project_id: u64, account: address, action_type: ActionType, coin_type_name: String, coin_amount: u64, deadline: u64, signatures: vector<u8>, clock: &Clock) {
        // check expiration
        assert!(deadline>clock.timestamp_ms(), EExpiration);

        // prevent replay
        assert!(!self.used_payment_ids.contains(payment_id), EUsedPaymentId);
        self.used_payment_ids.add(payment_id, true);

        // check signature
        let msg = encode_msg(payment_id, project_id, account, action_type, coin_type_name, coin_amount, deadline);
        let signer = signature_utils::recover_signer(msg, signatures);
        assert!(self.signers.contains(&signer), EInvalidSigner);
    }

    public fun deposit<T>(self: &mut RewardVault, payment_id: u64, project_id: u64, coin: Coin<T>, deadline: u64, signatures: vector<u8>, clock: &Clock, ctx: &mut TxContext) {
        let coin_type_name: String = std::type_name::get<T>().into_string();
        let coin_amount = coin::value(&coin);
        self.validate(payment_id, project_id, ctx.sender(), ActionType::Deposit, coin_type_name, coin_amount, deadline, signatures, clock);

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
        self.validate(payment_id, project_id, recipient, ActionType::Withdraw, coin_type_name,  amount, deadline, signatures, clock);

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
        self.validate(payment_id, project_id, recipient, ActionType::Claim, coin_type_name, amount, deadline, signatures, clock);

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
