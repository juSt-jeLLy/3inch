'use client';

import { Fragment } from 'react';
import { Dialog, Transition } from '@headlessui/react';
import Image from 'next/image';
import { XMarkIcon } from '@heroicons/react/24/outline';

export interface Token {
  id: string;
  name: string;
  fullName: string;
  icon: string;
  network: string;
  chainId: number;
}

interface TokenModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSelect: (token: Token) => void;
  tokens: Token[];
  selectedToken?: Token;
  otherSelectedToken?: Token; // To prevent selecting the same token
}

export default function TokenModal({
  isOpen,
  onClose,
  onSelect,
  tokens,
  selectedToken,
  otherSelectedToken,
}: TokenModalProps) {
  const handleSelect = (token: Token) => {
    onSelect(token);
    onClose();
  };

  return (
    <Transition appear show={isOpen} as={Fragment}>
      <Dialog as="div" className="relative z-50" onClose={onClose}>
        <Transition.Child
          as={Fragment}
          enter="ease-out duration-300"
          enterFrom="opacity-0"
          enterTo="opacity-100"
          leave="ease-in duration-200"
          leaveFrom="opacity-100"
          leaveTo="opacity-0"
        >
          <div className="fixed inset-0 bg-black/80" />
        </Transition.Child>

        <div className="fixed inset-0 overflow-y-auto">
          <div className="flex min-h-full items-center justify-center p-4">
            <Transition.Child
              as={Fragment}
              enter="ease-out duration-300"
              enterFrom="opacity-0 scale-95"
              enterTo="opacity-100 scale-100"
              leave="ease-in duration-200"
              leaveFrom="opacity-100 scale-100"
              leaveTo="opacity-0 scale-95"
            >
              <Dialog.Panel className="w-full max-w-md transform overflow-hidden rounded-2xl bg-[#1a1a1a] border border-[#ffd700]/10 p-6 text-left align-middle shadow-xl transition-all">
                <Dialog.Title as="div" className="flex justify-between items-center mb-6">
                  <h3 className="text-lg font-medium text-[#ffd700]">
                    Select Token
                  </h3>
                  <button
                    onClick={onClose}
                    className="p-1 rounded-full hover:bg-[#ffd700]/10 transition-colors duration-200"
                  >
                    <XMarkIcon className="h-5 w-5 text-[#ffd700]" />
                  </button>
                </Dialog.Title>

                <div className="space-y-2">
                  {tokens.map((token) => {
                    const isDisabled = token.id === otherSelectedToken?.id;
                    const isSelected = token.id === selectedToken?.id;

                    return (
                      <button
                        key={token.id}
                        onClick={() => !isDisabled && handleSelect(token)}
                        disabled={isDisabled}
                        className={`w-full flex items-center gap-4 p-4 rounded-xl transition-all duration-200 ${
                          isDisabled
                            ? 'opacity-50 cursor-not-allowed bg-gray-800/20'
                            : isSelected
                            ? 'bg-[#ffd700]/20 border border-[#ffd700]/30'
                            : 'hover:bg-[#ffd700]/10 border border-transparent'
                        }`}
                      >
                        <div className="relative">
                          <div className={`absolute inset-0 rounded-full blur-md ${
                            isSelected ? 'bg-[#ffd700]/30' : 'bg-[#ffd700]/10'
                          }`}></div>
                          <Image
                            src={token.icon}
                            alt={token.name}
                            width={40}
                            height={40}
                            className="relative"
                          />
                        </div>
                        <div className="flex-grow text-left">
                          <div className="font-bold text-white">{token.name}</div>
                          <div className="text-sm text-gray-400">{token.network}</div>
                        </div>
                      </button>
                    );
                  })}
                </div>
              </Dialog.Panel>
            </Transition.Child>
          </div>
        </div>
      </Dialog>
    </Transition>
  );
} 