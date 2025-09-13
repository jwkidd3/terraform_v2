# Output information from both module instances
output "dev_blog_info" {
  description = "Information about the dev blog application"
  value = {
    website_url     = module.dev_blog.website_url
    instance_id     = module.dev_blog.instance_id
    s3_bucket       = module.dev_blog.s3_bucket_name
  }
}

output "staging_portfolio_info" {
  description = "Information about the staging portfolio application"
  value = {
    website_url     = module.staging_portfolio.website_url
    instance_id     = module.staging_portfolio.instance_id
    s3_bucket       = module.staging_portfolio.s3_bucket_name
  }
}

output "all_websites" {
  description = "Quick access to all website URLs"
  value = {
    "Dev Blog"          = module.dev_blog.website_url
    "Staging Portfolio" = module.staging_portfolio.website_url
  }
}