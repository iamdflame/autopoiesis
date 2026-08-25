NET ?= testnet
.PHONY: help preflight test dcap biosphere verify clean

help:
	@echo "  make preflight NET=testnet   check everything, print exactly what to fund"
	@echo "  make test                    40 contract tests"
	@echo "  make dcap      NET=testnet   bring on-chain Intel DCAP attestation to 0G"
	@echo "  make biosphere NET=testnet   deploy Biosphere + seed the genesis organism"
	@echo "  make verify    NET=testnet   confirm what is live on chain"
	@echo
	@echo "  NET=testnet (chain 16602, free)  |  NET=mainnet (chain 16661, required for Wave 3)"

preflight:
	@NET=$(NET) ./scripts/preflight.sh

test:
	@forge test

dcap:
	@NET=$(NET) ./scripts/deploy-dcap.sh

biosphere:
	@set -a; . ./deployments/$(NET).env; set +a; \
	if [ -z "$$DCAP_VERIFIER" ]; then echo "DCAP_VERIFIER not set — run: make dcap NET=$(NET)"; exit 1; fi; \
	if [ -z "$$GENESIS_IDENTITY" ]; then echo "GENESIS_IDENTITY not set — see: scripts/measure.sh"; exit 1; fi; \
	RPC=$$( [ "$(NET)" = "mainnet" ] && echo https://evmrpc.0g.ai || echo https://evmrpc-testnet.0g.ai ); \
	forge script contracts/script/Bootstrap.s.sol --rpc-url $$RPC --broadcast --slow -vv

verify:
	@set -a; . ./deployments/$(NET).env; set +a; \
	RPC=$$( [ "$(NET)" = "mainnet" ] && echo https://evmrpc.0g.ai || echo https://evmrpc-testnet.0g.ai ); \
	EXP=$$( [ "$(NET)" = "mainnet" ] && echo https://chainscan.0g.ai || echo https://chainscan-testnet.0g.ai ); \
	echo "Biosphere  $$BIOSPHERE"; \
	echo "  population $$(cast call $$BIOSPHERE 'populationSize()(uint256)' --rpc-url $$RPC)"; \
	echo "  living     $$(cast call $$BIOSPHERE 'living()(uint256)' --rpc-url $$RPC)"; \
	echo "  commons    $$(cast call $$BIOSPHERE 'commons()(uint256)' --rpc-url $$RPC)"; \
	echo "Organism   $$ORGANISM"; \
	echo "  identity   $$(cast call $$ORGANISM 'identity()(bytes32)' --rpc-url $$RPC)"; \
	echo "  alive      $$(cast call $$ORGANISM 'alive()(bool)' --rpc-url $$RPC)"; \
	echo "  breathing  $$(cast call $$ORGANISM 'breathing()(bool)' --rpc-url $$RPC)"; \
	echo "  generation $$(cast call $$ORGANISM 'generation()(uint64)' --rpc-url $$RPC)"; \
	echo "  treasury   $$(cast balance $$ORGANISM --rpc-url $$RPC) wei"; \
	echo; echo "  $$EXP/address/$$ORGANISM"

clean:
	@rm -rf out cache .vendor
