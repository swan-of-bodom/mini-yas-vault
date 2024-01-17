use snforge_std::{
    declare, start_prank, stop_prank, ContractClassTrait, ContractClass, CheatTarget, PrintTrait
};
use starknet::{ContractAddress, contract_address_const};
use mini_yas_vault::yas::{
    yas_pool::{IYASPoolDispatcher, IYASPoolDispatcherTrait},
    yas_factory::{IYASFactoryDispatcher, IYASFactoryDispatcherTrait}
};
use mini_yas_vault::token::mock_erc20::{IERC20MockDispatcher, IERC20MockDispatcherTrait};

use tests::users::{admin, depositor, depositor_two};

#[test]
fn test_initial_deployment() {
    let factory = deploy_yas_factory();
    let (token0, token1) = deploy_mock_tokens();
    let pool = deploy_yas_pool(factory, token0, token1, 3000);

    assert(pool.contract_address.is_non_zero(), 'yas_pool_is_zero');
}
#[test]
fn test_initial_deployment() {
    let factory = deploy_yas_factory();
    let (token0, token1) = deploy_mock_tokens();
    let pool = deploy_yas_pool(factory, token0, token1, 3000);

    assert(pool.contract_address.is_non_zero(), 'yas_pool_is_zero');
}


fn deploy_yas_pool(
    factory: IYASFactoryDispatcher,
    token0: IERC20MockDispatcher,
    token1: IERC20MockDispatcher,
    fee: u32
) -> IYASPoolDispatcher {
    let contract_address = factory
        .create_pool(token0.contract_address, token1.contract_address, 3000);
    IYASPoolDispatcher { contract_address }
}

fn deploy_mock_tokens() -> (IERC20MockDispatcher, IERC20MockDispatcher) {
    let declared_token = declare('ERC20Mock');
    // Token0
    let name = 'Token0';
    let symbol = 'TK0';
    let constructor_calldata = array![name, symbol];
    let contract_address = declared_token.deploy(@constructor_calldata).unwrap();
    let token0 = IERC20MockDispatcher { contract_address };

    // Token1
    let name = 'Token1';
    let symbol = 'TK1';
    let constructor_calldata = array![name, symbol];
    let contract_address = declared_token.deploy(@constructor_calldata).unwrap();
    let token1 = IERC20MockDispatcher { contract_address };

    (token0, token1)
}

fn deploy_yas_factory() -> IYASFactoryDispatcher {
    let declared_pool = declare('YASPool');
    let admin = admin();
    let constructor_calldata = array![admin.into(), declared_pool.class_hash.into()];
    let declared_factory = declare('YASFactory');
    let contract_address = declared_factory.deploy(@constructor_calldata).unwrap();
    IYASFactoryDispatcher { contract_address }
}
