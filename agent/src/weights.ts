import { Indexer, MemData } from "@0gfoundation/0g-storage-ts-sdk";
import { ethers } from "ethers";
import { OG_MAINNET, OG_STORAGE_INDEXER } from "./chain.js";

/**
 * Weight storage on 0G.
 *
 * The economics of this protocol rest on one fact: a fine-tune does not need to
 * store a new copy of the model. A LoRA adapter is a low-rank decomposition of the
 * weight *change* — two thin matrices per adapted layer, typically 10-200MB against
 * a base of many gigabytes.
 *
 * So Cambrian stores the base weights once, addressed by Merkle root, and every
 * descendant stores only its delta. A lineage of thirty fine-tunes costs one base
 * model plus thirty adapters, not thirty-one models. Reconstruction is composition:
 * walk the lineage to a genesis root, fetch each adapter, apply in order.
 *
 * This is why 0G Storage matters here and why a generic chain could not host this.
 * Merkle-root addressing gives content identity for free — two identical adapters
 * uploaded by different people collapse to the same root, and the DAG dedupes itself.
 */

export interface StoredArtifact {
  /** 0G Storage Merkle root — the content address and the on-chain identifier. */
  root: string;
  /** Storage transaction hash. */
  txHash: string;
  sizeBytes: number;
}

export class WeightStore {
  private indexer: Indexer;
  private signer: ethers.Wallet;
  private rpc: string;

  constructor(privateKey: string, rpc: string = OG_MAINNET.rpcUrls.default.http[0]) {
    this.rpc = rpc;
    this.indexer = new Indexer(OG_STORAGE_INDEXER);
    this.signer = new ethers.Wallet(privateKey, new ethers.JsonRpcProvider(rpc));
  }

  /**
   * Upload a weight file or LoRA adapter. Files above the fragment threshold are
   * split automatically by the SDK, so multi-gigabyte base models are supported.
   */
  async put(data: Uint8Array, label: string): Promise<StoredArtifact> {
    const blob = new MemData(data);
    const [tx, err] = await this.indexer.upload(blob, this.rpc, this.signer);
    if (err) throw new Error(`0G Storage upload failed for ${label}: ${err}`);

    const [tree, treeErr] = await blob.merkleTree();
    if (treeErr) throw new Error(`merkle root unavailable for ${label}: ${treeErr}`);

    return {
      root: tree!.rootHash()!,
      txHash: typeof tx === "string" ? tx : String(tx),
      sizeBytes: data.length,
    };
  }

  /** Fetch an artifact by Merkle root, verifying the proof on the way down. */
  async get(root: string, outputPath: string): Promise<void> {
    const err = await this.indexer.download(root, outputPath, true /* withProof */);
    if (err) throw new Error(`0G Storage download failed for ${root}: ${err}`);
  }
}

/**
 * Resolve the full set of artifacts needed to reconstruct a model, ordered from
 * genesis to leaf. Applying these in sequence reproduces the model bit for bit —
 * which is what makes an on-chain lineage a *verifiable* claim rather than a label.
 */
export function reconstructionOrder(
  lineage: { id: bigint; weightsRoot: string; depth: number }[]
): string[] {
  return [...lineage].sort((a, b) => a.depth - b.depth).map((n) => n.weightsRoot);
}
