/// The `inbox` module defines a method of sending resources to other accounts.
/// 
/// The primary use case of this module is to be able to send coins to any address,
/// even if they do not have an existing `CoinStore`.
/// 
/// Transfers may also be revoked by the sender if its `deadline` has elapsed. This
/// prevents the sender from sending coins to invalid addresses.
///
/// # Lifecycle
///
/// 1. Call `inbox::send` to create a transfer of a resource to another party.
/// 2. Call `inbox::accept` to accept the resource.
///   a. If the sender does not want to send the resource, call `inbox::cancel` to cancel the transfer.
module inbox::inbox {
    use std::bcs;
    use std::signer;

    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::table::{Self, Table};

    use inbox::core::create_core_signer;

    friend inbox::offers;
    friend inbox::purse;

    /// Metadata about an inbox account.
    struct Inbox has key {
        /// A Table of `recipient` -> `inbox` address.
        signer_cap: SignerCapability,
    }

    /// A mapping of addresses to their inbox.
    struct InboxMapping has key {
        /// A Table of `recipient` -> `inbox` address.
        addresses: Table<address, address>,
    }

    /// Gets the inbox address of the given recipient, creating it if it doesn't exist.
    public fun get_or_create_inbox_address(recipient: address): address acquires InboxMapping {
        if (!exists<InboxMapping>(@inbox)) {
            let s = create_core_signer();
            move_to<InboxMapping>(&s, InboxMapping {
                addresses: table::new(),
            });
        };
        let mapping = borrow_global<InboxMapping>(@inbox); 
        if (!table::contains(&mapping.addresses, recipient)) {
            let mapping_mut = borrow_global_mut<InboxMapping>(@inbox); 
            let s = create_core_signer();
            let (inbox_signer, inbox_cap) = account::create_resource_account(&s, bcs::to_bytes(&recipient));
            let inbox_addr = signer::address_of(&inbox_signer);
            table::add(&mut mapping_mut.addresses, recipient, inbox_addr);
            move_to<Inbox>(&inbox_signer, Inbox {
                signer_cap: inbox_cap,
            });
            inbox_addr
        } else {
            *table::borrow(&mapping.addresses, recipient)
        }
    }

    public(friend) fun get_inbox_signer_from_inbox(inbox_addr: address): signer acquires Inbox {
        let signer_cap = &borrow_global<Inbox>(inbox_addr).signer_cap;
        account::create_signer_with_capability(signer_cap)
    }

    public(friend) fun get_inbox_signer(owner: address): signer acquires InboxMapping, Inbox {
        let inbox_addr = get_or_create_inbox_address(owner);
        get_inbox_signer_from_inbox(inbox_addr)
    }

}