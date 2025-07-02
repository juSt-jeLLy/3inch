'use client';

import { useState } from 'react';
import { useWallet } from '../context/WalletContext';
import { SUPPORTED_CHAINS } from '../config/wallets';

export default function NetworkSelector() {
  const { wallet, switchChain } = useWallet();
  const [isOpen, setIsOpen] = useState(false);

  const currentChain = SUPPORTED_CHAINS.find(
    chain => chain.chainId === wallet?.chainId
  );

  const handleNetworkSwitch = async (chainId: number) => {
    try {
      await switchChain(chainId);
      setIsOpen(false);
    } catch (error) {
      console.error('Failed to switch network:', error);
    }
  };

  return (
    <div className="relative">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex items-center px-4 py-2 rounded-lg bg-black/50 border border-[#ffd700]/10 hover:border-[#ffd700]/30 transition-all duration-300"
      >
        <span className="mr-2 text-[#ffd700]">
          {currentChain?.name || 'Unknown Network'}
        </span>
        <svg
          className={`w-4 h-4 transition-transform text-[#ffd700] ${isOpen ? 'rotate-180' : ''}`}
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M19 9l-7 7-7-7"
          />
        </svg>
      </button>

      {isOpen && (
        <div className="absolute right-0 mt-2 w-48 rounded-xl shadow-lg bg-black/40 backdrop-blur-xl border border-[#ffd700]/10">
          <div className="py-1">
            {SUPPORTED_CHAINS.map((chain) => (
              <button
                key={chain.chainId}
                onClick={() => handleNetworkSwitch(chain.chainId)}
                className={`block w-full text-left px-4 py-2 text-sm transition-all duration-300 ${
                  chain.chainId === wallet?.chainId
                    ? 'bg-[#ffd700]/10 text-[#ffd700]'
                    : 'text-gray-200 hover:bg-[#ffd700]/5 hover:text-[#ffd700]'
                }`}
              >
                {chain.name}
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );
} 