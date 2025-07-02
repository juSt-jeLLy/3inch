export const SUPPORTED_CHAINS = [
  {
    chainId: 11155111,
    name: 'Sepolia',
    nativeCurrency: {
      name: 'Sepolia Ether',
      symbol: 'ETH',
      decimals: 18,
    },
    rpcUrls: ['https://sepolia.infura.io/v3/'],
    blockExplorerUrls: ['https://sepolia.etherscan.io'],
    iconUrl: '/icons/eth.svg'
  },
  {
    chainId: 10143,
    name: 'Monad Testnet',
    nativeCurrency: {
      name: 'Monad',
      symbol: 'MON',
      decimals: 18,
    },
    rpcUrls: ['https://testnet-rpc.monad.xyz'],
    blockExplorerUrls: ['https://testnet-explorer.monad.xyz'],
    iconUrl: '/icons/monad.svg'
  },
];

export const SUPPORTED_WALLETS = [
  {
    name: 'MetaMask',
    icon: '/icons/metamask.svg',
  },
]; 