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
    self.seed = seed; // needed to deploy multiple smart contracts copies from one admin address
    self.lockEndTime = 0;
    self.nftOwner = null;
    self.nftAddress = null;
  }

  receive(msg: OwnershipAssigned) {
    if(self.nftOwner != null) {
        self.sendNft(msg.queryId, self.nftAddress!!, self.nftOwner!!);
    }
    require(msg.forwardPayload.bits() >=32, "Incorrect unlock time");
    self.lockEndTime = now() + msg.forwardPayload.loadUint(32);
    self.nftOwner = msg.prevOwner;
    self.nftAddress = sender();
  }

  receive(msg: NftWithdrawal) {
    let sender: Address = sender();
    require(self.nftOwner == sender, "Invalid sender");
    require(self.nftAddress == msg.nftAddress, "Invalid sender");
    if(now() < self.lockEndTime) {
        send(SendParameters {
            to: sender,
            value: 0,
            mode: SendRemainingValue,
            bounce: false,
            body: "NFT is still locked".asComment()
        });
    } else {
        self.sendNft(msg.queryId, self.nftAddress!!, sender);
        self.nftOwner = null;
        self.nftAddress = null;
    }
  }

  fun sendNft(queryId: Int, nftAddress: Address, owner: Address) {
    send(SendParameters {
        to: nftAddress,
        value: 0,
        mode: SendRemainingBalance,
        bounce: false,
        body: Transfer {
            queryId: queryId,
            newOwner: owner,
            responseDestination: owner,
            customPayload: null,
            forwardAmount: 0,
            forwardPayload: emptySlice()
        }.toCell()
    });
  }

  get fun time(): Int {
    if(self.lockEndTime == 0) {
        return 0;
    }
    return self.lockEndTime - now();
  }

  get fun nft(): Address? {
    return self.nftAddress;
  }

  get fun owner(): Address? {
    return self.nftOwner;
  }
}