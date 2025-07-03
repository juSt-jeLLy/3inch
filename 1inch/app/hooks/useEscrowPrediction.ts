import { useState } from 'react';
import { ethers } from 'ethers';
import { EscrowFactoryABI } from '../contracts/abis';
import { NETWORKS } from '../contracts/addresses';

export function useEscrowPrediction() {
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const predictEscrowSrc = async (
    fromChainId: number,
    orderHash: string
  ) => {
    setIsLoading(true);
    setError(null);

    try {
      if (!window.ethereum) {
        throw new Error('No ethereum provider found');
      }

      const provider = new ethers.BrowserProvider(window.ethereum);
      const signer = await provider.getSigner();

      // Get the network configuration
      const network = fromChainId === NETWORKS.sepolia.chainId ? NETWORKS.sepolia : NETWORKS.monad;
      
      // Create contract instance
      const escrowFactory = new ethers.Contract(
        network.contracts.escrowFactory,
        EscrowFactoryABI.abi,
        signer
      );

      // Predict the EscrowSrc address
      const escrowSrcAddress = await escrowFactory.addressOfEscrowSrc(orderHash);
      
      return escrowSrcAddress;

    } catch (err: any) {
      setError(err.message || 'Failed to predict escrow address');
      throw err;
    } finally {
      setIsLoading(false);
    }
  };

  return {
    predictEscrowSrc,
    isLoading,
    error
  };
} 