'use client';

import Image from "next/image";
import { useState, useEffect } from "react";
import { ArrowsUpDownIcon, ChevronDownIcon } from "@heroicons/react/24/outline";
import Navbar from "./components/Navbar";
import { useWallet } from "./context/WalletContext";

import TokenModal, { Token } from "./components/TokenModal";
import { useTokenBalance } from "./hooks/useTokenBalance";
import { useSwap, SwapStatus } from './hooks/useSwap';

const tokens: Token[] = [
  { 
    id: 'eth', 
    name: 'ETH Sepolia', 
    fullName: 'Ethereum', 
    icon: '/icons/eth.svg', 
    network: 'SEPOLIA NETWORK',
    chainId: 11155111
  },
  { 
    id: 'monad', 
    name: 'MON', 
    fullName: 'Monad', 
    icon: '/icons/monad.svg', 
    network: 'MONAD NETWORK',
    chainId: 10143
  }
];

// Helper function to format numbers
const formatNumber = (num: string | number) => {
  const value = typeof num === 'string' ? parseFloat(num) : num;
  if (isNaN(value)) return '0.0000';
  
  // If value is zero, return with 4 decimals
  if (value === 0) return '0.0000';
  
  // Format the number with exactly 4 decimal places
  return value.toLocaleString(undefined, {
    minimumFractionDigits: 4,
    maximumFractionDigits: 4
  });
};

export default function Home() {
  const [fromToken, setFromToken] = useState(tokens[0]);
  const [toToken, setToToken] = useState(tokens[1]);
  const [amount, setAmount] = useState('');
  const [chainWarning, setChainWarning] = useState<string | null>(null);
  const { isConnected, wallet, switchChain } = useWallet();

  // Token selection modal states
  const [isFromModalOpen, setIsFromModalOpen] = useState(false);
  const [isToModalOpen, setIsToModalOpen] = useState(false);

  // Get token balances
  const { balance: fromBalance, isLoading: isFromBalanceLoading } = useTokenBalance(fromToken, wallet?.address);

  const { swap, error: swapError, status: swapStatus, statusMessage } = useSwap();

  // Check if the current chain matches the selected token's chain
  useEffect(() => {
    if (isConnected && wallet) {
      if (wallet.chainId !== fromToken.chainId) {
        setChainWarning(`Please switch to ${fromToken.network} to proceed with the swap`);
      } else {
        setChainWarning(null);
      }
    }
  }, [isConnected, wallet?.chainId, fromToken]);

  // Token selection handlers
  const handleFromTokenSelect = async (token: Token) => {
    // If selected token is the same as toToken, swap them
    if (token.id === toToken.id) {
      setToToken(fromToken);
    }
    setFromToken(token);
    
    // Automatically switch network if needed
    if (wallet?.chainId !== token.chainId) {
      try {
        await switchChain(token.chainId);
      } catch (error: any) {
        setChainWarning(`Failed to switch to ${token.network}: ${error.message}`);
      }
    }
  };

  const handleToTokenSelect = (token: Token) => {
    // If selected token is the same as fromToken, swap them
    if (token.id === fromToken.id) {
      setFromToken(toToken);
    }
    setToToken(token);
  };

  // Handle token swap direction
  const handleSwapTokens = async () => {
    const newFromToken = toToken;
    const newToToken = fromToken;
    
    setFromToken(newFromToken);
    setToToken(newToToken);
    setAmount('');

    // Automatically switch network if needed
    if (wallet?.chainId !== newFromToken.chainId) {
      try {
        await switchChain(newFromToken.chainId);
      } catch (error: any) {
        setChainWarning(`Failed to switch to ${newFromToken.network}: ${error.message}`);
      }
    }
  };

  // Calculate estimated output
  const calculateOutput = () => {
    if (!amount) return '0.00000';
    return formatNumber(amount);
  };

  const handleSwapClick = async () => {
    if (!isConnected || chainWarning || !amount || parseFloat(amount) <= 0) {
      return;
    }

    try {
      await swap(fromToken, toToken, amount);
    } catch (err) {
      console.error('Swap failed:', err);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-[#1a1a1a] via-[#242424] to-[#1a1a1a] text-white font-mono">
      <Navbar />

      <div className="py-12 px-4 sm:px-6 lg:px-8">
        <div className="max-w-3xl mx-auto">
          {/* Header */}
          <div className="text-center mb-12 animate-fade-in">
            <h1 className="text-5xl font-bold mb-4 bg-gradient-to-r from-[#ffd700] via-[#ffed4a] to-[#ffd700] text-transparent bg-clip-text">
              SWAP TOKENS
            </h1>
            <p className="text-gray-400 text-lg">
              Fast, Secure, and Direct to Your Wallet
            </p>
          </div>

          {/* Chain Warning */}
          {chainWarning && (
            <div className="mb-6 p-4 bg-yellow-900/50 border border-yellow-600/50 rounded-xl text-yellow-500 flex justify-between items-center">
              <span>{chainWarning}</span>
              <button
                onClick={() => switchChain(fromToken.chainId)}
                className="px-4 py-2 bg-yellow-600/20 hover:bg-yellow-600/30 rounded-lg transition-colors duration-300"
              >
                Switch Network
              </button>
            </div>
          )}

          {/* Main Card */}
          <div className="relative bg-black/40 backdrop-blur-xl rounded-2xl p-8 border border-[#ffd700]/10 shadow-xl hover:shadow-2xl hover:shadow-[#ffd700]/10 transition-all duration-500">
            <div className="absolute inset-0 rounded-2xl bg-gradient-to-br from-[#ffd700]/5 via-transparent to-[#ffd700]/5 opacity-50"></div>
            


            {/* Exchange Cards */}
            <div className="relative space-y-3">
              {/* From Token */}
              <div className="bg-black/50 rounded-xl p-6 border border-[#ffd700]/10">
                <div className="flex justify-between items-center mb-4">
                  <span className="text-gray-400">YOU SEND</span>
                  <span className="text-gray-400">
                    Balance: {isFromBalanceLoading ? '...' : formatNumber(fromBalance)} {fromToken.name}
                  </span>
                </div>
                <div className="flex gap-4 items-center">
                  <button 
                    onClick={() => setIsFromModalOpen(true)}
                    className="flex items-center gap-3 px-6 py-3 bg-black/30 rounded-xl hover:bg-black/40 transition-colors duration-200 min-w-[160px]"
                  >
                    <div className="relative">
                      <div className="absolute inset-0 bg-[#ffd700]/20 rounded-full blur-md"></div>
                      <Image 
                        src={fromToken.icon} 
                        alt={fromToken.name} 
                        width={32} 
                        height={32}
                        className="relative"
                      />
                    </div>
                    <span className="font-bold text-[#ffd700] text-lg">{fromToken.name}</span>
                    <ChevronDownIcon className="h-5 w-5 text-[#ffd700] ml-auto" />
                  </button>
                  <div className="flex-grow">
                    <input
                      type="number"
                      value={amount}
                      onChange={(e) => {
                        const value = e.target.value;
                        // Don't allow negative numbers
                        if (value.startsWith('-')) return;
                        // Don't allow more than max balance
                        if (parseFloat(value) > parseFloat(fromBalance)) return;
                        setAmount(value);
                      }}
                      min="0"
                      max={fromBalance}
                      step="any"
                      placeholder="0.0000"
                      className="w-full bg-transparent text-2xl font-bold text-white placeholder-gray-600 focus:outline-none text-right [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
                    />
                  </div>
                  <button
                    onClick={() => setAmount(fromBalance)}
                    className="px-4 py-2 text-sm bg-[#ffd700]/10 hover:bg-[#ffd700]/20 text-[#ffd700] rounded-lg transition-colors duration-200"
                  >
                    MAX
                  </button>
                </div>
              </div>

              {/* Swap Arrow */}
              <div className="flex justify-center -my-3 relative z-10">
                <button 
                  onClick={handleSwapTokens}
                  className="relative bg-black/50 rounded-full p-3 border border-[#ffd700]/20 hover:border-[#ffd700]/40 transition-all duration-300 hover:scale-110 cursor-pointer group"
                >
                  <div className="absolute inset-0 bg-[#ffd700]/20 rounded-full blur-md opacity-0 group-hover:opacity-100 transition-opacity duration-300"></div>
                  <ArrowsUpDownIcon className="h-6 w-6 text-[#ffd700] relative" />
                </button>
              </div>

              {/* To Token */}
              <div className="bg-black/50 rounded-xl p-6 border border-[#ffd700]/10">
                <div className="flex justify-between items-center mb-4">
                  <span className="text-gray-400">YOU RECEIVE</span>
                </div>
                <div className="flex gap-4 items-center">
                  <button
                    onClick={() => setIsToModalOpen(true)}
                    className="flex items-center gap-3 px-6 py-3 bg-black/30 rounded-xl hover:bg-black/40 transition-colors duration-200 min-w-[160px]"
                  >
                    <div className="relative">
                      <div className="absolute inset-0 bg-[#ffd700]/20 rounded-full blur-md"></div>
                      <Image 
                        src={toToken.icon} 
                        alt={toToken.name} 
                        width={32} 
                        height={32}
                        className="relative"
                      />
                    </div>
                    <span className="font-bold text-[#ffd700] text-lg">{toToken.name}</span>
                    <ChevronDownIcon className="h-5 w-5 text-[#ffd700] ml-auto" />
                  </button>
                  <div className="flex-grow">
                    <div className="text-2xl font-bold text-white text-right">
                      {calculateOutput()}
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Swap Error */}
            {swapError && (
              <div className="mb-6 p-4 bg-red-900/50 border border-red-600/50 rounded-xl text-red-500">
                {swapError}
              </div>
            )}

            {/* Swap Button */}
            <button
              onClick={handleSwapClick}
              disabled={!isConnected || !!chainWarning || !amount || parseFloat(amount) <= 0 || swapStatus !== SwapStatus.IDLE}
              className={`relative w-full py-4 rounded-xl text-center font-bold text-lg transition-all duration-300 mt-8 ${
                isConnected && !chainWarning && amount && parseFloat(amount) > 0 && swapStatus === SwapStatus.IDLE
                  ? 'bg-gradient-to-r from-[#ffd700] via-[#ffed4a] to-[#ffd700] text-black hover:shadow-lg hover:shadow-[#ffd700]/20 hover:scale-[1.02]'
                  : 'bg-gray-600/50 text-gray-400 cursor-not-allowed'
              }`}
            >
              <span className="relative z-10">
                {!isConnected 
                  ? 'CONNECT WALLET'
                  : chainWarning
                  ? 'WRONG NETWORK'
                  : !amount || parseFloat(amount) <= 0
                  ? 'ENTER AMOUNT'
                  : swapStatus !== SwapStatus.IDLE
                  ? statusMessage
                  : 'SWAP NOW'
                }
              </span>
              {isConnected && !chainWarning && amount && parseFloat(amount) > 0 && swapStatus === SwapStatus.IDLE && (
                <div className="absolute inset-0 rounded-xl bg-gradient-to-r from-[#ffd700] via-[#ffed4a] to-[#ffd700] opacity-50 blur-lg transition-opacity duration-300 hover:opacity-100"></div>
              )}
            </button>

            {/* Status Message */}
            {swapStatus !== SwapStatus.IDLE && swapStatus !== SwapStatus.ERROR && (
              <div className="mt-4 p-4 rounded-lg bg-gray-800/50 border border-gray-700">
                <div className="flex items-center space-x-2">
                  <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-yellow-400"></div>
                  <p className="text-sm text-gray-300">{statusMessage}</p>
                </div>
                {swapStatus === SwapStatus.WAITING_FOR_COMPLETION && (
                  <p className="mt-2 text-xs text-gray-400">
                    Your tokens are safely locked in escrow. The cross-chain swap is being processed. 
                    This can take a few minutes to complete.
                  </p>
                )}
              </div>
            )}

            {/* Error Message */}
            {swapError && (
              <div className="mt-4 p-4 rounded-lg bg-red-900/20 border border-red-800">
                <p className="text-sm text-red-400">{swapError}</p>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Token Selection Modals */}
      <TokenModal
        isOpen={isFromModalOpen}
        onClose={() => setIsFromModalOpen(false)}
        onSelect={handleFromTokenSelect}
        tokens={tokens}
        selectedToken={fromToken}
        otherSelectedToken={toToken}
      />
      <TokenModal
        isOpen={isToModalOpen}
        onClose={() => setIsToModalOpen(false)}
        onSelect={handleToTokenSelect}
        tokens={tokens}
        selectedToken={toToken}
        otherSelectedToken={fromToken}
      />
    </div>
  );
}
