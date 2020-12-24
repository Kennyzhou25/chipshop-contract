pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

import "../owner/Operator.sol";

contract MockERC20 is ERC20Burnable, Operator {
    /**
     * @notice Constructs the Basis Dollar ERC-20 contract.
     */
    constructor(string memory name, string memory symbol, uint8 _decimals) public ERC20(name, symbol) {
        _setupDecimals(_decimals);
    }

    /**
     * @notice Operator mints dino dollar to a recipient
     * @param recipient_ The address of recipient
     * @param amount_ The amount of dino dollar to mint to
     * @return whether the process has been done
     */
    function mint(address recipient_, uint256 amount_) public onlyOperator returns (bool) {
        uint256 balanceBefore = balanceOf(recipient_);
        _mint(recipient_, amount_);
        uint256 balanceAfter = balanceOf(recipient_);

        return balanceAfter > balanceBefore;
    }
}
