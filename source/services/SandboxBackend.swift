// SandboxBackend.swift — Sandbox access backend enum
// Reconstructed from 5013 v3.2.17 binary
//
// Raw values decoded from inline Swift small-string constants:
//   0 = "mha_container" (legacyContainerNote)
//   1 = "kernel"
//   2 = "bad_query"
//   3 = "worse_query"
//   4 = "airLift"
//   5 = "unsupported"

import Foundation

enum SandboxBackend: String, CaseIterable, Equatable {
    case legacyContainerNote = "mha_container"
    case kernel              = "kernel"
    case badQuery            = "bad_query"
    case worseQuery          = "worse_query"
    case airLift             = "airLift"
    case unsupported         = "unsupported"
}
