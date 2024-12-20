module my_address::auction {
    use std::error;
    use std::option::{Self, Option};
    use std::signer;
    #[test_only]
    use std::string;
    #[test_only]
    use aptos_std::debug;

    ///deployer address is wrong
    const EWRONG_DEPLOYER_ADDRESS : u64 = 1;
    ///creator address is wrong
    const EWRONG_CREATOR_ADDRESS : u64 = 2;
    ///auction already completed
    const EAUCTION_ALREADY_COMPLETED : u64 =3;

    ///you have entered wrong auction id
    const EWRONG_AUCTION_ID : u64 = 4;

    ///current bid should be more than previous bid
    const ELESS_THAN_PREVIOUSBID : u64 = 5;

    struct Auction has key {
        creator_addr: address,
        auction_id: u64,
        item_name: vector<u8>,
        // Name of the item being auctioned
        highest_bid: u64,
        // Current highest bid
        highest_bidder: Option<address>,
        // Address of the highest bidder
        is_active: bool,
        // Auction status
    }

    struct Id has key {
        deployer_addr: address,
        id: u64
    }

    fun init_module(account: &signer) {
        let deployer_addr = signer::address_of(account);
        let id = Id {
            deployer_addr,
            id: 1
        };
        move_to(account, id)
    }

    public entry fun create_auction(account: &signer, deployer_addr:address,item_name: vector<u8>, starting_bid: u64) acquires Id {
        let creator_addr = signer::address_of(account);
        assert!(exists<Id>(deployer_addr),error::not_found(EWRONG_DEPLOYER_ADDRESS));
        let auction_id = borrow_global_mut<Id>(deployer_addr);
        let new_auction = Auction {
            auction_id: auction_id.id,
            creator_addr,
            item_name,
            highest_bid: starting_bid,
            highest_bidder: option::none<address>(),
            is_active: true
        };
        auction_id.id = auction_id.id + 1;
        move_to(account, new_auction);
    }

    public entry fun place_bid(bidder: &signer, creator: address, auction_id: u64, bid_amount: u64) acquires Auction {
        let bidder_addr = signer::address_of(bidder);
        assert!(exists<Auction>(creator),error::not_found(EWRONG_CREATOR_ADDRESS));
        let auction_details = borrow_global_mut<Auction>(creator);
        assert!(auction_details.is_active, error::permission_denied(EAUCTION_ALREADY_COMPLETED));
        assert!(auction_details.auction_id == auction_id, error::invalid_argument(EWRONG_AUCTION_ID));
        assert!(bid_amount > auction_details.highest_bid, error::invalid_argument(ELESS_THAN_PREVIOUSBID));
        auction_details.highest_bid = bid_amount;
        auction_details.highest_bidder = option::some<address>(bidder_addr);
    }

    public entry fun finalize_auction(account: &signer, auction_id: u64) acquires Auction {
        let creator_addr = signer::address_of(account);
        assert!(exists<Auction>(creator_addr), error::not_found(EWRONG_CREATOR_ADDRESS));
        let auction_details = borrow_global_mut<Auction>(creator_addr);
        assert!(auction_details.auction_id == auction_id, error::invalid_argument(EWRONG_AUCTION_ID));
        assert!(auction_details.is_active, error::permission_denied(EAUCTION_ALREADY_COMPLETED));
        auction_details.is_active = false;
    }

    #[view]
    public fun view_highest_bid(creator: address, auction_id: u64): u64 acquires Auction {
        assert!(exists<Auction>(creator), error::not_found(EWRONG_CREATOR_ADDRESS));
        let auction_details = borrow_global_mut<Auction>(creator);
        assert!(auction_details.auction_id == auction_id, error::invalid_argument(EWRONG_AUCTION_ID));
        auction_details.highest_bid
    }

    #[view]
    public fun view_status(creator : address, auction_id : u64): bool acquires Auction{
        assert!(exists<Auction>(creator), error::not_found(EWRONG_CREATOR_ADDRESS));
        let auction_details = borrow_global_mut<Auction>(creator);
        assert!(auction_details.auction_id == auction_id, error::invalid_argument(EWRONG_AUCTION_ID));
        auction_details.is_active
    }

    #[test(
        deployer = @0x1234,
        creator_1 = @0x222,
        creator_2 = @0x3333,
        bidder_1 = @0x444,
        bidder_2 = @0x555,
        bidder_3 = @0x666,
        bidder_4 = @0x777,
    )]

    public entry fun test_auction(
        deployer: signer,
        creator_1: signer,
        creator_2: signer,
        bidder_1: signer,
        bidder_2: signer,
        bidder_3: signer,
    bidder_4 : signer) acquires Id, Auction {
        let deployer_addr = signer::address_of(&deployer);
        aptos_framework::account::create_account_for_test(deployer_addr);
        let creator1_addr = signer::address_of(&creator_1);
        aptos_framework::account::create_account_for_test(creator1_addr);
        let creator2_addr = signer::address_of(&creator_2);
        aptos_framework::account::create_account_for_test(creator2_addr);
        let bidder1_addr = signer::address_of(&bidder_1);
        aptos_framework::account::create_account_for_test(bidder1_addr);
        let bidder2_addr = signer::address_of(&bidder_2);
        aptos_framework::account::create_account_for_test(bidder2_addr);
        let bidder3_addr = signer::address_of(&bidder_3);
        aptos_framework::account::create_account_for_test(bidder3_addr);
        let bidder4_addr = signer::address_of(&bidder_4);
        aptos_framework::account::create_account_for_test(bidder4_addr);

        init_module(&deployer);

        create_auction(&creator_1,deployer_addr, b"horse", 50);
        create_auction(&creator_2,deployer_addr, b"house", 100);
        let starting_bid_1 = view_highest_bid(creator1_addr , 1);
        let starting_bid_2 = view_highest_bid(creator2_addr , 2);

        //////////////////////////////////////////////////////////////////
        debug::print(&string::utf8(b"starting bid_1"));
        debug::print(&starting_bid_1);

        /////////////////////////////////////////////////////////////////
        debug::print(&string::utf8(b"starting bid_2"));
        debug::print(&starting_bid_2);

        /////////////////////////////////////////////////////////////////
        place_bid(&bidder_1,creator1_addr,1,60);
        place_bid(&bidder_2, creator1_addr , 1 , 65);

        /////////////////////////////////////////////////////////////////
        place_bid(&bidder_3,creator2_addr,2,120);
        place_bid(&bidder_4,creator2_addr,2,150);

        /////////////////////////////////////////////////////////////////
        let current_bid_1 = view_highest_bid(creator1_addr , 1);
        assert!(current_bid_1 == 65,11);
        /////////////////////////////////////////////////////////////////
        let current_bid_2 = view_highest_bid(creator2_addr , 2);
        assert!(current_bid_2 == 150,21);

        /////////////////////////////////////////////////////////////////
        finalize_auction(&creator_1,1);

        let auction_details_1 =   borrow_global<Auction>(creator1_addr);
        let auction_details_2 =   borrow_global<Auction>(creator2_addr);

        ///////////////////////////////////////////////////////////////// 11111
        assert!(auction_details_1.highest_bid == 65, 12);
        assert!(auction_details_1.is_active == false, 13);
        assert!(auction_details_1.highest_bidder == option::some<address>(bidder2_addr), 14);
        debug::print(&string::utf8(b"highest bid_1"));
        debug::print(&auction_details_1.highest_bid);
        debug::print(&string::utf8(b"highest bidder_1"));
        debug::print(&auction_details_1.highest_bidder);
        debug::print(&string::utf8(b"auction status 1"));
        debug::print(&auction_details_1.is_active);

        ///////////////////////////////////////////////////////////////// 22222
        assert!(auction_details_2.highest_bid == 150, 22);
        assert!(auction_details_2.is_active == true, 23);
        assert!(auction_details_2.highest_bidder == option::some<address>(bidder4_addr), 24);
        debug::print(&string::utf8(b"highest bid_2"));
        debug::print(&auction_details_2.highest_bid);
        debug::print(&string::utf8(b"highest bidder_2"));
        debug::print(&auction_details_2.highest_bidder);
        debug::print(&string::utf8(b"auction status 2"));
        debug::print(&auction_details_2.is_active)
    }

    #[test(
        deployer = @0x1234,
        creator_1 = @0x222,
        creator_2 = @0x3333,
    )]
    #[expected_failure(abort_code = 393217, location = Self
    )]
    public entry fun testfail_for_deployer(deployer : signer , creator_1 : signer,creator_2 : address)acquires Id {
        let deployer_addr = signer::address_of(&deployer);
        aptos_framework::account::create_account_for_test(deployer_addr);
        aptos_framework::account::create_account_for_test(signer::address_of(&creator_1));
        aptos_framework::account::create_account_for_test(creator_2);
     init_module(&deployer);
        create_auction(&creator_1,creator_2,b"horse",50)
    }

    #[test(
    deployer = @0x1234,
    creator_1 = @0x222,
    creator_2 = @0x3333,
    bidder_1 = @0x444,
    )]
    #[expected_failure(abort_code = 393218, location = Self
    )]

    public entry fun testfail_for_creator(deployer : signer, creator_1 : signer , creator_2 : address ,bidder_1 : signer) acquires Id,Auction {
        let deployer_addr = signer::address_of(&deployer);
        aptos_framework::account::create_account_for_test(deployer_addr);
        aptos_framework::account::create_account_for_test(signer::address_of(&creator_1));
        aptos_framework::account::create_account_for_test(creator_2);
        aptos_framework::account::create_account_for_test(signer::address_of(&bidder_1));

        init_module(&deployer);

        create_auction(&creator_1,deployer_addr,b"horse",50);

        place_bid(&bidder_1,creator_2,1,60)
    }

    #[test(
    deployer = @0x1234,
    creator_1 = @0x222,
    creator_2 = @0x3333,
    bidder_1 = @0x444,
        bidder_2 = @0x555,
    )]
    #[expected_failure(abort_code = 327683, location = Self
    )]

    public entry fun testfail_for_auction_status(deployer : signer, creator_1 : signer , creator_2 : address ,bidder_1 : signer,bidder_2 : signer) acquires Id,Auction{
        let deployer_addr = signer::address_of(&deployer);
        aptos_framework::account::create_account_for_test(deployer_addr);
        let creator1_addr = signer::address_of(&creator_1);
        aptos_framework::account::create_account_for_test(creator1_addr);
        aptos_framework::account::create_account_for_test(creator_2);
        aptos_framework::account::create_account_for_test(signer::address_of(&bidder_1));
        aptos_framework::account::create_account_for_test(signer::address_of(&bidder_2));

        init_module(&deployer);

        create_auction(&creator_1,deployer_addr,b"horse",50);

        place_bid(&bidder_1,creator1_addr,1,60);

        finalize_auction(&creator_1,1);

        place_bid(&bidder_2,creator1_addr,1,80);
    }

    #[test(
    deployer = @0x1234,
    creator_1 = @0x222,
    bidder_1 = @0x444,
    )]
    #[expected_failure(abort_code = 65540, location = Self
    )]

    public entry fun testfail_for_auction_id(deployer : signer, creator_1 : signer,bidder_1 : signer)acquires Id,Auction {
        let deployer_addr = signer::address_of(&deployer);
        aptos_framework::account::create_account_for_test(deployer_addr);
        let creator1_addr = signer::address_of(&creator_1);
        aptos_framework::account::create_account_for_test(creator1_addr);
        aptos_framework::account::create_account_for_test(signer::address_of(&bidder_1));

        init_module(&deployer);

        create_auction(&creator_1,deployer_addr,b"horse",50);

        place_bid(&bidder_1,creator1_addr,2,60);

    }

    #[test(
    deployer = @0x1234,
    creator_1 = @0x222,
    bidder_1 = @0x444,
    )]
    #[expected_failure(abort_code = 65541, location = Self
    )]

    public entry fun testfail_for_bid_amount(deployer : signer, creator_1 : signer,bidder_1 : signer)acquires Id,Auction{
        let deployer_addr = signer::address_of(&deployer);
        aptos_framework::account::create_account_for_test(deployer_addr);
        let creator1_addr = signer::address_of(&creator_1);
        aptos_framework::account::create_account_for_test(creator1_addr);
        aptos_framework::account::create_account_for_test(signer::address_of(&bidder_1));

        init_module(&deployer);

        create_auction(&creator_1,deployer_addr,b"horse",50);

        place_bid(&bidder_1,creator1_addr,1,40);
    }

    #[test(
    deployer = @0x1234,
    creator_1 = @0x222,
    bidder_1 = @0x444,
        bidder_2 = @0x555
    )]
    #[expected_failure(abort_code = 393218, location = Self
    )]

    public entry fun testfail_for_finalize_creator(deployer : signer, creator_1 : signer,bidder_1 : signer, bidder_2 : signer) acquires Id,Auction{
        let deployer_addr = signer::address_of(&deployer);
        aptos_framework::account::create_account_for_test(deployer_addr);
        let creator1_addr = signer::address_of(&creator_1);
        aptos_framework::account::create_account_for_test(creator1_addr);
        aptos_framework::account::create_account_for_test(signer::address_of(&bidder_1));
        aptos_framework::account::create_account_for_test(signer::address_of(&bidder_2));

        init_module(&deployer);

        create_auction(&creator_1,deployer_addr,b"horse",50);

        place_bid(&bidder_1,creator1_addr,1,100);
        place_bid(&bidder_2,creator1_addr,1,150);

        finalize_auction(&deployer , 1)

    }

    #[test(
    deployer = @0x1234,
    creator_1 = @0x222,
    bidder_1 = @0x444,
    bidder_2 = @0x555
    )]
    #[expected_failure(abort_code = 65540, location = Self
    )]

    public entry fun testfail_for_finalize_id(deployer : signer, creator_1 : signer,bidder_1 : signer, bidder_2 : signer) acquires Id,Auction {
        let deployer_addr = signer::address_of(&deployer);
        aptos_framework::account::create_account_for_test(deployer_addr);
        let creator1_addr = signer::address_of(&creator_1);
        aptos_framework::account::create_account_for_test(creator1_addr);
        aptos_framework::account::create_account_for_test(signer::address_of(&bidder_1));
        aptos_framework::account::create_account_for_test(signer::address_of(&bidder_2));

        init_module(&deployer);

        create_auction(&creator_1,deployer_addr,b"horse",50);

        place_bid(&bidder_1,creator1_addr,1,100);
        place_bid(&bidder_2,creator1_addr,1,150);

        finalize_auction(&creator_1 , 2)
    }

    #[test(
    deployer = @0x1234,
    creator_1 = @0x222,
    bidder_1 = @0x444,
    bidder_2 = @0x555
    )]
    #[expected_failure(abort_code = 327683, location = Self
    )]

    public entry fun testfail_for_finalize_status(deployer : signer, creator_1 : signer,bidder_1 : signer, bidder_2 : signer) acquires Id,Auction {
        let deployer_addr = signer::address_of(&deployer);
        aptos_framework::account::create_account_for_test(deployer_addr);
        let creator1_addr = signer::address_of(&creator_1);
        aptos_framework::account::create_account_for_test(creator1_addr);
        aptos_framework::account::create_account_for_test(signer::address_of(&bidder_1));
        aptos_framework::account::create_account_for_test(signer::address_of(&bidder_2));

        init_module(&deployer);

        create_auction(&creator_1,deployer_addr,b"horse",50);

        place_bid(&bidder_1,creator1_addr,1,100);
        place_bid(&bidder_2,creator1_addr,1,150);

        finalize_auction(&creator_1 , 1);
        finalize_auction(&creator_1,1)
    }
}