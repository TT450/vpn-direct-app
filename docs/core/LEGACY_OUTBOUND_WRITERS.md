# Legacy NormalizedNode.outbound writers inventory (REQ-P026)
#
# Production P0 path (Xray → NormalizedNode):
# - XrayJSONAdapter sets `outbound: nil` and uses attributes + UniversalOutboundBuilder.
#
# Remaining writers that still construct outbound dictionaries (for share-link / factories):
# - XrayVLESSConverter / XrayLeafConverter / XrayMuxAndMask — produce dicts that are flattened
#   into attributes by XrayJSONAdapter (not attached as NormalizedNode.outbound).
# - HysteriaOutboundFactory / HysteriaShareLinkParser — build dicts consumed via fromAttributes.
# - VLESSConfigBuilder (Apple app single-link path) — separate from NormalizedNode graph.
# - UniversalOutboundBuilder LEGACY early-return — still present for migration; encryption
#   fail-closed is enforced even on that path.
#
# Goal: no P0 import attaches prebuilt outbound that bypasses CompatibilityFieldPolicy
# without capability checks. Verified by XrayAndFailClosedTests.testXrayJSONAttributesOnlyNoLegacyOutbound.
