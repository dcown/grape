// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultisigWallet {
    event ExecutionSuccess(bytes32 txHash); // 交易成功事件
    event ExecutionFailure(bytes32 txHash); // 交易失败事件

    address[] owners; // 多签持有人数组
    mapping(address => bool) isOwner; // 记录一个地址是否为多签
    uint256 ownerCounter; // 多签持有人数量
    uint256 threshold; // 多签执行门槛，交易至少有n个多签人签名才能被执行。
    uint256 nonce; // nonce，防止签名重放攻击

    constructor(address[] memory _owners, uint256 _threshold) {
        _setupOwners(_owners, _threshold);
    }

    /// @dev 初始化owners, isOwner, ownerCount,threshold
    /// @param _owners: 多签持有人数组
    /// @param _threshold: 多签执行门槛，至少有几个多签人签署了交易
    function _setupOwners(address[] memory _owners, uint256 _threshold)
        internal
    {
        // threshold没被初始化过
        require(threshold == 0, "threshold is initialized");
        // 多签执行门槛 小于 多签人数
        require(
            _threshold <= _owners.length,
            "threshold should less than length of owner"
        );
        // 多签执行门槛至少为1
        require(_threshold >= 1, "threshold should be more than one");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            // 多签人不能为0地址，本合约地址，不能重复
            require(
                owner != address(0) &&
                    owner != address(this) &&
                    !isOwner[owner],
                "can not repeat"
            );
            owners.push(owner);
            isOwner[owner] = true;
        }
        ownerCounter = _owners.length;
        threshold = _threshold;
    }

    /*
     * @dev 在收集足够的多签签名后，执行交易
     * @param to 目标合约地址
     * @param value msg.value，支付的费用
     * @param data calldata
     * @param signatures 打包的签名，对应的多签地址由小到大，方便检查。 ({bytes32 r}{bytes32 s}{uint8 v}) (第一个多签的签名, 第二个多签的签名 ... )
     */
    function execTransaction(
        address to,
        uint256 value,
        bytes memory data,
        bytes memory signatures
    ) public payable returns (bool success) {
        bytes32 txHash = encodeTransactionData(to, value, data, nonce);
        nonce++;
        checkSignatures(txHash, signatures); // 检查签名
        (success, ) = to.call{value: value}(data);
        require(success, "call not success");
        if (success) emit ExecutionSuccess(txHash);
        else emit ExecutionFailure(txHash);
    }

    /**
     * @dev 检查签名和交易数据是否对应。如果是无效签名，交易会revert
     * @param dataHash 交易数据哈希
     * @param signatures 几个多签签名打包在一起
     */
    function checkSignatures(bytes32 dataHash, bytes memory signatures)
        public
        view
    {
        // 读取多签执行门槛
        uint256 _threshold = threshold;
        require(_threshold > 0, "not start");
        // 检查签名长度足够长
        require(
            signatures.length >= _threshold * 65,
            "signature length not enough"
        );

        // 通过一个循环，检查收集的签名是否有效
        // 思路：
        // 1. 用ecdsa先验证签名是否有效
        // 2. 利用 currentOwner > lastOwner 确定签名来自不同多签（多签地址递增）
        // 3. 利用 isOwner[currentOwner] 确定签名者为多签持有人
        address lastOwner = address(0);
        address currentOwner;
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 i;
        for (i = 0; i < _threshold; i++) {
            (v, r, s) = signatureSplit(signatures, i);
            // 利用ecrecover检查签名是否有效
            currentOwner = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19Ethereum Signed Message:\n32",
                        dataHash
                    )
                ),
                v,
                r,
                s
            );
            require(
                currentOwner > lastOwner && isOwner[currentOwner],
                "owner is wrong"
            );
            lastOwner = currentOwner;
        }
    }

    /// 将单个签名从打包的签名分离出来
    /// @param signatures 打包签名
    /// @param pos 要读取的多签index.
    function signatureSplit(bytes memory signatures, uint256 pos)
        internal
        pure
        returns (
            uint8 v,
            bytes32 r,
            bytes32 s
        )
    {
        assembly {
            let signaturePos := mul(0x41, pos)
            r := mload(add(signatures, add(signaturePos, 0x20)))
            s := mload(add(signatures, add(signaturePos, 0x40)))
            v := and(mload(add(signatures, add(signaturePos, 0x41))), 0xff)
        }
    }

    /// @dev 编码交易数据
    /// @param to 目标合约地址
    /// @param value msg.value，支付的以太坊
    /// @param data calldata
    /// @param _nonce 交易的nonce.
    /// @return 交易哈希bytes.
    function encodeTransactionData(
        address to,
        uint256 value,
        bytes memory data,
        uint256 _nonce
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(to, value, keccak256(data), _nonce));
    }
}
