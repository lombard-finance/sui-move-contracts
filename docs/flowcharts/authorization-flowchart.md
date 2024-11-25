```mermaid
flowchart TD
    L[Lombard] -->|uses| P[/Publisher/]
    P --> PA[Authorize]
    PA --> MRA[Minter Role]
    PA --> PRA[Pauser Role]
    P --> PD[Deauthorize]
    PD --> MRD[Minter Role]
    PD --> PRD[Pauser Role]
```