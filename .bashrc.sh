export PATH=~/node_scripts:~/.cabal/bin:~/.ghcup/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/binexport 

CNODE_HOME=/opt/cardano/cnode

alias cn='cd /opt/cardano/cnode/'
alias cno='xdg-open /opt/cardano/cnode'
alias open='xdg-open ./'
alias socket="export CARDANO_NODE_SOCKET_PATH=$CNODE_HOME/sockets/node0.socket"
alias socket1="export CARDANO_NODE_SOCKET_PATH=$CNODE_HOME/sockets/node1.socket"
alias peers="netstat -tupn | grep cardano | grep :8081 | grep 192. | grep ESTABLISHED"

shuttle() {
  file="$1"
  cp ${file} /media/bswan/Tx-shuttle/${file}
}

rm-db() {
  rm -r /opt/cardano/cnode/db/*
  rm -r /opt/cardano/cnode/db1/*
  rm -r /opt/cardano/cnode/db2/*
  rm -r /opt/cardano/cnode/logs/*
}

protocol-params() {
  cardano-cli query protocol-parameters --mainnet --out-file ~/tmp/protparams.json
  cat "/home/bswan/tmp/protparams.json"
}

getSlotTip() {
  cardano-cli query tip --mainnet | jq -r '.slot'
}

kes() {
  slotsPerKESPeriod=129600
  currSlot=$(getSlotTip)
  echo ""
  echo "slotsPerKESPeriod: ${slotsPerKESPeriod}"
  echo ""
  echo "KES: $((currSlot / slotsPerKESPeriod))"
  echo ""
}

getutxo() {
  addr=$1
  echo ""
  echo "address:"
  echo "${addr}"
  cardano-cli shelley query utxo --address ${addr} --mainnet
}

decoderaw() {
  file="$1"
  cardano-cli shelley text-view decode-cbor --in-file ${file}
}

submitx() {
  submitArgs=(
    transaction submit
    --tx-file tx.signed
    --cardano-mode
    --mainnet
  )

  cardano-cli ${submitArgs[*]}
}

ledger-state() {
  cardano-cli query ledger-state --mainnet > ~/ledger.json
} 

send-some-ada() {

  # Handle script arguments
  returnAddr="$1"
  utxo=$2
  index=$3
  utxo_balance="$4"
  amount_to_send="$5"
  recipientAddr="$6"
  tx_in="${utxo}#${index}"
  sKey=payment.skey


  currSlot=$(getSlotTip)
  ttlValue=$(( currSlot + 1000 ))
  change=$(( utxo_balance - amount_to_send ))

  tmpTx4FeeCalcArgs=(
    shelley transaction build-raw 
    --tx-in ${tx_in}
    --tx-out ${recipientAddr}+${amount_to_send}
    --tx-out ${returnAddr}+${change}
    --ttl ${ttlValue} 
    --fee 0
    --out-file tx0.tmp
  )
  cardano-cli ${tmpTx4FeeCalcArgs[*]}

  minFeeArgs=(
    shelley transaction calculate-min-fee
    --tx-body-file tx0.tmp
    --tx-in-count 1
    --tx-out-count 2
    --mainnet
    --witness-count 1
    --byron-witness-count 0
    --protocol-params-file ~/tmp/protparams.json
  )
  minFee=$([[ "$(cardano-cli ${minFeeArgs[*]})" =~ ([0-9]+) ]] && echo ${BASH_REMATCH[1]})

  newBalance=$(( utxo_balance - amount_to_send - minFee ))
  txOutRecipient="${recipientAddr}+${amount_to_send}"
  txOutChange="${returnAddr}+${newBalance}"

  buildArgs=(
    shelley transaction build-raw
    --tx-in ${tx_in}
    --tx-out ${txOutRecipient}
    --tx-out ${txOutChange}
    --ttl ${ttlValue}
    --fee ${minFee}
    --out-file tx-send-some-ada.raw
  )

  signArgs=(
    shelley transaction sign
    --tx-body-file tx-send-some-ada.raw
    --signing-key-file ${sKey}
    --mainnet
    --out-file tx.signed
  )

  # submitArgs=(
  #   shelley transaction submit
  #   --tx-file "/home/bswan/tmp"/tx.signed
  #   --cardano-mode
  #   --testnet-magic 42
  # )

  cardano-cli ${buildArgs[*]}
  echo "cardano-cli ${signArgs[*]}" > cmd-send-some-ada.txt

  echo "--------------------------------------"
  echo ""
  echo "ttl: ${ttlValue}"
  echo "fee: ${minFee}"
  echo ""
  echo "${tx_in}"
  echo "is sending:"
  echo "${amount_to_send}"
  echo "From address:"
  echo "${returnAddr}"
  echo "To address:"
  echo "${recipientAddr}"
  echo "With a change of:"
  echo "${newBalance}"
  echo "${minFee} + ${amount_to_send} +  ${newBalance} = $((amount_to_send + minFee + newBalance)))"

  echo ""
  echo ""
  echo ./tx-send-some-ada.raw
  echo ./cmd-send-some-ada.txt
  echo "--------------------------------------"
}

send-all-ada() {

  # Handle script arguments
  utxo=$1
  index=$2
  amount="$3"
  tx_in="${utxo}#${index}"
  recipientAddr="$4"
  sKey=payment.skey


  currSlot=$(getSlotTip)
  ttlValue=$(( currSlot + 1000 ))

  tmpTx4FeeCalcArgs=(
    shelley transaction build-raw 
    --tx-in ${tx_in}
    --tx-out ${recipientAddr}+${amount}
    --ttl ${ttlValue} 
    --fee 0
    --out-file tx0.tmp
  )
  cardano-cli ${tmpTx4FeeCalcArgs[*]}

  minFeeArgs=(
    shelley transaction calculate-min-fee
    --tx-body-file tx0.tmp
    --tx-in-count 1
    --tx-out-count 1
    --mainnet
    --witness-count 1
    --byron-witness-count 0
    --protocol-params-file ~/tmp/protparams.json
  )
  minFee=$([[ "$(cardano-cli ${minFeeArgs[*]})" =~ ([0-9]+) ]] && echo ${BASH_REMATCH[1]})

  newBalance=$(( amount - minFee ))
  txOut="${recipientAddr}+${newBalance}"

  buildArgs=(
    shelley transaction build-raw
    --tx-in ${tx_in}
    --tx-out ${txOut}
    --ttl ${ttlValue}
    --fee ${minFee}
    --out-file tx-send-all.raw
  )

  signArgs=(
    shelley transaction sign
    --tx-body-file tx-send-ada-all.raw
    --signing-key-file ${sKey}
    --mainnet
    --out-file tx.signed
  )

  cardano-cli ${buildArgs[*]}
  echo "cardano-cli ${signArgs[*]}" > cmd-send-all.txt

  # submitArgs=(
  #   shelley transaction submit
  #   --tx-file "/home/bswan/tmp"/tx.signed
  #   --cardano-mode
  #   --testnet-magic 42
  # )

  echo "--------------------------------------"
  echo ""
  echo "ttl: ${ttlValue}"
  echo "fee: ${minFee}"
  echo ""
  echo "${tx_in}"
  echo "is sending:"
  echo "${newBalance}"
  echo "To address:"
  echo "${recipientAddr}"
  echo "With a change of:"
  echo "${minFee} + ${amount} + ${newBalance} = $((amount + minFee + newBalance)))"

  echo ""
  echo ""
  echo ./tx-send-ada-all.raw
  echo ./cmd-send-ada-all.txt
  echo "--------------------------------------"
}

payment-keys() {
  cmdArgs=(
    shelley address key-gen
    --verification-key-file payment.vkey
    --signing-key-file payment.skey
  )
  cardano-cli ${cmdArgs[*]}
}

stake-keys() {
  cmdArgs=(
    shelley stake-address key-gen
    --verification-key-file stake.vkey
    --signing-key-file stake.skey
  )
  cardano-cli ${cmdArgs[*]}
}

base-address() {
  cmdArgs=(
    shelley address build
    --payment-verification-key-file payment.vkey
    --stake-verification-key-file stake.vkey
    --mainnet
    --out-file base.addr
  )
  cardano-cli ${cmdArgs[*]}
}

stake-cert() {
  cmdArgs=(
    shelley stake-address registration-certificate
    --stake-verification-key-file stake.vkey
    --out-file stake.cert
  )
  cardano-cli ${cmdArgs[*]}
}

node-cold-gen() {
  cmdArgs=(
    shelley node key-gen
    --cold-verification-key-file cold.vkey
    --cold-signing-key-file cold.skey
    --operational-certificate-issue-counter-file cold.counter
  )

  cardano-cli ${cmdArgs[*]}
}

node-vrf-gen() {
  cmdArgs=(
    shelley node key-gen-VRF
    --verification-key-file vrf.vkey
    --signing-key-file vrf.skey
  )

  cardano-cli ${cmdArgs[*]}
}

node-kes-gen() {
  cmdArgs=(
    shelley node key-gen-KES
    --verification-key-file kes.vkey
    --signing-key-file kes.skey
  )

  cardano-cli ${cmdArgs[*]}
}

delegation-certificate() {
  cold_vkey="cold.vkey"

  cmdArgs=(
    shelley stake-address delegation-certificate
    --stake-verification-key-file stake.vkey
    --cold-verification-key-file ${cold_vkey}
    --out-file delegation.cert
  )

  cardano-cli ${cmdArgs[*]}
}

pool-certificate() {
  # cardano-cli stake-pool metadata-hash --pool-metadata-file blackswanpool003.json
  # pool-margin 1% would be 0.01
  # se non cambia puoi usare talequale metadata, ma se cambia cambia filename
  # qui e' dove la VRF.vkey e' associata alla pool

  cmdArgs=(
    stake-pool registration-certificate
    --cold-verification-key-file /media/bswan/Tx-shuttle/BlackSwan/cold.vkey
    --vrf-verification-key-file /media/bswan/Tx-shuttle/BlackSwan/vrf.vkey
    --pool-pledge 25100000000
    --pool-cost 340000000
    --pool-margin 0.0299
    --pool-reward-account-verification-key-file /media/bswan/Tx-shuttle/BlackSwan/stake.vkey
    --pool-owner-stake-verification-key-file /media/bswan/Tx-shuttle/BlackSwan/stake.vkey
    --mainnet
    --pool-relay-ipv4 81.149.31.222
    --pool-relay-port 8081
    --metadata-url http://blackswanpool.com/blackswanpool003.json
    --metadata-hash bbace019d9634dd7a28392882dad55081731adf7ff970f1798b1b140a08d08b8
    --out-file pool.cert
  )
  cardano-cli ${cmdArgs[*]}
}

register-stake() {
  utxo=$1
  index=$2
  balance=$3
  tx_in="${utxo}#${index}"
  base_addr=$(cat base.addr)
  stake_cert_file="stake.cert"

  currSlot=$(getSlotTip)

  ttlValue=$(( currSlot + 1000 ))
  keyDeposit=$(cat "/home/bswan/tmp"/protparams.json | jq -r '.keyDeposit')

  #https://github.com/input-output-hk/cardano-node/releases/tag/1.27.0
  # NOT SURE CHANGES BRAKE CURRENT COMMANDS
  # There are some breaking changes:

  #   You must specify auxiliary scripts with --auxiliary-script-file instead of --script-file
  #   Scripts witnessing txins, certificates, withdrawals and minting must be paired with the thing they are witnessing.
  #   E.g:

  #   --certificate-file  $certfile --certificate-script-file $scriptfile
  #   --tx-out $txout --minting-script-file $scriptfile
  #   --withdrawal $withdrawal --withdrawal-script-file $scriptfile
  #   --tx-in $txin --txin-script-file $scriptfile

  #   Scripts are no longer specified at the tx signing stage. They are specified at the txbody stage.


  tmpTx4FeeCalcArgs=(
    shelley transaction build-raw
    --tx-in ${tx_in}
    --tx-out ${base_addr}+$(( balance - keyDeposit ))
    --ttl ${ttlValue}
    --fee 0
    --certificate-file ${stake_cert_file}
    --out-file tx0.tmp
  )
  # echo "cardano-cli ${tmpTx4FeeCalcArgs[*]}"
  cardano-cli ${tmpTx4FeeCalcArgs[*]}

  minFeeArgs=(
    shelley transaction calculate-min-fee
    --tx-body-file tx0.tmp
    --tx-in-count 1
    --tx-out-count 1
    --mainnet
    --witness-count 2
    --byron-witness-count 0
    --protocol-params-file ~/tmp/protparams.json
  )
  minFee=$([[ "$(cardano-cli ${minFeeArgs[*]})" =~ ([0-9]+) ]] && echo ${BASH_REMATCH[1]})

  newBalance=$(( balance - minFee - keyDeposit))
  tx_out="${base_addr}+${newBalance}"

  buildArgs=(
    shelley transaction build-raw
    --tx-in ${tx_in}
    --tx-out ${tx_out} 
    --ttl ${ttlValue}
    --fee ${minFee}
    --certificate-file ${stake_cert_file}
    --out-file tx-register-stake.raw
  )

  signArgs=(
    shelley transaction sign
    --tx-body-file tx-register-stake.raw
    --signing-key-file payment.skey
    --signing-key-file stake.skey
    --mainnet
    --out-file tx.signed
  )

  # submitArgs=(
  #   shelley transaction submit
  #   --tx-file "/home/bswan/tmp"/tx.signed
  #   --cardano-mode
  #   --testnet-magic 42
  # )

  cardano-cli ${buildArgs[*]}
  echo "cardano-cli ${signArgs[*]}" > cmd-register-stake.txt

  echo "--------------------------------------"
  echo "keyDeposit: ${keyDeposit}"
  echo ""
  echo "fee: ${minFee}"
  echo ""
  echo "--tx-out ${tx_out}"
  echo "${newBalance} + ${minFee} +  ${keyDeposit}= ${balance}"
  echo ""
  echo "ttl: ${ttlValue}"
  echo ./tx-register-stake.raw
  echo ./cmd-register-stake.txt
  echo "--------------------------------------"
}

register-pool() {
  utxo=$1
  index=$2
  balance=$3
  base_addr=$(cat base.addr)
  tx_in=${utxo}#${index}
  pledge_cert_file=delegation.cert
  pool_cert_file=pool.cert

  currSlot=$(getSlotTip)
  ttlValue=$(( currSlot + 1000 ))

  poolDeposit=$(cat ~/tmp/protparams.json | jq -r '.poolDeposit')
  echo "poolDeposit: ${poolDeposit}"

  tmpTx4FeeCalcArgs=(
    shelley transaction build-raw 
    --tx-in "${tx_in}"
    --tx-out "${base_addr}+$(( balance - poolDeposit ))"
    --ttl "${ttlValue}"
    --fee 0
    --out-file tx0.tmp
    --certificate-file "${pledge_cert_file}"
    --certificate-file "${pool_cert_file}"
  )
  cardano-cli ${tmpTx4FeeCalcArgs[*]}

  minFeeArgs=(
    shelley transaction calculate-min-fee
    --tx-body-file tx0.tmp
    --tx-in-count 1
    --tx-out-count 1
    --mainnet
    --witness-count 3
    --byron-witness-count 0
    --protocol-params-file ~/tmp/protparams.json
  )
  minFee=$([[ "$(cardano-cli ${minFeeArgs[*]})" =~ ([0-9]+) ]] && echo ${BASH_REMATCH[1]})

  newBalance=$(( balance - minFee - poolDeposit))
  tx_out="${base_addr}+${newBalance}"

  buildArgs=(
    shelley transaction build-raw 
    --tx-in "${tx_in}"
    --tx-out "${tx_out}"
    --ttl "${ttlValue}"
    --fee "${minFee}"
    --certificate-file "${pledge_cert_file}"
    --certificate-file "${pool_cert_file}"
    --out-file tx.raw
  )

  signArgs=(
    shelley transaction sign 
    --tx-body-file tx.raw
    --signing-key-file payment.skey
    --signing-key-file stake.skey
    --signing-key-file cold.skey
    --mainnet
    --out-file tx.signed
  )

  # submitArgs=(
  #   shelley transaction submit
  #   --tx-file "/home/bswan/tmp"/tx.signed
  #   --cardano-mode
  #   --testnet-magic 42
  # )

  cardano-cli ${buildArgs[*]}
  echo "cardano-cli ${signArgs[*]}" > cmd.txt

  echo "--------------------------------------"
  echo "poolDeposit: ${poolDeposit}"
  echo ""
  echo "ttl: ${ttlValue}"
  echo "fee: ${minFee}"
  echo ""
  echo "${tx_out}"
  echo "${newBalance} + ${minFee} +  ${poolDeposit} = ${balance} ($((newBalance + minFee + poolDeposit)))"
  echo ""
  echo ./tx.raw
  echo ./cmd.txt
  echo "--------------------------------------"
}

add-pledge() {
  utxo=$1
  index=$2
  balance=$3
  base_addr=$(cat base.addr)
  tx_in=${utxo}#${index}
  pledge_cert_file=delegation.cert
  pool_cert_file=pool.cert

  currSlot=$(getSlotTip)
  ttlValue=$(( currSlot + 1000 ))

  tmpTx4FeeCalcArgs=(
    shelley transaction build-raw 
    --tx-in "${tx_in}"
    --tx-out "${base_addr}+$((balance))"
    --ttl "${ttlValue}"
    --fee 0
    --out-file tx0.tmp
    --certificate-file "${pledge_cert_file}"
    --certificate-file "${pool_cert_file}"
  )
  cardano-cli ${tmpTx4FeeCalcArgs[*]}

  minFeeArgs=(
    shelley transaction calculate-min-fee
    --tx-body-file tx0.tmp
    --tx-in-count 1
    --tx-out-count 1
    --mainnet
    --witness-count 3
    --byron-witness-count 0
    --protocol-params-file ~/tmp/protparams.json
  )
  minFee=$([[ "$(cardano-cli ${minFeeArgs[*]})" =~ ([0-9]+) ]] && echo ${BASH_REMATCH[1]})

  newBalance=$(( balance - minFee ))
  tx_out="${base_addr}+${newBalance}"

  buildArgs=(
    shelley transaction build-raw 
    --tx-in "${tx_in}"
    --tx-out "${tx_out}"
    --ttl "${ttlValue}"
    --fee "${minFee}"
    --certificate-file "${pledge_cert_file}"
    --certificate-file "${pool_cert_file}"
    --out-file tx.raw
  )

  signArgs=(
    shelley transaction sign 
    --tx-body-file tx.raw
    --signing-key-file payment.skey
    --signing-key-file stake.skey
    --signing-key-file cold.skey
    --mainnet
    --out-file tx.signed
  )

  # submitArgs=(
  #   shelley transaction submit
  #   --tx-file "/home/bswan/tmp"/tx.signed
  #   --cardano-mode
  #   --testnet-magic 42
  # )

  cardano-cli ${buildArgs[*]}
  echo "cardano-cli ${signArgs[*]}" > cmd.txt

  echo "--------------------------------------"
  echo "poolDeposit: NONE"
  echo ""
  echo "ttl: ${ttlValue}"
  echo "fee: ${minFee}"
  echo ""
  echo "--tx-out ${tx_out}"
  echo "${newBalance} + ${minFee} = ${balance} ($((newBalance + minFee )))"
  echo ""
  echo ./tx.raw
  echo ./cmd.txt
  echo "--------------------------------------"
}

modify-pool-cert-pledge() {
  # not only to modify pool pledge but simply to reset anything associated with the pool, even if just VRF key
  utxo=$1
  index=$2
  balance=$3

  base_addr=$(cat /opt/cardano/cnode/priv/wallet/big_last_pledge/base.addr)
  tx_in=${utxo}#${index}
  pool_cert_file=pool.cert

  currSlot=$(getSlotTip)
  ttlValue=$(( currSlot + 10000 ))

  tmpTx4FeeCalcArgs=(
    transaction build-raw 
    --tx-in "${tx_in}"
    --tx-out "${base_addr}+$((balance))"
    --ttl "${ttlValue}"
    --fee 0
    --out-file 0-tx0.tmp
    --certificate-file "${pool_cert_file}"
  )
  cardano-cli ${tmpTx4FeeCalcArgs[*]}

  minFeeArgs=(
    transaction calculate-min-fee
    --tx-body-file 0-tx0.tmp
    --tx-in-count 1
    --tx-out-count 1
    --mainnet
    --witness-count 3
    --byron-witness-count 0
    --protocol-params-file ~/tmp/protparams.json
  )
  minFee=$([[ "$(cardano-cli ${minFeeArgs[*]})" =~ ([0-9]+) ]] && echo ${BASH_REMATCH[1]})

  newBalance=$(( balance - minFee ))
  tx_out="${base_addr}+${newBalance}"

  buildArgs=(
    transaction build-raw 
    --tx-in "${tx_in}"
    --tx-out "${tx_out}"
    --ttl "${ttlValue}"
    --fee "${minFee}"
    --certificate-file "${pool_cert_file}"
    --out-file 0-tx-modify-pool-cert-pledge.raw
  )

  signArgs=(
    transaction sign 
    --tx-body-file 0-tx-modify-pool-cert-pledge.raw
    --signing-key-file payment.skey
    --signing-key-file stake.skey
    --signing-key-file cold.skey
    --mainnet
    --out-file tx.signed
  )

  # submitArgs=(
  #   transaction submit
  #   --tx-file "/home/bswan/tmp"/tx.signed
  #   --cardano-mode
  #   --testnet-magic 42
  # ) 
  # use sumbitx cmd above

  cardano-cli ${buildArgs[*]}
  echo "cardano-cli ${signArgs[*]}" > 0-cmd-modify-pool-cert-pledge.txt

  echo "--------------------------------------"
  echo "poolDeposit: NONE"
  echo ""
  echo "ttl: ${ttlValue}"
  echo "fee: ${minFee}"
  echo ""
  echo "--tx-out ${tx_out}"
  echo "${newBalance} + ${minFee} = ${balance} ($((newBalance + minFee )))"
  echo ""
  echo ./0-tx-modify-pool-cert-pledge.raw
  echo ./0-cmd-modify-pool-cert-pledge.txt
  echo "--------------------------------------"
}

delegate() {
  # if [ $1='' ]; then
  #   echo "> delegate <utxo> <utxoIX> <utxo_balance> <utxo_address> <stake.vkey> <stake.skey> <payment.skey> <delegation.cert>"
  #   return 0
  # fi

  utxo=$1
  index=$2
  balance=$3
  base_addr=$4
  tx_in=${utxo}#${index}
  stake_vk_file="$5"
  stake_sk_file="$6"
  payment_sk_file="$7"
  pool_delegcert_file="$8"

  currSlot=$(getSlotTip)
  ttlValue=$(( currSlot + 1000 ))

  tmpTx4FeeCalcArgs=(
    shelley transaction build-raw 
    --tx-in ${tx_in}
    --tx-out ${base_addr}+0
    --ttl ${ttlValue}
    --fee 0
    --certificate-file ${pool_delegcert_file}
    --out-file tx0.tmp
  )
  cardano-cli ${tmpTx4FeeCalcArgs[*]}

  minFeeArgs=(
    shelley transaction calculate-min-fee
    --tx-body-file tx0.tmp
    --tx-in-count 1
    --tx-out-count 1
    --mainnet
    --witness-count 2
    --byron-witness-count 0
    --protocol-params-file ~/tmp/protparams.json
  )
  minFee=$([[ "$(cardano-cli ${minFeeArgs[*]})" =~ ([0-9]+) ]] && echo ${BASH_REMATCH[1]})

  newBalance=$(( balance - minFee ))
  tx_out="${base_addr}+${newBalance}"

  buildArgs=(
    shelley transaction build-raw
    --tx-in ${tx_in}
    --tx-out ${tx_out}
    --ttl ${ttlValue}
    --fee ${minFee}
    --certificate-file ${pool_delegcert_file}
    --out-file tx.raw
  )
  cardano-cli ${buildArgs[*]}

  signArgs=(
    shelley transaction sign
    --tx-body-file tx.raw
    --signing-key-file ${payment_sk_file}
    --signing-key-file ${stake_sk_file}
    --mainnet
    --out-file tx.signed
  )
  echo "cardano-cli ${signArgs[*]}" > cmd.txt

  # submitArgs=(
  #   shelley transaction submit
  #   --tx-file tx.signed
  #   --cardano-mode
  #   --mainnet
  # )
  # cardano-cli ${submitArgs[*]}
  echo "--------------------------------------"
  echo ./tx.raw
  echo ./cmd.txt
  echo "--------------------------------------"

}


# getPromMetrics() {
#   curl -s "http://${prom_host}:${prom_port}/metrics" > "${TMP_FOLDER}"/prom_metrics
# }
source "/etc/profile.d/rvm.sh"
