// Creating s3

resource "aws_s3_bucket" "public_site" {
  bucket = "public-site-step2"
  acl    = "public-read"

  website {
    index_document = "index.html"
  }

}

resource "aws_s3_bucket_object" "index" {
  bucket        = "${aws_s3_bucket.public_site.id}"
  key           = "index.html"
  content_type  = "text/html"
  acl           = "public-read"
  content       = <<EOF
Hello World!
You are Welcome!
EOF
}

// cloudfront

locals {
  s3_origin_id = "${aws_s3_bucket.public_site.id}"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.public_site.bucket_regional_domain_name}"
    origin_id   = "${local.s3_origin_id}"

  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "cloudfront challenge"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
