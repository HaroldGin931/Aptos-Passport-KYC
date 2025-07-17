//
//  Aptos_Passport_KYCTests.swift
//  Aptos Passport KYC – Unit Tests
//
//  Created by Harold on 2025/07/17.
//

import XCTest
import UIKit
@testable import Aptos_Passport_KYC         // ← app target

/// Helpers for loading reference images from the test bundle
private func loadImage(named name: String) -> UIImage {
    let bundle = Bundle(for: Aptos_Passport_KYCTests.self)
    guard
        let url   = bundle.url(forResource: name, withExtension: "jpg") ??
                    bundle.url(forResource: name, withExtension: "png"),
        let data  = try? Data(contentsOf: url),
        let image = UIImage(data: data)
    else {
        XCTFail("❌  Unable to load image '\(name)'")
        return UIImage()
    }
    return image
}

final class Aptos_Passport_KYCTests: XCTestCase {

    /// Expect two different faces to yield large distance / low similarity
    func testVisionSimilarity_DifferentFaces() throws {
        let imgA = loadImage(named: "blackgirlface")
        let imgB = loadImage(named: "myface")

        let (distance, similarity) = try FaceSimilarity.visionSimilarity(imgA: imgA, imgB: imgB)

        // Debug output (visible in the test log)
        print("🧪 [DifferentFaces] distance =", distance, " similarity =", similarity)

        XCTAssert(distance > 0.9,      "Distance too small; faces might not differ enough.")
        XCTAssert(similarity < 0.55,   "Similarity too high for different faces.")
    }

    func testVisionSimilarity_DifferentFaces2() throws {
        let imgA = loadImage(named: "3h")
        let imgB = loadImage(named: "myface")

        let (distance, similarity) = try FaceSimilarity.visionSimilarity(imgA: imgA, imgB: imgB)

        // Debug output (visible in the test log)
        print("🧪 [DifferentFaces] distance =", distance, " similarity =", similarity)

        XCTAssert(distance > 0.9,      "Distance too small; faces might not differ enough.")
        XCTAssert(similarity < 0.55,   "Similarity too high for different faces.")
    }

    /// Expect identical faces to yield tiny distance / high similarity
    func testVisionSimilarity_SameFace() throws {
        let img = loadImage(named: "myface")

        let (distance, similarity) = try FaceSimilarity.visionSimilarity(imgA: img, imgB: img)

        print("🧪 [SameFace] distance =", distance, " similarity =", similarity)

        XCTAssert(distance < 0.50,     "Distance too large for same face.")
        XCTAssert(similarity > 0.70,   "Similarity too low for same face.")
    }

    /// Same person: front vs frontclose  → should still be very similar
    func testVisionSimilarity_Front_vs_FrontClose() throws {
        let imgA = loadImage(named: "front")
        let imgB = loadImage(named: "frontclose")

        let (distance, similarity) = try FaceSimilarity.visionSimilarity(imgA: imgA, imgB: imgB)
        print("🧪 [Front~FrontClose] d =", distance, " s =", similarity)

        XCTAssert(distance < 0.6,  "Same face (different crop) distance too high.")
        XCTAssert(similarity > 0.70, "Similarity too low for same face.")
    }

    /// Same person, rotated head (front vs left)
    func testVisionSimilarity_Front_vs_Left() throws {
        let imgA = loadImage(named: "front")
        let imgB = loadImage(named: "left")

        let (distance, similarity) = try FaceSimilarity.visionSimilarity(imgA: imgA, imgB: imgB)
        print("🧪 [Front~Left] d =", distance, " s =", similarity)

        // Expect moderate distance, moderate-high similarity
        XCTAssert(distance < 0.8,  "Pose change distance unexpectedly high.")
        XCTAssert(similarity > 0.60, "Similarity unexpectedly low with same person different pose.")
    }

    /// Same person, glasses removed → frontclose vs frontclosenoglass
    func testVisionSimilarity_GlassesVsNoGlasses() throws {
        let imgA = loadImage(named: "frontclose")
        let imgB = loadImage(named: "frontclosenoglass")

        let (distance, similarity) = try FaceSimilarity.visionSimilarity(imgA: imgA, imgB: imgB)
        print("🧪 [Glass vs NoGlass] d =", distance, " s =", similarity)

        XCTAssert(distance < 0.8, "Glasses vs no glasses distance too high.")
        XCTAssert(similarity > 0.65, "Similarity too low when only glasses differ.")
    }
}
