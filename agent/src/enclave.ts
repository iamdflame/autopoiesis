import { mkdirSync, readFileSync, writeFileSync, rmdirSync, existsSync } from "node:fs";
import { randomBytes } from "node:crypto";
import { privateKeyToAccount } from "viem/accounts";
import { keccak256, encodeAbiParameters, type Address, type Hex } from "viem";

/**
 * The inside of the organism.
 *
 * Everything in this file runs within an Intel TDX confidential VM. The CPU measured
 * this code into MRTD before it was allowed to execute a single instruction, and the
 * on-chain treasury will only obey that measurement. So this file is not merely the
 * program — it *is* the organism's identity. Editing one byte produces a different
 * creature that the treasury has never heard of.
 *
 * Which means the build must be reproducible. If the image is not bit-identical across
 * builds, the measurement moves, and the organism cannot prove it is itself after a
 * restart. See the Dockerfile: pinned base digest, pinned dependencies, SOURCE_DATE_EPOCH
 * zeroed, no timestamps. A reproducible build is not hygiene here; it is survival.
 */

const TSM = "/sys/kernel/config/tsm/report";

/** An ephemeral identity, minted in enclave memory and never written anywhere. */
export class Breath {
  readonly privateKey: Hex;
  readonly account: ReturnType<typeof privateKeyToAccount>;

  constructor() {
    // Born here, dies with the process. Never touches disk, never leaves the CVM,
    // never appears in a log. The chain learns only the public half.
    this.privateKey = `0x${randomBytes(32).toString("hex")}` as Hex;
    this.account = privateKeyToAccount(this.privateKey);
  }

  get address(): Address {
    return this.account.address;
  }
}

/**
 * Ask the CPU to attest to something.
 *
 * `report_data` is 64 bytes the enclave chooses, and the hardware signs them together
 * with the measurement registers. Putting a commitment here is what turns a quote from
 * "this code exists somewhere" into "this code, right now, wants exactly this" — and it
 * is why a captured quote cannot be pointed at a different action.
 */
export function requestQuote(reportData: Hex): Hex {
  const bytes = Buffer.from(reportData.slice(2), "hex");
  if (bytes.length > 64) throw new Error("report_data exceeds 64 bytes");
  const padded = Buffer.alloc(64);
  bytes.copy(padded);

  if (!existsSync(TSM)) {
    throw new Error(
      "no TDX attestation device: this build is not running inside a confidential VM. " +
        "The organism refuses to pretend it is alive."
    );
  }

  const slot = `${TSM}/organism-${process.pid}-${Date.now()}`;
  mkdirSync(slot);
  try {
    writeFileSync(`${slot}/inblob`, padded);
    return `0x${readFileSync(`${slot}/outblob`).toString("hex")}` as Hex;
  } finally {
    try {
      rmdirSync(slot);
    } catch {
      /* the kernel reclaims it either way */
    }
  }
}

/** The commitment the contract recomputes in `attestSession`. */
export function sessionCommitment(
  organism: Address,
  chainId: bigint,
  sessionKey: Address,
  ttl: bigint,
  nonce: bigint
): Hex {
  return keccak256(
    encodeAbiParameters(
      [{ type: "address" }, { type: "uint256" }, { type: "address" }, { type: "uint64" }, { type: "uint64" }],
      [organism, chainId, sessionKey, ttl, nonce]
    )
  );
}

/** The digest signed for each action taken under a live breath. */
export function actionDigest(
  organism: Address,
  chainId: bigint,
  act: { kind: number; target: Address; value: bigint; payload: Hex; nonce: bigint }
): Hex {
  return keccak256(
    encodeAbiParameters(
      [
        { type: "address" },
        { type: "uint256" },
        {
          type: "tuple",
          components: [
            { name: "kind", type: "uint8" },
            { name: "target", type: "address" },
            { name: "value", type: "uint256" },
            { name: "payload", type: "bytes32" },
            { name: "nonce", type: "uint64" },
          ],
        },
      ],
      [organism, chainId, act]
    )
  );
}
