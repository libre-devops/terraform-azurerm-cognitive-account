# check blocks run after every plan and apply and emit a warning (without blocking) when an
# invariant is violated. They are the place to enforce module-wide consistency.

# The module does nothing without at least one account.
check "has_accounts" {
  assert {
    condition     = length(var.cognitive_accounts) > 0
    error_message = "No cognitive_accounts were supplied, so this module creates nothing."
  }
}

# The secure baseline is no public endpoint. If public access is on, warn unless there is a
# deny-by-default network ACL narrowing it down to an allow-list.
check "public_access_is_locked_down" {
  assert {
    condition = alltrue([
      for a in values(var.cognitive_accounts) :
      a.public_network_access_enabled == false || (a.network_acls != null && a.network_acls.default_action == "Deny")
    ])
    error_message = "An account has the public endpoint enabled without a deny-by-default network ACL. Prefer public_network_access_enabled = false with a private endpoint, or network_acls.default_action = Deny with an ip_rules / virtual_network_rules allow-list."
  }
}

# Entra-only auth is the secure posture; warn when account keys are left on.
check "prefer_entra_only_auth" {
  assert {
    condition = alltrue([
      for a in values(var.cognitive_accounts) : a.local_auth_enabled == false
    ])
    error_message = "An account has local_auth_enabled = true (account keys work). Prefer Entra ID token auth (local_auth_enabled = false) and grant data-plane roles instead."
  }
}
