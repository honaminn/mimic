import Foundation
import Vision

enum PoseAngleKey: String, CaseIterable, Hashable {
    case leftElbow
    case rightElbow
    case leftKnee
    case rightKnee
    case leftShoulder
    case rightShoulder
    case leftHip
    case rightHip
}

struct PoseAngles: Hashable {
    var values: [PoseAngleKey: Double]
}

enum PoseAngleScorer {
    nonisolated static func score(current: PoseAngles, reference: PoseAngles) -> Double {
        var diffs: [Double] = []
        for key in PoseAngleKey.allCases {
            guard let cur = current.values[key], let ref = reference.values[key] else { continue }
            let diff = abs(cur - ref)
            diffs.append(diff)
        }

        guard !diffs.isEmpty else { return 0 }
        let averageDiff = diffs.reduce(0, +) / Double(diffs.count)
        let maxAngleDiff = 120.0
        let normalized = max(0, min(1, 1 - (averageDiff / maxAngleDiff)))
        return normalized * 100
    }

    nonisolated static func angles(from observation: VNHumanBodyPoseObservation, minConfidence: VNConfidence = 0.1) -> PoseAngles? {
        guard let points = try? observation.recognizedPoints(.all) else { return nil }

        func point(_ key: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
            guard let point = points[key], point.confidence >= minConfidence else { return nil }
            return CGPoint(x: point.x, y: point.y)
        }

        func angle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Double {
            let ab = CGVector(dx: a.x - b.x, dy: a.y - b.y)
            let cb = CGVector(dx: c.x - b.x, dy: c.y - b.y)
            let dot = ab.dx * cb.dx + ab.dy * cb.dy
            let mag = hypot(ab.dx, ab.dy) * hypot(cb.dx, cb.dy)
            guard mag > 0 else { return 0 }
            let cosValue = max(-1.0, min(1.0, dot / mag))
            return acos(cosValue) * 180.0 / Double.pi
        }

        var values: [PoseAngleKey: Double] = [:]

        if let shoulder = point(.leftShoulder),
           let elbow = point(.leftElbow),
           let wrist = point(.leftWrist) {
            values[.leftElbow] = angle(shoulder, elbow, wrist)
        }
        if let shoulder = point(.rightShoulder),
           let elbow = point(.rightElbow),
           let wrist = point(.rightWrist) {
            values[.rightElbow] = angle(shoulder, elbow, wrist)
        }
        if let hip = point(.leftHip),
           let knee = point(.leftKnee),
           let ankle = point(.leftAnkle) {
            values[.leftKnee] = angle(hip, knee, ankle)
        }
        if let hip = point(.rightHip),
           let knee = point(.rightKnee),
           let ankle = point(.rightAnkle) {
            values[.rightKnee] = angle(hip, knee, ankle)
        }
        if let elbow = point(.leftElbow),
           let shoulder = point(.leftShoulder),
           let hip = point(.leftHip) {
            values[.leftShoulder] = angle(elbow, shoulder, hip)
        }
        if let elbow = point(.rightElbow),
           let shoulder = point(.rightShoulder),
           let hip = point(.rightHip) {
            values[.rightShoulder] = angle(elbow, shoulder, hip)
        }
        if let shoulder = point(.leftShoulder),
           let hip = point(.leftHip),
           let knee = point(.leftKnee) {
            values[.leftHip] = angle(shoulder, hip, knee)
        }
        if let shoulder = point(.rightShoulder),
           let hip = point(.rightHip),
           let knee = point(.rightKnee) {
            values[.rightHip] = angle(shoulder, hip, knee)
        }

        guard !values.isEmpty else { return nil }
        return PoseAngles(values: values)
    }
}
