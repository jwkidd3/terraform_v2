# Staging Environment Configuration
environment               = "staging"
instance_type            = "t3.small"
instance_count           = 2
enable_monitoring        = true
enable_backups          = true
enable_high_availability = false
allowed_cidrs = [
  "10.0.0.0/8",     # Internal network
  "172.16.0.0/12"   # VPN range
]

cost_optimization = {
  use_spot_instances = false  # More stable for staging
  enable_auto_stop   = false
  max_price         = 0.05
}