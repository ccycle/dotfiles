"use strict";
// Replaces node-addon-require-builtin's lib/index.js.
// The native addon locates Node's PrincipalRealm::builtin_module_require getter
// by matching its machine code, and rejects nixpkgs Node builds because they
// keep a frame-pointer prologue in that leaf function
// ("arm64 getter is not optional-bti-ldr-x0-this-imm-ret").
// Under --expose-internals, require() reaches the same internal modules, which
// is how dsh-hmr and cordis-plugin-loader already load them.
// getBindingInfo is omitted: no dsh code path calls it.
Object.defineProperty(exports, "__esModule", { value: true });
function requireBuiltin(moduleId) {
  if (!process.execArgv.includes("--expose-internals"))
    throw new Error(
      `node-addon-require-builtin shim: loading ${moduleId} requires node --expose-internals`,
    );
  return require(moduleId);
}
function isAllowedInternalId(moduleId) {
  return moduleId.startsWith("internal/");
}
exports.requireBuiltin = requireBuiltin;
exports.isAllowedInternalId = isAllowedInternalId;
exports.default = { requireBuiltin, isAllowedInternalId };
