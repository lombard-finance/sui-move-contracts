```mermaid
flowchart TD
    L[Lombard] --> |uses| MR[ Minter Role ]
    MR --> |borrow| TC[/TreasuryCap/]
    TC --> |call| MF[Mint Function]
    MF --> |Verify| MS[Multi-Sig Account] 
	  MS --> |Mint Tokens| LBTC[/LBTC/]
	  LBTC --> |transfer to| UR[User Sui Address]
```