import "@stdlib/deploy";

/*
  TASK 3 - DEX
  Create a simple jetton dex contract that trades one pair of jettons: A and B.
  The price of jettons depends on the amount of jettons that smart contract has.
  Therefore, the smart contract needs to keep track of how much jettons it has.
  
  Price for the jetton A in swap B->A should be calculated by formula "amountOfJettonAOnContract * decimal / amountOfJettonBOnContract".
  Token prices must be decimalized for accuracy, so it is the prices that must be adjusted to decimal 1e9.
  Decimals are only needed for price accuracy. It should be set as 1e9.
  So, if smart contract has 10 of jetton A and 2 of jetton B, then after sending 1 jetton B you should receive 5 of jettons A.

  Example formula for amountOfAJettonToSend in B->A swap will be (amountOfJettonAOnContract * decimal / amountOfJettonBOnContract) * amountOfTokenBToSwap / decimal

  If smart contract pool doesn't have enough jettons to trade, then it should send incoming jettons back to the user. For a clearer explanation, let's look at the example we described above (smart contract has 10 of jetton A and 2 of jetton B).
  If user will send 3 jettons B, smart contract should reject the message (because contract does not have 3 * 5 = 15 jettons A) and send 3 jettons B back to the user.

  If smart contract receives a different jetton (neither A nor B) then throw an error.

  Implement a getter that returns the number of jettons in the pool and one more to get the price of jetton A or jetton B.
  Getters' behavior with incorrect parameter (address other than that of jetton A or B) is undefined (there are no such tests).
  
  Note:
  Admin can add jettons A and B just by sending them to the smart contract (we need to add initial supply to the pool for it to be functional).
  To be exact: any jettons (A or B) received from the admin are "added". Admin can't swap.
*/

message(0x7362d09c) TokenNotification {
    queryId: Int as uint64;
    amount: Int as coins;
    from: Address;
    forwardPayload: Slice as remaining;
}

// To simplify the testing process and the specificity of the messages being sent, we decided to add clear default values in this transaction
message(0xf8a7ea5) TokenTransfer {
     queryId: Int as uint64; // should be 0
     amount: Int as coins; // should be amount of jettons to send
     destination: Address; // should be user address / TokenNotification.from
     responseDestination: Address?; // should be myAddress()
     customPayload: Cell?; // should be null
     forwardTonAmount: Int as coins; // should be ton("0.01")
     forwardPayload: Slice as remaining; // should be emptySlice()
}
contract Task3 with Deployable {
  owner: Address;
  a: Int as coins;
  b: Int as coins;
  jA: Address;
  jB: Address;
  decimal: Int;

  init(admin: Address, newjA: Address, newjB: Address) {
    self.owner = admin;
    self.jA = newjA;
    self.jB = newjB;
    self.a = 0;
    self.b = 0;
    self.decimal = 1000000000;
  }

  receive(msg: TokenNotification) {
    let jetton: Address = sender();
    let isOwner: Bool = msg.from == self.owner;
    if(isOwner) {
    let isA: Bool = jetton == self.jA;
    let isB: Bool = jetton == self.jB;
        if (isA) {
            self.a = self.a + msg.amount;
        } else if(isB) {
            self.b = self.b + msg.amount;
        } else {
            nativeThrow(99);
        }
        return;
    }
    let isA: Bool = jetton == self.jA;
    let isB: Bool = jetton == self.jB;
    if((isA && self.a <= self.amountOfAJettonToSend(msg.amount)) || (isB && self.b <= self.amountOfBJettonToSend(msg.amount))) {
        self.sendJetton(jetton, msg.amount, msg.from);
        return;
    }

    let outAddr: Address? = null;
    let outAmount: Int = 0;
    if (isA) {
        outAmount = self.amountOfBJettonToSend(msg.amount);
        if(self.b - outAmount == 0) {
            self.sendJetton(self.jA, msg.amount, msg.from);
            return;
        }
        outAddr = self.jB;
        self.a = self.a + msg.amount;
        self.b = self.b - outAmount;
    } else {
        outAmount = self.amountOfAJettonToSend(msg.amount);
        if(self.a - outAmount == 0) {
            self.sendJetton(self.jB, msg.amount, msg.from);
            return;
        }
        outAddr = self.jA;
        self.b = self.b + msg.amount;
        self.a = self.a - outAmount;
    }
    if (outAmount < 0) { return; }
    send(SendParameters{
            to: outAddr!!,
            value: 0,
            mode: SendRemainingValue,
            body: TokenTransfer{
                    queryId: 0,
                    amount: outAmount,
                    destination: msg.from,
                    responseDestination: myAddress(),
                    customPayload: null,
                    forwardTonAmount: ton("0.01"),
                    forwardPayload: emptySlice()
            }.toCell()
        });
  }

  fun sendJetton(jetton: Address, amount: Int, dest: Address) {
  send(SendParameters{
                  to: jetton,
                  value: 0,
                  mode: SendRemainingValue,
                  body: TokenTransfer{
                          queryId: 0,
                          amount: amount,
                          destination: dest,
                          responseDestination: myAddress(),
                          customPayload: null,
                          forwardTonAmount: ton("0.01"),
                          forwardPayload: emptySlice()
                  }.toCell()
          });
  }

  fun amountOfBJettonToSend(amount: Int): Int {
    return amount * self.b * self.decimal / self.a / self.decimal;
  }
  fun aPrice(): Int {
    return self.b * self.decimal / self.a;
  }

  fun amountOfAJettonToSend(amount: Int): Int {
    return (amount * ((self.a * self.decimal) / self.b)) / self.decimal;
  }

  fun bPrice(): Int {
    return self.a * self.decimal / self.b;
  }

  get fun price(jetton: Address): Int {
    if(jetton == self.jA) {
        if(self.b == 0) { return 0; } else { return self.aPrice(); }
    }
    if(jetton == self.jB) {
        if(self.a == 0) { return 0; } else { return self.bPrice();}
    }
    return 0;
  }
  
  get fun balance(jetton: Address): Int {
    if(jetton == self.jA) {
        return self.a;
    }
    if(jetton == self.jB) {
        return self.b;
    }
    return 0;
  }
}
