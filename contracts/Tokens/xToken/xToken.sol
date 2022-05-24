// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "../../xERC20/XTokenInterface.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "../../Finance/InterestRateModelInterface.sol";
import "@openzeppelin/contracts/utils/escrow/ConditionalEscrow.sol";
import "../../Finance/Exponential.sol";
import "../../Finance/Exp.sol";

contract xToken is Initializable, XTokenInterface,  IxToken,  XTokenStorage, Exponential {

    address public beacon;
    address public escrow;

    constructor(address _beacon, InterestRateModelInterface interestRateModel_, uint256 initialExchangeRate, string memory name_, string memory symbol_,
    uint8 decimals_) {
        initialize(_beacon, interestRateModel_ ,initialExchangeRate, name_, symbol_ ,decimals_);
    }

    function initialize(address _beacon, InterestRateModelInterface interestRateModel_, uint256 initialExchangeRate, string memory name_, string memory symbol_,
    uint8 decimals_) public initializer {
        require(msg.sender == admin, "only admin");
 
        require(accrualBlockNumber == 0 && borrowIndex == 0, "market already initialized");

    }

    function __xToken_init(address _beacon, address _escrow, InterestRateModelInterface interestRateModel_, uint256 initialExchangeRate, string memory name_, string memory symbol_,
    uint8 decimals_) internal initializer {
        beacon = _beacon;
        escrow = _escrow;
        _set_interest_rate_model(interestRateModel_);
        _set_initial_exchange_rate(initialExchangeRate);
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;


    }

    function name() public view virtual returns(string memory) {
        return _name;
    }

    function symbol() public view virtual returns(string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns(uint8) {
        return _decimals;
    }

    function _set_initial_exchange_rate(uint256 _rate) internal {
        require(_rate != 0, "initial rate cannot be zero");
        _initialExchangeRate = _rate;
    }

    function _set_accrual_block_number() internal {
        accrualBlockNumber = block.number;
    }

    function _set_borrow_index(uint256 _index) internal {
        borrowIndex = _index;
    }

    function _set_interest_rate_model(InterestRateModelInterface _interestRateModel) internal {
        interestRateModel = _interestRateModel;
    }

    function _set_initial_escrow() internal {
        conditionalEscrow = ConditionalEscrow(escrow);
    }

    function transferTokens(address spender, address src, address dst, uint256 tokens) internal returns(uint256) {
        require(transferAllowed(spender) != false, "not allowed to transfer tokens");
        require(src != dst, "not allowed to transfer");
        uint256 startingAllowance = 0;
        if (spender == src) {
            startingAllowance = 99999999999e18;
        } else {
            startingAllowance = _transferAllowances[src][spender];
        }

        uint256 allowanceNew;
        uint256 srxTokensNew;
        uint256 dstTokensNew;
        MathError mathErr;

        (mathErr, allowanceNew) = subUInt(startingAllowance, tokens);
        require(mathErr == MathError.NO_ERROR, "transfer not allowed");
        (mathErr, srxTokensNew) = subUInt(_accountTokens[src], tokens);
        require(mathErr == MathError.NO_ERROR, "transfer not allowed");
         (mathErr, dstTokensNew) = subUInt(_accountTokens[dst], tokens);
          require(mathErr == MathError.NO_ERROR, "transfer not allowed");

          _accountTokens[src] = srxTokensNew;
          _accountTokens[dst] = dstTokensNew;
          if(startingAllowance != 99999999999e18) {
              _transferAllowances[src][spender] = allowanceNew;
          }

          emit Transfer(src, dst, tokens);
          return uint256(0);

    }

      function transfer(address dst, uint256 amount) public nonReentrant returns(bool) {
          transferTokens(msg.sender, msg.sender, dst, amount);
      }

      function transferFrom(address src, address dst, uint256 amount) public nonReentrant returns(bool) {
           transferTokens(msg.sender, src, dst, amount);
      }

   
    function transferAllowed(address spender) public returns(bool) {
        return conditionalEscrow.withdrawalAllowed(spender);
    }

    function approve(address spender, uint256 amount) public returns(bool) {
         address src = msg.sender;
        _transferAllowances[src][spender] = amount;
        emit Approval(src, spender, amount);
    
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _transferAllowances[owner][spender];
    }

     function balanceOf(address owner) public view returns (uint256) {
        return _accountTokens[owner];
    }

     /**
     * @notice Get the underlying balance of the `owner`
     * @dev This also accrues interest in a transaction
     * @param owner The address of the account to query
     * @return The amount of underlying owned by `owner`
     */
    function balanceOfUnderlying(address owner) public returns (uint256) {
        Exp memory exchangeRate = Exp({mValue: exchangeRateCurrent()});
        (MathError mErr, uint256 balance) = mulScalarTruncate(exchangeRate, _accountTokens[owner]);
        require(mErr == MathError.NO_ERROR, "balance could not be calculated");
        return balance;
    }

     function getAccountSnapshot(address account) public view returns (uint256, uint256, uint256, uint256) {
        uint256 xTokenBalance = _accountTokens[account];
        uint256 borrowBalance;
        uint256 exchangeRate;

        MathError mErr;

        (mErr, borrowBalance) = borrowBalanceStoredInternal(account);
        if (mErr != MathError.NO_ERROR) {
            return (uint256(0), 0, 0, 0);
        }

        (mErr, exchangeRate) = exchangeRateStoredInternal();
        if (mErr != MathError.NO_ERROR) {
            return (uint256(0), 0, 0, 0);
        }

        return (uint256(0), xTokenBalance, borrowBalance, exchangeRate);
    }

    function borrowRatePerBlock() public view returns (uint256) {
        return interestRateModel.getBorrowRate(getCashPrior(), totalBorrows, totalReserve);
    }

     function supplyRatePerBlock() public view returns (uint256) {
        return interestRateModel.getSupplyRate(getCashPrior(), totalBorrows, totalReserve, reserveFactor);
    }

     function totalBorrowsCurrent() public nonReentrant returns (uint256) {
        require(accrueInterest() == uint256(0), "accrue interest failed");
        return totalBorrows;
    }

    function borrowBalanceCurrent(address account) public nonReentrant returns (uint256) {
        require(accrueInterest() == uint256(0), "accrue interest failed");
        return borrowBalanceStored(account);
    }

    function borrowBalanceStored(address account) public view returns (uint256) {
        (MathError err, uint256 result) = borrowBalanceStoredInternal(account);
        require(err == MathError.NO_ERROR, "borrowBalanceStored: borrowBalanceStoredInternal failed");
        return result;
    }

      function borrowBalanceStoredInternal(address account) internal view returns (MathError, uint256) {
        /* Note: we do not assert that the market is up to date */
        MathError mathErr;
        uint256 principalTimesIndex;
        uint256 result;

        /* Get borrowBalance and borrowIndex */
        BorrowSnapshot storage borrowSnapshot = _accountBorrows[account];

        /* If borrowBalance = 0 then borrowIndex is likely also 0.
         * Rather than failing the calculation with a division by 0, we immediately return 0 in this case.
         */
        if (borrowSnapshot.principal == 0) {
            return (MathError.NO_ERROR, 0);
        }

        /* Calculate new borrow balance using the interest index:
         *  recentBorrowBalance = borrower.borrowBalance * market.borrowIndex / borrower.borrowIndex
         */
        (mathErr, principalTimesIndex) = mulUInt(borrowSnapshot.principal, borrowIndex);
        if (mathErr != MathError.NO_ERROR) {
            return (mathErr, 0);
        }

        (mathErr, result) = divUInt(principalTimesIndex, borrowSnapshot.interestIndex);
        if (mathErr != MathError.NO_ERROR) {
            return (mathErr, 0);
        }

        return (MathError.NO_ERROR, result);
    }

    function exchangeRateCurrent() public nonReentrant returns (uint256) {
        require(accrueInterest() == uint256(0), "accrue interest failed");
        return exchangeRateStored();
    }

     function exchangeRateStored() public view returns (uint256) {
        (MathError err, uint256 result) = exchangeRateStoredInternal();
        require(err == MathError.NO_ERROR, "exchangeRateStored: exchangeRateStoredInternal failed");
        return result;
    }

    function exchangeRateStoredInternal() internal view returns (MathError, uint256) {
        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            /*
             * If there are no tokens minted:
             *  exchangeRate = initialExchangeRate
             */
            return (MathError.NO_ERROR, _initialExchangeRate);
        } else {
            /*
             * Otherwise:
             *  exchangeRate = (totalCash + totalBorrows - totalReserve) / totalSupply
             */
            uint256 totalCash = getCashPrior();
            uint256 cashPlusBorrowsMinusReserves;
            Exp memory exchangeRate;
            MathError mathErr;

            (mathErr, cashPlusBorrowsMinusReserves) = addThenSubUInt(totalCash, totalBorrows, totalReserve);
            if (mathErr != MathError.NO_ERROR) {
                return (mathErr, 0);
            }

            (mathErr, exchangeRate) = getExp(cashPlusBorrowsMinusReserves, _totalSupply);
            if (mathErr != MathError.NO_ERROR) {
                return (mathErr, 0);
            }

            return (MathError.NO_ERROR, exchangeRate.mValue);
        }
    }

/**
     * @notice Get cash balance of this xToken in the underlying asset
     * @return The quantity of underlying asset owned by this contract
     */
    function getCash() public view returns (uint256) {
        return getCashPrior();
    }

    /**
     * @notice Applies accrued interest to total borrows and reserves
     * @dev This calculates interest accrued from the last checkpointed block
     *   up to the current block and writes new checkpoint to storage.
     */
    function accrueInterest() public returns (uint256) {
        /* Remember the initial block number */
        uint256 currentBlockNumber = block.number;
        uint256 accrualBlockNumberPrior = accrualBlockNumber;

        /* Short-circuit accumulating 0 interest */
        if (accrualBlockNumberPrior == currentBlockNumber) {
            return uint256(0);
        }

        /* Read the previous values out of storage */
        uint256 cashPrior = getCashPrior();
        uint256 borrowsPrior = totalBorrows;
        uint256 reservesPrior = totalReserve;
        uint256 borrowIndexPrior = borrowIndex;

        /* Calculate the current borrow interest rate */
        uint256 borrowRate = interestRateModel.getBorrowRate(cashPrior, borrowsPrior, reservesPrior);
        require(borrowRate <= _borrowRateMax, "borrow rate is absurdly high");

        /* Calculate the number of blocks elapsed since the last accrual */
        (MathError mathErr, uint256 blockDelta) = subUInt(currentBlockNumber, accrualBlockNumberPrior);
        require(mathErr == MathError.NO_ERROR, "could not calculate block delta");

        /*
         * Calculate the interest accumulated into borrows and reserves and the new index:
         *  simpleInterestFactor = borrowRate * blockDelta
         *  interestAccumulated = simpleInterestFactor * totalBorrows
         *  totalBorrowsNew = interestAccumulated + totalBorrows
         *  totalReserveNew = interestAccumulated * reserveFactor + totalReserve
         *  borrowIndexNew = simpleInterestFactor * borrowIndex + borrowIndex
         */

        Exp memory simpleInterestFactor;
        uint256 interestAccumulated;
        uint256 totalBorrowsNew;
        uint256 totalReserveNew;
        uint256 borrowIndexNew;

        (mathErr, simpleInterestFactor) = mulScalar(Exp({mValue: borrowRate}), blockDelta);
      

        (mathErr, interestAccumulated) = mulScalarTruncate(simpleInterestFactor, borrowsPrior);
      

        (mathErr, totalBorrowsNew) = addUInt(interestAccumulated, borrowsPrior);
       

        (mathErr, totalReserveNew) = mulScalarTruncateAddUInt(Exp({mValue: reserveFactor}), interestAccumulated, reservesPrior);
       

        (mathErr, borrowIndexNew) = mulScalarTruncateAddUInt(simpleInterestFactor, borrowIndexPrior, borrowIndexPrior);
        

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /* We write the previously calculated values into storage */
        accrualBlockNumber = currentBlockNumber;
        borrowIndex = borrowIndexNew;
        totalBorrows = totalBorrowsNew;
        totalReserve = totalReserveNew;

        /* We emit an AccrueInterest event */
        emit AccrueInterest(cashPrior, interestAccumulated, borrowIndexNew, totalBorrowsNew);

        return uint256(0);
    }

       /**
     * @notice Sender supplies assets into the market and receives xTokens in exchange
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param mintAmount The amount of the underlying asset to supply
     * @return (uint256, uint256) An error code (0=success, otherwise a failure, see ErrorReporter.sol), and the actual mint amount.
     */
    function mintInternal(uint256 mintAmount) internal nonReentrant returns (uint256, uint256) {
        uint256 error = accrueInterest();
       
        // mintFresh emits the actual Mint event if successful and logs on errors, so we don't need to
        return mintFresh(msg.sender, mintAmount);
    }

    struct MintLocalVars {
        
        MathError mathErr;
        uint256 exchangeRate;
        uint256 mintTokens;
        uint256 totalSupplyNew;
        uint256 accountTokensNew;
        uint256 actualMintAmount;
    }

    /*
     * @notice User supplies assets into the market and receives xTokens in exchange
     * @dev Assumes interest has already been accrued up to the current block
     * @param minter The address of the account which is supplying the assets
     * @param mintAmount The amount of the underlying asset to supply
     * @return (uint256, uint256) An error code (0=success, otherwise a failure, see ErrorReporter.sol), and the actual mint amount.
     */
    function mintFresh(address minter, uint256 mintAmount) internal returns (uint256, uint256) {
        /* Fail if mint not allowed */
        bool allowed = mintAllowed();
       
       

        MintLocalVars memory vars;

        (vars.mathErr, vars.exchangeRate) = exchangeRateStoredInternal();
       

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /*
         *  We call `doTransferIn` for the minter and the mintAmount.
         *  Note: The xToken must handle variations between ERC-20 and ETH underlying.
         *  `doTransferIn` reverts if anything goes wrong, since we can't be sure if
         *  side-effects occurred. The function returns the amount actually transferred,
         *  in case of a fee. On success, the xToken holds an additional `actualMintAmount`
         *  of cash.
         */
        vars.actualMintAmount = doTransferIn(minter, mintAmount);

        /*
         * We get the current exchange rate and calculate the number of xTokens to be minted:
         *  mintTokens = actualMintAmount / exchangeRate
         */

        (vars.mathErr, vars.mintTokens) = divScalarByExpTruncate(vars.actualMintAmount, Exp({mValue: vars.exchangeRate}));
        require(vars.mathErr == MathError.NO_ERROR, "MINT_EXCHANGE_CALCULATION_FAILED");

        /*
         * We calculate the new total supply of xTokens and minter token balance, checking for overflow:
         *  totalSupplyNew = totalSupply + mintTokens
         *  accountTokensNew = accountTokens[minter] + mintTokens
         */
        (vars.mathErr, vars.totalSupplyNew) = addUInt(totalSupply, vars.mintTokens);
        require(vars.mathErr == MathError.NO_ERROR, "MINT_NEW_TOTAL_SUPPLY_CALCULATION_FAILED");

        (vars.mathErr, vars.accountTokensNew) = addUInt(_accountTokens[minter], vars.mintTokens);
        require(vars.mathErr == MathError.NO_ERROR, "MINT_NEW_ACCOUNT_BALANCE_CALCULATION_FAILED");

        /* We write previously calculated values into storage */
        totalSupply = vars.totalSupplyNew;
        _accountTokens[minter] = vars.accountTokensNew;

        /* We emit a Mint event, and a Transfer event */
        emit Mint(minter, vars.actualMintAmount, vars.mintTokens);
        emit Transfer(address(this), minter, vars.mintTokens);

        /* We call the defense hook */
        // unused function
        // controller.mintVerify(address(this), minter, vars.actualMintAmount, vars.mintTokens);

        return (uint(0), vars.actualMintAmount);
    }

     function redeemInternal(uint256 redeemTokens) internal nonReentrant returns (uint256) {
        uint256 error = accrueInterest();
      
        // redeemFresh emits redeem-specific logs on errors, so we don't need to
        return redeemFresh(msg.sender, redeemTokens, 0);
    }

     function redeemUnderlyingInternal(uint256 redeemAmount) internal nonReentrant returns (uint256) {
        uint256 error = accrueInterest();
      
        // redeemFresh emits redeem-specific logs on errors, so we don't need to
        return redeemFresh(msg.sender, 0, redeemAmount);
    }

    struct RedeemLocalVars {
        
        MathError mathErr;
        uint256 exchangeRate;
        uint256 redeemTokens;
        uint256 redeemAmount;
        uint256 totalSupplyNew;
        uint256 accountTokensNew;
    }

     /**
     * @notice User redeems xTokens in exchange for the underlying asset
     * @dev Assumes interest has already been accrued up to the current block
     * @param redeemer The address of the account which is redeeming the tokens
     * @param redeemTokensIn The number of xTokens to redeem into underlying (only one of redeemTokensIn or redeemAmountIn may be non-zero)
     * @param redeemAmountIn The number of underlying tokens to receive from redeeming xTokens (only one of redeemTokensIn or redeemAmountIn may be non-zero)
     * @return uint256 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function redeemFresh(address redeemer, uint256 redeemTokensIn, uint256 redeemAmountIn) internal returns (uint256) {
        require(redeemTokensIn == 0 || redeemAmountIn == 0, "one of redeemTokensIn or redeemAmountIn must be zero");

        RedeemLocalVars memory vars;

        /* exchangeRate = invoke Exchange Rate Stored() */
        (vars.mathErr, vars.exchangeRate) = exchangeRateStoredInternal();
       
        /* If redeemTokensIn > 0: */
        if (redeemTokensIn > 0) {
            /*
             * We calculate the exchange rate and the amount of underlying to be redeemed:
             *  redeemTokens = redeemTokensIn
             *  redeemAmount = redeemTokensIn x exchangeRateCurrent
             */
            vars.redeemTokens = redeemTokensIn;

            (vars.mathErr, vars.redeemAmount) = mulScalarTruncate(Exp({mValue: vars.exchangeRate}), redeemTokensIn);
           
        } else {
            /*
             * We get the current exchange rate and calculate the amount to be redeemed:
             *  redeemTokens = redeemAmountIn / exchangeRate
             *  redeemAmount = redeemAmountIn
             */

            (vars.mathErr, vars.redeemTokens) = Exponential.divScalarByExpTruncate(redeemAmountIn, Exp({mValue: vars.exchangeRate}));
           

            vars.redeemAmount = redeemAmountIn;
        }

        /* Fail if redeem not allowed */
        bool allowed = redeemAllowed();
      


        /*
         * We calculate the new total supply and redeemer balance, checking for underflow:
         *  totalSupplyNew = totalSupply - redeemTokens
         *  accountTokensNew = accountTokens[redeemer] - redeemTokens
         */
        (vars.mathErr, vars.totalSupplyNew) = subUInt(totalSupply, vars.redeemTokens);
       

        (vars.mathErr, vars.accountTokensNew) = subUInt(_accountTokens[redeemer], vars.redeemTokens);
        

        /* Fail gracefully if protocol has insufficient cash */
        require(getCashPrior() > vars.redeemAmount);

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /*
         * We invoke doTransferOut for the redeemer and the redeemAmount.
         *  Note: The xToken must handle variations between ERC-20 and ETH underlying.
         *  On success, the xToken has redeemAmount less of cash.
         *  doTransferOut reverts if anything goes wrong, since we can't be sure if side effects occurred.
         */
        doTransferOut(redeemer, vars.redeemAmount);

        /* We write previously calculated values into storage */
        totalSupply = vars.totalSupplyNew;
        _accountTokens[redeemer] = vars.accountTokensNew;

        /* We emit a Transfer event, and a Redeem event */
        emit Transfer(redeemer, address(this), vars.redeemTokens);
        emit Redeem(redeemer, vars.redeemAmount, vars.redeemTokens);

        /* We call the defense hook */
       // controller.redeemVerify(address(this), redeemer, vars.redeemAmount, vars.redeemTokens);

        return uint(0);
    }

        function borrowInternal(uint256 borrowAmount) internal nonReentrant returns (uint256) {
        uint256 error = accrueInterest();
      
        // borrowFresh emits borrow-specific logs on errors, so we don't need to
        return borrowFresh(msg.sender, borrowAmount);
    }

    struct BorrowLocalVars {
        MathError mathErr;
        uint256 accountBorrows;
        uint256 accountBorrowsNew;
        uint256 totalBorrowsNew;
    }

      /**
      * @notice Users borrow assets from the protocol to their own address
      * @param borrowAmount The amount of the underlying asset to borrow
      * @return uint256 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function borrowFresh(address borrower, uint256 borrowAmount) internal returns (uint256) {
        /* Fail if borrow not allowed */
        bool allowed = borrowAllowed();
      
        /* Verify market's block number equals current block number */
     
        /* Fail gracefully if protocol has insufficient underlying cash */
       
        BorrowLocalVars memory vars;

        /*
         * We calculate the new borrower and total borrow balances, failing on overflow:
         *  accountBorrowsNew = accountBorrows + borrowAmount
         *  totalBorrowsNew = totalBorrows + borrowAmount
         */
        (vars.mathErr, vars.accountBorrows) = borrowBalanceStoredInternal(borrower);
      
        (vars.mathErr, vars.accountBorrowsNew) = addUInt(vars.accountBorrows, borrowAmount);
       

        (vars.mathErr, vars.totalBorrowsNew) = addUInt(totalBorrows, borrowAmount);
      

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /*
         * We invoke doTransferOut for the borrower and the borrowAmount.
         *  Note: The xToken must handle variations between ERC-20 and ETH underlying.
         *  On success, the xToken borrowAmount less of cash.
         *  doTransferOut reverts if anything goes wrong, since we can't be sure if side effects occurred.
         */
        doTransferOut(borrower, borrowAmount);

        /* We write the previously calculated values into storage */
        _accountBorrows[borrower].principal = vars.accountBorrowsNew;
        _accountBorrows[borrower].interestIndex = borrowIndex;
        totalBorrows = vars.totalBorrowsNew;

        /* We emit a Borrow event */
        emit Borrow(borrower, borrowAmount, vars.accountBorrowsNew, vars.totalBorrowsNew);

        /* We call the defense hook */
        // unused function
        // controller.borrowVerify(address(this), borrower, borrowAmount);

        return uint256(0);
    }

      /**
     * @notice Sender repays their own borrow
     * @param repayAmount The amount to repay
     * @return (uint256, uint256) An error code (0=success, otherwise a failure, see ErrorReporter.sol), and the actual repayment amount.
     */
    function repayBorrowInternal(uint256 repayAmount) internal nonReentrant returns (uint256, uint256) {
        uint256 error = accrueInterest();
       
        // repayBorrowFresh emits repay-borrow-specific logs on errors, so we don't need to
        return repayBorrowFresh(msg.sender, msg.sender, repayAmount);
    }

    /**
     * @notice Sender repays a borrow belonging to borrower
     * @param borrower the account with the debt being payed off
     * @param repayAmount The amount to repay
     * @return (uint256, uint256) An error code (0=success, otherwise a failure, see ErrorReporter.sol), and the actual repayment amount.
     */
    function repayBorrowBehalfInternal(address borrower, uint256 repayAmount) internal nonReentrant returns (uint256, uint256) {
        uint256 error = accrueInterest();
  //yBorrowFresh emits repay-borrow-specific logs on errors, so we don't need to
        return repayBorrowFresh(msg.sender, borrower, repayAmount);
    }

    struct RepayBorrowLocalVars {
        
        MathError mathErr;
        uint256 repayAmount;
        uint256 borrowerIndex;
        uint256 accountBorrows;
        uint256 accountBorrowsNew;
        uint256 totalBorrowsNew;
        uint256 actualRepayAmount;
    }

    /**
     * @notice Borrows are repaid by another user (possibly the borrower).
     * @param payer the account paying off the borrow
     * @param borrower the account with the debt being payed off
     * @param repayAmount the amount of undelrying tokens being returned
     * @return (uint, uint) An error code (0=success, otherwise a failure, see ErrorReporter.sol), and the actual repayment amount.
     */
    function repayBorrowFresh(address payer, address borrower, uint256 repayAmount) internal returns (uint256, uint256) {
        /* Fail if repayBorrow not allowed */
       bool allowed = repayBorrowAllowed();
      

        RepayBorrowLocalVars memory vars;

        /* We remember the original borrowerIndex for verification purposes */
        vars.borrowerIndex = _accountBorrows[borrower].interestIndex;

        /* We fetch the amount the borrower owes, with accumulated interest */
        (vars.mathErr, vars.accountBorrows) = borrowBalanceStoredInternal(borrower);
     

        /* If repayAmount == -1, repayAmount = accountBorrows */
        if (repayAmount < uint256(0)) {
            vars.repayAmount = vars.accountBorrows;
        } else {
            vars.repayAmount = repayAmount;
        }

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /*
         * We call doTransferIn for the payer and the repayAmount
         *  Note: The xToken must handle variations between ERC-20 and ETH underlying.
         *  On success, the xToken holds an additional repayAmount of cash.
         *  doTransferIn reverts if anything goes wrong, since we can't be sure if side effects occurred.
         *   it returns the amount actually transferred, in case of a fee.
         */
        vars.actualRepayAmount = doTransferIn(payer, vars.repayAmount);

        /*
         * We calculate the new borrower and total borrow balances, failing on underflow:
         *  accountBorrowsNew = accountBorrows - actualRepayAmount
         *  totalBorrowsNew = totalBorrows - actualRepayAmount
         */
        (vars.mathErr, vars.accountBorrowsNew) = subUInt(vars.accountBorrows, vars.actualRepayAmount);
        require(vars.mathErr == MathError.NO_ERROR, "REPAY_BORROW_NEW_ACCOUNT_BORROW_BALANCE_CALCULATION_FAILED");

        (vars.mathErr, vars.totalBorrowsNew) = subUInt(totalBorrows, vars.actualRepayAmount);
        require(vars.mathErr == MathError.NO_ERROR, "REPAY_BORROW_NEW_TOTAL_BALANCE_CALCULATION_FAILED");

        /* We write the previously calculated values into storage */
        _accountBorrows[borrower].principal = vars.accountBorrowsNew;
        _accountBorrows[borrower].interestIndex = borrowIndex;
        totalBorrows = vars.totalBorrowsNew;

        /* We emit a RepayBorrow event */
        emit RepayBorrow(payer, borrower, vars.actualRepayAmount, vars.accountBorrowsNew, vars.totalBorrowsNew);

        /* We call the defense hook */
        // unused function
        // controller.repayBorrowVerify(address(this), payer, borrower, vars.actualRepayAmount, vars.borrowerIndex);

        return (uint256(0), vars.actualRepayAmount);
    }

    /**
     * @notice The sender liquidates the borrowers collateral.
     *  The collateral seized is transferred to the liquidator.
     * @param borrower The borrower of this xToken to be liquidated
     * @param xTokenCollateral The market in which to seize collateral from the borrower
     * @param repayAmount The amount of the underlying borrowed asset to repay
     * @return (uint, uint) An error code (0=success, otherwise a failure, see ErrorReporter.sol), and the actual repayment amount.
     */
    function liquidateBorrowInternal(address borrower, uint repayAmount, xToken xTokenCollateral) internal nonReentrant returns (uint, uint) {
        uint error = accrueInterest();
       
       // error = xTokenCollateral.accrueInterest();
      

        // liquidateBorrowFresh emits borrow-specific logs on errors, so we don't need to
        return liquidateBorrowFresh(msg.sender, borrower, repayAmount, xTokenCollateral);
    }

    /**
     * @notice The liquidator liquidates the borrowers collateral.
     *  The collateral seized is transferred to the liquidator.
     * @param borrower The borrower of this xToken to be liquidated
     * @param liquidator The address repaying the borrow and seizing collateral
     * @param xTokenCollateral The market in which to seize collateral from the borrower
     * @param repayAmount The amount of the underlying borrowed asset to repay
     * @return (uint, uint) An error code (0=success, otherwise a failure, see ErrorReporter.sol), and the actual repayment amount.
     */
    function liquidateBorrowFresh(address liquidator, address borrower, uint256 repayAmount, xToken xTokenCollateral) public returns(uint256,uint256) {

    

        /* Fail if repayAmount = 0 */
       
        /* Fail if repayAmount = -1 */
       


        /* Fail if repayBorrow fails */
       // (uint256 repayBorrowError, uint256 actualRepayAmount) = repayBorrowFresh(liquidator, borrower, repayAmount);
      

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /* We calculate the number of collateral tokens that will be seized */
        //(uint256 amountSeizeError, uint256 seizeTokens) = liquidateCalculateSeizeTokens(address(this), address(xTokenCollateral), actualRepayAmount);
        //require(amountSeizeError == uint256(0), "LIQUIDATE_controller_CALCULATE_AMOUNT_SEIZE_FAILED");
        uint256 seizeTokens;

        /* Revert if borrower collateral token balance < seizeTokens */
        require(xTokenCollateral.balanceOf(borrower) >= seizeTokens, "LIQUIDATE_SEIZE_TOO_MUCH");

        // If this is also the collateral, run seizeInternal to avoid re-entrancy, otherwise make an public call
        uint seizeError;
        if (address(xTokenCollateral) == address(this)) {
            seizeError = seizeInternal(address(this), liquidator, borrower, seizeTokens);
        } else {
            seizeError = xTokenCollateral.seize(liquidator, borrower, seizeTokens);
        }

        /* Revert if seize tokens fails (since we cannot be sure of side effects) */
        require(seizeError == uint(0), "token seizure failed");
        uint256 actualRepayAmount;

        /* We emit a LiquidateBorrow event */
        emit LiquidateBorrow(liquidator, borrower, actualRepayAmount, address(xTokenCollateral), seizeTokens);

        /* We call the defense hook */
        // unused function
        // controller.liquidateBorrowVerify(address(this), address(xTokenCollateral), liquidator, borrower, actualRepayAmount, seizeTokens);

        return (uint(0), actualRepayAmount);
    }

 /**
     * @notice Transfers collateral tokens (this market) to the liquidator.
     * @dev Will fail unless called by another xToken during the process of liquidation.
     *  Its absolutely critical to use msg.sender as the borrowed xToken and not a parameter.
     * @param liquidator The account receiving seized collateral
     * @param borrower The account having collateral seized
     * @param seizeTokens The number of xTokens to seize
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function seize(address liquidator, address borrower, uint seizeTokens) public nonReentrant returns (uint) {
        return seizeInternal(msg.sender, liquidator, borrower, seizeTokens);
    }

    struct SeizeInternalLocalVars {
        MathError mathErr;
        uint borrowerTokensNew;
        uint liquidatorTokensNew;
        uint liquidatorSeizeTokens;
        uint protocolSeizeTokens;
        uint protocolSeizeAmount;
        uint exchangeRate;
        uint totalReserveNew;
        uint totalSupplyNew;
    }

    /**
     * @notice Transfers collateral tokens (this market) to the liquidator.
     * @dev Called only during an in-kind liquidation, or by liquidateBorrow during the liquidation of another CToken.
     *  Its absolutely critical to use msg.sender as the seizer xToken and not a parameter.
     * @param seizerToken The contract seizing the collateral (i.e. borrowed xToken)
     * @param liquidator The account receiving seized collateral
     * @param borrower The account having collateral seized
     * @param seizeTokens The number of xTokens to seize
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function seizeInternal(address seizerToken, address liquidator, address borrower, uint seizeTokens) internal returns (uint) {
      
        SeizeInternalLocalVars memory vars;

        /*
         * We calculate the new borrower and liquidator token balances, failing on underflow/overflow:
         *  borrowerTokensNew = accountTokens[borrower] - seizeTokens
         *  liquidatorTokensNew = accountTokens[liquidator] + seizeTokens
         */
        (vars.mathErr, vars.borrowerTokensNew) = subUInt(_accountTokens[borrower], seizeTokens);
        uint256 protocolSeizeShares;
       

        vars.protocolSeizeTokens = mul_(seizeTokens, Exp({mValue: protocolSeizeShares}));
        vars.liquidatorSeizeTokens = sub_(seizeTokens, vars.protocolSeizeTokens);

        (vars.mathErr, vars.exchangeRate) = exchangeRateStoredInternal();
        require(vars.mathErr == MathError.NO_ERROR, "exchange rate math error");

        vars.protocolSeizeAmount = mul_ScalarTruncate(Exp({mValue: vars.exchangeRate}), vars.protocolSeizeTokens);

        vars.totalReserveNew = add_(totalReserve, vars.protocolSeizeAmount);
        vars.totalSupplyNew = sub_(totalSupply, vars.protocolSeizeTokens);

        (vars.mathErr, vars.liquidatorTokensNew) = addUInt(_accountTokens[liquidator], vars.liquidatorSeizeTokens);
        

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /* We write the previously calculated values into storage */
        totalReserve = vars.totalReserveNew;
        totalSupply = vars.totalSupplyNew;
        _accountTokens[borrower] = vars.borrowerTokensNew;
        _accountTokens[liquidator] = vars.liquidatorTokensNew;

        /* Emit a Transfer event */
        emit Transfer(borrower, liquidator, vars.liquidatorSeizeTokens);
        emit Transfer(borrower, address(this), vars.protocolSeizeTokens);
        emit ReservesAdded(address(this), vars.protocolSeizeAmount, vars.totalReserveNew);

        /* We call the defense hook */
        // unused function
        // controller.seizeVerify(address(this), seizerToken, liquidator, borrower, seizeTokens);

        return uint(0);
    }


    /*** Admin Functions ***/

    /**
      * @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @dev Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @param newPendingAdmin New pending admin.
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setPendingAdmin(address  newPendingAdmin) public returns (uint) {
        // Check caller = admin
        

        // Save current value, if any, for inclusion in log
        address oldPendingAdmin = pendingAdmin;

        // Store pendingAdmin with value newPendingAdmin
        pendingAdmin = newPendingAdmin;

        // Emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin)
        emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin);

        return uint(0);
    }

    /**
      * @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
      * @dev Admin function for pending admin to accept role and update admin
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _acceptAdmin() public returns (uint) {
      
        // Save current values for inclusion in log
        address oldAdmin = admin;
        address oldPendingAdmin = pendingAdmin;

        // Store admin with value pendingAdmin
        admin = pendingAdmin;

        // Clear the pending value
        pendingAdmin = address(0);

        emit NewAdmin(oldAdmin, admin);
        emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);

        return uint(0);
    }

    /**
      * @notice Sets a new controller for the market
      * @dev Admin function to set a new controller
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setcontroller(ControllerInterface newController) public returns (uint256) {
        // Check caller is admin
       // if (msg.sender != admin) {
       //     return fail(Error.UNAUTHORIZED, FailureInfo.SET_controller_OWNER_CHECK);
       // }

        //ControllerInterface oldcontroller = controller;
        // Ensure invoke controller.iscontroller() returns true
        //require(newController.isController(), "marker method returned false");

        // Set market's controller to newcontroller
        //controller = newController;

        // Emit Newcontroller(oldcontroller, newcontroller)
        //emit newController(oldcontroller, newController);

        return uint256(0);
    }

    /**
      * @notice accrues interest and sets a new reserve factor for the protocol using _setReserveFactorFresh
      * @dev Admin function to accrue interest and set a new reserve factor
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setReserveFactor(uint newReserveFactor) public nonReentrant returns (uint) {
        uint error = accrueInterest();
        
        return _setReserveFactorFresh(newReserveFactor);
    }

    /**
      * @notice Sets a new reserve factor for the protocol (*requires fresh interest accrual)
      * @dev Admin function to set a new reserve factor
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setReserveFactorFresh(uint newReserveFactor) internal returns (uint) {
       
        // Verify market's block number equals current block number
        require(accrualBlockNumber == block.number);

        // Check newReserveFactor ≤ maxReserveFactor
        require(newReserveFactor <= _reserveFactorMax, "");
     

        uint oldReserveFactor = reserveFactor;
        reserveFactor = newReserveFactor;

        emit NewReserveFactor(oldReserveFactor, newReserveFactor);

        return uint(0);
    }

    /**
     * @notice Accrues interest and reduces reserves by transferring from msg.sender
     * @param addAmount Amount of addition to reserves
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function _addReservesInternal(uint addAmount) internal nonReentrant returns (uint) {
        uint error = accrueInterest();
        require(error == 0, "");
       

        // _addReservesFresh emits reserve-addition-specific logs on errors, so we don't need to.
        (error, ) = _addReservesFresh(addAmount);
        return error;
    }

    /**
     * @notice Add reserves by transferring from caller
     * @dev Requires fresh interest accrual
     * @param addAmount Amount of addition to reserves
     * @return (uint, uint) An error code (0=success, otherwise a failure (see ErrorReporter.sol for details)) and the actual amount added, net token fees
     */
    function _addReservesFresh(uint addAmount) internal returns (uint, uint) {
        // totalReserve + actualAddAmount
        uint totalReserveNew;
        uint actualAddAmount;

        // We fail gracefully unless market's block number equals current block number
      require(accrualBlockNumber == block.number, "");

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /*
         * We call doTransferIn for the caller and the addAmount
         *  Note: The xToken must handle variations between ERC-20 and ETH underlying.
         *  On success, the xToken holds an additional addAmount of cash.
         *  doTransferIn reverts if anything goes wrong, since we can't be sure if side effects occurred.
         *  it returns the amount actually transferred, in case of a fee.
         */

        actualAddAmount = doTransferIn(msg.sender, addAmount);

        totalReserveNew = totalReserve + actualAddAmount;

        /* Revert on overflow */
        require(totalReserveNew >= totalReserve, "add reserves unexpected overflow");

        // Store reserves[n+1] = reserves[n] + actualAddAmount
        totalReserve = totalReserveNew;

        /* Emit NewReserves(admin, actualAddAmount, reserves[n+1]) */
        emit ReservesAdded(msg.sender, actualAddAmount, totalReserveNew);

        /* Return (NO_ERROR, actualAddAmount) */
        return (uint(0), actualAddAmount);
    }


    /**
     * @notice Accrues interest and reduces reserves by transferring to admin
     * @param reduceAmount Amount of reduction to reserves
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function _reduceReserves(uint reduceAmount) public nonReentrant returns (uint) {
        uint error = accrueInterest();
        require(error == 0, "");
        // _reduceReservesFresh emits reserve-reduction-specific logs on errors, so we don't need to.
        return _reduceReservesFresh(reduceAmount);
    }

    /**
     * @notice Reduces reserves by transferring to admin
     * @dev Requires fresh interest accrual
     * @param reduceAmount Amount of reduction to reserves
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function _reduceReservesFresh(uint reduceAmount) internal returns (uint) {
        // totalReserve - reduceAmount
        uint totalReserveNew;

       

        // We fail gracefully unless market's block number equals current block number
        require(accrualBlockNumber == block.number, "");

        // Fail gracefully if protocol has insufficient underlying cash
        require(getCashPrior() > reduceAmount, "");
        // Check reduceAmount ≤ reserves[n] (totalReserve)
       require(reduceAmount > totalReserve, "");

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        totalReserveNew = totalReserve - reduceAmount;
        // We checked reduceAmount <= totalReserve above, so this should never revert.
        require(totalReserveNew <= totalReserve, "reduce reserves unexpected underflow");

        // Store reserves[n+1] = reserves[n] - reduceAmount
        totalReserve = totalReserveNew;

        // doTransferOut reverts if anything goes wrong, since we can't be sure if side effects occurred.
        doTransferOut(admin, reduceAmount);

        emit ReservesReduced(admin, reduceAmount, totalReserveNew);

        return uint(0);
    }

    /**
     * @notice accrues interest and updates the interest rate model using _setInterestRateModelFresh
     * @dev Admin function to accrue interest and update the interest rate model
     * @param newInterestRateModel the new interest rate model to use
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function _setInterestRateModel(InterestRateModelInterface newInterestRateModel) public returns (uint) {
        uint error = accrueInterest();
       
        // _setInterestRateModelFresh emits interest-rate-model-update-specific logs on errors, so we don't need to.
        return _setInterestRateModelFresh(newInterestRateModel);
    }

    /**
     * @notice updates the interest rate model (*requires fresh interest accrual)
     * @dev Admin function to update the interest rate model
     * @param newInterestRateModel the new interest rate model to use
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function _setInterestRateModelFresh(InterestRateModelInterface newInterestRateModel) internal returns (uint) {

        // Used to store old model for use in the event that is emitted on success
        InterestRateModelInterface oldInterestRateModel;

        

        // Track the market's current interest rate model
        oldInterestRateModel = interestRateModel;

        // Ensure invoke newInterestRateModel.isInterestRateModel() returns true
       // require(newInterestRateModel.isInterestRateModel(), "marker method returned false");

        // Set the interest rate model to newInterestRateModel
        interestRateModel = newInterestRateModel;

        // Emit NewMarketInterestRateModel(oldInterestRateModel, newInterestRateModel)
        emit NewMarketInterestRateModel(oldInterestRateModel, newInterestRateModel);

        return uint(0);
    }

    /*** Safe Token ***/

    /**
     * @notice Gets balance of this contract in terms of the underlying
     * @dev This excludes the value of the current message, if any
     * @return The quantity of underlying owned by this contract
     */
    function getCashPrior() internal view virtual returns (uint) {
        return 0;
    }

    /**
     * @dev Performs a transfer in, reverting upon failure. Returns the amount actually transferred to the protocol, in case of a fee.
     *  This may revert due to insufficient balance or insufficient allowance.
     */
    function doTransferIn(address from, uint amount) internal virtual returns (uint) {
        return 0;
    }

    /**
     * @dev Performs a transfer out, ideally returning an explanatory error code upon failure tather than reverting.
     *  If caller has not called checked protocol's balance, may revert due to insufficient cash held in the contract.
     *  If caller has checked protocol's balance, and verified it is >= amount, this should not revert in normal conditions.
     */
    function doTransferOut(address  to, uint amount) internal virtual {
        // none
    }


    function mintAllowed() internal returns (bool) {
        return true;
    }

    function redeemAllowed() internal returns (bool) {
        return true;
    }

   function borrowAllowed() internal returns (bool) {
        return true;
    }

      function repayBorrowAllowed() internal returns (bool) {
        return true;
    }


}

interface ControllerInterface {}