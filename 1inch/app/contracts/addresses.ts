export const SEPOLIA_CONTRACTS = {
  escrowFactory: '0x239d9eb2418e5B4333a7976c3c3fE936DC6E6613',
  feeBank: '0x0043f7F2EC70Ee1caD72bF0fDf15Bfc9f1F29B18',
  escrowSrc: '0xDD3C59FfA6d09F5665BA103613Dd2A664DE1145d',
  escrowDst: '0xADe5C565424aB0eA210d6989134Fe65bb4BD627D',
  limitOrderProtocol: '0x7089d6f042bFD6B06a9d1Df08Dd4005c29682799',
  accessToken: '0xACCe550000159e70908C0499a1119D04e7039C28',
  feeToken: '0x8267cF9254734C6Eb452a7bb9AAF97B392258b21'  // DAI
}

export const MONAD_CONTRACTS = {
  escrowFactory: '0x919F799B949137e2b6AcE1fC5098b72EaDf7a453',
  feeBank: '0x71C1bF6126BB086d7aE3bB558cc69f64Dadb58e7',
  escrowSrc: '0xc099c7B20530E2dba84fcc227387EaDdD05C40ee',
  escrowDst: '0x5Ea309821656B59B65cc979EF4b34e5e17F1dd33',
  limitOrderProtocol: '0x27a635Ea36C79F433fD74147d42B7E58fc6Df834',
  accessToken: '0xD8107179Bb4233c382F6422A46c1A9338F039384',
  feeToken: '0x760AfE86e5de5fa0Ee542fc7B7B713e1c5425701'  // USDC
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