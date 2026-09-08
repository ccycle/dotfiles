# Provider auth comes from environment variables, never from literals here
# (TAILSCALE_OAUTH_CLIENT_ID / TAILSCALE_OAUTH_CLIENT_SECRET / TAILSCALE_TAILNET),
# set by scripts/tailscale-acl-apply.sh from sops. See ../secrets.yaml and
# .agents/skills/tailscale-acl-apply/SKILL.md for the credential bootstrap.
provider "tailscale" {}

# ../policy.hujson stays the single source of truth for the ACL content —
# it is also the file a human reviews/edits directly; this resource only
# owns getting that content applied. See ../design.md for why apply is
# manual (tofu plan review first).
resource "tailscale_acl" "this" {
  acl = file("${path.module}/../policy.hujson")
}
