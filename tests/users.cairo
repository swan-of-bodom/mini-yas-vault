use starknet::{ContractAddress, contract_address_const};

// For fork tests, setup borrower with LP token balance, and usdc whale

fn admin() -> ContractAddress {
    0xc0ffee.try_into().unwrap()
}

fn depositor() -> ContractAddress {
    111.try_into().unwrap()
}

fn depositor_two() -> ContractAddress {
    222.try_into().unwrap()
}
