import Foundation

/// RGB 颜色（0…255 分量）。
public struct PixelRGB: Equatable, Sendable {
    /// 红。
    public var r: Double
    /// 绿。
    public var g: Double
    /// 蓝。
    public var b: Double

    /// 创建 RGB。
    public init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }
}

/// Lab 颜色（D65）。
public struct LabColor: Equatable, Sendable {
    /// 明度。
    public var l: Double
    /// a 轴。
    public var a: Double
    /// b 轴。
    public var b: Double

    /// 创建 Lab。
    public init(l: Double, a: Double, b: Double) {
        self.l = l
        self.a = a
        self.b = b
    }
}

/// 取色结果（S4 §4；S7 D33 #1：主色=最大簇均值，辅色=次大簇且 ΔE>12）。
public struct ArtworkPalette: Equatable, Sendable {
    /// 主色。
    public var primary: PixelRGB
    /// 辅色。
    public var secondary: PixelRGB

    /// 创建调色板。
    public init(primary: PixelRGB, secondary: PixelRGB) {
        self.primary = primary
        self.secondary = secondary
    }
}

/// 取色器（S4 §4；S7 D33 #1：默认 KMeans-Lab（Lab、簇数 6、迭代 ≤10、忽略 <1% 簇），
/// OctTree 为快速路径；主色=最大簇均值，辅色=次大簇且 ΔE>12（不足补同色相明度变体））。
public enum ColorExtractor {
    /// 算法。
    public enum Algorithm: Sendable {
        /// KMeans-Lab（默认）。
        case kmeansLab
        /// OctTree 快速路径。
        case octTree
    }

    /// 簇数（D33 #1）。
    public static let clusterCount = 6
    /// 最大迭代（D33 #1）。
    public static let maxIterations = 10
    /// 忽略簇权重阈值（D33 #1：<1%）。
    public static let minClusterWeight = 0.01
    /// 辅色 ΔE 阈值（D33 #1）。
    public static let secondaryDeltaE = 12.0

    /// 从像素取色。
    /// - Parameters:
    ///   - pixels: 像素数组。
    ///   - algorithm: 算法。
    /// - Returns: 调色板；像素不足时为 `nil`。
    public static func palette(
        fromPixels pixels: [PixelRGB],
        algorithm: Algorithm = .kmeansLab
    ) -> ArtworkPalette? {
        guard !pixels.isEmpty else { return nil }
        let clusters: [(mean: PixelRGB, weight: Double)] =
            algorithm == .kmeansLab ? kmeansLab(pixels) : octTree(pixels)
        let valid = clusters
            .filter { $0.weight >= minClusterWeight }
            .sorted { $0.weight > $1.weight }
        guard let primaryCluster = valid.first else { return nil }
        let primary = primaryCluster.mean

        // 辅色=次大簇且 ΔE>12；不足补同色相明度变体（D33 #1）。
        let primaryLab = srgbToLab(primary)
        for candidate in valid.dropFirst() where deltaE(primaryLab, srgbToLab(candidate.mean)) > secondaryDeltaE {
            return ArtworkPalette(primary: primary, secondary: candidate.mean)
        }
        return ArtworkPalette(primary: primary, secondary: lightnessVariant(of: primaryLab))
    }

    /// 同色相明度变体（D33 #1 兜底）。
    public static func lightnessVariant(of lab: LabColor) -> PixelRGB {
        let shifted = LabColor(
            l: lab.l >= 50 ? max(0, lab.l - 25) : min(100, lab.l + 25),
            a: lab.a,
            b: lab.b
        )
        return labToSrgb(shifted)
    }

    // MARK: - 色彩空间（D65）

    /// sRGB → Lab。
    public static func srgbToLab(_ color: PixelRGB) -> LabColor {
        func channel(_ value: Double) -> Double {
            let v = value / 255
            return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        let r = channel(color.r)
        let g = channel(color.g)
        let b = channel(color.b)
        let x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047
        let y = r * 0.2126 + g * 0.7152 + b * 0.0722
        let z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883
        func f(_ t: Double) -> Double {
            t > 0.008856 ? pow(t, 1.0 / 3.0) : (7.787 * t) + (16.0 / 116.0)
        }
        let fx = f(x)
        let fy = f(y)
        let fz = f(z)
        return LabColor(l: (116 * fy) - 16, a: 500 * (fx - fy), b: 200 * (fy - fz))
    }

    /// Lab → sRGB（裁剪至 0…255）。
    public static func labToSrgb(_ lab: LabColor) -> PixelRGB {
        let fy = (lab.l + 16) / 116
        let fx = fy + (lab.a / 500)
        let fz = fy - (lab.b / 200)
        func fInv(_ t: Double) -> Double {
            pow(t, 3) > 0.008856 ? pow(t, 3) : (t - 16.0 / 116.0) / 7.787
        }
        let x = fInv(fx) * 0.95047
        let y = fInv(fy)
        let z = fInv(fz) * 1.08883
        let r = x * 3.2406 + y * -1.5372 + z * -0.4986
        let g = x * -0.9689 + y * 1.8758 + z * 0.0415
        let b = x * 0.0557 + y * -0.2040 + z * 1.0570
        func encode(_ v: Double) -> Double {
            let c = min(1, max(0, v))
            let srgb = c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1 / 2.4) - 0.055
            return (srgb * 255).rounded()
        }
        return PixelRGB(r: encode(r), g: encode(g), b: encode(b))
    }

    /// ΔE（CIE76）。
    public static func deltaE(_ a: LabColor, _ b: LabColor) -> Double {
        sqrt(pow(a.l - b.l, 2) + pow(a.a - b.a, 2) + pow(a.b - b.b, 2))
    }

    // MARK: - KMeans-Lab（默认）

    private static func kmeansLab(_ pixels: [PixelRGB]) -> [(mean: PixelRGB, weight: Double)] {
        let labs = pixels.map(srgbToLab)
        var centers: [LabColor] = (0 ..< clusterCount).map { index in
            labs[(index * labs.count) / clusterCount]
        }
        var assignments = [Int](repeating: 0, count: labs.count)

        for _ in 0 ..< maxIterations {
            var changed = false
            for (index, sample) in labs.enumerated() {
                let nearest = centers.enumerated().min {
                    deltaE(sample, $0.element) < deltaE(sample, $1.element)
                }!.offset
                if assignments[index] != nearest {
                    assignments[index] = nearest
                    changed = true
                }
            }
            for cluster in 0 ..< clusterCount {
                let members = zip(labs, assignments).filter { $0.1 == cluster }.map(\.0)
                if !members.isEmpty {
                    centers[cluster] = LabColor(
                        l: members.map(\.l).reduce(0, +) / Double(members.count),
                        a: members.map(\.a).reduce(0, +) / Double(members.count),
                        b: members.map(\.b).reduce(0, +) / Double(members.count)
                    )
                }
            }
            if !changed {
                break
            }
        }

        return (0 ..< clusterCount).compactMap { cluster in
            let members = zip(labs, assignments).filter { $0.1 == cluster }.map(\.0)
            guard !members.isEmpty else { return nil }
            let mean = LabColor(
                l: members.map(\.l).reduce(0, +) / Double(members.count),
                a: members.map(\.a).reduce(0, +) / Double(members.count),
                b: members.map(\.b).reduce(0, +) / Double(members.count)
            )
            return (labToSrgb(mean), Double(members.count) / Double(labs.count))
        }
    }

    // MARK: - OctTree（快速路径）

    private static func octTree(_ pixels: [PixelRGB]) -> [(mean: PixelRGB, weight: Double)] {
        // 按 4bit 通道粗分桶（OctTree 等价快速量化）。
        var buckets: [Int: (sum: (r: Double, g: Double, b: Double), count: Int)] = [:]
        for pixel in pixels {
            let key = (Int(pixel.r) >> 4) << 8 | (Int(pixel.g) >> 4) << 4 | (Int(pixel.b) >> 4)
            var bucket = buckets[key] ?? ((0, 0, 0), 0)
            bucket.sum.r += pixel.r
            bucket.sum.g += pixel.g
            bucket.sum.b += pixel.b
            bucket.count += 1
            buckets[key] = bucket
        }
        return buckets.values
            .sorted { $0.count > $1.count }
            .prefix(clusterCount)
            .map { bucket in
                (
                    PixelRGB(
                        r: bucket.sum.r / Double(bucket.count),
                        g: bucket.sum.g / Double(bucket.count),
                        b: bucket.sum.b / Double(bucket.count)
                    ),
                    Double(bucket.count) / Double(pixels.count)
                )
            }
    }
}
