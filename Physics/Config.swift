import Foundation

/// Configuration constants for the physics simulation.
struct Config {
  /// Maximum allowed linear velocity (m/s) to prevent blow-ups.
  static let maxVelocity: Float = 25
  /// Number of solver iterations per frame for stability.
  static let solverIterations: Int = 15
  /// Clamp skeleton position to keep the simulation within view.
  static let positionLimit: Float = 15
  /// Ground plane height for the demo scene.
  static let groundY: Float = 0
}
