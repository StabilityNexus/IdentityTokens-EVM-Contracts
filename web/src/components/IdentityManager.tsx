'use client';
import { useState } from 'react';

export default function IdentityManager() {
  const [name, setName] = useState('');
  const [nationality, setNationality] = useState('');
  
  // Placeholder for contract interaction logic
  const handleMint = async () => {
    console.log("Minting identity...");
    // 1. Connect to wallet
    // 2. Call IdentityToken.mint()
  };

  const handleUpdate = async () => {
    console.log("Updating profile...", { name, nationality });
    // Call IdentityToken.setProfile(tokenId, { name, nationality, ... })
  };

  return (
    <div className="w-full max-w-md p-6 border rounded-lg shadow-lg bg-white">
      <h2 className="text-2xl font-bold mb-4">Manage Identity</h2>
      <button onClick={handleMint} className="w-full bg-green-500 text-white p-2 rounded mb-6 font-semibold">
        Mint New Identity Token
      </button>

      <div className="space-y-4">
        <h3 className="font-semibold text-lg">Update Profile</h3>
        <div>
          <label className="block text-sm font-medium text-gray-700">Name</label>
          <input 
            type="text" 
            placeholder="John Doe" 
            value={name} 
            onChange={(e) => setName(e.target.value)}
            className="w-full p-2 border rounded mt-1"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700">Nationality</label>
          <input 
            type="text" 
            placeholder="Earth" 
            value={nationality} 
            onChange={(e) => setNationality(e.target.value)}
            className="w-full p-2 border rounded mt-1"
          />
        </div>
        {/* Add other fields: socialLinks, birthDate, etc. */}
        
        <button onClick={handleUpdate} className="w-full bg-blue-500 text-white p-2 rounded font-semibold">
          Save Profile
        </button>
      </div>
    </div>
  );
}
