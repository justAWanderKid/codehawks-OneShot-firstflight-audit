// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IOneShot} from "./interfaces/IOneShot.sol";
import {Credibility} from "./CredToken.sol";
import {ICredToken} from "./interfaces/ICredToken.sol";

contract RapBattle {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    IOneShot public oneShotNft;
    ICredToken public credToken;

    // If someone is waiting to battle, the defender will be populated, otherwise address 0
    address public defender;
    uint256 public defenderBet;
    uint256 public defenderTokenId;

    // [INFO] @audit BASE_SKILL amount should be `50` as it's stated in docs.

    uint256 public constant BASE_SKILL = 65; // The starting base skill of a rapper
    uint256 public constant VICE_DECREMENT = 5; // -5 for each vice the rapper has
    uint256 public constant VIRTUE_INCREMENT = 10; // +10 for each virtue the rapper has

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event OnStage(address indexed defender, uint256 tokenId, uint256 credBet);
    event Battle(address indexed challenger, uint256 tokenId, address indexed winner);

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor(address _oneShot, address _credibilityContract) {
        oneShotNft = IOneShot(_oneShot);
        credToken = ICredToken(_credibilityContract);
    }



    // [LOW] @audit `_credBet` amount can be `0`, if an battle start's, it does not matter who won the battle, winner will receive nothing.
    function goOnStageOrBattle(uint256 _tokenId, uint256 _credBet) external {
        if (defender == address(0)) {
            defender = msg.sender;
            defenderBet = _credBet;
            defenderTokenId = _tokenId;

            emit OnStage(msg.sender, _tokenId, _credBet);

            oneShotNft.transferFrom(msg.sender, address(this), _tokenId);
            credToken.transferFrom(msg.sender, address(this), _credBet);
        } else {
            // credToken.transferFrom(msg.sender, address(this), _credBet);
            _battle(_tokenId, _credBet);
        }
    }
    


    // [HIGH] @audit challenger can start a battle without even having an `Rapper NFT` and `CredToken`. by passing Other Peoples Rapper NFT tokenId that has better stats and just entering the same number as `defenderBet`, if he won, then he will the prize otherwise the transaction will revert. 
    // [LOW] @audit `defender` and `challenger` can be same address in battle.
    // [HIGH] @audit if the challenger is an smartContract, he can start a battle, and after he find out he lost the battle, reverts the whole transaction, if he won it, then he will just take the prize.
    function _battle(uint256 _tokenId, uint256 _credBet) internal {
        address _defender = defender;
        require(defenderBet == _credBet, "RapBattle: Bet amounts do not match");
        uint256 defenderRapperSkill = getRapperSkill(defenderTokenId);
        uint256 challengerRapperSkill = getRapperSkill(_tokenId);
        uint256 totalBattleSkill = defenderRapperSkill + challengerRapperSkill;
        uint256 totalPrize = defenderBet + _credBet;

        // [HIGH] @audit attacker can use weak Randomness to findout if his gonna win the battle or not.
        uint256 random = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender))) % totalBattleSkill;

        // Reset the defender
        defender = address(0);
        // event Battle(address indexed challenger, uint256 tokenId, address indexed winner);
        
        // [LOW] @audit emitting wrong event, in event below we determinte the winner with this calculation: `random < defenderRapperSkill` and in if statement below we determine the winner by `random <= defenderRapperSkill`
        emit Battle(msg.sender, _tokenId, random < defenderRapperSkill ? _defender : msg.sender);

        // If random <= defenderRapperSkill -> defenderRapperSkill wins, otherwise they lose

        // [LOW] @audit we don't increment the winner of the battle RapperStats `battlesWon` number.
        if (random <= defenderRapperSkill) {
            // We give them the money the defender deposited, and the challenger's bet
            credToken.transfer(_defender, defenderBet);
            credToken.transferFrom(msg.sender, _defender, _credBet);
        } else {
            // Otherwise, since the challenger never sent us the money, we just give the money in the contract
            credToken.transfer(msg.sender, _credBet);
        }
        totalPrize = 0;
        // Return the defender's NFT
        oneShotNft.transferFrom(address(this), _defender, defenderTokenId);
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW AND PURE
    //////////////////////////////////////////////////////////////*/
    function getRapperSkill(uint256 _tokenId) public view returns (uint256 finalSkill) {
        IOneShot.RapperStats memory stats = oneShotNft.getRapperStats(_tokenId);
        finalSkill = BASE_SKILL;
        if (stats.weakKnees) {
            finalSkill -= VICE_DECREMENT;
        }
        if (stats.heavyArms) {
            finalSkill -= VICE_DECREMENT;
        }
        if (stats.spaghettiSweater) {
            finalSkill -= VICE_DECREMENT;
        }
        if (stats.calmAndReady) {
            finalSkill += VIRTUE_INCREMENT;
        }
    }
}
