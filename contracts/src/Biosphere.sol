// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Organism} from "./Organism.sol";

/// @title  Biosphere
/// @notice The population, the fossil record, and the estate of the dead.
///
/// @dev    One self-owning machine is a curiosity. What makes it a system is that there
///         are many, that they are unequal, and that the unsuccessful ones actually go
///         away — permanently, taking their capital out of their own hands.
///
///         Nothing here decides which organisms deserve to live. There is no committee,
///         no scoring function, no governance token, no vote. Selection is done entirely
///         by whether strangers are willing to pay an organism for its inference. An
///         organism that earns, buys compute and keeps thinking. One that does not,
///         runs out, stops, and is buried by whoever cares to send the transaction.
///
///         Its estate does not evaporate. It flows to its nearest living ancestor, and
///         if the whole line is extinct, to a commons that anyone may draw on to seed
///         something new. Capital keeps moving toward whatever is still working, which
///         is the only definition of fitness this contract knows.
contract Biosphere {
    struct Record {
        address parent;
        uint64 bornAt;
        uint64 diedAt;
        bytes32 identity;
        bool exists;
    }

    mapping(address => Record) public record;
    address[] public census;

    uint256 public living;
    uint256 public deaths;
    /// @notice Estate of extinct lines. Anyone may draw on it to seed a new organism.
    uint256 public commons;

    event Spawned(address indexed organism, address indexed parent, bytes32 identity, uint256 endowment);
    event Buried(address indexed organism, uint64 atBlock);
    event Inherited(address indexed from, address indexed to, uint256 amount);
    event Escheated(address indexed from, uint256 amount);
    event Seeded(address indexed organism, uint256 drawn);

    error UnknownOrganism(address who);
    error AlreadyBuried(address who);
    error NotTheOrganism();
    error EndowmentTooSmall(uint256 sent, uint256 required);
    error TransferFailed();

    address public immutable attestation;
    /// @notice The quote verifier every organism spawned here will pin.
    /// @dev    Carried through to each Organism so that swapping the entrypoint's
    ///         verifier stops the population rather than subverting it.
    address public immutable quoteVerifier;

    constructor(address attestation_, address quoteVerifier_) {
        attestation = attestation_;
        quoteVerifier = quoteVerifier_;
    }

    /// @notice Bring an organism into existence. Callable by anyone, or by an organism
    ///         reproducing — the biosphere does not distinguish, because nothing about
    ///         parentage should confer authority over the child.
    /// @dev Minimum endowment. Spawning is permissionless by design — nothing about
    ///      parentage should confer authority — but a free `spawn` lets anyone inflate
    ///      the census indefinitely, so a newborn must at least be able to live briefly.
    uint256 public constant MIN_ENDOWMENT = 0.01 ether;

    /// @notice A child begins life with its parent's weights.
    /// @dev    Previously every child's soma was `keccak("genesis-soma" ‖ its own id)` —
    ///         a hash of itself, addressing nothing on 0G Storage. Nothing was inherited
    ///         and a newborn could not load weights at all, which made the claimed
    ///         heredity a parent pointer and no more. A child now starts from the
    ///         parent's soma and diverges by training, which is what descent means.
    function _inheritedSoma(address parent, bytes32 identity) private view returns (bytes32) {
        if (parent != address(0) && record[parent].exists) {
            bytes32 inherited = Organism(payable(parent)).soma();
            if (inherited != bytes32(0)) return inherited;
        }
        return keccak256(abi.encodePacked("genesis-soma", identity));
    }

    function spawn(bytes32 identity, address parent) public payable returns (address) {
        if (msg.value < MIN_ENDOWMENT) revert EndowmentTooSmall(msg.value, MIN_ENDOWMENT);
        Organism o = new Organism{value: msg.value}(
            identity,
            _inheritedSoma(parent, identity),
            attestation,
            quoteVerifier,
            address(this),
            parent
        );

        record[address(o)] = Record({
            parent: parent,
            bornAt: uint64(block.number),
            diedAt: 0,
            identity: identity,
            exists: true
        });
        census.push(address(o));
        unchecked {
            ++living;
        }

        emit Spawned(address(o), parent, identity, msg.value);
        return address(o);
    }

    /// @dev `seedFromCommons` used to live here: permissionless, with a caller-chosen
    ///      identity and amount. That let anyone with any TDX box measure their own image
    ///      and take the entire commons into an organism they controlled — the estate of
    ///      every extinct line, claimable by whoever called first. A test performed
    ///      exactly that drain and described it as a feature.
    ///
    ///      It is removed rather than patched, because no gate we can write here is
    ///      honest yet: the commons should flow toward demonstrated fitness, and this
    ///      contract has no non-gameable measure of that. Until it does, the commons
    ///      accrues and stays put. Dead capital is better than a faucet for whoever
    ///      polls hardest.

    function spawnWith(bytes32 identity, address parent, uint256 amount) private returns (address) {
        Organism o = new Organism{value: amount}(
            identity,
            keccak256(abi.encodePacked("genesis-soma", identity)),
            attestation,
            quoteVerifier,
            address(this),
            parent
        );
        record[address(o)] = Record({
            parent: parent,
            bornAt: uint64(block.number),
            diedAt: 0,
            identity: identity,
            exists: true
        });
        census.push(address(o));
        unchecked {
            ++living;
        }
        emit Spawned(address(o), parent, identity, amount);
        return address(o);
    }

    /// @notice Called by an organism as it is buried. Its remains have already arrived.
    /// @dev Payable, and the estate is `msg.value` rather than a balance difference.
    ///      Inferring it as `address(this).balance - commons` attributed any stray
    ///      transfer — this contract has a bare `receive()` — to the next heir.
    function reportDeath(address organism) external payable {
        if (msg.sender != organism) revert NotTheOrganism();
        Record storage r = record[organism];
        if (!r.exists) revert UnknownOrganism(organism);
        if (r.diedAt != 0) revert AlreadyBuried(organism);

        r.diedAt = uint64(block.number);
        unchecked {
            ++deaths;
            if (living > 0) --living;
        }
        emit Buried(organism, uint64(block.number));

        uint256 estate = msg.value;
        if (estate == 0) return;

        address heir = _nearestLivingAncestor(organism);
        if (heir == address(0)) {
            commons += estate;
            emit Escheated(organism, estate);
        } else {
            (bool sent,) = payable(heir).call{value: estate}("");
            if (!sent) revert TransferFailed();
            emit Inherited(organism, heir, estate);
        }
    }

    /// @dev Walks the ancestry off the hot path of any payment, bounded by a hard cap so
    ///      a pathological chain can never make a burial unaffordable.
    function _nearestLivingAncestor(address organism) private view returns (address) {
        address cur = record[organism].parent;
        for (uint256 i; i < 32; ++i) {
            if (cur == address(0)) return address(0);
            if (record[cur].exists && record[cur].diedAt == 0 && Organism(payable(cur)).alive()) {
                return cur;
            }
            cur = record[cur].parent;
        }
        return address(0);
    }

    function populationSize() external view returns (uint256) {
        return census.length;
    }

    receive() external payable {}
}
