#[cfg(test)]
mod tests {
    use core::array::ArrayTrait;
    use core::result::ResultTrait;
    use core::traits::TryInto;
    use snforge_std::{
        ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
        start_cheat_caller_address, stop_cheat_caller_address,
    };
    use starknet::{ContractAddress, contract_address_const};
    use unichain_contracts::Interfaces::ICertiva::{ICertivaDispatcher, ICertivaDispatcherTrait};
    use unichain_contracts::certiva::Certiva;
    use unichain_contracts::certiva::Certiva::{
        BulkCertificatesIssued, University, CertificateRevoked,
    };

    fn setup() -> (ContractAddress, ICertivaDispatcher) {
        let contract = declare("Certiva").unwrap().contract_class();
        let owner: ContractAddress = 'owner'.try_into().unwrap();

        let (contract_address, _) = contract.deploy(@array![owner.into()]).unwrap();
        let dispatcher = ICertivaDispatcher { contract_address: contract_address };

        (owner, dispatcher)
    }

    fn register_test_university(
        owner: ContractAddress, dispatcher: ICertivaDispatcher,
    ) -> ContractAddress {
        let university_name = 'Test University';
        let website_domain = "test.edu";
        let country = 'Test Country';
        let accreditation_body = 'Test Accreditation';
        let university_email = "test@test.edu";
        let wallet_address = contract_address_const::<'university'>();

        start_cheat_caller_address(dispatcher.contract_address, owner);
        dispatcher
            .register_university(
                university_name,
                website_domain,
                country,
                accreditation_body,
                university_email,
                wallet_address,
            );
        stop_cheat_caller_address(dispatcher.contract_address);

        wallet_address
    }

    fn issue_test_certificate(
        dispatcher: ICertivaDispatcher, university_wallet: ContractAddress, certificate_id: felt252,
    ) {
        let certificate_meta_data = "Student: John Doe, Degree: Computer Science";
        let hashed_key = "abcdef123456";

        start_cheat_caller_address(dispatcher.contract_address, university_wallet);
        dispatcher.issue_certificate(certificate_meta_data, hashed_key, certificate_id);
        stop_cheat_caller_address(dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Unauthorized caller')]
    fn test_register_university_unauthorized() {
        let (owner, dispatcher) = setup();

        // Test data
        let university_name = 'Harvard University';
        let website_domain = "nnamdi azikiwe university";
        let country = 'USA';
        let accreditation_body = 'NECHE';
        let university_email = "nnamdiazikiweuniversity@gmail.com";
        let wallet_address = contract_address_const::<2>();

        let non_owner = contract_address_const::<'non_owner'>();

        // Try to register university as non-owner
        // Register university as owner
        start_cheat_caller_address(dispatcher.contract_address, non_owner);
        dispatcher
            .register_university(
                university_name,
                website_domain,
                country,
                accreditation_body,
                university_email,
                wallet_address,
            );
        stop_cheat_caller_address(dispatcher.contract_address);
    }

    #[test]
    fn test_register_university_optional_field() {
        // Deploy the contract
        let (owner, dispatcher) = setup();

        // Test data
        let university_name = 'Harvard University';
        let website_domain = "nnamdi azikiwe university";
        let country = 'USA';
        let accreditation_body = '';
        let university_email = "nnamdiazikiweuniversity@gmail.com";
        let wallet_address = contract_address_const::<2>();

        let non_owner = contract_address_const::<'non_owner'>();

        // Try to register university as non-owner
        // Register university as owner
        start_cheat_caller_address(dispatcher.contract_address, owner);
        dispatcher
            .register_university(
                university_name,
                website_domain,
                country,
                accreditation_body,
                university_email,
                wallet_address,
            );
        stop_cheat_caller_address(dispatcher.contract_address);
    }

    #[test]
    fn test_register_university_event() {
        // Deploy the contract
        let (owner, dispatcher) = setup();

        // Test data
        let university_name = 'Harvard University';
        let website_domain_str: ByteArray = "nnamdi azikiwe university";
        let country = 'USA';
        let accreditation_body = 'dsscscnbs';
        let university_email_str: ByteArray = "nnamdiazikiweuniversity@gmail.com";
        let wallet_address = contract_address_const::<2>();

        let mut spy = spy_events();

        // Register university as owner
        start_cheat_caller_address(dispatcher.contract_address, owner);
        dispatcher
            .register_university(
                university_name,
                website_domain_str.clone(),
                country,
                accreditation_body,
                university_email_str.clone(),
                wallet_address,
            );
        stop_cheat_caller_address(dispatcher.contract_address);

        // Use the same values in the event assertion as were used in the function call
        spy
            .assert_emitted(
                @array![
                    (
                        dispatcher.contract_address,
                        Certiva::Event::university_created(
                            University {
                                university_name,
                                website_domain: website_domain_str, // Use the original value
                                country,
                                accreditation_body,
                                university_email: university_email_str, // Use the original value
                                wallet_address,
                            },
                        ),
                    ),
                ],
            );
    }

    // Tests for certificate issuance functionality
    #[test]
    fn test_issue_certificate() {
        // Setup contract and register a university
        let (owner, dispatcher) = setup();
        let university_wallet = register_test_university(owner, dispatcher);

        // Certificate data
        let certificate_meta_data = "Student: Usman Alfaki, Degree: Computer Science";
        let hashed_key = "abcdef123456";
        let certificate_id = 'CS-2023-001';

        // Clone variables before issuing certificate
        let cert_meta_clone = certificate_meta_data.clone();
        let hashed_key_clone = hashed_key.clone();
        let cert_id_clone1 = certificate_id.clone();

        // Use clones in the function call
        start_cheat_caller_address(dispatcher.contract_address, university_wallet);
        dispatcher.issue_certificate(cert_meta_clone, hashed_key_clone, cert_id_clone1);
        stop_cheat_caller_address(dispatcher.contract_address);

        // Now the original certificate_id is still available for cloning
        let cert_id_clone2 = certificate_id.clone();
        let stored_certificate = dispatcher.get_certificate(cert_id_clone2);

        // Clone stored_certificate before first use
        let stored_certificate_clone = stored_certificate.clone();

        // Use a different clone for each assertion
        assert(stored_certificate.certificate_meta_data == certificate_meta_data, 'Wrong metadata');
        assert(stored_certificate_clone.hashed_key == hashed_key, 'Wrong hashed key');
        assert(stored_certificate_clone.certificate_id == certificate_id, 'Wrong certificate ID');
        assert(stored_certificate.issuer_address == university_wallet, 'Wrong issuer');
    }

    #[test]
    #[should_panic(expected: 'University not registered')]
    fn test_issue_certificate_unauthorized() {
        // Setup contract
        let (owner, dispatcher) = setup();

        // Certificate data
        let certificate_meta_data = "Student: Usman Alfaki, Degree: Computer Science";
        let hashed_key = "abcdef123456";
        let certificate_id = 'CS-2023-001';

        // Try to issue certificate as non-university address
        let non_university = contract_address_const::<'non_university'>();
        start_cheat_caller_address(dispatcher.contract_address, non_university);
        dispatcher.issue_certificate(certificate_meta_data, hashed_key, certificate_id);
        stop_cheat_caller_address(dispatcher.contract_address);
    }

    #[test]
    fn test_certificate_issued_event() {
        let (owner, dispatcher) = setup();
        let university_wallet = register_test_university(owner, dispatcher);

        // Certificate data
        let certificate_meta_data = "Student: Usman Alfaki, Degree: Computer Science";
        let hashed_key = "abcdef123456";
        let certificate_id = 'CS-2023-001';

        // Clone before using in issue_certificate
        let cert_meta_clone1 = certificate_meta_data.clone();
        let hashed_key_clone1 = hashed_key.clone();
        let cert_id_clone1 = certificate_id.clone();

        let mut spy = spy_events();

        // Use clones in function call
        start_cheat_caller_address(dispatcher.contract_address, university_wallet);
        dispatcher.issue_certificate(cert_meta_clone1, hashed_key_clone1, cert_id_clone1);
        stop_cheat_caller_address(dispatcher.contract_address);

        // Clone again for get_certificate
        let cert_id_clone2 = certificate_id.clone();
        let stored_cert = dispatcher.get_certificate(cert_id_clone2);

        // Use clones for all comparisons
        let cert_meta_clone2 = certificate_meta_data.clone();
        let hashed_key_clone2 = hashed_key.clone();
        let cert_id_clone3 = certificate_id.clone();

        spy
            .assert_emitted(
                @array![
                    (
                        dispatcher.contract_address,
                        Certiva::Event::certificate_issued(stored_cert.clone()),
                    ),
                ],
            );

        assert(stored_cert.certificate_meta_data == cert_meta_clone2, 'Wrong metadata');
        assert(stored_cert.hashed_key == hashed_key_clone2, 'Wrong hashed key');
        assert(stored_cert.certificate_id == cert_id_clone3, 'Wrong certificate ID');
    }

    #[test]
    fn test_bulk_issue_certificates() {
        // Setup contract and register a university
        let (owner, dispatcher) = setup();
        let university_wallet = register_test_university(owner, dispatcher);

        // Prepare certificate data arrays
        let mut meta_data_array = ArrayTrait::new();
        meta_data_array.append("Student 1: Usman Alfaki, Degree: Computer Science");
        meta_data_array.append("Student 2: Jethro Smith, Degree: Engineering");

        let mut hashed_key_array = ArrayTrait::new();
        hashed_key_array.append("hash1");
        hashed_key_array.append("hash2");

        let mut cert_id_array = ArrayTrait::new();
        cert_id_array.append('CS-2023-001');
        cert_id_array.append('ENG-2023-001');

        let mut spy = spy_events();

        // Issue certificates in bulk
        start_cheat_caller_address(dispatcher.contract_address, university_wallet);
        dispatcher.bulk_issue_certificates(meta_data_array, hashed_key_array, cert_id_array);
        stop_cheat_caller_address(dispatcher.contract_address);

        // Verify event was emitted with correct count (2) and university
        spy
            .assert_emitted(
                @array![
                    (
                        dispatcher.contract_address,
                        Certiva::Event::certificates_bulk_issued(
                            BulkCertificatesIssued { count: 2, issuer: university_wallet },
                        ),
                    ),
                ],
            );

        // With our improved key derivation function, we can now verify individual certificates
        // by retrieving them using their certificate_id
        let cert_id1 = 'CS-2023-001';
        let cert_id2 = 'ENG-2023-001';

        let stored_cert1 = dispatcher.get_certificate(cert_id1);
        let stored_cert2 = dispatcher.get_certificate(cert_id2);

        assert(
            stored_cert1
                .certificate_meta_data == "Student 1: Usman Alfaki, Degree: Computer Science",
            ' metadata 1',
        );
        assert(
            stored_cert2.certificate_meta_data == "Student 2: Jethro Smith, Degree: Engineering",
            ' metadata 2',
        );
    }

    #[test]
    #[should_panic(expected: 'Arrays length mismatch')]
    fn test_bulk_issue_certificates_mismatch() {
        // Setup contract and register a university
        let (owner, dispatcher) = setup();
        let university_wallet = register_test_university(owner, dispatcher);

        // Prepare certificate data arrays with mismatched lengths
        let mut meta_data_array = ArrayTrait::new();
        meta_data_array.append("Student 1: Usman Alfaki, Degree: Computer Science");
        meta_data_array.append("Student 2: Jethro Smith, Degree: Engineering");

        let mut hashed_key_array = ArrayTrait::new();
        hashed_key_array.append("hash1");
        // Missing second hash to cause mismatch

        let mut cert_id_array = ArrayTrait::new();
        cert_id_array.append('CS-2023-001');
        cert_id_array.append('ENG-2023-001');

        // Attempt to issue certificates with mismatched arrays
        start_cheat_caller_address(dispatcher.contract_address, university_wallet);
        dispatcher.bulk_issue_certificates(meta_data_array, hashed_key_array, cert_id_array);
        stop_cheat_caller_address(dispatcher.contract_address);
    }

    #[test]
    fn test_get_certificate_by_issuer_found() {
        // Deploy the contract
        let (owner, dispatcher) = setup();

        let university_wallet = register_test_university(owner, dispatcher);

        // Certificate data
        let certificate_meta_data = "Student: Usman Alfaki, Degree: Computer Science";
        let hashed_key = "abcdef123456";
        let certificate_id = 'CS-2023-001';

        // Clone before using in issue_certificate
        let cert_meta_clone1 = certificate_meta_data.clone();
        let hashed_key_clone1 = hashed_key.clone();
        let cert_id_clone1 = certificate_id.clone();

        let mut spy = spy_events();

        // make function call
        start_cheat_caller_address(dispatcher.contract_address, university_wallet);
        dispatcher.issue_certificate(cert_meta_clone1, hashed_key_clone1, cert_id_clone1);

        stop_cheat_caller_address(dispatcher.contract_address);

        start_cheat_caller_address(dispatcher.contract_address, university_wallet);

        dispatcher.get_certicate_by_issuer();

        let expected_event = Certiva::Event::CertificateFound(
            Certiva::CertificateFound { issuer: university_wallet },
        );
        spy.assert_emitted(@array![(dispatcher.contract_address, expected_event)]);

        stop_cheat_caller_address(dispatcher.contract_address);
    }

    #[test]
    fn test_get_certificate_by_issuer_not_found() {
        // Deploy the contract
        let (owner, dispatcher) = setup();

        // Setup event spy
        let mut spy = spy_events();

        // Set caller address for the transaction
        let caller: ContractAddress = 'Daniel'.try_into().unwrap();
        start_cheat_caller_address(dispatcher.contract_address, caller);

        // Call the function
        dispatcher.get_certicate_by_issuer();

        // Assert that the CertificateNotFound event is emitted
        let expected_event = Certiva::Event::CertificateNotFound(
            Certiva::CertificateNotFound { issuer: caller },
        );
        spy.assert_emitted(@array![(dispatcher.contract_address, expected_event)]);

        stop_cheat_caller_address(dispatcher.contract_address);
    }

    #[test]
    fn test_revoke_certificate_authorized() {
        let (owner, dispatcher) = setup();
        let university_wallet = register_test_university(owner, dispatcher);
        let certificate_id = 'CS-2023-001';

        issue_test_certificate(dispatcher, university_wallet, certificate_id);

        let mut spy = spy_events();

        start_cheat_caller_address(dispatcher.contract_address, university_wallet);
        let result = dispatcher.revoke_certificate(certificate_id);
        stop_cheat_caller_address(dispatcher.contract_address);

        assert(result.is_ok(), 'Revoke should succeed');
        let certificate = dispatcher.get_certificate(certificate_id);
        assert(!certificate.isActive, 'Certificate should be revoked');

        spy
            .assert_emitted(
                @array![
                    (
                        dispatcher.contract_address,
                        Certiva::Event::CertificateRevoked(
                            CertificateRevoked { certificate_id, issuer: university_wallet },
                        ),
                    ),
                ],
            );
    }

    #[test]
    #[should_panic(expected: 'University not registered')]
    fn test_revoke_certificate_unregistered_university() {
        let (_owner, dispatcher) = setup();
        let certificate_id = 'CS-2023-001';
        let unregistered_wallet = contract_address_const::<'unregistered'>();

        start_cheat_caller_address(dispatcher.contract_address, unregistered_wallet);
        dispatcher.revoke_certificate(certificate_id);
        // The function will panic with 'University not registered' before returning Err
        stop_cheat_caller_address(dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Not certificate issuer')]
    fn test_revoke_certificate_non_issuer() {
        let (owner, dispatcher) = setup();
        let university_wallet1 = register_test_university(owner, dispatcher);
        let university_wallet2 = contract_address_const::<'university2'>();

        start_cheat_caller_address(dispatcher.contract_address, owner);
        dispatcher
            .register_university(
                'Test University 2',
                "test2.edu",
                'USA',
                'CHEA',
                "admin2@test.edu",
                university_wallet2,
            );
        stop_cheat_caller_address(dispatcher.contract_address);

        let certificate_id = 'CS-2023-001';
        issue_test_certificate(dispatcher, university_wallet1, certificate_id);

        start_cheat_caller_address(dispatcher.contract_address, university_wallet2);
        dispatcher.revoke_certificate(certificate_id);
        // The function will panic with 'Not certificate issuer' before returning Err
        stop_cheat_caller_address(dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: 'Certificate not found')]
    fn test_revoke_non_existent_certificate() {
        let (_owner, dispatcher) = setup();
        let university_wallet = register_test_university(_owner, dispatcher);
        let non_existent_id = 'CS-2023-999';

        start_cheat_caller_address(dispatcher.contract_address, university_wallet);
        dispatcher.revoke_certificate(non_existent_id);
        // The function will panic with 'Certificate not found' before returning Err
        stop_cheat_caller_address(dispatcher.contract_address);
    }

    #[test]
    fn test_revoke_certificate_verification() {
        let (owner, dispatcher) = setup();
        let university_wallet = register_test_university(owner, dispatcher);

        let certificate_id1 = 'CS-2023-001';
        let certificate_id2 = 'CS-2023-002';
        issue_test_certificate(dispatcher, university_wallet, certificate_id1);
        issue_test_certificate(dispatcher, university_wallet, certificate_id2);

        start_cheat_caller_address(dispatcher.contract_address, university_wallet);
        let result = dispatcher.revoke_certificate(certificate_id1);
        stop_cheat_caller_address(dispatcher.contract_address);

        assert(result.is_ok(), 'Revoke should succeed');
        let certificate1 = dispatcher.get_certificate(certificate_id1);
        assert(!certificate1.isActive, 'Certificate1 should be revoked');

        let certificate2 = dispatcher.get_certificate(certificate_id2);
        assert(certificate2.isActive, 'Cert2 should remain active');
    }

    #[test]
    #[should_panic(expected: 'Domain mismatch')]
    fn test_revoke_certificate_domain_mismatch() {
        let (_owner, dispatcher) = setup();
        let university_wallet = register_test_university(_owner, dispatcher);
        let certificate_id = 'CS-2023-001';

        issue_test_certificate(dispatcher, university_wallet, certificate_id);

        start_cheat_caller_address(dispatcher.contract_address, _owner);
        dispatcher
            .register_university(
                'Test University',
                "different.edu",
                'USA',
                'CHEA',
                "admin@test.edu",
                university_wallet,
            );
        stop_cheat_caller_address(dispatcher.contract_address);

        start_cheat_caller_address(dispatcher.contract_address, university_wallet);
        dispatcher.revoke_certificate(certificate_id);
        // The function will panic with 'Domain mismatch' before returning Err
        stop_cheat_caller_address(dispatcher.contract_address);
    }
}
