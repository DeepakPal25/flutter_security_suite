import Flutter
import UIKit
import XCTest

class RunnerTests: XCTestCase {

  func testFlutterEngineCreation() {
    let engine = FlutterEngine(name: "test")
    XCTAssertNotNil(engine, "FlutterEngine should initialise without crashing")
  }

}
