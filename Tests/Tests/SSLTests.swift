import Foundation
@testable import SSL
import XCTest

final class SSLTests: XCTestCase {
    func getSha256Data(input: Data) throws -> Data {
        let process = Process()
        let stdInp = Pipe()
        let stdOut = Pipe()
        let stdErr = Pipe()
        process.standardOutput = stdOut
        process.standardError = stdErr
        process.arguments = ["-a", "256"]
        process.executableURL = URL(string: "file:///usr/bin/shasum")
        process.standardInput = stdInp
        stdInp.fileHandleForWriting.write(input)
        try stdInp.fileHandleForWriting.close()
        try process.run()
        process.waitUntilExit()
        let errData = stdErr.fileHandleForReading.readDataToEndOfFile()
        try stdErr.fileHandleForReading.close()
        if !errData.isEmpty {
            if let errText = String(data: errData, encoding: .utf8) {
                throw NSError(domain: errText, code: 0, userInfo: nil)
            } else {
                throw NSError(domain: "error", code: 0, userInfo: ["data": errData])
            }
        }
        let data = stdOut.fileHandleForReading.readDataToEndOfFile()
        try stdOut.fileHandleForReading.close()
        return data
    }
    func getSha256Hex(input: Data) throws -> String {
        let data = try getSha256Data(input: input)
        guard let text = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "unexpected output from shasum command", code: 0, userInfo: nil)
        }
        return text
    }
    func _testSha256Random(index: Int) throws -> XCTestExpectation {
        let size = Int.random(in: 0..<65536)
        let exp = XCTestExpectation(description: "testRandom\(index)")
        DispatchQueue.global(qos: .background).async {
            let bytes: [UInt8] = (0..<size).map { _ -> UInt8 in
                return UInt8.random(in: 0..<255)
            }
            let source = Data(bytes)
            let hash = source.sha256
            NSLog("test random sha 256 #\(index) with \(size) bytes")
            do {
                let wanted = try self.getSha256Hex(input: source)
                XCTAssertTrue(wanted.hasPrefix(hash.hex))
            } catch {
                XCTFail("random test #\(index) with \(size) bytes failed: \(error)")
            }
            exp.fulfill()
        }
        return exp
    }
    func _testSha256(text: String) throws {
        let source = try XCTUnwrap(text.data(using: .ascii))
        let hash = source.sha256
        let wanted = try getSha256Hex(input: source)
        XCTAssertTrue(wanted.hasPrefix(hash.hex))
    }
    func testSha256() throws {
        try _testSha256(text: "hello\n")
        try _testSha256(text: "Hello, world!\n")
        let expectations = (0..<10).compactMap { try? self._testSha256Random(index: $0) }
        wait(for: expectations, timeout: 60)
    }
    func testRotateRight() throws {
        let x = UInt32(0x12345678)
        XCTAssertEqual(x.rotateRight(by: 7), UInt32(0xf02468ac))
    }
    func testMajor() throws {
        let x: UInt32 = 0x12345678
        let y: UInt32 = 0x90abcdef
        let z: UInt32 = 0x11223344
        XCTAssertEqual(UInt32.major(x: x, y: y, z: z), UInt32(0x1022576c))
    }
    func testChoose() throws {
        let x: UInt32 = 0x12345678
        let y: UInt32 = 0x90abcdef
        let z: UInt32 = 0x11223344
        XCTAssertEqual(UInt32.choose(x: x, y: y, z: z), UInt32(0x1122656c))
    }
    func testSigma0() throws {
        let x: UInt32 = 0x12345678
        XCTAssertEqual(UInt32(0xe7fce6ee), x.sigma0)
    }
    func testSigma1() throws {
        let x: UInt32 = 0x12345678
        XCTAssertEqual(UInt32(0xa1f78649), x.sigma1)
    }
    func testGamma0() throws {
        let x: UInt32 = 0x12345678
        XCTAssertEqual(UInt32(0x66146474), x.gamma0)
    }
    func testGamma1() throws {
        let x: UInt32 = 0x12345678
        XCTAssertEqual(UInt32(0x3561abda), x.gamma1)
    }
    static var allTests = [
        ("testRotateRight", testRotateRight),
        ("testChoose", testChoose),
        ("testMajor", testMajor),
        ("testSha256", testSha256),
        ("testSigma0", testSigma0),
        ("testSigma1", testSigma1),
        ("testGamma0", testGamma0),
        ("testGamma1", testGamma1),
    ]
}