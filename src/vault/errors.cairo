mod VaultErrors {
    const CALLER_NOT_YAS_POOL: felt252 = 'caller_not_yas_pool';
    const CANT_MINT_ZERO: felt252 = 'cant_mint_zero';
    const CANT_BURN_ZERO: felt252 = 'cant_burn_zero';
    const BELOW_INITIAL_LIQUIDITY: felt252 = 'below_initial_liquidity';
    const REENTRANT_CALL: felt252 = 'reentrant_call';
    const INSUFFICIENT_TOKEN_0: felt252 = 'insufficient_token_0';
    const INSUFFICIENT_TOKEN_1: felt252 = 'insufficient_token_1';
    const EXCEEDS_DEADLINE: felt252 = 'tx_exceeds_deadline';
    const CALLER_NOT_KEEPER: felt252 = 'caller_not_keeper';
    const KEEPER_CANT_BE_ZERO: felt252 = 'keeper_cant_be_zero';
    const KEEPER_FEE_TOO_HIGH: felt252 = 'keeper_fee_too_high';
}
