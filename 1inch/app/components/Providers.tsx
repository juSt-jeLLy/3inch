'use client';

import { WalletProvider } from '../context/WalletContext';
import WalletModal from './WalletModal';

export default function Providers({ children }: { children: React.ReactNode }) {
  return (
    <WalletProvider>
      {children}
      <WalletModal />
    </WalletProvider>
  );
} 