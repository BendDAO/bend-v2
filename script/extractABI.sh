# !/bin/bash
# NOTE: THis script requires the jq utlity or be installed
# for each contract in source folder, extract abi from artifact and create new json

# if directory doesn't exist, then create it
rm -rf release/abis
mkdir -p release/abis

for contractPath in src/*.sol
do
    fileWithExtension=${contractPath##*/}
    filename=${fileWithExtension%.*}
    jq '.abi' out/${fileWithExtension}/${filename}.json > release/abis/${filename}.json
done

for contractPath in src/modules/*.sol
do
    fileWithExtension=${contractPath##*/}
    filename=${fileWithExtension%.*}
    jq '.abi' out/${fileWithExtension}/${filename}.json > release/abis/${filename}.json
done

jq '.abi' out/DefaultInterestRateModel.sol/DefaultInterestRateModel.json > release/abis/DefaultInterestRateModel.json

jq '.abi' out/YieldRegistry.sol/YieldRegistry.json > release/abis/YieldRegistry.json
jq '.abi' out/YieldAccount.sol/YieldAccount.json > release/abis/YieldAccount.json
jq '.abi' out/YieldEthStakingLido.sol/YieldEthStakingLido.json > release/abis/YieldEthStakingLido.json
jq '.abi' out/YieldEthStakingEtherfi.sol/YieldEthStakingEtherfi.json > release/abis/YieldEthStakingEtherfi.json
jq '.abi' out/YieldSavingsDai.sol/YieldSavingsDai.json > release/abis/YieldSavingsDai.json
jq '.abi' out/YieldSavingsUSDS.sol/YieldSavingsUSDS.json > release/abis/YieldSavingsUSDS.json

jq '.abi' out/BendV1Migration.sol/BendV1Migration.json > release/abis/BendV1Migration.json
