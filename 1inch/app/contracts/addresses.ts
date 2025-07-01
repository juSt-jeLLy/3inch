export const SEPOLIA_CONTRACTS = {
  escrowFactory: '0x239d9eb2418e5B4333a7976c3c3fE936DC6E6613',
  feeBank: '0x0043f7F2EC70Ee1caD72bF0fDf15Bfc9f1F29B18',
  escrowSrc: '0xDD3C59FfA6d09F5665BA103613Dd2A664DE1145d',
  escrowDst: '0xADe5C565424aB0eA210d6989134Fe65bb4BD627D'
}

export const MONAD_CONTRACTS = {
  escrowFactory: '0x12aB0D1C6a7D21c3C3c47411846EaEf0DD30E1A7',
  feeBank: '0x799bD51d91eF62E0421072D6Fb6edf2ffb750D4a',
  escrowSrc: '0xb722FBD0D1F083324a914da62F181e5d8319F45C',
  escrowDst: '0x5e5E1871fE1CF495670b1D80b54F04D269d2A186',
  mockDai: '0x5aAdFB43eF8dAF45DD80F4676345b7676f1D70e3'
}

export const NETWORKS = {
  sepolia: {
    chainId: 11155111,
    name: 'Sepolia',
    contracts: SEPOLIA_CONTRACTS,
    rpcUrl: process.env.NEXT_PUBLIC_SEPOLIA_RPC_URL
  },
  monad: {
    chainId: 10143,
    name: 'Monad Testnet',
    contracts: MONAD_CONTRACTS,
    rpcUrl: process.env.NEXT_PUBLIC_MONAD_RPC_URL
  }
} 