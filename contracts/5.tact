import "@stdlib/deploy";

/*
  TASK 5 - NFT random swap 
  The smart contract contains a bunch of different NFTs.
  A user brings his NFT (sends it to the smart contract), with 2.1 TON (2 for admin's profit, 0.1 for gas) in attachment (as fee for swap).
  The smart contract randomly chooses some NFT from the available NFTs (including the newly incoming one) and gives it to the user in exchange for the brought NFT (but occasionally just returns user's NFT in some cases).
  Admin can deposit NFTs without swap logic. Any NFT received from the admin is considered deposited. Admin can't swap.
  Admin can withdraw all NFTs at once, and also all TONs collected from users as fees.
  Implement getter that will return NFT addresses held by the smart contract.
  Implement getter that will return the amount of admin`s profit collected.

  In details, the smart contract (later: SC) should have this logic:
  Messages
  * AdminWithdrawalProfit 
   - SC should check that sender is the admin / otherwise throw "Insufficient privelegies"
   - SC should send all collected fees to admin except 0.1 TON (use AdminFetchProfit message as body)
     In other words: after each such operation, the contract's balance should be equal to 0.1 TON (which are reserved for storage) and the rest should be sent to the admin
  * AdminWithdrawalAllNFTs
   - SC should check that incoming tx TON value is enough for NFT withdrawal. Specifically, at least: (1 + totalNftsHeld * 0.08) TONs. Otherwise throw "Insufficent funds"
   - SC should check that sender is the admin, throw "Invalid sender" otherwise
   - If all checks pass, SC should send NFTs one by one to the admin 
   - SC should be able to withdraw all NFTs by a single message from admin
  * OwnershipAssigned 
   - if prevOwner is the owner's (admin) address, then add NFT to the collection
   - if value of TON attached is less then 2.1 TON then stop execution and return NFT back,
     but only in case that TON attached is enough to process refund without losing TONs on the SC's balance
   - randomly select NFT to send from all the NFTs that smart contract has
   - send the selected NFT to the sender with all remaining balance (except for admin profit = fees collected from this and other swaps)
     In other words: the contract's balance should increase by exactly 2 TON, some incoming TONs will be consumed for gas and the remainings of the incoming TONs should be refunded to the sender
  
  Getters
  * profit
   - returns how much collected fees is available to withdraw for the admin (all fees minus 0.1 TON)
  * nfts
   - returns dict of held NFTs with NFT indexes (sequential numbers from 0, 1, 2 ... and up to 'totalNftsHeld-1') as keys and NFT address as values 
     the order of NFTs in this dictionary doesn't matter
*/

message AdminWithdrawalProfit {
  queryId: Int as uint64;
}

message AdminWithdrawalAllNFTs {
  queryId: Int as uint64;
}

message AdminFetchProfit {
  queryId: Int as uint64;
}

message(0x05138d91) OwnershipAssigned {
    queryId: Int as uint64;
    prevOwner: Address;
    forwardPayload: Slice as remaining; 
}

message(0x5fcc3d14) Transfer { 
    queryId: Int as uint64;            
    newOwner: Address; 
    responseDestination: Address; 
    customPayload: Cell?; 
    forwardAmount: Int as coins; 
    forwardPayload: Slice as remaining; 
}

contract Task5 with Deployable {
  seed: Int as uint128;
  owner: Address;
  nftMap: map<Int as uint16, Address>;
  nftCount: Int as uint16;

  init(seed: Int, owner: Address) {
    self.owner = owner;
    self.seed = seed; // needed to deploy multiple smart contracts copies from one admin address
    self.nftMap = emptyMap();
    self.nftCount = 0;
  }
/*
  OwnershipAssigned
   - if prevOwner is the owner's (admin) address, then add NFT to the collection
   - if value of TON attached is less then 2.1 TON then stop execution and return NFT back, but only in case that TON attached is enough to process refund without losing TONs on the SC's balance
   - randomly select NFT to send from all the NFTs that smart contract has
   - send the selected NFT to the sender with all remaining balance (except for admin profit = fees collected from this and other swaps)
     In other words: the contract's balance should increase by exactly 2 TON, some incoming TONs will be consumed for gas and the remainings of the incoming TONs should be refunded to the sender
*/
  receive(msg: OwnershipAssigned) {
    if(self.owner == msg.prevOwner) {
        self.nftMap.set(self.nftCount, sender());
        self.nftCount = self.nftCount + 1;
        return;
    }
    let ctx: Context = context();
    if(ctx.value < ton("0.1")) {
        return;
    }
    if(ctx.value < ton("2.1") || self.nftCount == 0) {
        nativeSendMessage(
            beginCell()
                .storeInt(1, 2)                         // internal_message + ihd_disabled
                .storeBool(true)                        // bounce
                .storeInt(0, 3)                         // bounced + from
                .storeAddress(ctx.sender)               // to
                .storeCoins(0)                          // value
                .storeInt(0, 1 + 4 + 4 + 64 + 32)       // currency_collection + IHR fees + Fwd fees + CreatedLT + CreatedAt
                .storeBool(false)                       // code/data
                .storeBool(true)                        // body
            .   storeRef(
                    beginCell()
                        .storeUint(1607220500, 32)      //Transfer
                        .storeUint(msg.queryId, 64)     //queryId
                        .storeAddress(msg.prevOwner)    //newOwner
                        .storeAddress(msg.prevOwner)    //newOwner
                        .storeBool(false)               //customPayload
                        .storeCoins(0)                  //forwardAmount
                        .storeSlice(emptySlice())       //forwardPayload
                        .endCell()
                ).endCell(),
            SendRemainingValue
        );
        return;
    }
    let nftIndex: Int = nativeRandomInterval(self.nftCount);
    let nft: Address = self.nftMap.get(nftIndex)!!;
    self.nftMap.set(nftIndex, ctx.sender);
    let fee: Int = ctx.value - ton("2");
    nativeReserve(myBalance() - ctx.value + ton("2"), 0);
    nativeSendMessage(
        beginCell()
            .storeInt(1, 2)                         // internal_message + ihd_disabled
            .storeBool(true)                        // bounce
            .storeInt(0, 3)                         // bounced + from
            .storeAddress(nft)                      // to
            .storeCoins(fee)                        // value
            .storeInt(0, 1 + 4 + 4 + 64 + 32)       // currency_collection + IHR fees + Fwd fees + CreatedLT + CreatedAt
            .storeBool(false)                       // code/data
            .storeBool(true)                        // body
            .storeRef(
                beginCell()
                    .storeUint(1607220500, 32)      //Transfer
                    .storeUint(msg.queryId, 64)     //queryId
                    .storeAddress(msg.prevOwner)    //newOwner
                    .storeAddress(msg.prevOwner)    //newOwner
                    .storeBool(false)               //customPayload
                    .storeCoins(0)                  //forwardAmount
                    .storeSlice(emptySlice())       //forwardPayload
                    .endCell()
            ).endCell(),
        SendRemainingBalance
    );
  }
/*
  AdminWithdrawalProfit
   - SC should check that sender is the admin / otherwise throw "Insufficient privelegies"
   - SC should send all collected fees to admin except 0.1 TON (use AdminFetchProfit message as body)
     In other words: after each such operation, the contract's balance should be equal to 0.1 TON (which are reserved for storage) and the rest should be sent to the admin
*/
  receive(msg: AdminWithdrawalProfit) {
    nativeThrowUnless(36287, sender() == self.owner);
    nativeReserve(ton("0.1"), 0);
    nativeSendMessage(
        beginCell()
            .storeInt(1, 2)                         // internal_message + ihd_disabled
            .storeBool(true)                        // bounce
            .storeInt(0, 3)                         // bounced + from
            .storeAddress(self.owner)                      // to
            .storeCoins(0)                        // value
            .storeInt(0, 1 + 4 + 4 + 64 + 32)       // currency_collection + IHR fees + Fwd fees + CreatedLT + CreatedAt
            .storeBool(false)                       // code/data
            .storeBool(true)                        // body
            .storeRef(
                beginCell()
                    .storeUint(4255419257, 32)      //AdminFetchProfit
                    .storeUint(msg.queryId, 64)     //queryId
                    .endCell()
            ).endCell(),
        SendRemainingBalance
    );
  }
/*
  AdminWithdrawalAllNFTs
   - SC should check that incoming tx TON value is enough for NFT withdrawal. Specifically, at least: (1 + totalNftsHeld * 0.08) TONs. Otherwise throw "Insufficent funds"
   - SC should check that sender is the admin, throw "Invalid sender" otherwise
   - If all checks pass, SC should send NFTs one by one to the admin
   - SC should be able to withdraw all NFTs by a single message from admin
*/
  receive(msg: AdminWithdrawalAllNFTs) {
    let ctx: Context = context();
    nativeThrowUnless(62515, ctx.value >= (ton("1") + (self.nftCount * ton("0.08"))));
    let myAddress: Address = myAddress();
    nativeThrowUnless(4429, ctx.sender == self.owner || ctx.sender == myAddress);
        let body: Cell = beginCell()
                            .storeUint(1607220500, 32)      //Transfer
                            .storeUint(msg.queryId, 64)     //queryId
                            .storeAddress(self.owner)       //newOwner
                            .storeAddress(self.owner)       //newOwner
                            .storeBool(false)               //customPayload
                            .storeCoins(0)                  //forwardAmount
                            .storeSlice(emptySlice())       //forwardPayload
                            .endCell();
    repeat(min(self.nftCount, 100)) {
        self.nftCount = self.nftCount - 1;
        nativeSendMessage(
            beginCell()
                .storeInt(1, 2)                                 // internal_message + ihd_disabled
                .storeBool(true)                                // bounce
                .storeInt(0, 3)                                 // bounced + from
                .storeAddress(self.nftMap.get(self.nftCount)!!) // to
                .storeCoins(ton("0.02"))                        // value
                .storeInt(0, 1 + 4 + 4 + 64 + 32)               // currency_collection + IHR fees + Fwd fees + CreatedLT + CreatedAt
                .storeBool(false)                               // code/data
                .storeBool(true)                                // body
                .storeRef(body)
                .endCell(),
            0
        );
    }
    if(self.nftCount > 0) {
        nativeSendMessage(
            beginCell()
                .storeInt(1, 2)                         // internal_message + ihd_disabled
                .storeBool(true)                        // bounce
                .storeInt(0, 3)                         // bounced + from
                .storeAddress(myAddress)                // to
                .storeCoins(0)                          // value
                .storeInt(0, 1 + 4 + 4 + 64 + 32)       // currency_collection + IHR fees + Fwd fees + CreatedLT + CreatedAt
                .storeBool(false)                       // code/data
                .storeBool(true)                        // body
                .storeRef(
                    beginCell()
                        .storeUint(1664696863, 32)      //AdminWithdrawalAllNFTs
                        .storeUint(msg.queryId, 64)     //queryId
                        .endCell()
                ).endCell(),
            SendRemainingBalance
        );
    } else {
        self.nftMap = null;
    }
  }

  get fun profit(): Int {
    return myBalance() - ton("0.1");
  }

  get fun nfts(): map<Int as uint16, Address> {
    return self.nftMap;
  }
}