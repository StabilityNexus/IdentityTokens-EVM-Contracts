'use client';

import { useState } from 'react';
import IdentityManager from '../components/IdentityManager';
import Endorser from '../components/Endorser';

export default function Home() {
  const [activeTab, setActiveTab] = useState<'identity' | 'endorse'>('identity');

  return (
    <main className="flex min-h-screen flex-col items-center p-24">
      <h1 className="text-4xl font-bold mb-8">Decentralized Identity Tokens</h1>
      
      <div className="flex gap-4 mb-8">
        <button 
          onClick={() => setActiveTab('identity')}
          className={`px-4 py-2 border rounded ${activeTab === 'identity' ? 'bg-blue-500 text-white' : ''}`}
        >
          My Identity
        </button>
        <button 
          onClick={() => setActiveTab('endorse')}
          className={`px-4 py-2 border rounded ${activeTab === 'endorse' ? 'bg-blue-500 text-white' : ''}`}
        >
          Endorse Others
        </button>
      </div>

      {activeTab === 'identity' ? <IdentityManager /> : <Endorser />}
    </main>
  );
}
