#!/bin/bash

INDEXER="null"
SNAPSHOT_INTERVAL=0
PRUNING_MODE=custom
PRUNING_INTERVAL=10
PRUNING_KEEP_RECENT=100
MINIMUM_GAS_PRICES=0.0025ulava
EXTERNAL_ADDRESS=$(wget -qO- eth0.me)
SEEDS="3a445bfdbe2d0c8ee82461633aa3af31bc2b4dc0@prod-pnet-seed-node.lavanet.xyz:26656,e593c7a9ca61f5616119d6beb5bd8ef5dd28d62d@prod-pnet-seed-node2.lavanet.xyz:26656"
PEERS=""

init_node() {
    # Set moniker and chain-id for Lava (Moniker can be anything, chain-id must be an integer)
    lavad init $MONIKER --chain-id $CHAINID --home $CONFIG_PATH

    # Set keyring-backend and chain-id configuration
    lavad config chain-id $CHAINID --home $CONFIG_PATH
    lavad config keyring-backend $KEYRING --home $CONFIG_PATH

    # if $KEY exists it should be deleted
    echo -e "\n\e[32m### Wallet info ###\e[0m"

    lavad keys add $KEY --keyring-backend $KEYRING --home $CONFIG_PATH

    # Download genesis file
    wget -O $CONFIG_PATH/config/genesis.json https://raw.githubusercontent.com/K433QLtr6RA9ExEq/GHFkqmTzpdNLDd6T/main/testnet-1/genesis_json/genesis.json

    # Set seeds/bpeers/peers
    sed -i -e "s/^external_address *=.*/external_address = \"$EXTERNAL_ADDRESS:26656\"/" $CONFIG_PATH/config/config.toml
    sed -i -e "s/^filter_peers *=.*/filter_peers = \"true\"/" $CONFIG_PATH/config/config.toml
    sed -i -e "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $CONFIG_PATH/config/config.toml
    sed -i -e "s/^seeds *=.*/seeds = \"$SEEDS\"/" $CONFIG_PATH/config/config.toml

    # Config pruning and snapshots
    sed -i -e "s/^indexer *=.*/indexer = \"$INDEXER\"/" $CONFIG_PATH/config/config.toml
    sed -i -e "s/^snapshot-interval *=.*/snapshot-interval = $SNAPSHOT_INTERVAL/" $CONFIG_PATH/config/app.toml
    sed -i -e "s/^pruning *=.*/pruning = \"$PRUNING_MODE\"/" $CONFIG_PATH/config/app.toml
    sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"$PRUNING_KEEP_RECENT\"/" $CONFIG_PATH/config/app.toml
    sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"$PRUNING_INTERVAL\"/" $CONFIG_PATH/config/app.toml

    # Set min price for GAZ in app.toml
    sed -i -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"$MINIMUM_GAS_PRICES\"/" $CONFIG_PATH/config/app.toml

    sed -i -e "s/^create_empty_blocks *=.*/create_empty_blocks = true/" $CONFIG_PATH/config/config.toml
    sed -i -e "s/^create_empty_blocks_interval *=.*/create_empty_blocks_interval = \"60s\"/" $CONFIG_PATH/config/config.toml
    sed -i -e "s/^timeout_propose *=.*/timeout_propose = \"60s\"/" $CONFIG_PATH/config/config.toml
    sed -i -e "s/^timeout_commit *=.*/timeout_commit = \"60s\"/" $CONFIG_PATH/config/config.toml
    sed -i -e "s/^timeout_broadcast_tx_commit *=.*/timeout_broadcast_tx_commit = \"601s\"/" $CONFIG_PATH/config/config.toml

    # Run this to ensure everything worked and that the genesis file is setup correctly
    lavad validate-genesis --home $CONFIG_PATH
}

create_endpoins_conf() {
  cat > "$CONFIG_PATH/config/rpcprovider.yml" <<_EOF_
endpoints:
  - api-interface: tendermintrpc
    chain-id: LAV1
    network-address: 0.0.0.0:2221
    node-urls:
      - url: ws://lava-node:26657/websocket
      - url: http://lava-node:26657
  - api-interface: grpc
    chain-id: LAV1
    network-address: 0.0.0.0:2221
    node-urls:
      - url: lava-node:9090
  - api-interface: rest
    chain-id: LAV1
    network-address: 0.0.0.0:2221
    node-urls:
      - url: http://lava-node:1317
_EOF_
}

start_node() {
  case ${NODETYPE,,} in
    validator)
      echo "### Run Validator Node ###"
      lavad start --home $CONFIG_PATH --pruning=nothing --log_level $LOGLEVEL
      ;;
    provider)
      echo "### Run RPC Node ###"
      [[ ! -f "$CONFIG_PATH/config/rpcprovider.yml" ]] && create_endpoins_conf
      lavad rpcprovider --home $CONFIG_PATH --geolocation $GEOLOCATION --from $KEY --log_level $LOGLEVEL --metrics-listen-address ":23001"
      ;;
    *)
    echo "The NODETYPE variable must be set and have a value: validator or provider"
    ;;
  esac
}

set_variable() {
  source ~/.bashrc
  if [[ ! $ACC_ADDRESS ]]
  then
    echo 'export ACC_ADDRESS='$(lavad keys show $KEY -a) >> $HOME/.bashrc
  fi
  if [[ ! $VAL_ADDRESS ]]
  then
    echo 'export VAL_ADDRESS='$(lavad keys show $KEY --bech val -a) >> $HOME/.bashrc
  fi
}

if [[ $LOGLEVEL && $LOGLEVEL == "debug" ]]
then
  set -x
fi

if [[ ! -d "$CONFIG_PATH" ]] || [[ ! -d "$CONFIG_PATH/config" || $(ls -la $CONFIG_PATH/config | grep -cie .*key.json) -eq 0 ]]
then
  echo -e "\n\e[32m### Initialization node ###\e[0m\n"
  init_node
fi

echo -e "\n\e[32m### Run node ###\e[0m\n"
set_variable
start_node
