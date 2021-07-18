#!/bin/bash
clear

#include lib
. /home/admin/_tor.commands.sh

# make sure txindex and wallet of bitcoin is on
/home/admin/config.scripts/network.wallet.sh on
/home/admin/config.scripts/network.txindex.sh on

# extract RPC credentials from bitcoin.conf - store only in var
RPC_USER=$(sudo cat /mnt/hdd/bitcoin/bitcoin.conf | grep rpcuser | cut -c 9-)
PASSWORD_B=$(sudo cat /mnt/hdd/bitcoin/bitcoin.conf | grep rpcpassword | cut -c 13-)

if [ "${chain}net" == "mainnet" ]; then
  BITCOINRPCPORT=8332
elif [ "${chain}net" == "testnet" ]; then
  BITCOINRPCPORT=18332
elif [ "${chain}net" == "signet" ]; then
  BITCOINRPCPORT=38332
fi

# check and set up the HS
/home/admin/config.scripts/tor.onion-service.sh bitcoin ${BITCOINRPCPORT} ${BITCOINRPCPORT}

hiddenService=$(sudo cat ${SERVICES_DATA_DIR}/bitcoin${BITCOINRPCPORT}/hostname)

# btcstandup://<rpcuser>:<rpcpassword>@<hidden service hostname>:<hidden service port>/?label=<optional node label>
quickConnect="btcstandup://$RPC_USER:$PASSWORD_B@$hiddenService:${BITCOINRPCPORT}/?label=$hostname"
echo
echo "scan the QR Code with Fully Noded to connect to your node:"
/home/admin/config.scripts/blitz.display.sh qr "${quickConnect}"
qrencode -t ANSI256 $quickConnect
echo "Press ENTER to return to the menu"
read key

# clean up
/home/admin/config.scripts/blitz.display.sh hide
clear