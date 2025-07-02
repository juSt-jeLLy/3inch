'use client';

import { useState, useRef, useEffect } from 'react';
import { WalletIcon, ChevronDownIcon } from "@heroicons/react/24/outline";
import { useWallet } from '../context/WalletContext';
import NetworkSelector from './NetworkSelector';
import Image from 'next/image';
import { SUPPORTED_CHAINS } from '../config/wallets';

export default function Navbar() {
  const [isHovering, setIsHovering] = useState(false);
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);
  const { isConnected, openModal, wallet, disconnectWallet } = useWallet();

  const currentChain = SUPPORTED_CHAINS.find(chain => chain.chainId === wallet?.chainId);

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsDropdownOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  return (
    <nav className="bg-black/30 backdrop-blur-lg border-b border-[#ffd700]/10 sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          <div className="flex items-center">
            <span className="text-2xl font-bold bg-gradient-to-r from-[#ffd700] via-[#ffed4a] to-[#ffd700] text-transparent bg-clip-text hover:scale-105 transition-transform cursor-pointer">
              3INCH
            </span>
          </div>
          <div className="flex items-center space-x-4">
            {isConnected && <NetworkSelector />}
            <div className="relative" ref={dropdownRef}>
              <button
                onClick={() => isConnected ? setIsDropdownOpen(!isDropdownOpen) : openModal()}
                onMouseEnter={() => setIsHovering(true)}
                onMouseLeave={() => setIsHovering(false)}
                className="group relative px-6 py-2 rounded-xl bg-gradient-to-r from-[#ffd700] via-[#ffed4a] to-[#ffd700] text-black font-bold hover:shadow-lg hover:shadow-[#ffd700]/20 transition-all duration-300 hover:scale-105"
              >
                <span className="absolute inset-0 rounded-xl bg-gradient-to-r from-[#ffd700] via-[#ffed4a] to-[#ffd700] opacity-50 blur-lg transition-opacity duration-300 group-hover:opacity-100"></span>
                <span className="relative flex items-center">
                  {isConnected ? (
                    <>
                      {currentChain && (
                        <Image
                          src={currentChain.iconUrl}
                          alt={currentChain.name}
                          width={20}
                          height={20}
                          className="mr-2"
                        />
                      )}
                      <span className="mr-2">{`${wallet?.address.slice(0, 6)}...${wallet?.address.slice(-4)}`}</span>
                      <ChevronDownIcon className={`h-4 w-4 transition-transform duration-300 ${isDropdownOpen ? 'rotate-180' : ''}`} />
                    </>
                  ) : (
                    <>
                      <WalletIcon className={`h-5 w-5 mr-2 transition-transform duration-300 ${isHovering ? 'rotate-12' : ''}`} />
                      Connect Wallet
                    </>
                  )}
                </span>
              </button>

              {/* Dropdown Menu */}
              {isDropdownOpen && isConnected && (
                <div className="absolute right-0 mt-2 w-48 rounded-xl bg-black/80 border border-[#ffd700]/20 shadow-lg overflow-hidden">
                  <button
                    onClick={() => {
                      disconnectWallet();
                      setIsDropdownOpen(false);
                    }}
                    className="w-full px-4 py-3 text-left text-[#ffd700] hover:bg-[#ffd700]/10 transition-colors flex items-center"
                  >
                    <WalletIcon className="h-5 w-5 mr-2" />
                    Disconnect
                  </button>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </nav>
  );
} 