/// A purse holds coins on behalf of an inbox.
/// This does not require the recipient to accept incoming coins.
module inbox::purse {
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::coins;
    use inbox::inbox::get_inbox_signer;
    use std::signer;

    /// Deposits coins into an inbox.
    public fun deposit<CoinType>(recipient: address, input: Coin<CoinType>) {
        let inbox_signer = &get_inbox_signer(recipient);
        let inbox_addr = signer::address_of(inbox_signer);
        if (!coin::is_account_registered<CoinType>(inbox_addr)) {
            coins::register<CoinType>(inbox_signer);
        };
        coin::deposit(inbox_addr, input);
    }

    /// Withdraws coins from the inbox.
    public fun withdraw<CoinType>(account: &signer, amount: u64): Coin<CoinType> {
        coin::withdraw(
            &get_inbox_signer(signer::address_of(account)),
            amount,
        )
    }

    /// Sends coins to the given recipient.
    /// WARNING: if the recipient address does not exist, coins can be lost forever!
    /// It is highly recommended to use `offers` instead, which supports revocable coin transfers.
    public entry fun unsafe_send<CoinType>(from: &signer, to: address, amount: u64) {
        deposit(
            to,
            coin::withdraw<CoinType>(from, amount),
        );
    }

    /// Withdraws coins to one's account.
    public entry fun withdraw_to_self<CoinType>(account: &signer, amount: u64) {
        coin::deposit(
            signer::address_of(account),
            withdraw<CoinType>(account, amount),
        );
    }
}