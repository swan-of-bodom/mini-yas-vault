mod LiquidityAmounts {
    use yas_core::numbers::fixed_point::implementations::impl_64x96::{
        FixedType, FixedTrait, FP64x96PartialOrd, FP64x96PartialEq, FP64x96Impl, FP64x96Zeroable,
        FP64x96Sub, ONE
    };

    use yas_core::utils::math_utils::{FullMath, BitShift::{U256BitShift}};

    /// @notice Computes the amount of liquidity received for a given amount of token0 and price range
    /// @dev Calculates amount0 * (sqrt(upper) * sqrt(lower)) / (sqrt(upper) - sqrt(lower))
    /// @param sqrt_ratio_AX96 A sqrt price representing the first tick boundary
    /// @param sqrt_ratio_BX96 A sqrt price representing the second tick boundary
    /// @param amount_0 The amount0 being sent in
    /// @return liquidity The amount of returned liquidity
    fn get_liquidity_for_amount_0(
        sqrt_ratio_AX96: FixedType, sqrt_ratio_BX96: FixedType, amount_0: u256
    ) -> u128 {
        let (sqrt_ratio_AX96, sqrt_ratio_BX96) = if sqrt_ratio_AX96 > sqrt_ratio_BX96 {
            (sqrt_ratio_BX96, sqrt_ratio_AX96)
        } else {
            (sqrt_ratio_AX96, sqrt_ratio_BX96)
        };
        let intermediate = FullMath::mul_div(sqrt_ratio_AX96.mag, sqrt_ratio_BX96.mag, ONE);
        FullMath::mul_div(amount_0, intermediate, (sqrt_ratio_BX96 - sqrt_ratio_AX96).mag)
            .try_into()
            .unwrap()
    }

    /// @notice Computes the amount of liquidity received for a given amount of token1 and price range
    /// @dev Calculates amount1 / (sqrt(upper) - sqrt(lower)).
    /// @param sqrt_ratio_AX96 A sqrt price representing the first tick boundary
    /// @param sqrt_ratio_BX96 A sqrt price representing the second tick boundary
    /// @param amount_1 The amount1 being sent in
    /// @return liquidity The amount of returned liquidity
    fn get_liquidity_for_amount_1(
        sqrt_ratio_AX96: FixedType, sqrt_ratio_BX96: FixedType, amount_1: u256
    ) -> u128 {
        let (sqrt_ratio_AX96, sqrt_ratio_BX96) = if sqrt_ratio_AX96 > sqrt_ratio_BX96 {
            (sqrt_ratio_BX96, sqrt_ratio_AX96)
        } else {
            (sqrt_ratio_AX96, sqrt_ratio_BX96)
        };
        FullMath::mul_div(amount_1, ONE, (sqrt_ratio_BX96 - sqrt_ratio_AX96).mag)
            .try_into()
            .unwrap()
    }

    /// @notice Computes the maximum amount of liquidity received for a given amount of token0, token1, the current
    /// pool prices and the prices at the tick boundaries
    /// @param sqrt_ratio_X96 A sqrt price representing the current pool prices
    /// @param sqrt_ratio_AX96 A sqrt price representing the first tick boundary
    /// @param sqrt_ratio_BX96 A sqrt price representing the second tick boundary
    /// @param amount_0 The amount of token0 being sent in
    /// @param amount_1 The amount of token1 being sent in
    /// @return liquidity The maximum amount of liquidity received
    fn get_liquidity_for_amounts(
        sqrt_ratio_X96: FixedType,
        sqrt_ratio_AX96: FixedType,
        sqrt_ratio_BX96: FixedType,
        amount_0: u256,
        amount_1: u256
    ) -> u128 {
        let (sqrt_ratio_AX96, sqrt_ratio_BX96) = if sqrt_ratio_AX96 > sqrt_ratio_BX96 {
            (sqrt_ratio_BX96, sqrt_ratio_AX96)
        } else {
            (sqrt_ratio_AX96, sqrt_ratio_BX96)
        };

        if sqrt_ratio_X96 <= sqrt_ratio_AX96 {
            get_liquidity_for_amount_0(sqrt_ratio_AX96, sqrt_ratio_BX96, amount_0)
        } else if sqrt_ratio_X96 < sqrt_ratio_BX96 {
            let liquidity_0 = get_liquidity_for_amount_0(sqrt_ratio_X96, sqrt_ratio_BX96, amount_0);
            let liquidity_1 = get_liquidity_for_amount_1(sqrt_ratio_AX96, sqrt_ratio_X96, amount_1);
            if liquidity_0 < liquidity_1 {
                liquidity_0
            } else {
                liquidity_1
            }
        } else {
            get_liquidity_for_amount_1(sqrt_ratio_AX96, sqrt_ratio_BX96, amount_1)
        }
    }
}
