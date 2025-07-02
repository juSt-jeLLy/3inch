import { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import { Token } from '../components/TokenModal';

export function useTokenBalance(token: Token, walletAddress: string | undefined) {
  const [balance, setBalance] = useState<string>('0.0');
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    const fetchBalance = async () => {
      if (!walletAddress || !window.ethereum) return;

      setIsLoading(true);
      try {
        const provider = new ethers.BrowserProvider(window.ethereum);
        
        // Check if we're on the correct network
        const network = await provider.getNetwork();
        const currentChainId = Number(network.chainId);
        
        // Only fetch balance if we're on the correct network for the token
        if (currentChainId === token.chainId) {
          const balance = await provider.getBalance(walletAddress);
          setBalance(ethers.formatEther(balance));
        } else {
          setBalance('0.0');
        }
      } catch (error) {
        console.error('Error fetching balance:', error);
        setBalance('0.0');
      } finally {
        setIsLoading(false);
      }
    };

    fetchBalance();

    // Set up event listeners for network and account changes
    if (window.ethereum) {
      const handleChainChanged = () => {
        fetchBalance();
      };

      const handleAccountsChanged = () => {
        fetchBalance();
      };

      window.ethereum.on('chainChanged', handleChainChanged);
      window.ethereum.on('accountsChanged', handleAccountsChanged);

      // Clean up event listeners
      return () => {
        window.ethereum.removeListener('chainChanged', handleChainChanged);
        window.ethereum.removeListener('accountsChanged', handleAccountsChanged);
      };
    }
  }, [token.chainId, walletAddress, token.id]);

  return { balance, isLoading };
} 