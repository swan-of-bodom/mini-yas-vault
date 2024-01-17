//! Mini YAS Vault.

use starknet::{ContractAddress};
use mini_yas_vault::data::calldata::{DepositParams, WithdrawParams};
use yas_core::libraries::position::{Info as PositionInfo, PositionKey};
use yas_core::contracts::yas_pool::{IYASPoolDispatcher, IYASPoolDispatcherTrait, Slot0};
use yas_core::numbers::fixed_point::core::{FixedTrait, FixedType};

#[starknet::interface]
trait IMiniYasVault<TContractState> {
    // ----------------------------------------------------------------------------------------
    //                                         ERC20
    // ----------------------------------------------------------------------------------------

    // TODO: Component?

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

    // Keeper settings //

    /// The current keeper's address, managing rebalances
    fn keeper(self: @TContractState) -> ContractAddress;
    /// The current fee that the keeper receives from each compound
    fn keeper_fee(self: @TContractState) -> u256;
    /// The maximum possible keeper fee (10%), from collected fees
    fn MAX_KEEPER_FEE(self: @TContractState) -> u256;

    // The vault position in YAS //

    /// Gets the Slot0 struct from YAS pool
    ///
    /// # Returns
    /// * The YAS Pool's slot0
    fn get_slot_0(self: @TContractState) -> Slot0;
    /// Gets the current vault's position key struct from YAS pool
    ///
    /// # Returns
    /// * The vault's current position key { vault_address, tick_lower, tick_upper }
    fn get_position_key(self: @TContractState) -> PositionKey;
    /// Gets the current vault's position info struct from YAS pool
    ///
    /// # Returns
    /// * The vault's current position info { liquidity, fee_growth_0, fee_growth_1, token_owed_0, token_owed_1 }
    fn get_position_info(self: @TContractState) -> PositionInfo;

    // Vault position info //

    /// Gets the total liquidity we own in YAS pool
    fn total_liquidity(self: @TContractState) -> u128;
    /// Converts YAS liquidity to MYV shares
    ///
    /// # Arguments
    /// * `liquidity` - The amount of YAS liquidity to convert to MYV shares
    fn convert_to_shares(self: @TContractState, liquidity: u128) -> u128;
    /// Converts MYV shares to YAS liquidity
    ///
    /// # Arguments
    /// * `shares` - The amount of MYV shares to convert to YAS liquidity
    fn convert_to_assets(self: @TContractState, shares: u128) -> u128;
    /// Helpful for calculating the liquidity to deposit
    ///
    /// # Arguments
    /// * `amount_0` - The amount of token0 to deposit
    /// * `amount_1` - The amount of token1 to deposit
    ///
    /// # Returns
    /// * The liquidity minted for amount_0 and amount_1
    fn get_liquidity_amount(self: @TContractState, amount_0: u256, amount_1: u256) -> u128;

    /// Getter to view the total amount of token0 and token1 the vault owns (position + fees)
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

    // Non-Constant functions //

    /// Deposits token0 and token1 amounts and mints vault shares
    ///
    /// # Arguments
    /// * `deposit_params` - The deposit params strcut, see calldata.cairo
    ///
    /// # Returns
    /// * The amount of shares minted
    fn deposit(ref self: TContractState, deposit_params: DepositParams) -> u128;
    /// Withdraws token0 and token1 and burns shares
    ///
    /// # Arguments
    /// * `withdraw_params` - The withdraw params struct, see calldata.cairo
    ///
    /// # Returns
    /// * The amount of token0 received
    /// * The amount of token1 received
    fn withdraw(ref self: TContractState, withdraw_params: WithdrawParams) -> (u256, u256);
    /// Compounds fees and charge management fees
    ///
    /// # Returns
    /// * The new YAS liquidity we minted
    /// * The amount of token0 collected
    /// * The amount of token1 collected
    fn compound_fees(ref self: TContractState) -> (u128, u256, u256);

    // Admin //

    /// Updates the keeper address.
    ///
    /// # Arguments
    /// * `new_keeper` - The address of the new keeper
    fn set_new_keeper(ref self: TContractState, new_keeper: ContractAddress);
    /// Updates the keeper fee.
    ///
    /// # Arguments
    /// * `new_keeper_fee` - The new fee for the keeper.
    fn set_keeper_fee(ref self: TContractState, new_keeper_fee: u256);
    /// Updates the keeper safe. Optional address for keeper to receive this pool's fees
    ///
    /// # Arguments
    /// * `new_keeper_safe` - The address of the new keeper safe
    fn set_keeper_safe(ref self: TContractState, new_keeper_safe: ContractAddress);


    // YAS //

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

    use mini_yas_vault::vault::events::VaultEvents::{
        Transfer, Approval, Deposit, Withdraw, NewKeeper, NewKeeperFee, PayKeeper, Compound,
        NewKeeperSafe
    };

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
        Deposit: Deposit,
        Withdraw: Withdraw,
        NewKeeper: NewKeeper,
        NewKeeperFee: NewKeeperFee,
        PayKeeper: PayKeeper,
        Compound: Compound,
        NewKeeperSafe: NewKeeperSafe
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
        keeper_fee: u256,
        // Address to receive fees (can be zero)
        keeper_safe: ContractAddress,
    }

    const WAD: u256 = 1_000_000_000_000_000_000;

    // Unsiwap uses minimum deposit for first depositor only
    const MIN_YAS_LIQUIDITY: u128 = 1000;

    // The maximum fee that the keeper can receive
    const MAX_KEEPER_FEE: u256 = 100_000_000_000_000_000; // 10%

    // ----------------------------------------------------------------------------------------
    //                                    4. CONSTURCTOR
    // ----------------------------------------------------------------------------------------

    #[constructor]
    fn constructor(ref self: ContractState, yas_pool: IYASPoolDispatcher,) {
        self.yas_pool.write(yas_pool);
        self.token_0.write(IERC20Dispatcher { contract_address: yas_pool.token_0() });
        self.token_1.write(IERC20Dispatcher { contract_address: yas_pool.token_1() });
    // self.fee.write(yas_pool.pool_fee());
    }

    // ----------------------------------------------------------------------------------------
    //                                    5. IMPLEMENTATION
    // ----------------------------------------------------------------------------------------

    #[external(v0)]
    impl MiniYasVaultImpl of super::IMiniYasVault<ContractState> {
        // ------------------------------------------------------------------------------------
        //                                     ERC20
        // ------------------------------------------------------------------------------------

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

        // ------------------------------------------------------------------------------------
        //                                    MINI YAS VAULT
        // ------------------------------------------------------------------------------------

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
        fn keeper_fee(self: @ContractState) -> u256 {
            self.keeper_fee.read()
        }
        /// # Implementation
        /// * IMiniYasVault
        fn MAX_KEEPER_FEE(self: @ContractState) -> u256 {
            MAX_KEEPER_FEE
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


        /// The total amounts we own
        ///
        /// # Implementation
        /// * IMiniYasVault
        fn get_total_amounts(self: @ContractState) -> (u256, u256) {
            // The amount of token0/token1 on the active position
            let (position_0, position_1) = self.get_position_amounts();
            // The amount of token0/token1 fees that we can claim 
            let (fee_0, fee_1) = self.get_position_fees();

            (position_0 + fee_0, position_1 + fee_1)
        }

        /// The amount of token0 and token1 we have in the active YAS position
        ///
        /// # Implementation
        /// * IMiniYasVault
        fn get_position_amounts(self: @ContractState) -> (u256, u256) {
            // TODO
            //LiquidityAmounts::get_amounts_for_liquidity(
            //    self.get_slot_0().sqrt_price_X96,
            //    get_sqrt_ratio_at_tick(position_key.tick_lower),
            //    get_sqrt_ratio_at_tick(position_key.tick_upper),
            //    self.total_liquidity(),
            //)
            (0xc0ffee, 0xc0ffee)
        }

        /// The amount of pending fees we can collect of token0 and token1
        ///
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
        fn convert_to_shares(self: @ContractState, liquidity: u128) -> u128 {
            let total_supply = self.total_supply.read();

            if total_supply.is_zero() {
                // ERROR: Check for minimum deposit for first depositor only, prevent inflation attack.
                assert(liquidity > MIN_YAS_LIQUIDITY, Errors::BELOW_INITIAL_LIQUIDITY);

                // Bootstrap pool at 1-to-1
                return liquidity;
            }

            liquidity.full_mul_div(total_supply, self.total_liquidity())
        }

        /// # Implementation
        /// * IMiniYasVault
        #[inline(always)]
        fn convert_to_assets(self: @ContractState, shares: u128) -> u128 {
            let total_supply = self.total_supply.read();

            if total_supply.is_zero() {
                return shares;
            }

            shares.full_mul_div(self.total_liquidity(), total_supply)
        }

        /// Useful to calculate the deposit_params
        ///
        /// # Implementation
        /// * IMiniYasVault
        fn get_liquidity_amount(self: @ContractState, amount_0: u256, amount_1: u256) -> u128 {
            let position_key = self.get_position_key();

            let liquidity = LiquidityAmounts::get_liquidity_for_amounts(
                self.get_slot_0().sqrt_price_X96,
                get_sqrt_ratio_at_tick(position_key.tick_lower),
                get_sqrt_ratio_at_tick(position_key.tick_upper),
                amount_0,
                amount_1
            );

            // TODO return min amounts, helpful for deposits
            //let (amount_0, amount_1) = LiquidityAmounts::get_amounts_for_liquidity(
            //    self.get_slot_0().sqrt_price_X96,
            //    get_sqrt_ratio_at_tick(position_key.tick_lower),
            //    get_sqrt_ratio_at_tick(position_key.tick_upper),
            //    liquidity,
            //)

            liquidity // return also mins
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
            // TODO auto-compound fees on deposits

            self._check_and_lock(deposit_params.deadline);

            // Calculate shares for the max liquidity given deposit params.
            let shares = self.convert_to_shares(deposit_params.liquidity);

            // ERROR: Check for zero shares.
            assert(shares > 0, Errors::CANT_MINT_ZERO);

            let position_key = self.get_position_key();

            // Payer is always msg.sender
            let caller = get_caller_address();
            /// Mint liquidity at YAS pool. The recipient is always the vault and we pass
            /// the payer (msg.sender) as data
            let (amount_0, amount_1) = self
                .yas_pool
                .read()
                .mint(
                    get_contract_address(),
                    position_key.tick_lower,
                    position_key.tick_upper,
                    deposit_params.liquidity,
                    array![caller.into()]
                );

            /// # Error
            /// * `INSUFFICIENT_TOKEN_0` - Check for token0 slippage.
            assert(amount_0 > deposit_params.amount_0_min, Errors::INSUFFICIENT_TOKEN_0);
            /// # Error
            /// * `INSUFFICIENT_TOKEN_1` - Check for token1 slippage.
            assert(amount_1 > deposit_params.amount_1_min, Errors::INSUFFICIENT_TOKEN_1);

            // Mint MYV shares to recipient.
            self._mint(deposit_params.recipient, shares);

            /// # Event
            /// * Deposit
            self
                .emit(
                    Deposit {
                        caller,
                        recipient: deposit_params.recipient,
                        liquidity: deposit_params.liquidity,
                        shares,
                        amount_0,
                        amount_1
                    }
                );

            self._unlock();

            shares
        }

        /// # Security
        /// * Non-Reentrant
        /// * Deadline
        ///
        /// # Implementation
        /// * IMiniYasVault
        fn withdraw(ref self: ContractState, withdraw_params: WithdrawParams) -> (u256, u256) {
            // TODO auto-compound fees on withdrawals
            self._check_and_lock(withdraw_params.deadline);

            // Get caller address and check for allowance
            let caller = get_caller_address();

            if caller != withdraw_params.owner {
                self._spend_allowance(withdraw_params.owner, caller, withdraw_params.shares);
            }

            // Calculate YAS liquidity for the shares burnt.
            let liquidity = self.convert_to_assets(withdraw_params.shares);
            // ERROR: Check for zero liquidity.
            assert(liquidity > 0, Errors::CANT_BURN_ZERO);

            // Burn MYV shares.
            self._burn(withdraw_params.owner, withdraw_params.shares);

            // Get position key
            let position_key = self.get_position_key();

            // Burn liquidity from pool.
            let (amount_0, amount_1) = self
                .yas_pool
                .read()
                .burn(position_key.tick_lower, position_key.tick_upper, liquidity);

            /// TODO: Collect here and pay assets - The assets returned should be proportional
            /// to the liquidity burnt relative to total pool liquidity + fee proportion amounts.

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

        /// # Implementation
        /// * IMiniYasVault
        fn compound_fees(ref self: ContractState) -> (u128, u256, u256) {
            // Savings
            let yas_pool = self.yas_pool.read();

            /// ------------------------------------------------------------------
            ///   1. Do a zero-burn first to update vault tokens owed
            /// ------------------------------------------------------------------

            let position_key = self.get_position_key();

            let (mut amount_0, mut amount_1) = yas_pool
                .burn(position_key.tick_lower, position_key.tick_upper, 0);

            /// ------------------------------------------------------------------
            ///   2. Pool state until we compound, needed to compute the rest
            /// ------------------------------------------------------------------

            let position_info = yas_pool.get_position(position_key);
            let sqrt_ratio_AX96 = get_sqrt_ratio_at_tick(position_key.tick_lower);
            let sqrt_ratio_BX96 = get_sqrt_ratio_at_tick(position_key.tick_upper);
            let sqrt_price_X96 = self.get_slot_0().sqrt_price_X96;

            /// ------------------------------------------------------------------
            ///   3. Get the maximum liquiity we can mint given fees collected
            /// ------------------------------------------------------------------

            let mut liquidity = LiquidityAmounts::get_liquidity_for_amounts(
                sqrt_price_X96,
                sqrt_ratio_AX96,
                sqrt_ratio_BX96,
                position_info.tokens_owed_0.into(),
                position_info.tokens_owed_1.into()
            );

            /// ------------------------------------------------------------------
            ///   Get the maximum amounts to mint the new liquidity
            /// ------------------------------------------------------------------

            // TODO compute token amounts given max liquidity we can add

            // (amount_0, amount_1) = LiquidityAmounts::get_amounts_for_liquidity(
            //     sqrt_price_X96,
            //     sqrt_ratio_AX96,
            //     sqrt_ratio_BX96,
            //     liquidity
            // );

            // Collect just enough to add liquidity again.

            /// (amount_0, amount_1) = yas_pool.collect(
            //     get_contract_address(), 
            //     tick_lower, 
            //     tick_upper, 
            //     amount_0, 
            //     amount_1
            // );

            /// ------------------------------------------------------------------
            ///   Charge keeper managemnet fee on the collected tokens
            /// ------------------------------------------------------------------

            let keeper_fee = self.keeper_fee.read();
            let fee_token_0 = YASMath::mul_div(amount_0, keeper_fee, WAD);
            let fee_token_1 = YASMath::mul_div(amount_1, keeper_fee, WAD);

            // Pay amounts from sender (can be the vault)
            self._pay_keeper_fees(fee_token_0, fee_token_1);

            /// ------------------------------------------------------------------
            ///   Mint liquidity
            /// ------------------------------------------------------------------

            liquidity =
                LiquidityAmounts::get_liquidity_for_amounts(
                    sqrt_price_X96,
                    sqrt_ratio_AX96,
                    sqrt_ratio_BX96,
                    amount_0 - fee_token_0,
                    amount_1 - fee_token_1
                );

            /// Mint liquidity at YAS pool. The recipient and payer is the vault.
            let (amount_0, amount_1) = self
                .yas_pool
                .read()
                .mint(
                    get_contract_address(),
                    position_key.tick_lower,
                    position_key.tick_upper,
                    liquidity,
                    array![get_contract_address().into()]
                );

            self.emit(Compound { liquidity, amount_0, amount_1 });

            (liquidity, amount_0, amount_1)
        }

        /// # Security
        /// * Only-Keeper
        ///
        /// # Implementation
        /// * IMiniYasVault
        fn set_keeper_fee(ref self: ContractState, new_keeper_fee: u256) {
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
        fn set_keeper_safe(ref self: ContractState, new_keeper_safe: ContractAddress) {
            // Only keeper.
            self._check_keeper();

            // Allow for keeper safe to be set to 0, significa mandar fees a keeper
            let old_keeper_safe = self.keeper_safe.read();
            self.keeper_safe.write(new_keeper_safe);

            // EVENT: Log the old and the new keeper safe address.
            self.emit(NewKeeperSafe { old_keeper_safe, new_keeper_safe });
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
        /// Internal function to pay keeper fees
        ///
        /// # Arguments
        /// * `fee_token_0` - The accrued fee of token0 to be sent to the keeper
        /// * `fee_token_1` - The accrued fee of token1 to be sent to the keeper
        fn _pay_keeper_fees(ref self: ContractState, fee_token_0: u256, fee_token_1: u256) {
            let keeper_safe = self.keeper_safe.read();
            let recipient = if keeper_safe.is_zero() {
                self.keeper.read()
            } else {
                keeper_safe
            };

            self._pay(self.token_0.read(), get_contract_address(), recipient, fee_token_0);
            self._pay(self.token_1.read(), get_contract_address(), recipient, fee_token_1);

            /// # Event
            /// * PayKeeperFee
            self.emit(PayKeeper { recipient, fee_token_0, fee_token_1 });
        }

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
