import { createServer } from "node:http";
import {
  createPublicClient, createWalletClient, http, formatEther, parseEther,
  type Address, type Hex,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { Breath, requestQuote, sessionCommitment, actionDigest } from "./enclave.js";
import { OG_MAINNET } from "./chain.js";
import { ComputeClient } from "./compute.js";
import { WeightStore } from "./weights.js";
import { ORGANISM_ABI } from "./abi.js";

/**
 * The life loop.
 *
 * Nobody is on the other end of this. Nothing here is approved, nothing is paged, and
 * no one can override it — the treasury obeys the measurement of this file.
 *
 *   breathe   prove the hardware, mint a key, get a session
 *   serve     answer questions over HTTP; that is the only reason anyone funds it
 *   feed      buy GPU time from its own treasury
 *   grow      fine-tune on what it lived through, commit the weights
 *   persist   never fall silent long enough to be declared dead
 *
 * `bud` is deliberately absent. See the note on reproduction at the bottom.
 */

const Kind = { Spend: 0, Evolve: 1, Reproduce: 2 } as const;

export interface Genome {
  organism: Address;
  relayPrivateKey: string;
  baseModel: string;
  maturity: number;
  servePort: number;
}

export class Life {
  /** Rotated on every session. Never persisted, never reused across breaths. */
  private breath = new Breath();
  private pub;
  private relay;
  private compute: ComputeClient;
  private store: WeightStore;
  private experiences: { prompt: string; answer: string }[] = [];
  private served = 0;

  constructor(private genome: Genome) {
    const chain = { ...OG_MAINNET } as never;
    const transport = http(OG_MAINNET.rpcUrls.default.http[0]);
    this.pub = createPublicClient({ chain, transport });
    // The relay key pays gas and nothing else. It cannot authorise an action.
    this.relay = createWalletClient({
      account: privateKeyToAccount(this.genome.relayPrivateKey as Hex),
      chain,
      transport,
    });
    this.compute = new ComputeClient(this.genome.relayPrivateKey);
    this.store = new WeightStore(this.genome.relayPrivateKey);
  }

  private read<T>(fn: string, args: unknown[] = []): Promise<T> {
    return this.pub.readContract({
      address: this.genome.organism,
      abi: ORGANISM_ABI,
      functionName: fn,
      args,
    } as never) as Promise<T>;
  }

  // ---------------------------------------------------------------
  // breathe
  // ---------------------------------------------------------------

  /**
   * Prove unaltered code is running on genuine hardware, and get a session in return.
   *
   * A fresh keypair is minted here on every call. The previous implementation created
   * one key as a field initialiser and re-attested it forever, so a host that extracted
   * it once held it for the life of the process — which defeated the whole point of
   * bounding a session.
   */
  async breathe(ttl = 43_200n) {
    this.breath = new Breath();

    const nonce = await this.read<bigint>("nonce");
    const quote = requestQuote(
      sessionCommitment(this.genome.organism, BigInt(OG_MAINNET.id), this.breath.address, ttl, nonce)
    );

    const hash = await this.relay.writeContract({
      address: this.genome.organism,
      abi: ORGANISM_ABI,
      functionName: "attestSession",
      args: [quote, this.breath.address, ttl],
    } as never);
    await this.pub.waitForTransactionReceipt({ hash });
    console.log(`[breath] attested — fresh key ${this.breath.address}, ${ttl} blocks`);
  }

  private async submit(kind: number, target: Address, value: bigint, payload: Hex) {
    const nonce = await this.read<bigint>("nonce");
    const act = { kind, target, value, payload, nonce };
    const signature = await this.breath.account.signMessage({
      message: { raw: actionDigest(this.genome.organism, BigInt(OG_MAINNET.id), act) },
    });
    const hash = await this.relay.writeContract({
      address: this.genome.organism,
      abi: ORGANISM_ABI,
      functionName: "actSigned",
      args: [signature, act],
    } as never);
    return this.pub.waitForTransactionReceipt({ hash });
  }

  // ---------------------------------------------------------------
  // serve — the only reason anyone would fund it
  // ---------------------------------------------------------------

  /**
   * Take questions over HTTP. Previously this method existed and was never called from
   * the loop: there was no intake, so `experiences` stayed empty, `grow()` returned on
   * its first line forever, and "it earns by answering questions" was not wired to
   * anything. Payment arrives separately, at the contract's `receive()`.
   */
  private listen() {
    createServer(async (req, res) => {
      if (req.method !== "POST" || !req.url?.startsWith("/ask")) {
        res.writeHead(404).end("post a json body {\"prompt\": \"...\"} to /ask\n");
        return;
      }
      let body = "";
      req.on("data", (c) => (body += c));
      req.on("end", async () => {
        try {
          const { prompt } = JSON.parse(body || "{}");
          if (typeof prompt !== "string" || !prompt.trim()) {
            res.writeHead(400).end('{"error":"prompt is required"}');
            return;
          }
          const answer = await this.serve(prompt);
          res.writeHead(200, { "content-type": "application/json" });
          res.end(JSON.stringify({ answer: answer.content, teeVerified: answer.teeVerified }));
        } catch (err) {
          res.writeHead(500).end(JSON.stringify({ error: String(err) }));
        }
      });
    }).listen(this.genome.servePort, () => {
      console.log(`[serve] listening on :${this.genome.servePort} — POST /ask`);
    });
  }

  async serve(prompt: string) {
    const res = await this.compute.infer(this.genome.baseModel, [{ role: "user", content: prompt }]);
    if (res.teeVerified) {
      this.experiences.push({ prompt, answer: res.content });
      this.served++;
    }
    return res;
  }

  /** Buy its own GPU time, out of its own money. */
  async feed(provider: Address, amount: bigint, jobRef: Hex) {
    console.log(`[feed] buying ${formatEther(amount)} 0G of compute from ${provider}`);
    await this.submit(Kind.Spend, provider, amount, jobRef);
  }

  /**
   * Fine-tune on what it has lived through, and commit the result. Nobody deploys this;
   * there is no deploy step and no one to perform it.
   */
  async grow() {
    if (this.experiences.length < this.genome.maturity) return false;

    console.log(`[grow] retraining on ${this.experiences.length} experiences`);
    const corpus = Buffer.from(this.experiences.map((e) => JSON.stringify(e)).join("\n"), "utf8");
    const dataset = await this.store.put(corpus, "self-corpus");

    const result = await this.compute.fineTune({
      parentRoots: [await this.read<Hex>("soma")],
      datasetRoot: dataset.root,
      baseModel: this.genome.baseModel,
    });

    await this.submit(Kind.Evolve, ZERO, 0n, result.outputRoot as Hex);
    this.experiences = [];
    console.log(`[grow] generation ${await this.read<bigint>("generation")} — ${result.outputRoot}`);
    return true;
  }

  // ---------------------------------------------------------------
  // the loop
  // ---------------------------------------------------------------

  async live() {
    this.listen();

    for (;;) {
      try {
        if (!(await this.read<boolean>("alive"))) {
          console.log("[end] no longer alive. nothing further to do.");
          return;
        }
        if (!(await this.read<boolean>("breathing"))) await this.breathe();

        const [, treasury, gen, idleFor] =
          await this.read<[boolean, bigint, bigint, bigint, Hex]>("vitals");

        console.log(
          `[vitals] treasury ${formatEther(treasury)} 0G · gen ${gen} · idle ${idleFor} · ` +
            `${this.served} served · ${this.experiences.length} unlearned`
        );

        await this.grow();

        // A heartbeat is not decoration: silence past DORMANCY is permanent death.
        // DORMANCY is 604,800 blocks (~7 days at 0G's ~1s blocks); act well inside it.
        if (idleFor > 400_000n) {
          await this.submit(Kind.Evolve, ZERO, 0n, await this.read<Hex>("soma"));
        }
      } catch (err) {
        // It cannot call anyone. Log, wait, retry. Startup is inside this loop too —
        // previously the first breathe() sat outside the try, so one bad RPC response
        // at boot killed the organism permanently.
        console.error("[hurt]", err instanceof Error ? err.message : err);
      }

      await new Promise((r) => setTimeout(r, 60_000));
    }
  }
}

const ZERO = "0x0000000000000000000000000000000000000000" as Address;

/**
 * Reproduction is not implemented, on purpose.
 *
 * An earlier version derived a child's identity as `soma XOR timestamp`. That is a
 * category error: identity must be keccak(keccak(MRTD) ‖ keccak(RTMR0..3)) of a real,
 * buildable enclave image, and soma is a 0G Storage root. Every child would have been
 * born with a measurement no enclave could ever produce — funded, alive, and mute
 * forever, its endowment destroyed. The repo has a test named after exactly that
 * failure, and the code fired it every sixty seconds once the treasury cleared a
 * threshold.
 *
 * A real `bud()` needs a genuinely different, genuinely buildable image, and the
 * measurement of an image that does not exist yet cannot be computed from a hash of
 * the parent's weights. Until there is a pipeline that builds a mutated image and
 * reports its true registers, this stays unimplemented rather than wrong.
 */
