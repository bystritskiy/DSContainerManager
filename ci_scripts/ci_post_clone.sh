#!/bin/sh

# Xcode Cloud post-clone script.
#
# TCA and its dependencies ship SPM macros (ComposableArchitecture,
# swift-case-paths, swift-dependencies, swift-perception). Xcode refuses to run
# a macro whose fingerprint has not been approved interactively, and there is no
# one to click "Trust & Enable" on a CI machine — the build would fail with
# "Macro ... must be enabled before it can be used". Locally the equivalent is
# the -skipMacroValidation flag; in Xcode Cloud it has to be set as a default
# before the build starts.

set -e

defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES

echo "Macro fingerprint validation disabled for this build."
