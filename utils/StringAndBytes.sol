// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// https://gist.github.com/ageyev/779797061490f5be64fb02e978feb6ac
contract A {
    function stringToBytes32(string memory source) public pure returns (bytes32 result) {
        assembly {
            result := mload(add(source, 32))
        }
    }

    function bytesArrayToString(bytes memory _bytes) public pure returns (string memory) {
        return string(_bytes);
    }

    function stringToBytesArray(string memory str) public pure returns (bytes memory){
        return bytes(str);
    }

    function bytes32ToBytes(bytes32 _bytes32) public pure returns (bytes memory){
        bytes memory bytesArray = new bytes(32);
        for (uint256 i; i < 32; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return bytesArray;
    }

    function bytes32ToString(bytes32 _bytes32) public pure returns (string memory){
        bytes memory bytesArray = bytes32ToBytes(_bytes32);
        return string(bytesArray);
    }

    // 字符串拼接
    function stringsConcatenation(string memory str1, string memory str2) public pure returns (string memory) {
        return concat(toSlice(str1), toSlice(str2));
    }

    function addressToString(address _address) public pure returns (string memory) {
        return stringsConcatenation("0x", addressToAsciiString(_address));
    }

    struct slice {uint _len; uint _ptr;}

    function memcpy(uint dest, uint src, uint len) internal pure{
        for (; len >= 32; len -= 32) {
            assembly {
            mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }
        uint mask = 256 ** (32 - len) - 1;
        assembly {
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dest), mask)
            mstore(dest, or(destpart, srcpart))
        }
    }

    /*
     * @dev Returns a slice containing the entire string.
     * @param self The string to make a slice from.
     * @return A newly allocated slice containing the entire string.
     */
    function toSlice(string memory self) private pure returns (slice memory) {
        uint ptr;
        assembly {
            ptr := add(self, 0x20)
        }
        return slice(bytes(self).length, ptr);
    }

    /*
     * @dev Returns a newly allocated string containing the concatenation of `self` and `other`.
     * @param self The first slice to concatenate.
     * @param other The second slice to concatenate.
     * @return The concatenation of the two strings.
     */
    function concat(slice memory self, slice memory other) private pure returns (string memory) {
        string memory ret = new string(self._len + other._len);
        uint retptr;
        assembly {
            retptr := add(ret, 32)
        }
        memcpy(retptr, self._ptr, self._len);
        memcpy(retptr + self._len, other._ptr, other._len);
        return ret;
    }

    /*
     * @dev Joins an array of slices, using `self` as a delimiter, returning a newly allocated string.
     * @param self The delimiter to use.
     * @param parts A list of slices to join.
     * @return A newly allocated string containing all the slices in `parts`, joined with `self`.
     */
    function join(slice memory self, slice[] memory parts) private pure returns (string memory) {
        if (parts.length == 0)
        return "";
        uint length = self._len * (parts.length - 1);
        for (uint i = 0; i < parts.length; i++)
        length += parts[i]._len;
        string memory ret = new string(length);
        uint retptr;
        assembly {retptr := add(ret, 32)}
        for (uint i = 0; i < parts.length; ++i) {
            memcpy(retptr, parts[i]._ptr, parts[i]._len);
            retptr += parts[i]._len;
            if (i < parts.length - 1) {
                memcpy(retptr, self._ptr, self._len);
                retptr += self._len;
            }
        }
        return ret;
    }

    function addressToAsciiString(address _address) public pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint(uint160(_address)) / (2 ** (8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = char(hi);
            s[2 * i + 1] = char(lo);
        }
        return string(s);
    }

    function char(bytes1 b) internal pure returns (bytes1 c) {
        uint8 _b = uint8(b);
        if (_b < 10) return bytes1(_b + 0x30);
        else return bytes1(_b + 0x57);
    }
}
