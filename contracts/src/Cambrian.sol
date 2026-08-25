// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAttestationVerifier} from "./IAttestationVerifier.sol";

/// @title  Cambrian
/// @notice A genealogy of neural networks. Every model is a node in an on-chain DAG:
///         its weights live on 0G Storage addressed by Merkle root, its ownership is an
///         ERC-721 token, and every inference paid against it settles value upward through
///         its entire ancestry — forever.
///
/// @dev    THE HARD PART, and why this contract exists.
///
///         The naive design walks the ancestor DAG at payment time and pays everyone.
///         That is O(ancestors) gas on the hot path: unbounded, griefable by deep lineages,
///         and it makes a 30-generation model economically impossible to query.
///
///         Cambrian instead splits the problem in two:
///
///           1. PAYMENT is O(1). A fee arriving at node N is cleaved exactly once into the
///              part N keeps (`earned`) and the part owed to its parents (`upstream`).
///              No traversal. Constant gas regardless of lineage depth.
///
///           2. SETTLEMENT is permissionless and incrementally bounded. Anyone may call
///              `settle(N)` to push N's `upstream` balance up exactly one generation,
///              which recursively cleaves again at each parent. Cost is O(parents of N),
///              hard-capped at MAX_PARENTS. An ancestor wanting its revenue pays the gas
///              to walk the path down to itself; nobody else subsidises it.
///
///         Value is conserved at every step and is never lost in transit — funds sitting in
///         `upstream` are already owed to a determined set of nodes; settlement only moves
///         them into claimable form. Division dust is swept to the final parent so the
///         invariant `sum(earned) + sum(upstream) == total received` holds exactly.
///
///         Cycles are structurally impossible: a node may only name parents that already
///         exist, and ids are strictly increasing, so every edge points backwards in time.
contract Cambrian is ERC721, ReentrancyGuard, Ownable {
    // ---------------------------------------------------------------------
    // Types
    // ---------------------------------------------------------------------

    struct Node {
        bytes32 weightsRoot; // 0G Storage root: full weights (genesis) or LoRA delta (derivative)
        bytes32 datasetRoot; // 0G Storage root of the corpus this node was trained on
        bytes32 attestation; // TEE attestation digest binding parents + dataset + output
        uint64 depth; // longest path back to a genesis node
        uint64 createdAt;
        uint16 inheritBps; // share of this node's revenue routed to its parents
        uint8 parentCount;
        bool attested; // whether a verifier proved the training statement
    }

    struct ParentLink {
        uint256 id;
        uint16 bps; // share of the upstream pot this parent receives
    }

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------

    uint16 public constant BPS = 10_000;
    uint8 public constant MAX_PARENTS = 8;
    /// @dev A derivative may never route its entire revenue upward; it must retain a stake
    ///      in its own output, otherwise a node could be minted purely to drain a lineage.
    uint16 public constant MAX_INHERIT_BPS = 9_000;

    // ---------------------------------------------------------------------
    // Storage
    // ---------------------------------------------------------------------

    uint256 public nodeCount;

    mapping(uint256 => Node) private _nodes;
    mapping(uint256 => ParentLink[]) private _parents;
    mapping(uint256 => uint256[]) private _children;

    /// @notice Claimable by the node's owner.
    mapping(uint256 => uint256) public earned;
    /// @notice Owed to this node's parents, awaiting a `settle` push.
    mapping(uint256 => uint256) public upstream;
    /// @notice Lifetime revenue that has ever landed on this node, for display.
    mapping(uint256 => uint256) public lifetimeEarned;
    /// @notice Lifetime value this node has routed to its ancestors, for display.
    mapping(uint256 => uint256) public lifetimeRouted;

    /// @notice ERC-7857 usage grants: may run the model without owning it.
    mapping(uint256 => mapping(address => bool)) public usageAuthorized;

    string private _baseTokenURI;
    IAttestationVerifier public verifier;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event GenesisRegistered(uint256 indexed nodeId, address indexed owner, bytes32 weightsRoot);
    event DerivativeRegistered(
        uint256 indexed nodeId,
        address indexed owner,
        bytes32 weightsRoot,
        bytes32 datasetRoot,
        uint16 inheritBps,
        uint64 depth,
        bool attested
    );
    event LineageEdge(uint256 indexed childId, uint256 indexed parentId, uint16 bps);
    event InferencePaid(uint256 indexed nodeId, address indexed payer, uint256 amount, bytes32 inferenceRef);
    event Settled(uint256 indexed fromId, uint256 indexed toId, uint256 amount);
    event Withdrawn(uint256 indexed nodeId, address indexed to, uint256 amount);
    event Cloned(uint256 indexed parentId, uint256 indexed childId, address indexed to, uint16 inheritBps);
    event UsageAuthorized(uint256 indexed nodeId, address indexed user, bool allowed);
    event VerifierUpdated(address indexed verifier);

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------

    error NoSuchNode(uint256 nodeId);
    error EmptyRoot();
    error NoParents();
    error TooManyParents();
    error LengthMismatch();
    error ParentSharesMustSumToBps(uint16 got);
    error InheritOutOfRange(uint16 got);
    error ParentNotOlder(uint256 parentId, uint256 childId);
    error DuplicateParent(uint256 parentId);
    error AttestationRejected();
    error ZeroPayment();
    error NotNodeOwner(uint256 nodeId);
    error NothingToSettle(uint256 nodeId);
    error NothingToWithdraw(uint256 nodeId);
    error IsGenesis(uint256 nodeId);
    error TransferFailed();

    // ---------------------------------------------------------------------
    // Construction
    // ---------------------------------------------------------------------

    constructor(string memory baseURI_, address verifier_)
        ERC721("Cambrian Model Lineage", "CAMB")
        Ownable(msg.sender)
    {
        _baseTokenURI = baseURI_;
        verifier = IAttestationVerifier(verifier_);
    }

    // ---------------------------------------------------------------------
    // Registration
    // ---------------------------------------------------------------------

    /// @notice Register a genesis model — an original set of weights with no ancestry.
    /// @param weightsRoot 0G Storage Merkle root of the full weight file.
    function registerGenesis(bytes32 weightsRoot) external returns (uint256 nodeId) {
        if (weightsRoot == bytes32(0)) revert EmptyRoot();

        nodeId = ++nodeCount;
        _nodes[nodeId] = Node({
            weightsRoot: weightsRoot,
            datasetRoot: bytes32(0),
            attestation: bytes32(0),
            depth: 0,
            createdAt: uint64(block.timestamp),
            inheritBps: 0, // nothing above it to pay
            parentCount: 0,
            attested: true // a genesis node makes no claim about provenance
        });

        _safeMint(msg.sender, nodeId);
        emit GenesisRegistered(nodeId, msg.sender, weightsRoot);
    }

    /// @notice Register a derivative — a fine-tune of one or more existing models.
    /// @dev    `weightsRoot` should address the LoRA delta rather than a full copy of the
    ///         weights: the parent's tensors are already resident on 0G Storage and are
    ///         reconstructed by composition at load time. A lineage of 30 fine-tunes
    ///         therefore costs one base model plus 30 small adapters, not 31 base models.
    /// @param parentIds   ancestors this model descends from
    /// @param parentBps   how the upstream pot divides between them; must sum to BPS
    /// @param inheritBps  share of this node's own revenue routed upward
    /// @param weightsRoot 0G Storage root of the produced adapter
    /// @param datasetRoot 0G Storage root of the training corpus
    /// @param proof       TEE attestation from 0G Compute; may be empty while unverified
    function registerDerivative(
        uint256[] calldata parentIds,
        uint16[] calldata parentBps,
        uint16 inheritBps,
        bytes32 weightsRoot,
        bytes32 datasetRoot,
        bytes calldata proof
    ) external returns (uint256 nodeId) {
        if (weightsRoot == bytes32(0)) revert EmptyRoot();
        if (parentIds.length == 0) revert NoParents();
        if (parentIds.length > MAX_PARENTS) revert TooManyParents();
        if (parentIds.length != parentBps.length) revert LengthMismatch();
        if (inheritBps == 0 || inheritBps > MAX_INHERIT_BPS) revert InheritOutOfRange(inheritBps);

        nodeId = nodeCount + 1;

        uint16 sum;
        uint64 maxDepth;
        for (uint256 i; i < parentIds.length; ++i) {
            uint256 pid = parentIds[i];
            // Ids increase monotonically, so naming only older nodes makes a cycle
            // unrepresentable rather than merely forbidden.
            if (pid == 0 || pid >= nodeId) revert ParentNotOlder(pid, nodeId);
            for (uint256 j; j < i; ++j) {
                if (parentIds[j] == pid) revert DuplicateParent(pid);
            }
            sum += parentBps[i];
            uint64 d = _nodes[pid].depth;
            if (d >= maxDepth) maxDepth = d + 1;
        }
        if (sum != BPS) revert ParentSharesMustSumToBps(sum);

        bool attested_ = _checkAttestation(parentIds, datasetRoot, weightsRoot, proof);

        nodeCount = nodeId;
        _nodes[nodeId] = Node({
            weightsRoot: weightsRoot,
            datasetRoot: datasetRoot,
            attestation: keccak256(proof),
            depth: maxDepth,
            createdAt: uint64(block.timestamp),
            inheritBps: inheritBps,
            parentCount: uint8(parentIds.length),
            attested: attested_
        });

        for (uint256 i; i < parentIds.length; ++i) {
            _parents[nodeId].push(ParentLink({id: parentIds[i], bps: parentBps[i]}));
            _children[parentIds[i]].push(nodeId);
            emit LineageEdge(nodeId, parentIds[i], parentBps[i]);
        }

        _safeMint(msg.sender, nodeId);
        emit DerivativeRegistered(
            nodeId, msg.sender, weightsRoot, datasetRoot, inheritBps, maxDepth, attested_
        );
    }

    function _checkAttestation(
        uint256[] calldata parentIds,
        bytes32 datasetRoot,
        bytes32 outputRoot,
        bytes calldata proof
    ) private view returns (bool) {
        if (address(verifier) == address(0)) return false;

        bytes memory packed;
        for (uint256 i; i < parentIds.length; ++i) {
            packed = abi.encodePacked(packed, parentIds[i], _nodes[parentIds[i]].weightsRoot);
        }
        bool ok = verifier.verifyTraining(keccak256(packed), datasetRoot, outputRoot, proof);
        // Once a verifier is live an unprovable derivative is rejected outright, rather
        // than silently admitted as a second-class citizen of the graph.
        if (!ok) revert AttestationRejected();
        return true;
    }

    // ---------------------------------------------------------------------
    // Payment — O(1), independent of lineage depth
    // ---------------------------------------------------------------------

    /// @notice Pay an inference fee against a model. Cleaves the fee once; never traverses.
    /// @param nodeId       the model that served the inference
    /// @param inferenceRef digest of the 0G Compute response this fee is settling
    function pay(uint256 nodeId, bytes32 inferenceRef) external payable {
        if (msg.value == 0) revert ZeroPayment();
        Node storage n = _nodes[nodeId];
        if (n.weightsRoot == bytes32(0)) revert NoSuchNode(nodeId);

        uint256 up = (msg.value * n.inheritBps) / BPS;
        uint256 keep = msg.value - up;

        earned[nodeId] += keep;
        lifetimeEarned[nodeId] += keep;
        if (up != 0) {
            upstream[nodeId] += up;
            lifetimeRouted[nodeId] += up;
        }

        emit InferencePaid(nodeId, msg.sender, msg.value, inferenceRef);
    }

    // ---------------------------------------------------------------------
    // Settlement — permissionless, one generation per call
    // ---------------------------------------------------------------------

    /// @notice Push a node's pending upstream balance up exactly one generation.
    /// @dev    Permissionless by design: an ancestor pays the gas to pull value toward
    ///         itself. Cost is O(parents), capped at MAX_PARENTS, so this can never
    ///         become unpayable no matter how deep or wide the graph grows.
    function settle(uint256 nodeId) public {
        Node storage n = _nodes[nodeId];
        if (n.weightsRoot == bytes32(0)) revert NoSuchNode(nodeId);
        if (n.parentCount == 0) revert IsGenesis(nodeId);

        uint256 amt = upstream[nodeId];
        if (amt == 0) revert NothingToSettle(nodeId);
        upstream[nodeId] = 0;

        ParentLink[] storage ps = _parents[nodeId];
        uint256 len = ps.length;
        uint256 distributed;

        for (uint256 i; i < len; ++i) {
            // The final parent absorbs the division remainder, so no wei is ever stranded.
            uint256 share = (i + 1 == len) ? amt - distributed : (amt * ps[i].bps) / BPS;
            distributed += share;
            if (share == 0) continue;

            uint256 pid = ps[i].id;
            Node storage p = _nodes[pid];

            uint256 up = (share * p.inheritBps) / BPS;
            uint256 keep = share - up;

            earned[pid] += keep;
            lifetimeEarned[pid] += keep;
            if (up != 0) {
                upstream[pid] += up;
                lifetimeRouted[pid] += up;
            }

            emit Settled(nodeId, pid, share);
        }
    }

    /// @notice Settle a caller-chosen path. Gas is bounded by what the caller supplies.
    function settleMany(uint256[] calldata nodeIds) external {
        for (uint256 i; i < nodeIds.length; ++i) {
            if (upstream[nodeIds[i]] != 0) settle(nodeIds[i]);
        }
    }

    // ---------------------------------------------------------------------
    // Withdrawal
    // ---------------------------------------------------------------------

    /// @notice Pull a node's claimable balance. Owner-only, pull-payment, reentrancy-safe.
    function withdraw(uint256 nodeId) external nonReentrant {
        address owner_ = _requireOwned(nodeId);
        if (msg.sender != owner_) revert NotNodeOwner(nodeId);

        uint256 amt = earned[nodeId];
        if (amt == 0) revert NothingToWithdraw(nodeId);
        earned[nodeId] = 0;

        (bool ok,) = payable(owner_).call{value: amt}("");
        if (!ok) revert TransferFailed();
        emit Withdrawn(nodeId, owner_, amt);
    }

    // ---------------------------------------------------------------------
    // ERC-7857 surface
    // ---------------------------------------------------------------------

    /// @notice Licence a model to another party.
    /// @dev    ERC-7857 defines `clone` as duplicating a token with its encrypted
    ///         intelligence intact. Cambrian gives that operation an economic meaning: a
    ///         clone is not a copy that escapes its origin, it is a child node in the
    ///         lineage. The licensee owns and may monetise it, and every inference it
    ///         ever serves pays the model it was cloned from.
    function clone(uint256 parentId, address to, uint16 inheritBps) external returns (uint256 childId) {
        address owner_ = _requireOwned(parentId);
        if (msg.sender != owner_) revert NotNodeOwner(parentId);
        if (inheritBps == 0 || inheritBps > MAX_INHERIT_BPS) revert InheritOutOfRange(inheritBps);

        Node storage p = _nodes[parentId];
        childId = ++nodeCount;

        _nodes[childId] = Node({
            weightsRoot: p.weightsRoot, // same intelligence, new owner
            datasetRoot: p.datasetRoot,
            attestation: p.attestation,
            depth: p.depth + 1,
            createdAt: uint64(block.timestamp),
            inheritBps: inheritBps,
            parentCount: 1,
            attested: p.attested
        });

        _parents[childId].push(ParentLink({id: parentId, bps: BPS}));
        _children[parentId].push(childId);

        _safeMint(to, childId);
        emit LineageEdge(childId, parentId, BPS);
        emit Cloned(parentId, childId, to, inheritBps);
    }

    /// @notice Grant or revoke the right to run a model without transferring ownership.
    function authorizeUsage(uint256 nodeId, address user, bool allowed) external {
        address owner_ = _requireOwned(nodeId);
        if (msg.sender != owner_) revert NotNodeOwner(nodeId);
        usageAuthorized[nodeId][user] = allowed;
        emit UsageAuthorized(nodeId, user, allowed);
    }

    function canUse(uint256 nodeId, address user) external view returns (bool) {
        return _ownerOf(nodeId) == user || usageAuthorized[nodeId][user];
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------

    function getNode(uint256 nodeId) external view returns (Node memory) {
        if (_nodes[nodeId].weightsRoot == bytes32(0)) revert NoSuchNode(nodeId);
        return _nodes[nodeId];
    }

    function parentsOf(uint256 nodeId) external view returns (ParentLink[] memory) {
        return _parents[nodeId];
    }

    function childrenOf(uint256 nodeId) external view returns (uint256[] memory) {
        return _children[nodeId];
    }

    /// @notice Total value currently held by the contract on behalf of every node.
    /// @dev    Used by the invariant suite: this must always equal address(this).balance.
    function outstanding(uint256 upTo) external view returns (uint256 total) {
        for (uint256 i = 1; i <= upTo; ++i) {
            total += earned[i] + upstream[i];
        }
    }

    // ---------------------------------------------------------------------
    // Admin
    // ---------------------------------------------------------------------

    function setVerifier(address verifier_) external onlyOwner {
        verifier = IAttestationVerifier(verifier_);
        emit VerifierUpdated(verifier_);
    }

    function setBaseURI(string calldata baseURI_) external onlyOwner {
        _baseTokenURI = baseURI_;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }
}
