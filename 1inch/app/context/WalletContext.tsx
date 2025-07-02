'use client';

import { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { SUPPORTED_CHAINS } from '../config/wallets';

interface Wallet {
  address: string;
  chainId: number;
}

interface WalletContextType {
  isConnected: boolean;
  wallet: Wallet | null;
  isModalOpen: boolean;
  error: string | null;
  isLoading: boolean;
  openModal: () => void;
  closeModal: () => void;
  connectWallet: (wallet: { name: string }) => Promise<void>;
  disconnectWallet: () => void;
  switchChain: (chainId: number) => Promise<void>;
  clearError: () => void;
}

const WalletContext = createContext<WalletContextType | undefined>(undefined);

declare global {
  interface Window {
    ethereum?: any;
  }
}

export function WalletProvider({ children }: { children: ReactNode }) {
  const [wallet, setWallet] = useState<Wallet | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [isInitialized, setIsInitialized] = useState(false);

  // Initialize wallet state from localStorage and check if already connected
  useEffect(() => {
    const initializeWallet = async () => {
      if (typeof window === 'undefined' || !window.ethereum) return;

      try {
        // Check if we have a stored connection state
        const storedWallet = localStorage.getItem('walletConnection');
        if (!storedWallet) return;

        // Get current accounts
        const accounts = await window.ethereum.request({
          method: 'eth_accounts'
        });

        if (accounts.length > 0) {
          const chainId = await window.ethereum.request({
            method: 'eth_chainId'
          });

          setWallet({
            address: accounts[0],
            chainId: parseInt(chainId, 16)
          });
        } else {
          localStorage.removeItem('walletConnection');
          setWallet(null);
        }
      } catch (error) {
        console.error('Failed to initialize wallet:', error);
        localStorage.removeItem('walletConnection');
      } finally {
        setIsInitialized(true);
      }
    };

    initializeWallet();
  }, []);

  const connectWallet = async (walletType: { name: string }) => {
    if (!window.ethereum) {
      setError('Please install MetaMask!');
      return;
    }

    setIsLoading(true);
    setError(null);

    try {
      // First, check if we're already connected
      const accounts = await window.ethereum.request({
        method: 'eth_accounts'
      });

      // If we're not connected or previously disconnected, request new permissions
      if (accounts.length === 0 || !localStorage.getItem('walletConnection')) {
        // This will trigger the MetaMask popup
        await window.ethereum.request({
          method: 'wallet_requestPermissions',
          params: [{ eth_accounts: {} }]
        });

        // After permission granted, get the accounts
        const newAccounts = await window.ethereum.request({
          method: 'eth_requestAccounts'
        });

        if (newAccounts.length === 0) {
          throw new Error('No accounts found after permission granted');
        }

        accounts[0] = newAccounts[0];
      }

      const chainId = await window.ethereum.request({
        method: 'eth_chainId',
      });

      const newWallet = {
        address: accounts[0],
        chainId: parseInt(chainId, 16),
      };

      setWallet(newWallet);
      localStorage.setItem('walletConnection', 'true');
      closeModal();
    } catch (error: any) {
      console.error('Connection error:', error);
      setError(error.message || 'Failed to connect wallet');
      localStorage.removeItem('walletConnection');
    } finally {
      setIsLoading(false);
    }
  };

  const disconnectWallet = () => {
    setWallet(null);
    localStorage.removeItem('walletConnection');
  };

  const switchChain = async (chainId: number) => {
    if (!window.ethereum) {
      throw new Error('Please install MetaMask!');
    }

    if (!wallet) {
      // If wallet is not connected, try to connect first
      try {
        const accounts = await window.ethereum.request({
          method: 'eth_requestAccounts'
        });
        
        if (accounts.length === 0) {
          throw new Error('Please connect your wallet first');
        }

        // Set wallet state with the connected account
        setWallet({
          address: accounts[0],
          chainId: parseInt(await window.ethereum.request({ method: 'eth_chainId' }), 16)
        });
      } catch (error: any) {
        throw new Error('Failed to connect wallet: ' + error.message);
      }
    }

    const chain = SUPPORTED_CHAINS.find(c => c.chainId === chainId);
    if (!chain) throw new Error('Unsupported chain');

    try {
      await window.ethereum.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: `0x${chainId.toString(16)}` }],
      });
    } catch (switchError: any) {
      if (switchError.code === 4902) {
        try {
          await window.ethereum.request({
            method: 'wallet_addEthereumChain',
            params: [{
              chainId: `0x${chainId.toString(16)}`,
              chainName: chain.name,
              nativeCurrency: chain.nativeCurrency,
              rpcUrls: chain.rpcUrls,
              blockExplorerUrls: chain.blockExplorerUrls
            }],
          });
        } catch (addError) {
          console.error('Error adding chain:', addError);
          throw addError;
        }
      }
      console.error('Error switching chain:', switchError);
      throw switchError;
    }
  };

  useEffect(() => {
    if (window.ethereum && isInitialized) {
      const handleAccountsChanged = (accounts: string[]) => {
        if (accounts.length === 0) {
          setWallet(null);
          localStorage.removeItem('walletConnection');
        } else if (wallet?.address !== accounts[0]) {
          setWallet(prev => prev ? {
            ...prev,
            address: accounts[0]
          } : null);
        }
      };

      const handleChainChanged = (chainId: string) => {
        setWallet(prev => prev ? {
          ...prev,
          chainId: parseInt(chainId, 16)
        } : null);
      };

      const handleDisconnect = () => {
        setWallet(null);
        localStorage.removeItem('walletConnection');
      };

      window.ethereum.on('accountsChanged', handleAccountsChanged);
      window.ethereum.on('chainChanged', handleChainChanged);
      window.ethereum.on('disconnect', handleDisconnect);

      return () => {
        window.ethereum.removeListener('accountsChanged', handleAccountsChanged);
        window.ethereum.removeListener('chainChanged', handleChainChanged);
        window.ethereum.removeListener('disconnect', handleDisconnect);
      };
    }
  }, [wallet, isInitialized]);

  const openModal = () => setIsModalOpen(true);
  const closeModal = () => setIsModalOpen(false);
  const clearError = () => setError(null);

  return (
    <WalletContext.Provider value={{
      isConnected: !!wallet,
      wallet,
      isModalOpen,
      error,
      isLoading,
      openModal,
      closeModal,
      connectWallet,
      disconnectWallet,
      switchChain,
      clearError
    }}>
      {children}
    </WalletContext.Provider>
  );
}

export function useWallet() {
  const context = useContext(WalletContext);
  if (context === undefined) {
    throw new Error('useWallet must be used within a WalletProvider');
  }
  return context;
} 