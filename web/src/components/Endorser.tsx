'use client';
import { useState } from 'react';

export default function Endorser() {
  const [targetTokenId, setTargetTokenId] = useState('');
  const [connectionType, setConnectionType] = useState('');

  const handleEndorse = async () => {
    console.log("Endorsing token:", targetTokenId, "Type:", connectionType);
    // Call IdentityToken.endorse(myTokenId, targetTokenId, keccak256(connectionType), 0)
  };

  return (
    <div className="w-full max-w-md p-6 border rounded-lg shadow-lg bg-white">
      <h2 className="text-2xl font-bold mb-4">Endorse an Identity</h2>
      <div className="space-y-4">
        <div>
           <label className="block text-sm font-medium text-gray-700">Target Token ID</label>
           <input 
             type="number" 
             placeholder="e.g. 42" 
             value={targetTokenId} 
             onChange={(e) => setTargetTokenId(e.target.value)}
             className="w-full p-2 border rounded mt-1"
           />
        </div>
        <div>
            <label className="block text-sm font-medium text-gray-700">Connection Type</label>
            <select 
                value={connectionType} 
                onChange={(e) => setConnectionType(e.target.value)}
                className="w-full p-2 border rounded mt-1"
            >
                <option value="">Select Connection Type</option>
                <option value="friend">Friend</option>
                <option value="colleague">Colleague</option>
                <option value="family">Family</option>
                <option value="other">Other</option>
            </select>
        </div>
        <button onClick={handleEndorse} className="w-full bg-purple-500 text-white p-2 rounded font-semibold">
          Endorse
        </button>
      </div>
    </div>
  );
}
