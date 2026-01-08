//
//  LiDARScanner.swift
//  Akusti-Scan-App-RT60
//
//  LiDAR-based room scanning for volume calculation
//

import ARKit
import RealityKit
import Combine

/// Errors during LiDAR scanning
enum LiDARError: Error, LocalizedError {
    case notSupported
    case sessionFailed(String)
    case insufficientData
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "LiDAR ist auf diesem Gerät nicht verfügbar."
        case .sessionFailed(let message):
            return "AR-Session fehlgeschlagen: \(message)"
        case .insufficientData:
            return "Nicht genügend Scandaten für Raumberechnung."
        case .permissionDenied:
            return "Kamerazugriff wurde verweigert."
        }
    }
}

/// Detected room dimensions from LiDAR scan
struct RoomDimensions: Sendable {
    let width: Float      // meters
    let length: Float     // meters
    let height: Float     // meters
    let volume: Float     // cubic meters
    let surfaceArea: Float // square meters

    var formattedVolume: String {
        String(format: "%.1f m³", volume)
    }

    var formattedDimensions: String {
        String(format: "%.1f × %.1f × %.1f m", length, width, height)
    }

    var formattedSurfaceArea: String {
        String(format: "%.1f m²", surfaceArea)
    }
}

/// Point cloud from LiDAR scan
struct PointCloud: Sendable {
    let points: [SIMD3<Float>]
    let timestamp: Date

    var boundingBox: (min: SIMD3<Float>, max: SIMD3<Float>) {
        guard !points.isEmpty else {
            return (SIMD3<Float>.zero, SIMD3<Float>.zero)
        }

        var minPoint = points[0]
        var maxPoint = points[0]

        for point in points {
            minPoint = min(minPoint, point)
            maxPoint = max(maxPoint, point)
        }

        return (minPoint, maxPoint)
    }
}

/// Service for LiDAR room scanning
@MainActor
@Observable
final class LiDARScanner: NSObject {

    // MARK: - Properties

    private var arSession: ARSession?
    private var collectedPoints: [SIMD3<Float>] = []

    private(set) var isScanning = false
    private(set) var scanProgress: Float = 0
    private(set) var pointCount: Int = 0
    private(set) var currentDimensions: RoomDimensions?
    private(set) var error: LiDARError?

    /// Check if LiDAR is available on this device
    static var isSupported: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }

    // MARK: - Initialization

    override init() {
        super.init()
    }

    // MARK: - Scanning

    /// Start LiDAR room scan
    func startScanning() throws {
        guard LiDARScanner.isSupported else {
            throw LiDARError.notSupported
        }

        let session = ARSession()
        session.delegate = self

        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .mesh
        configuration.frameSemantics = .sceneDepth

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            configuration.frameSemantics.insert(.smoothedSceneDepth)
        }

        configuration.planeDetection = [.horizontal, .vertical]

        collectedPoints.removeAll()
        pointCount = 0
        scanProgress = 0
        error = nil

        session.run(configuration)
        arSession = session
        isScanning = true
    }

    /// Stop scanning and calculate room dimensions
    func stopScanning() -> RoomDimensions? {
        arSession?.pause()
        arSession = nil
        isScanning = false

        guard collectedPoints.count > 100 else {
            error = .insufficientData
            return nil
        }

        let dimensions = calculateRoomDimensions()
        currentDimensions = dimensions
        return dimensions
    }

    /// Reset scanner
    func reset() {
        arSession?.pause()
        arSession = nil
        isScanning = false
        collectedPoints.removeAll()
        pointCount = 0
        scanProgress = 0
        currentDimensions = nil
        error = nil
    }

    // MARK: - Private Methods

    private func processDepthData(_ frame: ARFrame) {
        guard let depthData = frame.sceneDepth ?? frame.smoothedSceneDepth else {
            return
        }

        let depthMap = depthData.depthMap
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
            return
        }

        let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
        let intrinsics = frame.camera.intrinsics
        let transform = frame.camera.transform

        // Sample points from depth map
        let sampleStep = 8
        for y in stride(from: 0, to: height, by: sampleStep) {
            for x in stride(from: 0, to: width, by: sampleStep) {
                let depth = floatBuffer[y * width + x]

                guard depth > 0.1 && depth < 10.0 else { continue }

                // Convert to 3D point
                let point = unproject(
                    pixelX: Float(x),
                    pixelY: Float(y),
                    depth: depth,
                    intrinsics: intrinsics,
                    transform: transform
                )

                collectedPoints.append(point)
            }
        }

        pointCount = collectedPoints.count

        // Update progress (target ~10000 points for good coverage)
        scanProgress = min(1.0, Float(pointCount) / 10000.0)
    }

    private func unproject(
        pixelX: Float,
        pixelY: Float,
        depth: Float,
        intrinsics: simd_float3x3,
        transform: simd_float4x4
    ) -> SIMD3<Float> {
        let fx = intrinsics[0, 0]
        let fy = intrinsics[1, 1]
        let cx = intrinsics[2, 0]
        let cy = intrinsics[2, 1]

        // Camera space coordinates
        let x = (pixelX - cx) * depth / fx
        let y = (pixelY - cy) * depth / fy
        let z = depth

        let cameraPoint = SIMD4<Float>(x, -y, -z, 1)
        let worldPoint = transform * cameraPoint

        return SIMD3<Float>(worldPoint.x, worldPoint.y, worldPoint.z)
    }

    private func calculateRoomDimensions() -> RoomDimensions {
        let pointCloud = PointCloud(points: collectedPoints, timestamp: Date())
        let (minPoint, maxPoint) = pointCloud.boundingBox

        let width = maxPoint.x - minPoint.x
        let length = maxPoint.z - minPoint.z
        let height = maxPoint.y - minPoint.y

        let volume = width * length * height

        // Surface area = 2(wl + wh + lh)
        let surfaceArea = 2 * (width * length + width * height + length * height)

        return RoomDimensions(
            width: width,
            length: length,
            height: height,
            volume: volume,
            surfaceArea: surfaceArea
        )
    }
}

// MARK: - ARSessionDelegate

extension LiDARScanner: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        Task { @MainActor in
            processDepthData(frame)
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.error = .sessionFailed(error.localizedDescription)
            self.isScanning = false
        }
    }
}
