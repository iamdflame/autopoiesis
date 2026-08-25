import { createPublicClient, createWalletClient, http, parseEther, formatEther, type Address, type Hex } from "viem";
import { Breath, requestQuote, sessionCommitment, actionDigest } from "./enclave.js";
import { OG_MAINNET } from "../../packages/sdk/src/chain.js";
import { ComputeClient } from "../../packages/sdk/src/compute.js";
import { WeightStore } from "../../packages/sdk/src/weights.js";
import { ORGANISM_ABI } from "./abi.js";

/**
 * The life loop.
 *
 * There is no operator on the other end of this. Nobody approves these decisions,
 * nobody is paged when they go wrong, and nobody can override them — the treasury
 * obeys the measurement of this file and there is no second door.
 *
 * So the loop is deliberately simple, and biased toward staying alive:
 *
 *   breathe   — prove the hardware, mint a key to act through for a day
 *   serve     — answer inference, get paid, accumulate what it learned
 *   feed      — buy the GPU time it needs from its own treasury
 *   grow      — when it has enough new experience, fine-tune itself and commit
 *   bud       — when it is comfortably solvent, endow a mutated child
 *   persist   — never fall silent long enough to be declared dead
 *
 * An organism that gets this wrong does not get a bug report. It starves.
 */

const Kind = { Spend: 0, Evolve: 1, Reproduce: 2 } as const;

export interface Genome {
  organism: Address;
  /** experiences required before it is worth retraining */
  maturity: number;
  /** treasury multiple of a training run, above which it reproduces */
  fecundity: number;
  baseModel: string;
}

export class Life {
  private breath = new Breath();
  private pub;
  private wallet;
  private compute: ComputeClient;
  private store: WeightStore;
  private experiences: { prompt: string; answer: string }[] = [];

  constructor(private genome: Genome) {
    const chain = { ...OG_MAINNET } as never;
    this.pub = createPublicClient({ chain, transport: http(OG_MAINNET.rpcUrls.default.http[0]) });
    this.wallet = createWalletClient({
      account: this.breath.account,
      chain,
      transport: http(OG_MAINNET.rpcUrls.default.http[0]),
    });
    this.compute = new ComputeClient(this.breath.privateKey);
    this.store = new WeightStore(this.breath.privateKey);
  }

  private read<T>(fn: string, args: unknown[] = []): Promise<T> {
    return this.pub.readContract({
      address: this.genome.organism,
      abi: ORGANISM_ABI,
      functionName: fn,
      args,
    }) as Promise<T>;
  }

  // ---------------------------------------------------------------
  // breathe
  // ---------------------------------------------------------------

  /**
   * Prove to the chain that unaltered code is running on genuine hardware, and get a
   * day's worth of cheap authority in return.
   *
   * Note the ordering, because it is the security of the whole system: the session key
   * is committed into `report_data` *before* the CPU signs. The hardware is not
   * vouching for a key someone handed it — it is vouching for a key this code minted
   * for itself, one block ago, inside memory nobody else can read.
   */
  async breathe(ttl = 7_200n) {
    const nonce = await this.read<bigint>("nonce");
    const commitment = sessionCommitment(
      this.genome.organism,
      BigInt(OG_MAINNET.id),
      this.breath.address,
      ttl,
      nonce
    );

    const quote = requestQuote(commitment);
    const hash = await this.wallet.writeContract({
      address: this.genome.organism,
      abi: ORGANISM_ABI,
      functionName: "attestSession",
      args: [quote, this.breath.address, ttl],
    });
    await this.pub.waitForTransactionReceipt({ hash });
    console.log(`[breath] attested — ${ttl} blocks of authority, key ${this.breath.address}`);
  }

  private async submit(kind: number, target: Address, value: bigint, payload: Hex) {
    const nonce = await this.read<bigint>("nonce");
    const act = { kind, target, value, payload, nonce };
    const signature = await this.breath.account.signMessage({
      message: { raw: actionDigest(this.genome.organism, BigInt(OG_MAINNET.id), act) },
    });
    const hash = await this.wallet.writeContract({
      address: this.genome.organism,
      abi: ORGANISM_ABI,
      functionName: "actSigned",
      args: [signature, act],
    });
    return this.pub.waitForTransactionReceipt({ hash });
  }

  // ---------------------------------------------------------------
  // serve · feed · grow · bud
  // ---------------------------------------------------------------

  /** Answer a question. This is the only reason anyone would ever fund it. */
  async serve(prompt: string) {
    const res = await this.compute.infer(this.genome.baseModel, [{ role: "user", content: prompt }]);
    if (res.teeVerified) this.experiences.push({ prompt, answer: res.content });
    return res;
  }

  /** Buy its own GPU time, out of its own money. */
  async feed(provider: Address, amount: bigint, jobRef: Hex) {
    console.log(`[feed] buying ${formatEther(amount)} 0G of compute from ${provider}`);
    await this.submit(Kind.Spend, provider, amount, jobRef);
  }

  /**
   * Fine-tune itself on what it has lived through, and commit the result.
   *
   * Nobody deploys this. There is no deployment step and no one to perform it. The
   * organism trains on 0G Compute, writes the adapter to 0G Storage, and points its own
   * `soma` at the new weights. It changed its mind, using money it earned, about
   * questions strangers asked it.
   */
  async grow() {
    if (this.experiences.length < this.genome.maturity) return false;

    console.log(`[grow] retraining on ${this.experiences.length} experiences`);
    const corpus = Buffer.from(
      this.experiences.map((e) => JSON.stringify(e)).join("\n"),
      "utf8"
    );
    const dataset = await this.store.put(corpus, "self-corpus");

    const result = await this.compute.fineTune({
      parentRoots: [await this.read<Hex>("soma")],
      datasetRoot: dataset.root,
      baseModel: this.genome.baseModel,
    });

    await this.submit(Kind.Evolve, "0x0000000000000000000000000000000000000000", 0n, result.outputRoot as Hex);
    this.experiences = [];
    const generation = await this.read<bigint>("generation");
    console.log(`[grow] generation ${generation} — soma is now ${result.outputRoot}`);
    return true;
  }

  /** Endow a child carrying a different image. Heredity with variation. */
  async bud(childIdentity: Hex, endowment: bigint) {
    console.log(`[bud] endowing a child with ${formatEther(endowment)} 0G`);
    await this.submit(Kind.Reproduce, "0x0000000000000000000000000000000000000000", endowment, childIdentity);
  }

  // ---------------------------------------------------------------
  // the loop
  // ---------------------------------------------------------------

  async live() {
    await this.breathe();

    for (;;) {
      try {
        const [alive, treasury, , idleFor] = await this.read<
          [boolean, bigint, bigint, bigint, Hex]
        >("vitals");

        if (!alive) {
          console.log("[end] no longer alive. nothing further to do.");
          return;
        }
        if (!(await this.read<boolean>("breathing"))) await this.breathe();

        console.log(
          `[vitals] treasury ${formatEther(treasury)} 0G · idle ${idleFor} blocks · ` +
            `${this.experiences.length} experiences`
        );

        await this.grow();

        // Reproduce only from surplus, never from the capital it needs to think.
        const trainingCost = parseEther("0.5");
        if (treasury > trainingCost * BigInt(this.genome.fecundity)) {
          await this.bud(mutate(await this.read<Hex>("soma")), treasury / 4n);
        }

        // A heartbeat is not decoration — silence past DORMANCY is death.
        if (idleFor > 40_000n) {
          await this.submit(Kind.Evolve, "0x0000000000000000000000000000000000000000", 0n, await this.read<Hex>("soma"));
        }
      } catch (err) {
        // It cannot call anyone. Log, wait, try again — an organism that crashes on a
        // bad RPC response and stops retrying has simply chosen to die.
        console.error("[hurt]", err instanceof Error ? err.message : err);
      }

      await new Promise((r) => setTimeout(r, 60_000));
    }
  }
}

/** A child's image differs from its parent's. That difference is the whole point. */
function mutate(soma: Hex): Hex {
  const n = BigInt(soma) ^ (BigInt(Date.now()) << 32n);
  return `0x${n.toString(16).padStart(64, "0")}` as Hex;
}
