var HDWalletProvider = require("truffle-hdwallet-provider");
function getWallet(){
  return require('fs').readFileSync("./secrets.json", "utf8").trim();
}

module.exports = {
  networks: {
    rinkeby:{
      network_id:4,
      provider: new HDWalletProvider(getWallet(), "password", 'https://rinkeby.infura.io/'),
      gas: 4700000,
      gasPrice: 10000000000
    },
    development: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*" // Match any network id
    },
    chronobank: {
      network_id: 456719,
      provider: new HDWalletProvider(getWallet(),'password','https://private-full-geth-node.chronobank.io'),
      port: 8545,
      gas: 4700000
    },
    lx: {
      network_id: 456719,
      provider: new HDWalletProvider(getWallet(),'password','https://private-full-geth-node.chronobank.io'), // TODO
      port: 8545,
      gas: 4700000
    }
  }
};
