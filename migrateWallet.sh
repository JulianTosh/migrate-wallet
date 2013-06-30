#!/bin/bash

usage() {
  cat << _EOU_
Usage: $0 <source wallet file> <target wallet file>
  $0 grabs unspent inputs from a source electrum wallet and splits them into
  two inputs in the target wallet - one as a spend, one as change.
_EOU_
}

if [ $# -eq 0 ]; then
 usage 
 exit
fi

walletFrom=$HOME/.electrum/$1
walletTo=$HOME/.electrum/$2

if [ ! -f $walletFrom ]; then
  echo $walletFrom does not exist
  usage
  exit
fi
echo $walletFrom exists.

if [ ! -f $walletTo ]; then
  echo $walletTo does not exist
  usage
  exit
fi
echo $walletTo exists.

electrum -w $walletFrom listunspent > /tmp/unspent
cat /tmp/unspent | head -n 8 | awk '/{/,/}/' > /tmp/input


fromAddress=$(cat /tmp/input | grep address | sed 's/.*\b\(1[0-9a-zA-Z]*\).*/\1/')
echo From=$fromAddress

toAddress=$(electrum -w $walletTo -b listaddresses | egrep "address|balance" | awk '{print $2}' | sed 's/[\",]//g' | paste - - | grep "0$" | head -n 2 |  awk '{print $1}' | head -n 1)
echo To=$toAddress

changeAddress=$(electrum -w $walletTo -b listaddresses | egrep "address|balance" | awk '{print $2}' | sed 's/[\",]//g' | paste - - | grep "0$" | head -n 2 |  awk '{print $1}' | tail -n +2)
echo Change=$changeAddress

txhash=$(cat /tmp/input | grep tx_hash | sed 's/tx_hash/txid/; s/[ \t\s,]//g')
echo Hash=$txhash

index=$(cat /tmp/input | grep index | sed 's/index/vout/; s/[ \t\s,]//g')
echo Index=$index

echo "Getting balance of unspent input..."
balance=$(electrum -w $walletFrom getaddressbalance $fromAddress | grep "\bconfirmed" | sed 's/.*\"\([0-9\.]\+\)\"$/\1/')
echo Balance=$balance

distributionPct=$(echo "scale=8; $((100 + ($ANDOM$RANDOM$RANDOM$RANDOM % 900000))) / 1000000" | bc)
echo Distribution = $distributionPct

send=$(printf "%2.8f" $( echo "scale=2; $balance * $distributionPct" | bc))
echo Send=$send

command="electrum -w $walletFrom --fromaddr=$fromAddress --changeaddr=$changeAddress createrawtransaction '[{$txhash,$index}]' '{\"$toAddress\":$send}'"
echo Command=$command
echo
echo == Unsigned TX ==
eval $command | tee /tmp/unsigned
cat /tmp/unsigned | qrencode -o - | display
