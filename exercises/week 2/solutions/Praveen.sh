#!/bin/bash

echo "Let there be a node"
ORANGE='\033[35m'
NC='\033[0m' # No Color

# Function to create a bitcoin.conf file in the /Users/$USER/Library/Application Support/Bitcoin
create_conf_file() {
	echo "**************************************"
	echo -e "${ORANGE}Creating bitcoin.conf file${NC}"
	echo "**************************************"
	cd /Users/$USER/Library/Application\ Support/Bitcoin

	# Create a file called bitcoin.conf
	touch bitcoin.conf

	echo "regtest=1" >> bitcoin.conf
	echo "fallbackfee=0.0001" >> bitcoin.conf
	echo "server=1" >> bitcoin.conf
	echo "txindex=1" >> bitcoin.conf
	echo "daemon=1" >> bitcoin.conf
}

# Function to delete regtest dir if already exists within /Users/$USER/Library/Application\ Support/Bitcoin
delete_regtest_dir() {
	echo "**************************************"
	echo -e "${ORANGE}Deleting regtest directory if exists${NC}"
	echo "**************************************"
	cd /Users/$USER/Library/Application\ Support/Bitcoin
	if [ -d "regtest" ]; then
		echo "Deleting regtest directory"
		rm -rf regtest
	fi
}

# Function to start bitcoind in the background and run the last command
start_bitcoind() {
	echo "**************************************"
	echo -e "${ORANGE}Starting bitcoind${NC}"
	echo "**************************************"
	# Start bitcoind in the background
	bitcoind -daemon -regtest
	# Wait for 10 seconds
	sleep 4
	# Now you can run bitcoin-cli getinfo
	bitcoin-cli -regtest -getinfo
}

# Function to create 2 wallets called Miner and Trader

create_wallets() {
	echo "**************************************"
	echo -e "${ORANGE}Creating two wallets${NC}"
	echo "**************************************"
	# Create a wallet called Miner
	bitcoin-cli -regtest createwallet "Miner"
	# Create a wallet called Trader
	bitcoin-cli -regtest createwallet "Trader"
}

# Function to fund miner wallet

fund_miner_wallets() {
	echo "**************************************"
	echo -e "${ORANGE}Generate an address for miner and mine blocks${NC}"
	echo "**************************************"

	mineraddress=$(bitcoin-cli -regtest -rpcwallet="Miner" getnewaddress "Mining Reward")
	bitcoin-cli -regtest -rpcwallet="Miner" generatetoaddress 103 $mineraddress
	original_balance=$(bitcoin-cli  -regtest -rpcwallet="Miner" getbalance)
	echo "Original balance in $mineraddress $original_balance"

	read -n 1 -s -r -p "Press any key to continue"
}

create_rbf_transaction() {
	utxo1_txid=$(bitcoin-cli -regtest -rpcwallet="Miner" listunspent | jq -r '.[0] | .txid')
	utxo2_txid=$(bitcoin-cli -regtest -rpcwallet="Miner" listunspent | jq -r '.[1] | .txid')
	utxo3_txid=$(bitcoin-cli -regtest -rpcwallet="Miner" listunspent | jq -r '.[2] | .txid')

	utxo1_vout=$(bitcoin-cli -regtest -rpcwallet="Miner" listunspent | jq -r '.[0] | .vout')
	utxo2_vout=$(bitcoin-cli -regtest -rpcwallet="Miner" listunspent | jq -r '.[1] | .vout')
	utxo3_vout=$(bitcoin-cli -regtest -rpcwallet="Miner" listunspent | jq -r '.[2] | .vout')

	traderaddress=$(bitcoin-cli -regtest -rpcwallet="Trader" getnewaddress address_type=p2sh-segwit)
	changeaddress=$(bitcoin-cli -regtest -rpcwallet="Miner" getnewaddress address_type=p2sh-segwit)

	echo "utxo1_txid $utxo1_txid"
	echo "utxo2_txid $utxo2_txid"

	echo "utxo1_vout $utxo1_vout"
	echo "utxo2_vout $utxo2_vout"

	echo "traderaddress $traderaddress"
	bitcoin-cli -regtest -rpcwallet="Miner" listunspent

	#Create a raw transaction
	parentrawtxhex=$(bitcoin-cli -regtest -named  -rpcwallet="Miner" createrawtransaction inputs='''[ { "txid": "'$utxo1_txid'", "vout": '$utxo1_vout',  "sequence": 1}, { "txid": "'$utxo2_txid'", "vout": '$utxo2_vout',  "sequence": 1} ]''' outputs='''{ "'$traderaddress'": 70, "'$changeaddress'": 29.9999 }''')
	echo "Raw transaction $rawtxhex"
	signedtx=$(bitcoin-cli -regtest -named  -rpcwallet="Miner"  signrawtransactionwithwallet hexstring=$parentrawtxhex | jq -r '.hex')
	echo "Signed transaction $signedtx"
	bitcoin-cli -regtest -named  -rpcwallet="Miner" sendrawtransaction hexstring=$signedtx
	echo "Signed transaction $signedtx sent!"

	#tx=$(bitcoin-cli -regtest getrawmempool | jq -r '.[]')
	#completetx=$(bitcoin-cli -regtest getrawtransaction $tx 1)



	#bitcoin-cli -regtest -named  -rpcwallet="Miner" sendtoaddress $traderaddress 70
}


print_json() {
	tx=$(bitcoin-cli -regtest -rpcwallet="Miner"  getrawmempool  | jq -r '.[]' )
	json=$(bitcoin-cli -regtest -rpcwallet="Miner" decoderawtransaction $parentrawtxhex)
	echo $json | jq -r
	inputtx1=$(echo $json | jq -r '.vin[0].txid')
	inputtx2=$(echo $json | jq -r '.vin[1].txid')
	inputvout1=$(echo $json | jq -r '.vin[0].vout')
	inputvout2=$(echo $json | jq -r '.vin[1].vout')
	trader_script_pubkey=$(echo $json | jq -r '.vout[0].scriptPubKey.hex')
	miner_script_pubkey=$(echo $json | jq -r '.vout[1].scriptPubKey.hex')
	trader_amount=$(echo $json | jq -r '.vout[0].value')
	miner_amount=$(echo $json | jq -r '.vout[1].value')
	weight=$(echo $json | jq -r '.weight')
	json_fees=$(bitcoin-cli -regtest -rpcwallet="Miner" gettransaction $tx | jq -r '.fee')

	#json_fees_tx=$( bitcoin-cli -regtest getrawmempool | jq -r '.[]' )
	#json_fees=$(bitcoin-cli -regtest -rpcwallet="Miner" getrawtransaction $json_fees_tx) | jq -r '.fees'

	#echo $inputtx1, $inputtx2, $inputvout1, $inputvout2, $trader_script_pubkey, $miner_script_pubkey, $trader_amount, $miner_amount, $weight, $json_fees
	echo "**************** JSON of Parent Transaction *********************"
	parent_json='''{ "input": [ { "txid": "'$inputtx1'", "vout": '$inputvout1'}, { "txid": "'$inputtx2'", "vout": '$inputvout2'} ], "output": [ {"script_pubkey": "'$trader_script_pubkey'", "amount": "'$trader_amount'"}, {"script_pubkey": "'$miner_script_pubkey'", "amount": "'$miner_amount'"}] , "weight": "'$weight'", "fees": "'$json_fees'" }'''

	echo $parent_json | jq -r






}




clean_up() {
	echo "****************************************"
	echo -e "${ORANGE}Cleaning up${NC}"
	echo "****************************************"
	# Stop bitcoind
	bitcoin-cli -regtest stop
	# Delete the regtest directory
	rm -rf regtest
	# Delete the bitcoin.conf file
	#rm /Users/$USER/Library/Application\ Support/Bitcoin/bitcoin.conf


}



#create_conf_file
delete_regtest_dir
start_bitcoind
create_wallets
fund_miner_wallets
create_rbf_transaction
print_json
#clean_up
