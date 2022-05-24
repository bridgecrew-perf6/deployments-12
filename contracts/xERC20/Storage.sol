// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/escrow/ConditionalEscrow.sol";
import "../Finance/InterestRateModelInterface.sol";

interface XERC20StorageInterface {
  function getUnderlyingAddress() external returns(address);
}

abstract contract XERC20Storage is XERC20StorageInterface {
    address public underlying;

    function getUnderlyingAddress() public view returns (address) {
        return underlying;
    }
}

interface XDelegationStorage {
    event NewImplementation(address oldImpl, address newImpl);
    function setImplementation(address implementation_, bool allowResign, bytes memory becomeImplementationData) external;
}

interface XDelegateStorage is XDelegationStorage {

    function _becomeImplementation(bytes memory data) external;
    function _resignImplementation() external;

}

abstract contract XTokenStorage is ReentrancyGuard {

    using Address for address;

    string public _name;
    string public _symbol;
    uint8 public _decimals;

    // @notice max borrow rate is 0.0015% per block

    uint internal constant _borrowRateMax = 0.0015e16;
    uint internal constant _reserveFactorMax = 1e18;

    address public admin;

    address public pendingAdmin;

   

    uint256 public _initialExchangeRate;
    uint256 public reserveFactor;
    uint256 public accrualBlockNumber;
    uint256 public borrowIndex;
    uint256 public totalBorrows;
    uint256 public totalReserve;
    uint256 public totalSupply;

    mapping (address => uint256) public _accountTokens;
    mapping (address => mapping (address => uint)) public  _transferAllowances;

    ConditionalEscrow public conditionalEscrow;
    InterestRateModelInterface public interestRateModel;

    struct BorrowSnapshot {
        uint256 principal;
        uint256 interestIndex;
    }

    mapping(address => BorrowSnapshot) public _accountBorrows;

    uint256 public constant protocolFeeShare = 3e16;


}