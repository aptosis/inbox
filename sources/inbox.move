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
    use std::error;
    use std::signer;

    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::table::{Self, Table};
    use aptos_framework::timestamp;

    use inbox::inbox_signer;

    /// No pending transfer was found with this id.
    const ETRANSFER_NOT_PUBLISHED: u64 = 1;

    /// Only the creator of a transfer may refund it.
    const ECANNOT_REFUND_NOT_CREATOR: u64 = 2;

    /// Not enough time has passed since creating this transfer.
    const EREFUND_DEADLINE_NOT_MET: u64 = 3;

    /// A transfer of a resource.
    struct Transfer<T: store> has store {
        /// The address which initiated this transfer.
        creator: address,
        /// The resource to transfer.
        resource: T, 
        /// If coins are not accepted by this time, the transfer may be cancelled.
        deadline: u64,
    }

    /// An inbox holds the incoming `Transfer`s to a given address.
    /// Inboxes are stored on a resource account.
    struct Inbox<T: store> has key {
        /// A Table of pending transfers.
        pending: Table<u64, Transfer<T>>,
        /// The total number of items in this inbox.
        /// This is also the next unused index of the inbox.
        size: u64,
    }

    /// Metadata about an inbox account.
    struct InboxMeta has key {
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
            let s = inbox_signer::create();
            move_to<InboxMapping>(&s, InboxMapping {
                addresses: table::new(),
            });
        };
        let mapping = borrow_global<InboxMapping>(@inbox); 
        if (!table::contains(&mapping.addresses, recipient)) {
            let mapping_mut = borrow_global_mut<InboxMapping>(@inbox); 
            let s = inbox_signer::create();
            let (inbox_signer, inbox_cap) = account::create_resource_account(&s, bcs::to_bytes(&recipient));
            let inbox_addr = signer::address_of(&inbox_signer);
            table::add(&mut mapping_mut.addresses, recipient, inbox_addr);
            move_to<InboxMeta>(&inbox_signer, InboxMeta {
                signer_cap: inbox_cap,
            });
            inbox_addr
        } else {
            *table::borrow(&mapping.addresses, recipient)
        }
    }

    /// Offers a resource to an `Inbox`, creating it if it doesn't exist.
    public fun offer<T: store>(
        from: &signer,
        to: address,
        source: T,
        deadline_seconds: u64,
    ): u64 acquires InboxMapping, Inbox, InboxMeta {
        let deadline = timestamp::now_seconds() + deadline_seconds;
        offer_with_eta(from, to, source, deadline)
    }

    /// Initiates a transfer to an inbox.
    public fun offer_with_eta<T: store>(
        from: &signer,
        to: address,
        source: T,
        deadline: u64,
    ): u64 acquires InboxMapping, Inbox, InboxMeta {
        let inbox_addr = get_or_create_inbox_address(to);
        // If there are no transfers for this coin, create the table for the coin.
        if (!exists<Inbox<T>>(inbox_addr)) {
            let signer_cap = &borrow_global<InboxMeta>(inbox_addr).signer_cap;
            let inbox_signer = account::create_signer_with_capability(signer_cap);
            move_to<Inbox<T>>(&inbox_signer, Inbox {
                pending: table::new(),
                size: 0,
            });
        };

        let inbox = borrow_global_mut<Inbox<T>>(inbox_addr);
        inbox_offer_internal(
            inbox,
            signer::address_of(from),
            source,
            deadline,
        )
    }

    /// Cancels a transfer, returning the resource.
    /// 
    /// If the `deadline` has not yet been met, this transaction should fail.
    public fun cancel<T: store>(
        sender: &signer,
        recipient_addr: address,
        id: u64,
    ): T acquires InboxMapping, Inbox {
        let Transfer {
            resource, 
            deadline,
            creator,
        } = remove_transfer_internal<T>(recipient_addr, id);
        assert!(
            creator == signer::address_of(sender),
            error::permission_denied(ECANNOT_REFUND_NOT_CREATOR),
        );
        assert!(
            timestamp::now_seconds() >= deadline,
            error::invalid_state(EREFUND_DEADLINE_NOT_MET)
        );
        resource
    }

    /// Accepts a transfer.
    public fun accept<T: store>(
        recipient: &signer,
        id: u64,
    ): T acquires InboxMapping, Inbox {
        let Transfer {
            resource,
            creator: _creator,
            deadline: _deadline,
        } = remove_transfer_internal<T>(signer::address_of(recipient), id);
        resource
    }

    /// Removes a transfer from the recipient.
    /// Internal only-- this does not validate the recipient.
    fun remove_transfer_internal<T: store>(
        recipient_addr: address,
        id: u64,
    ): Transfer<T> acquires InboxMapping, Inbox {
        let inbox_addr = get_or_create_inbox_address(recipient_addr);
        let inbox = borrow_global_mut<Inbox<T>>(inbox_addr);
        inbox_remove_transfer_internal<T>(inbox, id)
    }

    /// Creates a transfer and adds it to the inbox.
    fun inbox_offer_internal<T: store>(
        inbox: &mut Inbox<T>,
        from: address,
        resource: T,
        deadline: u64,
    ): u64 {
        let id = inbox.size;
        table::add(&mut inbox.pending, id, Transfer {
            creator: from,
            resource, 
            deadline,
        });
        inbox.size = inbox.size + 1;
        id
    }

    /// Remove the transfer from the inbox.
    fun inbox_remove_transfer_internal<T: store>(
        inbox: &mut Inbox<T>,
        id: u64,
    ): Transfer<T> {
        assert!(
            table::contains(&mut inbox.pending, id),
            error::not_found(ETRANSFER_NOT_PUBLISHED)
        );
        table::remove(&mut inbox.pending, id)
    }
}