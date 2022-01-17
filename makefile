all :; forge build
test :; forge clean && forge test --verbosity 3 --fork-url ${ETH_RPC_URL}