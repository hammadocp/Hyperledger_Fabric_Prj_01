#!/bin/bash
# Copyright IBM Corp All Rights Reserved
# SPDX-License-Identifier: Apache-2.0


ROOTDIR=$(cd "$(dirname "$0")" && pwd)
export PATH=${ROOTDIR}/bin:${PWD}/bin:$PATH
export FABRIC_CFG_PATH=${PWD}/config

# use this as the default docker-compose yaml definition
COMPOSE_FILE_BASE=docker-compose-Prj01-net.yaml


function createCryptoMaterials(){

  echo "Generating Crypto Material"

  cryptogen generate --config=./config/crypto-config-orgA.yaml --output="organizations"
  cryptogen generate --config=./config/crypto-config-orgB.yaml --output="organizations"
  cryptogen generate --config=./config/crypto-config-orderer.yaml --output="organizations"
}



function createNetworkContainers() {
  echo "Creating Network Containers"
  docker-compose -f $COMPOSE_FILE_BASE up -d
}


function networkDown() {
# Remove Crypto Material
deleteCryptoMaterials
deleteNetworkConatainers
}

function deleteNetworkConatainers() {
  echo "Removing Network Containers"
  docker-compose -f $COMPOSE_FILE_BASE down --volumes --remove-orphans
 }

 # Function to Removing Crypto Material
function deleteCryptoMaterials() {
  echo "Removing Crypto Materials"
  rm -rf organizations
  rm -rf channel-artifacts
}


: ${CHANNEL_NAME:="mychannel"}

if [ ! -d "channel-artifacts" ]; then
  echo "Creating channel-artifacts Directory"
	mkdir channel-artifacts
fi
 
# Set environment variables for the peer org
setGlobals() {
  local USING_ORG=""
  if [ -z "$OVERRIDE_ORG" ]; then
    USING_ORG=$1
  else
    USING_ORG="${OVERRIDE_ORG}"
  fi

}

createChannelGenesisBlock(){
  setGlobals $ORG
	which configtxgen
	configtxgen -profile ChannelUsingRaft -outputBlock ./channel-artifacts/${CHANNEL_NAME}.block -channelID $CHANNEL_NAME

  echo "createChannelGenesisBlock Created Successfully"

}


function createChannel(){

  export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem
  export ORDERER_ADMIN_TLS_SIGN_CERT=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt 
  export ORDERER_ADMIN_TLS_PRIVATE_KEY=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key 
  osnadmin channel join --channelID ${CHANNEL_NAME} --config-block ./channel-artifacts/${CHANNEL_NAME}.block -o localhost:7053 --ca-file "$ORDERER_CA" --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY" >> log.txt 2>&1

  echo "Channel Created Successfully"
}

function joinChannel(){

  export CORE_PEER_TLS_ENABLED=true
  export CORE_PEER_LOCALMSPID=OrgA_MSP
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/orgA.example.com/peers/peer0.orgA.example.com/tls/ca.crt
  export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/orgA.example.com/users/Admin@orgA.example.com/msp
  export CORE_PEER_ADDRESS=localhost:7051

 BLOCKFILE="./channel-artifacts/${CHANNEL_NAME}.block"
 peer channel join -b $BLOCKFILE >&log.txt

  export CORE_PEER_TLS_ENABLED=true
  export CORE_PEER_LOCALMSPID=OrgB_MSP
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/orgB.example.com/peers/peer0.orgB.example.com/tls/ca.crt
  export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/orgB.example.com/users/Admin@orgB.example.com/msp
  export CORE_PEER_ADDRESS=localhost:9051

  BLOCKFILE="./channel-artifacts/${CHANNEL_NAME}.block"
  peer channel join -b $BLOCKFILE >&log2.txt

  echo "OrgA OrgB proposal submitted successfully!"
}

fetchChannelConfig() {

: ${CHANNEL_NAME:="mychannel"}
  export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem
  peer channel fetch config ${TEST_NETWORK_HOME}/channel-artifacts/config_block.pb -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c "CHANNEL_NAME" --tls --cafile "$ORDERER_CA"

}








# --- Main Funcation --- Start ---
#====================================

function main() {

  ARGS=$1
    #echo "Arguments = $ARGS"

if [ $ARGS == "down" ]; then

  echo "Network Getting Down";

  networkDown
  
elif [ $ARGS == "up" ]; then

  echo "Network Getting UP"

# Calling  Custom Funcations

  createCryptoMaterials
  createNetworkContainers
  createChannelGenesisBlock
  createChannel
  joinChannel
  fetchChannelConfig
  


elif [ $ARGS == " " ]; then

  echo "Invalid Input"
fi

}

#---- Main Funcation --- End ----

#Calling Main Function 

#set -x
main $1
#set +x
