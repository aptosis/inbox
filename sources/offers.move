module inbox::offers {
    use std::error;
    use std::signer;

    use aptos_framework::table::{Self, Table};
    use aptos_framework::timestamp;

    use inbox::inbox;

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

    /// `Offers` holds the incoming `Transfer`s to a given address.
    struct Offers<T: store> has key {
        /// A Table of pending transfers.
        pending: Table<u64, Transfer<T>>,
        /// The total number of items in this inbox.
        /// This is also the next unused index of the inbox.
        size: u64,
    }

    /// Offers a resource to an `Offers`, creating it if it doesn't exist.
    public fun offer<T: store>(
        from: &signer,
        to: address,
        source: T,
        deadline_seconds: u64,
    ): u64 acquires Offers {
        let deadline = timestamp::now_seconds() + deadline_seconds;
        offer_with_eta(from, to, source, deadline)
    }

    /// Initiates a transfer to an inbox.
    public fun offer_with_eta<T: store>(
        from: &signer,
        to: address,
        source: T,
        deadline: u64,
    ): u64 acquires Offers {
        let inbox_addr = inbox::get_or_create_inbox_address(to);
        // If there are no transfers for this coin, create the table for the coin.
        if (!exists<Offers<T>>(inbox_addr)) {
            let inbox_signer = inbox::get_inbox_signer_from_inbox(inbox_addr);
            move_to<Offers<T>>(&inbox_signer, Offers {
                pending: table::new(),
                size: 0,
            });
        };

        let offers = borrow_global_mut<Offers<T>>(inbox_addr);
        offer_internal(
            offers,
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
    ): T acquires Offers {
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
    ): T acquires Offers {
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
    ): Transfer<T> acquires Offers {
        let inbox_addr = inbox::get_or_create_inbox_address(recipient_addr);
        let inbox = borrow_global_mut<Offers<T>>(inbox_addr);
        offers_remove_transfer_internal<T>(inbox, id)
    }

    /// Creates a transfer and adds it to the inbox.
    fun offer_internal<T: store>(
        offers: &mut Offers<T>,
        from: address,
        resource: T,
        deadline: u64,
    ): u64 {
        let id = offers.size;
        table::add(&mut offers.pending, id, Transfer {
            creator: from,
            resource, 
            deadline,
        });
        offers.size = offers.size + 1;
        id
    }

    /// Remove the transfer from the offers.
    fun offers_remove_transfer_internal<T: store>(
        offers: &mut Offers<T>,
        id: u64,
    ): Transfer<T> {
        assert!(
            table::contains(&mut offers.pending, id),
            error::not_found(ETRANSFER_NOT_PUBLISHED)
        );
        table::remove(&mut offers.pending, id)
    }
}