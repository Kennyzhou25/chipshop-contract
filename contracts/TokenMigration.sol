pragma solidity ^0.8.0;

import "./interfaces/IBasisAsset.sol";

contract TokenMigration {

    IBasisAsset public oldChip;
    IBasisAsset public oldFish;
    IBasisAsset public oldMpea;

    IBasisAsset public newChip;
    IBasisAsset public newFish;

    uint256 public startBlock;
    uint256 public endBlock;

    modifier canMigrate() {
        require(block.number >= startBlock, "TokenMigration: Migration is not started.");
        require(block.number <= endBlock, "TokenMigration: Migration is finished.");
        _;
    }

    constructor(IBasisAsset _oldChip, IBasisAsset _oldFish, IBasisAsset _oldMpea, IBasisAsset _newChip, IBasisAsset _newFish, uint256 startBlock, uint256 _endBlock) {
        require(block.number <= endBlock, "TokenMigration: Invalid end time.");
        oldChip = _oldChip;
        oldFish = _oldFish;
        oldMpea = _oldMpea;
        newChip = _newChip;
        newFish = _newFish;
        startBlock = _startBlock;
        endBlock = _endBlock;
    }

    function migrateChip() external canMigrate {
        uint256 oldBalance = oldChip.balanceOf(msg.sender);
        oldChip.burnFrom(msg.sender, oldBalance);
        newChip.transfer(msg.sender, oldBalance);
    }

    function migrateFish() external canMigrate {
        uint256 oldBalance = oldFish.balanceOf(msg.sender);
        oldFish.burnFrom(msg.sender, oldBalance);
        newFish.transfer(msg.sender, oldBalance);
    }

    function migrateMpea() external canMigrate {
        uint256 oldBalance = oldMpea.balanceOf(msg.sender);
        oldMpea.burnFrom(msg.sender, oldBalance);
        newChip.transfer(msg.sender, oldBalance);
    }

    function burn() external {
        require(block.number > endBlock, "TokenMigration: not finished");
        newChip.burn(newChip.balanceOf(address(this)));
        newFish.burn(newFish.balanceOf(address(this)));
    }
}
