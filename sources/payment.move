
module reward_vault_sui::payment {
    // use sui::clock::Clock;
    // use sui::coin::Coin;

    // const EExpiration: u64 = 3;

    // public struct DepositPayment<T: store> has key, store {
    //     id: UID,
    //     payment_id: u64,
    //     project_id: u64,
    //     coin: Coin<T>,
    //     deadline: u64,
    //     signatures: vector<u8>
    // }


    // // Accessors 
    // public fun validate<T>(self: &DepositPayment<T>, clock: &Clock) {
    //     assert!(self.deadline>clock.timestamp_ms(), EExpiration);
    // }

    // public fun payment_id<T>(self: &DepositPayment<T>): u64{
    //     self.payment_id
    // }

    // public fun unpack<T>(self: DepositPayment):(u64, Coin<T>) {
    //     let DepositPayment { id, payment_id, coin, ..} = self;
    //     (payment_id, coin)
    // }

    // public fun deposit<T: store>(payment_id: u64, project_id: u64, coin: Coin<T>, deadline: u64, signatures: vector<u8>, to: address, ctx: &mut TxContext){
    //     let payment: DepositPayment<T> = DepositPayment {
    //         id: object::new(ctx),
    //         payment_id,
    //         project_id,
    //         coin,
    //         deadline,
    //         signatures,
    //     };
    //     transfer::transfer(payment, to);
    // }
}