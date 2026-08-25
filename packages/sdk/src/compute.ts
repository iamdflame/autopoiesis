import { createZGComputeNetworkBroker } from "@0gfoundation/0g-compute-ts-sdk";
import { ethers } from "ethers";
import { OG_MAINNET } from "./chain.js";

/**
 * Fine-tuning and inference on 0G Compute.
 *
 * Note which SDK path this uses. The Compute Router is the easy road — an
 * OpenAI-compatible endpoint, one balance, automatic failover — and it is what
 * every inference-wrapper reaches for. It is also inference-only.
 *
 * Cambrian needs the direct broker, because Cambrian needs to *train*. A lineage
 * is only meaningful if new nodes are genuinely descended from old ones, and that
 * means running a real fine-tune against real parent weights on a real GPU, then
 * proving it happened. The TEE signature over the job result is what converts
 * "this model claims descent" into "this model can prove descent".
 */

export interface FineTuneRequest {
  /** Merkle roots of the parent weights, in composition order. */
  parentRoots: string[];
  /** Merkle root of the training corpus on 0G Storage. */
  datasetRoot: string;
  baseModel: string;
  epochs?: number;
  loraRank?: number;
}

export interface FineTuneResult {
  /** Merkle root of the produced LoRA adapter. */
  outputRoot: string;
  /** TEE attestation over (parents, dataset, output) — the provenance proof. */
  attestation: `0x${string}`;
  providerAddress: string;
  costWei: bigint;
}

export class ComputeClient {
  private broker: Awaited<ReturnType<typeof createZGComputeNetworkBroker>> | null = null;
  private signer: ethers.Wallet;

  constructor(privateKey: string, rpc: string = OG_MAINNET.rpcUrls.default.http[0]) {
    this.signer = new ethers.Wallet(privateKey, new ethers.JsonRpcProvider(rpc));
  }

  private async ready() {
    if (!this.broker) this.broker = await createZGComputeNetworkBroker(this.signer);
    return this.broker;
  }

  /** Fund the escrow that pays providers as jobs complete. */
  async deposit(amount: string) {
    const b = await this.ready();
    await b.ledger.addLedger(ethers.parseEther(amount));
  }

  async listFineTuneProviders() {
    const b = await this.ready();
    return b.fineTuning.listService();
  }

  /**
   * Run a fine-tune. The returned attestation is what `registerDerivative` consumes:
   * the contract will not accept a descendant whose training statement does not verify
   * once a verifier is live.
   */
  async fineTune(req: FineTuneRequest): Promise<FineTuneResult> {
    const b = await this.ready();
    const providers = await b.fineTuning.listService();
    if (!providers.length) throw new Error("no 0G Compute fine-tuning providers available");

    const provider = providers[0];
    const task = await b.fineTuning.createTask(
      provider.provider,
      provider.serviceName ?? req.baseModel,
      req.datasetRoot,
      JSON.stringify({
        epochs: req.epochs ?? 3,
        lora_rank: req.loraRank ?? 16,
        parent_roots: req.parentRoots,
      })
    );

    const done = await this.awaitTask(provider.provider, task);
    return {
      outputRoot: done.outputRoot,
      attestation: done.signature as `0x${string}`,
      providerAddress: provider.provider,
      costWei: BigInt(done.cost ?? 0),
    };
  }

  private async awaitTask(provider: string, taskId: string, timeoutMs = 30 * 60_000) {
    const b = await this.ready();
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      const t: any = await b.fineTuning.getTask(provider, taskId);
      if (t.progress === "Finished" || t.status === "completed") return t;
      if (t.progress === "Failed" || t.status === "failed") {
        throw new Error(`fine-tune failed: ${t.error ?? "unknown"}`);
      }
      await new Promise((r) => setTimeout(r, 15_000));
    }
    throw new Error("fine-tune timed out");
  }

  /**
   * Serve an inference from a lineage node. Returns the response together with the
   * TEE-signed digest that `pay()` records on chain, so the fee is bound to a
   * specific verified response rather than being an unattributable transfer.
   */
  async infer(model: string, messages: { role: string; content: string }[]) {
    const b = await this.ready();
    const services = await b.inference.listService();
    const svc = services.find((s: any) => s.model === model) ?? services[0];
    if (!svc) throw new Error("no 0G Compute inference providers available");

    const { endpoint, model: served } = await b.inference.getServiceMetadata(svc.provider);
    const headers = await b.inference.getRequestHeaders(svc.provider, JSON.stringify(messages));

    const res = await fetch(`${endpoint}/chat/completions`, {
      method: "POST",
      headers: { "Content-Type": "application/json", ...headers },
      body: JSON.stringify({ model: served, messages }),
    });
    if (!res.ok) throw new Error(`0G inference failed: ${res.status} ${await res.text()}`);

    const json: any = await res.json();
    const content = json.choices?.[0]?.message?.content ?? "";
    const valid = await b.inference.processResponse(svc.provider, content, json.id);

    return {
      content,
      teeVerified: Boolean(valid),
      chatId: json.id as string,
      provider: svc.provider as string,
      digest: ethers.keccak256(ethers.toUtf8Bytes(`${json.id}:${content}`)) as `0x${string}`,
    };
  }
}
