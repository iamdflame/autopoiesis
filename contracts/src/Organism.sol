// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

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
