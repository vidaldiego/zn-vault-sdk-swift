import XCTest
@testable import ZnVault
final class AuditVerificationContractTests: XCTestCase {
    let json = #"{"status": "verified", "valid": true, "reasons": [], "errors": [], "checkedEntries": 3, "readEntries": 3, "authenticatedEntries": 3, "unverifiedEntries": 0, "unsignedDetailsEntries": 0, "scope": "retained", "interval": {"firstId": 5, "lastId": 7}, "completed": true, "startedAt": "2026-11-01T00:00:00Z", "finishedAt": "2026-11-01T00:00:01Z", "consistency": "repeatable_read", "historicalCompleteness": "not_proven"}"#
    func testEvidencePreserved() throws {
        let result = try JSONDecoder().decode(AuditVerifyResult.self, from: Data(json.utf8))
        XCTAssertTrue(result.valid)
        XCTAssertEqual(result.entriesVerified, 3)
        XCTAssertEqual(result.interval?.firstId, 5)
        XCTAssertEqual(result.historicalCompleteness, "not_proven")
        XCTAssertEqual(result.finishedAt, "2026-11-01T00:00:01Z")
    }
    func testUnknownAndPartialNeverSucceed() throws {
        for status in ["invalid", "unverifiable", "error", "empty", "unknown"] {
            let data = Data(json.replacingOccurrences(of: "verified", with: status).utf8)
            XCTAssertFalse(try JSONDecoder().decode(AuditVerifyResult.self, from: data).valid)
        }
        for data in [#"{"valid":true}"#, json.replacingOccurrences(of: "retained", with: "tail")] {
            XCTAssertFalse(try JSONDecoder().decode(AuditVerifyResult.self, from: Data(data.utf8)).valid)
        }
    }
}
