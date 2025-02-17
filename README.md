# Compound Stable Yield Chaser Vault

## Overview

This Vyper smart contract is designed to manage a vault that chases stable yield through the Compound protocol. It allows users to deposit assets, which are then swapped and supplied to Compound to earn interest. The contract also supports withdrawal of assets, including the ability to swap them back to the desired token.

## Features

- **Deposits**: Users can deposit assets into the vault. The contract supports swapping assets using CurveSwapRouter before supplying them to Compound.
- **Withdrawals**: Users can withdraw their assets from the vault. The contract supports swapping assets back to the desired token using CurveSwapRouter.
- **Events**: The contract emits various events to track deposits, withdrawals, asset updates, and fee changes.
- **Fee Management**: The contract supports entrance fees, service fees, and redemption fees, which are configurable.

## Constants

- `VETH`: Address representing Ether.
- `DENOMINATOR`: Used for denominator to represent decimal numbers using uint256.
- `BOBBY_RATE`: Bobby token price rate.
- `REDEMPTION_FEE_COLLECTOR`: Address that collects redemption fees.
- `REDEMPTION_FEE`: Redemption fee percentage.
- `WETH`: Address of the Wrapped Ether contract.
- `Router`: Address of the CurveSwapRouter.

## Events

- `Deposited`: Emitted when a deposit is made.
- `Released`: Emitted when assets are released.
- `UpdateAsset`: Emitted when the asset is updated.
- `Withdrawn`: Emitted when a withdrawal is made.
- `UpdateCompass`: Emitted when the compass address is updated.
- `UpdateRefundWallet`: Emitted when the refund wallet address is updated.
- `SetPaloma`: Emitted when the paloma is set.
- `UpdateEntranceFee`: Emitted when the entrance fee is updated.
- `UpdateServiceFeeCollector`: Emitted when the service fee collector address is updated.
- `UpdateServiceFee`: Emitted when the service fee is updated.
- `SetBobby`: Emitted when the bobby address is set.

## State Variables

- `compass`: Address of the compass.
- `asset`: Address of the current asset.
- `c_asset`: Address of the current Compound asset.
- `input_token`: Mapping of user addresses to their input tokens.
- `bobby`: Address of the bobby token.
- `deposits`: Mapping of user addresses to their deposit amounts.
- `total_deposit`: Total amount of pending deposits.
- `refund_wallet`: Address of the refund wallet.
- `entrance_fee`: Entrance fee percentage.
- `service_fee_collector`: Address of the service fee collector.
- `service_fee`: Service fee percentage.
- `paloma`: Paloma value.
- `nonce_check`: Mapping of nonces to their usage status.

## Functions

### Constructor

- `__init__`: Initializes the contract with the given parameters.

### Internal Functions

- `_safe_approve`: Safely approves a token transfer.
- `_safe_transfer`: Safely transfers tokens.
- `_safe_transfer_from`: Safely transfers tokens from a specified address.
- `_paloma_check`: Checks if the caller is the compass and if the paloma address that sent Job Scheduler message is valid.

### External Functions

- `deposit`: Allows users to deposit assets into the vault.
- `change_asset`: Changes the asset used by the vault.
- `set_bobby`: Sets the bobby address.
- `release_bobby`: Releases bobby tokens to a recipient.
- `asset_balance`: Returns the asset balance of a user.
- `withdraw`: Allows users to withdraw assets from the vault.
- `withdraw_amount`: Calculates the amount of assets that can be withdrawn.
- `update_compass`: Updates the compass address.
- `set_paloma`: Sets the paloma value.
- `update_refund_wallet`: Updates the refund wallet address.
- `update_entrance_fee`: Updates the entrance fee percentage.
- `update_service_fee_collector`: Updates the service fee collector address.
- `update_service_fee`: Updates the service fee percentage.

## License

This project is licensed under the Apache 2.0 License.

## Author

Volume.finance
