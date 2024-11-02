module reward_vault_sui::signature_utils {

    use sui::ecdsa_k1;
    use sui::address;
    use std::debug;
    use std::ascii::String;
    use std::bcs;

    public fun recover_signer(account: address, payment_id: u64, project_id: u64, coin_type_name: String, coin_amount: u64, deadline: u64, signature: vector<u8>): vector<u8> {
        let mut msg: vector<u8> = vector::empty();
        msg.append(bcs::to_bytes(&payment_id));
        msg.append(bcs::to_bytes(&project_id));
        
        msg.append(address::to_bytes(account));
        // package_id::module_id::coin_type, for example get 0x02::sui::SUI for SUI
        msg.append(coin_type_name.into_bytes());
        msg.append(bcs::to_bytes(&coin_amount));
        msg.append(bcs::to_bytes(&deadline));

        debug::print(&bcs::to_bytes(&payment_id));
        debug::print(&bcs::to_bytes(&project_id));
        debug::print(&address::to_bytes(account));
        debug::print(&bcs::to_bytes(&coin_amount));
        debug::print(&bcs::to_bytes(&deadline));

        debug::print(&msg);
        debug::print(&signature);
        let addr = ecrecover_to_eth_address(signature, msg);
        debug::print(&addr);
        addr
    }

    /// Recover the Ethereum address using the signature and message, assuming the signature was                                                                  
    /// produced over the Keccak256 hash of the message. Output an object with the recovered address                                                              
    /// to recipient.                                                                                                                                             
    public fun ecrecover_to_eth_address(                                                                                                                          
        mut signature: vector<u8>,                                                                                                                                
        msg: vector<u8>,                                                                                                                                          
    ): vector<u8> {                                                                                                                                                           
        // Normalize the last byte of the signature to be 0 or 1.                                                                                                 
        let v = &mut signature[64];                                                                                                                               
        if (*v == 27) {                                                                                                                                           
            *v = 0;                                                                                                                                               
        } else if (*v == 28) {                                                                                                                                    
            *v = 1;                                                                                                                                               
        } else if (*v > 35) {                                                                                                                                     
            *v = (*v - 1) % 2;                                                                                                                                    
        };                                                                                                                                                        
                                                                                                                                                                  
        // Ethereum signature is produced with Keccak256 hash of the message, so the last param is                                                                
        // 0.                                                                                                                                                     
        let pubkey = ecdsa_k1::secp256k1_ecrecover(&signature, &msg, 0);                                                                                          
        let uncompressed = ecdsa_k1::decompress_pubkey(&pubkey);                                                                                                  
                                                                                                                                                                  
        // Take the last 64 bytes of the uncompressed pubkey.                                                                                                     
        let mut uncompressed_64 = vector[];                                                                                                                       
        let mut i = 1;                                                                                                                                            
        while (i < 65) {                                                                                                                                          
            uncompressed_64.push_back(uncompressed[i]);                                                                                                           
            i = i + 1;                                                                                                                                            
        };                                                                                                                                                        
                                                                                                                                                                  
        // Take the last 20 bytes of the hash of the 64-bytes uncompressed pubkey.                                                                                
        let hashed = sui::hash::keccak256(&uncompressed_64);                                                                                                      
        let mut addr = vector[];                                                                                                                                  
        let mut i = 12;                                                                                                                                           
        while (i < 32) {                                                                                                                                          
            addr.push_back(hashed[i]);                                                                                                                            
            i = i + 1;                                                                                                                                            
        };
        addr
    }
}