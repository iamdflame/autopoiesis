/** Generated from out/Organism.sol/Organism.json — do not edit by hand. */
export const ORGANISM_ABI = [
  {
    "type": "constructor",
    "inputs": [
      {
        "name": "identity_",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "soma_",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "attestation_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "biosphere_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "parent_",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "payable"
  },
  {
    "type": "receive",
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "act",
    "inputs": [
      {
        "name": "rawQuote",
        "type": "bytes",
        "internalType": "bytes"
      },
      {
        "name": "a",
        "type": "tuple",
        "internalType": "struct Organism.Act",
        "components": [
          {
            "name": "kind",
            "type": "uint8",
            "internalType": "enum Organism.Kind"
          },
          {
            "name": "target",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "value",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "payload",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "nonce",
            "type": "uint64",
            "internalType": "uint64"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "actSigned",
    "inputs": [
      {
        "name": "signature",
        "type": "bytes",
        "internalType": "bytes"
      },
      {
        "name": "a",
        "type": "tuple",
        "internalType": "struct Organism.Act",
        "components": [
          {
            "name": "kind",
            "type": "uint8",
            "internalType": "enum Organism.Kind"
          },
          {
            "name": "target",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "value",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "payload",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "nonce",
            "type": "uint64",
            "internalType": "uint64"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "alive",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "attestSession",
    "inputs": [
      {
        "name": "rawQuote",
        "type": "bytes",
        "internalType": "bytes"
      },
      {
        "name": "sessionKey",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "ttl",
        "type": "uint64",
        "internalType": "uint64"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "breath",
    "inputs": [],
    "outputs": [
      {
        "name": "key",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "expires",
        "type": "uint64",
        "internalType": "uint64"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "breathing",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "generation",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint64",
        "internalType": "uint64"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "identity",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "nonce",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint64",
        "internalType": "uint64"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "soma",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "vitals",
    "inputs": [],
    "outputs": [
      {
        "name": "alive_",
        "type": "bool",
        "internalType": "bool"
      },
      {
        "name": "treasury",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "gen",
        "type": "uint64",
        "internalType": "uint64"
      },
      {
        "name": "idleFor",
        "type": "uint64",
        "internalType": "uint64"
      },
      {
        "name": "weights",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "event",
    "name": "Born",
    "inputs": [
      {
        "name": "identity",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "soma",
        "type": "bytes32",
        "indexed": false,
        "internalType": "bytes32"
      },
      {
        "name": "parent",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Breathed",
    "inputs": [
      {
        "name": "sessionKey",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "expires",
        "type": "uint64",
        "indexed": false,
        "internalType": "uint64"
      },
      {
        "name": "identity",
        "type": "bytes32",
        "indexed": false,
        "internalType": "bytes32"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Died",
    "inputs": [
      {
        "name": "atBlock",
        "type": "uint64",
        "indexed": false,
        "internalType": "uint64"
      },
      {
        "name": "returned",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "cause",
        "type": "string",
        "indexed": false,
        "internalType": "string"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Evolved",
    "inputs": [
      {
        "name": "generation",
        "type": "uint64",
        "indexed": true,
        "internalType": "uint64"
      },
      {
        "name": "from",
        "type": "bytes32",
        "indexed": false,
        "internalType": "bytes32"
      },
      {
        "name": "to",
        "type": "bytes32",
        "indexed": false,
        "internalType": "bytes32"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Fed",
    "inputs": [
      {
        "name": "from",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Reproduced",
    "inputs": [
      {
        "name": "child",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "childIdentity",
        "type": "bytes32",
        "indexed": false,
        "internalType": "bytes32"
      },
      {
        "name": "endowment",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Spent",
    "inputs": [
      {
        "name": "provider",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "jobRef",
        "type": "bytes32",
        "indexed": false,
        "internalType": "bytes32"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "ActionNotAttested",
    "inputs": []
  },
  {
    "type": "error",
    "name": "BadNonce",
    "inputs": [
      {
        "name": "expected",
        "type": "uint64",
        "internalType": "uint64"
      },
      {
        "name": "got",
        "type": "uint64",
        "internalType": "uint64"
      }
    ]
  },
  {
    "type": "error",
    "name": "BreathExpired",
    "inputs": [
      {
        "name": "expired",
        "type": "uint64",
        "internalType": "uint64"
      },
      {
        "name": "now_",
        "type": "uint64",
        "internalType": "uint64"
      }
    ]
  },
  {
    "type": "error",
    "name": "Dead",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ECDSAInvalidSignature",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ECDSAInvalidSignatureLength",
    "inputs": [
      {
        "name": "length",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "ECDSAInvalidSignatureS",
    "inputs": [
      {
        "name": "s",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ]
  },
  {
    "type": "error",
    "name": "EmptySoma",
    "inputs": []
  },
  {
    "type": "error",
    "name": "Insolvent",
    "inputs": [
      {
        "name": "want",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "have",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "MalformedReport",
    "inputs": [
      {
        "name": "length",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "MetabolicLimit",
    "inputs": [
      {
        "name": "want",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "allowed",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "NoBreath",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NotThisOrganism",
    "inputs": [
      {
        "name": "presented",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ]
  },
  {
    "type": "error",
    "name": "QuoteRejected",
    "inputs": []
  },
  {
    "type": "error",
    "name": "SessionTooLong",
    "inputs": [
      {
        "name": "asked",
        "type": "uint64",
        "internalType": "uint64"
      }
    ]
  },
  {
    "type": "error",
    "name": "StillAlive",
    "inputs": []
  },
  {
    "type": "error",
    "name": "TransferFailed",
    "inputs": []
  },
  {
    "type": "error",
    "name": "WrongSigner",
    "inputs": [
      {
        "name": "recovered",
        "type": "address",
        "internalType": "address"
      }
    ]
  }
] as const;
