# Development Environment Configuration
environment               = "dev"
instance_type            = "t3.micro"
instance_count           = 1
enable_monitoring        = false
enable_backups          = false
enable_high_availability = false
allowed_cidrs = ["0.0.0.0/0"]  # Open for development

cost_optimization = {
  use_spot_instances = true   # Use spot instances to save costs
  enable_auto_stop   = true
  max_price         = 0.01
}