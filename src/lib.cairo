mod vault {
    mod mini_yas_vault;
    mod events;
    mod errors;
}

mod data {
    mod calldata;
}

mod libraries {
    mod liquidity_amounts;
    mod full_math_lib;
}

// YAS Core contracts, used for tests
mod yas {
    mod yas_pool;
    mod yas_router;
    mod yas_factory;
}


mod token {
    mod erc20;
    mod mock_erc20;
}
