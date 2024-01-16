//! Mini YAS Vault.

use mini_yas_vault::data::calldata::{DepositParams, WithdrawParams};
use starknet::{ContractAddress};
use yas_core::libraries::position::{Info as PositionInfo, PositionKey};
use yas_core::contracts::yas_pool::{IYASPoolDispatcher, IYASPoolDispatcherTrait, Slot0};
use yas_core::numbers::fixed_point::core::{FixedTrait, FixedType};

#[starknet::interface]
trait IMiniYasVault<TContractState> {
    // ----------------------------------------------------------------------------------------
    //                                         ERC20
    // ----------------------------------------------------------------------------------------

    // Open zeppeplin's implementation of erc20 with u128
    // https://github.com/OpenZeppelin/cairo-contracts/blob/main/src/token/erc20/erc20.cairo
    //
    // commit-hash: 841a073

    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn decimals(self: @TContractState) -> u8;
    fn total_supply(self: @TContractState) -> u128;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u128;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u128;
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u128) -> bool;
    fn transfer_from(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u128
    ) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u128) -> bool;

    // ----------------------------------------------------------------------------------------
    //                                      MINI YAS VAULT
    // ----------------------------------------------------------------------------------------

    /// Get the YAS pool contract address for this vault
    fn pool(self: @TContractState) -> ContractAddress;
    /// The address of the pool's token0
    fn token_0(self: @TContractState) -> ContractAddress;
    /// The address of the pool's token1
    fn token_1(self: @TContractState) -> ContractAddress;
    /// The YAS pool's fee
    fn fee(self: @TContractState) -> u32;

    /// The current keeper's address, managing rebalances
    fn keeper(self: @TContractState) -> ContractAddress;
    /// The current fee that the keeper receives from each compound
    fn keeper_fee(self: @TContractState) -> u128;

    /// Gets the current vault's position key struct from YAS pool
    fn get_position_key(self: @TContractState) -> PositionKey;
    /// Gets the current vault's position info struct from YAS pool
    fn get_position_info(self: @TContractState) -> PositionInfo;
    /// Gets the Slot0 struct from YAS pool
    fn get_slot_0(self: @TContractState) -> Slot0;

    /// Gets the total liquidity we own in YAS pool
    fn total_liquidity(self: @TContractState) -> u128;
    /// Converts YAS liquidity to MYV shares
    fn liquidity_for_shares(self: @TContractState, liquidity: u128) -> u128;
    /// Converts MYV shares to YAS liquidity
    fn shares_for_liquidity(self: @TContractState, shares: u128) -> u128;

    /// Getter to view the total amount of underlying the vault owns (position + fees + balance)
    ///
    /// # Returns
    /// * The total amount of token0 the vault owns
    /// * The total amount of token1 the vault owns
    fn get_total_amounts(self: @TContractState) -> (u256, u256);

    /// Getter to view the total amount of token0 and token1 the vault has in the active position
    ///
    /// # Returns
    /// * The amount of token0 the vault owns in the active position
    /// * The amount of token1 the vault owns in the active position
    fn get_position_amounts(self: @TContractState) -> (u256, u256);

    /// Getter to view unclaimed fees
    ///
    /// # Returns
    /// * The amount of token0 the vault can collect from YAS pool
    /// * The amount of token1 the vault can collect from YAS pool
    fn get_position_fees(self: @TContractState) -> (u256, u256);

    /// TODO
    /// Getter to view the total amount of token0 and token1 the vault has in the active position
    ///
    /// # Arguments
    /// * The price of the pool as a sqrt(token1/token0) FixedType value
    ///
    /// # Returns
    /// * The amount of token0 the vault owns at `sqrt_price_X96`
    /// * The amount of token1 the vault owns at `sqrt_price_X96`
    /// fn get_amounts_at_price(self: @TContractState, sqrt_price_X96: FixedType) -> (u256, u256);

    /// Deposits token0 and token1 amounts and mints vault shares
    fn deposit(ref self: TContractState, deposit_params: DepositParams) -> u128;

    /// Withdraw from YAS pool
    fn withdraw(ref self: TContractState, withdraw_params: WithdrawParams) -> (u256, u256);

    /// Updates the keeper address.
    ///
    /// # Arguments
    /// * `new_keeper` - The address of the new keeper
    fn set_new_keeper(ref self: TContractState, new_keeper: ContractAddress);
    /// Updates the keeper fee.
    ///
    /// # Arguments
    /// * `new_keeper_fee` - The new fee for the keeper.
    fn set_keeper_fee(ref self: TContractState, new_keeper_fee: u128);

    /// Callback to mint liquidity at YAS pool
    fn yas_mint_callback(
        ref self: TContractState, amount_0_owed: u256, amount_1_owed: u256, data: Array<felt252>
    );
}

// Mini-Yas-Vault Contract
#[starknet::contract]
mod MiniYasVault {
    // ----------------------------------------------------------------------------------------
    //                                       1. IMPORTS
    // ----------------------------------------------------------------------------------------

    //  YAS CORE IMPORTS    
    use yas_core::contracts::yas_pool::{IYASPoolDispatcher, IYASPoolDispatcherTrait, Slot0};
    use yas_core::utils::math_utils::{FullMath as YASMath, Constants};
    use yas_core::libraries::{
        tick_math::TickMath::{get_tick_at_sqrt_ratio, get_sqrt_ratio_at_tick},
        position::{Info as PositionInfo, PositionKey}
    };
    use yas_core::numbers::{
        signed_integer::{i32::i32, integer_trait::IntegerTrait},
        fixed_point::core::{FixedTrait, FixedType}
    };

    //  MINI YAS VAULT IMPORTS    
    use mini_yas_vault::token::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use mini_yas_vault::data::calldata::{DepositParams, WithdrawParams};
    use mini_yas_vault::vault::errors::VaultErrors as Errors;
    use mini_yas_vault::libraries::{
        full_math_lib::FullMathLib::{FixedPointMathLibTrait}, liquidity_amounts::{LiquidityAmounts}
    };

    //  STARKNET CORE IMPORTS    
    use starknet::{
        ContractAddress, get_block_timestamp, get_contract_address, get_caller_address,
        Felt252TryIntoContractAddress
    };

    // ----------------------------------------------------------------------------------------
    //                                       2. EVENTS
    // ----------------------------------------------------------------------------------------

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
        Deposit: Deposit,
        Withdraw: Withdraw,
        NewKeeper: NewKeeper,
        NewKeeperFee: NewKeeperFee
    }

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
        old_keeper_fee: u128,
        new_keeper_fee: u128,
    }

    #[derive(Drop, starknet::Event)]
    struct NewKeeper {
        old_keeper: ContractAddress,
        new_keeper: ContractAddress,
    }

    // ----------------------------------------------------------------------------------------
    //                                       3. STORAGE
    // ----------------------------------------------------------------------------------------

    #[storage]
    struct Storage {
        // Re-entrant guard
        guard: bool,
        // Total supply of vault shares
        total_supply: u128,
        // Balances mapping
        balances: LegacyMap<ContractAddress, u128>,
        // Allowances mapping
        allowances: LegacyMap<(ContractAddress, ContractAddress), u128>,
        // Address of the YAS pool
        yas_pool: IYASPoolDispatcher,
        // The YAS pool's token0
        token_0: IERC20Dispatcher,
        // The YAS pool's token1
        token_1: IERC20Dispatcher,
        // The vault's current lower tick
        tick_lower: i32,
        // The vault's current upper tick
        tick_upper: i32,
        // The fee the charges for each swap
        fee: u32,
        // The keeper of this vault, in charge of rebalances, compounding, etc.
        keeper: ContractAddress,
        // Fee paid to the keeper of the vault (can be 0)
        keeper_fee: u128
    }

    // Unsiwap uses minimum deposit for first depositor only
    const MIN_YAS_LIQUIDITY: u128 = 1000;

    // The maximum fee that the keeper can receive
    const MAX_KEEPER_FEE: u128 = 100_000_000_000_000_000; // 10%

    // ----------------------------------------------------------------------------------------
    //                                    4. CONSTURCTOR
    // ----------------------------------------------------------------------------------------

    #[constructor]
    fn constructor(ref self: ContractState, yas_pool: IYASPoolDispatcher,) {
        self.yas_pool.write(yas_pool);
        self.token_0.write(IERC20Dispatcher { contract_address: yas_pool.token_0() });
        self.token_1.write(IERC20Dispatcher { contract_address: yas_pool.token_1() });
    }

    // ----------------------------------------------------------------------------------------
    //                                    5. IMPLEMENTATION
    // ----------------------------------------------------------------------------------------

    #[external(v0)]
    impl MiniYasVaultImpl of super::IMiniYasVault<ContractState> {
        // ------------------------------
        //   Constant Functions
        // ------------------------------

        /// # Implementation
        /// * IERC20
        fn name(self: @ContractState) -> felt252 {
            'Mini Yas Vault'
        }

        /// # Implementation
        /// * IERC20
        fn symbol(self: @ContractState) -> felt252 {
            'MYV: ' + self.token_0.read().symbol() + '/' + self.token_1.read().symbol()
        }

        /// # Implementation
        /// * IERC20
        fn decimals(self: @ContractState) -> u8 {
            18
        }

        /// # Implementation
        /// * IERC20
        fn total_supply(self: @ContractState) -> u128 {
            self.total_supply.read()
        }

        /// # Implementation
        /// * IERC20
        fn balance_of(self: @ContractState, account: ContractAddress) -> u128 {
            self.balances.read(account)
        }

        /// # Implementation
        /// * IERC20
        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> u128 {
            self.allowances.read((owner, spender))
        }

        /// # Implementation
        /// * IERC20
        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u128) -> bool {
            let sender = get_caller_address();
            self._transfer(sender, recipient, amount);
            true
        }

        /// # Implementation
        /// * IERC20
        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u128
        ) -> bool {
            let caller = get_caller_address();
            self._spend_allowance(sender, caller, amount);
            self._transfer(sender, recipient, amount);
            true
        }

        /// # Implementation
        /// * IERC20
        fn approve(ref self: ContractState, spender: ContractAddress, amount: u128) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, amount);
            true
        }

        /// # Implementation
        /// * IMiniYasVault
        fn pool(self: @ContractState) -> ContractAddress {
            self.yas_pool.read().contract_address
        }

        /// # Implementation
        /// * IMiniYasVault
        fn token_0(self: @ContractState) -> ContractAddress {
            self.token_0.read().contract_address
        }

        /// # Implementation
        /// * IMiniYasVault
        fn token_1(self: @ContractState) -> ContractAddress {
            self.token_1.read().contract_address
        }

        /// # Implementation
        /// * IMiniYasVault
        fn fee(self: @ContractState) -> u32 {
            self.fee.read()
        }

        /// # Implementation
        /// * IMiniYasVault
        fn keeper(self: @ContractState) -> ContractAddress {
            self.keeper.read()
        }

        /// # Implementation
        /// * IMiniYasVault
        fn keeper_fee(self: @ContractState) -> u128 {
            self.keeper_fee.read()
        }

        /// # Implementation
        /// * IMiniYasVault
        fn get_slot_0(self: @ContractState) -> Slot0 {
            self.yas_pool.read().get_slot_0()
        }

        /// # Implementation
        /// * IMiniYasVault
        fn total_liquidity(self: @ContractState) -> u128 {
            self.get_position_info().liquidity
        }

        /// # Implementation
        /// * IMiniYasVault
        fn get_total_amounts(self: @ContractState) -> (u256, u256) {
            // The amount of token0/token1 on the active position
            let (position_0, position_1) = self.get_position_amounts();
            // The amount of token0/token1 fees that we can claim 
            let (fee_0, fee_1) = self.get_position_fees();

            (position_0 + fee_0, position_1 + fee_1)
        }

        /// # Implementation
        /// * IMiniYasVault
        fn get_position_amounts(self: @ContractState) -> (u256, u256) {
            let position_key = self.get_position_key();

            let liquidity = self.yas_pool.read().get_position(position_key).liquidity;

            (10, 10)
        //LiquidityAmounts::get_amounts_for_liquidity(
        //    self.get_slot_0().sqrt_price_X96,
        //    get_sqrt_ratio_at_tick(position_key.tick_lower),
        //    get_sqrt_ratio_at_tick(position_key.tick_upper),
        //    liquidity,
        //)
        }

        /// # Implementation
        /// * IYASPool
        fn get_position_fees(self: @ContractState) -> (u256, u256) {
            let yas_pool = self.yas_pool.read();

            // Get global fees stored for token0 and token1
            let (fee_growth_global_0, fee_growth_global_1) = yas_pool.get_fee_growth_globals();

            // Get the lower and upper tick structs given the vault's position
            let position_key = self.get_position_key();
            let tick_lower_info = yas_pool.get_tick(position_key.tick_lower);
            let tick_upper_info = yas_pool.get_tick(position_key.tick_upper);

            // Get the active tick in YAS pool
            let tick = self.get_slot_0().tick;

            // Position info
            let position_info = self.yas_pool.read().get_position(position_key);

            // Token0 unclaimed fees
            let unclaimed_fees_0 = self
                ._unclaimed_token_fees(
                    fee_growth_global_0,
                    tick_lower_info.fee_growth_outside_0X128,
                    tick_upper_info.fee_growth_outside_0X128,
                    tick,
                    position_key.tick_lower,
                    position_key.tick_upper,
                    position_info.liquidity,
                    position_info.fee_growth_inside_0_last_X128,
                );

            // Token1 unclaimed fees
            let unclaimed_fees_1 = self
                ._unclaimed_token_fees(
                    fee_growth_global_1,
                    tick_lower_info.fee_growth_outside_1X128,
                    tick_upper_info.fee_growth_outside_1X128,
                    tick,
                    position_key.tick_lower,
                    position_key.tick_upper,
                    position_info.liquidity,
                    position_info.fee_growth_inside_0_last_X128,
                );

            (unclaimed_fees_0, unclaimed_fees_1)
        }

        /// # Implementation
        /// * IMiniYasVault
        #[inline(always)]
        fn get_position_info(self: @ContractState) -> PositionInfo {
            self.yas_pool.read().get_position(self.get_position_key())
        }

        /// # Implementation
        /// * IMiniYasVault
        #[inline(always)]
        fn get_position_key(self: @ContractState) -> PositionKey {
            PositionKey {
                owner: get_contract_address(),
                tick_lower: self.tick_lower.read(),
                tick_upper: self.tick_upper.read(),
            }
        }

        /// # Implementation
        /// * IMiniYasVault
        #[inline(always)]
        fn liquidity_for_shares(self: @ContractState, liquidity: u128) -> u128 {
            let total_supply = self.total_supply.read();

            if total_supply.is_zero() {
                // ERROR: Check for minimum deposit for first depositor only, prevent inflation attack.
                assert(liquidity > MIN_YAS_LIQUIDITY, Errors::BELOW_INITIAL_LIQUIDITY);

                return liquidity;
            }

            liquidity.full_mul_div(total_supply, self.total_liquidity())
        }

        /// # Implementation
        /// * IMiniYasVault
        #[inline(always)]
        fn shares_for_liquidity(self: @ContractState, shares: u128) -> u128 {
            let total_supply = self.total_supply.read();

            if total_supply.is_zero() {
                return shares;
            }

            shares.full_mul_div(self.total_liquidity(), total_supply)
        }

        // ------------------------------
        //   Non-Constant Functions
        // ------------------------------

        /// # Security
        /// * Non-Reentrant
        /// * Deadline
        ///
        /// # Implementation
        /// * IMiniYasVault
        fn deposit(ref self: ContractState, deposit_params: DepositParams) -> u128 {
            self._check_and_lock(deposit_params.deadline);

            // Check the maximum liquidity we can mint given deposit params.
            let position_key = self.get_position_key();

            let liquidity = LiquidityAmounts::get_liquidity_for_amounts(
                self.get_slot_0().sqrt_price_X96,
                get_sqrt_ratio_at_tick(position_key.tick_lower),
                get_sqrt_ratio_at_tick(position_key.tick_upper),
                deposit_params.amount_0,
                deposit_params.amount_1
            );

            // Calculate shares for the max liquidity given deposit params.
            let shares = self.liquidity_for_shares(liquidity);
            // ERROR: Check for zero shares.
            assert(shares > 0, Errors::CANT_MINT_ZERO);

            // Payer is always the payer of the tokens.
            let caller = get_caller_address();

            let (amount_0, amount_1) = self
                .yas_pool
                .read()
                .mint(
                    get_contract_address(),
                    position_key.tick_lower,
                    position_key.tick_upper,
                    liquidity,
                    array![caller.into()]
                );

            // ERROR: Check for slippage.
            assert(amount_0 > deposit_params.amount_0_min, Errors::INSUFFICIENT_TOKEN_0);
            assert(amount_1 > deposit_params.amount_1_min, Errors::INSUFFICIENT_TOKEN_1);

            // Mint MYV shares.
            self._mint(deposit_params.recipient, shares);

            self._unlock();

            self
                .emit(
                    Deposit {
                        caller,
                        recipient: deposit_params.recipient,
                        liquidity,
                        shares,
                        amount_0,
                        amount_1
                    }
                );

            shares
        }

        /// # Security
        /// * Non-Reentrant
        /// * Deadline
        ///
        /// # Implementation
        /// * IMiniYasVault
        fn withdraw(ref self: ContractState, withdraw_params: WithdrawParams) -> (u256, u256) {
            self._check_and_lock(withdraw_params.deadline);

            // Check for allowance
            let caller = get_caller_address();

            if caller != withdraw_params.owner {
                self._spend_allowance(withdraw_params.owner, caller, withdraw_params.shares);
            }

            // Calculate YAS liquidity for the shares burnt.
            let liquidity = self.shares_for_liquidity(withdraw_params.shares);
            // ERROR: Check for zero liquidity.
            assert(liquidity > 0, Errors::CANT_BURN_ZERO);

            // Burn MYV shares.
            self._burn(withdraw_params.owner, withdraw_params.shares);

            // Burn liquidity from the pool.
            let position_key = self.get_position_key();

            let (amount_0, amount_1) = self
                .yas_pool
                .read()
                .burn(position_key.tick_lower, position_key.tick_upper, liquidity);

            /// Gotta do collect here and pay assets...

            self._unlock();

            self
                .emit(
                    Withdraw {
                        caller,
                        recipient: withdraw_params.recipient,
                        owner: withdraw_params.owner,
                        liquidity,
                        shares: withdraw_params.shares,
                        amount_0,
                        amount_1
                    }
                );

            (amount_0, amount_1)
        }

        /// # Security
        /// * Only-Keeper
        ///
        /// # Implementation
        /// * IMiniYasVault
        fn set_keeper_fee(ref self: ContractState, new_keeper_fee: u128) {
            // Only keeper.
            self._check_keeper();

            // ERROR: Max keeper fee is 10% (ie. 0.1e18)
            assert(new_keeper_fee <= MAX_KEEPER_FEE, Errors::KEEPER_FEE_TOO_HIGH);

            let old_keeper_fee = self.keeper_fee.read();
            self.keeper_fee.write(new_keeper_fee);

            // EVENT: Log the old and the new keeper fee.
            self.emit(NewKeeperFee { old_keeper_fee, new_keeper_fee });
        }

        /// # Security
        /// * Only-Keeper
        ///
        /// # Implementation
        /// * IMiniYasVault
        fn set_new_keeper(ref self: ContractState, new_keeper: ContractAddress) {
            // Only keeper.
            self._check_keeper();

            // ERROR: Keeper can never be zero.
            assert(new_keeper.is_non_zero(), Errors::KEEPER_CANT_BE_ZERO);

            let old_keeper = self.keeper.read();
            self.keeper.write(new_keeper);

            // EVENT: Log the old and the new keeper address.
            self.emit(NewKeeper { old_keeper, new_keeper });
        }

        /// # Implementation
        /// * IYASPool
        fn yas_mint_callback(
            ref self: ContractState, amount_0_owed: u256, amount_1_owed: u256, data: Array<felt252>
        ) {
            // ERROR: Only allowed to be called by YAS Pool.
            let caller = get_caller_address();
            assert(caller == self.yas_pool.read().contract_address, Errors::CALLER_NOT_YAS_POOL);

            let sender = Felt252TryIntoContractAddress::try_into(*data.at(0)).expect('WAT');

            // Pay amounts from sender (can be the vault)
            self._pay(self.token_0.read(), sender, caller, amount_0_owed);
            self._pay(self.token_1.read(), sender, caller, amount_1_owed);
        }
    }

    // --------------------------------------------------------------------------------
    //                                Vault Internals
    // --------------------------------------------------------------------------------

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Internal function to transfer or pull tokens 
        ///
        /// # Arguments
        /// * `token` - The token we are paying
        /// * `from` - The owner of the tokens
        /// * `recipient` - The recipient of the tokens
        /// * `amount` - The amount being transferred
        fn _pay(
            ref self: ContractState,
            token: IERC20Dispatcher,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            // Check if the payment is coming from the vault itself
            if from == get_contract_address() {
                token.transfer(recipient, amount);
            } else {
                token.transferFrom(from, recipient, amount);
            }
        }

        /// Internal function to check for unclaimed fees in the vault position
        ///
        /// # Arguments
        /// * `fee_growth_global_token` - The token's global fee growth
        /// * `lower_tick_fee_growth_outside` - The token's lower tick fee growth outside
        /// * `upper_tick_fee_growth_outside` - The token' upper tick tick fee growth outside
        /// * `tick` - The tick to check fees for
        /// * `tick_lower` - The vault position's lower tick
        /// * `tick_upper` - The vault position's upper tick
        /// * `liquidity` - The vault position's liquidity in the YAS pool
        /// * `fee_growth_inside_last` - fee growth of token0/token1 inside the range as of last update
        fn _unclaimed_token_fees(
            self: @ContractState,
            fee_growth_global_token: u256,
            lower_tick_fee_growth_outside: u256,
            upper_tick_fee_growth_outside: u256,
            tick: i32,
            tick_lower: i32,
            tick_upper: i32,
            liquidity: u128,
            fee_growth_inside_last: u256
        ) -> u256 {
            // Calculate fee growth below
            //           __
            //        __|  |__
            //     __|  |  |  |__
            //  __|//|  |  |  |  |__
            // |//|//|  |  |  |  |  |
            //       ^     t  ^   
            // <---- lt       ut
            let fee_growth_below = if (tick >= tick_lower) {
                lower_tick_fee_growth_outside
            } else {
                fee_growth_global_token - lower_tick_fee_growth_outside
            };

            // Calculate fee growth above
            //           __
            //        __|  |__
            //     __|  |  |  |__
            //  __|  |  |  |  |//|__
            // |  |  |  |  |  |//|//|
            //       ^     t  ^   
            //      lt        ut --->
            let fee_growth_above = if (tick < tick_upper) {
                upper_tick_fee_growth_outside
            } else {
                fee_growth_global_token - upper_tick_fee_growth_outside
            };

            // Calculate total fee growth inside our range
            //           __
            //        __|//|__
            //     __|//|//|//|__
            //  __|  |//|//|//|  |__
            // |  |  |//|//|//|  |  |
            //       ^     t  ^   
            //       lt       ut
            let fee_growth_inside = fee_growth_global_token - fee_growth_below - fee_growth_above;

            // Get vault's fees since last update
            YASMath::mul_div(
                liquidity.into(), fee_growth_inside - fee_growth_inside_last, Constants::Q128
            )
        }

        /// Checks transaction deadline, if succeeds then locks the contract to prevent reentrancy
        ///
        /// # Arguments
        /// * `deadline` - The timestamp the transaction must be accepted by
        #[inline(always)]
        fn _check_and_lock(ref self: ContractState, deadline: u64) {
            assert(deadline <= get_block_timestamp(), Errors::EXCEEDS_DEADLINE);
            assert(!self.guard.read(), Errors::REENTRANT_CALL);
            self.guard.write(true);
        }

        #[inline(always)]
        fn _unlock(ref self: ContractState) {
            self.guard.write(false);
        }

        #[inline(always)]
        fn _check_keeper(ref self: ContractState) {
            // ERROR: Only Keeper.
            assert(get_caller_address() == self.keeper.read(), Errors::CALLER_NOT_KEEPER);
        }
    }

    // --------------------------------------------------------------------------------
    //                                   ERC20 INTERNALS
    // --------------------------------------------------------------------------------

    #[generate_trait]
    impl InternalERC20Impl of InternalERC20Trait {
        fn _increase_allowance(
            ref self: ContractState, spender: ContractAddress, added_value: u128
        ) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, self.allowances.read((caller, spender)) + added_value);
            true
        }

        fn _decrease_allowance(
            ref self: ContractState, spender: ContractAddress, subtracted_value: u128
        ) -> bool {
            let caller = get_caller_address();
            self
                ._approve(
                    caller, spender, self.allowances.read((caller, spender)) - subtracted_value
                );
            true
        }

        fn _mint(ref self: ContractState, recipient: ContractAddress, amount: u128) {
            self.total_supply.write(self.total_supply.read() + amount);
            self.balances.write(recipient, self.balances.read(recipient) + amount);
            self.emit(Transfer { from: Zeroable::zero(), to: recipient, value: amount });
        }

        fn _burn(ref self: ContractState, account: ContractAddress, amount: u128) {
            assert(!account.is_zero(), 'ERC20: burn from 0');
            self.total_supply.write(self.total_supply.read() - amount);
            self.balances.write(account, self.balances.read(account) - amount);
            self.emit(Transfer { from: account, to: Zeroable::zero(), value: amount });
        }

        fn _approve(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u128
        ) {
            assert(!owner.is_zero(), 'ERC20: approve from 0');
            assert(!spender.is_zero(), 'ERC20: approve to 0');
            self.allowances.write((owner, spender), amount);
            self.emit(Approval { owner, spender, value: amount });
        }

        fn _transfer(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u128
        ) {
            assert(!sender.is_zero(), 'ERC20: transfer from 0');
            assert(!recipient.is_zero(), 'ERC20: transfer to 0');
            self.balances.write(sender, self.balances.read(sender) - amount);
            self.balances.write(recipient, self.balances.read(recipient) + amount);
            self.emit(Transfer { from: sender, to: recipient, value: amount });
        }

        fn _spend_allowance(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u128
        ) {
            let current_allowance = self.allowances.read((owner, spender));
            if current_allowance != integer::BoundedInt::max() {
                self._approve(owner, spender, current_allowance - amount);
            }
        }
    }
}
