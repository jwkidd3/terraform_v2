# Production Environment Configuration
environment               = "prod"
instance_type            = "t3.medium"
instance_count           = 3
enable_monitoring        = true
enable_backups          = true
enable_high_availability = true
allowed_cidrs = [
  "10.0.0.0/8"      # Only internal network
]

cost_optimization = {
  use_spot_instances = false  # Never use spot in production
  enable_auto_stop   = false
  max_price         = 0.10
}