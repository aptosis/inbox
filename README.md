# Inbox by Aptos.is

The `inbox` module defines a method of sending resources to other accounts.

The primary use case of this module is to be able to send coins to any address,
even if they do not have an existing `CoinStore`.

Transfers may also be revoked by the sender if its `deadline` has elapsed. This
prevents the sender from sending coins to invalid addresses.

# Lifecycle

1. Call `inbox::send` to create a transfer of a resource to another party.
2. Call `inbox::accept` to accept the resource.
  a. If the sender does not want to send the resource, call `inbox::cancel` to cancel the transfer.

## Installation

To use inbox in your code, add the following to the `[addresses]` section of your `Move.toml`:

```toml
[addresses]
inbox = "0xf79945b8d98af4d50f1d9c84a27362d032e48c2c17a3f24e3c81cf4a2a0e06c0"
```



## License

Apache-2.0

