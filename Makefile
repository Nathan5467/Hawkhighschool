-include .env

setup:
	@forge install OpenZeppelin/openzeppelin-contracts
	@forge install OpenZeppelin/openzeppelin-contracts-upgradeable
	@forge install foundry-rs/forge-std
	@forge install Cyfrin/foundry-devops