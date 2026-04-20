#!/bin/bash

echo "========================================="
echo "Verifying GroupChat Configuration"
echo "========================================="

if [ -z "$groupChatAddress" ]; then
    echo -e "\033[31mError:\033[0m GroupChat address not set"
    return 1
fi

echo "Validating initialization parameters..."
missing_params=0

if [ -z "$LOVE20_GROUP_ADDRESS" ]; then
    echo -e "\033[31m✗\033[0m LOVE20_GROUP_ADDRESS not set"
    ((missing_params++))
fi

if [ -z "$ORIGIN_BLOCKS" ]; then
    echo -e "\033[31m✗\033[0m ORIGIN_BLOCKS not set"
    ((missing_params++))
fi

if [ -z "$PHASE_BLOCKS" ]; then
    echo -e "\033[31m✗\033[0m PHASE_BLOCKS not set"
    ((missing_params++))
fi

if [ $missing_params -gt 0 ]; then
    echo -e "\033[31mError:\033[0m $missing_params initialization parameter(s) missing"
    echo "Please ensure all parameters are loaded from group.chat.params / address.group.params"
    return 1
fi

echo -e "\033[32m✓\033[0m All initialization parameters are set"
echo ""

echo -e "GroupChat Address: $groupChatAddress\n"

failed_checks=0

echo "Verifying initialization parameters match contract values..."

check_equal "GroupChat: LOVE20_GROUP" $LOVE20_GROUP_ADDRESS $(cast_call $groupChatAddress "LOVE20_GROUP()(address)")
[ $? -ne 0 ] && ((failed_checks++))
echo ""

check_equal "GroupChat: ORIGIN_BLOCKS" $ORIGIN_BLOCKS $(cast_call $groupChatAddress "originBlocks()(uint256)")
[ $? -ne 0 ] && ((failed_checks++))
echo ""

check_equal "GroupChat: PHASE_BLOCKS" $PHASE_BLOCKS $(cast_call $groupChatAddress "phaseBlocks()(uint256)")
[ $? -ne 0 ] && ((failed_checks++))
echo ""

actual_max_content=$(cast_call $groupChatAddress "MAX_CONTENT_LENGTH()(uint256)")
echo -e "\033[32m✓\033[0m GroupChat: MAX_CONTENT_LENGTH"
echo -e "  Actual: $actual_max_content"
echo ""

actual_round=$(cast_call $groupChatAddress "currentRound()(uint256)" 2>/dev/null)
if [ -n "$actual_round" ]; then
    echo -e "\033[32m✓\033[0m GroupChat: currentRound"
    echo -e "  Actual: $actual_round"
else
    echo -e "\033[33m!\033[0m GroupChat: currentRound"
    echo -e "  Current block is before originBlocks, skip round value check"
fi
echo ""

echo "========================================="
if [ $failed_checks -eq 0 ]; then
    echo -e "\033[32m✓ All parameter checks passed (3/3)\033[0m"
    echo "========================================="
    return 0
else
    echo -e "\033[31m✗ $failed_checks check(s) failed\033[0m"
    echo "========================================="
    return 1
fi
