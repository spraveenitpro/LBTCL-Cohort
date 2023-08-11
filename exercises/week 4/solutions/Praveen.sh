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
	bitcoin-cli -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Miner generatetoaddress 104 $(bitcoin-cli -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Miner getnewaddress) >> /dev/null
	# Fund the Employer wallet
	bitcoin-cli -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Miner sendtoaddress  $(bitcoin-cli -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Employer getnewaddress) 15

	bitcoin-cli -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Miner generatetoaddress 1 $(bitcoin-cli -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Miner getnewaddress)

	Miner_Balance=$(bitcoin-cli -regtest  -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Miner getbalance)
	Employer_Balance=$(bitcoin-cli -regtest  -datadir=${HOME}/tmp_bitcoind_regtest -rpcwallet=Employer getbalance)

	echo "Miner has: " $Miner_Balance
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
clean_up