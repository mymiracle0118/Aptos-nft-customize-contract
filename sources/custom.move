/// This defines a minimally viable token for no-code solutions akin to the original token at
/// 0x3::token module.
/// The key features are:
/// * Base token and collection features
/// * Creator definable mutability for tokens
/// * Creator-based freezing of tokens
/// * Standard object-based transfer and events
/// * Metadata property type
module custom::aptos_token {
    use std::error;
    use std::option::{Self, Option, some};
    use std::string::{Self, String};
    use std::signer;
    use aptos_framework::object::{Self, ConstructorRef, Object};
    use aptos_framework::event;
    use aptos_framework::timestamp;
    use aptos_token_objects::collection;
    use aptos_token_objects::property_map;
    use aptos_token_objects::royalty;
    use aptos_token_objects::token;
    use aptos_std::table::{Self, Table};

    /// The collection does not exist
    const ECOLLECTION_DOES_NOT_EXIST: u64 = 1;
    /// The token does not exist
    const ETOKEN_DOES_NOT_EXIST: u64 = 2;
    /// The provided signer is not the creator
    const ENOT_CREATOR: u64 = 3;
    /// The field being changed is not mutable
    const EFIELD_NOT_MUTABLE: u64 = 4;
    /// The token being burned is not burnable
    const ETOKEN_NOT_BURNABLE: u64 = 5;
    /// The property map being mutated is not mutable
    const EPROPERTIES_NOT_MUTABLE: u64 = 6;
    /// Cannot buy nft because sale time is not yet
    const ESALE_UNACTIVAE_TIME: u64 = 7;
    /// Cannot buy nft because fund is not enough
    const EINCORRECT_FUNDS: u64 = 8;
    /// Not initialized yet
    const ENOT_INITIALIZED: u64 = 9;
    /// Not Found Collection
    const ECOLLECTION_NOT_FOUND: u64 = 10;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Storage state for managing the no-code Collection.
    struct AptosCollection has key {
        /// Used to mutate collection fields
        mutator_ref: Option<collection::MutatorRef>,
        /// Used to mutate royalties
        royalty_mutator_ref: Option<royalty::MutatorRef>,
        /// Determines if the creator can mutate the collection's description
        mutable_description: bool,
        /// Determines if the creator can mutate the collection's uri
        mutable_uri: bool,
        /// Determines if the creator can mutate token descriptions
        mutable_token_description: bool,
        /// Determines if the creator can mutate token names
        mutable_token_name: bool,
        /// Determines if the creator can mutate token properties
        mutable_token_properties: bool,
        /// Determines if the creator can mutate token uris
        mutable_token_uri: bool,
        /// Determines if the creator can burn tokens
        tokens_burnable_by_creator: bool,
        /// Determines if the creator can freeze tokens
        tokens_freezable_by_creator: bool,
    }
//:!:>resource
    struct CustomData has drop, store {
        symbol: String,
        /// Used to store token uri
        token_uri: String,
        /// Used to store mint limit per each transaction
        mint_per_tx: u64,
        /// Used to store mint fee per each nft
        mint_fee: u64,
        /// Used to store dev fee per each nft
        dev_fee: u64,
        /// Used to store withdraw wallet address
        withdraw_wallet: String,
        /// Used to store dev wallet address
        dev_wallet: String,
        /// Used to store sale time
        sale_time: u64,
    }
    
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct CustomHolder has key {
        custom_datas: Table<String, CustomData>
    }
//<:!:resource

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Storage state for managing the no-code Token.
    struct AptosToken has key {
        /// Used to burn.
        burn_ref: Option<token::BurnRef>,
        /// Used to control freeze.
        transfer_ref: Option<object::TransferRef>,
        /// Used to mutate fields
        mutator_ref: Option<token::MutatorRef>,
        /// Used to mutate properties
        property_mutator_ref: property_map::MutatorRef,
    }

    /// Contains the mutated fields name. This makes the life of indexers easier, so that they can
    /// directly understand the behavior in a writeset.
    struct MutationEvent has drop, store {
        mutated_field_name: String,
    }

    #[event]
    /// Contains the mutated fields name. This makes the life of indexers easier, so that they can
    /// directly understand the behavior in a writeset.
    struct Mutation has drop, store {
        mutated_field_name: String,
        collection: Object<AptosCollection>,
        old_value: String,
        new_value: String,
    }

    /// Create a new collection
    public entry fun create_collection(
        creator: &signer,
        description: String,
        name: String,
        symbol: String,
        uri: String,
        token_uri: String,
        mint_per_tx: u64,
        mint_fee: u64,
        dev_fee: u64,
        supply_limit: u64,
        withdraw_wallet: String,
        dev_wallet: String,
        sale_time: u64,
        // mutable_description: bool,
        // mutable_token_name: bool,
        // mutable_token_symbol: bool,
        // mutable_uri: bool,
        // mutable_token_uri: bool,
        // mutable_mint_per_tx: bool,

        // mutable_royalty: bool,
        // mutable_token_description: bool,
        // mutable_token_properties: bool,
        // tokens_burnable_by_creator: bool,
        // tokens_freezable_by_creator: bool,
        // royalty_numerator: u64,
        // royalty_denominator: u64,
    ) acquires CustomHolder {
        create_collection_object(
            creator,
            description,
            supply_limit,
            name,
            uri,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            0,
            1,
            symbol,
            token_uri,
            mint_per_tx,
            mint_fee,
            dev_fee,
            withdraw_wallet,
            dev_wallet,
            sale_time,
        );
    }

    public fun create_collection_object(
        creator: &signer,
        description: String,
        max_supply: u64,
        name: String,
        uri: String,
        mutable_description: bool,
        mutable_royalty: bool,
        mutable_uri: bool,
        mutable_token_description: bool,
        mutable_token_name: bool,
        mutable_token_properties: bool,
        mutable_token_uri: bool,
        tokens_burnable_by_creator: bool,
        tokens_freezable_by_creator: bool,
        royalty_numerator: u64,
        royalty_denominator: u64,
        symbol: String,
        token_uri: String,
        mint_per_tx: u64,
        mint_fee: u64,
        dev_fee: u64,
        withdraw_wallet: String,
        dev_wallet: String,
        sale_time: u64,
    ): Object<AptosCollection> acquires CustomHolder {
        let creator_addr = signer::address_of(creator);
        let royalty = royalty::create(royalty_numerator, royalty_denominator, creator_addr);
        let constructor_ref = collection::create_fixed_collection(
            creator,
            description,
            max_supply,
            name,
            option::some(royalty),
            uri,
        );

        let object_signer = object::generate_signer(&constructor_ref);
        let mutator_ref = if (mutable_description || mutable_uri) {
            option::some(collection::generate_mutator_ref(&constructor_ref))
        } else {
            option::none()
        };

        let royalty_mutator_ref = if (mutable_royalty) {
            option::some(royalty::generate_mutator_ref(object::generate_extend_ref(&constructor_ref)))
        } else {
            option::none()
        };

        let aptos_collection = AptosCollection {
            mutator_ref,
            royalty_mutator_ref,
            mutable_description,
            mutable_uri,
            mutable_token_description,
            mutable_token_name,
            mutable_token_properties,
            mutable_token_uri,
            tokens_burnable_by_creator,
            tokens_freezable_by_creator,
        };
        move_to(&object_signer, aptos_collection);

        let custom_data = CustomData {
            dev_fee,
            dev_wallet,
            mint_fee,
            mint_per_tx,
            sale_time,
            symbol,
            token_uri,
            withdraw_wallet,
        };

        if (!exists<CustomHolder>(creator_addr)) {
            move_to(creator, CustomHolder{
                custom_datas: table::new()
            })
        };
        let custom_holder = borrow_global_mut<CustomHolder>(creator_addr);
        table::add(&mut custom_holder.custom_datas, name, custom_data);

        object::object_from_constructor_ref(&constructor_ref)
    }

    public entry fun buy(
        creator: &signer,
        collection: String,
        amount: u64
    ) acquires AptosCollection /*, AptosToken */ {
        let creator_address = signer::address_of(creator);
        let collection_address = collection::create_collection_address(&creator_address, &collection);

        let aptos_collection = borrow_global<AptosCollection>(collection_address);

        // let current_time = timestamp::now_seconds();
        // assert!(
        //     aptos_collection.sale_time >= current_time,
        //     error::unavailable(ESALE_UNACTIVAE_TIME),
        // );
        
        // let sent_funds: u128 = 10; // calcuate the amount send by 
        // let mint_fee = aptos_collection.mint_fee;
        // let dev_fee = aptos_collection.dev_fee;
        // let total_fee = mint_fee + dev_fee;
        // let mint_per_tx = aptos_collection.mint_per_tx;
        // let withdraw_wallet = aptos_collection.withdraw_wallet;
        // let dev_wallet = aptos_collection.dev_wallet;

        // assert!(sent_funds >= (amount as u128) * (total_fee as u128), error::unavailable(EINCORRECT_FUNDS));

        // // let supply_limit = collection.max_supply;
        // let total_supply = collection::count(object::address_to_object<collection::Collection>(collection_address));
        // mint_token_object(creator, collection, description, name, uri, property_keys, property_types, property_values);
    }
    /// With an existing collection, directly mint a viable token into the creators account.
    public entry fun mint(
        creator: &signer,
        collection: String,
        description: String,
        name: String,
        uri: String,
        property_keys: vector<String>,
        property_types: vector<String>,
        property_values: vector<vector<u8>>,
    ) acquires AptosCollection, AptosToken {
        mint_token_object(creator, collection, description, name, uri, property_keys, property_types, property_values);
    }

    /// Mint a token into an existing collection, and retrieve the object / address of the token.
    public fun mint_token_object(
        creator: &signer,
        collection: String,
        description: String,
        name: String,
        uri: String,
        property_keys: vector<String>,
        property_types: vector<String>,
        property_values: vector<vector<u8>>,
    ): Object<AptosToken> acquires AptosCollection, AptosToken {
        let constructor_ref = mint_internal(
            creator,
            collection,
            description,
            name,
            uri,
            property_keys,
            property_types,
            property_values,
        );

        let collection = collection_object(creator, &collection);

        // If tokens are freezable, add a transfer ref to be able to freeze transfers
        let freezable_by_creator = are_collection_tokens_freezable(collection);
        if (freezable_by_creator) {
            let aptos_token_addr = object::address_from_constructor_ref(&constructor_ref);
            let aptos_token = borrow_global_mut<AptosToken>(aptos_token_addr);
            let transfer_ref = object::generate_transfer_ref(&constructor_ref);
            option::fill(&mut aptos_token.transfer_ref, transfer_ref);
        };

        object::object_from_constructor_ref(&constructor_ref)
    }

    /// With an existing collection, directly mint a soul bound token into the recipient's account.
    public entry fun mint_soul_bound(
        creator: &signer,
        collection: String,
        description: String,
        name: String,
        uri: String,
        property_keys: vector<String>,
        property_types: vector<String>,
        property_values: vector<vector<u8>>,
        soul_bound_to: address,
    ) acquires AptosCollection {
        mint_soul_bound_token_object(
            creator,
            collection,
            description,
            name,
            uri,
            property_keys,
            property_types,
            property_values,
            soul_bound_to
        );
    }

    /// With an existing collection, directly mint a soul bound token into the recipient's account.
    public fun mint_soul_bound_token_object(
        creator: &signer,
        collection: String,
        description: String,
        name: String,
        uri: String,
        property_keys: vector<String>,
        property_types: vector<String>,
        property_values: vector<vector<u8>>,
        soul_bound_to: address,
    ): Object<AptosToken> acquires AptosCollection {
        let constructor_ref = mint_internal(
            creator,
            collection,
            description,
            name,
            uri,
            property_keys,
            property_types,
            property_values,
        );

        let transfer_ref = object::generate_transfer_ref(&constructor_ref);
        let linear_transfer_ref = object::generate_linear_transfer_ref(&transfer_ref);
        object::transfer_with_ref(linear_transfer_ref, soul_bound_to);
        object::disable_ungated_transfer(&transfer_ref);

        object::object_from_constructor_ref(&constructor_ref)
    }

    fun mint_internal(
        creator: &signer,
        collection: String,
        description: String,
        name: String,
        uri: String,
        property_keys: vector<String>,
        property_types: vector<String>,
        property_values: vector<vector<u8>>,
    ): ConstructorRef acquires AptosCollection {
        let constructor_ref = token::create(creator, collection, description, name, option::none(), uri);

        let object_signer = object::generate_signer(&constructor_ref);

        let collection_obj = collection_object(creator, &collection);
        let collection = borrow_collection(&collection_obj);

        let mutator_ref = if (
            collection.mutable_token_description
                || collection.mutable_token_name
                || collection.mutable_token_uri
        ) {
            option::some(token::generate_mutator_ref(&constructor_ref))
        } else {
            option::none()
        };

        let burn_ref = if (collection.tokens_burnable_by_creator) {
            option::some(token::generate_burn_ref(&constructor_ref))
        } else {
            option::none()
        };

        let aptos_token = AptosToken {
            burn_ref,
            transfer_ref: option::none(),
            mutator_ref,
            property_mutator_ref: property_map::generate_mutator_ref(&constructor_ref),
        };
        move_to(&object_signer, aptos_token);

        let properties = property_map::prepare_input(property_keys, property_types, property_values);
        property_map::init(&constructor_ref, properties);

        constructor_ref
    }

    // Token accessors

    inline fun borrow<T: key>(token: &Object<T>): &AptosToken {
        let token_address = object::object_address(token);
        assert!(
            exists<AptosToken>(token_address),
            error::not_found(ETOKEN_DOES_NOT_EXIST),
        );
        borrow_global<AptosToken>(token_address)
    }

    #[view]
    public fun are_properties_mutable<T: key>(token: Object<T>): bool acquires AptosCollection {
        let collection = token::collection_object(token);
        borrow_collection(&collection).mutable_token_properties
    }

    #[view]
    public fun is_burnable<T: key>(token: Object<T>): bool acquires AptosToken {
        option::is_some(&borrow(&token).burn_ref)
    }

    #[view]
    public fun is_freezable_by_creator<T: key>(token: Object<T>): bool acquires AptosCollection {
        are_collection_tokens_freezable(token::collection_object(token))
    }

    #[view]
    public fun is_mutable_description<T: key>(token: Object<T>): bool acquires AptosCollection {
        is_mutable_collection_token_description(token::collection_object(token))
    }

    #[view]
    public fun is_mutable_name<T: key>(token: Object<T>): bool acquires AptosCollection {
        is_mutable_collection_token_name(token::collection_object(token))
    }

    #[view]
    public fun is_mutable_uri<T: key>(token: Object<T>): bool acquires AptosCollection {
        is_mutable_collection_token_uri(token::collection_object(token))
    }

    #[view]
    public fun get_symbol(addr: address, collection: String): String acquires CustomHolder {
        assert!(exists<CustomHolder>(addr), error::not_found(ENOT_INITIALIZED));
        let holder = borrow_global<CustomHolder>(addr);
        assert!(table::contains(&holder.custom_datas, collection), error::not_found(ECOLLECTION_NOT_FOUND));
        let custom_data = table::borrow(&holder.custom_datas, collection);
        custom_data.symbol
    }

    #[view]
    public fun get_token_uri(addr: address, collection: String): String acquires CustomHolder {
        assert!(exists<CustomHolder>(addr), error::not_found(ENOT_INITIALIZED));
        let holder = borrow_global<CustomHolder>(addr);
        assert!(table::contains(&holder.custom_datas, collection), error::not_found(ECOLLECTION_NOT_FOUND));
        let custom_data = table::borrow(&holder.custom_datas, collection);
        custom_data.token_uri
    }
    
    #[view]
    public fun get_mint_per_tx(addr: address, collection: String): u64 acquires CustomHolder {
        assert!(exists<CustomHolder>(addr), error::not_found(ENOT_INITIALIZED));
        let holder = borrow_global<CustomHolder>(addr);
        assert!(table::contains(&holder.custom_datas, collection), error::not_found(ECOLLECTION_NOT_FOUND));
        let custom_data = table::borrow(&holder.custom_datas, collection);
        custom_data.mint_per_tx
    }
    
    #[view]
    public fun get_mint_fee(addr: address, collection: String): u64 acquires CustomHolder {
        assert!(exists<CustomHolder>(addr), error::not_found(ENOT_INITIALIZED));
        let holder = borrow_global<CustomHolder>(addr);
        assert!(table::contains(&holder.custom_datas, collection), error::not_found(ECOLLECTION_NOT_FOUND));
        let custom_data = table::borrow(&holder.custom_datas, collection);
        custom_data.mint_fee
    }

    #[view]
    public fun get_dev_fee(addr: address, collection: String): u64 acquires CustomHolder {
        assert!(exists<CustomHolder>(addr), error::not_found(ENOT_INITIALIZED));
        let holder = borrow_global<CustomHolder>(addr);
        assert!(table::contains(&holder.custom_datas, collection), error::not_found(ECOLLECTION_NOT_FOUND));
        let custom_data = table::borrow(&holder.custom_datas, collection);
        custom_data.dev_fee
    }

    #[view]
    public fun get_withdraw_wallet(addr: address, collection: String): String acquires CustomHolder {
        assert!(exists<CustomHolder>(addr), error::not_found(ENOT_INITIALIZED));
        let holder = borrow_global<CustomHolder>(addr);
        assert!(table::contains(&holder.custom_datas, collection), error::not_found(ECOLLECTION_NOT_FOUND));
        let custom_data = table::borrow(&holder.custom_datas, collection);
        custom_data.withdraw_wallet
    }

    #[view]
    public fun get_dev_wallet(addr: address, collection: String): String acquires CustomHolder {
        assert!(exists<CustomHolder>(addr), error::not_found(ENOT_INITIALIZED));
        let holder = borrow_global<CustomHolder>(addr);
        assert!(table::contains(&holder.custom_datas, collection), error::not_found(ECOLLECTION_NOT_FOUND));
        let custom_data = table::borrow(&holder.custom_datas, collection);
        custom_data.dev_wallet
    }

    #[view]
    public fun get_sale_time(addr: address, collection: String): u64 acquires CustomHolder {
        assert!(exists<CustomHolder>(addr), error::not_found(ENOT_INITIALIZED));
        let holder = borrow_global<CustomHolder>(addr);
        assert!(table::contains(&holder.custom_datas, collection), error::not_found(ECOLLECTION_NOT_FOUND));
        let custom_data = table::borrow(&holder.custom_datas, collection);
        custom_data.sale_time
    }

    // Token mutators

    inline fun authorized_borrow<T: key>(token: &Object<T>, creator: &signer): &AptosToken {
        let token_address = object::object_address(token);
        assert!(
            exists<AptosToken>(token_address),
            error::not_found(ETOKEN_DOES_NOT_EXIST),
        );

        assert!(
            token::creator(*token) == signer::address_of(creator),
            error::permission_denied(ENOT_CREATOR),
        );
        borrow_global<AptosToken>(token_address)
    }

    public entry fun burn<T: key>(creator: &signer, token: Object<T>) acquires AptosToken {
        let aptos_token = authorized_borrow(&token, creator);
        assert!(
            option::is_some(&aptos_token.burn_ref),
            error::permission_denied(ETOKEN_NOT_BURNABLE),
        );
        move aptos_token;
        let aptos_token = move_from<AptosToken>(object::object_address(&token));
        let AptosToken {
            burn_ref,
            transfer_ref: _,
            mutator_ref: _,
            property_mutator_ref,
        } = aptos_token;
        property_map::burn(property_mutator_ref);
        token::burn(option::extract(&mut burn_ref));
    }

    public entry fun freeze_transfer<T: key>(creator: &signer, token: Object<T>) acquires AptosCollection, AptosToken {
        let aptos_token = authorized_borrow(&token, creator);
        assert!(
            are_collection_tokens_freezable(token::collection_object(token))
                && option::is_some(&aptos_token.transfer_ref),
            error::permission_denied(EFIELD_NOT_MUTABLE),
        );
        object::disable_ungated_transfer(option::borrow(&aptos_token.transfer_ref));
    }

    public entry fun unfreeze_transfer<T: key>(
        creator: &signer,
        token: Object<T>
    ) acquires AptosCollection, AptosToken {
        let aptos_token = authorized_borrow(&token, creator);
        assert!(
            are_collection_tokens_freezable(token::collection_object(token))
                && option::is_some(&aptos_token.transfer_ref),
            error::permission_denied(EFIELD_NOT_MUTABLE),
        );
        object::enable_ungated_transfer(option::borrow(&aptos_token.transfer_ref));
    }

    public entry fun set_description<T: key>(
        creator: &signer,
        token: Object<T>,
        description: String,
    ) acquires AptosCollection, AptosToken {
        assert!(
            is_mutable_description(token),
            error::permission_denied(EFIELD_NOT_MUTABLE),
        );
        let aptos_token = authorized_borrow(&token, creator);
        token::set_description(option::borrow(&aptos_token.mutator_ref), description);
    }

    public entry fun set_name<T: key>(
        creator: &signer,
        token: Object<T>,
        collection_name: String,
    ) acquires AptosToken {
        let aptos_token = authorized_borrow(&token, creator);
        token::set_name(option::borrow(&aptos_token.mutator_ref), collection_name);
    }

    public entry fun set_uri<T: key>(
        creator: &signer,
        token: Object<T>,
        uri: String,
    ) acquires AptosCollection, AptosToken {
        assert!(
            is_mutable_uri(token),
            error::permission_denied(EFIELD_NOT_MUTABLE),
        );
        let aptos_token = authorized_borrow(&token, creator);
        token::set_uri(option::borrow(&aptos_token.mutator_ref), uri);
    }

    public entry fun set_symbol(
        creator: &signer,
        collection: String,
        symbol: String
    ) acquires CustomHolder {
        let account_addr = signer::address_of(creator);
        assert!(exists<CustomHolder>(account_addr), error::not_found(ENOT_INITIALIZED));
        let custom_datas = &mut borrow_global_mut<CustomHolder>(account_addr).custom_datas;
        let custom_data = table::borrow_mut(custom_datas, collection);
        custom_data.symbol = symbol;
    }

    public entry fun set_token_uri(
        creator: &signer,
        collection: String,
        token_uri: String
    ) acquires CustomHolder {
        let account_addr = signer::address_of(creator);
        assert!(exists<CustomHolder>(account_addr), error::not_found(ENOT_INITIALIZED));
        let custom_datas = &mut borrow_global_mut<CustomHolder>(account_addr).custom_datas;
        let custom_data = table::borrow_mut(custom_datas, collection);
        custom_data.token_uri = token_uri;
    }

    public entry fun set_mint_per_tx(
        creator: &signer,
        collection: String,
        mint_per_tx: u64
    ) acquires CustomHolder {
        let account_addr = signer::address_of(creator);
        assert!(exists<CustomHolder>(account_addr), error::not_found(ENOT_INITIALIZED));
        let custom_datas = &mut borrow_global_mut<CustomHolder>(account_addr).custom_datas;
        let custom_data = table::borrow_mut(custom_datas, collection);
        custom_data.mint_per_tx = mint_per_tx;
    }

    public entry fun set_mint_fee(
        creator: &signer,
        collection: String,
        mint_fee: u64
    ) acquires CustomHolder {
        let account_addr = signer::address_of(creator);
        assert!(exists<CustomHolder>(account_addr), error::not_found(ENOT_INITIALIZED));
        let custom_datas = &mut borrow_global_mut<CustomHolder>(account_addr).custom_datas;
        let custom_data = table::borrow_mut(custom_datas, collection);
        custom_data.mint_fee = mint_fee;
    }

    public entry fun set_dev_fee(
        creator: &signer,
        collection: String,
        dev_fee: u64
    ) acquires CustomHolder {
        let account_addr = signer::address_of(creator);
        assert!(exists<CustomHolder>(account_addr), error::not_found(ENOT_INITIALIZED));
        let custom_datas = &mut borrow_global_mut<CustomHolder>(account_addr).custom_datas;
        let custom_data = table::borrow_mut(custom_datas, collection);
        custom_data.dev_fee = dev_fee;
    }

    public entry fun set_withdraw_wallet(
        creator: &signer,
        collection: String,
        withdraw_wallet: String
    ) acquires CustomHolder {
        let account_addr = signer::address_of(creator);
        assert!(exists<CustomHolder>(account_addr), error::not_found(ENOT_INITIALIZED));
        let custom_datas = &mut borrow_global_mut<CustomHolder>(account_addr).custom_datas;
        let custom_data = table::borrow_mut(custom_datas, collection);
        custom_data.withdraw_wallet = withdraw_wallet;
    }

    public entry fun set_dev_wallet(
        creator: &signer,
        collection: String,
        dev_wallet: String
    ) acquires CustomHolder {
        let account_addr = signer::address_of(creator);
        assert!(exists<CustomHolder>(account_addr), error::not_found(ENOT_INITIALIZED));
        let custom_datas = &mut borrow_global_mut<CustomHolder>(account_addr).custom_datas;
        let custom_data = table::borrow_mut(custom_datas, collection);
        custom_data.dev_wallet = dev_wallet;
    }
    
    public entry fun set_sale_time(
        creator: &signer,
        collection: String,
        sale_time: u64
    ) acquires CustomHolder {
        let account_addr = signer::address_of(creator);
        assert!(exists<CustomHolder>(account_addr), error::not_found(ENOT_INITIALIZED));
        let custom_datas = &mut borrow_global_mut<CustomHolder>(account_addr).custom_datas;
        let custom_data = table::borrow_mut(custom_datas, collection);
        custom_data.sale_time = sale_time;
    }

    public entry fun add_property<T: key>(
        creator: &signer,
        token: Object<T>,
        key: String,
        type: String,
        value: vector<u8>,
    ) acquires AptosCollection, AptosToken {
        let aptos_token = authorized_borrow(&token, creator);
        assert!(
            are_properties_mutable(token),
            error::permission_denied(EPROPERTIES_NOT_MUTABLE),
        );

        property_map::add(&aptos_token.property_mutator_ref, key, type, value);
    }

    public entry fun add_typed_property<T: key, V: drop>(
        creator: &signer,
        token: Object<T>,
        key: String,
        value: V,
    ) acquires AptosCollection, AptosToken {
        let aptos_token = authorized_borrow(&token, creator);
        assert!(
            are_properties_mutable(token),
            error::permission_denied(EPROPERTIES_NOT_MUTABLE),
        );

        property_map::add_typed(&aptos_token.property_mutator_ref, key, value);
    }

    public entry fun remove_property<T: key>(
        creator: &signer,
        token: Object<T>,
        key: String,
    ) acquires AptosCollection, AptosToken {
        let aptos_token = authorized_borrow(&token, creator);
        assert!(
            are_properties_mutable(token),
            error::permission_denied(EPROPERTIES_NOT_MUTABLE),
        );

        property_map::remove(&aptos_token.property_mutator_ref, &key);
    }

    public entry fun update_property<T: key>(
        creator: &signer,
        token: Object<T>,
        key: String,
        type: String,
        value: vector<u8>,
    ) acquires AptosCollection, AptosToken {
        let aptos_token = authorized_borrow(&token, creator);
        assert!(
            are_properties_mutable(token),
            error::permission_denied(EPROPERTIES_NOT_MUTABLE),
        );

        property_map::update(&aptos_token.property_mutator_ref, &key, type, value);
    }

    public entry fun update_typed_property<T: key, V: drop>(
        creator: &signer,
        token: Object<T>,
        key: String,
        value: V,
    ) acquires AptosCollection, AptosToken {
        let aptos_token = authorized_borrow(&token, creator);
        assert!(
            are_properties_mutable(token),
            error::permission_denied(EPROPERTIES_NOT_MUTABLE),
        );

        property_map::update_typed(&aptos_token.property_mutator_ref, &key, value);
    }

    // Collection accessors

    inline fun collection_object(creator: &signer, name: &String): Object<AptosCollection> {
        let collection_addr = collection::create_collection_address(&signer::address_of(creator), name);
        object::address_to_object<AptosCollection>(collection_addr)
    }

    inline fun borrow_collection<T: key>(token: &Object<T>): &AptosCollection {
        let collection_address = object::object_address(token);
        assert!(
            exists<AptosCollection>(collection_address),
            error::not_found(ECOLLECTION_DOES_NOT_EXIST),
        );
        borrow_global<AptosCollection>(collection_address)
    }

    public fun is_mutable_collection_description<T: key>(
        collection: Object<T>,
    ): bool acquires AptosCollection {
        borrow_collection(&collection).mutable_description
    }

    public fun is_mutable_collection_royalty<T: key>(
        collection: Object<T>,
    ): bool acquires AptosCollection {
        option::is_some(&borrow_collection(&collection).royalty_mutator_ref)
    }

    public fun is_mutable_collection_uri<T: key>(
        collection: Object<T>,
    ): bool acquires AptosCollection {
        borrow_collection(&collection).mutable_uri
    }

    public fun is_mutable_collection_token_description<T: key>(
        collection: Object<T>,
    ): bool acquires AptosCollection {
        borrow_collection(&collection).mutable_token_description
    }

    public fun is_mutable_collection_token_name<T: key>(
        collection: Object<T>,
    ): bool acquires AptosCollection {
        borrow_collection(&collection).mutable_token_name
    }

    public fun is_mutable_collection_token_uri<T: key>(
        collection: Object<T>,
    ): bool acquires AptosCollection {
        borrow_collection(&collection).mutable_token_uri
    }

    public fun is_mutable_collection_token_properties<T: key>(
        collection: Object<T>,
    ): bool acquires AptosCollection {
        borrow_collection(&collection).mutable_token_properties
    }

    public fun are_collection_tokens_burnable<T: key>(
        collection: Object<T>,
    ): bool acquires AptosCollection {
        borrow_collection(&collection).tokens_burnable_by_creator
    }

    public fun are_collection_tokens_freezable<T: key>(
        collection: Object<T>,
    ): bool acquires AptosCollection {
        borrow_collection(&collection).tokens_freezable_by_creator
    }

    // Collection mutators

    inline fun authorized_borrow_collection<T: key>(collection: &Object<T>, creator: &signer): &AptosCollection {
        let collection_address = object::object_address(collection);
        assert!(
            exists<AptosCollection>(collection_address),
            error::not_found(ECOLLECTION_DOES_NOT_EXIST),
        );
        assert!(
            collection::creator(*collection) == signer::address_of(creator),
            error::permission_denied(ENOT_CREATOR),
        );
        borrow_global<AptosCollection>(collection_address)
    }

    public entry fun set_collection_description<T: key>(
        creator: &signer,
        collection: Object<T>,
        description: String,
    ) acquires AptosCollection {
        let aptos_collection = authorized_borrow_collection(&collection, creator);
        assert!(
            aptos_collection.mutable_description,
            error::permission_denied(EFIELD_NOT_MUTABLE),
        );
        collection::set_description(option::borrow(&aptos_collection.mutator_ref), description);
    }

    public entry fun set_supply_limit<T: key>(
        creator: &signer,
        collection: Object<T>,
        supply_limit: u64,
    ) acquires AptosCollection {
        let aptos_collection = authorized_borrow_collection(&collection, creator);
        collection::set_max_supply(option::borrow(&aptos_collection.mutator_ref), supply_limit);
    }

    public fun set_collection_royalties<T: key>(
        creator: &signer,
        collection: Object<T>,
        royalty: royalty::Royalty,
    ) acquires AptosCollection {
        let aptos_collection = authorized_borrow_collection(&collection, creator);
        assert!(
            option::is_some(&aptos_collection.royalty_mutator_ref),
            error::permission_denied(EFIELD_NOT_MUTABLE),
        );
        royalty::update(option::borrow(&aptos_collection.royalty_mutator_ref), royalty);
    }

    entry fun set_collection_royalties_call<T: key>(
        creator: &signer,
        collection: Object<T>,
        royalty_numerator: u64,
        royalty_denominator: u64,
        payee_address: address,
    ) acquires AptosCollection {
        let royalty = royalty::create(royalty_numerator, royalty_denominator, payee_address);
        set_collection_royalties(creator, collection, royalty);
    }

    public entry fun set_collection_uri<T: key>(
        creator: &signer,
        collection: Object<T>,
        uri: String,
    ) acquires AptosCollection {
        let aptos_collection = authorized_borrow_collection(&collection, creator);
        assert!(
            aptos_collection.mutable_uri,
            error::permission_denied(EFIELD_NOT_MUTABLE),
        );
        collection::set_uri(option::borrow(&aptos_collection.mutator_ref), uri);
    }

    // Tests

    #[test_only]
    use aptos_framework::account;

    #[test(creator = @0x123)]
    fun test_create_and_transfer(creator: &signer) acquires AptosCollection, AptosToken {
        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);

        assert!(object::owner(token) == signer::address_of(creator), 1);
        object::transfer(creator, token, @0x345);
        assert!(object::owner(token) == @0x345, 1);
    }

    #[test(creator = @0x123, bob = @0x456)]
    #[expected_failure(abort_code = 0x50003, location = object)]
    fun test_mint_soul_bound(creator: &signer, bob: &signer) acquires AptosCollection {
        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, false);

        let creator_addr = signer::address_of(creator);
        account::create_account_for_test(creator_addr);

        let token = mint_soul_bound_token_object(
            creator,
            collection_name,
            string::utf8(b""),
            token_name,
            string::utf8(b""),
            vector[],
            vector[],
            vector[],
            signer::address_of(bob),
        );

        object::transfer(bob, token, @0x345);
    }

    #[test(creator = @0x123)]
    #[expected_failure(abort_code = 0x50003, location = object)]
    fun test_frozen_transfer(creator: &signer) acquires AptosCollection, AptosToken {
        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);
        freeze_transfer(creator, token);
        object::transfer(creator, token, @0x345);
    }

    #[test(creator = @0x123)]
    fun test_unfrozen_transfer(creator: &signer) acquires AptosCollection, AptosToken {
        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);
        freeze_transfer(creator, token);
        unfreeze_transfer(creator, token);
        object::transfer(creator, token, @0x345);
    }

    #[test(creator = @0x123, another = @0x456)]
    #[expected_failure(abort_code = 0x50003, location = Self)]
    fun test_noncreator_freeze(creator: &signer, another: &signer) acquires AptosCollection, AptosToken {
        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);
        freeze_transfer(another, token);
    }

    #[test(creator = @0x123, another = @0x456)]
    #[expected_failure(abort_code = 0x50003, location = Self)]
    fun test_noncreator_unfreeze(creator: &signer, another: &signer) acquires AptosCollection, AptosToken {
        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);
        freeze_transfer(creator, token);
        unfreeze_transfer(another, token);
    }

    #[test(creator = @0x123)]
    fun test_set_description(creator: &signer) acquires AptosCollection, AptosToken {
        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);

        let description = string::utf8(b"not");
        assert!(token::description(token) != description, 0);
        set_description(creator, token, description);
        assert!(token::description(token) == description, 1);
    }

    #[test(creator = @0x123)]
    #[expected_failure(abort_code = 0x50004, location = Self)]
    fun test_set_immutable_description(creator: &signer) acquires AptosCollection, AptosToken {
        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, false);
        let token = mint_helper(creator, collection_name, token_name);

        set_description(creator, token, string::utf8(b""));
    }

    #[test(creator = @0x123, noncreator = @0x456)]
    #[expected_failure(abort_code = 0x50003, location = Self)]
    fun test_set_description_non_creator(
        creator: &signer,
        noncreator: &signer,
    ) acquires AptosCollection, AptosToken {
        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);

        let description = string::utf8(b"not");
        set_description(noncreator, token, description);
    }

    #[test(creator = @0x123)]
    fun test_set_name(creator: &signer) acquires AptosCollection, AptosToken {
        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);

        let name = string::utf8(b"not");
        assert!(token::name(token) != name, 0);
        set_name(creator, token, name);
        assert!(token::name(token) == name, 1);
    }

    #[test(creator = @0x123)]
    #[expected_failure]
    fun test_set_immutable_name(creator: &signer) acquires AptosCollection, AptosToken {
        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, false);
        let token = mint_helper(creator, collection_name, token_name);

        set_name(creator, token, string::utf8(b""));
    }

    #[test(creator = @0x123, noncreator = @0x456)]
    #[expected_failure(abort_code = 0x50003, location = Self)]
    fun test_set_name_non_creator(
        creator: &signer,
        noncreator: &signer,
    ) acquires AptosCollection, AptosToken {
        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);

        let name = string::utf8(b"not");
        set_name(noncreator, token, name);
    }

    #[test(creator = @0x123)]
    fun test_set_uri(creator: &signer) acquires AptosCollection, AptosToken {
        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);

        let uri = string::utf8(b"not");
        assert!(token::uri(token) != uri, 0);
        set_uri(creator, token, uri);
        assert!(token::uri(token) == uri, 1);
    }

    #[test(creator = @0x123)]
    #[expected_failure(abort_code = 0x50004, location = Self)]
    fun test_set_immutable_uri(creator: &signer) acquires AptosCollection, AptosToken {
        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, false);
        let token = mint_helper(creator, collection_name, token_name);

        set_uri(creator, token, string::utf8(b""));
    }

    #[test(creator = @0x123, noncreator = @0x456)]
    #[expected_failure(abort_code = 0x50003, location = Self)]
    fun test_set_uri_non_creator(
        creator: &signer,
        noncreator: &signer,
    ) acquires AptosCollection, AptosToken {
        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);

        let uri = string::utf8(b"not");
        set_uri(noncreator, token, uri);
    }

    #[test(creator = @0x123)]
    fun test_burnable(creator: &signer) acquires AptosCollection, AptosToken {
        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);
        let token_addr = object::object_address(&token);

        assert!(exists<AptosToken>(token_addr), 0);
        burn(creator, token);
        assert!(!exists<AptosToken>(token_addr), 1);
    }

    #[test(creator = @0x123)]
    #[expected_failure(abort_code = 0x50005, location = Self)]
    fun test_not_burnable(creator: &signer) acquires AptosCollection, AptosToken {
        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, false);
        let token = mint_helper(creator, collection_name, token_name);

        burn(creator, token);
    }

    #[test(creator = @0x123, noncreator = @0x456)]
    #[expected_failure(abort_code = 0x50003, location = Self)]
    fun test_burn_non_creator(
        creator: &signer,
        noncreator: &signer,
    ) acquires AptosCollection, AptosToken {
        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);

        burn(noncreator, token);
    }

    #[test(creator = @0x123)]
    fun test_set_collection_description(creator: &signer) acquires AptosCollection {
        let collection_name = string::utf8(b"collection name");
        let collection = create_collection_helper(creator, collection_name, true);
        let value = string::utf8(b"not");
        assert!(collection::description(collection) != value, 0);
        set_collection_description(creator, collection, value);
        assert!(collection::description(collection) == value, 1);
    }

    #[test(creator = @0x123)]
    #[expected_failure(abort_code = 0x50004, location = Self)]
    fun test_set_immutable_collection_description(creator: &signer) acquires AptosCollection {
        let collection_name = string::utf8(b"collection name");
        let collection = create_collection_helper(creator, collection_name, false);
        set_collection_description(creator, collection, string::utf8(b""));
    }

    #[test(creator = @0x123, noncreator = @0x456)]
    #[expected_failure(abort_code = 0x50003, location = Self)]
    fun test_set_collection_description_non_creator(
        creator: &signer,
        noncreator: &signer,
    ) acquires AptosCollection {
        let collection_name = string::utf8(b"collection name");
        let collection = create_collection_helper(creator, collection_name, true);
        set_collection_description(noncreator, collection, string::utf8(b""));
    }

    #[test(creator = @0x123)]
    fun test_set_collection_uri(creator: &signer) acquires AptosCollection {
        let collection_name = string::utf8(b"collection name");
        let collection = create_collection_helper(creator, collection_name, true);
        let value = string::utf8(b"not");
        assert!(collection::uri(collection) != value, 0);
        set_collection_uri(creator, collection, value);
        assert!(collection::uri(collection) == value, 1);
    }

    #[test(creator = @0x123)]
    #[expected_failure(abort_code = 0x50004, location = Self)]
    fun test_set_immutable_collection_uri(creator: &signer) acquires AptosCollection {
        let collection_name = string::utf8(b"collection name");
        let collection = create_collection_helper(creator, collection_name, false);
        set_collection_uri(creator, collection, string::utf8(b""));
    }

    #[test(creator = @0x123, noncreator = @0x456)]
    #[expected_failure(abort_code = 0x50003, location = Self)]
    fun test_set_collection_uri_non_creator(
        creator: &signer,
        noncreator: &signer,
    ) acquires AptosCollection {
        let collection_name = string::utf8(b"collection name");
        let collection = create_collection_helper(creator, collection_name, true);
        set_collection_uri(noncreator, collection, string::utf8(b""));
    }

    #[test(creator = @0x123)]
    fun test_property_add(creator: &signer) acquires AptosCollection, AptosToken {
        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");
        let property_name = string::utf8(b"u8");
        let property_type = string::utf8(b"u8");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);
        add_property(creator, token, property_name, property_type, vector [ 0x08 ]);

        assert!(property_map::read_u8(&token, &property_name) == 0x8, 0);
    }

    #[test(creator = @0x123)]
    fun test_property_typed_add(creator: &signer) acquires AptosCollection, AptosToken {
        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");
        let property_name = string::utf8(b"u8");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);
        add_typed_property<AptosToken, u8>(creator, token, property_name, 0x8);

        assert!(property_map::read_u8(&token, &property_name) == 0x8, 0);
    }

    #[test(creator = @0x123)]
    fun test_property_update(creator: &signer) acquires AptosCollection, AptosToken {
        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");
        let property_name = string::utf8(b"bool");
        let property_type = string::utf8(b"bool");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);
        update_property(creator, token, property_name, property_type, vector [ 0x00 ]);

        assert!(!property_map::read_bool(&token, &property_name), 0);
    }

    #[test(creator = @0x123)]
    fun test_property_update_typed(creator: &signer) acquires AptosCollection, AptosToken {
        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");
        let property_name = string::utf8(b"bool");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);
        update_typed_property<AptosToken, bool>(creator, token, property_name, false);

        assert!(!property_map::read_bool(&token, &property_name), 0);
    }

    #[test(creator = @0x123)]
    fun test_property_remove(creator: &signer) acquires AptosCollection, AptosToken {
        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");
        let property_name = string::utf8(b"bool");

        create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);
        remove_property(creator, token, property_name);
    }

    #[test(creator = @0x123)]
    fun test_royalties(creator: &signer) acquires AptosCollection, AptosToken {
        let collection_name = string::utf8(b"collection name");
        let token_name = string::utf8(b"token name");

        let collection = create_collection_helper(creator, collection_name, true);
        let token = mint_helper(creator, collection_name, token_name);

        let royalty_before = option::extract(&mut token::royalty(token));
        set_collection_royalties_call(creator, collection, 2, 3, @0x444);
        let royalty_after = option::extract(&mut token::royalty(token));
        assert!(royalty_before != royalty_after, 0);
    }

    #[test_only]
    fun create_collection_helper(
        creator: &signer,
        collection_name: String,
        flag: bool,
    ): Object<AptosCollection> {
        create_collection_object(
            creator,
            string::utf8(b"collection description"),
            1,
            collection_name,
            string::utf8(b"collection uri"),
            flag,
            flag,
            flag,
            flag,
            flag,
            flag,
            flag,
            flag,
            flag,
            1,
            100,
            string::utf8(b"token uri"),
            string::utf8(b"token symbol"),
            2,
            200,
            200,
            string::utf8(b"0x3c15016877b2ba1a9227f47b1e2284287c500d11b7f7f3c1d09a53282d9dd1a1"),
            string::utf8(b"0x3c15016877b2ba1a9227f47b1e2284287c500d11b7f7f3c1d09a53282d9dd1a1"),
            1700000000,
        )
    }

    #[test_only]
    fun mint_helper(
        creator: &signer,
        collection_name: String,
        token_name: String,
    ): Object<AptosToken> acquires AptosCollection, AptosToken {
        let creator_addr = signer::address_of(creator);
        account::create_account_for_test(creator_addr);

        mint_token_object(
            creator,
            collection_name,
            string::utf8(b"description"),
            token_name,
            string::utf8(b"uri"),
            vector[string::utf8(b"bool")],
            vector[string::utf8(b"bool")],
            vector[vector[0x01]],
        )
    }
}