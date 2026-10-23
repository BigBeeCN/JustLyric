import Foundation

/// 蓝噪声抖动（S4 §4.3；S7 D33 #2：64×64 平铺、±1 LSB（≈0.4%））。
///
/// > Note: 平铺由交错梯度噪声（蓝噪声谱近似）确定性生成——实现级记录。
public enum BlueNoiseDither {
    /// 平铺边长（D33 #2）。
    public static let tileSize = 64
    /// 默认振幅 LSB（D33 #2：±1）。
    public static let amplitude = 1.0

    /// 生成 64×64 值平铺（确定性）。
    /// - Returns: 4096 个 0…255 值。
    public static func tile() -> [UInt8] {
        var values = [UInt8](repeating: 0, count: tileSize * tileSize)
        for y in 0 ..< tileSize {
            for x in 0 ..< tileSize {
                // 交错梯度噪声（固定常数，蓝噪声谱近似）。
                let noise = fract(52.9829189 * fract(0.06711056 * Double(x) + 0.00583715 * Double(y)))
                values[y * tileSize + x] = UInt8(noise * 255)
            }
        }
        return values
    }

    /// 位置偏移（D33 #2：±amplitude LSB）。
    /// - Parameters:
    ///   - x: 像素 x。
    ///   - y: 像素 y。
    ///   - amplitude: 振幅 LSB。
    /// - Returns: 偏移量（…±amplitude）。
    public static func offset(x: Int, y: Int, amplitude: Double = amplitude) -> Double {
        guard amplitude > 0 else { return 0 }
        let value = Double(tile()[(y % tileSize) * tileSize + (x % tileSize)]) / 255
        return (value * 2 - 1) * amplitude
    }

    private static func fract(_ value: Double) -> Double {
        value - floor(value)
    }
}
