struct InventoryQuantity: Equatable, Codable, Sendable {
    var itemID: String
    var quantity: Int
}

enum InventoryFailure: Equatable, Error, Sendable {
    case invalidParameters
    case insufficientQuantity
    case capacityExceeded
}

struct InventoryService: Sendable {
    static let defaultStackLimit = 99

    static func count(_ inventory: [InventoryQuantity], itemID: String) -> Int {
        inventory.reduce(0) { total, stack in
            stack.itemID == itemID ? total + stack.quantity : total
        }
    }

    /// The same itemID may occupy multiple stacks once each existing stack is full.
    static func tryAdd(
        _ inventory: [InventoryQuantity],
        capacity: Int,
        itemID: String,
        quantity: Int,
        stackLimit: Int = defaultStackLimit
    ) -> Result<[InventoryQuantity], InventoryFailure> {
        guard quantity >= 1, capacity >= 1, stackLimit >= 1 else {
            return .failure(.invalidParameters)
        }
        var next = inventory
        var remaining = quantity
        for index in next.indices where next[index].itemID == itemID {
            let freeSpace = stackLimit - next[index].quantity
            guard freeSpace > 0 else {
                continue
            }
            let moved = min(freeSpace, remaining)
            next[index].quantity += moved
            remaining -= moved
            if remaining == 0 {
                return .success(next)
            }
        }
        while remaining > 0, next.count < capacity {
            let moved = min(stackLimit, remaining)
            next.append(InventoryQuantity(itemID: itemID, quantity: moved))
            remaining -= moved
        }
        guard remaining == 0 else {
            return .failure(.capacityExceeded)
        }
        return .success(next)
    }

    static func tryRemove(
        _ inventory: [InventoryQuantity],
        itemID: String,
        quantity: Int
    ) -> Result<[InventoryQuantity], InventoryFailure> {
        guard quantity >= 1 else {
            return .failure(.invalidParameters)
        }
        guard count(inventory, itemID: itemID) >= quantity else {
            return .failure(.insufficientQuantity)
        }
        var remaining = quantity
        var next: [InventoryQuantity] = []
        for stack in inventory {
            var updated = stack
            if remaining > 0, updated.itemID == itemID {
                let removed = min(updated.quantity, remaining)
                updated.quantity -= removed
                remaining -= removed
            }
            if updated.quantity > 0 {
                next.append(updated)
            }
        }
        return .success(next)
    }
}
