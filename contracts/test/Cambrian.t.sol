// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Cambrian} from "../src/Cambrian.sol";

contract CambrianTest is Test {
    Cambrian internal c;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal user = address(0x5E2);

    bytes32 constant W0 = keccak256("genesis-weights");
    bytes32 constant D0 = keccak256("dataset");

    function setUp() public {
        c = new Cambrian("ipfs://base/", address(0));
        vm.deal(user, 1_000 ether);
    }

    // -----------------------------------------------------------------
    // helpers
    // -----------------------------------------------------------------

    function _genesis(address who) internal returns (uint256 id) {
        vm.prank(who);
        id = c.registerGenesis(W0);
    }

    function _child(address who, uint256 parent, uint16 inheritBps) internal returns (uint256 id) {
        uint256[] memory ps = new uint256[](1);
        uint16[] memory bps = new uint16[](1);
        ps[0] = parent;
        bps[0] = 10_000;
        vm.prank(who);
        id = c.registerDerivative(ps, bps, inheritBps, keccak256(abi.encode("lora", parent, who)), D0, "");
    }

    /// @dev Walks a chain from the deepest node upward, settling every generation.
    function _settleChain(uint256[] memory chain) internal {
        for (uint256 i = chain.length; i > 0; --i) {
            uint256 id = chain[i - 1];
            if (c.upstream(id) != 0) c.settle(id);
        }
    }

    // -----------------------------------------------------------------
    // structure
    // -----------------------------------------------------------------

    function test_genesis_hasNoAncestryAndKeepsEverything() public {
        uint256 g = _genesis(alice);
        assertEq(c.ownerOf(g), alice);
        assertEq(c.getNode(g).depth, 0);
        assertEq(c.getNode(g).inheritBps, 0);

        vm.prank(user);
        c.pay{value: 1 ether}(g, bytes32(0));

        assertEq(c.earned(g), 1 ether, "genesis keeps the whole fee");
        assertEq(c.upstream(g), 0);
    }

    function test_derivativeRecordsLineageAndDepth() public {
        uint256 g = _genesis(alice);
        uint256 d = _child(bob, g, 2_000);

        assertEq(c.ownerOf(d), bob);
        assertEq(c.getNode(d).depth, 1);
        assertEq(c.parentsOf(d).length, 1);
        assertEq(c.parentsOf(d)[0].id, g);
        assertEq(c.childrenOf(g)[0], d);
    }

    function test_cyclesAreUnrepresentable() public {
        uint256 g = _genesis(alice);
        uint256[] memory ps = new uint256[](1);
        uint16[] memory bps = new uint16[](1);
        bps[0] = 10_000;

        // naming a future id
        ps[0] = g + 5;
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Cambrian.ParentNotOlder.selector, g + 5, g + 1));
        c.registerDerivative(ps, bps, 2_000, W0, D0, "");

        // naming itself
        ps[0] = g + 1;
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Cambrian.ParentNotOlder.selector, g + 1, g + 1));
        c.registerDerivative(ps, bps, 2_000, W0, D0, "");
    }

    function test_rejectsMalformedParentShares() public {
        uint256 g = _genesis(alice);
        uint256[] memory ps = new uint256[](1);
        uint16[] memory bps = new uint16[](1);
        ps[0] = g;
        bps[0] = 9_999; // does not sum to BPS

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Cambrian.ParentSharesMustSumToBps.selector, uint16(9_999)));
        c.registerDerivative(ps, bps, 2_000, W0, D0, "");
    }

    function test_cannotRouteAllRevenueUpward() public {
        uint256 g = _genesis(alice);
        uint256[] memory ps = new uint256[](1);
        uint16[] memory bps = new uint16[](1);
        ps[0] = g;
        bps[0] = 10_000;

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Cambrian.InheritOutOfRange.selector, uint16(9_001)));
        c.registerDerivative(ps, bps, 9_001, W0, D0, "");
    }

    // -----------------------------------------------------------------
    // the royalty engine
    // -----------------------------------------------------------------

    function test_feeCleavesOnceAtPaymentTime() public {
        uint256 g = _genesis(alice);
        uint256 d = _child(bob, g, 2_500); // routes 25% upward

        vm.prank(user);
        c.pay{value: 1 ether}(d, bytes32(0));

        assertEq(c.earned(d), 0.75 ether);
        assertEq(c.upstream(d), 0.25 ether);
        assertEq(c.earned(g), 0, "parent is not paid until settlement");

        c.settle(d);

        assertEq(c.upstream(d), 0);
        assertEq(c.earned(g), 0.25 ether, "settlement moved value up one generation");
    }

    function test_valueReachesEveryAncestorOfADeepLineage() public {
        uint256 depth = 12;
        uint256[] memory chain = new uint256[](depth);
        chain[0] = _genesis(alice);
        for (uint256 i = 1; i < depth; ++i) {
            chain[i] = _child(bob, chain[i - 1], 5_000); // half flows up at every hop
        }

        vm.prank(user);
        c.pay{value: 1 ether}(chain[depth - 1], bytes32(0));
        _settleChain(chain);

        uint256 total;
        for (uint256 i; i < depth; ++i) {
            assertGt(c.earned(chain[i]), 0, "every ancestor received value");
            total += c.earned(chain[i]);
        }
        assertEq(total, 1 ether, "value is conserved exactly across the whole lineage");
    }

    /// @dev The claim the whole design rests on: payment cost does not grow with ancestry.
    ///      Compared like with like — two derivatives, one 1 generation deep and one 49 —
    ///      so the only variable is depth. A traversal-based royalty split would be ~49x
    ///      apart here.
    function test_paymentGasIsIndependentOfLineageDepth() public {
        uint256[] memory chain = new uint256[](50);
        chain[0] = _genesis(alice);
        for (uint256 i = 1; i < 50; ++i) {
            chain[i] = _child(bob, chain[i - 1], 3_000);
        }

        // Warm both nodes' slots first, so we measure the algorithm and not cold-storage noise.
        vm.startPrank(user);
        c.pay{value: 1 wei}(chain[1], bytes32(0));
        c.pay{value: 1 wei}(chain[49], bytes32(0));

        uint256 a = gasleft();
        c.pay{value: 1 ether}(chain[1], bytes32(0));
        uint256 gasShallow = a - gasleft();

        uint256 b = gasleft();
        c.pay{value: 1 ether}(chain[49], bytes32(0));
        uint256 gasDeep = b - gasleft();
        vm.stopPrank();

        console.log("pay() at depth  1:", gasShallow);
        console.log("pay() at depth 49:", gasDeep);
        console.log("delta:", gasDeep > gasShallow ? gasDeep - gasShallow : gasShallow - gasDeep);

        uint256 delta = gasDeep > gasShallow ? gasDeep - gasShallow : gasShallow - gasDeep;
        assertLt(delta, 250, "payment cost is flat in lineage depth");
    }

    function test_settlementCostIsBoundedByParentCountNotGraphSize() public {
        uint256[] memory chain = new uint256[](40);
        chain[0] = _genesis(alice);
        for (uint256 i = 1; i < 40; ++i) {
            chain[i] = _child(bob, chain[i - 1], 4_000);
        }

        vm.prank(user);
        c.pay{value: 10 ether}(chain[39], bytes32(0));

        uint256 g0 = gasleft();
        c.settle(chain[39]);
        uint256 used = g0 - gasleft();
        console.log("settle() one generation, 40-deep graph:", used);
        assertLt(used, 120_000, "one generation is a constant-size step");
    }

    function test_mergeSplitsAcrossMultipleParents() public {
        uint256 p1 = _genesis(alice);
        uint256 p2 = _genesis(bob);

        uint256[] memory ps = new uint256[](2);
        uint16[] memory bps = new uint16[](2);
        ps[0] = p1;
        ps[1] = p2;
        bps[0] = 7_000;
        bps[1] = 3_000;

        vm.prank(bob);
        uint256 merged = c.registerDerivative(ps, bps, 5_000, keccak256("merged"), D0, "");

        vm.prank(user);
        c.pay{value: 1 ether}(merged, bytes32(0));
        c.settle(merged);

        assertEq(c.earned(merged), 0.5 ether);
        assertEq(c.earned(p1), 0.35 ether);
        assertEq(c.earned(p2), 0.15 ether);
    }

    function test_noWeiIsStrandedByRounding() public {
        uint256 p1 = _genesis(alice);
        uint256 p2 = _genesis(bob);

        uint256[] memory ps = new uint256[](2);
        uint16[] memory bps = new uint16[](2);
        ps[0] = p1;
        ps[1] = p2;
        bps[0] = 3_333;
        bps[1] = 6_667;

        vm.prank(bob);
        uint256 m = c.registerDerivative(ps, bps, 3_333, keccak256("odd"), D0, "");

        uint256 odd = 1 ether + 7 wei;
        vm.prank(user);
        c.pay{value: odd}(m, bytes32(0));
        c.settle(m);

        assertEq(c.earned(m) + c.earned(p1) + c.earned(p2), odd, "not one wei lost to rounding");
    }

    // -----------------------------------------------------------------
    // ERC-7857
    // -----------------------------------------------------------------

    function test_cloneCreatesALicensedDescendantThatPaysItsOrigin() public {
        uint256 g = _genesis(alice);

        vm.prank(alice);
        uint256 licensed = c.clone(g, bob, 3_000);

        assertEq(c.ownerOf(licensed), bob, "licensee owns the clone");
        assertEq(c.getNode(licensed).weightsRoot, c.getNode(g).weightsRoot, "intelligence intact");
        assertEq(c.parentsOf(licensed)[0].id, g, "but it never escapes its lineage");

        vm.prank(user);
        c.pay{value: 1 ether}(licensed, bytes32(0));
        c.settle(licensed);

        assertEq(c.earned(licensed), 0.7 ether);
        assertEq(c.earned(g), 0.3 ether, "the origin is paid for its clone's work");
    }

    function test_usageGrantsDoNotTransferOwnership() public {
        uint256 g = _genesis(alice);
        assertFalse(c.canUse(g, bob));

        vm.prank(alice);
        c.authorizeUsage(g, bob, true);

        assertTrue(c.canUse(g, bob));
        assertEq(c.ownerOf(g), alice);
    }

    // -----------------------------------------------------------------
    // withdrawal
    // -----------------------------------------------------------------

    function test_onlyOwnerWithdraws() public {
        uint256 g = _genesis(alice);
        vm.prank(user);
        c.pay{value: 1 ether}(g, bytes32(0));

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Cambrian.NotNodeOwner.selector, g));
        c.withdraw(g);

        uint256 before = alice.balance;
        vm.prank(alice);
        c.withdraw(g);
        assertEq(alice.balance - before, 1 ether);
        assertEq(c.earned(g), 0);
    }

    // -----------------------------------------------------------------
    // conservation of value, under fuzzing
    // -----------------------------------------------------------------

    function testFuzz_contractNeverOwesMoreThanItHolds(
        uint16 inherit1,
        uint16 inherit2,
        uint96 amount
    ) public {
        inherit1 = uint16(bound(inherit1, 1, 9_000));
        inherit2 = uint16(bound(inherit2, 1, 9_000));
        amount = uint96(bound(amount, 1, 100 ether));

        uint256[] memory chain = new uint256[](3);
        chain[0] = _genesis(alice);
        chain[1] = _child(bob, chain[0], inherit1);
        chain[2] = _child(bob, chain[1], inherit2);

        vm.deal(user, amount);
        vm.prank(user);
        c.pay{value: amount}(chain[2], bytes32(0));
        _settleChain(chain);

        assertEq(c.outstanding(c.nodeCount()), address(c).balance, "books balance against real funds");
        assertEq(
            c.earned(chain[0]) + c.earned(chain[1]) + c.earned(chain[2]),
            amount,
            "every wei landed on some ancestor"
        );
    }
}
