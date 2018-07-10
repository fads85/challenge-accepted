output "cloudfront_domain" {
  value = "${aws_cloudfront_distribution.s3_distribution.domain_name}"
}

output "alb_dns" {
  value = "${aws_alb.nginx-fargate.dns_name}"
}
