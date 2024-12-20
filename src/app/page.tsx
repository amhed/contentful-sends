"use client";

import { useState } from "react";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import {
  useAccount,
  useWriteContract,
  useWaitForTransactionReceipt,
} from "wagmi";
import { ADDRESSES } from "@/constants/addresses";
import { parseUnits } from "viem";
import { useToast } from "@/hooks/use-toast";
import { signTypedData } from "@wagmi/core";

export default function TestPage() {
  const [contractAddress, setContractAddress] = useState(
    ADDRESSES.CONTENTFUL_SENDS.BASE
  );
  const [tokenAddress, setTokenAddress] = useState(ADDRESSES.TOKENS.USDC.BASE);
  const [amount, setAmount] = useState("");
  const [recipient, setRecipient] = useState("");
  const { address } = useAccount();
  const { toast } = useToast();

  const { writeContract: approveERC20, data: approveData } = useWriteContract();
  const { writeContract: sendERC20 } = useWriteContract();

  const { data: approveReceipt } = useWaitForTransactionReceipt({
    hash: approveData,
  });
  console.log(approveReceipt);

  const handleApprove = () => {
    if (!amount) return;
    approveERC20({
      address: tokenAddress as `0x${string}`,
      abi: [
        {
          name: "approve",
          type: "function",
          stateMutability: "nonpayable",
          inputs: [
            { name: "spender", type: "address" },
            { name: "amount", type: "uint256" },
          ],
          outputs: [{ name: "", type: "bool" }],
        },
      ],
      functionName: "approve",
      args: [contractAddress as `0x${string}`, parseUnits(amount, 6)],
    });
  };

  const handleSend = () => {
    if (!amount || !recipient) return;
    sendERC20({
      address: contractAddress as `0x${string}`,
      abi: [
        {
          name: "sendERC20",
          type: "function",
          stateMutability: "nonpayable",
          inputs: [
            { name: "token", type: "address" },
            { name: "to", type: "address" },
            { name: "amount", type: "uint256" },
          ],
          outputs: [],
        },
      ],
      functionName: "sendERC20",
      args: [
        tokenAddress as `0x${string}`,
        recipient as `0x${string}`,
        parseUnits(amount, 6),
      ],
    });
  };

  const handleEIP3009Send = async () => {
    if (!amount || !recipient) return;

    const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes from now
    const nonce = Math.floor(Math.random() * 1000000);

    const domain = {
      name: "USD Coin",
      version: "2",
      chainId: 8453, // Base
      verifyingContract: tokenAddress,
    };

    const types = {
      TransferWithAuthorization: [
        { name: "from", type: "address" },
        { name: "to", type: "address" },
        { name: "value", type: "uint256" },
        { name: "validAfter", type: "uint256" },
        { name: "validBefore", type: "uint256" },
        { name: "nonce", type: "bytes32" },
      ],
    };

    const value = {
      from: address,
      to: recipient,
      value: parseUnits(amount, 6),
      validAfter: 0,
      validBefore: deadline,
      nonce: `0x${nonce.toString(16).padStart(64, "0")}`,
    };

    try {
      const signature = await signTypedData({
        message: value,
        domain,
        types,
      });

      // Call your contract's receiveWithAuthorization function
      // Implementation depends on your contract's interface
    } catch (error) {
      console.error("Error signing:", error);
    }
  };

  return (
    <div className="container mx-auto p-4 max-w-2xl">
      <Card>
        <CardHeader>
          <CardTitle>Test ContentfulSends Contract</CardTitle>
          <CardDescription>
            Send ERC20 tokens through the contract
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <label className="text-sm font-medium">Contract Address</label>
            <Input
              value={contractAddress}
              onChange={(e) => setContractAddress(e.target.value)}
              placeholder="0x..."
            />
          </div>

          <div>
            <label className="text-sm font-medium">Token Address</label>
            <Input
              value={tokenAddress}
              onChange={(e) => setTokenAddress(e.target.value)}
              placeholder="0x..."
            />
          </div>

          <div>
            <label className="text-sm font-medium">Amount</label>
            <Input
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="100"
              type="number"
            />
          </div>

          <div>
            <label className="text-sm font-medium">Recipient</label>
            <Input
              value={recipient}
              onChange={(e) => setRecipient(e.target.value)}
              placeholder="0x..."
            />
          </div>

          <div className="flex space-x-2">
            <Button onClick={handleApprove}>Approve</Button>
            <Button onClick={handleSend} variant="default">
              Send
            </Button>
            <Button onClick={handleEIP3009Send} variant="secondary">
              Send with EIP3009
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
