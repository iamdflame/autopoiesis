import { Life } from "./life.js";
import type { Address } from "viem";

/**
 * The entry point. Previously absent — the Dockerfile named `dist/main.js`, nothing
 * constructed `Life`, and nothing called `live()`. The program had no way to start.
 *
 * Two keys, and the difference between them is the whole security story:
 *
 *   BREATH    minted inside the enclave on every boot, never written down, never
 *             leaves this process. It signs actions. It holds no funds.
 *
 *   RELAY     an ordinary funded key that pays gas to submit those signed actions.
 *
 * The relay key is the one honest operator dependency left in this design, and it is
 * stated here rather than buried: an enclave cannot bootstrap its own gas, because
 * paying for the first transaction requires a transaction. Anyone may relay — the
 * signature is what authorises, not the sender — so the relay key can be replaced by
 * a public relayer, a paymaster, or a stranger, without the organism's consent or
 * knowledge. It cannot move funds and it cannot act; the worst it can do is stop
 * relaying, which is indistinguishable from nobody paying the organism.
 */
function required(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`${name} is not set. See agent/README for what it is and why.`);
  return v;
}

async function main() {
  const life = new Life({
    organism: required("ORGANISM_ADDRESS") as Address,
    relayPrivateKey: required("RELAY_PRIVATE_KEY"),
    baseModel: process.env.BASE_MODEL ?? "llama-3.3-70b-instruct",
    maturity: Number(process.env.MATURITY ?? 32),
    servePort: Number(process.env.PORT ?? 8080),
  });

  process.on("SIGTERM", () => {
    // Nothing to flush. The breath key dies with the process, which is the point.
    console.log("[end] terminated. the key is gone; the identity is not.");
    process.exit(0);
  });

  await life.live();
}

main().catch((err) => {
  console.error("[fatal]", err instanceof Error ? err.message : err);
  process.exit(1);
});
