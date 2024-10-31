module reward_vault_sui::signature_utils {

    use sui::ecdsa_k1;
    use sui::coin::CoinMetadata;

    public fun recover_signer<T>(account: address, payment_id: u64, project_id: u64, coin_metadata: &CoinMetadata<T>, coin_amount: u64, deadline: u64, signature: vector<u8>): vector<u8> {
        let mut msg: vector<u8> = vector::empty();
        msg.append(payment_id.to_string().into_bytes());
        msg.append(project_id.to_string().into_bytes());
        msg.append(account.to_string().into_bytes());
        msg.append(object::id_bytes(coin_metadata));
        msg.append(coin_amount.to_string().into_bytes());
        msg.append(deadline.to_string().into_bytes());
        ecdsa_k1::secp256k1_ecrecover(&signature, &msg, 0)
    }
}