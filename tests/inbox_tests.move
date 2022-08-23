/// Tests for `inbox::inbox`.
module inbox::inbox_tests {
    use std::signer;
    use aptos_framework::timestamp;

    use inbox::inbox;
    use inbox::inbox_signer;

    use aptest::aptest;
    use aptest::acct;
    use aptest::check;

    #[test(
        framework = @aptos_framework,
        inbox_deployer = @inbox_deployer,
        sender = @0xa11ce,
        recipient = @0xb0b,
    )]
    /// Test sending coins and initializing an account
    public entry fun test_accept(
        framework: signer,
        inbox_deployer: signer,
        sender: signer,
        recipient: signer,
    ) {
        aptest::setup(&framework);
        inbox_signer::initialize_for_testing(&inbox_deployer);

        acct::create(&framework, &sender, 1000);
        acct::create(&framework, &recipient, 1000);

        timestamp::set_time_has_started_for_testing(&framework);

        // initiate coin transfer
        inbox::offer<u64>(&sender, signer::address_of(&recipient), 100, 0);

        // accept coin transfer
        let result = inbox::accept<u64>(&recipient, 0);
        check::eq(result, 100);
    }

    #[test(
        resources = @core_resources,
        framework = @aptos_framework,
        inbox_deployer = @inbox_deployer,
        sender = @0xa11ce,
        recipient = @0xb0b,
    )]
    /// Test sending coins and initializing an account
    public entry fun test_cancel(
        framework: signer,
        inbox_deployer: signer,
        sender: signer,
        recipient: signer,
    ) {
        aptest::setup(&framework);
        inbox_signer::initialize_for_testing(&inbox_deployer);

        acct::create(&framework, &sender, 1000);
        acct::create(&framework, &recipient, 1000);

        timestamp::set_time_has_started_for_testing(&framework);

        // initiate coin transfer
        inbox::offer<u64>(&sender, signer::address_of(&recipient), 100, 0);

        // cancel coin transfer
        inbox::cancel<u64>(&sender, signer::address_of(&recipient), 0);
    }
}