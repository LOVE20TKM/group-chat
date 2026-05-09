// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupChat} from "../interfaces/IGroupChat.sol";
import {IERC20Payment} from "../interfaces/external/IERC20Payment.sol";

import {IERC20Symbol} from "../interfaces/external/IERC20Symbol.sol";
import {IERC721Receiver} from "../interfaces/external/IERC721Receiver.sol";
import {ILOVE20Group} from "../interfaces/external/ILOVE20Group.sol";
import {IDenyVoteWeightSource} from "../interfaces/sources/IDenyVoteWeightSource.sol";
import {IPostScopeSource} from "../interfaces/sources/IPostScopeSource.sol";

abstract contract BaseGroupChatManager is IPostScopeSource, IDenyVoteWeightSource, IERC721Receiver {
    error ManagerAddressHasNoCode();
    error ChatAlreadyManaged();
    error RecentRoundsZero();
    error ManagerGroupNameUnavailable();
    error ManagerMintCostChanged();
    error ManagerPaymentFailed();
    error ManagerApprovalFailed();

    address public immutable GROUP_CHAT_ADDRESS;
    address public immutable LOVE20_GROUP_ADDRESS;
    uint256 public immutable MAX_GROUP_NAME_LENGTH;
    address public immutable DENY_SOURCE_ADDRESS;
    address public immutable BEFORE_POST_PLUGIN_ADDRESS;
    address public immutable AFTER_POST_PLUGIN_ADDRESS;

    bytes4 internal constant TEST_PREFIX = bytes4("Test");
    bytes internal constant FALLBACK_TOKEN_SYMBOL = "TOKEN";
    bytes16 internal constant HEX_SYMBOLS = "0123456789abcdef";
    uint256 internal constant GROUP_NAME_RANDOM_HEX_LENGTH = 12;

    uint256 internal _mintNonce;

    constructor(address groupChat_, address denySource_, address beforePostPlugin_, address afterPostPlugin_) {
        _requireCode(groupChat_);
        _requireOptionalCode(denySource_);
        _requireOptionalCode(beforePostPlugin_);
        _requireOptionalCode(afterPostPlugin_);

        address love20Group = IGroupChat(groupChat_).LOVE20_GROUP_ADDRESS();
        _requireCode(love20Group);

        GROUP_CHAT_ADDRESS = groupChat_;
        LOVE20_GROUP_ADDRESS = love20Group;
        MAX_GROUP_NAME_LENGTH = ILOVE20Group(love20Group).MAX_GROUP_NAME_LENGTH();
        DENY_SOURCE_ADDRESS = denySource_;
        BEFORE_POST_PLUGIN_ADDRESS = beforePostPlugin_;
        AFTER_POST_PLUGIN_ADDRESS = afterPostPlugin_;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function _mintManagedGroup(string memory groupNameStem) internal returns (uint256 groupId) {
        string memory groupName = _nextGroupName(groupNameStem);
        ILOVE20Group group = ILOVE20Group(LOVE20_GROUP_ADDRESS);

        uint256 expectedMintCost = group.calculateMintCost(groupName);
        if (expectedMintCost != 0) {
            address love20 = group.LOVE20_TOKEN_ADDRESS();
            if (!IERC20Payment(love20).transferFrom(msg.sender, address(this), expectedMintCost)) {
                revert ManagerPaymentFailed();
            }
            if (!IERC20Payment(love20).approve(LOVE20_GROUP_ADDRESS, expectedMintCost)) {
                revert ManagerApprovalFailed();
            }
        }

        uint256 actualMintCost;
        (groupId, actualMintCost) = group.mint(groupName);
        if (actualMintCost != expectedMintCost) {
            revert ManagerMintCostChanged();
        }
    }

    function _activateManagedChat(uint256 groupId) internal {
        string[] memory metaKeys = new string[](0);
        bytes[] memory metaValues = new bytes[](0);
        IGroupChat(GROUP_CHAT_ADDRESS).activateChat(
            groupId,
            metaKeys,
            metaValues,
            address(this),
            DENY_SOURCE_ADDRESS,
            BEFORE_POST_PLUGIN_ADDRESS,
            AFTER_POST_PLUGIN_ADDRESS,
            0
        );
    }

    function _pageCount(uint256 total, uint256 offset, uint256 limit) internal pure returns (uint256) {
        if (offset >= total) {
            return 0;
        }
        uint256 remaining = total - offset;
        return remaining < limit ? remaining : limit;
    }

    function _pageIndex(uint256 total, uint256 offset, uint256 localIndex, bool reverse)
        internal
        pure
        returns (uint256)
    {
        if (reverse) {
            return total - 1 - offset - localIndex;
        }
        return offset + localIndex;
    }

    function _requireCode(address target) internal view {
        if (target.code.length == 0) {
            revert ManagerAddressHasNoCode();
        }
    }

    function _requireOptionalCode(address target) internal view {
        if (target != address(0)) {
            _requireCode(target);
        }
    }

    function _requireNotManaged(bool managed) internal pure {
        if (managed) {
            revert ChatAlreadyManaged();
        }
    }

    function _requireRecentRounds(uint256 recentRounds) internal pure {
        if (recentRounds == 0) {
            revert RecentRoundsZero();
        }
    }

    function _tokenGroupNameStem(string memory managerPrefix, address token) internal view returns (string memory) {
        uint256 reservedBytes = _testPrefixBytes() + bytes(managerPrefix).length + 1 + GROUP_NAME_RANDOM_HEX_LENGTH;
        string memory tokenSymbol = _tokenSymbolLabel(token, _remainingNameBytes(reservedBytes));
        return string(abi.encodePacked(managerPrefix, tokenSymbol));
    }

    function _tokenActionGroupNameStem(string memory managerPrefix, address token, uint256 actionId)
        internal
        view
        returns (string memory)
    {
        string memory actionIdLabel = _uintToString(actionId);
        uint256 reservedWithoutSymbol = _testPrefixBytes() + bytes(managerPrefix).length + bytes(actionIdLabel).length
            + 1 + GROUP_NAME_RANDOM_HEX_LENGTH;
        if (reservedWithoutSymbol > MAX_GROUP_NAME_LENGTH) {
            uint256 maxActionIdBytes =
                _remainingNameBytes(_testPrefixBytes() + bytes(managerPrefix).length + 1 + GROUP_NAME_RANDOM_HEX_LENGTH);
            actionIdLabel = _truncateAscii(actionIdLabel, maxActionIdBytes);
        }

        uint256 reservedWithSymbol = _testPrefixBytes() + bytes(managerPrefix).length + bytes(actionIdLabel).length + 2
            + GROUP_NAME_RANDOM_HEX_LENGTH;
        string memory tokenSymbol = _tokenSymbolLabel(token, _remainingNameBytes(reservedWithSymbol));
        if (bytes(tokenSymbol).length == 0) {
            return string(abi.encodePacked(managerPrefix, actionIdLabel));
        }
        return string(abi.encodePacked(managerPrefix, tokenSymbol, "_", actionIdLabel));
    }

    function _nextGroupName(string memory groupNameStem) internal returns (string memory) {
        bool requiresTestPrefix = _love20TokenRequiresTestPrefix();
        for (uint256 i = 0; i < 8; i++) {
            string memory groupName = _canonicalizeGroupName(
                string(
                    abi.encodePacked(
                        groupNameStem,
                        "_",
                        _hexString(
                            keccak256(
                                abi.encodePacked(block.chainid, address(this), msg.sender, block.number, _mintNonce)
                            )
                        )
                    )
                ),
                requiresTestPrefix
            );
            unchecked {
                _mintNonce++;
            }
            if (!ILOVE20Group(LOVE20_GROUP_ADDRESS).isGroupNameUsed(groupName)) {
                return groupName;
            }
        }
        revert ManagerGroupNameUnavailable();
    }

    function _tokenSymbolLabel(address token, uint256 maxBytes) internal view returns (string memory) {
        if (maxBytes == 0) {
            return "";
        }

        bytes memory sanitized = FALLBACK_TOKEN_SYMBOL;
        if (token.code.length != 0) {
            try IERC20Symbol(token).symbol() returns (string memory resolvedSymbol) {
                bytes memory candidate = _sanitizeAsciiTokenSymbol(resolvedSymbol);
                if (candidate.length != 0) {
                    sanitized = candidate;
                }
            } catch {}
        }

        return _truncateAscii(string(sanitized), maxBytes);
    }

    function _love20TokenRequiresTestPrefix() internal view returns (bool) {
        address love20 = ILOVE20Group(LOVE20_GROUP_ADDRESS).LOVE20_TOKEN_ADDRESS();
        if (love20.code.length == 0) {
            return false;
        }
        return bytes4(bytes(IERC20Symbol(love20).symbol())) == TEST_PREFIX;
    }

    function _sanitizeAsciiTokenSymbol(string memory rawSymbol) internal pure returns (bytes memory) {
        bytes memory input = bytes(rawSymbol);
        bytes memory output = new bytes(input.length);
        uint256 outputLength;

        for (uint256 i = 0; i < input.length; i++) {
            bytes1 char = input[i];
            if ((char >= 0x30 && char <= 0x39) || (char >= 0x41 && char <= 0x5A) || (char >= 0x61 && char <= 0x7A)) {
                output[outputLength] = char;
                outputLength++;
            }
        }

        bytes memory trimmed = new bytes(outputLength);
        for (uint256 i = 0; i < outputLength; i++) {
            trimmed[i] = output[i];
        }
        return trimmed;
    }

    function _truncateAscii(string memory value, uint256 maxBytes) internal pure returns (string memory) {
        bytes memory input = bytes(value);
        if (input.length <= maxBytes) {
            return value;
        }

        bytes memory truncated = new bytes(maxBytes);
        for (uint256 i = 0; i < maxBytes; i++) {
            truncated[i] = input[i];
        }
        return string(truncated);
    }

    function _uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }

        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits--;
            buffer[digits] = bytes1(uint8(48 + value % 10));
            value /= 10;
        }
        return string(buffer);
    }

    function _testPrefixBytes() internal view returns (uint256) {
        return _love20TokenRequiresTestPrefix() ? 4 : 0;
    }

    function _remainingNameBytes(uint256 reservedBytes) internal view returns (uint256) {
        if (reservedBytes >= MAX_GROUP_NAME_LENGTH) {
            return 0;
        }
        return MAX_GROUP_NAME_LENGTH - reservedBytes;
    }

    function _canonicalizeGroupName(string memory groupName, bool requiresTestPrefix)
        internal
        pure
        returns (string memory)
    {
        if (!requiresTestPrefix || _hasTestPrefix(groupName)) {
            return groupName;
        }
        return string(abi.encodePacked("Test", groupName));
    }

    function _hasTestPrefix(string memory groupName) internal pure returns (bool) {
        bytes memory nameBytes = bytes(groupName);
        return nameBytes.length >= 4 && nameBytes[0] == "T" && nameBytes[1] == "e" && nameBytes[2] == "s"
            && nameBytes[3] == "t";
    }

    function _hexString(bytes32 value) internal pure returns (string memory) {
        bytes memory buffer = new bytes(GROUP_NAME_RANDOM_HEX_LENGTH);
        for (uint256 i = 0; i < GROUP_NAME_RANDOM_HEX_LENGTH / 2; i++) {
            uint8 b = uint8(value[i]);
            buffer[2 * i] = HEX_SYMBOLS[b >> 4];
            buffer[2 * i + 1] = HEX_SYMBOLS[b & 0x0f];
        }
        return string(buffer);
    }
}
