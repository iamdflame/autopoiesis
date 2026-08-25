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
    error NothingInCommons();
    error TransferFailed();

    address public immutable attestation;

    constructor(address attestation_) {
        attestation = attestation_;
    }

    /// @notice Bring an organism into existence. Callable by anyone, or by an organism
    ///         reproducing — the biosphere does not distinguish, because nothing about
    ///         parentage should confer authority over the child.
    function spawn(bytes32 identity, address parent) public payable returns (address) {
        Organism o = new Organism{value: msg.value}(
            identity,
            keccak256(abi.encodePacked("genesis-soma", identity)),
            attestation,
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

    /// @notice Draw the commons down to seed a new line when an old one is extinct.
    function seedFromCommons(bytes32 identity, uint256 amount) external returns (address) {
        if (amount == 0 || amount > commons) revert NothingInCommons();
        commons -= amount;
        address o = spawnWith(identity, address(0), amount);
        emit Seeded(o, amount);
        return o;
    }

    function spawnWith(bytes32 identity, address parent, uint256 amount) private returns (address) {
        Organism o = new Organism{value: amount}(
            identity,
            keccak256(abi.encodePacked("genesis-soma", identity)),
            attestation,
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
    function reportDeath(address organism) external {
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

        uint256 estate = address(this).balance - commons;
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
