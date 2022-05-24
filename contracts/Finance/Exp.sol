// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;


contract ExpMath {
    uint256 constant expScale = 1e18;
    uint256 constant doubleScale = 1e36;
    uint256 constant halfExpScale = expScale/2;
    uint256 constant mValueOne = expScale;

    struct Exp {
        uint256 mValue;
    }

    struct Double {
        uint256 mValue;
    }

    /**
     * @dev Truncates the given exp to a whole number value.
     *      For example, truncate(Exp{mValue: 15 * expScale}) = 15
     */
    function truncate(Exp memory exp) pure internal returns (uint) {
        // Note: We are not using careful math here as we're performing a division that cannot fail
        return exp.mValue / expScale;
    }

    /**
     * @dev Multiply an Exp by a scalar, then truncate to return an unsigned integer.
     */
    function mul_ScalarTruncate(Exp memory a, uint256 scalar) pure internal returns (uint) {
        Exp memory product = mul_(a, scalar);
        return truncate(product);
    }

    /**
     * @dev Multiply an Exp by a scalar, truncate, then add an to an unsigned integer, returning an unsigned integer.
     */
    function mul_ScalarTruncateAddUInt(Exp memory a, uint256 scalar, uint256 addend) pure internal returns (uint) {
        Exp memory product = mul_(a, scalar);
        return add_(truncate(product), addend);
    }

    /**
     * @dev Checks if first Exp is less than second Exp.
     */
    function lessThanExp(Exp memory left, Exp memory right) pure internal returns (bool) {
        return left.mValue < right.mValue;
    }

    /**
     * @dev Checks if left Exp <= right Exp.
     */
    function lessThanOrEqualExp(Exp memory left, Exp memory right) pure internal returns (bool) {
        return left.mValue <= right.mValue;
    }

    /**
     * @dev Checks if left Exp > right Exp.
     */
    function greaterThanExp(Exp memory left, Exp memory right) pure internal returns (bool) {
        return left.mValue > right.mValue;
    }

    /**
     * @dev returns true if Exp is exactly zero
     */
    function isZeroExp(Exp memory value) pure internal returns (bool) {
        return value.mValue == 0;
    }

    function safe224(uint256 n, string memory errorMessage) pure internal returns (uint224) {
        require(n < 2**224, errorMessage);
        return uint224(n);
    }

    function safe32(uint256 n, string memory errorMessage) pure internal returns (uint32) {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }

    function add_(Exp memory a, Exp memory b) pure internal returns (Exp memory) {
        return Exp({mValue: add_(a.mValue, b.mValue)});
    }

    function add_(Double memory a, Double memory b) pure internal returns (Double memory) {
        return Double({mValue: add_(a.mValue, b.mValue)});
    }

    function add_(uint256 a, uint256 b) pure internal returns (uint) {
        return add_(a, b, "addition overflow");
    }

    function add_(uint256 a, uint256 b, string memory errorMessage) pure internal returns (uint) {
        uint256 c = a + b;
        require(c >= a, errorMessage);
        return c;
    }

    function sub_(Exp memory a, Exp memory b) pure internal returns (Exp memory) {
        return Exp({mValue: sub_(a.mValue, b.mValue)});
    }

    function sub_(Double memory a, Double memory b) pure internal returns (Double memory) {
        return Double({mValue: sub_(a.mValue, b.mValue)});
    }

    function sub_(uint256 a, uint256 b) pure internal returns (uint) {
        return sub_(a, b, "subtraction underflow");
    }

    function sub_(uint256 a, uint256 b, string memory errorMessage) pure internal returns (uint) {
        require(b <= a, errorMessage);
        return a - b;
    }

    function mul_(Exp memory a, Exp memory b) pure internal returns (Exp memory) {
        return Exp({mValue: mul_(a.mValue, b.mValue) / expScale});
    }

    function mul_(Exp memory a, uint256 b) pure internal returns (Exp memory) {
        return Exp({mValue: mul_(a.mValue, b)});
    }

    function mul_(uint256 a, Exp memory b) pure internal returns (uint) {
        return mul_(a, b.mValue) / expScale;
    }

    function mul_(Double memory a, Double memory b) pure internal returns (Double memory) {
        return Double({mValue: mul_(a.mValue, b.mValue) / doubleScale});
    }

    function mul_(Double memory a, uint256 b) pure internal returns (Double memory) {
        return Double({mValue: mul_(a.mValue, b)});
    }

    function mul_(uint256 a, Double memory b) pure internal returns (uint) {
        return mul_(a, b.mValue) / doubleScale;
    }

    function mul_(uint256 a, uint256 b) pure internal returns (uint) {
        return mul_(a, b, "multiplication overflow");
    }

    function mul_(uint256 a, uint256 b, string memory errorMessage) pure internal returns (uint) {
        if (a == 0 || b == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, errorMessage);
        return c;
    }

    function div_(Exp memory a, Exp memory b) pure internal returns (Exp memory) {
        return Exp({mValue: div_(mul_(a.mValue, expScale), b.mValue)});
    }

    function div_(Exp memory a, uint256 b) pure internal returns (Exp memory) {
        return Exp({mValue: div_(a.mValue, b)});
    }

    function div_(uint256 a, Exp memory b) pure internal returns (uint) {
        return div_(mul_(a, expScale), b.mValue);
    }

    function div_(Double memory a, Double memory b) pure internal returns (Double memory) {
        return Double({mValue: div_(mul_(a.mValue, doubleScale), b.mValue)});
    }

    function div_(Double memory a, uint256 b) pure internal returns (Double memory) {
        return Double({mValue: div_(a.mValue, b)});
    }

    function div_(uint256 a, Double memory b) pure internal returns (uint) {
        return div_(mul_(a, doubleScale), b.mValue);
    }

    function div_(uint256 a, uint256 b) pure internal returns (uint) {
        return div_(a, b, "divide by zero");
    }

    function div_(uint256 a, uint256 b, string memory errorMessage) pure internal returns (uint) {
        require(b > 0, errorMessage);
        return a / b;
    }

    function fraction(uint256 a, uint256 b) pure internal returns (Double memory) {
        return Double({mValue: div_(mul_(a, doubleScale), b)});
    }
}