import { SEPOLIA_CONTRACTS, MONAD_CONTRACTS } from '../contracts/addresses';

export const CONTRACTS = {
  // Sepolia Testnet (Chain ID: 11155111)
  11155111: {
    limitOrderProtocol: SEPOLIA_CONTRACTS.limitOrderProtocol,
    nativeToken: '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE', // ETH address
    erc20True: SEPOLIA_CONTRACTS.accessToken  // Using accessToken as ERC20True
  },
  // Monad Testnet (Chain ID: 10143)
  10143: {
    limitOrderProtocol: MONAD_CONTRACTS.limitOrderProtocol,
    nativeToken: '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE', // MON address
    erc20True: MONAD_CONTRACTS.accessToken  // Using accessToken as ERC20True
  }
}; 