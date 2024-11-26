```mermaid
flowchart TD
    L[Lombard Multisig Address] -->|publishes| SC[LBTC Smart Contract]
    SC --> |uses| CT[/ControlledTreasury/]
    CT --> |is authorized| AC[AdminCap]
    AC --> PA[Assign Role]
    PA --> MRA[MinterCap]
    PA --> PRA[PauserCap]
    AC --> PD[Revoke Role]
    PD --> MRD[MinterCap]
    PD --> PRD[PauserCap]
```
