# How to run the script

## Env

Fill .env file at project root.

## Deployment

### GAS Price Unit

5Gwei = 5000000000.
10Gwei = 10000000000.
60Gwei = 60000000000.
100Gwei = 100000000000.

### Deploy Pool Contracts

```shell
# Pool Contracts
. ./setup-env.sh && forge script ./script/DeployPoolFull.s.sol -vvvvv --private-key ${PRIVATE_KEY} --etherscan-api-key ${ETHERSCAN_KEY} --rpc-url {NETWORK} --broadcast --slow --verify --with-gas-price {GAS}

# Init Pool Configs
. ./setup-env.sh && forge script ./script/InitConfigPool.s.sol -vvvvv --private-key ${PRIVATE_KEY} --etherscan-api-key ${ETHERSCAN_KEY} --rpc-url {NETWORK} --broadcast --slow --verify --with-gas-price {GAS}
```

### Deploy Yield Contracts

```shell
# Price Adapters
. ./setup-env.sh && forge script ./script/DeployPriceAdapter.s.sol -vvvvv --private-key ${PRIVATE_KEY} --etherscan-api-key ${ETHERSCAN_KEY} --rpc-url {NETWORK} --broadcast --slow --verify --with-gas-price {GAS}

# Pool Contracts
. ./setup-env.sh && forge script ./script/DeployYieldStaking.s.sol -vvvvv --private-key ${PRIVATE_KEY} --etherscan-api-key ${ETHERSCAN_KEY} --rpc-url {NETWORK} --broadcast --slow --verify --with-gas-price {GAS}

# Init Yield Configs
. ./setup-env.sh && forge script ./script/InitConfigYield.s.sol -vvvvv --private-key ${PRIVATE_KEY} --etherscan-api-key ${ETHERSCAN_KEY} --rpc-url {NETWORK} --broadcast --slow --verify --with-gas-price {GAS}
```

## Install Modules

```shell
. ./setup-env.sh && forge script ./script/InstallModule.s.sol -vvvvv --private-key ${PRIVATE_KEY} --etherscan-api-key ${ETHERSCAN_KEY} --rpc-url {NETWORK} --broadcast --slow --verify --with-gas-price {GAS}
```

## Query

```shell
forge script ./script/QueryPool.s.sol --rpc-url sepolia -vvvvv
```

## Verify

```shell
forge verify-contract --etherscan-api-key ${ETHERSCAN_KEY} --rpc-url sepolia ${ContractAddress} ${ContractFile}:${ContractName}
```
