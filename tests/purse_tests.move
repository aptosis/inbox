/// Tests for `inbox::purse`.
module inbox::purse_tests {
    use std::signer;

    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;

    use inbox::core;
    use inbox::purse;

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
        core::initialize_for_testing(&inbox_deployer);

        acct::create(&framework, &sender, 1000);

        let recipient_addr = signer::address_of(&recipient);
        check::eq(purse::balance<AptosCoin>(recipient_addr), 0);

        purse::unsafe_send<AptosCoin>(&sender, recipient_addr, 100);

        check::eq(purse::balance<AptosCoin>(recipient_addr), 100);

        acct::create(&framework, &recipient, 0);
        purse::withdraw_to_self<AptosCoin>(&recipient, 100);
        check::eq(purse::balance<AptosCoin>(recipient_addr), 0);
        check::eq(coin::balance<AptosCoin>(recipient_addr), 100);
    }
}