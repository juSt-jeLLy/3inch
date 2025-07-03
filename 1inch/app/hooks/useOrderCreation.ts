import { useState } from 'react';
import { BrowserProvider, JsonRpcSigner } from 'ethers';
import { useWallet } from '../context/WalletContext';
import { createOrder, signOrder, Order } from '../utils/orderUtils';

interface UseOrderCreationResult {
  createAndSignOrder: (
    makerAsset: string,
    takerAsset: string,
    makingAmount: string,
    takingAmount: string
  ) => Promise<{
    order: Order;
    signature: {
      r: string;
      vs: string;
    };
  }>;
  error: string | null;
  isLoading: boolean;
}

export function useOrderCreation(
  chainId: number,
  limitOrderProtocolAddress: string
): UseOrderCreationResult {
  const { wallet } = useWallet();
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const createAndSignOrder = async (
    makerAsset: string,
    takerAsset: string,
    makingAmount: string,
    takingAmount: string
  ) => {
    try {
      setIsLoading(true);
      setError(null);

      if (!wallet || !window.ethereum) {
        throw new Error('Wallet not connected');
      }

      const provider = new BrowserProvider(window.ethereum);
      const signer = await provider.getSigner(wallet.address);

      // Create the order
      const order = await createOrder(
        wallet.address,
        makerAsset,
        takerAsset,
        makingAmount,
        takingAmount,
        chainId,
        limitOrderProtocolAddress
      );

      // Sign the order
      const signature = await signOrder(
        order,
        signer,
        chainId,
        limitOrderProtocolAddress
      );

      return { order, signature };
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to create and sign order';
      setError(errorMessage);
      throw err;
    } finally {
      setIsLoading(false);
    }
  };

  return {
    createAndSignOrder,
    error,
    isLoading
  };
} 