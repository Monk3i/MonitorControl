//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Foundation
import os.log

class Display: Equatable {
  internal let identifier: CGDirectDisplayID
  internal let prefsId: String
  internal var name: String
  internal var vendorNumber: UInt32?
  internal var modelNumber: UInt32?

  static func == (lhs: Display, rhs: Display) -> Bool {
    return lhs.identifier == rhs.identifier
  }

  var isEnabled: Bool {
    get { prefs.object(forKey: PrefKey.state.rawValue + self.prefsId) as? Bool ?? true }
    set { prefs.set(newValue, forKey: PrefKey.state.rawValue + self.prefsId) }
  }

  var forceSw: Bool {
    get { return prefs.bool(forKey: PrefKey.forceSw.rawValue + self.prefsId) }
    set { prefs.set(newValue, forKey: PrefKey.forceSw.rawValue + self.prefsId) }
  }

  var swBrightness: Float {
    get { return prefs.float(forKey: PrefKey.SwBrightness.rawValue + self.prefsId) }
    set { prefs.set(newValue, forKey: PrefKey.SwBrightness.rawValue + self.prefsId) }
  }

  var friendlyName: String {
    get { return prefs.string(forKey: PrefKey.friendlyName.rawValue + self.prefsId) ?? self.name }
    set { prefs.set(newValue, forKey: PrefKey.friendlyName.rawValue + self.prefsId) }
  }

  var brightnessSliderHandler: SliderHandler?
  var isVirtual: Bool = false

  var defaultGammaTableRed = [CGGammaValue](repeating: 0, count: 256)
  var defaultGammaTableGreen = [CGGammaValue](repeating: 0, count: 256)
  var defaultGammaTableBlue = [CGGammaValue](repeating: 0, count: 256)
  var defaultGammaTableSampleCount: UInt32 = 0
  var defaultGammaTablePeak: Float = 1

  func prefValueExists(for command: Command) -> Bool {
    return prefs.object(forKey: PrefKey.value.rawValue + String(command.rawValue) + self.prefsId) != nil
  }

  func readPrefValue(for command: Command) -> Float {
    return prefs.float(forKey: PrefKey.value.rawValue + String(command.rawValue) + self.prefsId)
  }

  func savePrefValue(_ value: Float, for command: Command) {
    prefs.set(value, forKey: PrefKey.value.rawValue + String(command.rawValue) + self.prefsId)
  }

  func readPrefValueInt(for command: Command) -> Int {
    return prefs.integer(forKey: PrefKey.value.rawValue + String(command.rawValue) + self.prefsId)
  }

  func savePrefValueInt(_ value: Int, for command: Command) {
    prefs.set(value, forKey: PrefKey.value.rawValue + String(command.rawValue) + self.prefsId)
  }

  func prefValueExistsKey(forkey: PrefKey, for command: Command) -> Bool {
    return prefs.object(forKey: forkey.rawValue + String(command.rawValue) + self.prefsId) != nil
  }

  func readPrefValueKey(forkey: PrefKey, for command: Command) -> Float {
    return prefs.float(forKey: forkey.rawValue + String(command.rawValue) + self.prefsId)
  }

  func savePrefValueKey(forkey: PrefKey, value: Float, for command: Command) {
    prefs.set(value, forKey: forkey.rawValue + String(command.rawValue) + self.prefsId)
  }

  func readPrefValueKeyInt(forkey: PrefKey, for command: Command) -> Int {
    return prefs.integer(forKey: forkey.rawValue + String(command.rawValue) + self.prefsId)
  }

  func savePrefValueKeyInt(forkey: PrefKey, value: Int, for command: Command) {
    prefs.set(value, forKey: forkey.rawValue + String(command.rawValue) + self.prefsId)
  }

  func readPrefValueKeyString(forkey: PrefKey, for command: Command) -> String {
    return prefs.string(forKey: forkey.rawValue + String(command.rawValue) + self.prefsId) ?? ""
  }

  func savePrefValueKeyString(forkey: PrefKey, value: String, for command: Command) {
    prefs.set(value, forKey: forkey.rawValue + String(command.rawValue) + self.prefsId)
  }

  func readPrefValueKeyBool(forkey: PrefKey, for command: Command) -> Bool {
    return prefs.bool(forKey: forkey.rawValue + String(command.rawValue) + self.prefsId)
  }

  func savePrefValueKeyBool(forkey: PrefKey, value: Bool, for command: Command) {
    prefs.set(value, forKey: forkey.rawValue + String(command.rawValue) + self.prefsId)
  }

  func removePrefValueKey(forkey: PrefKey, for command: Command) {
    prefs.removeObject(forKey: forkey.rawValue + String(command.rawValue) + self.prefsId)
  }

  internal init(_ identifier: CGDirectDisplayID, name: String, vendorNumber: UInt32?, modelNumber: UInt32?, isVirtual: Bool = false) {
    self.identifier = identifier
    self.name = name
    self.vendorNumber = vendorNumber
    self.modelNumber = modelNumber
    self.prefsId = "(" + String(name.filter { !$0.isWhitespace }) + String(vendorNumber ?? 0) + String(modelNumber ?? 0) + "@" + String(identifier) + ")"
    os_log("Display init with prefsIdentifier %{public}@", type: .info, self.prefsId)
    self.isVirtual = isVirtual
    self.swUpdateDefaultGammaTable()
  }

  func calcNewBrightness(isUp: Bool, isSmallIncrement: Bool) -> Float {
    var step: Float = (isUp ? 1 : -1) / 16.0
    let delta = step / 4
    if isSmallIncrement {
      step = delta
    }
    return min(max(0, ceil((self.getBrightness() + delta) / step) * step), 1)
  }

  func stepBrightness(isUp: Bool, isSmallIncrement: Bool) {
    let value = self.calcNewBrightness(isUp: isUp, isSmallIncrement: isSmallIncrement)
    if self.setBrightness(value) {
      OSDUtils.showOsd(displayID: self.identifier, command: .brightness, value: value * 64, maxValue: 64)
      if let slider = brightnessSliderHandler {
        slider.setValue(value)
      }
    }
  }

  func setBrightness(_ to: Float) -> Bool {
    if self.setSwBrightness(value: to) {
      self.savePrefValue(to, for: .brightness)
      return true
    }
    return false
  }

  func getBrightness() -> Float {
    if self.prefValueExists(for: .brightness) {
      return self.readPrefValue(for: .brightness)
    } else {
      return self.getSwBrightness()
    }
  }

  func getShowOsdDisplayId() -> CGDirectDisplayID {
    if CGDisplayIsInHWMirrorSet(self.identifier) != 0 || CGDisplayIsInMirrorSet(self.identifier) != 0, CGDisplayMirrorsDisplay(self.identifier) != 0 {
      for mirrorMaestro in DisplayManager.shared.getAllNonVirtualDisplays() where CGDisplayMirrorsDisplay(self.identifier) == mirrorMaestro.identifier {
        if let otherMirrorMain = mirrorMaestro as? OtherDisplay, otherMirrorMain.isSw() {
          var thereAreOthers = false
          for mirrorMember in DisplayManager.shared.getAllNonVirtualDisplays() where CGDisplayMirrorsDisplay(mirrorMember.identifier) == CGDisplayMirrorsDisplay(self.identifier) && mirrorMember.identifier != self.identifier {
            thereAreOthers = true
          }
          if !thereAreOthers {
            return otherMirrorMain.identifier
          }
        }
      }
    }
    return self.identifier
  }

  func swUpdateDefaultGammaTable() {
    CGGetDisplayTransferByTable(self.identifier, 256, &self.defaultGammaTableRed, &self.defaultGammaTableGreen, &self.defaultGammaTableBlue, &self.defaultGammaTableSampleCount)
    let redPeak = self.defaultGammaTableRed.max() ?? 0
    let greenPeak = self.defaultGammaTableGreen.max() ?? 0
    let bluePeak = self.defaultGammaTableBlue.max() ?? 0
    self.defaultGammaTablePeak = max(redPeak, greenPeak, bluePeak)
  }

  func swBrightnessTransform(value: Float, reverse: Bool = false) -> Float {
    let lowTreshold: Float = 0.0 // If we don't want to allow zero brightness for safety reason, this value can be modified (for example to 0.1 for a 10% minimum)
    if !reverse {
      return value * (1 - lowTreshold) + lowTreshold
    } else {
      return (value - lowTreshold) / (1 - lowTreshold)
    }
  }

  let swBrightnessSemaphore = DispatchSemaphore(value: 1)
  func setSwBrightness(value: Float, smooth: Bool = false) -> Bool {
    let brightnessValue = min(1, value)
    var currentValue = self.swBrightness
    self.swBrightness = brightnessValue
    var newValue = brightnessValue
    currentValue = self.swBrightnessTransform(value: currentValue)
    newValue = self.swBrightnessTransform(value: newValue)
    if smooth {
      DispatchQueue.global(qos: .userInteractive).async {
        self.swBrightnessSemaphore.wait()
        for transientValue in stride(from: currentValue, to: newValue, by: 0.005 * (currentValue > newValue ? -1 : 1)) {
          let gammaTableRed = self.defaultGammaTableRed.map { $0 * transientValue }
          let gammaTableGreen = self.defaultGammaTableGreen.map { $0 * transientValue }
          let gammaTableBlue = self.defaultGammaTableBlue.map { $0 * transientValue }
          guard app.reconfigureID == 0 else {
            return
          }
          CGSetDisplayTransferByTable(self.identifier, self.defaultGammaTableSampleCount, gammaTableRed, gammaTableGreen, gammaTableBlue)
          Thread.sleep(forTimeInterval: 0.001) // Let's make things quick if not performed in the background
        }
        self.swBrightnessSemaphore.signal()
      }
    } else {
      let gammaTableRed = self.defaultGammaTableRed.map { $0 * newValue }
      let gammaTableGreen = self.defaultGammaTableGreen.map { $0 * newValue }
      let gammaTableBlue = self.defaultGammaTableBlue.map { $0 * newValue }
      CGSetDisplayTransferByTable(self.identifier, self.defaultGammaTableSampleCount, gammaTableRed, gammaTableGreen, gammaTableBlue)
    }
    return true
  }

  func getSwBrightness() -> Float {
    var gammaTableRed = [CGGammaValue](repeating: 0, count: 256)
    var gammaTableGreen = [CGGammaValue](repeating: 0, count: 256)
    var gammaTableBlue = [CGGammaValue](repeating: 0, count: 256)
    var gammaTableSampleCount: UInt32 = 0
    if CGGetDisplayTransferByTable(self.identifier, 256, &gammaTableRed, &gammaTableGreen, &gammaTableBlue, &gammaTableSampleCount) == CGError.success {
      let redPeak = gammaTableRed.max() ?? 0
      let greenPeak = gammaTableGreen.max() ?? 0
      let bluePeak = gammaTableBlue.max() ?? 0
      let gammaTablePeak = max(redPeak, greenPeak, bluePeak)
      let peakRatio = gammaTablePeak / self.defaultGammaTablePeak
      let brightnessValue = round(self.swBrightnessTransform(value: peakRatio, reverse: true) * 256) / 256
      return brightnessValue
    }
    return 1
  }

  func resetSwBrightness() -> Bool {
    return self.setSwBrightness(value: 1)
  }

  func isSwBrightnessNotDefault() -> Bool {
    guard !self.isVirtual else {
      return false
    }
    if self.getSwBrightness() < 1 {
      return true
    }
    return false
  }

  func refreshBrightness() -> Bool {
    return false
  }

  func isBuiltIn() -> Bool {
    if CGDisplayIsBuiltin(self.identifier) != 0 {
      return true
    } else {
      return false
    }
  }
}
