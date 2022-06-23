// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Compound/ExponentialNoError.sol";
import "./DTokenInterfaces.sol";

contract DToken is
    DTokenInterface,
    DTokenStorage,
    ReentrancyGuard,
    ERC20,
    Ownable,
    ExponentialNoError
{
    using SafeERC20 for IERC20;

    uint32 private _scale = 10;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC20(name_, symbol_) {
        _decimals = decimals_;
    }

    modifier onlyBorrowAllower() {
        require(borrowAllower == _msgSender(), "Only borrowAllower");
        _;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function initialize(
        address underlyingToken_,
        address borrowAllower_,
        address pTokenAddress_,
        uint256 initialExchangeRateMantissa_,
        uint256 baseRatePerYear,
        uint256 multiplierPerYear,
        uint256 jumpMultiplierPerYear,
        uint256 kink_
    ) external onlyOwner {
        underlyingToken = underlyingToken_;
        borrowAllower = borrowAllower_;
        pTokenAddress = pTokenAddress_;

        require(
            accrualBlockNumber == 0 && borrowIndex == 0,
            "Market may only be initialized once"
        );

        // Set initial exchange rate
        initialExchangeRateMantissa = initialExchangeRateMantissa_;
        require(
            initialExchangeRateMantissa > 0,
            "Initial exchange rate must be greater than zero"
        );

        _updateJumpRateModel(
            baseRatePerYear,
            multiplierPerYear,
            jumpMultiplierPerYear,
            kink_
        );

        // Initialize block number and borrow index (block number mocks depend on comptroller being set)
        accrualBlockNumber = block.number;
        borrowIndex = mantissaOne;

        // Ensure underlyingToken is ERC20
        IERC20(underlyingToken).totalSupply();
    }

    function scale() public view returns (uint32) {
        return _scale;
    }

    function exchange(address exToken, uint256 amount)
        external
        onlyBorrowAllower
    {
        require(exToken != address(0), "PoolToken: exchange zero exToken");
        require(amount != 0, "PoolToken: exchange zero amount");

        _burn(owner(), amount);

        IERC20(exToken).transfer(owner(), amount * scale());
    }

    function mint(uint256 amount) external nonReentrant {
        _mint(msg.sender, amount);
    }

    /**
     * @notice Sender borrows assets from the protocol to their own address
     * @param borrowAmount The amount of the underlying asset to borrow
     */
    function borrow(uint256 borrowAmount) external onlyBorrowAllower {}

    /**
     * @notice Sender repays their own borrow
     * @param repayAmount The amount to repay, or -1 for the full outstanding amount
     */
    function repayBorrow(uint256 repayAmount) external onlyBorrowAllower {}

    /**
     * @notice Applies accrued interest to total borrows and reserves
     * @dev This calculates interest accrued from the last checkpointed block
     *   up to the current block and writes new checkpoint to storage.
     */
    function accrueInterest() public {
        /* Remember the initial block number */
        uint256 currentBlockNumber = block.number;
        uint256 accrualBlockNumberPrior = accrualBlockNumber;

        /* Short-circuit accumulating 0 interest */
        if (accrualBlockNumberPrior == currentBlockNumber) {
            return;
        }

        /* Read the previous values out of storage */
        uint256 cashPrior = IERC20(underlyingToken).balanceOf(address(this));
        uint256 borrowsPrior = totalBorrows;
        uint256 reservesPrior = totalReserves;
        uint256 borrowIndexPrior = borrowIndex;

        /* Calculate the current borrow interest rate */
        uint256 borrowRateMantissa = getBorrowRate(
            cashPrior,
            borrowsPrior,
            reservesPrior
        );
        require(
            borrowRateMantissa <= borrowRateMaxMantissa,
            "borrow rate is absurdly high"
        );

        /* Calculate the number of blocks elapsed since the last accrual */
        uint256 blockDelta = currentBlockNumber - accrualBlockNumberPrior;

        /*
         * Calculate the interest accumulated into borrows and reserves and the new index:
         *  simpleInterestFactor = borrowRate * blockDelta
         *  interestAccumulated = simpleInterestFactor * totalBorrows
         *  totalBorrowsNew = interestAccumulated + totalBorrows
         *  totalReservesNew = interestAccumulated * reserveFactor + totalReserves
         *  borrowIndexNew = simpleInterestFactor * borrowIndex + borrowIndex
         */
        Exp memory simpleInterestFactor = mul_(
            Exp({mantissa: borrowRateMantissa}),
            blockDelta
        );
        uint256 interestAccumulated = mul_ScalarTruncate(
            simpleInterestFactor,
            borrowsPrior
        );
        uint256 totalBorrowsNew = interestAccumulated + borrowsPrior;
        uint256 totalReservesNew = mul_ScalarTruncateAddUInt(
            Exp({mantissa: reserveFactorMantissa}),
            interestAccumulated,
            reservesPrior
        );
        uint256 borrowIndexNew = mul_ScalarTruncateAddUInt(
            simpleInterestFactor,
            borrowIndexPrior,
            borrowIndexPrior
        );

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /* We write the previously calculated values into storage */
        accrualBlockNumber = currentBlockNumber;
        borrowIndex = borrowIndexNew;
        totalBorrows = totalBorrowsNew;
        totalReserves = totalReservesNew;
    }

    /**
     * @notice Update the parameters of the interest rate model (only callable by owner, i.e. Timelock)
     * @param baseRatePerYear The approximate target base APR, as a mantissa (scaled by baseInterestRate)
     * @param multiplierPerYear The rate of increase in interest rate wrt utilization (scaled by baseInterestRate)
     * @param jumpMultiplierPerYear The multiplierPerBlock after hitting a specified utilization point
     * @param kink_ The utilization point at which the jump multiplier is applied
     */
    function updateJumpRateModel(
        uint256 baseRatePerYear,
        uint256 multiplierPerYear,
        uint256 jumpMultiplierPerYear,
        uint256 kink_
    ) external onlyOwner {
        _updateJumpRateModel(
            baseRatePerYear,
            multiplierPerYear,
            jumpMultiplierPerYear,
            kink_
        );
    }

    /**
     * @notice Calculates the utilization rate of the market: `borrows / (cash + borrows - reserves)`
     * @param cash The amount of cash in the market
     * @param borrows The amount of borrows in the market
     * @param reserves The amount of reserves in the market (currently unused)
     * @return The utilization rate as a mantissa between [0, baseInterestRate]
     */
    function utilizationRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) public pure returns (uint256) {
        // Utilization rate is 0 when there are no borrows
        if (borrows == 0) {
            return 0;
        }

        return (borrows * baseInterestRate) / (cash + borrows - reserves);
    }

    /**
     * @notice Calculates the current borrow rate per block, with the error code expected by the market
     * @param cash The amount of cash in the market
     * @param borrows The amount of borrows in the market
     * @param reserves The amount of reserves in the market
     * @return The borrow rate percentage per block as a mantissa (scaled by baseInterestRate)
     */
    function getBorrowRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) public view returns (uint256) {
        uint256 util = utilizationRate(cash, borrows, reserves);

        if (util <= kink) {
            return
                ((util * multiplierPerBlock) / baseInterestRate) +
                baseRatePerBlock;
        } else {
            uint256 normalRate = ((kink * multiplierPerBlock) /
                baseInterestRate) + baseRatePerBlock;
            uint256 excessUtil = util - kink;
            return
                ((excessUtil * jumpMultiplierPerBlock) / baseInterestRate) +
                normalRate;
        }
    }

    /**
     * @notice Calculates the current supply rate per block
     * @param cash The amount of cash in the market
     * @param borrows The amount of borrows in the market
     * @param reserves The amount of reserves in the market
     * @param reserveFactorMantissa The current reserve factor for the market
     * @return The supply rate percentage per block as a mantissa (scaled by baseInterestRate)
     */
    function getSupplyRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves,
        uint256 reserveFactorMantissa
    ) public view returns (uint256) {
        uint256 oneMinusReserveFactor = baseInterestRate -
            reserveFactorMantissa;
        uint256 borrowRate = getBorrowRate(cash, borrows, reserves);
        uint256 rateToPool = (borrowRate * oneMinusReserveFactor) /
            baseInterestRate;
        return
            (utilizationRate(cash, borrows, reserves) * rateToPool) /
            baseInterestRate;
    }

    /**
     * @notice Internal function to update the parameters of the interest rate model
     * @param baseRatePerYear The approximate target base APR, as a mantissa (scaled by baseInterestRate)
     * @param multiplierPerYear The rate of increase in interest rate wrt utilization (scaled by baseInterestRate)
     * @param jumpMultiplierPerYear The multiplierPerBlock after hitting a specified utilization point
     * @param kink_ The utilization point at which the jump multiplier is applied
     */
    function _updateJumpRateModel(
        uint256 baseRatePerYear,
        uint256 multiplierPerYear,
        uint256 jumpMultiplierPerYear,
        uint256 kink_
    ) private {
        baseRatePerBlock = baseRatePerYear / blocksPerYear;
        multiplierPerBlock =
            (multiplierPerYear * baseInterestRate) /
            (blocksPerYear * kink_);
        jumpMultiplierPerBlock = jumpMultiplierPerYear / blocksPerYear;
        kink = kink_;
    }
}
