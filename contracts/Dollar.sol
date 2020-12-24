// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

import "./owner/Operator.sol";

contract Dollar is ERC20Burnable, Operator {
    uint256 public constant STABLES_POOL_REWARD_ALLOCATION = 500000 ether;

    bool public rewardPoolDistributed = false;

    /**
     * @notice Constructs the Basis Dollar ERC-20 contract.
     */
    constructor() public ERC20("Basis Dollar", "BSD") {
        // Mints 1 Basis Dollar to contract creator for initial pool setup
        _mint(msg.sender, 1 ether);
    }

    /**
     * @notice Operator mints basis dollar to a recipient
     * @param recipient_ The address of recipient
     * @param amount_ The amount of basis dollar to mint to
     * @return whether the process has been done
     */
    function mint(address recipient_, uint256 amount_) public onlyOperator returns (bool) {
        uint256 balanceBefore = balanceOf(recipient_);
        _mint(recipient_, amount_);
        uint256 balanceAfter = balanceOf(recipient_);

        return balanceAfter > balanceBefore;
    }

    function burn(uint256 amount) public override onlyOperator {
        super.burn(amount);
    }

    function burnFrom(address account, uint256 amount) public override onlyOperator {
        super.burnFrom(account, amount);
    }

    /**
     * @notice distribute to reward pool (only once)
     */
    function distributeReward(address _stablesPool) external onlyOperator {
        require(!rewardPoolDistributed, "only can distribute once");
        require(_stablesPool != address(0), "!_stablesPool");
        rewardPoolDistributed = true;
        _mint(_stablesPool, STABLES_POOL_REWARD_ALLOCATION);
    }
}
