use starknet::{ContractAddress};

/// Deposit struct for YAS vault.
///
/// # Arguments
/// * `liquidity` - Amount of YAS liquidity to mint
/// * `amount_0_min` - Minimum acceptable amount of token0, for slippage
/// * `amount_1_min` - Minimum acceptable amount of token1, for slippage
/// * `recipient` - Recipient address of vault shares
/// * `deadline` - Timestamp deadline for the transaction.
#[derive(Drop, Serde)]
struct DepositParams {
liquidity: u128,
    amount_0_min: u256,
    amount_1_min: u256,
    recipient: ContractAddress,
    deadline: u64,
}

/// Withdrawal struct for YAS vault.
///
/// # Arguments
/// * `shares` - The amount of shares to burn
/// * `amount_0_min` - Minimum acceptable amount of token0 to receive.
/// * `amount_1_min` - Minimum acceptable amount of token1 to receive.
/// * `owner` - Address of the MYV shares owner.
/// * `recipient` - The recipient of token0 and token1
/// * `deadline` - Timestamp deadline for the transaction.
#[derive(Drop, Serde)]
struct WithdrawParams {
    amount_0_min: u256,
    amount_1_min: u256,
    owner: ContractAddress,
    recipient: ContractAddress,
    deadline: u64,
    shares: u128,
}
