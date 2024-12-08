```
######                       ######     #    #######
#     # ###### #    # #####  #     #   # #   #     #
#     # #      ##   # #    # #     #  #   #  #     #
######  #####  # #  # #    # #     # #     # #     #
#     # #      #  # # #    # #     # ####### #     #
#     # #      #   ## #    # #     # #     # #     #
######  ###### #    # #####  ######  #     # #######
```

# BendDAO Protocol V2

This repository contains the smart contracts source code and markets configuration for BendDAO V2 Protocol. The repository uses Foundry as development environment for compilation, testing and deployment tasks.

---

## What are BendDAO Protocol V2?

BendDAO V2 Protocol brings you composable lending and leverage. It allows anyone to borrow in an overcollateralized fashion, leverage savings on MakerDAO, leverage stake on Lido, leverage restake with EigenLayer derivatives, bringing together lending and leverage in the same protocol!

V2 Protocol has three user sides to it:

Lenders deposit assets to earn passive yield.

Borrowers can use ERC20 & ERC721 as collaterals to borrow assets in an overcollateralized fashion.

Leverage users can use ERC721 as collaterals to borrow assets to create leverage positions, which can be used across DeFi, NFTs, RWA, etc.

---

## Documentation

[Doc Hub](https://docs.benddao.xyz)

[User Guide](https://docs.benddao.xyz/portal/v/v2)

[Dev Guide](https://docs.benddao.xyz/developers/v/v2-1)

---

## Audits

All audits are stored in the [audits](./audits/) folder and [online](https://docs.benddao.xyz/portal/v/v2/security-and-risks/audits).

---

## Bug bounty

A bug bounty is open on Immunefi. The rewards and scope are defined [here](https://immunefi.com/bounty/benddao/).

---

## Testing with [Foundry](https://github.com/foundry-rs/foundry) 🔨

For testing, make sure `yarn` and `foundry` are installed.

Alternatively, if you only want to set up

Refer to the `env.example` for the required environment variable.

```bash
npm run test
```

---

## Test coverage

Test coverage is reported using [foundry](https://github.com/foundry-rs/foundry) coverage with [lcov](https://github.com/linux-test-project/lcov) report formatting (and optionally, [genhtml](https://manpages.ubuntu.com/manpages/xenial/man1/genhtml.1.html) transformer).

To generate the `lcov` report, run the following:

```bash
npm run coverage:lcov
```

The report is then usable either:

- via [Coverage Gutters](https://marketplace.visualstudio.com/items?itemName=ryanluker.vscode-coverage-gutters) following [this tutorial](https://mirror.xyz/devanon.eth/RrDvKPnlD-pmpuW7hQeR5wWdVjklrpOgPCOA-PJkWFU)
- via HTML, using `npm run coverage:html` to transform the report and opening `coverage/index.html`

---

## Storage seatbelt

2 CI pipelines are currently running on every PR to check that the changes introduced are not modifying the storage layout of proxied smart contracts in an unsafe way:

- [storage-layout.sh](./scripts/storage-layout.sh) checks that the latest foundry storage layout snapshot is identical to the committed storage layout snapshot
- [foundry-storage-check](https://github.com/Rubilmax/foundry-storage-diff) is in test phase and will progressively replace the snapshot check

In the case the storage layout snapshots checked by `storage-layout.sh` are not identical, the developer must commit the updated storage layout snapshot stored under [snapshots/](./snapshots/) by running:

- `npm run storage-layout-generate` with the appropriate protocol parameters

---

## Deployment & Upgrades

Documents in the [script](./script/) folder.

---

## Questions & Feedback

For any questions or feedback, you can send an email to [developer@benddao.xyz](mailto:developer@benddao.xyz).

---

## Licensing

The primary license for BendDAO v2 is the Business Source License 1.1 (`BUSL-1.1`), see [`LICENSE`](./LICENSE).

However, some files can also be licensed under `GPL-2.0-or-later` (as indicated in their SPDX headers).
