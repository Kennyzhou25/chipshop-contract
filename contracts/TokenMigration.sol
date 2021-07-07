pragma solidity ^0.8.0;

import "./interfaces/IBasisAsset.sol";

contract TokenMigration {

    IBasisAsset public oldChip = IBasisAsset(0x8d92474DE93aB8C0De11C29db7c1628772bEd484);
    IBasisAsset public oldFish = IBasisAsset(0xd092C8aD4B8dAB3174553d580E185c4AB3F31d7C);
    IBasisAsset public oldMpea = IBasisAsset(0xd4B702dF46F0Efa69f06dC6e31162962A9c77Df3);

    IBasisAsset public newChip;
    IBasisAsset public newFish;
    IBasisAsset public newMpea;

    constructor(IBasisAsset _newChip, IBasisAsset _newFish, IBasisAsset _newMpea) {
        newChip = _newChip;
        newFish = _newFish;
        newMpea = _newMpea;
    }

    function migrateChip() external {
        uint256 oldBalance = oldChip.balanceOf(msg.sender);
        oldChip.burnFrom(msg.sender, oldBalance);
        newChip.mint(msg.sender, oldBalance);
    }

    function migrateFish() external {
        uint256 oldBalance = oldFish.balanceOf(msg.sender);
        oldFish.burnFrom(msg.sender, oldBalance);
        newFish.mint(msg.sender, oldBalance);
    }

    function migrateMpea() external {
        uint256 oldBalance = oldMpea.balanceOf(msg.sender);
        oldMpea.burnFrom(msg.sender, oldBalance);
        newChip.mint(msg.sender, oldBalance);
    }
}
