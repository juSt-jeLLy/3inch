import { 
  JsonRpcSigner, 
  TypedDataDomain, 
  TypedDataField,
  randomBytes,
  parseUnits,
  Signature,
  concat,
  getBytes,
  TypedDataEncoder,
  toBeHex,
  hexlify
} from 'ethers';

// EIP-712 Type Definitions
const EIP712_DOMAIN: TypedDataDomain = {
  name: 'Limit Order Protocol',
  version: '1',
  chainId: 1, // This will be dynamically set
  verifyingContract: '', // This will be set to the Limit Order Protocol address
};

const EIP712_ORDER_TYPE: Record<string, TypedDataField[]> = {
  Order: [
    { name: 'salt', type: 'uint256' },
    { name: 'maker', type: 'address' },
    { name: 'receiver', type: 'address' },
    { name: 'makerAsset', type: 'address' },
    { name: 'takerAsset', type: 'address' },
    { name: 'makingAmount', type: 'uint256' },
    { name: 'takingAmount', type: 'uint256' },
    { name: 'makerTraits', type: 'uint256' }
  ]
};

export interface Order {
  salt: string;
  maker: string;
  receiver: string;
  makerAsset: string;
  takerAsset: string;
  makingAmount: string;
  takingAmount: string;
  makerTraits: string;
}

export async function createOrder(
  maker: string,
  makerAsset: string, // ETH or MON address
  takerAsset: string, // ERC20True address
  makingAmount: string,
  takingAmount: string,
  chainId: number,
  limitOrderProtocolAddress: string
): Promise<Order> {
  // Generate random salt
  const randomValue = randomBytes(32);
  const salt = hexlify(randomValue);
  
  // For cross-chain swaps, receiver is same as maker
  const receiver = maker;
  
  // MakerTraits: For now, we'll use basic traits (can be customized later)
  // 0 means: no bit invalidator, no predicate, no series nonce, etc.
  const makerTraits = '0';

  return {
    salt,
    maker,
    receiver,
    makerAsset,
    takerAsset,
    makingAmount: parseUnits(makingAmount, 18).toString(), // Assuming 18 decimals
    takingAmount: parseUnits(takingAmount, 18).toString(), // Assuming 18 decimals
    makerTraits
  };
}

export async function signOrder(
  order: Order,
  signer: JsonRpcSigner,
  chainId: number,
  limitOrderProtocolAddress: string
): Promise<{ r: string; vs: string }> {
  // Set up domain with correct chainId and contract
  const domain = {
    ...EIP712_DOMAIN,
    chainId,
    verifyingContract: limitOrderProtocolAddress,
  };

  // Get signature
  const signature = await signer.signTypedData(
    domain,
    EIP712_ORDER_TYPE,
    order
  );

  // Split signature into r, vs components as required by the protocol
  const sig = Signature.from(signature);
  const vs = concat([
    getBytes(`0x${sig.v.toString(16)}`), // Convert v to hex string
    sig.s
  ]);

  return {
    r: sig.r,
    vs: hexlify(vs)
  };
}

// Helper function to get order hash
export function getOrderHash(
  order: Order,
  chainId: number,
  limitOrderProtocolAddress: string
): string {
  const domain = {
    ...EIP712_DOMAIN,
    chainId,
    verifyingContract: limitOrderProtocolAddress,
  };

  return TypedDataEncoder.hash(
    domain,
    EIP712_ORDER_TYPE,
    order
  );
} 