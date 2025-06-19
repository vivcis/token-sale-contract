use token_sale::{
    ITokenSaleDispatcher, 
    ITokenSaleDispatcherTrait,
    TokenSale
};
use token_sale::interfaces::ierc20::IERC20;
use crate::test_utils::mock_erc20;

use starknet::{ContractAddress, contract_address_const};
use starknet::testing::set_caller_address;
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
use core::byte_array::ByteArray;
use starknet::storage::StoragePointerReadAccess;

#[test]
fn test_constructor() {
    let owner = contract_address_const::<123>();
    let accepted_token = contract_address_const::<456>();
    
    // Declare and deploy the contract
    let contract_class = declare("TokenSale").unwrap().contract_class();
    let constructor_calldata = array![owner.into(), accepted_token.into()];
    let (contract_address, _) = contract_class.deploy(@constructor_calldata).unwrap();
    
    // Create dispatcher
    let contract = ITokenSaleDispatcher { contract_address };

    // Test assertions using getter functions
    assert(contract.get_owner() == owner, 'Owner not set');
    assert(contract.get_accepted_payment_token() == accepted_token, 'Accepted token not set');
}

#[test]
fn test_check_available_token() {
    let owner = contract_address_const::<123>();
    let accepted_token = contract_address_const::<456>();
    let test_token = contract_address_const::<789>();
    
    let contract = TokenSale::unsafe_new(owner, accepted_token);
    let dispatcher = ITokenSaleDispatcher { contract_address: contract.contract_address };
    
    let erc20 = mock_erc20::unsafe_new(
        ByteArray::from("TestToken"),
        ByteArray::from("TTK"),
        18
    );
    // spoof(test_token, erc20.contract_address); // Removed: spoof is not available
    
    set_caller_address(owner);
    erc20.mint(contract.contract_address, 1000_u256);
    
    let balance = dispatcher.check_available_token(test_token);
    assert(balance == 1000_u256, 'Incorrect token balance');
}

#[test]
fn test_deposit_token() {
    let owner = contract_address_const::<123>();
    let accepted_token = contract_address_const::<456>();
    let test_token = contract_address_const::<789>();
    let amount = 500_u256;
    let price = 10_u256;
    
    let contract = TokenSale::unsafe_new(owner, accepted_token);
    let dispatcher = ITokenSaleDispatcher { contract_address: contract.contract_address };
    
    let payment_token = mock_erc20::unsafe_new(
        ByteArray::from("PaymentToken"),
        ByteArray::from("PAY"), 
        18
    );
    let sale_token = mock_erc20::unsafe_new(
        ByteArray::from("SaleToken"),
        ByteArray::from("SALE"),
        18
    );
    
    // spoof(accepted_token, payment_token.contract_address); // Removed: spoof is not available
    // spoof(test_token, sale_token.contract_address); // Removed: spoof is not available
    
    set_caller_address(owner);
    payment_token.mint(owner, 1000_u256);
    payment_token.approve(contract.contract_address, amount);
    
    dispatcher.deposit_token(test_token, amount, price);
    
    assert(
        contract.tokens_available_for_sale.read(test_token) == amount, 
        'Tokens available not updated correctly'
    );
    assert(
        contract.token_price.read(test_token) == price, 
        'Token price not set correctly'
    );
    assert(
        payment_token.balance_of(contract.contract_address) == amount, 
        'Tokens not transferred to contract'
    );
}

#[test]
#[should_panic(expected: "insufficient balance")]
fn test_deposit_insufficient_balance() {
    let owner = contract_address_const::<123>();
    let accepted_token = contract_address_const::<456>();
    let test_token = contract_address_const::<789>();
    
    let contract = TokenSale::unsafe_new(owner, accepted_token);
    let dispatcher = ITokenSaleDispatcher { contract_address: contract.contract_address };
    
    set_caller_address(owner);
    dispatcher.deposit_token(test_token, 500_u256, 10_u256);
}

#[test]
#[should_panic(expected: 'Ownable: caller is not the owner')]
fn test_non_owner_deposit() {
    let owner = contract_address_const::<123>();
    let non_owner = contract_address_const::<999>();
    let accepted_token = contract_address_const::<456>();
    
    let contract = TokenSale::unsafe_new(owner, accepted_token);
    let dispatcher = ITokenSaleDispatcher { contract_address: contract.contract_address };
    
    set_caller_address(non_owner);
    dispatcher.deposit_token(contract_address_const::<789>(), 500_u256, 10_u256);
}

#[test]
fn test_buy_token() {
    let owner = contract_address_const::<123>();
    let buyer = contract_address_const::<321>();
    let accepted_token = contract_address_const::<456>();
    let test_token = contract_address_const::<789>();
    let amount = 100_u256;
    let price = 5_u256;
    
    let contract = TokenSale::unsafe_new(owner, accepted_token);
    let dispatcher = ITokenSaleDispatcher { contract_address: contract.contract_address };
    
    let payment_token = mock_erc20::unsafe_new(
        ByteArray::from("PaymentToken"),
        ByteArray::from("PAY"),
        18
    );
    let sale_token = mock_erc20::unsafe_new(
        ByteArray::from("SaleToken"),
        ByteArray::from("SALE"),
        18
    );
    
    spoof(accepted_token, payment_token.contract_address);
    spoof(test_token, sale_token.contract_address);
    
    // Setup initial state
    set_caller_address(owner);
    sale_token.mint(contract.contract_address, 1000_u256);
    dispatcher.deposit_token(test_token, 1000_u256, price);
    
    // Buyer prepares funds
    set_caller_address(buyer);
    payment_token.mint(buyer, 1000_u256);
    payment_token.approve(contract.contract_address, amount * price);
    
    // Execute buy
    dispatcher.buy_token(test_token, amount);
    
    // Verify results
    assert(
        sale_token.balance_of(buyer) == amount,
        'Buyer did not receive tokens'
    );
    assert(
        payment_token.balance_of(contract.contract_address) == amount * price,
        'Contract did not receive payment'
    );
    assert(
        contract.tokens_available_for_sale.read(test_token) == 1000_u256 - amount,
        'Token supply not updated'
    );
}