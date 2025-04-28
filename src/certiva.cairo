#[starknet::contract]
pub mod Certiva {
    use core::array::ArrayTrait;
    use core::byte_array::ByteArray;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, contract_address_const, get_caller_address};
    use crate::Interfaces::ICertiva::ICertiva;


    #[storage]
    struct Storage {
        owner: ContractAddress,
        university: Map<ContractAddress, University>,
        certificates: Map<felt252, Certificate>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
    }

    #[derive(Drop, Serde, starknet::Event, starknet::Store)]
    pub struct University {
        pub university_name: felt252,
        pub website_domain: ByteArray,
        pub country: felt252,
        pub accreditation_body: felt252,
        pub university_email: ByteArray,
        pub wallet_address: ContractAddress,
    }

    #[derive(Drop, Clone, Serde, starknet::Event, starknet::Store)]
    pub struct Certificate {
        pub certificate_meta_data: ByteArray,
        pub hashed_key: ByteArray,
        pub certificate_id: felt252,
        pub issuer_domain: ByteArray,
        pub issuer_address: ContractAddress,
        pub isActive: bool,
    }

    #[derive(Drop, Serde, starknet::Event)]
    pub struct BulkCertificatesIssued {
        pub count: felt252,
        pub issuer: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CertificateFound {
        pub issuer: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CertificateNotFound {
        pub issuer: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CertificateRevoked {
        pub certificate_id: felt252,
        pub issuer: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        university_created: University,
        certificate_issued: Certificate,
        certificates_bulk_issued: BulkCertificatesIssued,
        CertificateFound: CertificateFound,
        CertificateNotFound: CertificateNotFound,
        CertificateRevoked: CertificateRevoked,
    }

    #[abi(embed_v0)]
    impl CertivaImpl of ICertiva<ContractState> {
        // fn to register university
        // only contract owner can register university
        fn register_university(
            ref self: ContractState,
            university_name: felt252,
            website_domain: ByteArray,
            country: felt252,
            accreditation_body: felt252,
            university_email: ByteArray,
            wallet_address: ContractAddress,
        ) {
            // Check that caller is the owner
            let caller = get_caller_address();
            let owner = self.owner.read();
            let zero_address = contract_address_const::<0>();
            assert(caller == owner, 'Unauthorized caller');

            // Validate inputs
            assert(university_name != 0, 'University name is required');
            assert(wallet_address != zero_address, 'Wallet address cannot be zero');
            assert(country != 0, 'Country is required');

            let new_university = University {
                university_name: university_name,
                website_domain: website_domain.clone(),
                country: country,
                accreditation_body: accreditation_body,
                university_email: university_email.clone(),
                wallet_address: wallet_address,
            };

            self.university.write(wallet_address, new_university);

            self
                .emit(
                    Event::university_created(
                        University {
                            university_name,
                            website_domain,
                            country,
                            accreditation_body,
                            university_email,
                            wallet_address,
                        },
                    ),
                );
        }

        // Function to get university details by wallet address
        fn get_university(self: @ContractState, wallet_address: ContractAddress) -> University {
            self.university.read(wallet_address)
        }

        // Function to issue a certificate by a registered university
        fn issue_certificate(
            ref self: ContractState,
            certificate_meta_data: ByteArray,
            hashed_key: ByteArray,
            certificate_id: felt252,
        ) {
            let caller = get_caller_address();

            let university = self.university.read(caller);
            let zero_address = contract_address_const::<0>();
            assert(university.wallet_address != zero_address, 'University not registered');

            let new_certificate = Certificate {
                certificate_meta_data: certificate_meta_data.clone(),
                hashed_key: hashed_key.clone(),
                certificate_id: certificate_id.clone(),
                issuer_domain: university.website_domain.clone(),
                issuer_address: caller,
                isActive: true,
            };

            self.certificates.write(certificate_id, new_certificate.clone());
            self.emit(Event::certificate_issued(new_certificate));
        }

        // Function to issue multiple certificates at once by a registered university
        fn bulk_issue_certificates(
            ref self: ContractState,
            certificate_meta_data_array: Array<ByteArray>,
            hashed_key_array: Array<ByteArray>,
            certificate_id_array: Array<felt252>,
        ) {
            let caller = get_caller_address();

            let university = self.university.read(caller);
            let zero_address = contract_address_const::<0>();
            assert(university.wallet_address != zero_address, 'University not registered');

            let len = certificate_id_array.len();
            assert(certificate_meta_data_array.len() == len, 'Arrays length mismatch');
            assert(hashed_key_array.len() == len, 'Arrays length mismatch');

            let mut i: u32 = 0;
            while i != len {
                let certificate_meta_data = certificate_meta_data_array.at(i).clone();
                let hashed_key = hashed_key_array.at(i).clone();
                let certificate_id = certificate_id_array.at(i).clone();

                let new_certificate = Certificate {
                    certificate_meta_data: certificate_meta_data,
                    hashed_key: hashed_key,
                    certificate_id: certificate_id,
                    issuer_domain: university.website_domain.clone(),
                    issuer_address: caller,
                    isActive: true,
                };

                self.certificates.write(certificate_id, new_certificate);

                i += 1;
            }

            let count_felt: felt252 = len.into();

            self
                .emit(
                    Event::certificates_bulk_issued(
                        BulkCertificatesIssued { count: count_felt, issuer: caller },
                    ),
                );
        }

        // Function to get certificate details by certificate ID
        fn get_certificate(self: @ContractState, certificate_id: felt252) -> Certificate {
            self.certificates.read(certificate_id)
        }

        // Function to get Certificate details by issuer address
        fn get_certicate_by_issuer(ref self: ContractState) -> Array<Certificate> {
            let caller = get_caller_address();
            let mut certificates_by_issuer: Array<Certificate> = ArrayTrait::new();
            let mut found: bool = false;

            let mut i: usize = 1;
            let max_iterations: usize = 101;
            while i != max_iterations {
                let certificate = self.certificates.read(i.into());
                if certificate.issuer_address == caller {
                    certificates_by_issuer.append(certificate);
                    found = true;
                }

                i = i + 1;
            }

            if found {
                self.emit(Event::CertificateFound(CertificateFound { issuer: caller }));
            } else {
                self.emit(Event::CertificateNotFound(CertificateNotFound { issuer: caller }));
            }

            certificates_by_issuer
        }

        fn revoke_certificate(
            ref self: ContractState, certificate_id: felt252,
        ) -> Result<(), felt252> {
            let caller = get_caller_address();

            // Check if caller is a registered university
            let university = self.university.read(caller);
            let zero_address = contract_address_const::<0>();
            if university.wallet_address == zero_address {
                return Result::Err('University not registered');
            }

            // Get certificate and verify it exists
            let mut certificate = self.certificates.read(certificate_id);
            if certificate.certificate_id == 0 {
                return Result::Err('Certificate not found');
            }

            // Verify the caller is the issuer and domains match
            if certificate.issuer_address != caller {
                return Result::Err('Not certificate issuer');
            }
            if certificate.issuer_domain != university.website_domain {
                return Result::Err('Domain mismatch');
            }

            // Revoke the certificate
            certificate.isActive = false;
            self.certificates.write(certificate_id, certificate);

            // Emit event
            self
                .emit(
                    Event::CertificateRevoked(
                        CertificateRevoked { certificate_id, issuer: caller },
                    ),
                );

            Result::Ok(())
        }
    }
}
