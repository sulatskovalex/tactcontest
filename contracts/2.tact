import "@stdlib/deploy";

/*
  TASK 2 - Proxy 
  Create a contract that forwards all received TONs
  to the admin contract (whose address is set in init_store).
  Message from this proxy contract to the admin contract should contain:
    - Address of user who sent original message (should be stored in the outcoming body's data/bits)
    - Original message that proxy smart contract received from user (should be stored in the outcoming body's first ref)
  Also, if admin contract decides to reject message (if it sends to the proxy "Refund" message with opcode=0x44),
  proxy contract needs to forward all TONs (attached to Refund message) back to the user.
  User address will be provided in Refund message body as "sender".
  In refund transaction, it is important to have a check that the refund message came from the admin address
*/

message(0x44) Refund {
  queryId: Int as uint64;
  sender: Address;
}

contract Task2 with Deployable {
  admin: Address;

  init(admin: Address) {
    self.admin = admin;
  }
  
  receive(msg: Refund) {
    nativeThrowUnless(132, sender() == self.admin);
    nativeSendMessage(
        beginCell()
            .storeInt(1, 2) // internal_message + ihd_disabled
            .storeBool(true) // bounce
            .storeInt(0, 3) // bounced + from
            .storeAddress(msg.sender) // to
            .storeCoins(0) // Value
            .storeInt(0, 1 + 4 + 4 + 64 + 32) // currency_collection + IHR fees + Fwd fees + CreatedLT + CreatedAt
            .storeBool(false) // code/data
            .storeBool(false) // body
            .endCell(),
        SendRemainingBalance
    );
  }

  receive(msg: Slice) {
    nativeSendMessage(
        beginCell()
            .storeInt(1, 2) // internal_message + ihd_disabled
            .storeBool(true) // bounce
            .storeInt(0, 3) // bounced + from
            .storeAddress(self.admin) // to
            .storeCoins(0) // Value
            .storeInt(0, 1 + 4 + 4 + 64 + 32) // currency_collection + IHR fees + Fwd fees + CreatedLT + CreatedAt
            .storeBool(false) // code/data
            .storeBool(true) // body
            .storeRef(beginCell().storeSlice(sender().asSlice()).storeRef(msg.asCell()).endCell())
            .endCell(),
        SendRemainingValue
    );
  }
}
