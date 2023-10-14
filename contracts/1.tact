import "@stdlib/deploy";

/*
  TASK 1 - Counter 
  Implement a counter contract that will have 2 opcodes ('Add' / 'Subtract'),
  which adds or subtracts the received number (int32) from the number that is stored in the state (and stores the result back in the state).
  You also need to implement one getter with the name "counter" to get the current number from the state.
*/

message Add {
  queryId: Int as uint64;
  number: Int as int32;
}

message Subtract {
  queryId: Int as uint64;
  number: Int as int32;
}

contract Task1 with Deployable {
    counter: Int as int32;

    init() {
      self.counter = 0;
    }

//    receive(msg: Add) {
//        self.counter = self.counter + msg.number;
//    }
    
//    receive(msg: Subtract) {
//        self.counter = self.counter - msg.number;
//    }

    receive(msg: Slice) {
        if(msg.bits() >= 32) {
            let op: Int = msg.loadUint(32);
            msg.skipBits(64);
            let value: Int = msg.loadInt(32);
            if (op == 1900888912) {
                self.counter = self.counter + value;
            } else if(op == 1296507738) {
                self.counter = self.counter - value;
            }
        }
    }

    get fun counter(): Int {
        return self.counter;
    }
}
