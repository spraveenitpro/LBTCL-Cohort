#!/bin/bash

echo "Let there be a node"
ORANGE='\033[35m'
NC='\033[0m' # No Color


# Function to delete regtest dir if already exists within /Users/$USER/Library/Application\ Support/Bitcoin
setup_regtest_env() {
	echo "**************************************"
	echo -e "${ORANGE}Setup regtest directory ${NC}"
	echo "**************************************"

	# delete  ~/tmp_bitcoind_regtest if it exists
	if [ -d ~/tmp_bitcoind_regtest ]; then
		rm -rf ~/tmp_bitcoind_regtest
	fi


	mkdir ~/tmp_bitcoind_regtest
	chown -R $USER ~/tmp_bitcoind_regtest
	cd ~/tmp_bitcoind_regtest

	touch bitcoin.conf

	echo "regtest=1" >> bitcoin.conf
	echo "fallbackfee=0.00001" >> bitcoin.conf
	echo "server=1" >> bitcoin.conf
	echo "txindex=1" >> bitcoin.conf
	echo "daemon=1" >> bitcoin.conf


}

# Function to start bitcoind in the background and run the last command
start_bitcoind() {
	echo "**************************************"
	echo -e "${ORANGE}Starting bitcoind${NC}"
	echo "**************************************"
	# Start bitcoind in the background
	bitcoind -daemon -regtest  -datadir=${HOME}/tmp_bitcoind_regtest  -conf=${HOME}/tmp_bitcoind_regtest/bitcoin.conf
	# Wait for 10 seconds
	sleep 4
	bitcoin-cli -regtest -datadir=${HOME}/tmp_bitcoind_regtest getblockchaininfo

}

# Function to create 2 wallets called Miner and Trader

create_wallets() {
	echo "**************************************"
	echo -e "${ORANGE}Creating Three wallets${NC}"
	echo "**************************************"
	# Create a wallet called Miner
	bitcoin-cli  -datadir=${HOME}/tmp_bitcoind_regtest -named createwallet wallet_name=Miner
	# Create a wallet called Alice
	bitcoin-cli  -datadir=${HOME}/tmp_bitcoind_regtest -named createwallet wallet_name=Employee

	# Create a wallet called Bob
	bitcoin-cli  -datadir=${HOME}/tmp_bitcoind_regtest -named createwallet wallet_name=Employer

}

# Fund the wallets

fund_miner_employer() {
	echo "**************************************"
	echo -e "${ORANGE}Funding Miner and Employer${NC}"
	echo "**************************************"
	# Fund the Miner wallet
	miner_address=$(bitcoin-cli -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Miner getnewaddress)
	bitcoin-cli -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Miner generatetoaddress 104 $miner_address >> /dev/null
	bitcoin-cli -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Miner generatetoaddress 1 $(bitcoin-cli -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Miner getnewaddress) >> /dev/null


	# Fund the Employer wallet
	bitcoin-cli -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Miner sendtoaddress  $(bitcoin-cli -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Employer getnewaddress) 200 >> /dev/null

	bitcoin-cli -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Miner generatetoaddress 1 $(bitcoin-cli -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Miner getnewaddress) >> /dev/null

	Miner_Balance=$(bitcoin-cli -regtest  -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Miner getbalance)
	Employer_Balance=$(bitcoin-cli -regtest  -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Employer getbalance)

	echo "Miner has: " $Miner_Balance
	echo "Employer has: " $Employer_Balance

}

create_salary_transaction() {
	echo "**************************************"
	echo -e "${ORANGE}Trying to Pay salary to employee with locktime${NC}"
	echo "**************************************"

	utxo_txid=$(bitcoin-cli -regtest  -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Employer listunspent | jq -r '.[0].txid'  )
	utxo_vout=$(bitcoin-cli -regtest  -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Employer listunspent | jq -r '.[0].vout'  )
	recipient=$(bitcoin-cli -regtest  -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Employee getnewaddress legacy)
	changeaddress=$(bitcoin-cli -regtest  -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Employer getrawchangeaddress legacy)

	fee=0.00001
	salary=40
	#remainder=$($Employer_Balance - $fee - $amount| bc)
	remainder=$(echo "scale=5; $Employer_Balance - $fee - $salary" | bc)


	#rawtxhex=$(bitcoin-cli -regtest  -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Employer createrawtransaction inputs='''[{"txid":"'$utxo_txid'", "vout":'$utxo_vout'}]''' outputs='''{"'$recipient'":40, "'$changeaddress'":'$remainder'}''')
	rawtxhex=$(bitcoin-cli -named -regtest -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Employer createrawtransaction inputs='''[{"txid":"'$utxo_txid'", "vout":'$utxo_vout'}]''' outputs='''{"'$recipient'":40, "'$changeaddress'":'$remainder'}''' locktime=500 )
	#echo "rawtxhex: " $rawtxhex
	#bitcoin-cli -regtest -datadir=${HOME}/tmp_bitcoind_regtest decoderawtransaction $rawtxhex
	signedtx=$(bitcoin-cli -regtest -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Employer signrawtransactionwithwallet $rawtxhex | jq -r '.hex')
	#bitcoin-cli -regtest -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Employer signrawtransactionwithwallet $rawtxhex | jq -r '.hex'

	#echo $signedtx
	bitcoin-cli -named -regtest -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Employer sendrawtransaction $signedtx

	echo "**************************************"
	echo -e "${ORANGE}As you can see, it will not broadcast due to the timelock while giving the above error${NC}"
	echo "**************************************"

	#bitcoin-cli  -regtest -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Employer getblockcount
}

mine_and_broadcast_transaction() {
	echo "**************************************"
	echo -e "${ORANGE}Mining blocks till locktime${NC}"
	echo "**************************************"
	#bitcoin-cli -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Miner generatetoaddress 395 $miner_address >> /dev/null


	bitcoin-cli -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Miner generatetoaddress 395 $miner_address >> /dev/null &
	# Save the PID of the background process
	bg_pid=$!

	# Hide the cursor
	tput civis

	# Display the dots while the background command is running
	count=0
	while kill -0 $bg_pid 2> /dev/null; do
		count=$(( (count + 1) % 45 ))
		printf "\rGenerating blocks: %${count}s" | tr ' ' '.'
		sleep 0.5
	done

	# Print a newline and show the cursor when done
	echo ""
	tput cnorm



	bitcoin-cli -named -regtest -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Employer sendrawtransaction $signedtx >> /dev/null
	bitcoin-cli -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Miner generatetoaddress 1 $miner_address >> /dev/null

	echo "Block generation completed"
	Employer_Balance=$(bitcoin-cli -regtest  -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Employer getbalance)
	Employee_Balance=$(bitcoin-cli -regtest  -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Employee getbalance)
	echo "Employee has: " $Employee_Balance
	echo "Employer has: " $Employer_Balance



}



clean_up() {
	echo "****************************************"
	echo -e "${ORANGE}Cleaning up${NC}"
	echo "****************************************"
	# Stop bitcoind
	bitcoin-cli -regtest -datadir=${HOME}/tmp_bitcoind_regtest stop
	# Delete the regtest directory
	rm -rf ~/tmp_bitcoind_regtest


}



setup_regtest_env
start_bitcoind
create_wallets
fund_miner_employer
create_salary_transaction
mine_and_broadcast_transaction
clean_up