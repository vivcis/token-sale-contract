#[starknet::contract]
pub mod mock_erc20 {
    use starknet::storage::StorageMapWriteAccess;
    use starknet::get_caller_address;
    use starknet::storage::StorageMapReadAccess;
    use starknet::storage::StoragePointerWriteAccess;
    use starknet::storage::StoragePointerReadAccess;
    use starknet::ContractAddress;
    use token_sale::interfaces::ierc20::IERC20;
    use core::byte_array::ByteArray;
    
    #[storage]
    struct Storage {
        name: ByteArray,
        symbol: ByteArray,
        decimals: u8,
        balances: LegacyMap<ContractAddress, u256>,
        allowances: LegacyMap<(ContractAddress, ContractAddress), u256>,
        total_supply: u256
    }
    
    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        decimals: u8
    ) {
        self.name.write(name);
        self.symbol.write(symbol);
        self.decimals.write(decimals);
        self.total_supply.write(0_u256);
    }
    
    #[abi(embed_v0)]
    impl MockERC20Impl of IERC20<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            self.name.read()
        }
        
        fn symbol(self: @ContractState) -> ByteArray {
            self.symbol.read()
        }
        
        fn decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }
        
        fn total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }
        
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }
        
        fn allowance(
            self: @ContractState, 
            owner: ContractAddress, 
            spender: ContractAddress
        ) -> u256 {
            self.allowances.read((owner, spender))
        }
        
        fn approve(
            ref self: ContractState, 
            spender: ContractAddress, 
            amount: u256
        ) -> bool {
            let caller = get_caller_address();
            self.allowances.write((caller, spender), amount);
            true
        }
        
        fn transfer(
            ref self: ContractState, 
            recipient: ContractAddress, 
            amount: u256
        ) -> bool {
            let caller = get_caller_address();
            let caller_balance = self.balances.read(caller);
            assert(caller_balance >= amount, 'Insufficient balance');
            
            self.balances.write(caller, caller_balance - amount);
            let recipient_balance = self.balances.read(recipient);
            self.balances.write(recipient, recipient_balance + amount);
            true
        }
        
        fn transfer_from(
            ref self: ContractState, 
            sender: ContractAddress, 
            recipient: ContractAddress, 
            amount: u256
        ) -> bool {
            let caller = get_caller_address();
            let allowance = self.allowances.read((sender, caller));
            assert(allowance >= amount, 'Insufficient allowance');
            
            let sender_balance = self.balances.read(sender);
            assert(sender_balance >= amount, 'Insufficient balance');
            
            self.allowances.write((sender, caller), allowance - amount);
            self.balances.write(sender, sender_balance - amount);
            let recipient_balance = self.balances.read(recipient);
            self.balances.write(recipient, recipient_balance + amount);
            true
        }
        
        fn mint(
            ref self: ContractState, 
            recipient: ContractAddress, 
            amount: u256
        ) -> bool {
            let current_balance = self.balances.read(recipient);
            self.balances.write(recipient, current_balance + amount);
            self.total_supply.write(self.total_supply.read() + amount);
            true
        }
    }
}