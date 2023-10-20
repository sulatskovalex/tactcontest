import "@stdlib/deploy";

/*
  TASK 4 - NFT locker
  Implement a smart contract that will lock NFT for a period of time specified by the owner.
  Smart conrtact should contain logic to process following messages and getters: 

  Messages: 
  * OwnershipAssigned
   - Recives nft + time (in a forwardPayload message as uint32) for which this nft will be locked + address of the sender of the nft (prevOwner).
   - If the smart contract already holds an nft then return the incoming nft back to the sender
  * NftWithdrawal
   - Request withdrawal of the locked nft
   - If sender is not the owner (that came from OwnershipAssigned as prevOwner address) then throw "Invalid sender" 
   - If time has not passed then send message back to the sender with the comment "NFT is still locked" according to the TON's "message with text comment" standard 
   - Otherwise (all good) send the locked nft back to the owner with all the remaining TON balance
   Note that the order of checks is important
   (in case: "sender is not the owner" and "time has not passed" at the same time, "Invalid sender" error takes priority)

  Getters:
  * time
   - get how much lock time is left
  * nft
   - get the address of the locked nft 
  * owner
   - get the owner of the locked nft (that came from OwnershipAssigned as prevOwner)
*/

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

message NftWithdrawal {
  queryId: Int as uint64;
  nftAddress: Address;
}

contract Task4 with Deployable {
  seed: Int as uint128;
  lockEndTime: Int as uint32;
  nftOwner: Address?;
  nftAddress: Address?;

  init(seed: Int) {
    self.lockEndTime = 0;
    self.nftOwner = null;
    self.nftAddress = null;
    self.seed = seed; // needed to deploy multiple smart contracts copies from one admin address
  }

  receive(msg: OwnershipAssigned) {
    if(self.nftOwner != null) {
        let sender: Address = sender();
        nativeSendMessage(
            beginCell()
                .storeInt(1, 2)                         // internal_message + ihd_disabled
                .storeBool(true)                        // bounce
                .storeInt(0, 3)                         // bounced + from
                .storeAddress(sender)                   // to
                .storeCoins(0)                          // value
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
        return;
    }
    self.lockEndTime = now() + msg.forwardPayload.preloadUint(32);
    self.nftOwner = msg.prevOwner;
    self.nftAddress = sender();
  }

  receive(msg: NftWithdrawal) {
    let sender: Address = sender();
    nativeThrowUnless(39, self.nftOwner == sender);
    if(now() < self.lockEndTime) {
        nativeSendMessage(
            beginCell()
                .storeInt(1, 2)                     // internal_message + ihd_disabled
                .storeBool(true)                    // bounce
                .storeInt(0, 3)                     // bounced + from
                .storeAddress(sender)               // to
                .storeCoins(0)                      //value
                .storeInt(0, 1 + 4 + 4 + 64 + 32)   // currency_collection + IHR fees + Fwd fees + CreatedLT + CreatedAt
                .storeBool(false)                   // code/data
                .storeBool(true)                    // body
                .storeRef("NFT is still locked".asComment())
                .endCell(),
            SendRemainingValue
          );
        return;
    }
    nativeThrowUnless(39, self.nftAddress == msg.nftAddress);
    nativeSendMessage(
        beginCell()
            .storeInt(1, 2)                         // internal_message + ihd_disabled
            .storeBool(true)                        // bounce
            .storeInt(0, 3)                         // bounced + from
            .storeAddress(self.nftAddress!!)        // to
            .storeCoins(0)                          // value
            .storeInt(0, 1 + 4 + 4 + 64 + 32)       // currency_collection + IHR fees + Fwd fees + CreatedLT + CreatedAt
            .storeBool(false)                       // code/data
            .storeBool(true)                        // body
            .storeRef(
                beginCell()
                    .storeUint(1607220500, 32)      //Transfer
                    .storeUint(msg.queryId, 64)     //queryId
                    .storeAddress(sender)           //newOwner
                    .storeAddress(sender)           //newOwner
                    .storeBool(false)               //customPayload
                    .storeCoins(0)                  //forwardAmount
                    .storeSlice(emptySlice())       //forwardPayload
                    .endCell()
            ).endCell(),
        SendRemainingBalance
    );
    self.nftOwner = null;
    self.nftAddress = null;
  }

  get fun time(): Int {
    return self.lockEndTime - now();
  }

  get fun nft(): Address? {
    return self.nftAddress;
  }

  get fun owner(): Address? {
    return self.nftOwner;
  }
}