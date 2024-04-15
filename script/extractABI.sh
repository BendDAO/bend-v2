# !/bin/bash
# NOTE: THis script requires the jq utlity or be installed
# for each contract in source folder, extract abi from artifact and create new json

for contractPath in src/*.sol
do
    fileWithExtension=${contractPath##*/}
    filename=${fileWithExtension%.*}
    # if directory doesn't exist, then create it
    mkdir -p release/abis
    jq '.abi' out/${fileWithExtension}/${filename}.json > release/abis/${filename}.json
done

for contractPath in src/modules/*.sol
do
    fileWithExtension=${contractPath##*/}
    filename=${fileWithExtension%.*}
    # if directory doesn't exist, then create it
    mkdir -p release/abis
    jq '.abi' out/${fileWithExtension}/${filename}.json > release/abis/${filename}.json
done
