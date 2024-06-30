// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract Book {
    struct Order {
        uint256 id;
        address user;
        uint256 amount;
        uint256 interestRate;
        uint256 duration;
        bool isLend;
    }

    struct TreeNode {
        uint256 orderId;
        uint256 height;
        uint256 left;
        uint256 right;
    }

    uint256 public nextOrderId;
    mapping(uint256 => Order) public orders;
    mapping(address => uint256[]) public userOrders;
    mapping(uint256 => TreeNode) public tree;
    uint256 public root;
    uint256 public size;

    event OrderCreated(uint256 indexed orderId, address indexed user, uint256 amount, uint256 interestRate, uint256 duration, bool isLend);
    event OrderMatched(uint256 indexed lendOrderId, uint256 indexed borrowOrderId);

    constructor() {
        nextOrderId = 1;
    }

    function createOrder(uint256 amount, uint256 interestRate, uint256 duration, bool isLend) public {
        uint256 orderId = nextOrderId++;
        orders[orderId] = Order(orderId, msg.sender, amount, interestRate, duration, isLend);
        userOrders[msg.sender].push(orderId);
        root = insert(root, orderId);
        emit OrderCreated(orderId, msg.sender, amount, interestRate, duration, isLend);
    }

    function height(uint256 node) internal view returns (uint256) {
        if (node == 0) return 0;
        return tree[node].height;
    }

    function balanceFactor(uint256 node) internal view returns (int256) {
        if (node == 0) return 0;
        return int256(height(tree[node].left)) - int256(height(tree[node].right));
    }

    function updateHeight(uint256 node) internal {
        tree[node].height = 1 + max(height(tree[node].left), height(tree[node].right));
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    function rotateRight(uint256 y) internal returns (uint256) {
        uint256 x = tree[y].left;
        uint256 T2 = tree[x].right;

        tree[x].right = y;
        tree[y].left = T2;

        updateHeight(y);
        updateHeight(x);

        return x;
    }

    function rotateLeft(uint256 x) internal returns (uint256) {
        uint256 y = tree[x].right;
        uint256 T2 = tree[y].left;

        tree[y].left = x;
        tree[x].right = T2;

        updateHeight(x);
        updateHeight(y);

        return y;
    }

    function insert(uint256 node, uint256 orderId) internal returns (uint256) {
        if (node == 0) {
            tree[orderId] = TreeNode(orderId, 1, 0, 0);
            size++;
            return orderId;
        }

        Order storage newOrder = orders[orderId];
        Order storage currentOrder = orders[tree[node].orderId];

        if (newOrder.interestRate < currentOrder.interestRate) {
            tree[node].left = insert(tree[node].left, orderId);
        } else {
            tree[node].right = insert(tree[node].right, orderId);
        }

        updateHeight(node);
        int256 balance = balanceFactor(node);

        // L L 
        if (balance > 1 && newOrder.interestRate < orders[tree[node].left].interestRate) {
            return rotateRight(node);
        }

        // R R
        if (balance < -1 && newOrder.interestRate >= orders[tree[node].right].interestRate) {
            return rotateLeft(node);
        }

        // L R
        if (balance > 1 && newOrder.interestRate >= orders[tree[node].left].interestRate) {
            tree[node].left = rotateLeft(tree[node].left);
            return rotateRight(node);
        }

        // R L
        if (balance < -1 && newOrder.interestRate < orders[tree[node].right].interestRate) {
            tree[node].right = rotateRight(tree[node].right);
            return rotateLeft(node);
        }

        return node;
    }

    function matchOrders() public {
        matchRecursive(root);
    }

    function matchRecursive(uint256 node) internal {
        if (node == 0) return;

        matchRecursive(tree[node].left);

        Order storage currentOrder = orders[tree[node].orderId];
        if (currentOrder.isLend) {
            uint256 matchNode = findMatch(root, currentOrder.interestRate, false);
            if (matchNode != 0) {
                Order storage matchOrder = orders[tree[matchNode].orderId];
                if (currentOrder.amount == matchOrder.amount && currentOrder.duration == matchOrder.duration) {
                    emit OrderMatched(currentOrder.id, matchOrder.id);
                    deleteOrder(currentOrder.id);
                    deleteOrder(matchOrder.id);
                }
            }
        }

        matchRecursive(tree[node].right);
    }

    function findMatch(uint256 node, uint256 interestRate, bool isLend) internal view returns (uint256) {
        if (node == 0) return 0;

        Order storage currentOrder = orders[tree[node].orderId];
        if (currentOrder.isLend != isLend && currentOrder.interestRate == interestRate) {
            return node;
        }

        uint256 leftMatch = findMatch(tree[node].left, interestRate, isLend);
        if (leftMatch != 0) return leftMatch;

        return findMatch(tree[node].right, interestRate, isLend);
    }

    function deleteOrder(uint256 orderId) internal {
        delete orders[orderId];
        // todo rebalancing
    }

    function getUserOrders(address user) public view returns (uint256[] memory) {
        return userOrders[user];
    }
}

