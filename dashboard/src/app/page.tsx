'use client'

import { useAccount, useWriteContract, usePublicClient } from 'wagmi'
import { abi } from '@/lib/contract'
import { useState, useEffect } from 'react'
import { parseEther, formatEther } from 'viem'

const CONTRACT_ADDRESS = process.env.NEXT_PUBLIC_CONTRACT_ADDRESS as `0x${string}`

export default function Dashboard() {
  const { address, isConnected } = useAccount()
  const publicClient = usePublicClient()
  const { writeContract } = useWriteContract()

  const [rootId, setRootId] = useState<bigint>(0n)
  const [subId, setSubId] = useState<bigint>(0n)
  const [delegations, setDelegations] = useState<any[]>([])
  const [tree, setTree] = useState<Map<bigint, bigint[]>>(new Map())
  const [expanded, setExpanded] = useState<Set<bigint>>(new Set())

  // Refresh tree
  const refresh = async () => {
    if (!publicClient) return
    const d = await publicClient.readContract({
      address: CONTRACT_ADDRESS,
      abi,
      functionName: 'getChildren',
      args: [0n]
    })
    const children = await Promise.all(d.map(async (id) => {
      const c = await publicClient.readContract({
        address: CONTRACT_ADDRESS,
        abi,
        functionName: 'getChildren',
        args: [id]
      })
      return { id, children: c }
    }))
    const map = new Map<bigint, bigint[]>()
    for (const { id, children } of children) map.set(id, children)
    setTree(map)
  }

  useEffect(() => { if (isConnected) refresh() }, [isConnected, publicClient])

  const createRoot = async (e: React.FormEvent) => {
    e.preventDefault()
    const form = e.target as HTMLFormElement
    const targets = (form.elements.namedItem('targets') as HTMLInputElement).value.split(',').map(s => s.trim() as `0x${string}`).filter(Boolean)
    const selectorsRaw = (form.elements.namedItem('selectors') as HTMLInputElement).value.split(',').map(s => s.trim())
    const selectors = selectorsRaw.map(s => `0x${BigInt('0x' + s).toString(16).padStart(8, '0')}` as `0x${string}`)
    const maxValue = (form.elements.namedItem('maxValue') as HTMLInputElement).value
    const ttl = (form.elements.namedItem('ttl') as HTMLInputElement).value
    const intentRaw = (form.elements.namedItem('intent') as HTMLInputElement).value.trim()
    const intentHash = intentRaw ? `0x${BigInt('0x' + intentRaw).toString(16).padStart(64, '0')}` : `0x${'0'.repeat(64)}`

    writeContract({
      address: CONTRACT_ADDRESS,
      abi,
      functionName: 'createDelegation',
      args: [
        (form.elements.namedItem('delegate') as HTMLInputElement).value as `0x${string}`,
        targets,
        selectors,
        parseEther(maxValue),
        BigInt(ttl),
        intentHash as `0x${string}`
      ]
    })
  }

  const createSub = async (e: React.FormEvent) => {
    e.preventDefault()
    const form = e.target as HTMLFormElement
    const parent = BigInt((form.elements.namedItem('parent') as HTMLInputElement).value)
    const delegate = (form.elements.namedItem('subDelegate') as HTMLInputElement).value as `0x${string}`
    const targets = (form.elements.namedItem('subTargets') as HTMLInputElement).value.split(',').map(s => s.trim() as `0x${string}`).filter(Boolean)
    const selectorsRaw = (form.elements.namedItem('subSelectors') as HTMLInputElement).value.split(',').map(s => s.trim())
    const selectors = selectorsRaw.map(s => `0x${BigInt('0x' + s).toString(16).padStart(8, '0')}` as `0x${string}`)
    const maxValue = (form.elements.namedItem('subMax') as HTMLInputElement).value
    const ttl = (form.elements.namedItem('subTtl') as HTMLInputElement).value
    const intentRaw = (form.elements.namedItem('subIntent') as HTMLInputElement).value.trim()
    const intentHash = intentRaw ? `0x${BigInt('0x' + intentRaw).toString(16).padStart(64, '0')}` : `0x${'0'.repeat(64)}`

    writeContract({
      address: CONTRACT_ADDRESS,
      abi,
      functionName: 'createSubDelegation',
      args: [
        parent,
        delegate,
        targets,
        selectors,
        parseEther(maxValue),
        BigInt(ttl),
        intentHash as `0x${string}`
      ]
    })
  }

  const executeCall = async (e: React.FormEvent) => {
    e.preventDefault()
    const form = e.target as HTMLFormElement
    const delegationId = BigInt((form.elements.namedItem('execId') as HTMLInputElement).value)
    const target = (form.elements.namedItem('execTarget') as HTMLInputElement).value as `0x${string}`
    const data = (form.elements.namedItem('execData') as HTMLInputElement).value
    const value = (form.elements.namedItem('execValue') as HTMLInputElement).value

    writeContract({
      address: CONTRACT_ADDRESS,
      abi,
      functionName: 'execute',
      args: [delegationId, target, data as `0x${string}`, parseEther(value)],
      value: parseEther(value)
    })
  }

  const revoke = async (id: bigint) => {
    writeContract({
      address: CONTRACT_ADDRESS,
      abi,
      functionName: 'revoke',
      args: [id]
    })
  }

  if (!isConnected) return <div className="p-8 text-center">Connect your wallet to use the dashboard.</div>

  return (
    <div className="min-h-screen bg-zinc-950 text-zinc-100 p-6">
      <h1 className="text-2xl font-bold mb-4">Delegator Agent Dashboard</h1>
      <p className="mb-6 text-zinc-400">Contract: {CONTRACT_ADDRESS}</p>

      {/* Forms */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
        {/* Create Root */}
        <form onSubmit={createRoot} className="border border-zinc-800 p-4 rounded bg-zinc-900">
          <h2 className="text-lg font-semibold mb-2">Create Root Delegation</h2>
          <div className="grid gap-2">
            <input name="delegate" placeholder="Delegate address" className="px-2 py-1 bg-zinc-800 rounded text-sm" required />
            <input name="targets" placeholder="Allowed targets (comma separated, empty for any)" className="px-2 py-1 bg-zinc-800 rounded text-sm" />
            <input name="selectors" placeholder="Allowed selectors (bytes4 hex, comma sep)" className="px-2 py-1 bg-zinc-800 rounded text-sm" />
            <input name="maxValue" placeholder="Max value (ETH)" className="px-2 py-1 bg-zinc-800 rounded text-sm" required />
            <input name="ttl" placeholder="TTL (seconds)" className="px-2 py-1 bg-zinc-800 rounded text-sm" required />
            <input name="intent" placeholder="Intent hash (hex)" className="px-2 py-1 bg-zinc-800 rounded text-sm" />
            <button type="submit" className="bg-blue-600 hover:bg-blue-700 px-3 py-1 rounded text-sm">Create</button>
          </div>
        </form>

        {/* Create Sub */}
        <form onSubmit={createSub} className="border border-zinc-800 p-4 rounded bg-zinc-900">
          <h2 className="text-lg font-semibold mb-2">Create Sub-Delegation</h2>
          <div className="grid gap-2">
            <input name="parent" placeholder="Parent delegation ID" className="px-2 py-1 bg-zinc-800 rounded text-sm" required />
            <input name="subDelegate" placeholder="Sub-delegate address" className="px-2 py-1 bg-zinc-800 rounded text-sm" required />
            <input name="subTargets" placeholder="Allowed targets (empty for any)" className="px-2 py-1 bg-zinc-800 rounded text-sm" />
            <input name="subSelectors" placeholder="Allowed selectors (bytes4 hex)" className="px-2 py-1 bg-zinc-800 rounded text-sm" />
            <input name="subMax" placeholder="Max value (ETH)" className="px-2 py-1 bg-zinc-800 rounded text-sm" required />
            <input name="subTtl" placeholder="TTL (seconds)" className="px-2 py-1 bg-zinc-800 rounded text-sm" required />
            <input name="subIntent" placeholder="Intent hash (hex)" className="px-2 py-1 bg-zinc-800 rounded text-sm" />
            <button type="submit" className="bg-green-600 hover:bg-green-700 px-3 py-1 rounded text-sm">Create Sub</button>
          </div>
        </form>

        {/* Execute */}
        <form onSubmit={executeCall} className="border border-zinc-800 p-4 rounded bg-zinc-900">
          <h2 className="text-lg font-semibold mb-2">Execute Call</h2>
          <div className="grid gap-2">
            <input name="execId" placeholder="Delegation ID" className="px-2 py-1 bg-zinc-800 rounded text-sm" required />
            <input name="execTarget" placeholder="Target address" className="px-2 py-1 bg-zinc-800 rounded text-sm" required />
            <input name="execData" placeholder="Calldata (hex)" className="px-2 py-1 bg-zinc-800 rounded text-sm" required />
            <input name="execValue" placeholder="ETH value" className="px-2 py-1 bg-zinc-800 rounded text-sm" required />
            <button type="submit" className="bg-purple-600 hover:bg-purple-700 px-3 py-1 rounded text-sm">Execute</button>
          </div>
        </form>

        {/* Revoke */}
        <div className="border border-zinc-800 p-4 rounded bg-zinc-900">
          <h2 className="text-lg font-semibold mb-2">Quick Revoke</h2>
          <div className="grid gap-2">
            <input id="revokeId" placeholder="Delegation ID" className="px-2 py-1 bg-zinc-800 rounded text-sm" />
            <button onClick={() => { const v = (document.getElementById('revokeId') as HTMLInputElement).value; if (v) revoke(BigInt(v)) }} className="bg-red-600 hover:bg-red-700 px-3 py-1 rounded text-sm">Revoke</button>
          </div>
        </div>
      </div>

      {/* Tree */}
      <div>
        <h2 className="text-xl font-bold mb-2">Delegation Tree</h2>
        <button onClick={refresh} className="mb-4 px-3 py-1 bg-zinc-800 rounded text-sm">Refresh</button>
        <ul className="space-y-1">
          {Array.from(tree.entries()).map(([id, children]) => (
            <li key={Number(id)} className="ml-4">
              <button onClick={() => setExpanded(s => { const n = new Set(s); n.has(id) ? n.delete(id) : n.add(id); return n })} className="text-blue-400 hover:underline">
                {expanded.has(id) ? '▼' : '▶'} Delegation {Number(id)} (children: {children.length})
              </button>
              {expanded.has(id) && children.length > 0 && (
                <ul className="ml-4">
                  {children.map(cid => (
                    <li key={Number(cid)}>Delegation {Number(cid)}</li>
                  ))}
                </ul>
              )}
            </li>
          ))}
        </ul>
      </div>
    </div>
  )
}
