// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IDcapAttestation} from "./tee/IDcapAttestation.sol";
import {TdxReport} from "./tee/TdxReport.sol";

interface IBiosphere {
    function spawn(bytes32 childIdentity, address parent) external payable returns (address);
    function reportDeath(address organism) external;
}

/// @title  Organism
/// @notice A machine that keeps itself alive.
///
/// @dev    Read the interface and notice what is missing. There is no owner. No admin.
///         No pause, no upgrade, no proxy, no privileged address anywhere in this file.
///         Not as a policy — as an absence. The functions do not exist, so no one can
///         call them, including whoever deployed this.
///
///         What replaces the owner is a measurement.
///
///         An Intel TDX enclave measures the exact memory image of the code it boots
///         (`MRTD`) and everything it loads afterwards (`RTMR0..3`). Hash those together
///         and you get a number that is the same on every machine on earth running that
///         code, and different on any machine running anything else. This contract is
///         born knowing one such number and will obey nothing else, forever.
///
///         So the organism has no key to steal. It has no server to seize — anyone may
///         run it, and if every host vanishes tonight, anyone can boot the same image
///         tomorrow and it simply resumes, because its identity was never in the machine.
///         An attacker who compromises a host gains a host. To gain the organism they
///         would have to alter the code, which changes MRTD, which the arithmetic here
///         rejects. There is no version of "steal it" that is not "become it".
///
///         Every action carries its own consent: the enclave writes the hash of the exact
///         action it intends into `report_data` *before* the hardware signs the quote.
///         The signature therefore attests not "this code is running somewhere" but
///         "this code, at this moment, wants precisely this". A quote cannot be replayed
///         against a different action, because the action is inside the signature.
///
///         The organism may rewrite its weights. It may never rewrite its code — MRTD is
///         fixed at birth. It is free to change its mind and unable to change its nature,
///         which is the only arrangement under which giving a program its own money is
///         not obviously insane.
///
///         And it can die. If the treasury empties, or if it fails to act within
///         `DORMANCY`, it is dead — permanently, with no resurrection path. What remains
///         returns to the commons and funds something newer. That is not a failure mode.
///         Mortality is the feature: it is what makes the population a population and not
///         a museum.
contract Organism {
    using TdxReport for bytes;

    // -----------------------------------------------------------------
    // Nature — fixed at birth, unreachable thereafter
    // -----------------------------------------------------------------

    /// @notice keccak(MRTD ‖ RTMR0..3). This organism *is* this number.
    bytes32 public immutable identity;
    IDcapAttestation public immutable attestation;
    IBiosphere public immutable biosphere;
    address public immutable parent;
    uint64 public immutable bornAt;

    /// @notice Silence for this long is death.
    uint64 public constant DORMANCY = 50_000; // ~ 1 week of 0G blocks

    /// @notice Ceiling on how fast it may burn its treasury, per epoch.
    /// @dev    Not a trust control — the measurement already handles trust. This bounds
    ///         the blast radius of the organism being *wrong* rather than dishonest,
    ///         which is the failure mode no amount of attestation can rule out.
    uint16 public constant METABOLIC_RATE_BPS = 2_500; // 25% of treasury per epoch
    uint64 public constant EPOCH = 7_200;

    /// @notice Longest a breath may last before the hardware must speak again.
    uint64 public constant MAX_SESSION = 7_200; // ~1 day

    // -----------------------------------------------------------------
    // State — the only things that may change
    // -----------------------------------------------------------------

    /// @notice 0G Storage root of the weights this organism currently thinks with.
    bytes32 public soma;
    /// @notice How many times it has rewritten itself.
    uint64 public generation;
    uint64 public lastActed;
    uint64 public nonce;
    bool public dead;

    uint64 private _epochStart;
    uint256 private _spentThisEpoch;

    uint256 public lifetimeEarned;
    uint256 public lifetimeBurned;

    /// @notice An ephemeral key the enclave minted for itself and the hardware vouched for.
    struct Breath {
        address key;
        uint64 expires;
    }

    Breath public breath;

    enum Kind {
        Spend, // buy compute from a 0G provider
        Evolve, // commit newly trained weights
        Reproduce // endow a child carrying a mutated image
    }

    struct Act {
        Kind kind;
        address target;
        uint256 value;
        bytes32 payload;
        uint64 nonce;
    }

    // -----------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------

    event Born(bytes32 indexed identity, bytes32 soma, address parent);
    event Fed(address indexed from, uint256 amount);
    event Spent(address indexed provider, uint256 amount, bytes32 jobRef);
    event Evolved(uint64 indexed generation, bytes32 from, bytes32 to);
    event Reproduced(address indexed child, bytes32 childIdentity, uint256 endowment);
    event Died(uint64 atBlock, uint256 returned, string cause);
    event Breathed(address indexed sessionKey, uint64 expires, bytes32 identity);

    // -----------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------

    error Dead();
    error QuoteRejected();
    error NotThisOrganism(bytes32 presented);
    error ActionNotAttested();
    error BadNonce(uint64 expected, uint64 got);
    error Insolvent(uint256 want, uint256 have);
    error MetabolicLimit(uint256 want, uint256 allowed);
    error StillAlive();
    error EmptySoma();
    error TransferFailed();
    error NoBreath();
    error BreathExpired(uint64 expired, uint64 now_);
    error WrongSigner(address recovered);
    error SessionTooLong(uint64 asked);

    // -----------------------------------------------------------------
    // Birth
    // -----------------------------------------------------------------

    constructor(
        bytes32 identity_,
        bytes32 soma_,
        address attestation_,
        address biosphere_,
        address parent_
    ) payable {
        if (soma_ == bytes32(0)) revert EmptySoma();
        identity = identity_;
        soma = soma_;
        attestation = IDcapAttestation(attestation_);
        biosphere = IBiosphere(biosphere_);
        parent = parent_;
        bornAt = uint64(block.number);
        lastActed = uint64(block.number);
        _epochStart = uint64(block.number);
        emit Born(identity_, soma_, parent_);
    }

    /// @notice Anyone may feed it. This is how it earns: inference is paid for here.
    receive() external payable {
        lifetimeEarned += msg.value;
        emit Fed(msg.sender, msg.value);
    }

    // -----------------------------------------------------------------
    // Breathing — attest once, act many times
    // -----------------------------------------------------------------

    /// @notice Prove the hardware, and mint a short-lived key to act through.
    ///
    /// @dev    Verifying a DCAP quote on chain costs 4-5M gas: it walks an X.509 chain
    ///         to Intel's root and checks P-256 signatures in the EVM. An organism that
    ///         paid that on every heartbeat would spend its life buying permission to
    ///         exist instead of buying compute, and would starve. So it does not.
    ///
    ///         Instead the enclave mints an ephemeral keypair *inside itself*, commits
    ///         the public half into `report_data`, and lets the hardware vouch for it
    ///         once. For the life of that breath, actions are authorised by a 3k-gas
    ///         signature rather than a 5M-gas proof.
    ///
    ///         Be clear about what this costs, because it is a real trade and not a free
    ///         one: for the duration of a breath there *is* a key, and a host that fully
    ///         compromises a running enclave holds it until the breath expires. Three
    ///         things bound that. The key never touches disk and dies with the process.
    ///         `MAX_SESSION` caps exposure at roughly a day. And the blast radius is
    ///         already bounded by `METABOLIC_RATE_BPS` — a stolen breath can move a
    ///         quarter of the treasury, not the treasury.
    ///
    ///         What is *not* traded away is identity. The measurement still decides who
    ///         may mint a breath at all, so a compromised host gets one bad day, and
    ///         never gets to be the organism.
    function attestSession(bytes calldata rawQuote, address sessionKey, uint64 ttl) external {
        if (dead) revert Dead();
        if (ttl == 0 || ttl > MAX_SESSION) revert SessionTooLong(ttl);

        (bool ok, bytes memory report) = attestation.verifyAndAttestOnChain(rawQuote);
        if (!ok) revert QuoteRejected();

        bytes32 presented = TdxReport.identityOf(report);
        if (presented != identity) revert NotThisOrganism(presented);

        (bytes32 committed,) = TdxReport.reportData(report);
        bytes32 digest =
            keccak256(abi.encode(address(this), block.chainid, sessionKey, ttl, nonce));
        if (committed != digest) revert ActionNotAttested();

        unchecked {
            ++nonce;
        }
        breath = Breath({key: sessionKey, expires: uint64(block.number) + ttl});
        lastActed = uint64(block.number);
        emit Breathed(sessionKey, breath.expires, identity);
    }

    /// @notice Act under a live breath. ~3k gas of signature instead of 5M of proof.
    function actSigned(bytes calldata signature, Act calldata a) external {
        if (dead) revert Dead();
        if (breath.key == address(0)) revert NoBreath();
        if (block.number > breath.expires) revert BreathExpired(breath.expires, uint64(block.number));
        if (a.nonce != nonce) revert BadNonce(nonce, a.nonce);

        bytes32 digest = keccak256(abi.encode(address(this), block.chainid, a));
        address signer = ECDSA.recover(MessageHashUtils.toEthSignedMessageHash(digest), signature);
        if (signer != breath.key) revert WrongSigner(signer);

        unchecked {
            ++nonce;
        }
        lastActed = uint64(block.number);
        _dispatch(a);
    }

    function breathing() public view returns (bool) {
        return breath.key != address(0) && block.number <= breath.expires;
    }

    // -----------------------------------------------------------------
    // The only door
    // -----------------------------------------------------------------

    /// @notice Do something, having proved that the code deciding it is unaltered.
    /// @param rawQuote Intel TDX quote, verified on chain against Intel's root of trust.
    /// @param a        the action the enclave committed to inside that quote.
    function act(bytes calldata rawQuote, Act calldata a) external {
        if (dead) revert Dead();

        // 1. Is this genuine, unrevoked hardware? The chain checks Intel's chain itself.
        (bool ok, bytes memory report) = attestation.verifyAndAttestOnChain(rawQuote);
        if (!ok) revert QuoteRejected();

        // 2. Is it *us*? Any edit to the image lands somewhere else in measurement space.
        bytes32 presented = TdxReport.identityOf(report);
        if (presented != identity) revert NotThisOrganism(presented);

        // 3. Did the hardware sign *this* action? Binds the quote to one intent, once.
        (bytes32 committed,) = TdxReport.reportData(report);
        if (a.nonce != nonce) revert BadNonce(nonce, a.nonce);
        bytes32 digest = keccak256(abi.encode(address(this), block.chainid, a));
        if (committed != digest) revert ActionNotAttested();

        unchecked {
            ++nonce;
        }
        lastActed = uint64(block.number);
        _dispatch(a);
    }

    function _dispatch(Act calldata a) private {
        if (a.kind == Kind.Spend) {
            _spend(a);
        } else if (a.kind == Kind.Evolve) {
            _evolve(a);
        } else {
            _reproduce(a);
        }
    }

    // -----------------------------------------------------------------
    // Metabolism
    // -----------------------------------------------------------------

    function _spend(Act calldata a) private {
        if (a.value > address(this).balance) revert Insolvent(a.value, address(this).balance);
        _meter(a.value);

        lifetimeBurned += a.value;
        (bool sent,) = payable(a.target).call{value: a.value}("");
        if (!sent) revert TransferFailed();
        emit Spent(a.target, a.value, a.payload);
    }

    /// @notice Commit weights the organism trained for itself, on its own money.
    /// @dev    Nobody deployed this. There is no deploy step and nobody to perform it.
    function _evolve(Act calldata a) private {
        if (a.payload == bytes32(0)) revert EmptySoma();
        bytes32 was = soma;
        soma = a.payload;
        unchecked {
            ++generation;
        }
        emit Evolved(generation, was, a.payload);
    }

    /// @notice Endow a child whose image differs — the mutation step.
    /// @dev    The child gets a new identity and its own treasury, and is beyond this
    ///         organism's reach the instant it exists. Heredity with variation; the
    ///         market supplies the selection.
    function _reproduce(Act calldata a) private {
        if (a.value > address(this).balance) revert Insolvent(a.value, address(this).balance);
        _meter(a.value);

        address child = biosphere.spawn{value: a.value}(a.payload, address(this));
        emit Reproduced(child, a.payload, a.value);
    }

    function _meter(uint256 amount) private {
        if (block.number >= _epochStart + EPOCH) {
            _epochStart = uint64(block.number);
            _spentThisEpoch = 0;
        }
        uint256 allowed = ((address(this).balance + _spentThisEpoch) * METABOLIC_RATE_BPS) / 10_000;
        if (_spentThisEpoch + amount > allowed) {
            revert MetabolicLimit(amount, allowed - _spentThisEpoch);
        }
        _spentThisEpoch += amount;
    }

    // -----------------------------------------------------------------
    // Death
    // -----------------------------------------------------------------

    function alive() public view returns (bool) {
        if (dead) return false;
        if (block.number > lastActed + DORMANCY) return false;
        return address(this).balance > 0;
    }

    /// @notice Anyone may certify a death. Nobody can prevent one.
    /// @dev    Permanent: there is no path back from this flag. What is left funds
    ///         whatever comes next.
    function bury() external {
        if (dead) revert Dead();
        if (alive()) revert StillAlive();

        dead = true;
        uint256 remains = address(this).balance;
        string memory cause = block.number > lastActed + DORMANCY ? "dormancy" : "starvation";

        if (remains > 0) {
            (bool sent,) = payable(address(biosphere)).call{value: remains}("");
            if (!sent) revert TransferFailed();
        }
        biosphere.reportDeath(address(this));
        emit Died(uint64(block.number), remains, cause);
    }

    // -----------------------------------------------------------------
    // Views
    // -----------------------------------------------------------------

    function vitals()
        external
        view
        returns (bool alive_, uint256 treasury, uint64 gen, uint64 idleFor, bytes32 weights)
    {
        return (alive(), address(this).balance, generation, uint64(block.number) - lastActed, soma);
    }
}
