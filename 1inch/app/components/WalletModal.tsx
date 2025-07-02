'use client';

import { useWallet } from '../context/WalletContext';
import { SUPPORTED_WALLETS, SUPPORTED_CHAINS } from '../config/wallets';
import Image from 'next/image';
import { XMarkIcon } from '@heroicons/react/24/outline';

export default function WalletModal() {
  const { 
    isModalOpen, 
    closeModal, 
    connectWallet, 
    error, 
    isLoading,
    wallet,
    switchChain
  } = useWallet();

  if (!isModalOpen) return null;

  const handleConnect = async (wallet: { name: string }) => {
    try {
      // First connect the wallet
      await connectWallet(wallet);
      
      // After successful connection, check and switch chain if needed
      if (window.ethereum) {
        try {
          const chainId = await window.ethereum.request({ method: 'eth_chainId' });
          const currentChainId = parseInt(chainId, 16);
          
          // Check if current chain is supported
          const isSupported = SUPPORTED_CHAINS.some(chain => chain.chainId === currentChainId);
          
          if (!isSupported) {
            // Wait a bit before switching chain to ensure wallet is properly connected
            setTimeout(async () => {
              try {
                // Default to Sepolia if current chain is not supported
                await switchChain(SUPPORTED_CHAINS[0].chainId);
              } catch (switchError) {
                console.error('Chain switch error:', switchError);
              }
            }, 500);
          }
        } catch (chainError) {
          console.error('Chain check error:', chainError);
        }
      }
    } catch (err) {
      console.error('Connection error:', err);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center" onClick={closeModal}>
      <div className="fixed inset-0 bg-black/60 backdrop-blur-sm" />
      <div 
        className="relative w-[400px] rounded-2xl bg-black/80 border border-[#ffd700]/20 p-6 shadow-xl"
        onClick={e => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-2xl font-bold text-[#ffd700]">
            Connect Wallet
          </h2>
          <button 
            onClick={closeModal}
            className="p-1 rounded-lg hover:bg-[#ffd700]/10 transition-colors"
          >
            <XMarkIcon className="w-6 h-6 text-[#ffd700]" />
          </button>
        </div>

        {/* Network Warning */}
        <div className="mb-6 text-sm text-[#ffd700]/80">
          Please make sure you are connected to either Sepolia or Monad Testnet
        </div>

        {/* Error Message */}
        {error && (
          <div className="mb-4 p-4 bg-red-900/50 text-red-400 rounded-lg border border-red-500/20 text-sm">
            {error}
          </div>
        )}

        {/* Wallet Options */}
        <div className="space-y-3">
          {SUPPORTED_WALLETS.map((wallet) => (
            <button
              key={wallet.name}
              onClick={() => handleConnect(wallet)}
              disabled={isLoading}
              className="w-full flex items-center justify-between p-4 rounded-xl border border-[#ffd700]/10 hover:border-[#ffd700]/30 transition-all duration-300 hover:shadow-lg hover:shadow-[#ffd700]/10 bg-black/50 text-[#ffd700] disabled:opacity-50 disabled:cursor-not-allowed group"
            >
              <div className="flex items-center gap-3">
                <Image
                  src={wallet.icon}
                  alt={wallet.name}
                  width={32}
                  height={32}
                  className="group-hover:scale-110 transition-transform duration-300"
                />
                <span className="text-lg font-medium">{wallet.name}</span>
              </div>
              {isLoading && (
                <div className="w-5 h-5 border-2 border-[#ffd700]/30 border-t-[#ffd700] rounded-full animate-spin" />
              )}
            </button>
          ))}
        </div>

        {/* Network Icons */}
        <div className="mt-6 flex items-center justify-center gap-4">
          {SUPPORTED_CHAINS.map((chain) => (
            <div key={chain.chainId} className="text-center">
              <Image
                src={chain.iconUrl}
                alt={chain.name}
                width={24}
                height={24}
                className="mx-auto mb-2"
              />
              <span className="text-xs text-gray-400">{chain.name}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
} 