// AppInfo.swift — Device and OS information
// Reconstructed from 5013 v3.2.17 binary

import Foundation

enum AppInfo {
    static var osVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    static var osBuild: String {
        var size: Int = 0
        sysctlbyname("kern.osversion", nil, &size, nil, 0)
        var buf = [CChar](repeating: 0, count: size)
        sysctlbyname("kern.osversion", &buf, &size, nil, 0)
        return String(cString: buf)
    }

    static var machineName: String {
        var size: Int = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var buf = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &buf, &size, nil, 0)
        return String(cString: buf)
    }
}
