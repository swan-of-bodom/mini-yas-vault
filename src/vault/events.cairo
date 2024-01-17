mod VaultEvents {
    use starknet::{ContractAddress};

    #[derive(Drop, starknet::Event)]
    struct Transfer {
        from: ContractAddress,
        to: ContractAddress,
        value: u128
    }

    #[derive(Drop, starknet::Event)]
    struct Approval {
        owner: ContractAddress,
        spender: ContractAddress,
        value: u128
    }

    #[derive(Drop, starknet::Event)]
    struct Deposit {
        caller: ContractAddress,
        recipient: ContractAddress,
        liquidity: u128,
        shares: u128,
        amount_0: u256,
        amount_1: u256
    }

    #[derive(Drop, starknet::Event)]
    struct Withdraw {
        caller: ContractAddress,
        recipient: ContractAddress,
        owner: ContractAddress,
        liquidity: u128,
        shares: u128,
        amount_0: u256,
        amount_1: u256
    }

    #[derive(Drop, starknet::Event)]
    struct NewKeeperFee {
        old_keeper_fee: u256,
        new_keeper_fee: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct NewKeeper {
        old_keeper: ContractAddress,
        new_keeper: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct PayKeeperFee {
        keeper: ContractAddress,
        fee_token_0: u256,
        fee_token_1: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Compound {
        liquidity: u128,
        amount_0: u256,
        amount_1: u256,
    }
}
