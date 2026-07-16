// Probe: MultitouchSupport device identity semantics.
// 1. Does MTDeviceGetDeviceID exist?
// 2. Are MTDeviceRef pointers identical across two MTDeviceCreateList calls?
// 3. Do the reported device IDs match across calls?
import Foundation

typealias CreateListFn = @convention(c) () -> Unmanaged<CFMutableArray>?
typealias GetDeviceIDFn = @convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<UInt64>) -> Int32

guard let lib = dlopen(
    "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW
) else { print("dlopen FAILED"); exit(1) }

guard let createSym = dlsym(lib, "MTDeviceCreateList") else { print("MTDeviceCreateList MISSING"); exit(1) }
let createList = unsafeBitCast(createSym, to: CreateListFn.self)

let getIDSym = dlsym(lib, "MTDeviceGetDeviceID")
print("MTDeviceGetDeviceID symbol: \(getIDSym != nil ? "PRESENT" : "MISSING")")
let getID = getIDSym.map { unsafeBitCast($0, to: GetDeviceIDFn.self) }

func snapshot(_ label: String) -> [(ptr: UInt, id: UInt64?)] {
    guard let listU = createList() else { print("\(label): createList nil"); return [] }
    let list = listU.takeRetainedValue()
    let n = CFArrayGetCount(list)
    var out: [(UInt, UInt64?)] = []
    for i in 0..<n {
        let p = UnsafeMutableRawPointer(mutating: CFArrayGetValueAtIndex(list, i)!)
        var devID: UInt64 = 0
        let ok = getID?(p, &devID)
        out.append((UInt(bitPattern: p), ok == 0 ? devID : nil))
    }
    print("\(label): count=\(n) " + out.map { "ptr=0x\(String($0.0, radix: 16)) id=\($0.1.map(String.init) ?? "ERR")" }.joined(separator: " | "))
    return out
}

let a = snapshot("list A")
let b = snapshot("list B")
let ptrStable = a.map(\.ptr) == b.map(\.ptr)
let idStable = a.map(\.id) == b.map(\.id) && a.allSatisfy { $0.id != nil }
print("pointers stable across calls: \(ptrStable)")
print("device IDs stable across calls: \(idStable)")
