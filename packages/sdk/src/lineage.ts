import { createPublicClient, http, type Address, type PublicClient } from "viem";
import { OG_MAINNET } from "./chain.js";

export interface LineageNode {
  id: bigint;
  owner: Address;
  weightsRoot: `0x${string}`;
  datasetRoot: `0x${string}`;
  depth: number;
  inheritBps: number;
  attested: boolean;
  parents: { id: bigint; bps: number }[];
  children: bigint[];
  earned: bigint;
  upstream: bigint;
  lifetimeEarned: bigint;
}

/** A single hop of value, for animating settlement in the client. */
export interface Flow {
  from: bigint;
  to: bigint;
  amount: bigint;
}

/**
 * Reads the lineage DAG out of chain state.
 *
 * The contract deliberately does not expose an "ancestors of" view: resolving one
 * on chain would be the same unbounded traversal the payment path was designed to
 * avoid, and a view function that can run out of gas is a liability disguised as a
 * convenience. Traversal belongs here, off chain, where it is free.
 */
export class LineageReader {
  private client: PublicClient;

  constructor(
    private address: Address,
    private abi: readonly unknown[],
    rpc: string = OG_MAINNET.rpcUrls.default.http[0]
  ) {
    this.client = createPublicClient({ transport: http(rpc) }) as PublicClient;
  }

  private read<T>(functionName: string, args: unknown[]): Promise<T> {
    return this.client.readContract({
      address: this.address,
      abi: this.abi as never,
      functionName,
      args,
    }) as Promise<T>;
  }

  async node(id: bigint): Promise<LineageNode> {
    const [raw, parents, children, owner, earned, upstream, lifetime] = await Promise.all([
      this.read<any>("getNode", [id]),
      this.read<any[]>("parentsOf", [id]),
      this.read<bigint[]>("childrenOf", [id]),
      this.read<Address>("ownerOf", [id]),
      this.read<bigint>("earned", [id]),
      this.read<bigint>("upstream", [id]),
      this.read<bigint>("lifetimeEarned", [id]),
    ]);

    return {
      id,
      owner,
      weightsRoot: raw.weightsRoot,
      datasetRoot: raw.datasetRoot,
      depth: Number(raw.depth),
      inheritBps: Number(raw.inheritBps),
      attested: raw.attested,
      parents: parents.map((p) => ({ id: p.id as bigint, bps: Number(p.bps) })),
      children,
      earned,
      upstream,
      lifetimeEarned: lifetime,
    };
  }

  /** Every ancestor of a node, breadth-first, deduplicated. */
  async ancestors(id: bigint): Promise<LineageNode[]> {
    const seen = new Map<string, LineageNode>();
    let frontier = [id];

    while (frontier.length) {
      const layer = await Promise.all(frontier.map((n) => this.node(n)));
      const next: bigint[] = [];
      for (const n of layer) {
        if (seen.has(n.id.toString())) continue;
        seen.set(n.id.toString(), n);
        for (const p of n.parents) next.push(p.id);
      }
      frontier = next;
    }
    return [...seen.values()].sort((a, b) => a.depth - b.depth);
  }

  /**
   * Simulate where a fee paid to `id` ends up, without spending anything.
   *
   * This mirrors the contract's arithmetic exactly, including the rule that the last
   * parent absorbs the division remainder, so the preview a user sees before paying
   * is the settlement they get afterwards — to the wei.
   */
  async previewSplit(id: bigint, amount: bigint): Promise<{ shares: Map<string, bigint>; flows: Flow[] }> {
    const nodes = new Map((await this.ancestors(id)).map((n) => [n.id.toString(), n]));
    const shares = new Map<string, bigint>();
    const flows: Flow[] = [];

    const credit = (n: bigint, v: bigint) =>
      shares.set(n.toString(), (shares.get(n.toString()) ?? 0n) + v);

    const push = (nodeId: bigint, value: bigint) => {
      const n = nodes.get(nodeId.toString());
      if (!n || value === 0n) return;

      const up = (value * BigInt(n.inheritBps)) / 10_000n;
      credit(nodeId, value - up);
      if (up === 0n || n.parents.length === 0) return;

      let distributed = 0n;
      n.parents.forEach((p, i) => {
        const isLast = i === n.parents.length - 1;
        const share = isLast ? up - distributed : (up * BigInt(p.bps)) / 10_000n;
        distributed += share;
        flows.push({ from: nodeId, to: p.id, amount: share });
        push(p.id, share);
      });
    };

    push(id, amount);
    return { shares, flows };
  }
}
