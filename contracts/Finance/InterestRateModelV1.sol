// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "./InterestRateModelInterface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract InterestRateModelV1 is InterestRateModelInterface, Ownable {

    using SafeMath for uint256;

     event NewInterestParams(uint256 baseRatePerBlock, uint256 multiplierPerBlock);
     event BlockPerDayUpdated(uint256 oldValue, uint256 newValue);
     event BlockMultiplierUpdated(uint256 oldValue, uint256 newValue);
     event BaseRateUpdated(uint256 oldValue, uint256 newValue);

    // approximate number of blocks per year
    uint256 private blockPerDay = 6122;
    uint256 private blockPerYear = blockPerDay * 365;

    uint256 public multiplierPerBlock;
    uint256 public baseRatePerBlock;

    address public _owner;

    constructor(uint256 baseRatePerYear, uint256 mulPerYear) {
        _owner = msg.sender;
        baseRatePerBlock = baseRatePerYear.div(blockPerYear);
        multiplierPerBlock = mulPerYear.div(blockPerYear);
        emit NewInterestParams(baseRatePerBlock, multiplierPerBlock);
    }

    function _updateBlocksPerDay(uint256 bpd) public onlyOwner {
        uint256 OldBpd = blockPerDay;
        blockPerDay = bpd;
        emit BlockPerDayUpdated(OldBpd, bpd);
    }

    function _updateMultiplier(uint256 mpb) public onlyOwner {
        uint256 OldVal = multiplierPerBlock;
        multiplierPerBlock = mpb;
        emit BlockMultiplierUpdated(OldVal, mpb);
    }

    function _updateBaseRate(uint256 brpb) public onlyOwner {
        uint256 OldVal = baseRatePerBlock;
        baseRatePerBlock = brpb;
        emit BaseRateUpdated(OldVal, brpb);
    }

     /**
     * @notice Calculates the utilization rate of the market: `borrows / (cash + borrows - reserves)`
     * @param cash The amount of cash in the market
     * @param borrows The amount of borrows in the market
     * @param reserves The amount of reserves in the market (currently unused)
     * @return The utilization rate as a maValue between [0, 1e18]
     */
    function utilizationRate(uint256 cash, uint256 borrows, uint256 reserves) public pure returns (uint256) {
        // Utilization rate is 0 when there are no borrows
        if (borrows == 0) {
            return 0;
        }

        return borrows.mul(1e18).div(cash.add(borrows).sub(reserves));
    }

    function getBorrowRate(uint256 cash, uint256 borrows, uint256 reserves) public view returns (uint256) {
        uint256 ur = utilizationRate(cash, borrows, reserves);
        return ur.mul(multiplierPerBlock).div(1e18).add(baseRatePerBlock);
    }

  function getSupplyRate(uint256 cash, uint256 borrows, uint256 reserves, uint256 reserveFactor) public view returns (uint256) {
        uint256 oneMinusReserveFactor = uint(1e18).sub(reserveFactor);
        uint256 borrowRate = getBorrowRate(cash, borrows, reserves);
        uint256 rateToPool = borrowRate.mul(oneMinusReserveFactor).div(1e18);
        return utilizationRate(cash, borrows, reserves).mul(rateToPool).div(1e18);
    }

}