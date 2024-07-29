
### Project

When opportunity knocks, you gunna answer it? One Shot lets a user mint a rapper NFT, have it gain experience in the streets (staking) and
Rap Battle against other NFTs for Cred.

• `OneShot.sol`:

The Rapper NFT.

Users mint a rapper that begins with all the flaws and self-doubt we all experience.
NFT Mints with the following properties:

* `weakKnees` - True
* `heavyArms` - True
* `spaghettiSweater` - True
* `calmandReady` - False
* `battlesWon` - 0

The only way to improve these stats is by staking in the `Streets.sol`:


• `Streets.sol`:

Experience on the streets will earn you Cred and remove your rapper's doubts.

* Staked Rapper NFTs will earn 1 Cred ERC20/day staked up to 4 maximum
* Each day staked a Rapper will have properties change that will help them in their next Rap Battle


• `RapBattle.sol`:

Users can put their Cred on the line to step on stage and battle their Rappers. A base skill of 50 is applied to all rappers in battle, and this is modified by the properties the rapper holds.

* WeakKnees - False = +5
* HeavyArms - False = +5
* SpaghettiSweater - False = +5
* CalmAndReady - True = +10

Each rapper's skill is then used to weight their likelihood of randomly winning the battle!

* Winner is given the total of both bets

• `CredToken.sol`:

ERC20 token that represents a Rapper's credibility and time on the streets. The primary currency at risk in a rap battle.


• `Chains`:

This Contract will be deployed on `Ethereum` and `Arbitrum`.


### Questions

- How the Rap Battle Works?
- What are the rapper doubts?


### Attack Vectors

- Can we do something that `Oneshot.sol` mints us a `Rapper NFT` with different stats? `no`
- Can we do something so we earn more `Cred` token per day? `idk i did not find a way`
- Can we do something so we change our `Rapper NFT` properties by ourselves without waiting a day? `idk i did not find a way`
- Can we exploit something so our `Rapper NFT` gets the best Properties? `yes we did when starting the battle as challenger`
- Can we exploint somethign so other People `Rapper NFT`s Properties get worse than Yesterday? `no i guess`
- Can user start a Rap battle without putting `Cred` Token on the Line? `yes sir`
- since we deploy on `ethereum` and `arbitrum`, keep in mind the low level `opcode` differences and even differences in `global variables like block.timestamp, block.numebr` and...
- in `CredToken.sol` only `streetContract` can mint new `Cred` Tokens, see if you can find a way to make `streetContract` to call `mint()` to mint yourself new `Cred` Tokens. `i did not find a way to do that`
- see how you can use `streetContract` to update your Rappers stats with `OneShot:updateRapperStats()` function. (only streetContract can call it) `i didn't find a way`

### Notes

- Make sure the User NFT has this stats:

    * `weakKnees` - True
    * `heavyArms` - True
    * `spaghettiSweater` - True
    * `calmandReady` - False
    * `battlesWon` - 0

- Seems like when we stake `Rapper NFT`, overtime we as Rapper get better once we Earn `Cred Token`.
- Seems like the maximum amount of `Rapper NFT` we can stake is `4` i guess. `NO`
- Seems like the winner of rap battle is choosed randomly. (keep in mind the weak randomness vulnerablity.) `yup we did find a vulnerablity in it`
- Seems like the winner gets total `Cred` token that was put on the line by both Rappers.   `yup`
- we have access to `approve`, `transferFrom`, `safeTransferFrom` in `Oneshot.sol` Rapper NFT.