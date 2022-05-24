// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "./Storage.sol";
interface XERC20Interface is XERC20StorageInterface {
     function mint(uint256 mintAmount) external returns (uint256);
    function redeem(uint256 redeemTokens) external returns (uint256);
    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);
    function borrow(uint256 borrowAmount) external returns (uint256);
    function repayBorrow(uint256 repayAmount) external returns (uint256);
    function repayBorrowBehalf(address borrower, uint256 repayAmount) external returns (uint256);
    function liquidateBorrow(address borrower, uint256 repayAmount, address _tokenCollateralAddress) external returns (uint256);
    function sweepToken(XERC20Interface token) external;


    /*** Admin Functions ***/

    function _addReserves(uint256 addAmount) external returns (uint256);
}