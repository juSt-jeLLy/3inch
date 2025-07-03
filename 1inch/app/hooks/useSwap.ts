import { useState } from 'react';
import { useWallet } from '../context/WalletContext';
import { useOrderCreation } from './useOrderCreation';
import { CONTRACTS } from '../config/contracts';
import { Token } from '../components/TokenModal';
import { ethers } from 'ethers';

// Basic ERC20 ABI for approval
const ERC20_ABI = [
  'function approve(address spender, uint256 amount) public returns (bool)',
  'function allowance(address owner, address spender) public view returns (uint256)'
];

export enum SwapStatus {
  IDLE = 'IDLE',
  APPROVING = 'APPROVING',
  SIGNING = 'SIGNING',
  WAITING_FOR_LOCK = 'WAITING_FOR_LOCK',
  LOCKING = 'LOCKING',
  WAITING_FOR_COMPLETION = 'WAITING_FOR_COMPLETION',
  COMPLETED = 'COMPLETED',
  ERROR = 'ERROR'
}

interface UseSwapResult {
  swap: (fromToken: Token, toToken: Token, amount: string) => Promise<void>;
  error: string | null;
  status: SwapStatus;
  statusMessage: string;
}

export function useSwap(): UseSwapResult {
  const { wallet } = useWallet();
  const [error, setError] = useState<string | null>(null);
  const [status, setStatus] = useState<SwapStatus>(SwapStatus.IDLE);
  const [statusMessage, setStatusMessage] = useState<string>('');

  // Get the order creation hook
  const { createAndSignOrder } = useOrderCreation(
    wallet?.chainId || 0,
    CONTRACTS[wallet?.chainId as keyof typeof CONTRACTS]?.limitOrderProtocol || ''
  );

  const updateStatus = (newStatus: SwapStatus, message: string) => {
    setStatus(newStatus);
    setStatusMessage(message);
  };

  // Check and handle token approval
  const checkAndApproveToken = async (
    tokenAddress: string,
    spenderAddress: string,
    amount: string
  ) => {
    if (!wallet || !window.ethereum) throw new Error('Wallet not connected');

    const provider = new ethers.BrowserProvider(window.ethereum);
    const signer = await provider.getSigner();
    const tokenContract = new ethers.Contract(tokenAddress, ERC20_ABI, signer);

    // For native token (ETH/MON), no approval needed
    if (tokenAddress === CONTRACTS[wallet.chainId as keyof typeof CONTRACTS]?.nativeToken) {
      return;
    }

    // Check current allowance
    const currentAllowance = await tokenContract.allowance(wallet.address, spenderAddress);
    const requiredAmount = ethers.parseUnits(amount, 18);

    // If current allowance is less than required amount, request approval
    if (currentAllowance < requiredAmount) {
      updateStatus(SwapStatus.APPROVING, 'Approving token spending...');
      try {
        const tx = await tokenContract.approve(spenderAddress, requiredAmount);
        await tx.wait(); // Wait for transaction to be mined
      } catch (err) {
        updateStatus(SwapStatus.ERROR, 'Failed to approve token spending');
        throw err;
      }
    }
  };

  const waitForLockConfirmation = async (orderHash: string) => {
    // This would be replaced with your actual backend API call
    updateStatus(SwapStatus.WAITING_FOR_LOCK, 'Waiting for escrow lock transaction...');
    
    // Simulated backend response - in reality, this would be an API call
    // that waits for the resolver to prepare the escrow transaction
    await new Promise(resolve => setTimeout(resolve, 2000));

    updateStatus(SwapStatus.LOCKING, 'Confirming escrow lock...');
    // Here you would:
    // 1. Get the escrow transaction from your backend
    // 2. Present it to the user for confirmation
    // 3. Wait for the transaction to be mined
    
    updateStatus(SwapStatus.WAITING_FOR_COMPLETION, 'Tokens locked in escrow. Waiting for cross-chain completion...');
  };

  const swap = async (fromToken: Token, toToken: Token, amount: string) => {
    try {
      updateStatus(SwapStatus.IDLE, '');
      setError(null);

      if (!wallet) {
        throw new Error('Wallet not connected');
      }

      const contracts = CONTRACTS[wallet.chainId as keyof typeof CONTRACTS];
      if (!contracts) {
        throw new Error('Unsupported chain');
      }

      // Check and handle token approval first
      await checkAndApproveToken(
        contracts.nativeToken,
        contracts.limitOrderProtocol,
        amount
      );

      // Create and sign the order
      updateStatus(SwapStatus.SIGNING, 'Please sign the order...');
      const { order, signature } = await createAndSignOrder(
        contracts.nativeToken, // makerAsset (native token)
        contracts.erc20True,   // takerAsset (ERC20True token)
        amount,
        amount // For now, using 1:1 ratio. In reality, you'd calculate this based on price
      );

      // Wait for escrow lock confirmation
      await waitForLockConfirmation(order.orderHash);

      updateStatus(SwapStatus.COMPLETED, 'Swap completed successfully!');

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to create swap';
      setError(errorMessage);
      updateStatus(SwapStatus.ERROR, errorMessage);
      throw err;
    }
  };

  return {
    swap,
    error,
    status,
    statusMessage
  };
} 